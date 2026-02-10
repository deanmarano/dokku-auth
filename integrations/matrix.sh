#!/usr/bin/env bash
# ============================================================================
# WARNING: UNTESTED INTEGRATION
# This integration preset has not been validated with E2E tests.
# It may not work correctly with the current plugin version.
# Use at your own risk and please report issues.
# ============================================================================

# Matrix Synapse OIDC integration preset
# https://element-hq.github.io/synapse/latest/openid.html

PRESET_NAME="matrix"
PRESET_DESCRIPTION="Matrix Synapse homeserver"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_LDAP_SUPPORTED=true

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/_synapse/client/oidc/callback"
}

# No environment variables - Matrix uses homeserver.yaml
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

Matrix Synapse OIDC Setup Instructions:
=======================================

Add to homeserver.yaml:
-----------------------
oidc_providers:
  - idp_id: authelia
    idp_name: "Authelia"
    issuer: "https://${AUTH_DOMAIN}"
    client_id: "$CLIENT_ID"
    client_secret: "<client_secret>"
    scopes: ["openid", "profile", "email"]
    user_mapping_provider:
      config:
        subject_claim: "sub"
        localpart_template: "{{ user.preferred_username }}"
        display_name_template: "{{ user.name }}"
        email_template: "{{ user.email }}"

Enable SSO:
-----------
# Allow SSO login
enable_registration: false
enable_registration_without_verification: false

# Redirect to SSO by default (optional)
sso:
  client_whitelist:
    - https://element.example.com/

Password Auth:
--------------
You can keep password auth enabled alongside OIDC:
  password_config:
    enabled: true

Or disable it for SSO-only:
  password_config:
    enabled: false

Restart Synapse to apply changes.

Element/Web Client:
-------------------
Element will show "Sign in with Authelia" option.
Configure in Element: Settings > General > "Continue with SSO"

EOF
}

# LDAP configuration for Matrix Synapse
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Matrix Synapse LDAP Setup Instructions:
=======================================

Requires matrix-synapse-ldap3 module.

Add to homeserver.yaml:
-----------------------
modules:
  - module: ldap_auth_provider.LdapAuthProviderModule
    config:
      enabled: true
      uri: "ldap://${LDAP_HOST}:${LDAP_PORT}"
      start_tls: false
      base: "ou=people,$BASE_DN"
      attributes:
        uid: "uid"
        mail: "mail"
        name: "displayName"
      bind_dn: "$BIND_DN"
      bind_password: "<bind_password>"
      filter: "(objectClass=person)"

Install the module:
-------------------
pip install matrix-synapse-ldap3

Or with Docker, ensure the module is installed in the image.

LDAP vs OIDC:
-------------
Choose one authentication method:
- OIDC: SSO with Authelia (recommended)
- LDAP: Direct LDAP authentication

OIDC is preferred as it:
- Provides true SSO
- Centralizes authentication in Authelia
- Supports MFA via Authelia

EOF
}
