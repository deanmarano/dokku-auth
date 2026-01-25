#!/usr/bin/env bash
# Wiki.js OIDC/LDAP integration preset
# https://docs.requarks.io/auth

PRESET_NAME="wikijs"
PRESET_DESCRIPTION="Wiki.js documentation wiki"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_LDAP_SUPPORTED=true

# Generate redirect URI from app domain
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/login/oidc/callback"
}

# No environment variables - Wiki.js uses web UI config
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

Wiki.js OIDC Setup Instructions:
================================

1. Go to Administration > Authentication

2. Click "Add Strategy" and select "OpenID Connect / OAuth2"

3. Configure:
   - Display Name: Authelia
   - Client ID: $CLIENT_ID
   - Client Secret: <client_secret>
   - Authorization URL: https://${AUTH_DOMAIN}/api/oidc/authorization
   - Token URL: https://${AUTH_DOMAIN}/api/oidc/token
   - User Info URL: https://${AUTH_DOMAIN}/api/oidc/userinfo
   - Issuer: https://${AUTH_DOMAIN}
   - Logout URL: https://${AUTH_DOMAIN}/logout
   - Callback URL: https://<wiki-domain>/login/oidc/callback
   - Scope: openid profile email
   - ID Claim: preferred_username
   - Email Claim: email
   - Display Name Claim: name

4. Click "Apply" to save

5. Enable the strategy by clicking the toggle

Optional Settings:
------------------
- Self-registration: Allow users to create accounts
- Assign to Group: Default group for new users

EOF
}

# LDAP configuration for Wiki.js
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Wiki.js LDAP Setup Instructions:
================================

1. Go to Administration > Authentication

2. Click "Add Strategy" and select "LDAP / Active Directory"

3. Configure:
   - Display Name: LLDAP
   - URL: ldap://${LDAP_HOST}:${LDAP_PORT}
   - Bind DN: $BIND_DN
   - Bind Credentials: <bind_password>
   - Search Base: ou=people,$BASE_DN
   - Search Filter: (uid={{username}})
   - TLS: disabled

4. Attribute Mapping:
   - Unique ID Field: uid
   - Email Field: mail
   - Display Name Field: displayName

5. Click "Apply" to save

6. Enable the strategy by clicking the toggle

EOF
}
