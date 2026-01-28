#!/usr/bin/env bash
# Emby LDAP integration preset
# https://github.com/jellyfin/jellyfin-plugin-ldapauth (compatible with Emby)

PRESET_NAME="emby"
PRESET_DESCRIPTION="Emby media server (LDAP plugin)"
PRESET_SCOPES=""
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_OIDC_SUPPORTED=false
PRESET_LDAP_SUPPORTED=true

# Emby doesn't use OIDC natively
preset_redirect_uri() {
  echo ""
}

# No OIDC env vars for Emby
preset_env_vars() {
  echo ""
}

# Post-integration instructions (for LDAP)
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Emby LDAP Setup Instructions:
=============================

Emby uses LDAP via a plugin, not OIDC.
Use 'dokku auth:integrate:emby' for LDAP setup.

EOF
}

# LDAP configuration for Emby
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"
  local BIND_PASSWORD="$6"

  cat <<EOF
Emby LDAP Setup Instructions:
=============================

1. Install the LDAP Authentication plugin:
   - Go to Settings > Plugins > Catalog
   - Find "LDAP Authentication" and install it
   - Restart Emby

2. Configure LDAP in Settings > Plugins > LDAP Authentication:

   LDAP Server Settings:
   ---------------------
   LDAP Server: $LDAP_HOST
   LDAP Port: $LDAP_PORT
   Secure LDAP: unchecked (LLDAP uses plaintext on internal network)
   Start TLS: unchecked

   LDAP Bind User:
   ---------------
   LDAP Bind User: $BIND_DN
   LDAP Bind Password: $BIND_PASSWORD

   LDAP Search Settings:
   ---------------------
   LDAP Base DN for searches: ou=people,$BASE_DN
   LDAP Search Filter: (uid={0})
   LDAP Search Attributes: uid, mail, displayName

   LDAP User Settings:
   -------------------
   LDAP Uid Attribute: uid
   LDAP Username Attribute: uid

   Admin Configuration:
   --------------------
   Enable Admin Filter: checked
   Admin Filter: (memberOf=cn=emby_admin,ou=groups,$BASE_DN)

   User Creation:
   --------------
   Enable User Creation: checked
   Create users as administrators: unchecked

3. Test Configuration:
   - Click "Test LDAP Server Settings"
   - Try logging in with an LDAP user

4. Create the emby_admin group in LLDAP:
   dokku auth:groups:create $SERVICE emby_admin

EOF
}

# Generate Emby plugin config XML
preset_generate_config() {
  local LDAP_HOST="$1"
  local LDAP_PORT="$2"
  local BASE_DN="$3"
  local BIND_DN="$4"

  cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <LdapServer>$LDAP_HOST</LdapServer>
  <LdapPort>$LDAP_PORT</LdapPort>
  <UseSsl>false</UseSsl>
  <UseStartTls>false</UseStartTls>
  <SkipSslVerify>false</SkipSslVerify>
  <LdapBindUser>$BIND_DN</LdapBindUser>
  <LdapBindPassword></LdapBindPassword>
  <LdapBaseDn>ou=people,$BASE_DN</LdapBaseDn>
  <LdapSearchFilter>(uid={0})</LdapSearchFilter>
  <LdapSearchAttributes>uid,mail,displayName</LdapSearchAttributes>
  <LdapUidAttribute>uid</LdapUidAttribute>
  <LdapUsernameAttribute>uid</LdapUsernameAttribute>
  <CreateUsersFromLdap>true</CreateUsersFromLdap>
  <EnableLdapAdminFilterMemberUid>true</EnableLdapAdminFilterMemberUid>
  <LdapAdminFilter>(memberOf=cn=emby_admin,ou=groups,$BASE_DN)</LdapAdminFilter>
</PluginConfiguration>
EOF
}
