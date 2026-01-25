#!/usr/bin/env bash
# Syncthing integration preset
# Proxy auth only

PRESET_NAME="syncthing"
PRESET_DESCRIPTION="Syncthing file synchronization"
PRESET_SCOPES=""
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_OIDC_SUPPORTED=false
PRESET_LDAP_SUPPORTED=false
PRESET_PROXY_AUTH=true

# No OIDC redirect
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

Syncthing Setup Instructions:
=============================

Syncthing does not support OIDC or LDAP.
Use Authelia forward auth to protect the web UI.

Protect the App:
----------------
dokku auth:protect $APP \\
  --service $SERVICE \\
  --bypass-path "/rest/*"

Note: /rest/* is bypassed for API access (requires API key).

Syncthing Authentication:
-------------------------
Syncthing has its own authentication. You can either:

1. Disable Syncthing auth, use Authelia only:
   - In Syncthing GUI: Settings > GUI > uncheck "Use HTTPS"
   - Remove GUI username/password
   - Rely on Authelia for authentication

2. Keep both (defense in depth):
   - Authelia protects external access
   - Syncthing auth as backup

API Key:
--------
Syncthing uses API keys for REST API access.
Find it in: Actions > Settings > API Key

For scripts/automation, use:
  curl -H "X-API-Key: <apikey>" https://<domain>/rest/...

BEP Protocol:
-------------
Syncthing device-to-device sync (port 22000) is separate
from the web UI and doesn't go through the reverse proxy.

EOF
}

# No LDAP support
preset_ldap_config() {
  cat <<EOF
Syncthing LDAP Support:
=======================

Syncthing does not support LDAP authentication.
Use forward auth (dokku auth:protect) instead.

EOF
}
