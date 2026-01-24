# dokku-auth

A Dokku plugin for managing LDAP authentication and authentication gateways.

## Features

- **LDAP Backend**: Uses LLDAP as a lightweight LDAP server for user management
- **Authentication Gateway**: Authelia provides SSO, 2FA, and forward authentication
- **OIDC Provider**: Configure OIDC clients for your applications
- **Forward Auth**: Protect apps with authentication at the nginx level
- **App Integration**: Link apps to provide LDAP credentials as environment variables

## Requirements

- Dokku 0.30.0+
- Docker
- Python 3 (for YAML manipulation)

## Installation

```bash
# Install the plugin
sudo dokku plugin:install https://github.com/deanmarano/dokku-auth.git auth

# Or install from local directory during development
sudo dokku plugin:install file:///path/to/dokku-auth auth
```

## Quick Start

```bash
# Create an auth service
dokku auth:create default

# Link an app to the auth service (provides LDAP credentials)
dokku auth:link default myapp

# Add an OIDC client for an application
dokku auth:oidc:add default myapp --redirect-uri https://myapp.example.com/callback

# Protect an app with forward authentication
dokku auth:protect default myapp
```

## Commands

### Service Management

```bash
# Create an auth service
dokku auth:create <service> [--provider lldap] [--gateway-domain auth.example.com]

# Destroy an auth service
dokku auth:destroy <service> [-f|--force]

# List all auth services
dokku auth:list

# Show service information
dokku auth:info <service>

# Show service status
dokku auth:status <service>

# View logs
dokku auth:logs <service> [-t|--tail 50] [-f|--follow] [--lldap|--authelia]
```

### App Linking

Link apps to provide LDAP credentials as environment variables:

```bash
# Link an app
dokku auth:link <service> <app>

# Unlink an app
dokku auth:unlink <service> <app>
```

When linked, apps receive these environment variables:
- `LDAP_HOST`: LLDAP container name (resolvable on the service network)
- `LDAP_PORT`: LDAP port (3890)
- `LDAP_BASE_DN`: Base DN for LDAP queries
- `LDAP_BIND_DN`: DN for binding to LDAP
- `LDAP_BIND_PASSWORD`: Password for LDAP binding
- `LDAP_USER_FILTER`: Filter for user searches
- `LDAP_GROUP_FILTER`: Filter for group searches

### OIDC Client Management

Configure OIDC clients for applications to use Authelia as an identity provider:

```bash
# Add an OIDC client
dokku auth:oidc:add <service> <client_id> --redirect-uri <uri> [--secret <secret>] [--public] [--pkce]

# Remove an OIDC client
dokku auth:oidc:remove <service> <client_id> [-f|--force]

# List OIDC clients
dokku auth:oidc:list <service> [-q|--quiet]
```

### Forward Authentication

Protect apps with forward authentication via Authelia:

```bash
# Protect an app
dokku auth:protect <service> <app> [--bypass-path /api/health] [--require-group admin] [--policy one_factor]

# Remove protection
dokku auth:unprotect <service> <app> [-f|--force]
```

## Architecture

```
                                    ┌─────────────────┐
                                    │    Authelia     │
                                    │  (SSO Gateway)  │
                                    │   Port 9091     │
                                    └────────┬────────┘
                                             │
                                             │ LDAP Auth
                                             │
                                    ┌────────▼────────┐
                                    │     LLDAP       │
                                    │  (LDAP Server)  │
                                    │   Port 3890     │
                                    │   Port 17170    │
                                    └────────┬────────┘
                                             │
                                             │ Docker Network
                                             │ (auth-<service>)
                                             │
              ┌──────────────────────────────┼──────────────────────────────┐
              │                              │                              │
     ┌────────▼────────┐            ┌────────▼────────┐            ┌────────▼────────┐
     │    App 1        │            │    App 2        │            │    App 3        │
     │  (LDAP linked)  │            │  (OIDC client)  │            │  (Protected)    │
     └─────────────────┘            └─────────────────┘            └─────────────────┘
```

## Configuration

### Environment Variables

Set these in your Dokku environment or in the plugin config:

- `AUTH_DEFAULT_DOMAIN`: Default domain for services (default: from dokku global domain)
- `AUTH_DEFAULT_PROVIDER`: Default LDAP provider (default: lldap)

### Authelia Configuration

The Authelia configuration is stored at:
```
/var/lib/dokku/data/storage/auth-<service>/authelia/configuration.yml
```

You can manually edit this file for advanced configuration, then restart Authelia:
```bash
docker restart auth-<service>-authelia
```

### LLDAP Web UI

Access the LLDAP admin interface at:
```
http://<server-ip>:17170
```

Default admin credentials are stored in:
```
/var/lib/dokku/services/auth/<service>/provider-config/ADMIN_PASSWORD
```

## Development

### Setup

```bash
# Clone the repository
git clone https://github.com/deanmarano/dokku-auth.git
cd dokku-auth

# Initialize submodules (for testing)
git submodule update --init --recursive

# Or install BATS helpers manually
git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert
```

### Testing

```bash
# Run linting
make lint

# Check formatting
make format-check

# Format scripts
make format

# Run unit tests
make test-unit

# Run all tests (requires Dokku installed)
make test-integration
```

### Project Structure

```
dokku-auth/
├── plugin.toml           # Plugin metadata
├── config                 # Configuration and constants
├── commands               # Command dispatcher
├── functions              # Shared utility functions
├── help-functions         # Help system
├── log-functions          # Logging utilities
├── install                # Plugin installation hook
├── providers/
│   └── lldap/
│       ├── config.sh      # Provider configuration
│       └── provider.sh    # Provider implementation
├── subcommands/
│   ├── create             # auth:create
│   ├── destroy            # auth:destroy
│   ├── info               # auth:info
│   ├── list               # auth:list
│   ├── link               # auth:link
│   ├── unlink             # auth:unlink
│   ├── status             # auth:status
│   ├── logs               # auth:logs
│   ├── oidc-add           # auth:oidc:add
│   ├── oidc-remove        # auth:oidc:remove
│   ├── oidc-list          # auth:oidc:list
│   ├── protect            # auth:protect
│   └── unprotect          # auth:unprotect
├── tests/
│   ├── test_helper.bash   # Test utilities
│   ├── test_helper/       # BATS support libraries
│   ├── unit/              # Unit tests
│   └── integration/       # Integration tests
└── .github/
    └── workflows/
        └── ci.yml         # GitHub Actions CI
```

## License

MIT License
