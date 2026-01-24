#!/usr/bin/env bash
# LLDAP Provider Implementation

set -eo pipefail
[[ $DOKKU_TRACE ]] && set -x

PROVIDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config.sh
source "$PROVIDER_DIR/config.sh"

# Get LLDAP API URL for a service
_get_lldap_api_url() {
  local SERVICE="$1"
  local SERVICE_ROOT
  SERVICE_ROOT="$(get_service_root "$SERVICE")"

  if [[ -f "$SERVICE_ROOT/provider-config/API_URL" ]]; then
    cat "$SERVICE_ROOT/provider-config/API_URL"
  else
    # Default to dokku app URL
    echo "https://lldap-${SERVICE}.${AUTH_DEFAULT_DOMAIN}"
  fi
}

# Get LLDAP admin password for a service
_get_lldap_password() {
  local SERVICE="$1"
  local SERVICE_ROOT
  SERVICE_ROOT="$(get_service_root "$SERVICE")"

  if [[ -f "$SERVICE_ROOT/provider-config/ADMIN_PASSWORD" ]]; then
    cat "$SERVICE_ROOT/provider-config/ADMIN_PASSWORD"
  fi
}

# Get LLDAP base DN for a service
_get_lldap_base_dn() {
  local SERVICE="$1"
  local SERVICE_ROOT
  SERVICE_ROOT="$(get_service_root "$SERVICE")"

  if [[ -f "$SERVICE_ROOT/provider-config/BASE_DN" ]]; then
    cat "$SERVICE_ROOT/provider-config/BASE_DN"
  else
    echo "dc=${AUTH_DEFAULT_DOMAIN//./,dc=}"
  fi
}

# Get authentication token from LLDAP
provider_get_token() {
  local SERVICE="$1"
  local API_URL
  local PASSWORD

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  PASSWORD="$(_get_lldap_password "$SERVICE")"

  if [[ -z "$PASSWORD" ]]; then
    echo "No admin password configured" >&2
    return 1
  fi

  local RESPONSE
  RESPONSE=$(curl -s -X POST "${API_URL}/auth/simple/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"${PASSWORD}\"}")

  echo "$RESPONSE" | jq -r '.token // empty'
}

# Validate provider credentials
provider_validate_credentials() {
  local SERVICE="$1"
  local TOKEN

  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  return 0
}

# List all users
provider_list_users() {
  local SERVICE="$1"
  local API_URL
  local TOKEN

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d '{"query":"{ users { id email displayName creationDate uuid } }"}' |
    jq '.data.users'
}

# List all groups
provider_list_groups() {
  local SERVICE="$1"
  local API_URL
  local TOKEN

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d '{"query":"{ groups { id displayName creationDate uuid } }"}' |
    jq '.data.groups'
}

