#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Paperless-ngx OIDC integration preset
# https://docs.paperless-ngx.com/configuration/#oidc

PRESET_NAME="paperless"
PRESET_DESCRIPTION="Paperless-ngx document management"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_LDAP_SUPPORTED=false

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/accounts/oidc/authelia/login/callback/"
}

# Environment variables for Paperless-ngx
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
PAPERLESS_APPS=allauth.socialaccount.providers.openid_connect
PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"APPS":[{"provider_id":"authelia","name":"Authelia","client_id":"$CLIENT_ID","secret":"$CLIENT_SECRET","settings":{"server_url":"https://${AUTH_DOMAIN}"}}]}}
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Paperless-ngx OIDC Setup Instructions:
======================================

Environment variables have been configured (if --set-env was used).

Important Notes:
----------------
1. The PAPERLESS_SOCIALACCOUNT_PROVIDERS must be valid JSON
2. Provider ID "authelia" is used in the redirect URI
3. Users must exist in Paperless before OIDC login works

Creating Users:
---------------
Option 1: Create user via CLI first
  dokku run $APP python manage.py createsuperuser

Option 2: Enable auto-provisioning (Paperless 2.0+)
  PAPERLESS_SOCIAL_AUTO_SIGNUP=true

Disable Local Login (optional):
-------------------------------
PAPERLESS_DISABLE_REGULAR_LOGIN=true

Restart the app to apply changes:
  dokku ps:restart $APP

EOF
}

# LDAP not supported by Paperless-ngx
preset_ldap_config() {
  cat <<EOF
Paperless-ngx LDAP Support:
===========================

Paperless-ngx does not natively support LDAP authentication.
Use OIDC integration instead.

LDAP users can authenticate via Authelia OIDC, where Authelia
handles LDAP authentication on behalf of Paperless.

Alternative - Remote User Header:
---------------------------------
Paperless supports REMOTE_USER authentication:
  PAPERLESS_ENABLE_HTTP_REMOTE_USER=true
  PAPERLESS_HTTP_REMOTE_USER_HEADER_NAME=HTTP_X_FORWARDED_USER

Combined with Authelia forward auth, this can pass the authenticated
username to Paperless.

EOF
}
