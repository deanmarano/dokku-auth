#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# *arr stack (Radarr, Sonarr, etc.) integration preset
# These apps use forward auth only

PRESET_NAME="arr"
PRESET_DESCRIPTION="*arr stack (Radarr, Sonarr, Prowlarr, etc.)"
PRESET_SCOPES=""
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_OIDC_SUPPORTED=false
PRESET_LDAP_SUPPORTED=false
PRESET_PROXY_AUTH=true

# No OIDC redirect
preset_redirect_uri() {
  echo ""
}

# No OIDC env vars
preset_env_vars() {
  echo ""
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

*arr Stack (Radarr/Sonarr/etc.) Setup Instructions:
===================================================

The *arr applications do not support OIDC or LDAP natively.
Use Authelia forward auth to protect them.

Protect the App:
----------------
dokku auth:protect $APP \\
  --service $SERVICE \\
  --bypass-path "/api/*" \\
  --bypass-path "/feed/*"

The API and feed paths are bypassed to allow:
- External applications (Overseerr, Ombi) to access the API
- RSS feed readers to access feeds
- Download clients to send notifications

API Key Authentication:
-----------------------
*arr apps use API keys for programmatic access.
Find the API key in: Settings > General > Security

For external apps, use the API key instead of user auth:
  https://<domain>/api/v3/...?apikey=<apikey>

Additional Bypass Paths (if needed):
------------------------------------
--bypass-path "/login"      # Allow login page
--bypass-path "/ping"       # Health checks
--bypass-path "/initialize" # First-run setup

Header Auth (Advanced):
-----------------------
Some *arr apps support header authentication.
In Settings > General > Authentication:
- Method: External
- Required: Disabled for API

Then Authelia can pass the username via header.

EOF
}

# No LDAP support
preset_ldap_config() {
  cat <<EOF
*arr Stack LDAP Support:
========================

*arr applications (Radarr, Sonarr, Prowlarr, Lidarr, etc.)
do not support LDAP authentication.

Use forward auth (dokku auth:protect) instead.

EOF
}
