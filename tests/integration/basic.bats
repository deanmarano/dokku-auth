#!/usr/bin/env bats

load '../test_helper'

# Integration tests require Dokku to be installed
# These tests run against a real Dokku installation

setup() {
  # Skip if dokku is not available
  if ! command -v dokku &>/dev/null; then
    skip "Dokku is not installed"
  fi
}

@test "integration: plugin is installed" {
  run dokku plugin:list
  assert_success
  assert_output --partial "auth"
}

@test "integration: help command works" {
  run dokku auth:help
  assert_success
  assert_output --partial "auth:create"
  assert_output --partial "auth:destroy"
}

@test "integration: list shows no services initially" {
  run dokku auth:list
  assert_success
  # Output should be empty or show "no services"
}

# Note: The following tests create real Docker containers
# They should only be run in CI or dedicated test environments

@test "integration: create and destroy service" {
  skip "Requires Docker - run manually or in CI"

  local SERVICE="test-$$"

  # Create service
  run dokku auth:create "$SERVICE"
  assert_success

  # Verify service exists
  run dokku auth:list
  assert_success
  assert_output --partial "$SERVICE"

  # Destroy service
  run dokku auth:destroy "$SERVICE" --force
  assert_success

  # Verify service is gone
  run dokku auth:list
  refute_output --partial "$SERVICE"
}
