#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Uptime Kuma integration preset
# Supports proxy auth headers

PRESET_NAME="uptimekuma"
PRESET_DESCRIPTION="Uptime Kuma monitoring"
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

Uptime Kuma Setup Instructions:
===============================

Uptime Kuma does not support OIDC or LDAP natively.
Use Authelia forward auth to protect it.

Protect the App:
----------------
dokku sso:protect $APP \\
  --service $SERVICE \\
  --bypass-path "/api/status-page/*" \\
  --bypass-path "/api/badge/*" \\
  --bypass-path "/assets/*"

Bypassed paths allow:
- Public status pages to remain accessible
- Status badges for external embedding
- Static assets to load

Status Pages:
-------------
Uptime Kuma status pages can be public or protected.
Configure per-page visibility in the Uptime Kuma UI.

If all status pages should be protected:
  dokku sso:protect $APP --service $SERVICE

Socket.IO / WebSocket:
----------------------
Uptime Kuma uses WebSocket for real-time updates.
Ensure your nginx config supports WebSocket proxying.

EOF
}

# No LDAP support
preset_ldap_config() {
  cat <<EOF
Uptime Kuma LDAP Support:
=========================

Uptime Kuma does not support LDAP authentication.
Use forward auth (dokku sso:protect) instead.

EOF
}
