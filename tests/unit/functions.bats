#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_test_dirs
}

teardown() {
  teardown_test_dirs
}

@test "functions: service_exists returns false for non-existent service" {
  run service_exists "nonexistent"
  assert_failure
}

@test "functions: service_exists returns true for existing service" {
  create_mock_service "test-service"

  run service_exists "test-service"
  assert_success

  destroy_mock_service "test-service"
}

@test "functions: get_service_root returns correct path" {
  run get_service_root "myservice"
  assert_success
  assert_output "$PLUGIN_DATA_ROOT/myservice"
}

@test "functions: get_service_data_dir returns correct path" {
  run get_service_data_dir "myservice"
  assert_success
  assert_output "$AUTH_DATA_ROOT/auth-myservice"
}

@test "functions: get_service_provider returns default for new service" {
  mkdir -p "$PLUGIN_DATA_ROOT/test-service"

  run get_service_provider "test-service"
  assert_success
  assert_output "lldap"

  rmdir "$PLUGIN_DATA_ROOT/test-service"
}

@test "functions: get_service_provider returns stored provider" {
  create_mock_service "test-service"

  run get_service_provider "test-service"
  assert_success
  assert_output "lldap"

  destroy_mock_service "test-service"
}

@test "functions: generate_secret produces 64-char hex string" {
  run generate_secret
  assert_success
  assert [ ${#output} -eq 64 ]
  [[ "$output" =~ ^[a-f0-9]+$ ]]
}

@test "functions: generate_password produces password" {
  run generate_password
  assert_success
  assert [ ${#output} -ge 20 ]
}

@test "functions: get_linked_apps returns empty for new service" {
  create_mock_service "test-service"

  run get_linked_apps "test-service"
  assert_success
  assert_output ""

  destroy_mock_service "test-service"
}

@test "functions: add_app_link adds app to links" {
  create_mock_service "test-service"

  add_app_link "test-service" "myapp"

  run get_linked_apps "test-service"
  assert_success
  assert_output "myapp"

  destroy_mock_service "test-service"
}

@test "functions: is_app_linked returns true for linked app" {
  create_mock_service "test-service"
  add_app_link "test-service" "myapp"

  run is_app_linked "test-service" "myapp"
  assert_success

  destroy_mock_service "test-service"
}

@test "functions: is_app_linked returns false for unlinked app" {
  create_mock_service "test-service"

  run is_app_linked "test-service" "myapp"
  assert_failure

  destroy_mock_service "test-service"
}

@test "functions: remove_app_link removes app from links" {
  create_mock_service "test-service"
  add_app_link "test-service" "myapp"
  add_app_link "test-service" "otherapp"

  remove_app_link "test-service" "myapp"

  run is_app_linked "test-service" "myapp"
  assert_failure

  run is_app_linked "test-service" "otherapp"
  assert_success

  destroy_mock_service "test-service"
}

@test "functions: get_lldap_container returns correct name" {
  run get_lldap_container "myservice"
  assert_success
  assert_output "auth-myservice-lldap"
}

@test "functions: get_authelia_container returns correct name" {
  run get_authelia_container "myservice"
  assert_success
  assert_output "auth-myservice-authelia"
}

@test "functions: get_service_network returns correct name" {
  run get_service_network "myservice"
  assert_success
  assert_output "auth-myservice"
}
