#!/usr/bin/env bash
# Test helper functions for dokku-auth

# Load BATS helpers (paths relative to this file's location)
HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
load "${HELPER_DIR}/test_helper/bats-support/load"
load "${HELPER_DIR}/test_helper/bats-assert/load"

# Set up test environment - PLUGIN_BASE_PATH is the repository root
export PLUGIN_BASE_PATH="${HELPER_DIR}/.."
export PLUGIN_DATA_ROOT="${BATS_TMPDIR}/dokku-auth-test/services"
export PLUGIN_CONFIG_ROOT="${BATS_TMPDIR}/dokku-auth-test/config"
export AUTH_DATA_ROOT="${BATS_TMPDIR}/dokku-auth-test/data"
export AUTH_DEFAULT_DOMAIN="test.local"

# Source plugin config and functions
source "$PLUGIN_BASE_PATH/config"
source "$PLUGIN_BASE_PATH/functions"

# Create test directories
setup_test_dirs() {
  mkdir -p "$PLUGIN_DATA_ROOT"
  mkdir -p "$PLUGIN_CONFIG_ROOT"
  mkdir -p "$AUTH_DATA_ROOT"
}

# Clean up test directories
teardown_test_dirs() {
  rm -rf "${BATS_TMPDIR}/dokku-auth-test"
}

# Mock dokku command
mock_dokku() {
  export PATH="${BATS_TEST_DIRNAME}/mocks:$PATH"
}

# Generate a unique test service name
generate_test_service_name() {
  echo "test-$$-$RANDOM"
}

# Create a mock service for testing
create_mock_service() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"

  mkdir -p "$SERVICE_ROOT"/{provider-config,oidc-clients,gateway-config}
  echo "lldap" > "$SERVICE_ROOT/PROVIDER"
  echo "dc=test,dc=local" > "$SERVICE_ROOT/provider-config/BASE_DN"
  echo "test-password" > "$SERVICE_ROOT/provider-config/ADMIN_PASSWORD"
  echo "test-jwt-secret" > "$SERVICE_ROOT/provider-config/JWT_SECRET"
  echo "auth.test.local" > "$SERVICE_ROOT/gateway-config/DOMAIN"
}

# Clean up a mock service
destroy_mock_service() {
  local SERVICE="$1"
  rm -rf "$PLUGIN_DATA_ROOT/$SERVICE"
  rm -rf "$AUTH_DATA_ROOT/auth-$SERVICE"
}

# Assert file contains text
assert_file_contains() {
  local file="$1"
  local text="$2"

  if [[ ! -f "$file" ]]; then
    fail "File does not exist: $file"
  fi

  if ! grep -q "$text" "$file"; then
    fail "File '$file' does not contain '$text'"
  fi
}

# Assert file does not contain text
assert_file_not_contains() {
  local file="$1"
  local text="$2"

  if [[ ! -f "$file" ]]; then
    return 0  # File doesn't exist, so it doesn't contain the text
  fi

  if grep -q "$text" "$file"; then
    fail "File '$file' contains '$text' but shouldn't"
  fi
}
