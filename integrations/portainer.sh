#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Portainer OIDC integration preset
# https://docs.portainer.io/admin/settings/authentication/oauth

PRESET_NAME="portainer"
PRESET_DESCRIPTION="Portainer container management"
PRESET_SCOPES="openid profile email groups"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false

# Generate redirect URI from app domain
# Portainer uses the base domain as redirect
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}"
}

# No environment variables - Portainer uses UI/API config
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

Portainer OIDC Setup Instructions:
==================================

1. Go to Settings > Authentication > OAuth

2. Enable OAuth and configure:
   - Provider: Custom
   - Client ID: $CLIENT_ID
   - Client Secret: <client_secret>
   - Authorization URL: https://${AUTH_DOMAIN}/api/oidc/authorization
   - Token URL: https://${AUTH_DOMAIN}/api/oidc/token
   - Resource URL: https://${AUTH_DOMAIN}/api/oidc/userinfo
   - Redirect URL: https://<portainer-domain>
   - Logout URL: https://${AUTH_DOMAIN}/logout
   - User Identifier: preferred_username
   - Scopes: openid profile email groups

3. Optional - Group Claims:
   - Enable "Use Group Claims"
   - Group Claim Name: groups

Important Notes:
----------------
- Users must exist in Portainer before they can log in via OAuth
- Create users manually or enable auto-user provisioning
- For admin access, add users to a group and configure group mapping

EOF
}

# LDAP configuration for Portainer
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Portainer LDAP Setup Instructions:
==================================

1. Go to Settings > Authentication > LDAP

2. Configure LDAP settings:
   - LDAP Server: $LDAP_HOST
   - Port: $LDAP_PORT
   - Use TLS: No (internal network)
   - Reader DN: $BIND_DN
   - Password: <bind_password>

3. User Search Settings:
   - Base DN: ou=people,$BASE_DN
   - Username Attribute: uid
   - Filter: (objectClass=person)

4. Group Search Settings:
   - Group Base DN: ou=groups,$BASE_DN
   - Group Membership Attribute: member
   - Group Filter: (objectClass=groupOfUniqueNames)

5. Test the configuration before saving

EOF
}
