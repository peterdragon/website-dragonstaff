#!/usr/bin/perl -w
# oiapachectl

use strict;

OIApacheCtl->new->run;
exit(0);


package OIApacheCtl;

use Carp;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use DBI;

sub new
{
	my $class = shift;

	my $apacheroot = "<%apache_root%>";
	#$apacheroot = ".";
	my $this = {
		VERSION		=> "0.5",
		apacheroot	=> "$apacheroot",
		logpath		=> "$apacheroot/logs",
		#httpdcmd		=> "/bin/echo child server_%s; sleep 9999999",
		# run mod_perl server su'd to dev so that tmplib will be owned by dev
		httpdmodperlcmd	=> "/bin/su <%omuser%> -l -c '$apacheroot/bin/httpdom -f $apacheroot/conf/httpd_modperl.conf -Dserver_oi%s'",
		# run proxy server as root so it can listen on port 80
		httpdproxycmd		=> "$apacheroot/bin/httpd -f $apacheroot/conf/httpd_proxy.conf",
		# run proxy ssl server as root so it can listen on port 443
		httpdproxysslcmd	=> "$apacheroot/bin/httpd -f $apacheroot/conf/httpd_proxy.conf -DSSL",
		hostipaddr	=> "<%ipaddr%>",
		siteroot		=> "<%oisiteroot%>",
		verbose		=> 0,
		proxy_listen_multi_ports => 0,
		servers_hp	=> undef,
		servers_ap	=> undef,
		dbh			=> undef,
		dbiargs		=> { dsn => "DBI:mysql:sys", user => "<%mysqlomuser%>", pass => "<%mysqlompw%>" },
	};
	bless $this, $class;

	$this->init;

	$this;
}

my $end_obj = undef;
sub end
{
	$end_obj->{dbh}->disconnect if $end_obj->{dbh};
	$end_obj->{dbh} = undef;
	$end_obj = undef;
}

END { end(); }

sub init
{
	my $this = shift;

	$end_obj = $this;
	if (exists $ENV{MOD_PERL})
	{
		Apache->request->register_cleanup(\&end);
	}

	$this->sql_connect_db || confess "cannot connect to db $this->{dbiargs}->{dsn}: $!";

	# get backend server information from SQL sys_backend table
	$this->{servers_ap} = $this->sql_get_servers
		or die "no servers found in $this->{dbiargs}->{dsn} sys_server";
	$this->{servers_hp} = { map { ${_}->{server} => ${_} } @{$this->{servers_ap}} };
	$this->{vhosts_ap} = $this->sql_get_enabled_vhosts
		or die "no vhosts found in $this->{dbiargs}->{dsn} sys_vhost";


	$this;
}

