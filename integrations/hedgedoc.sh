#!/usr/bin/env bash
# HedgeDoc OIDC integration preset
# https://docs.hedgedoc.org/configuration/#oauth2

PRESET_NAME="hedgedoc"
PRESET_DESCRIPTION="HedgeDoc collaborative markdown"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_LDAP_SUPPORTED=true

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/auth/oauth2/callback"
}

# Environment variables for HedgeDoc
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
CMD_OAUTH2_PROVIDERNAME=Authelia
CMD_OAUTH2_CLIENT_ID=$CLIENT_ID
CMD_OAUTH2_CLIENT_SECRET=$CLIENT_SECRET
CMD_OAUTH2_AUTHORIZATION_URL=https://${AUTH_DOMAIN}/api/oidc/authorization
CMD_OAUTH2_TOKEN_URL=https://${AUTH_DOMAIN}/api/oidc/token
CMD_OAUTH2_USER_PROFILE_URL=https://${AUTH_DOMAIN}/api/oidc/userinfo
CMD_OAUTH2_SCOPE=openid profile email
CMD_OAUTH2_USER_PROFILE_USERNAME_ATTR=preferred_username
CMD_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR=name
CMD_OAUTH2_USER_PROFILE_EMAIL_ATTR=email
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

HedgeDoc OIDC Setup Instructions:
=================================

Environment variables have been configured (if --set-env was used).

The OAuth2 login button will appear on the login page.

Additional Options:
-------------------
# Allow only OAuth2 login (disable local accounts)
CMD_EMAIL=false
CMD_ALLOW_EMAIL_REGISTER=false

# Allow anonymous access (view only)
CMD_ALLOW_ANONYMOUS=true
CMD_ALLOW_ANONYMOUS_EDITS=false

# Default permission for new notes
CMD_DEFAULT_PERMISSION=limited

Restart the app to apply changes:
  dokku ps:restart $APP

EOF
}

# LDAP configuration for HedgeDoc
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
HedgeDoc LDAP Setup Instructions:
=================================

Environment variables:
----------------------
CMD_LDAP_URL=ldap://${LDAP_HOST}:${LDAP_PORT}
CMD_LDAP_BINDDN=$BIND_DN
CMD_LDAP_BINDCREDENTIALS=<bind_password>
CMD_LDAP_SEARCHBASE=ou=people,$BASE_DN
CMD_LDAP_SEARCHFILTER=(uid={{username}})
CMD_LDAP_USERIDFIELD=uid
CMD_LDAP_USERNAMEFIELD=uid
CMD_LDAP_TLS_CA=
CMD_LDAP_PROVIDERNAME=LLDAP

EOF
}
