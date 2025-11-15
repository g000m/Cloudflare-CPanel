# Cloudflare cPanel Plugin - Rollback & Safety Guide

This guide ensures you can safely test and rollback the Cloudflare cPanel plugin without compromising your server.

---

## 🛡️ Safety First: Pre-Installation Checklist

Before installing on your test server, complete these steps:

### 1. Create a Full Backup

**Run the backup script:**
```bash
bash cloudflare.backup.sh
```

This will:
- ✅ Backup all existing plugin files (if upgrading from v7.x)
- ✅ Backup all user data (API tokens, settings)
- ✅ Backup cron jobs and hooks
- ✅ Create an automatic restore script
- ✅ Generate a complete manifest

**Backup location:** `/root/cloudflare_backup_YYYYMMDD_HHMMSS/`

### 2. Take a Server Snapshot (Recommended)

If your hosting provider supports snapshots (AWS, DigitalOcean, Linode, etc.):
- Take a complete server snapshot before installation
- This provides a full system rollback option

### 3. Test on Non-Production First

If possible:
- Install on a staging/development server first
- Test all functionality before production deployment

---

## 📦 Installation Process (Safe Mode)

### Step 1: Create Backup
```bash
cd /root
wget https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.backup.sh
bash cloudflare.backup.sh
```

**Verify backup created:**
```bash
ls -lh /root/cloudflare_backup_*/
cat /root/cloudflare_backup_*/BACKUP_MANIFEST.txt
```

### Step 2: Install Plugin
```bash
bash <(curl -s https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.install.sh)
```

**Monitor for errors during installation.**

### Step 3: Verify Installation
```bash
# Check plugin registered
/usr/local/cpanel/bin/manage_plugins list | grep -i cloudflare

# Check files installed (Jupiter theme)
ls -l /usr/local/cpanel/base/frontend/jupiter/cloudflare/

# Check PHP backend
ls -l /usr/local/cpanel/3rdparty/php/*/lib/php/cloudflare/

# Check Perl module
ls -l /usr/local/cpanel/Cpanel/API/CloudFlare.pm
```

### Step 4: Test Basic Functionality

1. **Access cPanel as a test user** (not root)
2. **Find the Cloudflare icon**
   - Usually in "Domains" or "Advanced" section
3. **Create a test API token:**
   - Go to https://dash.cloudflare.com/profile/api-tokens
   - Create token with: Zone:DNS:Edit, Zone:Zone:Read, Zone:Zone Settings:Edit
4. **Enter token in plugin**
5. **Verify token validation works**

---

## 🔄 Rollback Procedures

### Option 1: Automatic Restore (Fastest)

If you created a backup with `cloudflare.backup.sh`:

```bash
# Find your backup
ls -d /root/cloudflare_backup_*

# Run the auto-restore script
cd /root/cloudflare_backup_YYYYMMDD_HHMMSS/
bash RESTORE.sh

# Restart cPanel
service cpanel restart
```

**This will:**
- ✅ Restore all plugin files to previous state
- ✅ Restore user data and configurations
- ✅ Restore scripts and cron jobs
- ✅ Take 1-2 minutes

---

### Option 2: Clean Uninstall (Remove Everything)

If you want to completely remove the plugin:

```bash
# Download uninstall script
wget https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.uninstall.sh

# Run uninstaller (will offer to backup first)
bash cloudflare.uninstall.sh

# Restart cPanel
service cpanel restart
```

**This will:**
- ✅ Remove all plugin files (both themes)
- ✅ Remove PHP backend
- ✅ Remove Perl module
- ✅ Remove cron jobs and hooks
- ✅ Optionally backup user data first
- ⚠️ User data files stay in home directories (safe)

---

### Option 3: Manual Rollback (If Scripts Fail)

If automated scripts fail, manually remove files:

```bash
# Set variables
INSTALL_DIR="/usr/local/cpanel"

# Get PHP version
PHPVER=$(ls -al $INSTALL_DIR/3rdparty/bin/php | awk '{print $11}' | rev | cut -d '/' -f 3 | rev)

# Remove plugin files
rm -rf $INSTALL_DIR/base/frontend/jupiter/cloudflare
rm -rf $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
rm -rf $INSTALL_DIR/3rdparty/php/$PHPVER/lib/php/cloudflare
rm -f $INSTALL_DIR/Cpanel/API/CloudFlare.pm
rm -f $INSTALL_DIR/bin/cloudflare_update.sh
rm -rf $INSTALL_DIR/bin/admin/CloudFlare

# Remove hooks
sed -i '/cloudflare_update.sh/d' /scripts/postupcp

# Remove cron
crontab -l | grep -v "cloudflare_update.sh" | crontab -

# Unregister plugin
/usr/local/cpanel/scripts/uninstall_plugin cloudflare

# Restart cPanel
service cpanel restart
```

---

### Option 4: Server Snapshot Restore (Nuclear Option)

If you took a server snapshot before installation:

1. Log in to your hosting provider control panel
2. Locate your snapshot (taken before installation)
3. Restore server to snapshot
4. **WARNING:** This will revert ALL server changes, not just the plugin

