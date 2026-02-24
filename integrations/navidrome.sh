#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Navidrome integration preset
# https://www.navidrome.org/docs/usage/security/#reverse-proxy-authentication

PRESET_NAME="navidrome"
PRESET_DESCRIPTION="Navidrome music server"
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

# Environment variables for Navidrome
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
ND_REVERSEPROXYUSERHEADER=Remote-User
ND_REVERSEPROXYWHITELIST=172.16.0.0/12
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Navidrome Setup Instructions:
=============================

Navidrome supports reverse proxy (header) authentication.

1. Set environment variables (if --set-env was used):
   ND_REVERSEPROXYUSERHEADER=Remote-User
   ND_REVERSEPROXYWHITELIST=172.16.0.0/12

2. Protect with Authelia:
   dokku sso:protect $APP \\
     --service $SERVICE \\
     --bypass-path "/rest/*" \\
     --bypass-path "/share/*"

Bypassed paths allow:
- /rest/* - Subsonic API for music apps
- /share/* - Shared playlist/album links

Subsonic API:
-------------
Music apps (DSub, Symfonium, etc.) use the Subsonic API.
These authenticate with Navidrome credentials, not Authelia.

Create a dedicated user in Navidrome for app access.

Header Authentication:
----------------------
When using header auth, Authelia passes the username
in the Remote-User header. Navidrome auto-creates users.

Whitelist your Docker network to trust the header.

EOF
}

# No LDAP support
preset_ldap_config() {
  cat <<EOF
Navidrome LDAP Support:
=======================

Navidrome does not support LDAP authentication.
Use reverse proxy header authentication instead.

EOF
}
