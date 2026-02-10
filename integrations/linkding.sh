#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Linkding integration preset
# https://github.com/sissbruecker/linkding

PRESET_NAME="linkding"
PRESET_DESCRIPTION="Linkding bookmark manager"
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

# Environment variables for Linkding
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
LD_ENABLE_AUTH_PROXY=True
LD_AUTH_PROXY_USERNAME_HEADER=HTTP_REMOTE_USER
LD_AUTH_PROXY_LOGOUT_URL=https://${AUTH_DOMAIN}/logout
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Linkding Setup Instructions:
============================

Environment variables have been configured (if --set-env was used).

1. Protect with Authelia:
   dokku auth:protect $APP \\
     --service $SERVICE \\
     --bypass-path "/api/*" \\
     --bypass-path "/feeds/*"

Bypassed paths allow:
- /api/* - REST API (uses token auth)
- /feeds/* - RSS feeds (can be public or authenticated)

API Authentication:
-------------------
Linkding API uses token authentication.
Generate token in: Settings > Integrations > API Token

Browser Extensions:
-------------------
Browser extensions use the API token, not OIDC.
Configure the extension with your API token.

User Management:
----------------
With proxy auth, users are auto-created on first login.
The first user becomes admin.

To create additional admins:
  dokku run $APP python manage.py createsuperuser

Restart the app to apply changes:
  dokku ps:restart $APP

EOF
}

# No LDAP support
preset_ldap_config() {
  cat <<EOF
Linkding LDAP Support:
======================

Linkding does not support LDAP authentication.
Use reverse proxy header authentication instead.

EOF
}
