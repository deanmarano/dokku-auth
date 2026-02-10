#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# BookStack OIDC integration preset
# https://www.bookstackapp.com/docs/admin/oidc-auth/

PRESET_NAME="bookstack"
PRESET_DESCRIPTION="BookStack documentation platform"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_LDAP_SUPPORTED=true

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/oidc/callback"
}

# Environment variables for BookStack
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
AUTH_METHOD=oidc
OIDC_NAME=Authelia
OIDC_DISPLAY_NAME_CLAIMS=name
OIDC_CLIENT_ID=$CLIENT_ID
OIDC_CLIENT_SECRET=$CLIENT_SECRET
OIDC_ISSUER=https://${AUTH_DOMAIN}
OIDC_ISSUER_DISCOVER=true
OIDC_USER_TO_GROUPS=true
OIDC_GROUPS_CLAIM=groups
OIDC_REMOVE_FROM_GROUPS=true
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

BookStack OIDC Setup Instructions:
==================================

Environment variables have been configured (if --set-env was used).

Key Settings:
-------------
- AUTH_METHOD=oidc enables OIDC as the auth method
- OIDC_ISSUER_DISCOVER=true uses auto-discovery
- OIDC_USER_TO_GROUPS=true enables group sync
- OIDC_REMOVE_FROM_GROUPS=true keeps groups in sync

Group Mapping:
--------------
BookStack will automatically create roles from OIDC groups.
Users will be assigned to roles matching their group names.

Create groups in LLDAP like:
- bookstack_admin -> Admin role
- bookstack_editor -> Editor role

Additional Options:
-------------------
# Dump OIDC claims for debugging
OIDC_DUMP_USER_DETAILS=true

# Disable local login (OIDC only)
AUTH_AUTO_INITIATE=true

Restart the app to apply changes:
  dokku ps:restart $APP

EOF
}

# LDAP configuration for BookStack
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
BookStack LDAP Setup Instructions:
==================================

Environment variables:
----------------------
AUTH_METHOD=ldap
LDAP_SERVER=ldap://${LDAP_HOST}:${LDAP_PORT}
LDAP_BASE_DN=ou=people,$BASE_DN
LDAP_DN=$BIND_DN
LDAP_PASS=<bind_password>
LDAP_USER_FILTER=(&(uid=\${user}))
LDAP_VERSION=3
LDAP_ID_ATTRIBUTE=uid
LDAP_EMAIL_ATTRIBUTE=mail
LDAP_DISPLAY_NAME_ATTRIBUTE=displayName
LDAP_START_TLS=false

Group Sync:
-----------
LDAP_USER_TO_GROUPS=true
LDAP_GROUP_ATTRIBUTE=memberOf
LDAP_REMOVE_FROM_GROUPS=true

EOF
}
