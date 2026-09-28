#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  LAUNCHER_PATH="${REPO_ROOT}/scripts/rmz-copilot.sh"
  SETUP_SCRIPT_PATH="${REPO_ROOT}/scripts/setup-rmz-copilot.sh"
  TEST_DIRECTORY="$(mktemp -d)"
  TEST_HOME="${TEST_DIRECTORY}/home"
  MOCK_BIN="${TEST_DIRECTORY}/bin"
  VAGRANT_LOG="${TEST_DIRECTORY}/vagrant.log"
  mkdir -p "${TEST_HOME}" "${MOCK_BIN}"
  export REPO_ROOT LAUNCHER_PATH SETUP_SCRIPT_PATH TEST_DIRECTORY TEST_HOME
  export HOME="${TEST_HOME}" SHELL=/bin/bash VAGRANT_LOG
  export PATH="${MOCK_BIN}:${PATH}"

  cat >"${MOCK_BIN}/vagrant" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s\n' "$*" "$PWD" >>"${VAGRANT_LOG}"
case "${1:-}" in
  up) exit "${VAGRANT_UP_STATUS:-0}" ;;
  ssh) exit "${VAGRANT_SSH_STATUS:-0}" ;;
  *) exit 99 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/vagrant"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

@test "PRD-005: launches host Vagrant from the repository before opening SSH" {
  run bash -c 'cd "$TEST_DIRECTORY" && bash "$LAUNCHER_PATH"'

  [ "${status}" -eq 0 ]
  [ "$(cat "${VAGRANT_LOG}")" = "up|${REPO_ROOT}
ssh|${REPO_ROOT}" ]
}

@test "PRD-005: does not open SSH when host vagrant up fails" {
  export VAGRANT_UP_STATUS=41

  run bash "${LAUNCHER_PATH}"

  [ "${status}" -eq 41 ]
  [ "$(cat "${VAGRANT_LOG}")" = "up|${REPO_ROOT}" ]
}

@test "PRD-005: propagates a host vagrant ssh failure" {
  export VAGRANT_SSH_STATUS=29

  run bash "${LAUNCHER_PATH}"

  [ "${status}" -eq 29 ]
  [ "$(cat "${VAGRANT_LOG}")" = "up|${REPO_ROOT}
ssh|${REPO_ROOT}" ]
}

@test "PRD-005: installs an idempotent rmz-copilot command for Bash" {
  printf 'export RMZ_TEST_PROFILE_VALUE=preserved' >"${HOME}/.bashrc"
  source_line='. "$HOME/.config/rmz-ai-vm/rmz-copilot.sh" # rmz-copilot setup'

  run bash -c 'cd "$TEST_DIRECTORY" && bash "$SETUP_SCRIPT_PATH"'
  [ "${status}" -eq 0 ]
  run bash -c 'cd "$TEST_DIRECTORY" && bash "$SETUP_SCRIPT_PATH"'
  [ "${status}" -eq 0 ]

  grep -q '^export RMZ_TEST_PROFILE_VALUE=preserved$' "${HOME}/.bashrc"
  [ "$(grep -Fxc -- "${source_line}" "${HOME}/.bashrc")" -eq 1 ]
  [ -f "${HOME}/.config/rmz-ai-vm/rmz-copilot.sh" ]

  run bash -c 'cd "$TEST_DIRECTORY"; source "$HOME/.bashrc"; rmz-copilot'

  [ "${status}" -eq 0 ]
  [ "$(cat "${VAGRANT_LOG}")" = "up|${REPO_ROOT}
ssh|${REPO_ROOT}" ]
}

@test "PRD-005: creates the Bash profile when it does not exist" {
  run bash "${SETUP_SCRIPT_PATH}"

  [ "${status}" -eq 0 ]
  [ -f "${HOME}/.bashrc" ]
  grep -Fq '. "$HOME/.config/rmz-ai-vm/rmz-copilot.sh" # rmz-copilot setup' \
    "${HOME}/.bashrc"
}

@test "PRD-005: reports when Linux login shell cannot be detected" {
  run env SHELL= bash "${SETUP_SCRIPT_PATH}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Cannot detect the login shell"* ]]
  [ ! -e "${HOME}/.bashrc" ]
  [ ! -e "${HOME}/.zshrc" ]
}

@test "PRD-005: rejects unsupported Linux shells without installing a profile" {
  run env SHELL=/bin/fish bash "${SETUP_SCRIPT_PATH}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Unsupported login shell: fish"* ]]
  [ ! -e "${HOME}/.bashrc" ]
  [ ! -e "${HOME}/.zshrc" ]
  [ ! -e "${HOME}/.config/rmz-ai-vm" ]
}

@test "PRD-005: installs rmz-copilot in Zsh startup files" {
  printf 'export RMZ_TEST_ZSH_PROFILE_VALUE=preserved\n' >"${HOME}/.zshrc"
  run env SHELL=/bin/zsh bash -c \
    'cd "$TEST_DIRECTORY" && bash "$SETUP_SCRIPT_PATH"'

  [ "${status}" -eq 0 ]
  grep -q '^export RMZ_TEST_ZSH_PROFILE_VALUE=preserved$' "${HOME}/.zshrc"
  grep -Fq '. "$HOME/.config/rmz-ai-vm/rmz-copilot.sh" # rmz-copilot setup' \
    "${HOME}/.zshrc"
  run bash -c 'cd "$TEST_DIRECTORY"; source "$HOME/.zshrc"; rmz-copilot'

  [ "${status}" -eq 0 ]
  [ "$(cat "${VAGRANT_LOG}")" = "up|${REPO_ROOT}
ssh|${REPO_ROOT}" ]
}
