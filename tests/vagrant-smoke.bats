#!/usr/bin/env bats

setup() {
  if [[ "${RUN_VAGRANT_SMOKE:-0}" != "1" ]]; then
    skip "set RUN_VAGRANT_SMOKE=1 to run the Vagrant integration test"
  fi

  if ! command -v vagrant >/dev/null 2>&1; then
    printf 'Vagrant is required for the Vagrant integration test\n' >&2
    return 1
  fi
  if ! command -v VBoxManage >/dev/null 2>&1; then
    printf 'VirtualBox is required for the Vagrant integration test\n' >&2
    return 1
  fi

  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_DIRECTORY="$(mktemp -d)"
  PROJECT_DIRECTORY="${TEST_DIRECTORY}/workspace/rmz-ai-vm"
  VAGRANT_HOME_DIRECTORY="${TEST_DIRECTORY}/vagrant-home"
  VM_NAME="copilot-smoke-$$"
  mkdir -p "${PROJECT_DIRECTORY}"
  cp "${REPO_ROOT}/Vagrantfile" "${PROJECT_DIRECTORY}/Vagrantfile"
  cp "${REPO_ROOT}/vm-config.json" "${PROJECT_DIRECTORY}/vm-config.json"
  cp -R "${REPO_ROOT}/provision" "${PROJECT_DIRECTORY}/provision"
}

teardown() {
  if [[ -n "${PROJECT_DIRECTORY:-}" &&
    -d "${PROJECT_DIRECTORY}/.vagrant" ]]; then
    (
      cd "${PROJECT_DIRECTORY}"
      VM_NAME="${VM_NAME}" \
        VAGRANT_HOME="${VAGRANT_HOME_DIRECTORY}" \
        vagrant destroy --force
    ) || return 1
  fi

  if [[ -n "${TEST_DIRECTORY:-}" && -d "${TEST_DIRECTORY}" ]]; then
    rm -rf -- "${TEST_DIRECTORY}"
  fi
}

vagrant_in_project() {
  (
    cd "${PROJECT_DIRECTORY}"
    VM_NAME="${VM_NAME}" \
      VAGRANT_HOME="${VAGRANT_HOME_DIRECTORY}" \
      vagrant "$@"
  )
}

@test "PRD-003: Vagrant provisions and runs the official Copilot CLI" {
  run vagrant_in_project up --provider virtualbox
  [ "${status}" -eq 0 ]

  smoke_command="$(cat <<'EOF'
set -eu
  copilot_path="$(command -v copilot)"
  test "$copilot_path" = /usr/local/bin/copilot
  version="$(copilot --version)"
  test -n "$version"
  printf '%s\n' "$copilot_path"
  printf '%s\n' "$version"
test ! -e "$HOME/.copilot/settings.json"
test ! -e "$HOME/.copilot/copilot-instructions.md"
test ! -e "$HOME/.copilot/skills"
EOF
)"

  run vagrant_in_project ssh -c "${smoke_command}"
  [ "${status}" -eq 0 ]
  [ -n "${output}" ]
}
