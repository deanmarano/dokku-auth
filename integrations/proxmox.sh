#!/usr/bin/env bash
# Proxmox VE OIDC integration preset
# https://pve.proxmox.com/wiki/User_Management#pveum_openid

PRESET_NAME="proxmox"
PRESET_DESCRIPTION="Proxmox VE virtualization platform"
PRESET_SCOPES="openid profile email"
PRESET_REQUIRE_PKCE=false
PRESET_PUBLIC=false
PRESET_LDAP_SUPPORTED=true

# Proxmox doesn't use standard redirect URI
preset_redirect_uri() {
  local DOMAIN="$1"
  # Proxmox expects no redirect URI in OIDC config
  # It handles redirects internally
  echo "https://${DOMAIN}"
}

# No environment variables - Proxmox uses CLI/GUI config
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

Proxmox VE OIDC Setup Instructions:
====================================

Via CLI (on Proxmox host):
--------------------------
pveum realm add authelia --type openid \\
  --issuer-url "https://${AUTH_DOMAIN}" \\
  --client-id "$CLIENT_ID" \\
  --client-key "<client_secret>" \\
  --username-claim "preferred_username" \\
  --autocreate 1

Via Web UI:
-----------
1. Go to Datacenter > Permissions > Realms
2. Click "Add" and select "OpenID Connect Server"
3. Configure:
   - Realm: authelia
   - Issuer URL: https://${AUTH_DOMAIN}
   - Client ID: $CLIENT_ID
   - Client Key: <client_secret>
   - Default: No (or Yes to make default login)
   - Autocreate Users: Yes
   - Username Claim: preferred_username

User Permissions:
-----------------
After users log in, assign permissions:
  pveum acl modify / --users <user>@authelia --roles PVEAdmin

Or create groups and assign permissions to groups:
  pveum group add admins
  pveum acl modify / --groups admins --roles PVEAdmin

EOF
}

# LDAP configuration for Proxmox
preset_ldap_config() {
  local SERVICE="$1"
  local LDAP_HOST="$2"
  local LDAP_PORT="$3"
  local BASE_DN="$4"
  local BIND_DN="$5"

  cat <<EOF
Proxmox VE LDAP Setup Instructions:
====================================

Via CLI:
--------
pveum realm add lldap --type ldap \\
  --base_dn "ou=people,$BASE_DN" \\
  --bind_dn "$BIND_DN" \\
  --server1 "$LDAP_HOST" \\
  --port $LDAP_PORT \\
  --secure 0 \\
  --user_attr "uid" \\
  --default 0

Then set the password:
  pveum realm modify lldap --password "<bind_password>"

Via Web UI:
-----------
1. Go to Datacenter > Permissions > Realms
2. Click "Add" and select "LDAP Server"
3. Configure:
   - Realm: lldap
   - Base Domain Name: ou=people,$BASE_DN
   - User Attribute Name: uid
   - Server: $LDAP_HOST
   - Port: $LDAP_PORT
   - SSL: unchecked
   - Bind User: $BIND_DN
   - Bind Password: <bind_password>

Sync Groups (optional):
-----------------------
pveum realm modify lldap \\
  --group_dn "ou=groups,$BASE_DN" \\
  --group_filter "(objectClass=groupOfUniqueNames)" \\
  --group_name_attr "cn" \\
  --sync_attributes "email:mail,firstname:givenName"

pveum realm sync lldap --scope both

EOF
}
