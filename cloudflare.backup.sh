#!/bin/bash

#
# Cloudflare cPanel Plugin Backup Script
# Creates a complete backup before installation/upgrade
#

echo "=============================================="
echo "Cloudflare cPanel Plugin Backup Utility"
echo "=============================================="
echo ""

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: You must run this backup script as root."
    exit 1
fi

BACKUP_DIR="/root/cloudflare_backup_$(date +%Y%m%d_%H%M%S)"
INSTALL_DIR="/usr/local/cpanel"

echo "Creating backup in: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Function to check if file/directory exists and back it up
backup_if_exists() {
    local SOURCE=$1
    local DEST_NAME=$2

    if [ -e "$SOURCE" ]; then
        echo "→ Backing up: $SOURCE"
        cp -r "$SOURCE" "$BACKUP_DIR/$DEST_NAME" 2>/dev/null
        return 0
    fi
    return 1
}

# Backup existing plugin files (if any)
echo ""
echo "Backing up existing plugin files..."
backup_if_exists "$INSTALL_DIR/base/frontend/jupiter/cloudflare" "plugin_jupiter"
backup_if_exists "$INSTALL_DIR/base/frontend/paper_lantern/cloudflare" "plugin_paper_lantern"

# Get PHP version and backup PHP files
CPANELSUPPORTEDPHPPATH=$(ls -al $INSTALL_DIR/3rdparty/bin/php 2>/dev/null | awk '{print $11}')
PHPVERSION=$(echo $CPANELSUPPORTEDPHPPATH | rev | cut -d '/' -f 3 | rev)

if [ -n "$PHPVERSION" ]; then
    backup_if_exists "$INSTALL_DIR/3rdparty/php/$PHPVERSION/lib/php/cloudflare" "plugin_php_$PHPVERSION"
fi

# Backup Perl module
backup_if_exists "$INSTALL_DIR/Cpanel/API/CloudFlare.pm" "CloudFlare.pm"

# Backup scripts
backup_if_exists "$INSTALL_DIR/bin/cloudflare_update.sh" "cloudflare_update.sh"
backup_if_exists "$INSTALL_DIR/bin/admin/CloudFlare" "adminbin_CloudFlare"

# Backup deprecated host key (if exists)
backup_if_exists "/root/.cpanel/datastore/cf_api" "cf_api_hostkey"