**Use only if:**
- The plugin broke critical server functionality
- Other rollback methods failed
- No other option works

---

## 🚨 Troubleshooting Rollback Issues

### Issue: RESTORE.sh fails with permission errors

**Solution:**
```bash
chmod +x /root/cloudflare_backup_*/RESTORE.sh
bash /root/cloudflare_backup_*/RESTORE.sh
```

### Issue: cPanel won't restart after uninstall

**Solution:**
```bash
# Check cPanel logs
tail -100 /usr/local/cpanel/logs/error_log

# Force restart
/usr/local/cpanel/scripts/restartsrv_cpanel --stop
/usr/local/cpanel/scripts/restartsrv_cpanel --start

# If still failing, rebuild cPanel config
/usr/local/cpanel/scripts/rebuildhttpdconf
```

### Issue: Plugin still appears in cPanel after uninstall

**Solution:**
```bash
# Clear cPanel cache
/usr/local/cpanel/scripts/clear_cpanel_cache

# Rebuild dynamic UI
/usr/local/cpanel/bin/rebuild_sprites

# Force update
/usr/local/cpanel/scripts/upcp --force
```

### Issue: User data lost

**Solution:**
```bash
# User data is stored in home directories - check there first
find /home -name "cloudflare_data.yaml" -path "*/.cpanel/datastore/*"

# If you ran backup, restore from there
cd /root/cloudflare_backup_*/user_data/
# Copy back to user home directories
for USER_DIR in */; do
    USERNAME=$(basename "$USER_DIR")
    cp "$USER_DIR/cloudflare_data.yaml" "/home/$USERNAME/.cpanel/datastore/"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.cpanel/datastore/cloudflare_data.yaml"
done
```

---

## 📋 Post-Rollback Verification

After any rollback, verify your server is stable:

```bash
# 1. Check cPanel is running
service cpanel status

# 2. Verify websites are accessible
curl -I http://localhost

# 3. Check for errors
tail -50 /usr/local/cpanel/logs/error_log

# 4. Test cPanel login
# Open browser: https://your-server-ip:2083

# 5. Verify plugin is gone
/usr/local/cpanel/bin/manage_plugins list | grep -i cloudflare
# (should return nothing)
```

---

## 🔐 What's Safe vs What's Not

### ✅ Safe Operations (Won't Break Server)

- Installing the plugin (only adds files)
- Uninstalling the plugin (only removes plugin files)
- Running backup script (read-only)
- Running restore script (only affects plugin)
- Creating API tokens in Cloudflare
- Entering API tokens in plugin

### ⚠️ Caution Required

- Changing DNS records (could affect site accessibility)
- Enabling full zone mode (transfers nameservers)
- Deleting zones in Cloudflare (could break sites)

### ❌ What Won't Be Affected by Rollback

- Your Cloudflare account (unchanged)
- DNS records in Cloudflare (unchanged)
- Website files (unchanged)
- Databases (unchanged)
- Email accounts (unchanged)
- Other cPanel plugins (unchanged)

---

## 📞 Emergency Contacts & Resources

### If Something Goes Wrong

1. **Check logs first:**
   ```bash
   tail -100 /usr/local/cpanel/logs/error_log
   tail -100 /var/log/messages
   ```

2. **Restore from backup:**
   ```bash
   cd /root/cloudflare_backup_*/
   bash RESTORE.sh
   ```

3. **Contact your hosting provider** if:
   - cPanel won't start after rollback
   - Server is inaccessible
   - Critical services are down

4. **Report issues:**
   - GitHub Issues: https://github.com/g000m/Cloudflare-CPanel/issues
   - Include: error logs, cPanel version, PHP version

---

## 📝 Pre-Flight Checklist

Before testing on your server, check off:

- [ ] Created full backup with `cloudflare.backup.sh`
- [ ] Verified backup exists in `/root/cloudflare_backup_*/`
- [ ] Reviewed BACKUP_MANIFEST.txt
- [ ] Tested RESTORE.sh works (optional dry-run)
- [ ] Took server snapshot (if available)
- [ ] Have SSH access in case cPanel breaks
- [ ] Know how to access server console (if SSH fails)
- [ ] Read this entire rollback guide
- [ ] Tested on non-production server first (if possible)

---

## ⏱️ Estimated Rollback Times

| Method | Time Required | Downtime |
|--------|---------------|----------|
| Automatic Restore | 1-2 minutes | None (plugin only) |
| Clean Uninstall | 2-3 minutes | None (plugin only) |
| Manual Rollback | 5-10 minutes | None (plugin only) |
| Server Snapshot | 10-30 minutes | Full server down |

---

## 🎯 Summary: You're Protected If...

✅ **You created a backup** before installing
✅ **You have the uninstall script** available
✅ **You have server console access** (worst case)
✅ **You took a server snapshot** (optional but recommended)

**Then you can safely test this plugin!** The rollback options are comprehensive and tested.

---

**Questions?** Open an issue on GitHub or consult your hosting provider's support.

**Ready to proceed?** Start with Step 1: `bash cloudflare.backup.sh`
