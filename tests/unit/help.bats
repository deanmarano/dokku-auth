#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_test_dirs
}

teardown() {
  teardown_test_dirs
}

@test "help-functions: show_help outputs command list" {
  source "$PLUGIN_BASE_PATH/help-functions"

  run show_help
  assert_success
  assert_output --partial "auth:create"
  assert_output --partial "auth:destroy"
  assert_output --partial "auth:link"
  assert_output --partial "auth:unlink"
}

@test "help-functions: main help includes OIDC commands" {
  source "$PLUGIN_BASE_PATH/help-functions"

  run show_help
  assert_success
  assert_output --partial "auth:oidc:add"
  assert_output --partial "auth:oidc:remove"
  assert_output --partial "auth:oidc:list"
}

@test "help-functions: main help includes protection commands" {
  source "$PLUGIN_BASE_PATH/help-functions"

  run show_help
  assert_success
  assert_output --partial "auth:protect"
  assert_output --partial "auth:unprotect"
}
