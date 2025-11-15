# Migration Plan: Host API to Token-Based Authentication

## Overview
This document outlines the strategy for migrating from the deprecated Cloudflare Host API to modern API token-based authentication for PHP 7.4+ compatibility.

## Current State Analysis

### Authentication Flow (Host API - DEPRECATED)
1. **Installation**: Requires `HOST_KEY` parameter
   - Stored in `/root/.cpanel/datastore/cf_api`
   - Used to query Host API for version info and user provisioning

2. **User Onboarding** (via `HostActions.php`):
   - `userCreate()`: Creates new Cloudflare account via `host-gw.html?act=user_create`
   - `userAuth()`: Authenticates existing account via `host-gw.html?act=user_auth`
   - Returns: `user_api_key` (Global API Key), `cloudflare_email`, `unique_id`, `user_key`

3. **Data Storage** (via `DataStore.php`):
   ```yaml
   # ~/.cpanel/datastore/cloudflare_data.yaml
   client_api_key: "xxx"         # Global API Key
   cloudflare_email: "user@example.com"
   host_user_unique_id: "xxx"    # Host API unique ID
   host_user_key: "xxx"          # Host API user key
   ```

4. **Zone Provisioning**:
   - `partialZoneSet()`: Calls `host-gw.html?act=zone_set` for CNAME setup
   - Uses Host API to provision zones in Cloudflare hosting partner program

### HTTP Client (Guzzle 5.x - INCOMPATIBLE with PHP 7.4+)
- Location: `vendor/cloudflare/cloudflare-plugin-backend/src/API/DefaultHttpClient.php`
- Uses deprecated methods:
  - `base_url` → should be `base_uri`
  - `->json()` → should be `json_decode($response->getBody())`
  - `createRequest()` → should use direct request methods

## Target State

### New Authentication Flow (API Tokens)
1. **Installation**: NO host key required
   - Remove HOST_KEY requirement from install script
   - Get latest version from GitHub releases API instead of Host API

2. **User Onboarding**:
   - User creates API token in Cloudflare dashboard with required permissions:
     - Zone:DNS:Edit
     - Zone:Zone:Read
     - Zone:Zone Settings:Edit
   - User enters API token directly in cPanel plugin UI
   - Plugin verifies token via `GET /client/v4/user/tokens/verify`
   - Plugin fetches user email via `GET /client/v4/user`

3. **Data Storage**:
   ```yaml
   # ~/.cpanel/datastore/cloudflare_data.yaml
   api_token: "xxx"              # Scoped API Token
   cloudflare_email: "user@example.com"
   ```

4. **Zone Provisioning**:
   - Direct Client API v4 calls (no Host API)
   - Full zone: Use `POST /zones` to add zone
   - Partial zone (CNAME): Direct DNS record creation via `POST /zones/{zone_id}/dns_records`

### HTTP Client (Guzzle 7.x - Compatible with PHP 7.4+, 8.x)
- Update all Guzzle HTTP client code
- Use PSR-7 compliant request/response handling

## Implementation Steps

### Phase 1: Update Dependencies

1. **Update `composer.json`**:
   ```json
   {
     "require": {
       "php": "^7.4 || ^8.0 || ^8.1 || ^8.2 || ^8.3",
       "symfony/yaml": "^6.0 || ^7.0",
       "guzzlehttp/guzzle": "^7.0",
       "true/punycode": "^2.0",
       "cloudflare/cloudflare-plugin-backend": "^2.2"
     },
     "require-dev": {
       "phpunit/phpunit": "^10.0 || ^11.0",
       "squizlabs/php_codesniffer": "^3.0"
     }
   }
   ```

2. **Fork/Update `cloudflare-plugin-backend`**:
   - This package is abandoned and uses Guzzle 5.x
   - Option A: Fork and update internally
   - Option B: Vendor the code and update in this repo
   - **Recommended**: Option B (vendor code locally)

### Phase 2: Migrate HTTP Client (Guzzle 5.x → 7.x)

1. **Update `DefaultHttpClient.php`** (from cloudflare-plugin-backend):
   ```php
   // OLD (Guzzle 5.x):
   new GuzzleHttp\Client(['base_url' => $endpoint]);
   $response = $this->client->send($apiRequest)->json();
   $this->client->createRequest($method, $url, $options);

   // NEW (Guzzle 7.x):
   new GuzzleHttp\Client(['base_uri' => $endpoint]);
   $response = $this->client->send($apiRequest);
   $data = json_decode($response->getBody()->getContents(), true);
   new GuzzleHttp\Psr7\Request($method, $url);
   ```

2. **Update Authentication Headers**:
   ```php
   // OLD (Global API Key):
   'X-Auth-Key' => $apiKey,
   'X-Auth-Email' => $email

   // NEW (API Token):
   'Authorization' => 'Bearer ' . $apiToken
   ```

### Phase 3: Replace Host API Authentication

