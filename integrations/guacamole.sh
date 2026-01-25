#!/usr/bin/env bash
# Apache Guacamole integration preset
# https://guacamole.apache.org/doc/gug/openid-auth.html

PRESET_NAME="guacamole"
PRESET_DESCRIPTION="Apache Guacamole remote desktop"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_LDAP_SUPPORTED=true

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/guacamole/"
}

# Environment variables for Guacamole
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  cat <<EOF
OPENID_AUTHORIZATION_ENDPOINT=https://${AUTH_DOMAIN}/api/oidc/authorization
OPENID_JWKS_ENDPOINT=https://${AUTH_DOMAIN}/jwks.json
OPENID_ISSUER=https://${AUTH_DOMAIN}
OPENID_CLIENT_ID=$CLIENT_ID
OPENID_REDIRECT_URI=https://<guacamole-domain>/guacamole/
OPENID_USERNAME_CLAIM_TYPE=preferred_username
OPENID_GROUPS_CLAIM_TYPE=groups
EOF
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Apache Guacamole OIDC Setup Instructions:
=========================================

Environment variables have been configured (if --set-env was used).

Important: Update OPENID_REDIRECT_URI with your actual domain.

Required Extension:
-------------------
Ensure guacamole-auth-sso-openid extension is installed.
Download from: https://guacamole.apache.org/releases/

Place in: /etc/guacamole/extensions/

Properties File Alternative:
----------------------------
Add to guacamole.properties:

openid-authorization-endpoint: https://${AUTH_DOMAIN}/api/oidc/authorization
openid-jwks-endpoint: https://${AUTH_DOMAIN}/jwks.json
openid-issuer: https://${AUTH_DOMAIN}
openid-client-id: $CLIENT_ID
openid-redirect-uri: https://<domain>/guacamole/
openid-username-claim-type: preferred_username
openid-groups-claim-type: groups

Restart Guacamole to apply changes.

User/Connection Management:
---------------------------
OIDC authenticates users, but connections are still
managed in Guacamole (database or LDAP).

For automatic connection assignment, combine with LDAP.

EOF
}

# LDAP configuration for Guacamole
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Apache Guacamole LDAP Setup Instructions:
=========================================

Required Extension:
-------------------
Install guacamole-auth-ldap extension.

Add to guacamole.properties:
----------------------------
ldap-hostname: $LDAP_HOST
ldap-port: $LDAP_PORT
ldap-encryption-method: none
ldap-user-base-dn: ou=people,$BASE_DN
ldap-username-attribute: uid
ldap-search-bind-dn: $BIND_DN
ldap-search-bind-password: <bind_password>
ldap-user-search-filter: (objectClass=person)

Group-based Connection Access:
------------------------------
ldap-group-base-dn: ou=groups,$BASE_DN
ldap-group-name-attribute: cn
ldap-member-attribute: member

This allows assigning connections to LDAP groups.

Combining OIDC + LDAP:
----------------------
You can use both:
- OIDC for authentication (SSO)
- LDAP for user/group data and connection assignments

Set in guacamole.properties:
  extension-priority: openid, ldap

EOF
}
