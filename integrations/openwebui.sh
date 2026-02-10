#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Open WebUI OIDC integration preset
# https://docs.openwebui.com/getting-started/advanced-topics#openid-connect-oidc-authentication

PRESET_NAME="openwebui"
PRESET_DESCRIPTION="Open WebUI for LLMs"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/oauth/oidc/callback"
}

# Environment variables for Open WebUI
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
ENABLE_OAUTH_SIGNUP=true
OAUTH_PROVIDER_NAME=Authelia
OAUTH_CLIENT_ID=$CLIENT_ID
OAUTH_CLIENT_SECRET=$CLIENT_SECRET
OPENID_PROVIDER_URL=https://${AUTH_DOMAIN}/.well-known/openid-configuration
OAUTH_SCOPES=openid profile email
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Open WebUI OIDC Setup Instructions:
===================================

Environment variables have been configured (if --set-env was used).

The "Sign in with Authelia" button will appear on the login page.

Additional Options:
-------------------
# Merge existing accounts by email
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true

# Admin email (first user with this email becomes admin)
OAUTH_ADMIN_EMAIL=admin@example.com

# Allowed email domains
OAUTH_ALLOWED_DOMAINS=example.com

# Username claim (default: preferred_username)
OAUTH_USERNAME_CLAIM=preferred_username

# Email claim (default: email)
OAUTH_EMAIL_CLAIM=email

Restart the app to apply changes:
  dokku ps:restart $APP

EOF
}

# LDAP not directly supported
preset_ldap_config() {
  cat <<EOF
Open WebUI LDAP Support:
========================

Open WebUI does not natively support LDAP.
Use OIDC integration instead.

LDAP users can authenticate via:
1. Authelia OIDC (recommended) - users auth against LDAP through Authelia
2. Trusted header authentication with a reverse proxy

EOF
}