1. **Remove `HostActions.php`** entirely
   - Delete `src/Cpanel/HostActions.php`
   - Delete `src/Cpanel/HostRoutes.php`
   - Delete `vendor/cloudflare/cloudflare-plugin-backend/src/API/Host.php`

2. **Create new `TokenActions.php`**:
   ```php
   class TokenActions
   {
       /**
        * Verify and save API token
        * POST /user/tokens/verify
        */
       public function verifyAndSaveToken($apiToken)
       {
           // 1. Verify token
           $verifyResponse = $this->api->get('/user/tokens/verify', [], $apiToken);

           // 2. Get user email
           $userResponse = $this->api->get('/user', [], $apiToken);

           // 3. Save to DataStore
           $this->dataStore->createUserDataStore($apiToken, $userResponse['email']);

           return $verifyResponse;
       }
   }
   ```

3. **Update `DataStore.php`**:
   ```php
   const API_TOKEN_KEY = 'api_token';
   const EMAIL_KEY = 'cloudflare_email';

   // Remove:
   // - HOST_USER_UNIQUE_ID_KEY
   // - HOST_USER_KEY
   // - CLIENT_API_KEY (Global API Key)

   public function createUserDataStore($apiToken, $email)
   {
       $this->yamlData = array(
           self::API_TOKEN_KEY => $apiToken,
           self::EMAIL_KEY => $email,
       );
       $this->saveYAMLFile();
   }

   public function getAPIToken()
   {
       return $this->get(self::API_TOKEN_KEY);
   }
   ```

### Phase 4: Update Zone Provisioning

1. **Update `Zone/Partial.php`** for CNAME setup:
   ```php
   // OLD: Calls host-gw.html?act=zone_set

   // NEW: Direct DNS record creation
   public function partialZoneSet($subdomain, $zoneName)
   {
       // 1. Get zone ID from Cloudflare (or create if needed)
       $zoneId = $this->getOrCreateZone($zoneName);

       // 2. Create CNAME record pointing to *.cdn.cloudflare.net
       $this->createDNSRecord($zoneId, [
           'type' => 'CNAME',
           'name' => $subdomain,
           'content' => $subdomain . '.cdn.cloudflare.net',
           'proxied' => true
       ]);

       // 3. Create resolve-to record in cPanel DNS
       $this->cpanelAPI->addDNSRecord($zoneName, [
           'type' => 'A',
           'name' => 'cloudflare-resolve-to.' . $zoneName,
           'content' => $this->getOriginIP()
       ]);
   }
   ```

2. **Add Full Zone Support**:
   ```php
   public function fullZoneSet($zoneName)
   {
       // 1. Create zone in Cloudflare
       $response = $this->api->post('/zones', [
           'name' => $zoneName,
           'jump_start' => true  // Auto-fetch DNS records
       ]);

       // 2. Return nameservers for user to update
       return $response['result']['name_servers'];
   }
   ```

### Phase 5: Update Installation Script

1. **Remove Host Key Requirement** (`cloudflare.install.sh`):
   ```bash
   # OLD:
   usage() {
       echo "Usage: ./$INSTALLER -k HOST_KEY -n 'ORG_NAME'"
   }

   # NEW:
   usage() {
       echo "Usage: ./$INSTALLER"
       echo ""
       echo "Install the Cloudflare cPanel plugin."
       echo "After installation, users will configure their API tokens in the UI."
   }
   ```

2. **Update Version Detection**:
   ```bash
   # OLD: Query deprecated Host API
   LATEST_VERSION=$(curl -s https://api.cloudflare.com/host-gw.html -d "act=cpanel_info" -d "host_key=$HOST_KEY" | ...)

   # NEW: Use GitHub Releases API
   LATEST_VERSION=$(curl -s https://api.github.com/repos/cloudflare/CloudFlare-CPanel/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
   ```

3. **Remove Host Key Storage**:
   ```bash
   # DELETE:
   echo $HOST_KEY > /root/.cpanel/datastore/cf_api
   chmod 600 /root/.cpanel/datastore/cf_api
   ```

4. **Remove Perl Module Host Key Access**:
   - Update `CloudFlare.pm` to remove `getHostApiKey()` function
   - Delete `APIKey` adminbin script
   - Update `CpanelAPI.php` to remove `getHostAPIKey()` method

### Phase 6: Update Frontend for Jupiter Theme

1. **Add Jupiter Theme Support**:
   ```bash
   # In cloudflare.install.sh, detect theme and install to both:
   install -d $INSTALL_DIR/base/frontend/paper_lantern/cloudflare
   install -d $INSTALL_DIR/base/frontend/jupiter/cloudflare
   ```

2. **Update UI for Token Input**:
   - Modify frontend to show token input field instead of email/password
   - Add link to Cloudflare dashboard to create token
   - Add instructions for required token permissions:
     - Zone:DNS:Edit
     - Zone:Zone:Read
     - Zone:Zone Settings:Edit

### Phase 7: Update Client API Calls

