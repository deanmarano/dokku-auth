#!/usr/bin/env bash
# Audiobookshelf OIDC integration preset
# https://www.audiobookshelf.org/docs#openid-connect

PRESET_NAME="audiobookshelf"
PRESET_DESCRIPTION="Audiobookshelf audiobook server"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/auth/openid/callback,https://${DOMAIN}/auth/openid/mobile-redirect"
}

# Environment variables for Audiobookshelf
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  # Audiobookshelf uses UI configuration, not env vars for OIDC
  echo ""
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Audiobookshelf OIDC Setup Instructions:
=======================================

1. Go to Settings > Authentication > OpenID Connect

2. Configure:
   - Issuer URL: https://${AUTH_DOMAIN}
   - Client ID: $CLIENT_ID
   - Client Secret: <client_secret>
   - Button Text: Login with Authelia
   - Match existing users by: email

3. Advanced Options (optional):
   - Auto Launch: Opens OIDC login automatically
   - Auto Register: Create new users on first login

4. Mobile App:
   The mobile redirect URI is already configured.
   Users can log in via the mobile app using OIDC.

EOF
}

# LDAP not supported
preset_ldap_config() {
  cat <<EOF
Audiobookshelf LDAP Support:
============================

Audiobookshelf does not support LDAP authentication.
Use OIDC integration instead.

EOF
}
