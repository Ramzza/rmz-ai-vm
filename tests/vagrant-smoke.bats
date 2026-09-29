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
  cp -R "${REPO_ROOT}/.github" "${PROJECT_DIRECTORY}/.github"
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

@test "Vagrant provisions a runnable Copilot CLI with managed settings" {
  run vagrant_in_project up --provider virtualbox
  [ "${status}" -eq 0 ]

  smoke_command="$(cat <<'EOF'
set -eu
version="$("$HOME/.local/bin/copilot" --version)"
test -n "$version"
printf '%s\n' "$version"
jq -e --slurpfile expected \
  /workspace/rmz-ai-vm/provision/copilot-settings.json \
  '.model == $expected[0].model
   and .effortLevel == $expected[0].effortLevel
   and .tabs.hide == $expected[0].tabs.hide' \
  "$HOME/.copilot/settings.json" >/dev/null
if timeout --kill-after=1s 4s \
  script -q -e -c 'bash -ic copilot' /dev/null >/dev/null 2>&1; then
  startup_status=0
else
  startup_status=$?
fi
test "$startup_status" -eq 124
EOF
)"

  run vagrant_in_project ssh -c "${smoke_command}"
  [ "${status}" -eq 0 ]
  [ -n "${output}" ]
}
