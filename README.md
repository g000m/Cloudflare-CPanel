# Cloudflare cPanel Plugin (v8.0+)

**Modern token-based authentication • PHP 7.4+ support • cPanel 100+ Jupiter theme compatible**

This is a revived and modernized version of the Cloudflare cPanel integration, updated with token-based authentication and compatibility with modern PHP versions and cPanel releases.

## Features

- ✅ **Token-based authentication** - No host key or partnership program required
- ✅ **Modern PHP support** - PHP 7.4, 8.0, 8.1, 8.2, 8.3
- ✅ **Latest cPanel** - Full support for cPanel 100+ with Jupiter theme
- ✅ **Legacy compatibility** - Also supports Paper Lantern theme
- ✅ **Cloudflare API v4** - Uses latest Cloudflare APIs
- ✅ **Zone management** - Both full zone and partial (CNAME) setup
- ✅ **DNS management** - Create, edit, delete DNS records
- ✅ **Security settings** - SSL/TLS, firewall rules, caching options
- ✅ **Multi-language** - English, German, Spanish, French, Italian, Dutch, Portuguese

## Requirements

- **cPanel**: Version 100+ recommended (Jupiter theme), 90+ supported (Paper Lantern)
- **PHP**: 7.4, 8.0, 8.1, 8.2, or 8.3
- **Operating System**: RHEL-based (CentOS, AlmaLinux, Rocky Linux) or Ubuntu
- **Root Access**: Required for installation
- **Cloudflare Account**: Free or paid account with API token access

## 🛡️ Safety & Rollback

**Testing on a production server?** We've got you covered with comprehensive backup and rollback tools:

### Before Installation: Create a Backup
```bash
wget https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.backup.sh
bash cloudflare.backup.sh
```

This creates a complete backup with an **automatic restore script** for instant rollback.

### If Something Goes Wrong: Instant Rollback
```bash
cd /root/cloudflare_backup_*/
bash RESTORE.sh  # One command - back to previous state
```

### Complete Removal: Clean Uninstall
```bash
bash <(curl -s https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.uninstall.sh)
```

**📖 Full Safety Guide:** See [ROLLBACK_GUIDE.md](ROLLBACK_GUIDE.md) for:
- Pre-installation checklist
- Multiple rollback strategies
- Troubleshooting procedures
- Emergency recovery steps

**✅ Safe to test:** The plugin only modifies plugin files. Your websites, databases, and email remain untouched.

## Installation

### Quick Installation

Using an SSH client (Terminal, PuTTY, etc.):

**Step 1:** Access your server as root
```bash
ssh root@YOUR_SERVER_IP
```

**Step 2:** Run the installation script
```bash
bash <(curl -s https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.install.sh)
```

The installer will:
- Auto-detect the latest version from GitHub
- Install to both Jupiter and Paper Lantern themes
- Set up automatic weekly updates
- Configure cPanel integration

### Manual Installation

If you prefer to install from a local file:

```bash
wget https://github.com/g000m/Cloudflare-CPanel/archive/v8.0.0.tar.gz
bash cloudflare.install.sh -f v8.0.0.tar.gz
```

## Initial Configuration

### For Users: Creating a Cloudflare API Token

After installation, each cPanel user must create their own Cloudflare API token:

**Step 1:** Log in to the Cloudflare dashboard
Visit: https://dash.cloudflare.com/

**Step 2:** Navigate to API Tokens
Go to: **My Profile** > **API Tokens**

**Step 3:** Create a new token
Click **"Create Token"**

**Step 4:** Configure permissions
Your token needs these permissions:
- **Zone** > **DNS** > **Edit**
- **Zone** > **Zone** > **Read**
- **Zone** > **Zone Settings** > **Edit**

**Recommended token template:** Use the "Edit zone DNS" template and add Zone:Read and Zone Settings:Edit permissions.

**Step 5:** Set zone resources
Choose which zones this token can access:
- **All zones** (easiest for users with multiple domains)
- **Specific zones** (more secure, select individual domains)

