#!/bin/bash

#
# Cloudflare cPanel Plugin Uninstall Script (v8.0+)
#

echo "============================================"
echo "Cloudflare cPanel Plugin Uninstaller v8.0+"
echo "============================================"
echo ""

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: You must run this uninstall script as root."
    exit 1
fi

INSTALL_DIR="/usr/local/cpanel"

# Offer backup option
read -p "Do you want to backup user data before uninstalling? (y/n): " BACKUP_CHOICE
if [[ $BACKUP_CHOICE =~ ^[Yy]$ ]]; then
    BACKUP_DIR="/root/cloudflare_backup_$(date +%Y%m%d_%H%M%S)"
    echo "Creating backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"

    # Backup user YAML files
    find /home -name "cloudflare_data.yaml" -path "*/.cpanel/datastore/*" -exec cp --parents {} "$BACKUP_DIR" \; 2>/dev/null

    # Backup plugin files for reference
    if [ -d "$INSTALL_DIR/base/frontend/jupiter/cloudflare" ]; then
        cp -r "$INSTALL_DIR/base/frontend/jupiter/cloudflare" "$BACKUP_DIR/plugin_files_jupiter" 2>/dev/null
    fi
    if [ -d "$INSTALL_DIR/base/frontend/paper_lantern/cloudflare" ]; then
        cp -r "$INSTALL_DIR/base/frontend/paper_lantern/cloudflare" "$BACKUP_DIR/plugin_files_paper_lantern" 2>/dev/null
    fi

    echo "✓ Backup created at: $BACKUP_DIR"
    echo ""
fi

echo "Uninstalling Cloudflare cPanel plugin..."

# Get PHP Version
CPANELSUPPORTEDPHPPATH=$(ls -al $INSTALL_DIR/3rdparty/bin/php 2>/dev/null | awk '{print $11}')
PHPVERSION=$(echo $CPANELSUPPORTEDPHPPATH | rev | cut -d '/' -f 3 | rev)

# Remove frontend files (both themes)
echo "→ Removing frontend files..."
rm -rf "$INSTALL_DIR/base/frontend/paper_lantern/cloudflare" 2>/dev/null
rm -rf "$INSTALL_DIR/base/frontend/jupiter/cloudflare" 2>/dev/null
rm -f "$INSTALL_DIR/base/frontend/paper_lantern/dynamicui/dynamicui_cloudflare"*.conf 2>/dev/null
rm -f "$INSTALL_DIR/base/frontend/jupiter/dynamicui/dynamicui_cloudflare"*.conf 2>/dev/null

# Remove PHP backend files
if [ -n "$PHPVERSION" ]; then
    echo "→ Removing PHP backend files (PHP $PHPVERSION)..."
    rm -rf "$INSTALL_DIR/3rdparty/php/$PHPVERSION/lib/php/cloudflare" 2>/dev/null
fi

# Remove Perl module
echo "→ Removing Perl module..."
rm -f "$INSTALL_DIR/Cpanel/API/CloudFlare.pm" 2>/dev/null

# Remove deprecated host key file (v7.x legacy)
if [ -f "/root/.cpanel/datastore/cf_api" ]; then
    echo "→ Removing deprecated host key file..."
    rm -f "/root/.cpanel/datastore/cf_api" 2>/dev/null
fi

# Remove adminbin (v7.x legacy)
rm -rf "$INSTALL_DIR/bin/admin/CloudFlare" 2>/dev/null

# Remove update script
echo "→ Removing update script..."
rm -f "$INSTALL_DIR/bin/cloudflare_update.sh" 2>/dev/null

# Remove post-update hook
echo "→ Removing cPanel update hook..."
cfonupgrade=$(grep -F "cloudflare_update" /scripts/postupcp 2>/dev/null)
if [ -n "$cfonupgrade" ]; then
    sed -i '/cloudflare_update.sh/d' /scripts/postupcp
fi

# Remove cron job
echo "→ Removing auto-update cron job..."
crontab -l 2>/dev/null | grep -v "cloudflare_update.sh" | crontab - 2>/dev/null

# Unregister plugin with cPanel
echo "→ Unregistering plugin with cPanel..."
if [ -f "/usr/local/cpanel/scripts/uninstall_plugin" ]; then
    /usr/local/cpanel/scripts/uninstall_plugin cloudflare 2>/dev/null
fi

echo ""
echo "============================================"
echo "Cloudflare cPanel Plugin Uninstalled!"
echo "============================================"
echo ""
echo "IMPORTANT NOTES:"
echo "- Plugin files have been removed from the server"
echo "- User Cloudflare data files (~/.cpanel/datastore/cloudflare_data.yaml) were NOT deleted"
echo "- Zones and DNS records in Cloudflare accounts were NOT affected"
echo ""

if [[ $BACKUP_CHOICE =~ ^[Yy]$ ]]; then
    echo "- Backup saved at: $BACKUP_DIR"
    echo "  To restore, manually copy files back from this location"
    echo ""
fi

echo "To reinstall, run: bash cloudflare.install.sh"
echo ""
