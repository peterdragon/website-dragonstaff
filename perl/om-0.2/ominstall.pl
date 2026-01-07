#!/usr/bin/perl
# ominstall.pl - build/configure OM application for perl 5.8.0 on Redhat EL 3 or 4
# set tabstop to 3 spaces to read properly
# OM uses the OI (OpenInteract) mod_perl framework and Apache web server
#

use strict;
use warnings;

{
	ominstall->new->run;
	exit(0);
}

package cpanversion;

sub getmoduleversion
{
	my $module = shift || die;
	my $rc = eval "require $module";
	no strict 'refs';
	my $ver = ${"${module}::VERSION"} || '0';
	my @ver = split(/\./,$ver);
	$ver = $ver[0]*1.0;
	$ver += $ver[1]/100.0 if defined $ver[1];
	$ver += $ver[2]/10000.0 if defined $ver[2];
	use strict 'refs';
	#print "module instver $ver\n";
	$ver;
}

sub modulenametoversion
{
	my $module = shift || die;
	my $ver = $module;
	$ver =~ s/[a-zA-Z][0-9]+//g;
	$ver =~ s/[^0-9\.\-]//g;
	$ver =~ s/\-/\./g;
	$ver =~ s/(\.)+/\./g;
	$ver =~ s/^(\.)+//;
	$ver =~ s/(\.)+$//;
	my @ver = split(/\./,$ver);
	$ver = $ver[0]*1.0;
	$ver += $ver[1]/100.0 if defined $ver[1];
	$ver += $ver[2]/10000.0 if defined $ver[2];
	$ver;	
}



package ominstall;

use vars qw/ $VERSION /;
$VERSION = "0.2";


use Carp;
use Getopt::Long;
use Pod::Usage;
use File::Path;
use File::Copy;
use Cwd;
use Data::Dumper;
use ExtUtils::Installed;


my $obj;

sub new
{
	my $class = shift;

	my $this = {
		verbose			=> 0,
		debug				=> 0,
		timestamp		=> 0,
		tarnoalternate	=> 0,
		taroverwrite	=> 0,
		ask				=> 0,
		phases_ap		=> [
			'userroot',
			'userom',
			'network',
			'rpm',
			'aptlocalrhel3',
			'mysql',
			'phpmyadmin',
			'apachessl',
			'buildapacheproxy',
			'buildapachemodperl',
			'configureapaches',
			'libgd',
			'cpan_oi',
			'cpan_om',
			'oi',
			'omconf',
			'oiserver',
			'omsite',
			'start',
			],		
		optphases_ap	=> [
			'aptnet',
			],
		settings			=> {},
		default_settings		=> [
			#installsrc		=> '/mnt/cdrom',
			installsrc		=> '/usr2/om',
			work_root		=> '/tmp/om',
			hostname			=> 'server1',
			domain			=> 'mydomain.com',
			ipaddr			=> '69.61.62.175',
			network			=> '69.61.62.0',
			subnet			=> '69.61.62.',
			netmask			=> '255.255.255.0',
			broadcast		=> '69.61.62.255',
			gateway			=> '192.168.1.1',
			omroot			=> '/opt/om',
			oisiteroot		=> '/opt/om/site',
			oibaseroot		=> '/opt/om/base',
			ombin				=> '/opt/om/bin',
			oisrcroot		=> '/opt/om/src/',
			oisrc				=> '/opt/om/src/openinteract',
			omuser			=> 'om',
			omgroup			=> 'om',
			ompw				=> 'om',
			omhome			=> '/opt/om',
			omuid				=> '400',
			omgid				=> '400',
			server			=> 'test',
			serverport		=> '8082',
			site				=> 'test',
			vhost				=> 'test.mydomain.com',
#			omdatabase		=> 'dstest',
			mysqlrootpw		=> '18fh237Ax9',
			mysqlomuser		=> 'om',
			mysqlompw		=> 'om',
			apache_root		=> '/opt/om/apache',
			apache_docroot	=> '/opt/om/apache/htdocs',
			mysql_db_root	=> '/var/lib/mysql',
			perlprefix		=> '/opt/om/perllib',
			phpmyadminwebpw => '.0A9by5.',
			oiapachectl		=> '/opt/om/bin/oiapachectl',
			oi_manage		=> '/opt/om/perllib/bin/oi_manage',
			mysql				=> '/usr/bin/mysql',
			],
		fixed_settings			=> {
			oiapachectl_src	=> 'oiapachectl.pl',
			root_pkg			=> 'root.tgz',
			libgd_pkg		=> 'gd-2.0.33.tar.gz',
			om_sql			=> 'om.sql',
			dsblank_sql 	=> 'dsblank.sql',
			oiblank_sql		=> 'oiblank.sql',
			phpmyadmin_pkg => 'phpMyAdmin-2.6.1.tar.gz',
			apache_pkg		=> 'apache_1.3.33.tar.gz',
			modperl_pkg		=> 'mod_perl-1.29.tar.gz',
			modssl_pkg		=> 'mod_ssl-2.8.22-1.3.33.tar.gz',
			apacheconf_pkg	=> 'apacheconf.tgz',
			omhtml_pkg		=> 'omhtml.tgz',
			omhome_pkg		=> 'omhome.tgz',
			oi_cpan_pkg		=> 'OpenInteract-1.62.tar.gz',
			oipatchoi_pkg	=> 'ompatchoi62.tgz',
			oi_om_conftemplate_pkg => 'omoiconftemplate.tgz',
			oi_om_conftemplate_morefiles => [
					'log4perl.conf',
					],
			archivetar_pkgs => [
					'IO-String-1.06.tar.gz',
					'IO-Zlib-1.04.tar.gz',
					'Archive-Tar-1.23.tar.gz',
					],
			rpm_mysql_pkgs => [
					'MySQL-server-4.1.9-0.i386.rpm',
					'MySQL-client-4.1.9-0.i386.rpm',
					'MySQL-shared-compat-4.1.9-0.i386.rpm',
					],
			rpm_pkgs => [
					'apt-0.5.15cnc6-3.1.el3.dag.i386.rpm',
					'lynx-2.8.5-11.i386.rpm',
					],
			aptrpm_pkgs => [ qw/
					eel2_2.3.7-0.dag.rhel3_i386.rpm
					evolution-connector_1.4.7.2-1.1.el3.dag_i386.rpm
					intltool_0.28-0.rhel3.dag_i386.rpm
					lftp_3.0.12-1.1.el3.rf_i386.rpm
					libxml2_2.6.16-1.1.el3.rf_i386.rpm
					libxml2-devel_2.6.16-1.1.el3.rf_i386.rpm
					libxml2-python_2.6.16-1.1.el3.rf_i386.rpm
					logwatch_5.2.2-0.1.1.el3.dag_noarch.rpm
					mtools_3.9.9-2.rhel3.dag_i386.rpm
					mtr_2%3a0.65-1.1.el3.rf_i386.rpm
					nmap_2%3a3.81-1.1.el3.rf_i386.rpm
					perl-Digest-SHA1_2.07-1.rhel3.dag_i386.rpm
					perl-Net-DNS_0.48-1.1.el3.rf_i386.rpm
					perl-XML-Parser_2.34-1.1.el3.dag_i386.rpm
					rsync_2.6.3-1.1.el3.rf_i386.rpm
					spamassassin_2.64-2.1.el3.dag_i386.rpm
					splint_3.1.1-1.rhel3.dag_i386.rpm
					synaptic_0.55.1-1.1.el3.rf_i386.rpm
					syslinux_3.07-1.1.el3.rf_i386.rpm
				/	],
			cpan_bundle_dbd_mysql_pkgs => [
					[ 'DBI'					=> 'DBI-1.47.tar.gz' ],
					[ 'Data::ShowTable'  => 'Data-ShowTable-3.3.tar.gz' ],
					[ 'DBD::mysql'			=>	'DBD-mysql-2.9005_3.tar.gz' ],
					],
			cpan_bundle_mp_pkgs => [
					[ 'libapreq'	=> 'libapreq-1.33.tar.gz' ],
					],
			cpan_bundle_oi_pkgs => [
					# Bundle::CPAN
					#{ m=>'File::Spec', f=>'PathTools-3.04.tar.gz', force=>1 },
					#{ m=>'Digest::MD5', f=>'Digest-MD5-2.33.tar.gz', precmd=>'LANG=en_US.UTF-8 perl Makefile.PL', makefile=>0 },
					[ 'Compress::Zlib'	=> 'Compress-Zlib-1.34.tar.gz' ],
					[ 'Data::Dumper'		=> 'Data-Dumper-2.121.tar.gz' ],
					[ 'Net::Telnet'		=> 'Net-Telnet-3.03.tar.gz' ],
					{m=>'Net::FTP', f=> 'libnet-1.19.tar.gz', precmd=>'/usr/bin/perl Configure -d' },
					[ 'Term::ReadKey'		=> 'TermReadKey-2.30.tar.gz' ],
					{m=>'Term::ReadLine::Perl', f=>'Term-ReadLine-Perl-1.0203.tar.gz', ver=>'0.99' },
					[ 'CPAN'					=> 'CPAN-1.76.tar.gz' ],
					# OI (OpenInteract)
					{ m=>'IPC::ShareLite', f=>'IPC-ShareLite-0.09.tar.gz', precmd => './Configure -de; /usr/bin/yes \'\' | /usr/bin/perl Makefile.PL', makefile => 0 },
					[ 'base'					=> 'base-2.03.tar.gz' ],
					[ 'Digest'				=> 'Digest-1.10.tar.gz' ],
					[ 'Digest::SHA1'		=> 'Digest-SHA1-2.10.tar.gz' ],
					[ 'Error'				=> 'Error-0.15.tar.gz' ],
					[ 'Cache::Cache'		=> 'Cache-Cache-1.03.tar.gz' ],
					{m=>'Module::Build', f=>'Module-Build-0.2608.tar.gz', precmd => '/usr/bin/perl Makefile.PL install_base=\'/opt/om/perllib\'', makefile => 0 },
					[ 'Params::Validate'	=> 'Params-Validate-0.76.tar.gz' ],
					[ 'Net::Daemon'		=> 'Net-Daemon-0.38.tar.gz' ],
					[ 'RPC::PlServer'		=> 'PlRPC-0.2018.tar.gz' ],
					[ 'Test::Manifest'	=> 'Test-Manifest-1.11.tar.gz' ],
					[ 'Tie::DBI'			=> 'Tie-DBI-0.94.tar.gz' ],
					{m=>'Devel::CoreStack', f=>'Devel-CoreStack-1.3.tar.gz', ver=>'1.03'},
					[ 'Test::Harness'		=> 'Test-Harness-2.46.tar.gz' ],
					[ 'Test::Simple'		=> 'Test-Simple-0.47.tar.gz' ],
					{ m=>'IPC::ShareLite', f=>'IPC-ShareLite-0.09.tar.gz', precmd => './Configure -de', makefile => 0 },
					{ m=>'CPAN::WAIT', f=>'CPAN-WAIT-0.27-2.tar.gz', ver=>'0.27', precmd => '/bin/touch .notest' },
					[ 'Apache::DBI'		=> 'Apache-DBI-0.94.tar.gz' ],
					[ 'Carp::Assert'		=> 'Carp-Assert-0.18.tar.gz' ],
					[ 'Class::Fields'		=> 'Class-Fields-0.201.tar.gz' ],
					[ 'Class::Accessor'	=> 'Class-Accessor-0.19.tar.gz' ],
					[ 'Class::Date'		=> 'Class-Date-1.1.7.tar.gz' ],
					[ 'Class::Singleton'	=> 'Class-Singleton-1.03.tar.gz' ],					
					[ 'Carp::Clan'			=> 'Carp-Clan-5.3.tar.gz' ],
					[ 'Bit::Vector'		=> 'Bit-Vector-6.4.tar.gz' ],
					[ 'Date::Calc'			=> 'Date-Calc-5.4.tar.gz' ],
					[ 'File::MMagic'		=> 'File-MMagic-1.22.tar.gz' ],
					[ 'Mail::RFC822::Address'	=>'Mail-RFC822-Address-0.3.tar.gz' ],
					[ 'Mail::Sendmail'	=> 'Mail-Sendmail-0.79.tar.gz' ],
					[ 'Pod::POM'			=>'Pod-POM-0.15.tar.gz' ],
					[ 'HTML::Tree'			=>'HTML-Tree-3.18.tar.gz' ],
					[ 'HTML::Summary'		=> 'HTML-Summary-0.017.tar.gz' ],
					[ 'Devel::StackTrace'	=> 'Devel-StackTrace-1.11.tar.gz' ],
					[ 'Time::Piece'		=> 'Time-Piece-1.08.tar.gz' ],
					[ 'Class::Factory'	=> 'Class-Factory-1.03.tar.gz' ],
					[ 'Text::German'		=> 'Text-German-0.03.tar.gz' ],
					[ 'Lingua::Stem::Snowball::No'	=> 'Snowball-Norwegian-1.0.tar.gz' ],
					[ 'Lingua::Stem::Snowball::Se'	=> 'Snowball-Swedish-1.01.tar.gz' ],
					[ 'Lingua::PT::Stemmer'	=> 'Lingua-PT-Stemmer-0.01.tar.gz' ],
					[ 'Lingua::Stem::It'	=> 'Lingua-Stem-It-0.01.tar.gz' ],
					[ 'Lingua::Stem::Fr'	=> 'Lingua-Stem-Fr-0.02.tar.gz' ],
					[ 'Lingua::Stem::Ru'	=> 'Lingua-Stem-Ru-0.01.tar.gz' ],
					[ 'Lingua::Stem::Snowball::Da'	=> 'Lingua-Stem-Snowball-Da-1.01.tar.gz' ],
					[ 'Lingua::Stem'		=> 'Lingua-Stem-0.81.tar.gz' ],
					[ 'Text::Reform'		=> 'Text-Reform-1.11.tar.gz' ],
					[ 'Text::Autoformat'	=> 'Text-Autoformat-1.12.tar.gz' ],
					[ 'DBD::Multiplex'	=> 'DBD-Multiplex-1.96.tar.gz' ],
					[ 'XML::RSS'			=> 'XML-RSS-1.05.tar.gz' ],
					[ 'XML::XPath'			=> 'XML-XPath-1.13.tar.gz' ],
					[ 'GD'					=> 'GD-2.19.tar.gz' ],
					[ 'GD::Text'			=> 'GDTextUtil-0.86.tar.gz' ],
					[ 'GD::Graph'			=> 'GDGraph-1.43.tar.gz' ],
					[ 'GD::Graph3d'		=> 'GD-Graph3d-0.63.tar.gz' ],
					[ 'AppConfig'			=> 'AppConfig-1.56.tar.gz' ],
					{m=>'Template', f=>'Template-Toolkit-2.14.tar.gz', precmd=>'/usr/bin/perl Makefile.PL TT_ACCEPT=y', makefile=>0 },
					[ 'Convert::ASN1'		=> 'Convert-ASN1-0.18.tar.gz' ],
					{m=>'Net::SSLeay', f=>'Net_SSLeay.pm-1.25.tar.gz', precmd=>'/usr/bin/perl Makefile.PL -- PREFIX=/opt/om/perllib LIB=/opt/om/perllib', makefile=>0},
					[ 'Authen::SASL'		=> 'Authen-SASL-2.08.tar.gz' ],
					[ 'IO::Socket::SSL'	=> 'IO-Socket-SSL-0.96.tar.gz' ],
					[ 'XML::SAX::Base'	=> 'XML-SAX-Base-1.02.tar.gz' ],
					{m=>'Net::LDAP', f=>'perl-ldap-0.3202.tar.gz', ver=>'0.32' },
					{m=>'Time::Zone', f=>'TimeDate-1.16.tar.gz' },
					[ 'MIME::Lite'			=> 'MIME-Lite-3.01.tar.gz' ],
					{m=>'Log::Dispatch', f=>'Log-Dispatch-2.10.tar.gz', precmd => '/usr/bin/perl Makefile.PL install_base=\'/opt/om/perllib\'', makefile => 0 },
					[ 'Log::Log4perl'		=> 'Log-Log4perl-0.51.tar.gz' ],
					[ 'SPOPS'				=> 'SPOPS-0.87.tar.gz' ],
					[ 'Apache::DB'			=> 'Apache-DB-0.09.tar.gz' ],
					[ 'Apache::Session'	=> 'Apache-Session-1.6.tar.gz' ],
					[ 'Apache::Test'		=> 'Apache-Test-1.20.tar.gz' ],
					],
			cpan_bundle_om_pkgs => [
					[ 'OpenInteract'		=> 'OpenInteract-1.62.tar.gz' ],
					],
			cpan_bundle_oi_inst_pkgs => [
					{m=>'OpenInteract', f=>'OpenInteract-1.62.tar.gz', maketest=>0 },
					],
			oisite_pkgs => [
					'oisite.tgz',
					],
			},

		@_,

		cwd					=> undef,
		cpan_pkg_versions	=> undef,
	};
	bless $this, $class;
	$this->init;
	$this;
}

