#!/usr/bin/env bash
# Gitea OIDC integration preset
# https://docs.gitea.com/usage/authentication#oauth2-provider

PRESET_NAME="gitea"
PRESET_DESCRIPTION="Gitea / Forgejo git server"
PRESET_SCOPES="openid profile email groups"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false

# Generate redirect URI from app domain
# Gitea uses: https://<domain>/user/oauth2/<provider>/callback
preset_redirect_uri() {
  local DOMAIN="$1"
  echo "https://${DOMAIN}/user/oauth2/authelia/callback"
}

# Environment variables for Gitea (if using env-based config)
preset_env_vars() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local CLIENT_SECRET="$4"
  local AUTH_DOMAIN="$5"

  # Gitea OAuth is typically configured via admin UI or CLI, not env vars
  echo ""
}

# Post-integration instructions
preset_instructions() {
  local SERVICE="$1"
  local APP="$2"
  local CLIENT_ID="$3"
  local AUTH_DOMAIN="$4"

  cat <<EOF

Gitea OIDC Setup Instructions:
==============================

Option 1: Via Admin UI
----------------------
1. Go to Site Administration > Authentication Sources
2. Click "Add Authentication Source"
3. Select "OAuth2" as the type
4. Configure:
   - Authentication Name: authelia
   - OAuth2 Provider: OpenID Connect
   - Client ID: $CLIENT_ID
   - Client Secret: <client_secret>
   - OpenID Connect Auto Discovery URL: https://${AUTH_DOMAIN}/.well-known/openid-configuration
   - Additional Scopes: groups (optional, for group sync)

Option 2: Via CLI (gitea admin auth)
------------------------------------
dokku enter $APP web gitea admin auth add-oauth \\
  --name authelia \\
  --provider openidConnect \\
  --key "$CLIENT_ID" \\
  --secret "<client_secret>" \\
  --auto-discover-url "https://${AUTH_DOMAIN}/.well-known/openid-configuration" \\
  --scopes "openid profile email groups"

Optional: Enable group sync
---------------------------
Add these flags to the CLI command or configure in UI:
  --group-claim-name groups
  --admin-group gitea_admin
  --restricted-group ""

EOF
}

# LDAP configuration for Gitea
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Gitea LDAP Setup Instructions:
==============================

Via CLI:
--------
dokku enter <app> web gitea admin auth add-ldap \\
  --name "LLDAP" \\
  --host "$LDAP_HOST" \\
  --port $LDAP_PORT \\
  --security-protocol unencrypted \\
  --bind-dn "$BIND_DN" \\
  --bind-password "<password>" \\
  --user-search-base "ou=people,$BASE_DN" \\
  --user-filter "(&(objectClass=person)(uid=%s))" \\
  --email-attribute mail \\
  --username-attribute uid \\
  --firstname-attribute givenName \\
  --surname-attribute sn \\
  --admin-filter "(memberOf=cn=gitea_admin,ou=groups,$BASE_DN)"

Via Admin UI:
-------------
1. Go to Site Administration > Authentication Sources
2. Click "Add Authentication Source"
3. Select "LDAP (via BindDN)" as the type
4. Configure with the values above

EOF
}