**Step 6:** Create and copy the token
Click **"Create Token"** and **copy the generated token** (you'll only see it once!)

**Step 7:** Enter token in cPanel
- Log in to cPanel
- Find the **Cloudflare** icon (usually in "Domains" or "Advanced" section)
- Paste your API token when prompted
- Click **"Verify"** to confirm it works

## Usage

### Adding a Domain to Cloudflare

**Full Zone Setup (Recommended):**
1. In cPanel, navigate to the Cloudflare plugin
2. Select your domain
3. Click "Add Site"
4. Cloudflare will provide nameservers
5. Update your domain registrar to use Cloudflare nameservers

**Partial Zone Setup (CNAME):**
1. Enable in `config.json` (see Configuration section)
2. Select partial/CNAME setup option
3. Plugin will automatically create required CNAME records
4. Subdomains will be proxied through Cloudflare

### Managing DNS Records

- View all DNS records for your domain
- Add new records (A, AAAA, CNAME, MX, TXT, etc.)
- Edit existing records
- Enable/disable Cloudflare proxy (orange cloud)
- Set TTL values

### Cloudflare Settings

Configure these settings directly from cPanel:
- **Security Level** - Adjust visitor challenge level
- **SSL/TLS Mode** - Off, Flexible, Full, Full (Strict)
- **Always Online** - Serve cached pages when origin is down
- **Development Mode** - Bypass cache for testing
- **Browser Cache TTL** - Control browser caching
- **Minification** - Compress HTML, CSS, JavaScript
- **Rocket Loader** - Async JavaScript loading

## Configuration

### Optional Configuration File

Create `/usr/local/cpanel/base/frontend/[THEME]/cloudflare/config.json` to customize:

```json
{
  "debug": false,
  "featureManagerIsFullZoneProvisioningEnabled": true,
  "locale": "en"
}
```

**Available options:**
- `debug` - Enable debug logging (default: false)
- `featureManagerIsFullZoneProvisioningEnabled` - Allow full zone setup (default: true)
- `locale` - Language code: en, de, es, fr, it, nl, pt (default: en)

Replace `[THEME]` with `jupiter` or `paper_lantern` depending on your cPanel theme.

## Localization

The plugin supports multiple languages:
- **en** - English (default, always up to date)
- **de** - German
- **es** - Spanish
- **fr** - French
- **it** - Italian
- **nl** - Dutch
- **pt** - Portuguese

### Adding a New Language

1. Copy `lang/en.js` to `lang/[LANGUAGE_CODE].js`
2. Translate all strings in the new file
3. Create `config.json` (see Configuration section)
4. Set `"locale": "[LANGUAGE_CODE]"`

## Uninstalling

To remove the plugin completely:

```bash
bash <(curl -s https://raw.githubusercontent.com/g000m/Cloudflare-CPanel/main/cloudflare.uninstall.sh)
```

**Note:** This removes the plugin from the server but does **not** remove zones or DNS records from your Cloudflare account.

## Upgrading from v7.x

**⚠️ Breaking Change:** Version 8.0 introduces token-based authentication and is **not** compatible with v7.x installations.

### Migration Steps:

1. **Backup your data** - Export zone information from Cloudflare dashboard
2. **Run the new installer** - It will overwrite v7.x files
3. **Create API tokens** - Each user must create a new API token (see Initial Configuration)
4. **Re-configure zones** - Users may need to re-add their zones

The old global API keys and host keys are no longer supported.

## Troubleshooting

### Plugin not appearing in cPanel
- Check that installation completed successfully
- Verify plugin is registered: `/usr/local/cpanel/bin/manage_plugins list`
- Check theme directory exists for your active theme (Jupiter or Paper Lantern)
- Restart cPanel: `service cpanel restart`

### API token invalid
- Verify token has correct permissions (see Initial Configuration)
- Check token hasn't expired
- Ensure token is for the correct Cloudflare account
- Token must have access to the zones you're trying to manage

### DNS records not syncing
- Verify "Advanced DNS Zone Editor" is enabled in cPanel
- Check cPanel error logs: `/usr/local/cpanel/logs/error_log`
- Verify Cloudflare API is accessible from your server
- Check for firewall rules blocking Cloudflare API

### PHP compatibility issues
- Verify PHP version: `php -v` (must be 7.4+)
- Check composer dependencies installed: `composer.json` in plugin directory
- Review PHP error logs in cPanel

## Development

### Requirements for Development
- PHP 7.4 or higher
- Composer
- PHPUnit 10+ for testing
- Access to a cPanel test server

### Running Tests
```bash
composer install
composer test
```

### Linting
```bash
composer lint
```

### Formatting
```bash
composer format
```

## Version History

### v8.0.0-alpha (2025-01-15)
- 🎉 **Major Release**: Revival of abandoned plugin
- ✨ Token-based authentication (replaces deprecated Host API)
- ✨ PHP 7.4-8.3 support
- ✨ Guzzle 7.x HTTP client
- ✨ cPanel 130+ Jupiter theme support
- ✨ Modern Cloudflare API v4
- 🔒 Removed deprecated Host API dependencies
- 📦 Updated all dependencies to modern versions
- 🚀 Simplified installation (no host key required)

### v7.0.1 (2019-xx-xx)
- Last release before deprecation
- Used deprecated Host API
- PHP 5.6+ support

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

- **Issues**: https://github.com/g000m/Cloudflare-CPanel/issues
- **Cloudflare Docs**: https://developers.cloudflare.com/
- **cPanel Docs**: https://docs.cpanel.net/

## License

BSD-3-Clause License

Copyright (c) 2025, Cloudflare cPanel Plugin Contributors

See LICENSE file for full details.

## Credits

- Original plugin by Cloudflare, Inc.
- Revived and modernized by the community
- Built with ❤️ for the cPanel and Cloudflare communities

---

**Note**: This is a community-maintained fork of the original CloudFlare cPanel plugin. It is not officially affiliated with or endorsed by Cloudflare, Inc. or cPanel, LLC.