# Get user by username
provider_get_user() {
  local SERVICE="$1"
  local USERNAME="$2"
  local API_URL
  local TOKEN

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{\"query\":\"{ user(userId: \\\"${USERNAME}\\\") { id email displayName creationDate uuid groups { id displayName } } }\"}" |
    jq '.data.user'
}

# Get group members
provider_get_group_members() {
  local SERVICE="$1"
  local GROUP_ID="$2"
  local API_URL
  local TOKEN

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{\"query\":\"{ group(groupId: ${GROUP_ID}) { users { id } } }\"}" |
    jq -r '.data.group.users[].id'
}

# Create app group
provider_create_app_group() {
  local SERVICE="$1"
  local APP_NAME="$2"
  local GROUP_NAME="${APP_NAME}_users"
  local API_URL
  local TOKEN

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{\"query\":\"mutation { createGroup(name: \\\"${GROUP_NAME}\\\") { id displayName } }\"}" |
    jq '.data.createGroup'
}

# Delete app group
provider_delete_app_group() {
  local SERVICE="$1"
  local APP_NAME="$2"
  local GROUP_NAME="${APP_NAME}_users"
  local API_URL
  local TOKEN
  local GROUP_ID

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  # Get group ID first
  GROUP_ID=$(curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d '{"query":"{ groups { id displayName } }"}' |
    jq -r ".data.groups[] | select(.displayName == \"${GROUP_NAME}\") | .id")

  if [[ -z "$GROUP_ID" ]]; then
    return 0 # Group doesn't exist, nothing to delete
  fi

  curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{\"query\":\"mutation { deleteGroup(groupId: ${GROUP_ID}) { ok } }\"}"
}

# Add user to group
provider_add_user_to_group() {
  local SERVICE="$1"
  local USER_ID="$2"
  local GROUP_ID="$3"
  local API_URL
  local TOKEN

  API_URL="$(_get_lldap_api_url "$SERVICE")"
  TOKEN="$(provider_get_token "$SERVICE")"

  if [[ -z "$TOKEN" ]]; then
    return 1
  fi

  curl -s -X POST "${API_URL}/api/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{\"query\":\"mutation { addUserToGroup(userId: \\\"${USER_ID}\\\", groupId: ${GROUP_ID}) { ok } }\"}"
}

# Create LLDAP container for service
provider_create_container() {
  local SERVICE="$1"
  local SERVICE_ROOT
  local DATA_DIR
  local CONTAINER_NAME
  local NETWORK
  local BASE_DN
  local ADMIN_PASSWORD
  local JWT_SECRET

  SERVICE_ROOT="$(get_service_root "$SERVICE")"
  DATA_DIR="$(get_service_data_dir "$SERVICE")/lldap"
  CONTAINER_NAME="$(get_lldap_container "$SERVICE")"
  NETWORK="$(get_service_network "$SERVICE")"
  BASE_DN="$(_get_lldap_base_dn "$SERVICE")"
  ADMIN_PASSWORD="$(generate_password)"
  JWT_SECRET="$(generate_secret)"

  # Store credentials
  mkdir -p "$SERVICE_ROOT/provider-config"
  echo "$ADMIN_PASSWORD" >"$SERVICE_ROOT/provider-config/ADMIN_PASSWORD"
  echo "$BASE_DN" >"$SERVICE_ROOT/provider-config/BASE_DN"
  echo "$JWT_SECRET" >"$SERVICE_ROOT/provider-config/JWT_SECRET"
  chmod 600 "$SERVICE_ROOT/provider-config"/*

  # Create data directory
  mkdir -p "$DATA_DIR"

  # Create network if it doesn't exist
  docker network create "$NETWORK" 2>/dev/null || true

  # Run container
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    -v "${DATA_DIR}:/data" \
    -e "LLDAP_JWT_SECRET=${JWT_SECRET}" \
    -e "LLDAP_LDAP_USER_PASS=${ADMIN_PASSWORD}" \
    -e "LLDAP_LDAP_BASE_DN=${BASE_DN}" \
    -e "LLDAP_LDAP_USER_EMAIL=admin@${AUTH_DEFAULT_DOMAIN}" \
    -e "TZ=${TZ:-America/New_York}" \
    "$PROVIDER_DOCKER_IMAGE"

  # Store API URL (internal network URL)
  echo "http://${CONTAINER_NAME}:${PROVIDER_WEB_PORT}" >"$SERVICE_ROOT/provider-config/API_URL"

  return 0
}

# Destroy LLDAP container for service
provider_destroy_container() {
  local SERVICE="$1"
  local CONTAINER_NAME
  CONTAINER_NAME="$(get_lldap_container "$SERVICE")"

  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true

  return 0
}

# Get container status
provider_container_status() {
  local SERVICE="$1"
  local CONTAINER_NAME
  CONTAINER_NAME="$(get_lldap_container "$SERVICE")"

  docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "not found"
}

# Get container logs
provider_container_logs() {
  local SERVICE="$1"
  local LINES="${2:-100}"
  local CONTAINER_NAME
  CONTAINER_NAME="$(get_lldap_container "$SERVICE")"

  docker logs --tail "$LINES" "$CONTAINER_NAME" 2>&1
}
