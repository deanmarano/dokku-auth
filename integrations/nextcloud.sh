#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Nextcloud OIDC integration preset
# https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/oidc_auth.html

PRESET_NAME="nextcloud"
PRESET_DESCRIPTION="Nextcloud with user_oidc app"
PRESET_SCOPES="openid profile email groups"
PRESET_REQUIRE_PKCE=true
PRESET_PKCE_METHOD="S256"
PRESET_PUBLIC=false

# Generate redirect URI from app domain
# Nextcloud uses: https://<domain>/apps/user_oidc/code
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/apps/user_oidc/code"
}

# Environment variables to set on the Dokku app
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  # Nextcloud OIDC is configured via occ commands, not env vars
  # Return empty - will use post_integrate hook instead
  echo ""
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Nextcloud OIDC Setup Instructions:
===================================

1. Install the user_oidc app in Nextcloud:
   dokku enter $APP web php occ app:enable user_oidc

2. Add the OIDC provider:
   dokku enter $APP web php occ user_oidc:provider authelia \\
     --clientid="$CLIENT_ID" \\
     --clientsecret="<client_secret>" \\
     --discoveryuri="https://${AUTH_DOMAIN}/.well-known/openid-configuration" \\
     --scope="openid profile email groups" \\
     --unique-uid=1 \\
     --check-bearer=1

3. Configure PKCE (required for Authelia 4.39+):
   dokku enter $APP web php occ config:app:set user_oidc \\
     oidc_login_code_challenge_method --value="S256"

4. Optional - Make OIDC the only login method:
   dokku enter $APP web php occ config:app:set user_oidc \\
     allow_multiple_user_backends --value="0"

EOF
}

# LDAP configuration for Nextcloud
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Nextcloud LDAP Setup Instructions:
===================================

1. Enable the LDAP app:
   dokku enter <app> web php occ app:enable user_ldap

2. Create LDAP configuration:
   dokku enter <app> web php occ ldap:create-empty-config

3. Configure LDAP settings:
   dokku enter <app> web php occ ldap:set-config s01 ldapHost "$LDAP_HOST"
   dokku enter <app> web php occ ldap:set-config s01 ldapPort "$LDAP_PORT"
   dokku enter <app> web php occ ldap:set-config s01 ldapBase "$BASE_DN"
   dokku enter <app> web php occ ldap:set-config s01 ldapAgentName "$BIND_DN"
   dokku enter <app> web php occ ldap:set-config s01 ldapAgentPassword "<password>"
   dokku enter <app> web php occ ldap:set-config s01 ldapUserFilter "(objectClass=person)"
   dokku enter <app> web php occ ldap:set-config s01 ldapLoginFilter "(&(objectClass=person)(uid=%uid))"
   dokku enter <app> web php occ ldap:set-config s01 ldapUserDisplayName "displayName"
   dokku enter <app> web php occ ldap:set-config s01 ldapEmailAttribute "mail"

4. Test the configuration:
   dokku enter <app> web php occ ldap:test-config s01

EOF
}
