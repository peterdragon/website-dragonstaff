# GitHub Pages Migration Guide

This guide will help you migrate your website from AWS S3/CloudFront to GitHub Pages to save money.

## Step 1: Prepare Your Local Repository

The git repository has been initialized. Now add and commit your files:

```bash
cd /Users/peter/dev/website-dragonstaff.co.uk

# Add all files (respecting .gitignore)
git add .

# Create initial commit
git commit -m "Initial commit: Migrate to GitHub Pages"

# Rename branch to main (if needed)
git branch -M main
```

## Step 2: Create GitHub Repository

1. Go to [GitHub](https://github.com) and sign in
2. Click the "+" icon in the top right → "New repository"
3. Repository name: `dragonstaff-website` (or any name you prefer)
4. Description: "Dragonstaff website - www.dragonstaff.co.uk"
5. Set to **Public** (required for free GitHub Pages)
6. **DO NOT** initialize with README, .gitignore, or license (we already have these)
7. Click "Create repository"

## Step 3: Push to GitHub

After creating the repository, GitHub will show you commands. Use these:

```bash
# Add the remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/dragonstaff-website.git

# Push to GitHub
git push -u origin main
```

## Step 4: Configure GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** → **Pages** (in the left sidebar)
3. Under "Source", select:
   - Branch: `main`
   - Folder: `/ (root)`
4. Click **Save**

## Step 5: Configure Custom Domain

1. Still in **Settings** → **Pages**
2. Under "Custom domain", enter: `www.dragonstaff.co.uk`
3. Check **"Enforce HTTPS"** (this will be available after DNS is configured)
4. Click **Save**

GitHub will create a file called `CNAME` in your repository. This is normal and required.

## Step 6: Update DNS in Squarespace

You need to update your DNS records to point to GitHub Pages instead of CloudFront.

### Option A: Use CNAME (Recommended for www subdomain)

1. Go to Squarespace → Settings → Domains → Manage dragonstaff.co.uk
2. Find the existing `www` CNAME record
3. Update it to:
   - **Host**: `www`
   - **Type**: `CNAME`
   - **Value**: `YOUR_USERNAME.github.io` (replace with your GitHub username)
   - **TTL**: 300

### Option B: Use A Records (For root domain)

If you want to use the root domain (dragonstaff.co.uk), add these A records:

1. Go to Squarespace DNS settings
2. Add/update A records for `@`:
   - **185.199.108.153**
   - **185.199.109.153**
   - **185.199.110.153**
   - **185.199.111.153**

**Note**: You can't use CNAME for root domain if you have MX records (for email). In that case, use A records.

## Step 7: Wait for DNS Propagation

- DNS changes can take 5-15 minutes to propagate
- GitHub Pages may take a few minutes to detect your custom domain
- Once detected, you'll see a green checkmark in GitHub Pages settings

## Step 8: Enable HTTPS

After DNS propagates:
1. Go back to **Settings** → **Pages**
2. Check **"Enforce HTTPS"** (should now be available)
3. Your site will be available at `https://www.dragonstaff.co.uk`

## Step 9: Clean Up AWS Resources (Optional)

Once you've verified GitHub Pages is working:

### Delete CloudFront Distribution
```bash
aws cloudfront delete-distribution --id E1QAWIJS0O0G4A --if-match <ETAG>
```
(You'll need to disable it first, wait for deployment, then delete)

### Delete SSL Certificate
```bash
aws acm delete-certificate --certificate-arn arn:aws:acm:us-east-1:036761243520:certificate/e72a5265-3fc8-4402-83d1-15dc54701020 --region us-east-1
```

### Keep or Delete S3 Bucket
You can either:
- **Keep it** as a backup (minimal cost for storage)
- **Delete it** if you're sure you don't need it:
  ```bash
  aws s3 rb s3://dragonstaff.co.uk --force
  ```

## Troubleshooting

### DNS Not Working
- Check DNS propagation: https://www.whatsmydns.net
- Verify CNAME/A records are correct in Squarespace
- Wait up to 48 hours for full propagation (usually much faster)

### GitHub Pages Not Updating
- Check repository settings → Pages → ensure branch is set correctly
- Verify files are in the root directory
- Check GitHub Actions tab for any build errors

### HTTPS Not Available
- DNS must be fully propagated first
- Wait 5-10 minutes after DNS is correct
- GitHub needs to verify domain ownership

## Benefits of GitHub Pages

✅ **Free hosting** - No AWS costs  
✅ **Free SSL** - Automatic HTTPS  
✅ **Git-based workflow** - Easy updates  
✅ **CDN included** - Fast global delivery  
✅ **Custom domains** - Full support  
✅ **Automatic deployments** - Push to deploy  

## Future Updates

To update your website:
```bash
# Make changes to files
git add .
git commit -m "Update website content"
git push
```

Changes will be live within 1-2 minutes!

