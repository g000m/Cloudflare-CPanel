#!/bin/bash

#
# CloudFlare cPanel Install Script (v8.0+)
# Token-based authentication - No host key required
#

INSTALLER="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

usage() {
    echo "Usage: ./$INSTALLER [-f /path/to/local/cpanel.tar.gz] [-v]"
    echo
    echo "Install the Cloudflare cPanel plugin (v8.0+ with token-based authentication)."
    echo
    echo "Options:"
    echo "     -f LOCAL_FILE - Install from a local file instead of downloading from GitHub."
    echo "                     The local file should be named CloudFlare-CPanel-X.Y.Z.tar.gz"
    echo "     -v            - Verbose output"
    echo
    echo "After installation, users will configure their Cloudflare API tokens"
    echo "through the cPanel interface."
    echo
    echo "To create an API token:"
    echo "  1. Log in to the Cloudflare dashboard"
    echo "  2. Go to My Profile > API Tokens"
    echo "  3. Create a token with permissions: Zone:DNS:Edit, Zone:Zone:Read, Zone:Zone Settings:Edit"
    echo
    exit 1
}

# Parse the arguments
LOCAL_FILE_PATH=""
VERBOSE=false

while getopts ":f:v" opt; do
    case $opt in
        f)
            if [ "$LOCAL_FILE_PATH" = "" ]; then
                LOCAL_FILE_PATH=$OPTARG
            fi
            ;;
        v)
            VERBOSE=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
         :)
            echo "Option -$OPTARG requires an argument" >&2
            exit 1
            ;;
    esac
done

if [ "$VERBOSE" = true ]; then
    echo "LOCAL_FILE_PATH = '$LOCAL_FILE_PATH'"
fi

# Check that we're running as root (or "effectively" as root, i.e., euid=0)
if [[ $EUID -ne 0 ]]; then
    echo "You must run this installation script as root."
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    echo "Running as root"
fi

echo "Starting CloudFlare CPanel Installation..."

#
# If not installing from a local file we need to download and untar
#
if [ "$LOCAL_FILE_PATH" = "" ]; then

    # Find the proper version to download from GitHub Releases API
    echo "Fetching latest version from GitHub..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/g000m/Cloudflare-CPanel/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

    if [ "$VERBOSE" = true ]; then
        echo "LATEST_VERSION - '$LATEST_VERSION'"
    fi

    if [ -z "$LATEST_VERSION" ]; then
      echo -e "ERROR: Could not find latest version from GitHub releases.\n"
      echo "Please check your internet connection or use the -f flag to install from a local file."
      usage
    else
      echo "Downloading and unpacking latest version v$LATEST_VERSION..."
    fi

    # Download and extract
    DOWNLOAD_URL="https://github.com/g000m/Cloudflare-CPanel/archive/v$LATEST_VERSION.tar.gz"

    if [ "$VERBOSE" = true ]; then
        echo "curl -sL $DOWNLOAD_URL | tar xzf -"
    fi

    curl -sL $DOWNLOAD_URL | tar xzf -

    # We could check for extract errors here, but the directory check outside
    # the if statement will take care of this

#
# We're installing from a local file
#
else

    # Check to make sure the file exists
    if [ ! -f $LOCAL_FILE_PATH ]; then
        echo "ERROR - Not found '$LOCAL_FILE_PATH'"
        exit 1
    fi

    # We expect the file to be named like so: 'Cloudflare-CPanel-$LATEST_VERSION.tar.gz'
    # for example Cloudflare-CPanel-1.2.3.tar.gz
    FNAME=$(basename "$LOCAL_FILE_PATH");
    LATEST_VERSION=$(echo -n "$FNAME" | sed 's/^Cloudflare-CPanel-//' | sed 's/.tar.gz//')

    if [ "$VERBOSE" = true ]; then
        echo "LATEST_VERSION - '$LATEST_VERSION'"
    fi

    echo "Unpacking from local tar file '$LOCAL_FILE_PATH'"
    tar xfz $LOCAL_FILE_PATH

    # We could check for extract errors here, but the directory check outside
    # the if statement will take care of this

fi

# Make sure that the tar directory got created correctly. We expect a directory
# name something like this: Cloudflare-CPanel-$LATEST_VERSION/cloudflare

if [ ! -d "Cloudflare-CPanel-$LATEST_VERSION" ]; then
    echo "ERROR - Unpack failed, directory not found: 'Cloudflare-CPanel-$LATEST_VERSION'"
    exit 1
fi

SOURCE_DIR="Cloudflare-CPanel-$LATEST_VERSION"
INSTALL_DIR="/usr/local/cpanel"

if [ "$VERBOSE" = true ]; then
    echo "Installing from '$SOURCE_DIR' to '$INSTALL_DIR'"
fi