# Backup user data files
echo ""
echo "Backing up user data files..."
USER_DATA_COUNT=0
for USER_HOME in /home/*; do
    YAML_FILE="$USER_HOME/.cpanel/datastore/cloudflare_data.yaml"
    if [ -f "$YAML_FILE" ]; then
        USERNAME=$(basename "$USER_HOME")
        mkdir -p "$BACKUP_DIR/user_data/$USERNAME"
        cp "$YAML_FILE" "$BACKUP_DIR/user_data/$USERNAME/cloudflare_data.yaml"
        USER_DATA_COUNT=$((USER_DATA_COUNT + 1))
        echo "→ Backed up data for user: $USERNAME"
    fi
done

if [ $USER_DATA_COUNT -eq 0 ]; then
    echo "  (No user data found)"
fi

# Backup cron jobs
echo ""
echo "Backing up cron configuration..."
crontab -l > "$BACKUP_DIR/root_crontab.txt" 2>/dev/null

# Backup postupcp hook
if [ -f "/scripts/postupcp" ]; then
    grep -A 2 -B 2 "cloudflare" /scripts/postupcp > "$BACKUP_DIR/postupcp_cloudflare.txt" 2>/dev/null
fi

# Create backup manifest
echo ""
echo "Creating backup manifest..."
cat > "$BACKUP_DIR/BACKUP_MANIFEST.txt" << EOF
Cloudflare cPanel Plugin Backup
================================
Backup Date: $(date)
Server: $(hostname)
cPanel Version: $(cat /usr/local/cpanel/version 2>/dev/null || echo "Unknown")
PHP Version: $PHPVERSION

Files Backed Up:
----------------
EOF

find "$BACKUP_DIR" -type f -o -type d | while read -r FILE; do
    echo "  ${FILE#$BACKUP_DIR/}" >> "$BACKUP_DIR/BACKUP_MANIFEST.txt"
done

# Create restore script
cat > "$BACKUP_DIR/RESTORE.sh" << 'RESTORE_EOF'
#!/bin/bash
#
# Restore script - Use this to rollback to the backup
#

echo "=============================================="
echo "Cloudflare cPanel Plugin Restore Utility"
echo "=============================================="
echo ""

BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/usr/local/cpanel"

echo "Restoring from: $BACKUP_DIR"
echo ""
read -p "This will overwrite current plugin files. Continue? (y/n): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Restore plugin files
if [ -d "$BACKUP_DIR/plugin_jupiter" ]; then
    echo "→ Restoring Jupiter theme files..."
    cp -r "$BACKUP_DIR/plugin_jupiter" "$INSTALL_DIR/base/frontend/jupiter/cloudflare"
fi

if [ -d "$BACKUP_DIR/plugin_paper_lantern" ]; then
    echo "→ Restoring Paper Lantern theme files..."
    cp -r "$BACKUP_DIR/plugin_paper_lantern" "$INSTALL_DIR/base/frontend/paper_lantern/cloudflare"
fi

# Restore PHP files
for PHP_BACKUP in "$BACKUP_DIR"/plugin_php_*; do
    if [ -d "$PHP_BACKUP" ]; then
        PHPVER=$(basename "$PHP_BACKUP" | sed 's/plugin_php_//')
        echo "→ Restoring PHP files (PHP $PHPVER)..."
        mkdir -p "$INSTALL_DIR/3rdparty/php/$PHPVER/lib/php"
        cp -r "$PHP_BACKUP" "$INSTALL_DIR/3rdparty/php/$PHPVER/lib/php/cloudflare"
    fi
done

# Restore Perl module
if [ -f "$BACKUP_DIR/CloudFlare.pm" ]; then
    echo "→ Restoring Perl module..."
    cp "$BACKUP_DIR/CloudFlare.pm" "$INSTALL_DIR/Cpanel/API/CloudFlare.pm"
fi

# Restore scripts
if [ -f "$BACKUP_DIR/cloudflare_update.sh" ]; then
    echo "→ Restoring update script..."
    cp "$BACKUP_DIR/cloudflare_update.sh" "$INSTALL_DIR/bin/cloudflare_update.sh"
    chmod +x "$INSTALL_DIR/bin/cloudflare_update.sh"
fi

if [ -d "$BACKUP_DIR/adminbin_CloudFlare" ]; then
    echo "→ Restoring adminbin..."
    cp -r "$BACKUP_DIR/adminbin_CloudFlare" "$INSTALL_DIR/bin/admin/CloudFlare"
fi

# Restore host key (if exists)
if [ -f "$BACKUP_DIR/cf_api_hostkey" ]; then
    echo "→ Restoring host key..."
    mkdir -p /root/.cpanel/datastore
    cp "$BACKUP_DIR/cf_api_hostkey" "/root/.cpanel/datastore/cf_api"
    chmod 600 "/root/.cpanel/datastore/cf_api"
fi

# Restore user data
if [ -d "$BACKUP_DIR/user_data" ]; then
    echo "→ Restoring user data..."
    for USER_BACKUP in "$BACKUP_DIR/user_data"/*; do
        if [ -d "$USER_BACKUP" ]; then
            USERNAME=$(basename "$USER_BACKUP")
            if [ -d "/home/$USERNAME" ]; then
                mkdir -p "/home/$USERNAME/.cpanel/datastore"
                cp "$USER_BACKUP/cloudflare_data.yaml" "/home/$USERNAME/.cpanel/datastore/cloudflare_data.yaml"
                chown "$USERNAME:$USERNAME" "/home/$USERNAME/.cpanel/datastore/cloudflare_data.yaml"
                echo "  ✓ Restored data for: $USERNAME"
            fi
        fi
    done
fi

# Restore cron (manual - requires user review)
if [ -f "$BACKUP_DIR/root_crontab.txt" ]; then
    echo ""
    echo "NOTE: Cron jobs were backed up to: $BACKUP_DIR/root_crontab.txt"
    echo "      Review and restore manually if needed: crontab $BACKUP_DIR/root_crontab.txt"
fi

echo ""
echo "=============================================="
echo "Restore Complete!"
echo "=============================================="
echo ""
echo "You may need to restart cPanel services:"
echo "  service cpanel restart"
echo ""
RESTORE_EOF

chmod +x "$BACKUP_DIR/RESTORE.sh"

echo ""
echo "=============================================="
echo "Backup Complete!"
echo "=============================================="
echo ""
echo "Backup saved to: $BACKUP_DIR"
echo ""
echo "Contents:"
echo "  - Plugin files (Jupiter & Paper Lantern themes)"
echo "  - PHP backend files"
echo "  - Perl module"
echo "  - User data ($USER_DATA_COUNT users)"
echo "  - Configuration files"
echo "  - BACKUP_MANIFEST.txt (full inventory)"
echo "  - RESTORE.sh (automatic restore script)"
echo ""
echo "To restore this backup later:"
echo "  cd $BACKUP_DIR"
echo "  bash RESTORE.sh"
echo ""
echo "You can now proceed with installation/upgrade."
echo ""
