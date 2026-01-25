#!/usr/bin/env bash
# Vaultwarden LDAP integration preset
# https://github.com/dani-garcia/vaultwarden/wiki/LDAP-Sync

PRESET_NAME="vaultwarden"
PRESET_DESCRIPTION="Vaultwarden password manager"
PRESET_SCOPES=""
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_OIDC_SUPPORTED=false
PRESET_LDAP_SUPPORTED=true

# Vaultwarden doesn't support OIDC
preset_redirect_uri() {
  echo ""
}

# No OIDC env vars
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

Vaultwarden LDAP Setup Instructions:
====================================

Vaultwarden requires a separate LDAP sync container (vaultwarden_ldap).
OIDC is not natively supported.

Use 'dokku auth:protect' for forward auth protection if needed.

EOF
}

# LDAP configuration for Vaultwarden
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Vaultwarden LDAP Setup Instructions:
====================================

Vaultwarden uses a separate sync container: vaultwarden_ldap
https://github.com/ViViDboarder/vaultwarden_ldap

1. Deploy vaultwarden_ldap alongside Vaultwarden:

docker run -d --name vaultwarden_ldap \\
  -e VAULTWARDEN_URL=https://<vaultwarden-domain> \\
  -e VAULTWARDEN_ADMIN_TOKEN=<admin_token> \\
  -e LDAP_HOST=$LDAP_HOST \\
  -e LDAP_PORT=$LDAP_PORT \\
  -e LDAP_BIND_DN=$BIND_DN \\
  -e LDAP_BIND_PASSWORD=<bind_password> \\
  -e LDAP_SEARCH_BASE_DN=ou=people,$BASE_DN \\
  -e LDAP_SEARCH_FILTER=(&(objectClass=person)(mail=*)) \\
  -e LDAP_SYNC_INTERVAL_SECONDS=3600 \\
  vividboarder/vaultwarden_ldap

2. Enable admin panel in Vaultwarden:
   ADMIN_TOKEN=<secure-token>

3. LDAP sync will:
   - Invite new LDAP users to Vaultwarden
   - Users still set their own master password
   - Does NOT sync passwords from LDAP

Alternative - Forward Auth:
---------------------------
Use Authelia forward auth to protect the Vaultwarden web vault:
  dokku auth:protect <vaultwarden-app> --bypass-path "/api/*" --bypass-path "/identity/*"

This protects web access while allowing client apps to work.

EOF
}