# Install frontend files to both Paper Lantern and Jupiter themes for compatibility
# Paper Lantern theme (legacy, cPanel < 100)
install -d $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
install $SOURCE_DIR/proxy.live.php $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
install $SOURCE_DIR/index.live.php $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
install $SOURCE_DIR/compiled.js $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
install $SOURCE_DIR/config.json.sample $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
install $SOURCE_DIR/composer.json $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
install -d $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/lang
install $SOURCE_DIR/lang/* $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/lang
install -d $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/assets
install $SOURCE_DIR/assets/* $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/assets
install -d $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/fonts
install $SOURCE_DIR/fonts/* $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/fonts
install -d $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/stylesheets
install $SOURCE_DIR/stylesheets/* $INSTALL_DIR/base/frontend/paper_lantern/cloudflare/stylesheets

# Jupiter theme (current, cPanel >= 100)
echo "Installing to Jupiter theme..."
install -d $INSTALL_DIR/base/frontend/jupiter/cloudflare
install $SOURCE_DIR/proxy.live.php $INSTALL_DIR/base/frontend/jupiter/cloudflare
install $SOURCE_DIR/index.live.php $INSTALL_DIR/base/frontend/jupiter/cloudflare
install $SOURCE_DIR/compiled.js $INSTALL_DIR/base/frontend/jupiter/cloudflare
install $SOURCE_DIR/config.json.sample $INSTALL_DIR/base/frontend/jupiter/cloudflare
install $SOURCE_DIR/composer.json $INSTALL_DIR/base/frontend/jupiter/cloudflare
install -d $INSTALL_DIR/base/frontend/jupiter/cloudflare/lang
install $SOURCE_DIR/lang/* $INSTALL_DIR/base/frontend/jupiter/cloudflare/lang
install -d $INSTALL_DIR/base/frontend/jupiter/cloudflare/assets
install $SOURCE_DIR/assets/* $INSTALL_DIR/base/frontend/jupiter/cloudflare/assets
install -d $INSTALL_DIR/base/frontend/jupiter/cloudflare/fonts
install $SOURCE_DIR/fonts/* $INSTALL_DIR/base/frontend/jupiter/cloudflare/fonts
install -d $INSTALL_DIR/base/frontend/jupiter/cloudflare/stylesheets
install $SOURCE_DIR/stylesheets/* $INSTALL_DIR/base/frontend/jupiter/cloudflare/stylesheets

# Install the CloudFlare.pm file (Perl module for cPanel integration)
install -d $INSTALL_DIR/Cpanel/API
install $SOURCE_DIR/CloudFlare.pm $INSTALL_DIR/Cpanel/API

# Get PHP Version
CPANELSUPPORTEDPHPPATH=`ls -l $INSTALL_DIR/3rdparty/bin/php`
PHPVERSION=`echo $CPANELSUPPORTEDPHPPATH | rev | cut -d '/' -f 3 | rev`

# Install PHP code
install -d $INSTALL_DIR/3rdparty/php/$PHPVERSION/lib/php/cloudflare/vendor
/bin/cp -rf $SOURCE_DIR/vendor/* $INSTALL_DIR/3rdparty/php/$PHPVERSION/lib/php/cloudflare/vendor
install -d $INSTALL_DIR/3rdparty/php/$PHPVERSION/lib/php/cloudflare/src
/bin/cp -rf $SOURCE_DIR/src/* $INSTALL_DIR/3rdparty/php/$PHPVERSION/lib/php/cloudflare/src

# Register the plugin buttons with Cpanel
/usr/local/cpanel/scripts/install_plugin $SOURCE_DIR/installers/cloudflare_simple.tar.bz2

# Copy cloudflare_update.sh to where the cron expects it to be
install $SOURCE_DIR/cloudflare_update.sh $INSTALL_DIR/bin

# Create CPanel hook to update plugin after Cpanel Update
CF_ON_UPGRADE=`grep -F "cloudflare_update" /scripts/postupcp`
if [ "$CF_ON_UPGRADE" == "" ]; then
    echo "sh /usr/local/cpanel/bin/cloudflare_update.sh force" >> /scripts/postupcp
fi

# Create cron job to automatically update plugin
iscf=`crontab -l | grep cloudflare`
if [ "$iscf" == "" ]; then
    crontab -l > c.cur
    echo "12 2 * * 0 /usr/local/cpanel/bin/cloudflare_update.sh >/dev/null 2>&1" >> c.cur
    crontab c.cur
fi

echo "Cleaning up"
rm -rf "CloudFlare-CPanel-$LATEST_VERSION"

echo ""
echo "=========================================="
echo "Cloudflare cPanel Plugin v8.0+ Installed!"
echo "=========================================="
echo ""
echo "IMPORTANT: This version uses token-based authentication."
echo ""
echo "Next steps for users:"
echo "  1. Log in to cPanel"
echo "  2. Navigate to the Cloudflare plugin"
echo "  3. Create an API token at: https://dash.cloudflare.com/profile/api-tokens"
echo "     Required permissions:"
echo "     - Zone:DNS:Edit"
echo "     - Zone:Zone:Read"
echo "     - Zone:Zone Settings:Edit"
echo "  4. Enter the API token in the plugin interface"
echo ""
echo "Installation complete!"
echo ""
