# Quick Start: Safe Testing Guide

## ⚡ TL;DR - Safe Testing in 3 Steps

```bash
# 1. BACKUP (creates safety net)
wget https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.backup.sh
bash cloudflare.backup.sh

# 2. INSTALL (test the plugin)
bash <(curl -s https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.install.sh)

# 3. ROLLBACK (if needed - instant restore)
cd /root/cloudflare_backup_*/ && bash RESTORE.sh
```

---

## 🎯 What You Asked For: Clear Rollback Path

### ✅ **YES - Multiple rollback options available:**

| If This Happens... | Do This... | Time | Risk |
|-------------------|------------|------|------|
| Installation fails mid-way | `cd /root/cloudflare_backup_*/ && bash RESTORE.sh` | 1-2 min | None |
| Plugin breaks cPanel UI | `bash cloudflare.uninstall.sh` | 2-3 min | None |
| Need to remove completely | `bash cloudflare.uninstall.sh` | 2-3 min | None |
| Everything is broken | See manual rollback below | 5-10 min | None |

### ✅ **What's Protected:**

Your test server is protected because:

1. **Automatic Backup Script**
   - Backs up all plugin files
   - Backs up all user data
   - Creates auto-restore script
   - Timestamped (won't overwrite)

2. **Clean Uninstall**
   - Removes all plugin files
   - Offers backup before removal
   - Never touches user websites
   - Leaves no trace

3. **Multiple Rollback Strategies**
   - Automatic (1 command)
   - Manual (documented)
   - Nuclear (server snapshot)

4. **Safe by Design**
   - Plugin only modifies plugin files
   - Websites stay online during install/uninstall
   - Databases untouched
   - Email accounts untouched
   - DNS records only change if you modify them

---

## 📋 Pre-Flight Checklist (Before Testing)

```bash
# Check off each item:
[ ] 1. Have root SSH access
[ ] 2. Know server console access method (if SSH fails)
[ ] 3. Created backup: bash cloudflare.backup.sh
[ ] 4. Verified backup exists: ls /root/cloudflare_backup_*/
[ ] 5. Tested restore works: cd /root/cloudflare_backup_*/ && bash RESTORE.sh --dry-run
[ ] 6. (Optional) Took server snapshot with hosting provider
```

**If all checked:** ✅ Safe to proceed with installation!

---

## 🚨 Emergency Procedures

### Scenario 1: Installation Fails/Errors

```bash
# Stop installation if possible (Ctrl+C)

# Roll back to previous state
cd /root/cloudflare_backup_*/
bash RESTORE.sh

# Verify rollback worked
/usr/local/cpanel/bin/manage_plugins list | grep cloudflare
# (should show nothing or previous version)
```

### Scenario 2: cPanel UI Broken After Install

```bash
# Option A: Quick uninstall
bash cloudflare.uninstall.sh

# Option B: Restore backup
cd /root/cloudflare_backup_*/
bash RESTORE.sh

# Restart cPanel
service cpanel restart

# Check status
service cpanel status
tail -50 /usr/local/cpanel/logs/error_log
```

### Scenario 3: Can't Access cPanel at All

```bash
# Via SSH - Check cPanel is running
service cpanel status

# If stopped, start it
service cpanel start

# Remove plugin manually (worst case)
rm -rf /usr/local/cpanel/base/frontend/jupiter/cloudflare
rm -rf /usr/local/cpanel/base/frontend/paper_lantern/cloudflare
service cpanel restart

# Check logs
tail -100 /usr/local/cpanel/logs/error_log
```

### Scenario 4: Everything Else Fails

```bash
# Manual complete removal
INSTALL_DIR="/usr/local/cpanel"
PHPVER=$(ls -al $INSTALL_DIR/3rdparty/bin/php | awk '{print $11}' | rev | cut -d '/' -f 3 | rev)

rm -rf $INSTALL_DIR/base/frontend/jupiter/cloudflare
rm -rf $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
rm -rf $INSTALL_DIR/3rdparty/php/$PHPVER/lib/php/cloudflare
rm -f $INSTALL_DIR/Cpanel/API/CloudFlare.pm
rm -f $INSTALL_DIR/bin/cloudflare_update.sh

# Clean up hooks/cron
sed -i '/cloudflare_update.sh/d' /scripts/postupcp
crontab -l | grep -v "cloudflare_update.sh" | crontab -

# Restart everything
service cpanel restart
/usr/local/cpanel/scripts/rebuildhttpdconf
/usr/local/cpanel/scripts/restartsrv_httpd
```

---

## ✅ What WON'T Break

**The plugin installation/uninstallation will NOT affect:**

- ❌ Your websites (stay online)
- ❌ Your databases (untouched)
- ❌ Your email accounts (untouched)
- ❌ Your SSL certificates (untouched)
- ❌ Your FTP accounts (untouched)
- ❌ Other cPanel plugins (untouched)
- ❌ Server configuration (untouched)
- ❌ User files in /home (untouched)

**Only these are modified:**
- ✅ Plugin files in /usr/local/cpanel/base/frontend/
- ✅ Plugin PHP backend in /usr/local/cpanel/3rdparty/php/
- ✅ Plugin Perl module in /usr/local/cpanel/Cpanel/API/
- ✅ Plugin update script in /usr/local/cpanel/bin/
- ✅ Cron job entry (auto-update)
- ✅ Hook in /scripts/postupcp (auto-update)

---

## 📞 Support Resources

### If You Need Help:

1. **Check the logs first:**
   ```bash
   tail -100 /usr/local/cpanel/logs/error_log
   ```

2. **Consult the guides:**
   - [ROLLBACK_GUIDE.md](ROLLBACK_GUIDE.md) - Comprehensive rollback documentation
   - [README.md](README.md) - Full documentation

3. **Report issues:**
   - GitHub: https://github.com/g000m/Cloudflare-CPanel/issues
   - Include: cPanel version, PHP version, error logs

4. **Contact hosting provider if:**
   - cPanel won't start after rollback
   - Server is completely inaccessible
   - Need to restore from server snapshot

---

## ⏱️ Time Estimates

| Operation | Duration | Server Downtime |
|-----------|----------|-----------------|
| Create backup | 30-60 sec | None |
| Install plugin | 1-2 min | None |
| Restore backup | 1-2 min | None |
| Uninstall plugin | 2-3 min | None |
| Manual rollback | 5-10 min | None |
| Test functionality | 10-15 min | None |

**Total safe testing time:** ~20-30 minutes including all safety checks

---

## 🎓 Recommended Testing Flow

### Phase 1: Setup Safety Net (5 minutes)
1. Create backup: `bash cloudflare.backup.sh`
2. Verify backup: `ls /root/cloudflare_backup_*/`
3. Review backup manifest: `cat /root/cloudflare_backup_*/BACKUP_MANIFEST.txt`

### Phase 2: Install & Test (15 minutes)
4. Install plugin: `bash cloudflare.install.sh`
5. Verify installation: Check cPanel UI
6. Create test API token at Cloudflare
7. Test token verification in plugin
8. Test basic DNS operations (optional)

### Phase 3: Rollback Test (5 minutes)
9. Test uninstall: `bash cloudflare.uninstall.sh` (with backup)
10. Verify removal: Check cPanel UI
11. Test restore: `cd /root/cloudflare_backup_*/ && bash RESTORE.sh`
12. Verify restore: Check cPanel UI

### Phase 4: Final Decision
- **Keep it:** Leave installed, start using
- **Remove it:** Run `bash cloudflare.uninstall.sh` (no backup)
- **Try later:** Keep backup for future testing

---

## ✨ You're Ready!

With these safety measures in place, you can **confidently test the plugin** on your server:

✅ **Multiple rollback options**
✅ **Automatic restore script**
✅ **Clean uninstall available**
✅ **No risk to websites/data**
✅ **Documented procedures**
✅ **Quick recovery time (1-2 min)**

**Questions answered?** You now have a **clear path to roll back** if anything compromises your test server!

---

**Start here:** `bash cloudflare.backup.sh`
