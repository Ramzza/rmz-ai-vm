#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  VAGRANTFILE="${VAGRANTFILE_PATH:-${REPO_ROOT}/Vagrantfile}"
}

assert_contains() {
  run grep -F -q -- "$1" "${VAGRANTFILE}"
  [ "${status}" -eq 0 ]
}

@test "PRD-001: provisions a persistent headless Ubuntu 22.04 workspace" {
  assert_contains 'config.vm.box = "ubuntu/jammy64"'
  assert_contains 'config.vm.synced_folder File.expand_path("..", __dir__),'
  assert_contains '"/workspace",'
  assert_contains 'vb.gui = false'
}

@test "PRD-002: supports default and override VM resource settings" {
  assert_contains 'ENV.fetch("VM_CPUS", "2").to_i'
  assert_contains 'ENV.fetch("VM_MEMORY_MB", "6144").to_i'
  assert_contains 'ENV.fetch("VM_NAME", "copilot-dev")'
}

@test "PRD-003: passes the selected user and repository assets to bootstrap" {
  assert_contains 'ENV.fetch("VM_USER", "vagrant")'
  assert_contains 'path: "provision/bootstrap.sh"'
  assert_contains 'File.join("/workspace", File.basename(__dir__), ".github", "skills")'
  assert_contains 'File.join("/workspace", File.basename(__dir__), ".github", "copilot-instructions.md")'
  assert_contains 'File.join("/workspace", File.basename(__dir__), "provision", "copilot-settings.json")'
  assert_contains 'File.join("/workspace", File.basename(__dir__), "provision", "configure-copilot-settings.sh")'
  assert_contains 'File.join("/workspace", File.basename(__dir__), "provision", "install-copilot.sh")'
}