1. **Update `Client.php`** (from cloudflare-plugin-backend):
   ```php
   // Change authentication from Global API Key to Token
   private function setAuthHeaders($apiToken)
   {
       $this->headers['Authorization'] = 'Bearer ' . $apiToken;
       // Remove:
       // $this->headers['X-Auth-Key'] = ...
       // $this->headers['X-Auth-Email'] = ...
   }
   ```

2. **Update all API calls** in `ClientActions.php`:
   - Verify all endpoints are using v4 API
   - Update any deprecated endpoints
   - Use latest Cloudflare API features

## Cloudflare API Endpoints Used

### Current Endpoints (Verify Still Valid)
- `GET /zones` - List zones ✅
- `GET /zones/{id}` - Get zone details ✅
- `DELETE /zones/{id}` - Delete zone ✅
- `GET /zones/{id}/dns_records` - List DNS records ✅
- `POST /zones/{id}/dns_records` - Create DNS record ✅
- `PATCH /zones/{id}/dns_records/{id}` - Update DNS record ✅
- `DELETE /zones/{id}/dns_records/{id}` - Delete DNS record ✅
- `GET /zones/{id}/settings/*` - Get zone settings ✅
- `PATCH /zones/{id}/settings/*` - Update zone settings ✅

### New Endpoints to Add
- `GET /user/tokens/verify` - Verify API token
- `GET /user` - Get user details (email)
- `POST /zones` - Create new zone (for full zone mode)

## Testing Strategy

1. **Unit Tests** (Update to PHPUnit 10/11):
   - Test token validation
   - Test API client with Guzzle 7
   - Test DataStore with new schema

2. **Integration Tests**:
   - Test full authentication flow
   - Test zone creation (both partial and full)
   - Test DNS record management

3. **PHP Version Tests**:
   - Run tests on PHP 7.4, 8.1, 8.2, 8.3
   - Use Docker containers for isolated testing

4. **Manual Testing** (when cPanel available):
   - Install on cPanel 130+ with Jupiter theme
   - Create API token in Cloudflare
   - Add token to plugin
   - Create partial zone (CNAME)
   - Create full zone
   - Manage DNS records
   - Adjust zone settings

## Backwards Compatibility

**Breaking Changes** (acceptable for major version bump to 8.0.0):
- ❌ No migration path for existing Host API users
- ❌ Installation no longer requires host key
- ❌ Users must create API tokens manually in Cloudflare dashboard
- ❌ Old YAML data structure not compatible

**Rationale**: Since this is a revival of an abandoned plugin (deprecated in 2019), and the Host API is completely defunct, backwards compatibility is not feasible or necessary.

## Rollout Plan

1. **Version 8.0.0-alpha**: Initial token-based authentication
2. **Version 8.0.0-beta**: Full feature parity with token auth
3. **Version 8.0.0-rc1**: PHP 8.x compatibility verified
4. **Version 8.0.0**: Stable release

## Documentation Updates

1. **README.md**:
   - Update PHP version requirements (7.4+)
   - Add API token creation instructions
   - Remove all Host API references
   - Add Jupiter theme support notice

2. **INSTALLATION.md** (new):
   - Step-by-step cPanel installation
   - How to create Cloudflare API token
   - Required token permissions
   - Troubleshooting guide

3. **UPGRADE.md** (new):
   - Migration from v7.x (if applicable)
   - Breaking changes list
   - New features

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Guzzle upgrade breaks API calls | High | Comprehensive unit tests |
| Token permissions insufficient | Medium | Document exact permissions needed |
| cPanel API changes (130+) | Low | Test on target cPanel version |
| PHP 8.x compatibility issues | Medium | Test on all supported PHP versions |
| Jupiter theme incompatibility | Low | Test on Jupiter theme |

## Success Criteria

- ✅ Runs on PHP 7.4, 8.1, 8.2, 8.3
- ✅ No deprecated dependencies
- ✅ Uses Cloudflare API tokens (not Global API Keys)
- ✅ No Host API dependencies
- ✅ Works on cPanel 130+ with Jupiter theme
- ✅ Both partial and full zone provisioning work
- ✅ All DNS record operations work
- ✅ All zone settings management works
- ✅ Passes all unit tests on all PHP versions

## Timeline Estimate

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1: Dependencies | 2 hours | None |
| Phase 2: HTTP Client | 4 hours | Phase 1 |
| Phase 3: Authentication | 8 hours | Phase 2 |
| Phase 4: Zone Provisioning | 6 hours | Phase 3 |
| Phase 5: Installation | 4 hours | Phase 3 |
| Phase 6: Frontend | 4 hours | Phase 5 |
| Phase 7: API Updates | 4 hours | Phase 2 |
| Testing | 8 hours | All phases |
| Documentation | 4 hours | All phases |
| **Total** | **44 hours** | - |

## Next Steps

1. ✅ Complete this migration plan
2. ⏭️ Start Phase 1: Update composer.json
3. ⏭️ Vendor cloudflare-plugin-backend code locally
4. ⏭️ Begin Guzzle upgrade
