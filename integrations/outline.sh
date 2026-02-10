#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Outline OIDC integration preset
# https://docs.getoutline.com/s/hosting/doc/oidc-8CPBm6uC0I

PRESET_NAME="outline"
PRESET_DESCRIPTION="Outline wiki/knowledge base"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/auth/oidc.callback"
}

# Environment variables for Outline
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
OIDC_CLIENT_ID=$CLIENT_ID
OIDC_CLIENT_SECRET=$CLIENT_SECRET
OIDC_AUTH_URI=https://${AUTH_DOMAIN}/api/oidc/authorization
OIDC_TOKEN_URI=https://${AUTH_DOMAIN}/api/oidc/token
OIDC_USERINFO_URI=https://${AUTH_DOMAIN}/api/oidc/userinfo
OIDC_LOGOUT_URI=https://${AUTH_DOMAIN}/logout
OIDC_USERNAME_CLAIM=preferred_username
OIDC_DISPLAY_NAME=Authelia
OIDC_SCOPES=openid profile email
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Outline OIDC Setup Instructions:
================================

Environment variables have been configured (if --set-env was used).

The following environment variables are set:
- OIDC_CLIENT_ID
- OIDC_CLIENT_SECRET
- OIDC_AUTH_URI
- OIDC_TOKEN_URI
- OIDC_USERINFO_URI
- OIDC_LOGOUT_URI
- OIDC_USERNAME_CLAIM
- OIDC_DISPLAY_NAME
- OIDC_SCOPES

Restart the app to apply changes:
  dokku ps:restart $APP

Notes:
------
- First user to sign in becomes the admin
- Outline requires email verification for new users
- Make sure SMTP is configured in Outline

EOF
}

# LDAP not supported
preset_ldap_config() {
  cat <<EOF
Outline LDAP Support:
=====================

Outline does not support LDAP authentication.
Use OIDC integration instead.

EOF
}