sub init
{
	my $this = shift;
	
	$obj = $this;
	if (exists $ENV{MOD_PERL})
	{
		Apache->request->register_cleanup(\&end);
	}

	$this->checkphases;

	$this;
}

sub initrun
{
	my $this = shift;

	# work out settings
	if ( $this->{ask} ) # show defaults and ask user to confirm or enter new value
	{
		print boldhigh("Interactive ominstall run\n")."Please confirm defaults by pressing ENTER or type in the new value to use\n";
		for ( my $i = 0; $i < scalar @{$this->{default_settings}}; $i += 2 )
		{
			my $set = $this->{default_settings}->[$i];
			my $def = $this->{default_settings}->[$i+1];
			printf "%-15s [%-20s] : ", $set, $def;
			my $ask = <STDIN>;
			chomp $ask;
			if ( $ask )
			{
				$this->{settings}->{$set} = $ask;
			}
			else # apply default unless calling program set this value
			{
				$this->{settings}->{$set} = $def unless defined $this->{settings}->{$set};
			}
		}
		my $ask = "";
		while ( $ask ne "yes" )
		{
			print bold("Type yes to continue: ");
			$ask = <STDIN>;
			chomp $ask;
		}
	}
	else # apply defaults unless supplied by caller
	{
		for ( my $i = 0; $i < scalar @{$this->{default_settings}}; $i += 2 )
		{
			my $set = $this->{default_settings}->[$i];
			my $def = $this->{default_settings}->[$i+1];
			$this->{settings}->{$set} = $def unless defined $this->{settings}->{$set};
		}
	}
	# apply fixed settings
	for ( keys %{$this->{fixed_settings}} )
	{
		$this->{settings}->{$_} = $this->{fixed_settings}->{$_};
	}

	$this->{dbiargs} = { dsn => 'dbi:mysql:om', user => 'root', pass => $this->{settings}->{mysqlrootpw} };

	my $root = $this->{settings}->{installsrc} || confess;
	$this->{settings}->{cpan_root} = "$root/cpan";
	$this->{settings}->{rpm_root} = "$root/rpm";
	$this->{settings}->{aptrpm_root} = "$root/aptrpm";
	$this->{settings}->{src_root} = "$root/src";

	$this->{cwd} = getcwd();

	$ENV{SHELL} = '/bin/sh';

	my $perlprefix = $this->{settings}->{perlprefix};
	eval "use lib ( \"$perlprefix\" );" ;
	$ENV{PERLLIB} = "$perlprefix:$perlprefix/lib:$perlprefix/i386-linux-thread-multi:$perlprefix/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi:$perlprefix/lib/perl5/site_perl/5.8.0";

	mkpath ($perlprefix);
	mkpath ($this->{settings}->{work_root});

	my $checkpath = $this->{settings}->{installsrc}."/ominstall.pl";
	die "cannot find ominstall source [$checkpath]" unless -r $checkpath;

	$this->check_install_archivetar;
}

sub end { $obj = undef; }
END { end(); }

sub run
{
	my $this = shift;
	my $s = $this->{settings};

	unless ( $> == 0 )
	{
		die "you need to be logged in as root to run this program\n";
	}

	# unbuffered output
	$| = 1;

	my $phasefrom;
	my $phaseto;
	my $phase;
	my $command = '';
	GetOptions (
		help				=> sub { pod2usage(1); },
		man				=> sub { pod2usage(-exitstatus => 1, -verbose => 2); },
		debug				=> \$this->{debug},
		verbose			=> \$this->{verbose},
		timestamp		=> \$this->{timestamp},
		tarnoalternate	=> \$this->{tarnoalternate},
		taroverwrite	=> \$this->{taroverwrite},
		listphases		=> sub { $command = 'listphases'; },
		ask				=> \$this->{ask},
		'phase=s'		=> sub { $command = 'phase'; $phase = $_[1]; },
		'startphase=s'	=> sub { $command = 'runphasefromto'; $phasefrom = $_[1]; },
		'endphase=s'	=> sub { $command = 'runphasefromto'; $phaseto = $_[1]; },
		'site=s'			=> sub { $s->{site} = $_[1]; },
		#'omdatabase=s'	=> sub { $s->{omdatabase} = $_[1]; },
		)
		or exit(1);

	if ( $command eq 'listphases' )
	{
		$this->listphases;
	}
	elsif ( $command eq 'phase' )
	{
		$this->initrun;
		$this->runphase ($phase);
	}
	elsif ( $command eq 'runphasefromto' )
	{
		unless ( $phasefrom && $phaseto )
		{
			warn "You must supply both startphase and endphase if you want to run a series of phases\n";
			pod2usage(1);
		}
		$this->initrun;
		$this->runphasefromto ( $phasefrom, $phaseto );
	}
	else
	{
		pod2usage(1);
	}
}

### Logging