sub run
{
	my $this = shift;
	my $command = "list";
	my $server = "all";
	GetOptions (
		help			=> sub { pod2usage(1); },
		man			=> sub { pod2usage(-exitstatus => 1, -verbose => 2); },
		verbose		=> \$this->{verbose},
		command		=> \$command,
		'server=s'	=> \$server,
		)
		or exit(1);
	#print "verbose = $this->{verbose}\ncommand = $command\nserver = $server\n";
	#print Dumper(@ARGV);
	$command = shift @ARGV if $#ARGV >= 0;
	my @server_names = ($#ARGV >= 0) ? @ARGV : ($server);

	unless ( $> == 0 )
	{
		die "you need to be root to run this program, try doing\n"
	.		 "sudo service httpdoi start\n";
	}

	$| = 1;

	my $fn = "command_$command";
	die "Unrecognised command \"$command\"" unless $this->can($fn);

	# single command
	if ( $command eq "writeconfig" )
	{
		my $res = $this->$fn;
		exit($res);
	}

	# command that applies to 1 or all servers
	# build up and verify server array
	my @servers;
	if ( $server_names[0] eq "all" )
	{
		@servers = @{$this->{servers_ap}};
	}
	else
	{
		for my $server ( @server_names )
		{
			die "invalid server \"" . bold($server) . "\"" unless $this->{servers_hp}->{$server};
			push @servers, $this->{servers_hp}->{$server};
		}
	}
	# process servers
	for ( @servers )
	{
		my $res = $this->$fn ( server => ${_}->{server}, port => ${_}->{port}, );
		exit($res) if $res;
	}

	exit(0);
}

###

sub sql_connect_db
{
	my $this = shift;

	my $da = $this->{dbiargs};
	$this->{dbh} = DBI->connect( $da->{dsn}, $da->{user}, $da->{pass} )
			|| die "Cannot connect to database $da->{dsn}: $DBI::errstr" ;
	#$this->{dbh}->{RaiseError} = 1;
}

sub sql_get_servers
{
	my $this = shift;

	my ($rv, $sth) = $this->sql_exec ( <<ENDSQL );
SELECT
	svr_server,
	svr_port,
	svr_enabled
FROM
	sys_server
ORDER BY
	svr_port
ENDSQL

	return undef unless $rv > 0;

	my @servers;

	while ( my $rp = $sth->fetchrow_hashref )
	{
		push @servers, { server => "$rp->{svr_server}", port => "$rp->{svr_port}", secure => "0", enabled => "$rp->{svr_enabled}" };
	}
	$sth->finish;

	return \@servers;
}

sub sql_get_enabled_vhosts
{
	my $this = shift;

	my ($rv, $sth) = $this->sql_exec ( <<ENDSQL );
SELECT
	svh_vhost,
	svh_server,
	svh_comment,
	svh_secure,
	svr_port
FROM
	sys_vhost, sys_server
WHERE
	svh_server = svr_server
AND
	svh_enabled != '0'
AND
	svr_enabled != '0'
ORDER BY
	svh_vhost
ENDSQL

	return undef unless $rv > 0;

	my @vhosts;
	while ( my $rp = $sth->fetchrow_hashref )
	{
		push @vhosts, {
				vhost => "$rp->{svh_vhost}",
				server => "$rp->{svh_server}",
				comment => "$rp->{svh_comment}",
				secure => "$rp->{svh_secure}",
				port => "$rp->{svr_port}",
		};
	}
	$sth->finish;
	return \@vhosts;
}

sub sql_update_server_pid
{
	my $this = shift;
	my %arg = ( server => undef, pid => undef, @_ );
	confess unless $arg{server} && defined $arg{pid};

	my ($rv, $sth) = $this->sql_exec ( <<ENDSQL , $arg{pid}, $arg{server} );
UPDATE
	sys_server
SET
	svr_pid = ?
WHERE
	svr_server = ?
ENDSQL
	$rv;
}

sub sql_exec
{
	my $this = shift;
	my $sql = shift;

	confess unless $this->{dbh};
	my $sth = $this->{dbh}->prepare($sql) || confess;
	my $rv = $sth->execute(@_);
	unless ($rv)
	{
		confess "cannot execute sql: ", $sth->errstr(), "\nsql: $sql\nargs: \"", join("\", \"",@_), "\"\n";
	}
	return ($rv, $sth);
}

### commands

sub command_list
{
	my $this = shift;

	print "Available servers are:\n", join("\n",sort(keys %{$this->{servers_hp}})), "\n";
}

sub command_start
{
	my $this = shift;
	my %arg = ( server => undef, port => undef, @_ );

	# check if running
	if ( $this->server_httpd_is_running($arg{server}) )
	{
		print "server ".bold($arg{server})." httpd already running with pid "
			. $this->server_httpd_get_pid($arg{server}) . "\n";
		return 0;
	}
	# check enabled
	unless ( $this->{servers_hp}->{$arg{server}}->{enabled} )
	{
		print "server ".bold($arg{server})." not enabled\n";
		return 0;
	}
	# build command
	my $cmd =
		$arg{server} eq "proxy" 	?	$this->{httpdproxycmd} :
		$arg{server} eq "proxyssl" ?	$this->{httpdproxysslcmd} :
					sprintf($this->{httpdmodperlcmd}, $arg{server});
	print "$cmd\n" if $this->{verbose};
	# run child
	my $pid = fork();
	die "cannot fork: $!" unless defined $pid;
	if ($pid == 0) # child
	{
		exec($cmd);
		warn "could not run $cmd: $!";
		exit(0);
	}
	if ( $pid ) # parent
	{
		print "starting server ".bold($arg{server})." httpd child process on port $arg{port}\n";
		$pid = 0;
		my $retry_secs = 20;
		my $retry_interval = 0.1;
		for (my $i=0; $i < ($retry_secs/$retry_interval) && $pid == 0; $i++)
		{
			select(undef,undef,undef,$retry_interval); # wait for short interval
			$pid = $this->server_httpd_get_pid($arg{server});
			if ( $pid && kill(0,$pid) )
			{
				print "...started process $pid\n";
				$this->sql_update_server_pid ( server => $arg{server}, pid => $pid );
				return 0; # success
			}
		}
		# failed
		die boldhigh("ERROR: server $arg{server} child failed");
	}
	exit(1);
}

sub command_stop
{
	my $this = shift;
	my %arg = ( server => undef, port => undef, @_ );

	# check if running
	unless ( $this->server_httpd_is_running($arg{server}) )
	{
		print "server ".bold($arg{server})." httpd already stopped\n";
	}
	else
	{
		my $pid = $this->server_httpd_get_pid($arg{server});
		if ( kill(15,$pid) )
		{
			print "stopped server ".bold($arg{server})." httpd child process $pid\n";
			# wait for httpd to remove pid file
			my $retry_secs = 10;
			my $retry_interval = 0.1;
			my $pidfile = $this->server_pidfile_path($arg{server});
			for (my $i=0; $i < ($retry_secs/$retry_interval) && $pid; $i++)
			{
				select(undef,undef,undef,$retry_interval); # wait for short interval
				$pid = 0 unless $this->server_httpd_get_pid($arg{server});
			}
			if ( $pid )
			{
				die boldhigh("ERROR: server $arg{server} child $pid did not exit and removed pidfile $pidfile");
			}
		}
		else
		{
			warn "could not kill process pid $pid: $!";
		}
		$this->server_tidyup($arg{server});
	}
	0;
}

sub command_restart
{
	my $this = shift;
	my %arg = ( server => undef, port => undef, @_ );

	$this->command_stop(@_);
	$this->command_start(@_);

	0;
}

sub command_status
{
	my $this = shift;
	my %arg = ( server => undef, port => undef, @_ );

	my $pid = $this->server_httpd_get_pid($arg{server});

	if ( $this->server_httpd_is_running($arg{server}) )
	{
		print "server ".bold($arg{server})." httpd running with pid $pid listening on port $arg{port}\n";
	}
	elsif ( $pid == 0 )
	{
		print "server ".bold($arg{server})." not running\n";
	}
	else # child has exited early
	{
		print boldhigh("WARNING: server $arg{server} httpd child pid $pid port $arg{port} exited too soon\n");
		# tidy up
		my $path = $this->server_pidfile_path($arg{server});
		unlink($path) or warn "cannot remove pidfile \"$path\"";
		$this->sql_update_server_pid ( server => $arg{server}, pid => 0 );
	}

	0;
}

sub command_writeconfig
{
	my $this = shift;

	my ($path,$s);

	# precalculate some vars to use in here documents
	my $hostipaddr = $this->{hostipaddr} || confess;
	my $apacheroot = $this->{apacheroot} || confess;
	my $siteroot = $this->{siteroot} || confess;
	my $generatedby = "generated by oiapachectl v$this->{VERSION}";

	my $ports_hp = { map { ${_}->{port} => ${_} } @{$this->{servers_ap}} };
	my $vhosts_hp = { map { ${_}->{vhost} => ${_} } @{$this->{vhosts_ap}} };

	## do mod_perl config
	# build up config file contents
	$s = <<EOM ;
# httpd_modperl.conf ${generatedby}
Include ${apacheroot}/conf/httpd_modperl_base.conf
# run httpd_modperl with -Dserver_name where server_name is one of the following

EOM
	# add servers to config file in port order
	for my $port ( sort keys %$ports_hp )
	{
		my $server = $ports_hp->{$port}->{server};
		next if $server =~ m/^proxy/; # only for mod_perl servers, proxy goes to different apache below
		my $pidpath = $this->server_pidfile_path($server);
		#$this->command_stop( server => $server, port => $port );
		$s .= <<EOM ;
<IfDefine server_oi${server}>
Listen 127.0.0.1:${port}
PidFile ${pidpath}
<VirtualHost 127.0.0.1:${port}>
Port $port
Include ${siteroot}/${server}/conf/httpd_modperl.conf
</VirtualHost>
</IfDefine>

EOM
	}
	# write mod_perl config file
	$path = "${apacheroot}/conf/httpd_modperl.conf";
	open(F, "> $path") or die "cannot write config file $path";
	print F $s or confess;
	close(F) or confess;
	print "written config file $path\n";

	## do proxy vhosts config
	$s = "";
	$s = <<EOM ;
# httpd_proxy_vhosts.conf ${generatedby}
EOM

	# keep track of which backends are required and what the port is
	my %backend;
	for my $vhost ( sort keys %$vhosts_hp )
	{
		my $server = $vhosts_hp->{$vhost}->{server};
		next if $server =~ m/^proxy/; # only for mod_perl servers
		$backend{$server} = $vhosts_hp->{$vhost}->{port};
	}
	# option to listen at one address with multiple ports and map these to backends
	if ( $this->{proxy_listen_multi_ports} )
	{
		# put Listen statements in for each backend
		for ( keys %backend )
		{
			$s .= "Listen ${hostipaddr}:$backend{$_}\n";
		}
		$s .= "\n";
	}

	# define vhost containers
	for my $vhost ( sort keys %$vhosts_hp )
	{
		my $server = $vhosts_hp->{$vhost}->{server};
		next if $server =~ m/^proxy/; # only for mod_perl servers
		my $port = $vhosts_hp->{$vhost}->{port};
		my $security = $vhosts_hp->{$vhost}->{secure} ?
			"   Include ${apacheroot}/conf/httpd_proxy_secure.conf\n"
		:  "";
		$s .= <<EOM ;

# proxy ${vhost} to backend ${server} at localhost:${port}
<VirtualHost *>
   ServerName        ${vhost}
   ErrorLog          logs/proxy_error_log_${vhost}
   DocumentRoot      ${siteroot}/${server}/html
   Include ${apacheroot}/conf/httpd_proxy_rewrite1.conf
   RewriteRule       ^/(.*\$)  http://127.0.0.1:${port}/\$1 [P]
   Include ${apacheroot}/conf/httpd_proxy_rewrite2.conf
$security</VirtualHost>
EOM
	}
	
	# write proxy config file
	$path = "${apacheroot}/conf/httpd_proxy_vhosts.conf";
	open(F, "> $path") or die "cannot write config file $path";
	print F $s or confess;
	close(F) or confess;
	print "written config file $path\n";

	0;
}

###

sub server_pidfile_path
{
	($_[0]->{logpath}||".") . "/" . "oihttpd.pid." . $_[1];
}

sub server_httpd_get_pid
{
	my $this = shift;
	my $server = shift;
	my $arr_ap = $this->read_into_array ( file => $this->server_pidfile_path($server) )
		or return 0;
	return 0 + @$arr_ap[0];
}

sub server_httpd_write_pid
{
	my $this = shift;
	my $server = shift;
	my $pid = shift;

	return 1;

	my $path = $this->server_pidfile_path($server);
	$this->write_from_array ( file => $path, arrayptr => [ "$pid" ] )
		or die "cannot write file \"$path\": $!";
	1;
}

sub server_tidyup
{
	my $this = shift;
	my $server = shift;

	$this->sql_update_server_pid ( server => $server, pid => 0 );
	#my $path = $this->server_pidfile_path($server);
	#unlink($path) or warn "cannot remove pidfile \"$path\"";
}

sub server_httpd_is_running
{
	my $this = shift;
	my $server = shift;
	my $pid = $this->server_httpd_get_pid ( $server );
	return $pid && kill(0,$pid);
}

###

sub bold
{
	sprintf "\033[1m" . join("",@_) . "\033[0m";
}

sub boldhigh
{
	sprintf "\033[1;45m" . join("",@_) . "\033[0m";
}

sub read_into_array
{
	my $this = shift;
	my %arg = ( trim => 0, file => undef, @_ );

	open(F, "< $arg{file}") or return undef;
	my @arr;
	while (<F>)
	{
		next if /^#/ or /^(\s)*$/; # ignore comments or blank lines
		chomp;		# remove newline
		if ( $arg{trim} )	# trim leading, trailing spaces
		{
      	s/^\s+//;
      	s/\s+$//;
      }
		push(@arr, $_);
	}
	close (F) or return undef;
	return \@arr;
}

sub write_from_array
{
	my $this = shift;
	my %arg = ( trim => 0, file => undef, arrayptr => undef, @_ );

	open(F, "> $arg{file}") or return undef;
	for ( @{$arg{arrayptr}} )
	{
		if ( $arg{trim} )
		{
      	s/^\s+//;
      	s/\s+$//;
		}
		print F "$_\n" or return undef;
	}
	close(F) or return undef;
	return 1;
}


__END__

=head1 NAME

oiapachectl - control OI apache web servers

=head1 SYNOPSIS

oiapachectl [-verbose] [-help|-man] [-server {all}] [-command] {list}|start|stop|status|restart|writeconfig [server1 [server2...]]

=head1 OPTIONS

=over 8

=item B<-verbose>

Print details of commands issued.

=item B<-help>

Print brief help and exit.

=item B<-man>

Print manual page and exit.

=item B<-server {all}>

Sets the servers whose web servers are to be controlled. Defaults to all.

=item B<-command>

Optional prefix to one of the following commands.

=item B<list>

List available servers which have mod_perl web servers (default command).

=item B<start>

Start the specified servers.

=item B<stop>

Stop the specified servers.

=item B<status>

Report on the status of the specified servers.

=item B<restart>

Stop, then start, the specified servers.

=item B<writeconfig>

Stop servers, then write out apache config file from
servers listed in SQL sys_server table.

=item B<server1..servern>

Alternative way of setting servers to be controlled. Default is "all",
which affects all known servers.

=back

=head1 DESCRIPTION

Controls OI apache mod_perl web servers. Lets you start, stop, restart one or more servers.
By default, it applies the command to all server. You can specify --server to restrict it to
a particular server.

=cut
