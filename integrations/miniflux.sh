#!/usr/bin/env bash
# Miniflux OIDC integration preset
# https://miniflux.app/docs/howto.html#oauth2

PRESET_NAME="miniflux"
PRESET_DESCRIPTION="Miniflux RSS reader"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/oauth2/oidc/callback"
}

# Environment variables for Miniflux
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
OAUTH2_PROVIDER=oidc
OAUTH2_CLIENT_ID=$CLIENT_ID
OAUTH2_CLIENT_SECRET=$CLIENT_SECRET
OAUTH2_REDIRECT_URL=https://<app-domain>/oauth2/oidc/callback
OAUTH2_OIDC_DISCOVERY_ENDPOINT=https://${AUTH_DOMAIN}/.well-known/openid-configuration
OAUTH2_USER_CREATION=1
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Miniflux OIDC Setup Instructions:
=================================

Environment variables have been configured (if --set-env was used).

Important: Update OAUTH2_REDIRECT_URL with your actual domain:
  dokku config:set $APP OAUTH2_REDIRECT_URL=https://<your-domain>/oauth2/oidc/callback

Additional Options:
-------------------
# Disable local authentication (OAuth only)
DISABLE_LOCAL_AUTH=1

# Run database migrations automatically
RUN_MIGRATIONS=1

# Create admin user if needed
CREATE_ADMIN=1
ADMIN_USERNAME=admin
ADMIN_PASSWORD=<secure-password>

Restart the app to apply changes:
  dokku ps:restart $APP

EOF
}

# LDAP not supported by Miniflux
preset_ldap_config() {
  cat <<EOF
Miniflux LDAP Support:
======================

Miniflux does not support LDAP authentication.
Use OIDC integration instead.

For proxy-based authentication, Miniflux supports:
- AUTH_PROXY_HEADER: HTTP header containing username
- AUTH_PROXY_USER_CREATION: Auto-create users from proxy auth

EOF
}