sub tstamp
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	sprintf("%04d/%02d/%02d-%02d:%02d:%02d ", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}
sub lprint { print tstamp() if $obj->{timestamp}; print @_; }
sub vprint { return unless $obj->{verbose}; print tstamp() if $obj->{timestamp}; print @_; }
sub dprint { return unless $obj->{debug}; print tstamp() if $obj->{timestamp}; print @_; }

### Phases

sub listphases
{
	my $this = shift;	
	print "Phases:\n" . join("\n", @{$this->{phases_ap}}) . "\n";
	print "\nOptional Phases:\n" . join("\n", @{$this->{optphases_ap}}) . "\n";
}

sub getphasenum
{
	my $this = shift;
	my $phase = shift || confess;
	my $i;
	for ( $i = $#{$this->{phases_ap}}; $i > -1; $i-- )
	{
		last if $this->{phases_ap}->[$i] eq $phase;
	}
	return $i unless $i == -1; # return if found
	for ( $i = $#{$this->{optphases_ap}}; $i > -1; $i-- )
	{
		last if $this->{optphases_ap}->[$i] eq $phase;
	}
	return (100 + $i) unless $i == -1; # return if found
	$i; # -1 = not found
}

sub checkphases
{
	my $this = shift;
	my @missing;
	for ( my $i = 0; $i <= $#{$this->{phases_ap}}; $i++ )
	{
		my $fn = "run_".$this->{phases_ap}->[$i];
		push @missing, $fn unless $this->can($fn);
	}
	confess "ERROR: Missing phase methods:\n".join("\n",@missing)."\n" if $#missing > -1;
}

sub runphase
{
	my $this = shift;
	my $phase = shift || confess;
	my $i = $this->getphasenum($phase);
	unless ( $i > -1 )
	{
		warn bold("Unknown phase: $phase\n");
		$this->listphases;
		return 0;
	}	
	lprint '++ '.boldhigh("Running phase [$i: $phase]\n");
	my $fn = "run_$phase";
	confess "ERROR: Missing method for phase: $phase" unless $this->can($fn);
	my $success= $this->$fn;
	lprint '++ ', ($success ? "Success" : "FAIL"), "\n";
	lprint "++ Ended phase $phase\n";
	1;
}

sub runphasefromto
{
	my $this = shift;
	my $phasefrom = shift || confess;
	my $phaseto = shift || confess;
	my $i = $this->getphasenum($phasefrom);
	unless ( $i > -1 )
	{
		warn bold("Unknown start phase: $phasefrom\n");
		$this->listphases;
		return 0;
	}
	my $j = $this->getphasenum($phaseto);
	unless ( $j > -1 )
	{
		warn bold("Unknown end phase: $phaseto\n");
		$this->listphases;
		return 0;
	}
	unless ( $i <= $j )
	{
		warn bold("The start phase must come before the end phase in the list\n");
		$this->listphases;
		return 0;
	}

	lprint '+++ '.boldhigh("Running phases from [$i: $phasefrom] to [$j: $phaseto]\n");
	my $success = 1;
	for ( my $k = $i; $success && $k <= $j; $k++ )
	{
		$success = 0 unless $this->runphase ( $this->{phases_ap}->[$k] );
	}
	lprint '+++ ', ($success ? "Success" : "FAIL"), "\n";
	lprint boldhigh("+++ Ended running phases from [$i: $phasefrom] to [$j: $phaseto]\n");
}

### Directory and unpack/install utilities

sub reset_cwd
{
	my $this = shift;
	confess "cwd not set" unless $this->{cwd};
	chdir ($this->{cwd}) || confess "Cannot chdir to $this->{cwd}: $!";
}

sub set_cwd
{
	my $this = shift;
	my $dir = shift || confess "set_cwd(): dir not set";
	chdir ($dir) || confess "Cannot chdir to $dir: $!";
}

sub exec_child
{
	my $this = shift;
	my %arg = (
		path			=> undef,
		wait			=> 1,
		verbose		=> 1,
		stdin			=> undef,
		stdintext	=> undef,
		stdout		=> undef,
		stderr		=> undef,
		append		=> 0,
		logcmd		=> 0,
		unsafe		=> 0,
		@_,
		);
	confess unless $arg{path};
	$arg{path} =~ s/^\s+//;
	lprint "cmd: $arg{path}\n" if $arg{verbose};
	my $prog = [ split ( /\s+/, $arg{path} ) ];
	$prog = $prog->[0];
	confess "cannot execute $prog" unless -x $prog || $arg{unsafe};
	my $app = $arg{append} ? ">>" : ">";
	$ENV{PATH} = '/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/root/bin';
	#$ENV{LANG} = 'en_US.UTF-8';
	#$ENV{LANG} = 'en_GB.UTF-8';
	# either pipe text to child
	if ( $arg{stdintext} )
	{
		local $SIG{PIPE} = 'IGNORE';
		local $| = 1;
		$ENV{PATH} = '/bin';
		if ( $arg{logcmd} && $arg{stdout} )
		{
			open(LOG, "$app$arg{stdout}") || confess;
			print LOG "cmd: $arg{path}\n";
			close(LOG);
		}
		my $stdout = $arg{stdout} ? "1$app$arg{stdout}" : '';
		my $stderr = $arg{stderr} ? "2$app$arg{stderr}" : '';
		open(CHILD, "| $arg{path} $stdout $stderr") || confess "cannot fork: $!";
		print CHILD $arg{stdintext} || confess "cannot write child: $!";
		close CHILD || warn "cannot close child: [$!] [$?]";
		return $? / 256;
	}
	# or run child using our I/O streams
	defined(my $pid = fork) or die 'cannot fork: ' . $!;
	if ($pid == 0) # child
	{
		open(STDIN,"< $arg{stdin}")||confess "$!" if $arg{stdin};
		open(STDOUT,"$app$arg{stdout}")||confess "$!" if $arg{stdout};
		open(STDERR,"$app$arg{stderr}")||confess "$!" if $arg{stderr};
		local $| = 1;
		print STDOUT "cmd: $arg{path}\n" if $arg{stdout} && $arg{logcmd};
		vprint "+ Running $prog\n";
		exec($arg{path}) || die "+   ERROR cannot execute program $prog: $!";
	}
	# parent
	return $pid unless $arg{wait};
	waitpid($pid,0);
	return $? / 256; # hi byte is exit status
}

sub check_install_archivetar
{
	my $this = shift;
	my $rc;
	my $s = $this->{settings};
	my $inst = eval "require Archive::Tar";
	return if $inst;
	lprint "Archive::Tar not installed - attempting to install\n";
	for ( @{$s->{archivetar_pkgs}} )
	{
		$this->install_cpan ( archive => $s->{cpan_root}.'/'.$_, maketest => 0 );
	}
	eval "require Archive::Tar"
		or confess "Failed to require Archive::Tar after installation";
}

sub untar
{
	my $this = shift;
	my %arg = (
		archive		=> undef,
		targetroot	=> undef,
		overwrite	=> $this->{taroverwrite},
		alternate	=> (! $this->{tarnoalternate}),
		fatal			=> 1,
		verbose		=> $this->{verbose},
		@_,
		);
	confess unless $arg{archive} && $arg{targetroot};
	$this->set_cwd ($arg{targetroot});
	my $verbose = $arg{verbose} ? 'v' : '';
	my $rc = $this->exec_child ( path => "/bin/tar x${verbose}fz ".$arg{archive}, stdin => $arg{stdin}, stdout => $arg{stdout}, stderr => $arg{stderr}, append => $arg{append}  );
	($rc == 0) || die "could not unpack archive $arg{archive}";
	$this->reset_cwd;
	1;	
}

sub softuntar
{
	my $this = shift;
	my %arg = (
		archive		=> undef,
		targetroot	=> undef,
		overwrite	=> $this->{taroverwrite},
		alternate	=> (! $this->{tarnoalternate}),
		fatal			=> 1,
		returnlist	=> 0,
		template_fields_hp => undef,
		@_,
		);
	confess unless $arg{archive} && $arg{targetroot};

	$this->set_cwd ($arg{targetroot});
	my $tar = Archive::Tar->new;
	$tar->read ( $arg{archive}, 1 )
		or $arg{fatal} ? confess "Cannot untar archive: $arg{archive}: $!" : return 0;
	my @files = $tar->list_files;
	for my $file (@files)
	{
		if ( ! -r $file || ($arg{overwrite} && -f $file) )
		{
			vprint " writing $file ";
			$tar->extract_file ($file);
			if ( $arg{template_fields_hp} )
			{
				$this->template_replace ( infilepath => $file, outfilepath => $file, fields_hp => $arg{template_fields_hp} );
				vprint "from template";
			}
			print "\n";
		}
		elsif ( ! -f $file )
		{
			# skip existing directories
		}
		elsif ( $arg{alternate} )
		{
			my $alt = $file . '.om';
			if ( -r $alt )
			{
				vprint " skipping existing alternate file $alt\n";
			}
			else
			{
				vprint " found $file writing alternate $alt ";
				$tar->extract_file ($file, $alt);
				if ( $arg{template_fields_hp} )
				{
					$this->template_replace ( infilepath => $alt, outfilepath => $alt, fields_hp => $arg{template_fields_hp} );
					vprint "from template";
				}
				print "\n";
			}
		}
		else
		{
			vprint " skipping existing file $file\n";
		}
	}
	$this->reset_cwd;
	return $arg{returnlist} ? \@files : 1;
	1;	
}

sub install_rpm
{
	my $this = shift;
	my %arg = (
		archive_root	=> $this->{settings}->{rpm_root},
		archives_ap		=> undef,
		force				=> 0,
		@_,
	);

	my $rpmroot = $arg{archive_root} || confess;
	confess unless $arg{archives_ap};

	# check versions and only install where necessary
	my @rpms;
	for my $pkg ( @{$arg{archives_ap}} )
	{
		confess "$rpmroot/$pkg not found" unless -r "$rpmroot/$pkg";
		if ( $arg{force} )
		{
			push @rpms, $pkg;
			next;
		}
		my ($name,$ver) = split(/\s+/,`/bin/rpm -q --qf '%{NAME} %{VERSION}' -p $rpmroot/$pkg 2>/dev/null`);
		confess unless $name && defined $ver;
		$ver =~ s/[[:alpha:]](.)*$//;
		my $instver = `/bin/rpm --qf '%{VERSION}' -q $name`;
		if ( $instver =~ m/not installed/ )
		{
			vprint " install $pkg ($name $ver)\n";
			push @rpms, $pkg;
		}
		else
		{
			$instver =~ s/[[:alpha:]](.)*$//;
			my @v1 = split(/\./,$ver);
			$v1[1] ||= 0;
			$v1[2] ||= 0;
			my @v2 = split(/\./,$instver);
			$v2[1] ||= 0;
			$v2[2] ||= 0;
			my $nver 		= $v1[0]*10000 + $v1[1]*100 + $v1[2];
			my $ninstver	= $v2[0]*10000 + $v2[1]*100 + $v2[2];
			if ($ninstver >= $nver) # already up to date
			{
				vprint " skip $name-$instver already installed\n";
				next;
			}
			vprint " upgrade $pkg ($name $ver)\n";
			push @rpms, $pkg;
		}
	}
	return 1 unless $#rpms > -1;
	my $cmd = '/bin/rpm -Uvh ' . $rpmroot.'/' . join(" $rpmroot/",@rpms);
	$this->exec_child ( path => $cmd ) == 0 or $arg{fatal} ? die "could not run: $cmd" : return undef;
	1;
}

sub install_cpan
{
	my $this = shift;
	my $s = $this->{settings};
	my %arg = (
		module		=> undef, # module to test version against
		archive		=> undef, # filename should end in .tar.gz or .tgz
		chkcmd		=> undef, # optional command to run to see if a module should be installed
		precmd		=> undef, # optional preparatory command, e.g. if something other than perl Makefile.PL required
		makefile		=> 1,	# run perl Makefile.PL
		make			=> 1, # run make
		maketest		=> 1, # run make test
		makeinstall	=> 1, # run make install
		prefix		=> $s->{perlprefix},
		force			=> 0, # ignore errors and force re-install even if already installed
		stdin			=> '/dev/null',
		stdintext	=> undef, # optional text to pass as input to make install
		stdout		=> undef, # defaults to terminal, can pass filename to write STDOUT to
		stderr		=> undef, # defaults to terminal, can pass filename to write STDERR to
		append		=> 1, # append rather than overwrite when writing STDOUT to file
		ver			=> undef,
		@_,
	);
	confess unless $arg{archive};
	my $name = [ split(/\//,$arg{archive}) ]->[-1];
	vprint "install_cpan: $name, ";

	my $pkg = $arg{module};
	unless ($pkg)
	{
		($pkg = $name) =~ s/^((.)*?)-[0-9].*$/$1/;
		$pkg =~ s/-/\:\:/;
	}
	(my $ver = $name) =~ s/.*?-([0-9](.)*).tar.gz$/$1/;
	$ver = cpanversion::modulenametoversion ( $name );
	$ver = $arg{ver} if $arg{ver};
	my $instver = cpanversion::getmoduleversion ( $pkg );
	my $action;
	#print "ver: $ver, instver: $instver\n";
	if ( $instver && $instver * 1.0 >= $ver * 1.0 )
	{
		$action = $arg{force} ? "install" : "skip";
	}
	elsif ( $instver )
	{
		$action = "upgrade";
	}
	else
	{
		$action = "install";
	}

	# optional check command to run to see if CPAN package installed, should return 0 if it is or <>0 if not
	if ( $arg{chkcmd} )
	{
		my $rc = $this->exec_child ( path => $arg{chkcmd}, stdout => '/dev/null', stderr => '/dev/null' );
		$action = "skip" if $rc == 0;
	}

	if ( $action eq "skip" )
	{
		vprint "skipped, have version $instver\n";
		return;
	}
	vprint ($action eq "upgrade" ? "upgrading, have version $instver\n" : "installing\n");

	die "Cannot find: $arg{archive}" unless -r $arg{archive};
	$this->set_cwd ($s->{work_root});
	my $rc;
	$rc = $this->exec_child ( path => '/bin/tar xfz '.$arg{archive}, stdin => $arg{stdin}, stdout => $arg{stdout}, stderr => $arg{stderr}, append => $arg{append} );
	($rc == 0) || die "could not unpack archive $arg{archive}";
	(my $subdir = $name) =~ s/.tar.gz$//;
	$subdir =~ s/.tgz$//;
	$subdir =~ s/(-[0-9\.]+)-[0-9\.]+/$1/;
	$this->set_cwd ( $subdir );
	if ( $arg{precmd} )
	{
		$rc = $this->exec_child ( path => $arg{precmd}, stdin => $arg{stdin}, stdout => $arg{stdout}, stderr => $arg{stderr}, append => $arg{append});
		($rc == 0) || die "could not run precmd";
	}
	if ( $arg{makefile} )
	{
		my $prefix = $arg{prefix} ? "PREFIX=$arg{prefix} LIB=$arg{prefix}" : '';
		$rc = $this->exec_child ( path => "/usr/bin/perl Makefile.PL $prefix", stdin => $arg{stdin}, stdout => $arg{stdout}, stderr => $arg{stderr}, append => $arg{append} );
		($rc == 0) || die "could not make Makefile.PL";
	}
	if ( $arg{make} && !$arg{force} )
	{
		$rc = $this->exec_child ( path => '/usr/bin/make', stdin => $arg{stdin}, stdout => $arg{stdout}, stderr => $arg{stderr}, append => $arg{append});
		($rc == 0) || die "could not make";
	}
	if ( $arg{maketest} && !$arg{force} )
	{
		$rc = $this->exec_child ( path => '/usr/bin/make test', stdin => $arg{stdin}, stdout => $arg{stdout}, stderr => $arg{stderr}, append => $arg{append});
		($rc == 0) || die "could not make test";	
	}
	if ( $arg{makeinstall} || $arg{force} )
	{
		$rc = $this->exec_child ( path => '/usr/bin/make install', stdin => $arg{stdin}, stdout => $arg{stdout}, stderr => $arg{stderr}, append => $arg{append}, stdintext => $arg{stdintext});
		($rc == 0) || die "could not make install";
	}
	$this->reset_cwd;
	1;
}

sub install_cpan_set
{
	my $this = shift;
	my %arg = (
		set		=> undef,
		pause		=> 0,
		logfile	=> undef,
		@_,
		);
	my $s = $this->{settings};
	confess unless $arg{set};

	for my $p ( @{$arg{set}} )
	{
		my ($mod, $file);
		my %flags = (
			chkcmd		=> '',
			precmd		=> '',
			makefile		=> 1,
			make			=> 0,
			maketest		=> 0,
			makeinstall	=> 1,
			force			=> 0,
			stdin			=> '/dev/null',
			stdintext	=> undef,
			stdout		=> $arg{logfile},
			stderr		=> $arg{logfile},
			append		=> 1,
			ver			=> '',
			);
		if ( ref($p) eq 'ARRAY' ) # module name, package file name
		{
			$mod = $p->[0];
			$file = $p->[1];
		}
		elsif ( ref($p) eq 'HASH' ) # m=module name, f=package file, rest passed to install_cpan()
		{
			$mod = $p->{m};
			$file = $p->{f};
			for ( keys %$p )
			{
				next if $_ eq "m" || $_ eq "f";
				$flags{$_} = $p->{$_} if defined $flags{$_};
				warn "$mod: unexpected flag: $_\n" unless defined $flags{$_};
			}
		}
		$this->install_cpan (
			%flags,
			module	=> $mod,
			archive	=> $s->{cpan_root}.'/'.$file,
			);
		if ( $arg{pause} )
		{
			lprint "Press RETURN to continue\n";
			<STDIN>;
		}
	}
}

sub exec_mysql
{
	my $this = shift;
	my $s = $this->{settings};
	my %arg = (
		sql		=> undef,
		flags		=> '',
		@_,
		);
	confess unless $arg{sql};
	my $user = 'root';
	my $pw = $s->{mysqlrootpw};
	my $cmd = ($s->{mysql}||die "mysql path not set")." -u$user -p$pw $arg{flags}";
	my $rc = $this->exec_child ( path => $cmd, stdintext => $arg{sql} );
	($rc == 0) || warn "could not run sql:\n$arg{sql}";
	($rc == 0);
}

sub add_unix_user
{
	my $this = shift;
	my $s = $this->{settings};
	my %arg = (
		user		=> undef,
		group		=> undef,
		pw			=> undef,
		home		=> undef,
		uid		=> undef,
		gid		=> undef,
		@_,
		);
	for ( keys %arg )
	{
		confess unless defined $arg{$_};
	}

	# add user and group if not already there
	my $need_chown = 0;
	if ( ! defined getgrnam($arg{group}) )
	{
		my $cmdgid = defined getgrgid($arg{gid}) ? "" : "-g $arg{gid}";
		my $cmd = "/usr/sbin/groupadd -g $arg{gid} $arg{group}";
		lprint "add group: $cmd\n";
		$this->exec_child (path => $cmd) == 0 || die "could not groupadd: $cmd";
	}
	$arg{gid} = getgrnam($arg{group});
	confess unless defined $arg{gid};
	if ( ! defined getpwnam($arg{user}) )
	{
		my $cmduid = defined getpwuid($arg{uid}) ? "" : "-u $arg{uid}";
		my $cmd = "/usr/sbin/useradd $cmduid -d $arg{home} -g $arg{group} -p $arg{pw} $arg{user}";
		lprint "add user : $cmd\n";
		$this->exec_child (path => $cmd) == 0 || die "could not useradd: $cmd";
		# rather than use -p password which can be seen with 'ps' could run separately
		#    echo "$PASSWORD" | /usr/bin/passwd --stdin "$USERNAME"
	}
	$arg{uid} = getpwnam($arg{user});
	confess unless defined $arg{uid};

	# add to /etc/sudoers so can restart mod_perl service
	my $sudofile = "/etc/sudoers";
	my $ap = $this->read_into_array ( file => $sudofile ) || confess "cannot read $sudofile: $!";
	if ( grep {/\/sbin\/service/} grep {/^$arg{user}\s/} @$ap )
	{
		lprint "already in $sudofile\n";
	}
	else
	{
		lprint "adding to $sudofile\n";
		push @$ap, "$arg{user} ALL = NOPASSWD: /sbin/service";
		$this->write_from_array ( file => $sudofile, arrayptr => $ap ) || confess "cannot write $sudofile: $!";
	}

	# untar files to home directory if needed
	my $homepkg = $s->{"$arg{user}home_pkg"};
	if ( $homepkg )
	{
		# ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire)
		my $homedir = [ getpwnam($arg{user}) ]->[7] || confess;
		lprint "unpacking $arg{user} home archive to $homedir\n";
		my $archive = $s->{src_root}.'/'.$homepkg;
		$this->softuntar ( archive => $archive, targetroot => "$homedir/", alternate => 1, template_fields_hp => $s );
	}

	1;
}

### Run methods for each phase

sub run_userroot
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Unpacking root archive\n");
	my $archive = $s->{src_root}.'/'.$s->{root_pkg};
	$this->softuntar ( archive => $archive, targetroot => '/root', template_fields_hp => $s );
}

sub run_userom
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Configure user om\n");
	$this->add_unix_user ( user => $s->{omuser}, group => $s->{omgroup}, pw => $s->{ompw},
		home => $s->{omhome}, uid => $s->{omuid}, gid => $s->{omgid} );
}

sub run_network
{
	my $this = shift;
	my $s = $this->{settings};
	my $hostname	= $s->{hostname} || confess;
	my $domain		= $s->{domain} || confess;
	my $ipaddr		= $s->{ipaddr} || confess;
	my $network		= $s->{network} || confess;
	my $subnet		= $s->{subnet} || confess;
	my $netmask		= $s->{netmask} || confess;
	my $broadcast	= $s->{broadcast} || confess;
	my $gateway		= $s->{gateway} || confess;

	lprint bold("Configure network\n");

=head1
	lprint "IP forwarding\n";
	# check /etc/sysctl.conf and turn on IP forwarding if necessary
	my $sysfile = '/etc/sysctl.conf';
	my $ap = $this->read_into_array ( file => $sysfile, fatal => 1 );
	if ( grep {/^net.ipv4.ip_forward = 1/} @$ap )
	{
		lprint "already on\n";
	}
	else
	{
		map ( s/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/, @$ap );
		#$this->write_from_array ( file => $sysfile, arrayptr => $ap, fatal => 1 );
		#my cmd = '/sbin/sysctl -w net.ipv4.conf.eth0.forwarding=1';
		#$this->exec_child (path => $cmd) == 0 || die "could not run: $cmd";
	}

=cut

	lprint "Default route to gateway\n";
	my @a = grep {/^default/} `/sbin/route`;
	if ( $#a > -1 )
	{
		@a = split(/\s+/,$a[0]);
		$gateway = $a[1];
		lprint "already set to: $gateway\n";
	}
	else
	{
		my $gateway = $s->{gateway} || confess;
		my $cmd = "/sbin/route add default gw $gateway";
		$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";
	}

	lprint "TCP wrappers\n";
	my $tcpallow = '/etc/hosts.allow';
	my $ap = $this->read_into_array ( file => $tcpallow, fatal => 1 );
	if ( grep {/^ALL: $subnet/} @$ap )
	{
		lprint "$tcpallow already configured\n";
	}	
	else
	{
		push @$ap, "ALL: $subnet";
		$this->write_from_array ( file => $tcpallow, arrayptr => $ap, fatal => 1 );
		lprint "$tcpallow updated\n";
	}
	my $tcpdeny = '/etc/hosts.deny';
	$ap = $this->read_into_array ( file => $tcpdeny, fatal => 1 );
	if ( grep {/^ALL: ALL/} @$ap )
	{
		lprint "$tcpdeny already configured\n";
	}	
	else
	{
		push @$ap, "ALL: ALL";
		$this->write_from_array ( file => $tcpdeny, arrayptr => $ap, fatal => 1 );
		lprint "$tcpdeny updated\n";
	}
	my $cmd = "/sbin/service xinetd reload";
	$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";

	# iptables - should have been set up at install time
	lprint "IP Tables\n";
	my $iptables = '/etc/sysconfig/iptables';
	$ap = $this->read_into_array ( file => $iptables, fatal => 1 );
	if ( grep {/--dport 22 -j ACCEPT/} @$ap )
	{
		lprint "$iptables already configured\n";
	}
	else
	{
		my $iptable = <<EOF ;
	# Firewall configuration written by redhat-config-securitylevel
	# Manual customization of this file is not recommended.
	*filter
	:INPUT ACCEPT [0:0]
	:FORWARD ACCEPT [0:0]
	:OUTPUT ACCEPT [0:0]
	:RH-Firewall-1-INPUT - [0:0]
	-A INPUT -j RH-Firewall-1-INPUT
	-A FORWARD -j RH-Firewall-1-INPUT
	-A RH-Firewall-1-INPUT -i lo -j ACCEPT
	-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j ACCEPT
	-A RH-Firewall-1-INPUT -p 50 -j ACCEPT
	-A RH-Firewall-1-INPUT -p 51 -j ACCEPT
	-A RH-Firewall-1-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
	-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
	-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
	-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 137:139 -j ACCEPT
	-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited
	COMMIT
EOF
		lprint "$iptables should have been set at install time\n";
		lprint "here is a sample that allows ssh, http, https and Samba file sharing\n";
		print "$iptable\n";
	}

	# network
	my $netfn = '/etc/sysconfig/network';
	if ( -r "$netfn.orig" )
	{
		lprint "$netfn already configured\n";
	}
	else
	{
		$this->backup_file ( file => "$netfn" );
		my $content = <<EOF ;
NETWORKING=yes
HOSTNAME=$hostname
GATEWAY=$gateway
EOF
		$this->write_file ( file => $netfn, content => $content );
		lprint "$netfn updated\n";
	}
	# ifcfg-eth0
	my $ethfn = '/etc/sysconfig/network-scripts/ifcfg-eth0';
	if ( -r "$ethfn.orig" )
	{
		lprint "$ethfn already configured\n";
	}
	else
	{
		$this->backup_file ( file => "$ethfn" );
		my $content = <<EOF ;
DEVICE=eth0
BOOTPROTO=static
BROADCAST=$broadcast
IPADDR=$ipaddr
NETMASK=$netmask
NETWORK=$network
ONBOOT=yes
TYPE=Ethernet
EOF
		$this->write_file ( file => $ethfn, content => $content );
		lprint "$ethfn updated\n";
	}
	# /etc/hosts
	my $hostfn = '/etc/hosts';
	$ap = $this->read_into_array ( file => $hostfn, fatal => 1 );
	my $foundhost = 0;
	for ( my $i = 0; $i <= $#{$ap}; $i++ )
	{
		$ap->[$i] = '127.0.0.1 localhost.localdomain localhost' if $ap->[$i] =~ m/^127.0.0.1/;
		$foundhost = 1 if $ap->[$i] =~ m/\s$hostname\s/;
	}
	if ( $foundhost )
	{
		lprint "$hostfn already configured\n";
	}
	else
	{
		push @$ap, "$ipaddr    $hostname ${hostname}.${domain}";
		$this->backup_file ( file => "$hostfn" );
		$this->write_from_array ( file => $hostfn, arrayptr => $ap, fatal => 1 );
		lprint "$hostfn updated\n";
		
		lprint "setting hostname and domainname\n";
		my $cmd = "/bin/hostname $hostname";
		lprint " $cmd\n";
		$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";
		$cmd = "/bin/domainname $domain";
		lprint " $cmd\n";
		$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";	
	}		

	# ifconfig
	$cmd = "/sbin/ifconfig eth0 $ipaddr netmask $netmask broadcast $broadcast";
	lprint "change IP settings\n $cmd\n";
	$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";		

	1;
}

sub run_rpm
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Installing RPMS\n");
	for my $pkg ( @{$s->{rpm_pkgs}} )
	{
		$this->install_rpm ( archive_root => $s->{rpm_root}, archives_ap => [ $pkg ] );
	}

	1;
}

sub run_aptnet
{
	my $this = shift;
	my $s = $this->{settings};

	lprint bold("Updating apt packages from network\n");
	my $cmd = '/usr/bin/apt-get update';
	$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";
	$cmd = '/usr/bin/apt-get upgrade -y';
	$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";
	$cmd = '/usr/bin/apt-get install synaptic';
	$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";
}

sub run_aptlocalrhel3
{
	my $this = shift;
	my $s = $this->{settings};

	lprint bold("Installing APT RHEL3 RPMS\n");
	$this->install_rpm ( archive_root => $s->{aptrpm_root}, archives_ap => $s->{aptrpm_pkgs} );
	1;
}

sub run_mysql
{
	my $this = shift;
	my $s = $this->{settings};

	lprint bold("Installing mysql RPMS\n");
	$this->install_rpm ( archives_ap => $s->{rpm_mysql_pkgs} );
	lprint "Configuring /etc/my.cnf\n";
	my $myfn = '/etc/my.cnf';
	my $ap = $this->read_into_array ( file => $myfn, fatal => 1 );
	if ( grep {/^old-passwords/} @$ap )
	{
		lprint "already done\n";
	}
	else
	{
		confess "missing [mysqld] section" unless grep {/^\[mysqld\]/} @$ap;
		for ( my $i = 0; $i <= $#{$ap}; $i++ )
		{
			if ( $ap->[$i] =~ m/^\[mysqld\]/ )
			{
				# old-passwords needed to make phpmyadmin client work through mysql 3.23 compatibility
				splice ( @$ap, ($i+1), 0, 'old-passwords' );
				last;
			}
		}
		$this->backup_file ( file => "$myfn" );
		$this->write_from_array ( file => $myfn, arrayptr => $ap, fatal => 1 );
		lprint "$myfn updated\n";
	}
	my $hostname = $s->{hostname} || confess;
	my $cmd = "/sbin/service mysql restart";

	lprint "Configure users\n";
	# set mysql root password
	my $myrootpw = $s->{mysqlrootpw};
	confess unless defined $myrootpw;
	$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";	
	sleep(2);
	lprint " root\n";
	$cmd = "/usr/bin/mysqladmin -u root old-password '$myrootpw'";
	$this->exec_child ( path => $cmd ) == 0 || warn "could not set mysql root password";	
	#
	my $user = $s->{mysqlomuser} || confess;
	my $pw = $s->{mysqlompw} || warn "no mysql $user password set";
	lprint " $user\n";
	my $sql = <<EOF ;
GRANT ALL PRIVILEGES ON *.* TO root\@localhost IDENTIFIED BY '$myrootpw' WITH GRANT OPTION;
GRANT Select,Insert,Update,Delete,Create,Drop,References,Index,Alter,File ON *.* TO '$user'\@localhost IDENTIFIED BY '$pw';
GRANT Select,Insert,Update,Delete,Create,Drop,References,Index,Alter,File ON *.* TO '$user'\@'%' IDENTIFIED BY '$pw';
EOF
	$this->exec_mysql ( sql => $sql ) || warn "could not create mysql users";

	#recompile perl DBD::mysql using version 2.9003
	# perl -MCPAN -e 'force install Bundle::DBD::mysql'
	# module						RHEL3 U4 version
	#	DBI  						1.32
	#	Data::ShowTable		none
	#	Mysql  					1.2401
	#	DBD::mysql  			2.1021
	my $lang = $ENV{LANG};
	$ENV{LANG} = 'C';
	$this->install_cpan_set ( set => $s->{cpan_bundle_dbd_mysql_pkgs}, pause => 0, maketest => 0 );
	$ENV{LANG} = $lang;
	1;
}

sub run_phpmyadmin
{
	my $this = shift;
	my $s = $this->{settings};
	my $rc;
	lprint bold("Installing phpMyAdmin... ");
	if ( -r '/usr/local/phpmyadmin' )
	{
		lprint "already installed\n";
	}
	else
	{
		lprint "\n";
		my $archive = $s->{src_root}.'/'.$s->{phpmyadmin_pkg};
		$this->untar ( archive => $archive, targetroot => '/usr/local', overwrite => 1 );
		(my $subdir = $s->{phpmyadmin_pkg}) =~ s/.tar.gz$//;
		$subdir =~ s/.tgz$//;
		my $pmadir = '/usr/local/' . $subdir;
		symlink ($pmadir, '/usr/local/phpmyadmin') || warn "Cannot create symbolic link from $pmadir: $!";
	}

	my $conf = '/usr/local/phpmyadmin/config.inc.php';
	lprint " editing $conf\n";
	my $ap = $this->read_into_array ( file => $conf ) || confess "cannot read $conf: $!";
	for ( @$ap )
	{
		s/^\$cfg\[\'PmaAbsoluteUri\'\].*/\$cfg\['PmaAbsoluteUri'\] = 'https:\/\/'.$s->{hostname}.'\/phpmyadmin\/';/ ;
		s/^\$cfg\[\'PmaAbsoluteUri_DisableWarning.*/\$cfg\['PmaAbsoluteUri_DisableWarning'\] = TRUE;/ ;
		s/^\$cfg\[\'Servers\'\]\[\$i\]\[\'password\'\].*/\$cfg\[\'Servers\'\]\[\$i\]\[\'password\'\]      = \'$s->{mysqlrootpw}\';/ ;
		s/^\$cfg\[\'Servers\'\]\[\$i\]\[\'verbose\'\].*/\$cfg\[\'Servers\'\]\[\$i\]\[\'verbose\'\]       = \'$s->{hostname}\';/ ;
	}
	$this->backup_file ( file => "$conf" );
	$this->write_from_array ( file => $conf, arrayptr => $ap ) || confess "cannot write $conf: $!";

	lprint "creating web security\n";
	my $htpfn = '/usr/local/.htpasswd';
	if ( -r $htpfn )
	{
		lprint " $htpfn already set\n";
	}
	else
	{
		lprint " creating $htpfn\n";
		my $cmd = "/usr/bin/htpasswd -cb $htpfn $s->{omuser} '$s->{phpmyadminwebpw}'";
		$this->exec_child ( path => $cmd ) == 0 || warn "could not set phpmyadmin web password";
	}
	my $htafn = '/usr/local/phpmyadmin/.htaccess';
	if ( -r $htafn )
	{
		lprint " $htafn already set\n";
	}
	else
	{
		my $content = <<EOF ;
AuthUserFile $htpfn
AuthGroupFile /dev/null
AuthName Security
AuthType Basic

<Limit GET POST PUT>
require valid-user
</Limit>
EOF
		$this->write_file ( file => $htafn, content => $content );
		lprint " $htafn created\n";
	}

	my $httpconf = '/etc/httpd/conf/httpd.conf';
	lprint "configuring $httpconf... ";
	my $content = $this->read_file ( file => $httpconf ) || confess "cannot read $httpconf: $!";
	if ( $content =~ m/Alias \/phpmyadmin\// )
	{
		lprint "already added\n";
	}
	else
	{
		$content .= <<EOF ;
Alias /phpmyadmin/ "/usr/local/phpmyadmin/"
<Directory "/usr/local/phpmyadmin">
   Order deny,allow
   Deny from all
   Allow from $s->{subnet} 127.0.0.1 localhost
   Options Indexes MultiViews
   AllowOverride AuthConfig
</Directory>
EOF
		$this->backup_file ( file => $httpconf );
		$this->write_file ( file => $httpconf, content => $content );
		lprint "added\n";
	}
	
	my $cmd = "/sbin/service httpd restart";
	$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";

	1;
}

sub run_apachessl
{
	my $this = shift;
	lprint bold("Configure apache SSL");
	my $ssldir = '/etc/httpd/conf/om';
	mkpath($ssldir);
	$this->set_cwd ( $ssldir );
	my $cmd = '/usr/bin/openssl req -new -passin pass:dummy -passout pass:dummy > om.cert.csr';
	my $stdintext = "GB\nBucks\nMilton Keynes\nMyCompany Ltd\nSoftware\nserver1\nroot\@server1\n\nPeter\n";
	my $rc = $this->exec_child ( path => $cmd, stdintext => $stdintext );
	($rc == 0) || die "could not make csr";
	$cmd = '/usr/bin/openssl rsa -in privkey.pem -out om.cert.key -passin pass:dummy';
	$rc = $this->exec_child ( path => $cmd );# stdintext => "dummy\n" );
	$cmd = '/usr/bin/openssl x509 -in om.cert.csr -out om.cert.crt -req -signkey om.cert.key -days 3650';
	$rc = $this->exec_child ( path => $cmd );
	#$cmd = '/bin/cp om.cert.key /etc/httpd/conf/ssl.key/server.key';
	#$rc = $this->exec_child ( path => $cmd );
	#$cmd = '/bin/cp om.cert.crt /etc/httpd/conf/ssl.crt/server.crt';
	#$rc = $this->exec_child ( path => $cmd );

	# disable SSL support in RedHat apache server by renaming ssl.conf
	my $rh_sslconf = '/etc/httpd/conf.d/ssl.conf';
	if ( -r $rh_sslconf )
	{
		lprint "Disabling SSL in RedHat apache by renaming $rh_sslconf to $rh_sslconf.orig\n";
		rename $rh_sslconf, $rh_sslconf . ".orig";
		my $cmd = "/sbin/service httpd restart";
		$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";
	}

	1;
}

sub run_buildapacheproxy
{
	my $this = shift;
	my $s = $this->{settings};
	my ($rc, $cmd);
	lprint bold("Building apache proxy\n");
	my $aproot = $s->{apache_root} || confess;
	if ( -r $aproot )
	{
		lprint " $aproot already installed\n";
		return 1;
	}
	my $logfile = $this->{verbose} ? undef : $s->{work_root}.'/buildapacheproxy.log';
	unlink($logfile) if $logfile;

	lprint " unpacking apache source\n";
	my $aparchive = $s->{src_root}.'/'.$s->{apache_pkg};
	$this->untar ( archive => $aparchive, targetroot => $s->{work_root}, stdout => '/dev/null' );

	lprint " unpacking mod_ssl source\n";
	(my $apsubdir = $s->{apache_pkg}) =~ s/.tar.gz$//;
	my $modsslarch = $s->{src_root}.'/'.$s->{modssl_pkg};
	$this->untar ( archive => $modsslarch, targetroot => $s->{work_root}, stdout => '/dev/null' );
	(my $modsslsubdir = $s->{modssl_pkg}) =~ s/.tar.gz$//;

	lprint " configuring mod_ssl\n";
	$this->set_cwd ( $s->{work_root}.'/'.$modsslsubdir );
	$rc = $this->exec_child ( stdout => $logfile, logcmd => 1, append => 1, path => <<EOF );
	 /bin/sh ./configure \\
		--with-apache=../$apsubdir \\
		--prefix=$aproot \\
		--with-ssl \\
		--with-crt=/etc/httpd/conf/om/om.cert.crt \\
		--with-key=/etc/httpd/conf/om/om.cert.key \\
		--enable-module=ssl \\
		--enable-shared=ssl \\
EOF
	($rc == 0) || die "could not configure mod_ssl\n";

	lprint " configuring apache\n";
	$this->set_cwd ( $s->{work_root}.'/'.$apsubdir );
	# RHEL3 has ssl headers under /usr/kerberos/include so add to INCLUDES
	chomp ($main::ENV{INCLUDES} = `/usr/bin/pkg-config --cflags-only-I openssl`);
	$rc = $this->exec_child ( stdout => $logfile, logcmd => 1, append => 1, path => <<EOF );
	 /bin/sh ./configure \\
		--prefix=$aproot \\
		--enable-module=ssl \\
		--enable-shared=ssl \\
		--enable-module=rewrite \\
		--enable-module=proxy \\
EOF
	($rc == 0) || die "could not configure apache\n";

	lprint " making apache proxy\n";
	$rc = $this->exec_child ( stdout => $logfile, logcmd => 1, append => 1, path => "/usr/bin/make install" );
	($rc == 0) || die "could not make apache\n";

	$this->reset_cwd;

	1;
}

sub run_buildapachemodperl
{
	my $this = shift;
	my $s = $this->{settings};
	my ($rc, $cmd);
	lprint bold("Building apache mod_perl\n");
	my $aproot = $s->{apache_root} || confess;
	if ( ! -r $aproot )
	{
		die " need to install apache proxy first to $aproot\n";
	}
	if ( -r $aproot."/bin/httpdom" )
	{
		lprint " $aproot/bin/httpdom already built\n";
		return 1;
	}
	my $logfile = $this->{verbose} ? undef : $s->{work_root}.'/buildapachemodperl.log';
	unlink($logfile) if $logfile;

	lprint " unpacking apache source\n";
	my $aparchive = $s->{src_root}.'/'.$s->{apache_pkg};
	$this->untar ( archive => $aparchive, targetroot => $s->{work_root}, stdout => '/dev/null' );
	(my $apsubdir = $s->{apache_pkg}) =~ s/.tar.gz$//;

	lprint " unpacking mod_perl source\n";
	my $mparchive = $s->{src_root}.'/'.$s->{modperl_pkg};
	$this->untar ( archive => $mparchive, targetroot => $s->{work_root}, stdout => '/dev/null' );
	(my $mpsubdir = $s->{modperl_pkg}) =~ s/.tar.gz$//;

	lprint " configuring mod_perl\n";
	$this->set_cwd ( $s->{work_root}.'/'.$mpsubdir );
	$rc = $this->exec_child ( stdout => $logfile, logcmd => 1, append => 1, path => "/usr/bin/perl Makefile.PL EVERYTHING=1 APACHE_SRC=../$apsubdir/src USE_APACI=1 PREP_HTTPD=1 DO_HTTPD=1" );

	lprint " installing mod_perl\n";
	$rc = $this->exec_child ( stdout => $logfile, logcmd => 1, append => 1, path => "/usr/bin/make install" );
	($rc == 0) || die "could not make apache\n";

	lprint " configuring apache\n";
	$this->set_cwd ( $s->{work_root}.'/'.$apsubdir );
	$rc = $this->exec_child ( stdout => $logfile, logcmd => 1, append => 1, path => "/bin/sh ./configure \\
	--prefix=$aproot \\
	--target=httpdom \\
	--enable-module=rewrite \\
	--activate-module=src/modules/perl/libperl.a \\
	--enable-module=perl" );
	($rc == 0) || die "could not configure apache\n";

	lprint " making apache mod_perl\n";
	$rc = $this->exec_child ( stdout => $logfile, logcmd => 1, append => 1, path => "/usr/bin/make" );
	($rc == 0) || die "could not make apache\n";
	
	lprint "copying src/httpdom to $aproot/bin/httpdom\n";
	copy("src/httpdom", "$aproot/bin/httpdom") || confess "cannot copy src/httpdom to $aproot/bin/httpdom: $!";
	chmod 0555, "$aproot/bin/httpdom";

	lprint "installing mod_perl libapreq\n";
	$this->install_cpan_set ( logfile => $logfile, set => $s->{cpan_bundle_mp_pkgs}, pause => 0, maketest => 0 );

	$this->reset_cwd;

	1;
}

sub run_configureapaches
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Configure apaches\n");

	my $aproot = $s->{apache_root}||confess;
	unless ( -r $aproot )
	{
		lprint " $aproot not installed - try running phases buildapacheproxy and buildapachemodperl first\n";
		return 1;
	}

	# make RedHat apache listen at localhost 8080 only
	my $httpconf = '/etc/httpd/conf/httpd.conf';
	lprint "configuring $httpconf ... ";
	my $ap = $this->read_into_array ( file => $httpconf ) || confess "cannot read $httpconf: $!";
	if ( grep {/^Listen 127.0.0.1:8080$/} @$ap )
	{
		lprint "already configured\n";
	}
	else
	{
		for ( @$ap )
		{
			s/^Listen 0.0.0.0:80$/Listen 127.0.0.1:8080/;
		}
		$this->backup_file ( file => "$httpconf" );
		$this->write_from_array ( file => $httpconf, arrayptr => $ap ) || confess "cannot write $httpconf: $!";
		lprint "done\n";

		my $cmd = "/sbin/service httpd restart";
		$this->exec_child ( path => $cmd ) == 0 || die "could not run: $cmd";
	}	

	# untar our proxy and mod_perl apache files
	lprint "apache proxy and mod_perl conf files\n";
	if ( 0 && -r $aproot.'/conf/httpd_proxy_base.conf' )
	{
		lprint " already exist\n";
	}
	else
	{
		my $acarchive = $s->{src_root}.'/'.$s->{apacheconf_pkg};
		my $confdir = $aproot . '/conf';
		my $files_ap = $this->softuntar ( archive => $acarchive, targetroot => $confdir, overwrite => 1, template_fields_hp => $s );
	}

	lprint "apache log permissions\n";
	my $cmd = "/bin/chmod -R a+rwx $aproot/logs";
	$this->exec_child ( path => $cmd ) == 0 || die "could not run $cmd";

	1;
}

sub run_libgd
{
	my $this = shift;
	my $s = $this->{settings};
	my $rc;
	lprint bold("Installing libgd 2\n");
	# maybe should go to /opt/lib ?
	if ( -r '/usr/local/lib/libgd.so' )
	{
		lprint " already installed\n";
	}
	else
	{
		my $archive = $s->{src_root}.'/'.$s->{libgd_pkg};
		$this->untar ( archive => $archive, targetroot => $s->{work_root}, overwrite => 1 );
		(my $subdir = $s->{libgd_pkg}) =~ s/.tar.gz$//;
		$subdir =~ s/.tgz$//;
		$this->set_cwd ( $s->{work_root}.'/'.$subdir );	
		$rc = $this->exec_child ( path => '/bin/sh ./configure' ); # --prefix=/usr if you want to overwrite RH libgd.1.8.4
		($rc == 0) || die "could not configure";
		$rc = $this->exec_child ( path => '/usr/bin/make install' );
		($rc == 0) || die "could not make";
		$this->reset_cwd;
	}
	# add /usr/local/lib to shared library search path
	my $ldsoconf = '/etc/ld.so.conf';
	my $ap = $this->read_into_array ( file => $ldsoconf ) || confess "cannot read $ldsoconf: $!";
	if ( grep {/^\/usr\/local\/lib$/} @$ap )
	{
		lprint "/usr/local/lib already in $ldsoconf\n";
	}
	else
	{
		lprint "adding /usr/local/lib to $ldsoconf\n";
		push @$ap, "/usr/local/lib";
		$this->backup_file ( file => "$ldsoconf" );
		$this->write_from_array ( file => $ldsoconf, arrayptr => $ap ) || confess "cannot write $ldsoconf: $!";
		$rc = $this->exec_child ( path => '/sbin/ldconfig' );
	}
	1;
}

sub run_cpan_oi
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Installing CPAN modules to support OpenInteract\n");
	my $logfile = $this->{verbose} ? undef : $s->{work_root}.'/cpanoi.log';
	if ( $logfile )
	{
		lprint "Logging detailed output to $logfile\n";
		unlink($logfile) if $logfile;
	}
	$this->install_cpan_set ( set => $s->{cpan_bundle_oi_pkgs}, pause => 0, logfile => $logfile );
	1;
}

sub run_cpan_om
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Installing CPAN modules to support OM\n");
	my $logfile = $this->{verbose} ? undef : $s->{work_root}.'/cpanom.log';
	if ( $logfile )
	{
		lprint "Logging detailed output to $logfile\n";
		unlink($logfile);
	}
	$this->install_cpan_set ( set => $s->{cpan_bundle_om_pkgs}, pause => 0, logfile => $logfile );
	1;
}

sub run_oi
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Installing OpenInteract source\n");
	my $oiarch = $s->{cpan_root}.'/'.$s->{oi_cpan_pkg};
	my $oisrc = $s->{oisrc};
	my $oisrcroot = $s->{oisrcroot};

	# install site perl OI modules
	my $logfile = $this->{verbose} ? undef : $s->{work_root}.'/cpanom.log';
	$this->install_cpan_set ( set => $s->{cpan_bundle_oi_inst_pkgs}, pause => 0, logfile => $logfile );

	# unpack OI source below /usr/local/src and create symbolic link to openinteract
	# so we can do "oi_manage install" from /usr/local/src/openinteract now and later
	if ( -r $oisrc )
	{
		lprint "OI source already installed to $oisrc\n";
	}
	else
	{
		mkpath($oisrcroot);
		$this->untar ( archive => $oiarch, targetroot => $oisrcroot );
		my $name = [ split(/\//,$oiarch) ]->[-1];
		(my $subdir = $name) =~ s/.tar.gz$//;
		$subdir =~ s/.tgz$//;
		my $oisrcreal = $oisrcroot.'/'.$subdir;
		unlink($oisrc);
		symlink ($oisrcreal, $oisrc) || warn "Cannot create symbolic link from $oisrcreal to $oisrc: $!";
		lprint "OI source installed to $oisrc\n";
	}

	1;
}

sub run_omconf
{
	my $this = shift;
	my $s = $this->{settings};
	lprint bold("Installing OM apache and OI configuration and mysql databases\n");
	my $oisrc = $s->{oisrc};

	# oiapachectl script used to start/stop or configure our apache
	my $instpath = $s->{oiapachectl};
	lprint "$instpath ... ";
	my $oiapachectl = $s->{src_root}.'/'.$s->{oiapachectl_src};
	if ( -r $instpath )
	{
		lprint " already installed\n";
	}
	else
	{
		$this->template_replace ( infilepath => $oiapachectl, outfilepath => $instpath, fields_hp => $s );
		chmod 0555, $instpath;
		lprint "$instpath installed\n";
		# create om database and tables needed for oiapachectl
		lprint "creating om database\n";
		my $serverfn = $s->{src_root}.'/'.$s->{om_sql};
		my $content;
		$this->template_replace ( infilepath => $serverfn, content_sp => \$content, fields_hp => $s );
		$this->exec_mysql ( sql => $content, flags => '--force' ) || warn "could not create database om";
		lprint "create dsblank database\n";
		my $dsblankfn = $s->{src_root}.'/'.$s->{dsblank_sql};
		$this->template_replace ( infilepath => $dsblankfn, content_sp => \$content, fields_hp => $s );
		$this->exec_mysql ( sql => $content, flags => '--force' ) || warn "could not create database dsblank";
		lprint "flush mysql tables\n";
		$this->exec_mysql ( sql => "flush tables;" ) || warn 'could not flush mysql tables';		
	}

	# create our apache conf files
	my $cmd = "$s->{oiapachectl} writeconfig";
	$this->exec_child ( path => $cmd ) == 0 || die "could not run $cmd";

	# configure OI conf templates for OM
	#	sample-server.ini
	#		expires_in  = 60
	#		[action_info none]
	#		redir = om
	#		[action_info not_found]
	#		redir = om
	#	sample-server.perl
   #  	'expires_in' => 60,
   #	sample-log4perl.conf
   #	sample-startup.pl
	lprint "Editing OI conf templates for OM\n";
	my $oiomctpkg = $s->{src_root}.'/'.$s->{oi_om_conftemplate_pkg};
	$this->softuntar ( archive => $oiomctpkg, targetroot => $oisrc, overwrite => 1, template_fields_hp => $s );
	# OM patch for OI site_perl modules
	lprint "Patching OpenInteract below $s->{perlprefix}\n";
	my $archive = $s->{src_root}.'/'.$s->{oipatchoi_pkg};
	$this->untar ( archive => $archive, targetroot => $s->{perlprefix}, overwrite => 1 );
	1;
}

=pod

	server 								(vhost)*
	
	db oitest							db dstest
	db om.sys_server					db om.sys_vhost
	base oitest
	site oitest
	html

=cut

sub run_oiserver
{
	my $this = shift;
	my $s = $this->{settings};
	my $server = $s->{server}||confess;
	lprint bold("Installing OpenInteract server \"$server\"\n");

	my $oiarch = $s->{cpan_root}.'/'.$s->{oi_cpan_pkg};
	my $oisrcroot = $s->{oisrcroot};
	my $oisrc = $s->{oisrc};
	my $oi_manage = $s->{oi_manage};
	my $webname = $server;
	my $sitehome = $s->{oisiteroot}.'/'.$webname;
	my $basedirroot = $s->{oibaseroot};
	my $basedir = $basedirroot.'/'.$webname;
	my $webdir = $s->{oisiteroot}.'/'.$webname;
	my $dbname = 'oi'.$webname;
	$s->{dbsite} = $dbname;
	my $tasksrc = $s->{src_root}.'/task-5.01.tar.gz';
	my $instlog = $s->{work_root}.'/oiwebsite.log';
	(my $insterr = $instlog) =~ s/.log$/.err/;
	my $cmd;
	my $content;

	# Install OI base and website directories in om area and create database

	lprint "site = $webname, basedir = $basedir, webdir = $webdir\n";
	lprint "logging oi_manage output to $instlog and errors to $insterr\n";
	unlink($instlog);
	unlink($insterr);
	my %logflags = ( stdout => $instlog, stderr => $insterr, append => 1, logcmd => 1 );

	# install OI base from OI source directory and add OM task package 
	if ( -r $basedir )
	{
		lprint "OI base already installed to $basedir\n";
	}
	else
	{
		$this->set_cwd ($oisrc);
		mkpath($basedirroot);
		$cmd = "$oi_manage install --base_dir=$basedir";
		$this->exec_child ( path => $cmd, %logflags ) == 0 || die "could not run $cmd";
		$cmd = "$oi_manage install_package --base_dir=$basedir --package_file=$tasksrc";
		$this->exec_child ( path => $cmd, %logflags ) == 0 || die "could not run $cmd";
	}

	# install OI base to website
	mkpath($s->{oisiteroot});
	$cmd = "$oi_manage create_website --base_dir=$basedir --website_name=$dbname --website_dir=$webdir";
	$this->exec_child ( path => $cmd, %logflags ) == 0 || die "could not run $cmd";
	# some site conf settings default from OI conf templates set up in run_omconf(), others done here
	for ( @{$s->{oi_om_conftemplate_morefiles}} )
	{
		my $infn = $oisrc.'/conf/sample-'.$_;
		my $outfn = $webdir.'/conf/'.$_;
		$this->template_replace ( infilepath => $infn, outfilepath => $outfn, fields_hp => $s );
		vprint " conf template $_ written\n";
	}

	# create OI site database - maybe should remove the risky drop database but it's convenient for now
	lprint "creating OI site database $dbname\n";
	my $sql = <<EOF ;
drop database if exists `$dbname`;
create database `$dbname`;
grant all on `$dbname`.* to `$s->{mysqlomuser}`\@localhost;
flush privileges;
flush tables;
EOF
	$this->exec_mysql ( sql => $sql ) || warn "could not create mysql database $dbname";

	# install base packages to site and default OI sql records
	$cmd = "$oi_manage install_sql --base_dir=$basedir --website_dir=$webdir --package=INITIAL";
	$this->exec_child ( path => $cmd, stdout => $instlog, stderr => $insterr, append => 1, logcmd => 1 ) == 0 || die "could not run $cmd";
	my $txt = $this->read_file ( file => $instlog );
	my $supw;
	$txt =~ /Administrator password: ([A-Z]+)/ && ($supw = $1);

	# update OI sql records to give blank OI website database to match blank OM site database
	lprint "update $webname database with OM blank defaults\n";
	my $oiblankfn = $s->{src_root}.'/'.$s->{oiblank_sql};
	$this->template_replace ( infilepath => $oiblankfn, content_sp => \$content, fields_hp => $s );
	$this->exec_mysql ( sql => $content, flags => '--force' ) || warn "could not update database $dbname with OM blank defaults";

	# unpack OM html, styles, images below site html
	my $archive = $s->{src_root}.'/'.$s->{omhtml_pkg};
	$this->untar ( archive => $archive, targetroot => $webdir.'/html', overwrite => 1 );
	# install OM packages to site
	$cmd = "$oi_manage apply_package --base_dir=$basedir --website_dir=$webdir --package=task";
	$this->exec_child ( path => $cmd, %logflags ) == 0 || die "could not run $cmd";
	#
	$supw ? lprint "OI superuser password was $supw\n"
		: warn "cannot find OI superuser password in $instlog - maybe the $webname database already existed";

	lprint "resetting file ownership\n";
	my $siteuser = $s->{omuser} || confess;
	my $sitegroup = $s->{omgroup} || confess;
	confess unless $sitehome && length($sitehome) > 6;
	$cmd = "/bin/chown -R $siteuser.$sitegroup $basedir $sitehome ";
	$this->exec_child ( path => $cmd ) == 0 || die "could not run $cmd";

	1;
}

sub run_omsite
{
	my $this = shift;
	my $s = $this->{settings};
	my $server = $s->{server}||confess;
	my $site = $s->{site}||confess;
	lprint bold("Installing OM site \"$site\"\n");
	my $cmd;

	# create OM site database, virtual host record, and apache config files

	# create OM site database by copying from dsblank
	my $omdatabase = $s->{site} || confess;
	$omdatabase = 'ds'.$omdatabase;
	lprint "creating OM database $omdatabase\n";
	my $dbroot = $s->{mysql_db_root} || confess;
	my $omdbpath = $dbroot.'/'.$omdatabase;
	my $omblankdbpath = $dbroot.'/dsblank';
	confess "cannot find database dsblank" unless -d $omblankdbpath;
	if ( -r $omdbpath )
	{
		warn "OM database $omdbpath already exists\!";
	}
	else
	{
		$cmd = "/bin/cp -Rpd $omblankdbpath $omdbpath";
		$this->exec_child ( path => $cmd ) == 0 || die "could not run $cmd";
	}
	$this->exec_mysql ( sql => "flush tables" ) || warn "could not flush mysql tables";

	# set up vhost record in om.sys_vhost
	$this->sql_connect_db;
	my $vhost = $s->{vhost} || confess;
	my $comment = '';
	my $enabled = '1';
	my $secure = '0';
	my $sql = <<EOM ;
INSERT INTO sys_vhost (svh_vhost, svh_server, svh_database, svh_comment, svh_enabled, svh_secure )
VALUES (?,?,?,?,?,?)
EOM
	my ($rv, $sth) = $this->sql_exec ( sql => $sql, args => [ $vhost, $server, $omdatabase, $comment, $enabled, $secure ], fatal => 0 );
	warn "sql error: ", $sth->errstr(), "\nsql: $sql\n" unless $rv;

	# set up server record if needed in om.sys_server
	my $serverport = $s->{serverport} || confess;
	$enabled = '1';
	$sql = <<EOM ;
INSERT INTO sys_server (svr_server, svr_port, svr_enabled)
VALUES (?,?,?)
EOM
	($rv, $sth) = $this->sql_exec ( sql => $sql, args => [ $server, $serverport, $enabled ], fatal => 0 );
	warn "sql error: ", $sth->errstr(), "\nsql: $sql\n" unless $rv;
	
	# recreate apache conf files
	$cmd = "$s->{oiapachectl} writeconfig";
	$this->exec_child ( path => $cmd ) == 0 || die "could not run $cmd";

	1;	
}

sub run_start
{
	my $this = shift;
	my $s = $this->{settings};

	my $cmd = $s->{oiapachectl}.' start';
	$this->exec_child ( path => $cmd ) == 0 || die "could not run $cmd";

	1;
}

sub run_
{
	my $this = shift;
	my $s = $this->{settings};
	1;
}

###

sub sql_connect_db
{
	my $this = shift;
	return 1 if $this->{dbh};

	eval "require DBI";
	my $dummy = $DBI::errstr;
	my $da = $this->{dbiargs};
	$this->{dbh} = DBI->connect( $da->{dsn}, $da->{user}, $da->{pass} )
			|| die "Cannot connect to database $da->{dsn}: $DBI::errstr" ;
	#$this->{dbh}->{RaiseError} = 1;
}

sub sql_exec
{
	my $this = shift;
	my %arg = ( sql => undef, fatal => 1, args => [], @_ );

	confess unless $this->{dbh};
	my $sth = $this->{dbh}->prepare($arg{sql}) || confess;
	my $rv = $sth->execute(@{$arg{args}});
	if (!$rv && $arg{fatal})
	{
		confess "cannot execute sql: ", $sth->errstr(), "\nsql: $arg{sql}\nargs: \"", join("\", \"",@{$arg{args}}), "\"\n";
	}
	return ($rv, $sth);
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
	my %arg = ( trim => 0, nocomments => 0, file => undef, fatal => 0, @_ );

	open(F, "< $arg{file}") or $arg{fatal} ? confess "cannot read: $arg{file}: $!" : return undef;
	my @arr;
	while (<F>)
	{
		next if $arg{nocomments} && ( /^#/ or /^(\s)*$/ ); # ignore comments or blank lines
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
	my %arg = ( trim => 0, file => undef, arrayptr => undef, fatal => 0, @_ );

	open(F, "> $arg{file}") or $arg{fatal} ? confess "cannot write: $arg{file}: $!" : return undef;
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

sub read_file
{
	my $this = shift;
	my %arg = ( file => undef, fatal => 0, @_ );
	confess unless $arg{file};
	confess "$arg{file} is not a normal file" if -r $arg{file} && ! -f $arg{file};
	open(F, "< $arg{file}") or $arg{fatal} ? confess "cannot open: $arg{file}: $!" : return undef;
	local $/;
	my $s = <F>;
	close(F) or $arg{fatal} ? confess "cannot close: $arg{file}: $!" : return undef;
	$s;
}

sub write_file
{
	my $this = shift;
	my %arg = ( file => undef, content => undef, fatal => 0, @_ );
	confess unless $arg{file} && defined $arg{content};
	open(F, "> $arg{file}") or $arg{fatal} ? confess "cannot open: $arg{file}: $!" : return undef;
	print F $arg{content} or $arg{fatal} ? confess "cannot write: $arg{file}: $!" : return undef;
	close(F) or $arg{fatal} ? confess "cannot close: $arg{file}: $!" : return undef;
	1;
}

sub backup_file
{
	my $this = shift;
	my %arg = ( file => undef, ext => '.orig', @_ );
	confess unless $arg{file};
	$this->write_file ( file => "$arg{file}$arg{ext}", fatal => 1, content =>
		$this->read_file ( file => $arg{file}, fatal => 1 ) );
}

sub template_replace
{
	my $this = shift;
	my %arg = (
		infilepath		=> undef,
		outfilepath		=> undef,
		content_sp		=> undef,
		fields_hp		=> undef,
		warn_missing	=> 1,
		name				=> '',
		@_,
		);

	if ( $arg{infilepath} )
	{
		return 1 if -d $arg{infilepath}; # skip directories
		confess "cannot read $arg{infilepath}: $!" unless -f $arg{infilepath};
		my $content = $this->read_file ( file => $arg{infilepath} );
		confess "cannot read $arg{infilepath}: $!" unless defined $content;
		if ( $arg{content_sp} )
		{
			${$arg{content_sp}} = $content;
		}
		else
		{
			$arg{content_sp} = \$content;
		}
	}
	confess unless defined $arg{content_sp} && defined $arg{fields_hp};

   # replace placeholders in template
   my @missing;
   ${$arg{content_sp}} =~ s{ \<% ( .*? ) %\> } # <% %> field delimiters
		{ exists($arg{fields_hp}->{$1}) ? $arg{fields_hp}->{$1}
		: ($arg{warn_missing} ? push(@missing,$1) : "") }gsex;
	if ( scalar @missing )
	{
		confess "template ".($arg{infilepath} ? $arg{infilepath} : $arg{name})." missing fields:\n ".join("\n ",@missing)."\n";
	}

	if ( $arg{outfilepath} )
	{
		$this->write_file ( file => $arg{outfilepath}, content => ${$arg{content_sp}} ) || confess "cannot write $arg{outfilepath}: $!";
	}

	1;
}

__END__

=head1 NAME

ominstall.pl - install OM and/or supporting packages

=head1 SYNOPSIS

ominstall.pl [-help|-man] [-verbose] [-timestamp] [-tarnoalternate] [-taroverwrite] [-site=sitename] {-listphases | -phase=name | -startphase=name1 -endphase=name2}

=head1 OPTIONS

=over 8

=item B<-listphases>

List the phases of installation available.

=item B<-phase>

Run a single phase of installation.

=item B<-startphase> B<-endphase>

Run phases from the startphase to the endphase specified.

=item B<-ask>

Ask for configuration values rather than use built in defaults.

=item B<-help>

Print brief help and exit.

=item B<-man>

Print manual page and exit.

=item B<-verbose>

Print details of commands issued.

=item B<-debug>

Print debugging information.

=item B<-timestamp>

Prefix messages with timestamp.

=item B<-tarnoalternate>

When untar'ing files do not create an alternate copy where the original already exists.
The default is to create an alternate.

=item B<-taroverwrite>

When untar'ing files overwrite where the original exists. Default no.

=item B<-site=sitename>

When running the omsite phase, specifies the name to use when creating
the OpenInteract site base, website and database used by a mod_perl server. Default 'oitest'.

=item B<-omdatabase=dbname>

When running the omsite phase, specifies the name of the OM database
to create and associate with the mod_perl server. Each apache virtual host can have a
different OM database, while sharing the OI database used by the server.
Default 'dstest'.

=back

=head1 DESCRIPTION

Installs the OM application and/or its supporting packages:

=over 1

=item * Root login setup

=item * Mysql

=item * perl CPAN libraries

=item * apache proxy and mod_perl servers

=back

=head1 COPYRIGHT

Copyright (c) 2006 Dragonstaff Limited, UK. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

