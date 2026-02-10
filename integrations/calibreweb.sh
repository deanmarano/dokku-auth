#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Calibre-Web integration preset
# https://github.com/janeczku/calibre-web/wiki/Configuration#ldap-login

PRESET_NAME="calibreweb"
PRESET_DESCRIPTION="Calibre-Web ebook server"
PRESET_SCOPES=""
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_OIDC_SUPPORTED=false
PRESET_LDAP_SUPPORTED=true
PRESET_PROXY_AUTH=true

# No OIDC redirect
preset_redirect_uri() {
  echo ""
}

# Environment variables for Calibre-Web
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

Calibre-Web Setup Instructions:
===============================

Calibre-Web supports LDAP and reverse proxy authentication.

Option 1: LDAP Authentication
-----------------------------
Use 'dokku auth:integrate $SERVICE $APP --preset calibreweb'
and configure LDAP in the admin panel.

Option 2: Reverse Proxy Authentication
--------------------------------------
1. Enable in Admin > Configuration > Feature Configuration:
   - Allow Reverse Proxy Authentication: Yes
   - Reverse Proxy Header Name: Remote-User

2. Protect with Authelia:
   dokku auth:protect $APP \\
     --service $SERVICE \\
     --bypass-path "/opds/*" \\
     --bypass-path "/kobo/*"

Bypassed paths allow:
- /opds/* - OPDS catalog for ebook readers
- /kobo/* - Kobo sync endpoint

OPDS/Kobo Authentication:
-------------------------
OPDS and Kobo use basic auth with Calibre-Web credentials.
Create users in Calibre-Web for device access.

EOF
}

# LDAP configuration for Calibre-Web
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Calibre-Web LDAP Setup Instructions:
====================================

Configure in Admin > Configuration > LDAP Configuration:

LDAP Server:
------------
- LDAP Server Host: $LDAP_HOST
- LDAP Server Port: $LDAP_PORT
- LDAP Encryption: None
- LDAP Admin Username: $BIND_DN
- LDAP Admin Password: <bind_password>

LDAP Search:
------------
- LDAP User Base DN: ou=people,$BASE_DN
- LDAP User Search Filter: (&(objectClass=person)(uid=%s))
- LDAP Group Base DN: ou=groups,$BASE_DN
- LDAP Group Search Filter: (&(objectClass=groupOfUniqueNames)(cn=%s))

LDAP Attributes:
----------------
- LDAP User UID Attribute: uid
- LDAP User Email Attribute: mail
- LDAP User Name Attribute: displayName
- LDAP Group Attribute: memberOf

Group-based Access:
-------------------
- Allow login for members of group: calibreweb_users
- Admin group: calibreweb_admin

Create these groups in LLDAP and assign users.

EOF
}
