# Homelab App Integrations

This document tracks planned integrations for the dokku-auth plugin. Each integration provides pre-configured OIDC client settings and/or LDAP configuration helpers for popular self-hosted applications.

## Integration Priority

### Tier 1: Full OIDC + LDAP Support
These apps have native support for both OpenID Connect and LDAP, making them ideal first integrations.

| App | OIDC | LDAP | Proxy Auth | Status |
|-----|------|------|------------|--------|
| [Nextcloud](https://nextcloud.com) | ✓ | ✓ | ✓ | Done |
| [Gitea](https://gitea.io) | ✓ | ✓ | ✓ | Done |
| [Portainer](https://portainer.io) | ✓ | ✓ | - | Done |
| [Proxmox](https://proxmox.com) | ✓ | ✓ | - | Planned |
| [GitLab](https://gitlab.com) | ✓ | ✓ | - | Planned |
| [Bookstack](https://www.bookstackapp.com) | ✓ | ✓ | - | Planned |
| [Hedgedoc](https://hedgedoc.org) | ✓ | ✓ | - | Planned |

### Tier 2: OIDC-Only Apps
These apps support OpenID Connect but not LDAP.

| App | OIDC | LDAP | Proxy Auth | Status |
|-----|------|------|------------|--------|
| [Immich](https://immich.app) | ✓ | - | - | Done |
| [Grafana](https://grafana.com) | ✓ | ✓ | - | Done |
| [Audiobookshelf](https://audiobookshelf.org) | ✓ | - | - | Done |
| [Miniflux](https://miniflux.app) | ✓ | - | ✓ | Planned |
| [Open WebUI](https://openwebui.com) | ✓ | - | - | Planned |
| [Outline](https://getoutline.com) | ✓ | - | - | Done |
| [Matrix Synapse](https://matrix.org) | ✓ | ✓ | - | Planned |

### Tier 3: LDAP-Only Apps
These apps support LDAP but not OIDC directly.

| App | OIDC | LDAP | Proxy Auth | Status |
|-----|------|------|------------|--------|
| [Jellyfin](https://jellyfin.org) | - | ✓ (plugin) | - | Done |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | - | ✓ | - | Planned |
| [WikiJS](https://js.wiki) | - | ✓ | - | Planned |
| [Calibre-Web](https://github.com/janeczku/calibre-web) | - | ✓ | ✓ | Planned |
| [Navidrome](https://navidrome.org) | - | ✓ | ✓ | Planned |
| [Paperless-ngx](https://docs.paperless-ngx.com) | - | ✓ | ✓ | Planned |

### Tier 4: Proxy Auth Only
These apps don't support OIDC or LDAP natively but can be protected via Authelia forward auth.

| App | OIDC | LDAP | Proxy Auth | Status |
|-----|------|------|------------|--------|
| [Syncthing](https://syncthing.net) | - | - | ✓ | Planned |
| [Radarr](https://radarr.video) | - | - | ✓ | Planned |
| [Sonarr](https://sonarr.tv) | - | - | ✓ | Planned |
| [Prowlarr](https://prowlarr.com) | - | - | ✓ | Planned |
| [Lidarr](https://lidarr.audio) | - | - | ✓ | Planned |
| [Bazarr](https://bazarr.media) | - | - | ✓ | Planned |
| [Uptime Kuma](https://uptime.kuma.pet) | - | - | ✓ | Planned |
| [Pi-hole](https://pi-hole.net) | - | - | ✓ | Planned |
| [Linkding](https://github.com/sissbruecker/linkding) | - | - | ✓ | Planned |
| [Changedetection.io](https://changedetection.io) | - | - | ✓ | Planned |
| [Home Assistant](https://home-assistant.io) | - | ✓ | ✓ | Planned |
| [Apache Guacamole](https://guacamole.apache.org) | ✓ | ✓ | ✓ | Planned |

## Commands

### Using Presets with OIDC

```bash
# List available presets
dokku auth:integrate --list

# Full integration (creates OIDC client + shows app-specific instructions)
dokku auth:integrate <service> <app> --preset <preset>
dokku auth:integrate default mycloud --preset nextcloud --set-env

# Or use preset with oidc:add directly
dokku auth:oidc:add <service> <client> --preset <preset> --domain <app-domain>
dokku auth:oidc:add default photos --preset immich --domain photos.example.com
```

### Available Presets

- `nextcloud` - Nextcloud with user_oidc app
- `gitea` - Gitea / Forgejo git server
- `immich` - Immich photo management
- `jellyfin` - Jellyfin media server (LDAP only)
- `portainer` - Portainer container management
- `grafana` - Grafana monitoring dashboard
- `audiobookshelf` - Audiobookshelf audiobook server
- `outline` - Outline wiki/knowledge base

## Integration Details

### Nextcloud

**OIDC Configuration:**
- Requires: `user_oidc` app installed
- Scopes: `openid profile email groups`
- PKCE: Required (S256)
- Redirect URI: `https://<domain>/apps/user_oidc/code`

**LDAP Configuration:**
- Base DN: `ou=people,dc=<domain>`
- User filter: `(objectClass=person)`
- Group filter: `(objectClass=groupOfUniqueNames)`

### Gitea

**OIDC Configuration:**
- Scopes: `openid profile email groups`
- Redirect URI: `https://<domain>/user/oauth2/authelia/callback`
- Auto-discover from `.well-known/openid-configuration`

**LDAP Configuration:**
- Bind DN pattern support
- Group sync supported

### Immich

**OIDC Configuration:**
- Scopes: `openid profile email`
- Redirect URI: `app.immich:/` (mobile) and `https://<domain>/auth/login` (web)
- Requires: `OAUTH_ENABLED=true`

### Jellyfin

**LDAP Configuration (via plugin):**
- LDAP Bind User: `uid=admin,ou=people,dc=<domain>`
- LDAP Search Base: `ou=people,dc=<domain>`
- LDAP Search Filter: `(uid=*)`
- LDAP Admin Filter: `(memberOf=cn=jellyfin_admin,ou=groups,dc=<domain>)`

### Portainer

**OIDC Configuration:**
- Scopes: `openid profile email groups`
- Redirect URI: `https://<domain>`
- Note: Users must be pre-created in Portainer before OIDC login

### Grafana

**OIDC Configuration:**
- Scopes: `openid profile email groups`
- Redirect URI: `https://<domain>/login/generic_oauth`
- Role mapping via groups

**LDAP Configuration:**
- Supports group-to-role mapping
- Multiple LDAP servers supported

### *arr Apps (Radarr, Sonarr, etc.)

**Forward Auth Only:**
- No native authentication integration
- Use `auth:protect` with bypass paths for API access:
  ```bash
  dokku auth:protect myapp --bypass-path "/api/*"
  ```

## Implementation Roadmap

1. **Phase 1: Core Integrations**
   - Nextcloud (most requested)
   - Gitea (common dev tool)
   - Immich (popular photo management)
   - Jellyfin (popular media server)

2. **Phase 2: DevOps Tools**
   - Portainer
   - Grafana
   - GitLab

3. **Phase 3: Media & Content**
   - *arr stack (Radarr, Sonarr, etc.)
   - Audiobookshelf
   - Navidrome
   - Calibre-Web

4. **Phase 4: Productivity**
   - Bookstack
   - Hedgedoc
   - WikiJS
   - Paperless-ngx
   - Outline

5. **Phase 5: Infrastructure**
   - Proxmox
   - Home Assistant
   - Apache Guacamole
   - Syncthing

## References

- [Self-hosted Authentication Table](https://github.com/d-513/selfhosted-authentication-table)
- [Authelia OpenID Connect Docs](https://www.authelia.com/integration/openid-connect/)
- [Authelia Integration Guide](https://www.authelia.com/integration/prologue/get-started/)
- [LLDAP Documentation](https://github.com/lldap/lldap)
