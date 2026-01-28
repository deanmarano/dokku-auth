#!/usr/bin/env bash
# Plex Media Server integration preset
# https://plex.tv

PRESET_NAME="plex"
PRESET_DESCRIPTION="Plex Media Server (proxy auth for web access)"
PRESET_SCOPES=""
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_OIDC_SUPPORTED=false
PRESET_LDAP_SUPPORTED=false
PRESET_PROXY_AUTH=true

# Plex uses its own plex.tv authentication - no OIDC
preset_redirect_uri() {
  echo ""
}

# No OIDC/LDAP env vars for Plex
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

Plex Authentication Notes:
==========================

Plex uses its own plex.tv account system for authentication.
It does not support OIDC or LDAP natively.

Options for protecting Plex:

1. Forward Auth (Recommended for LAN access):
   - Protect web interface access with Authelia
   - Users authenticate via Authelia, then access Plex
   - Note: Plex apps/clients still use plex.tv auth

   dokku auth:protect $APP --service $SERVICE

2. Network-level protection:
   - Use firewall rules to restrict access
   - Plex Remote Access handles external streaming

3. Plex Home Users:
   - Use Plex's built-in Home feature for family sharing
   - Managed users don't need separate plex.tv accounts

Important Considerations:
-------------------------
- Plex clients (apps, TVs, etc.) authenticate directly with plex.tv
- Forward auth only protects the web interface
- Remote Access streams bypass your reverse proxy
- Consider using Overseerr/Ombi for request management (supports OIDC)

For Plex companion apps with better auth support:
- Overseerr: dokku auth:integrate $SERVICE overseerr --preset overseerr
- Tautulli: Use proxy auth protection

EOF
}

# No LDAP config for Plex
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"
  local BIND_PASSWORD="$6"

  cat <<EOF
Plex LDAP Notes:
================

Plex does not support LDAP authentication natively.
Users must have plex.tv accounts to use Plex.

Alternatives:
- Use forward auth to protect web interface access
- Use Jellyfin or Emby if LDAP authentication is required

EOF
}
