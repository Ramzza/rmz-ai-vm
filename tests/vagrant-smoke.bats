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
  mkdir -p "${PROJECT_DIRECTORY}/.github"
  cp "${REPO_ROOT}/.github/copilot-instructions.md" \
    "${PROJECT_DIRECTORY}/.github/copilot-instructions.md"
  cp -R "${REPO_ROOT}/.github/skills" "${PROJECT_DIRECTORY}/.github/skills"
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

@test "PRD-003: Vagrant installs Copilot before optional manual initialization" {
  run vagrant_in_project up --provider virtualbox
  [ "${status}" -eq 0 ]

  smoke_command="$(cat <<'EOF'
set -eu
copilot_path="$(command -v copilot)"
test "$copilot_path" = /usr/local/bin/copilot
test ! -e "$HOME/.copilot"
version="$(copilot --version)"
test -n "$version"
printf '%s\n' "$copilot_path"
printf '%s\n' "$version"
test "$(command -v copilot-init)" = /usr/local/bin/copilot-init
test ! -e "$HOME/.copilot/copilot-instructions.md"
test ! -e "$HOME/.copilot/skills"
python3 - <<'PY'
import errno
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios
import time

os.environ["TERM"] = "xterm-256color"
pid, terminal = pty.fork()
if pid == 0:
    os.execvp("copilot", ["copilot"])

fcntl.ioctl(terminal, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
deadline = time.monotonic() + 5
output = bytearray()
while time.monotonic() < deadline:
    ended, status = os.waitpid(pid, os.WNOHANG)
    if ended:
        sys.stderr.write(
            f"Copilot exited before interactive startup (status {status}).\n"
        )
        sys.exit(1)
    readable, _, _ = select.select([terminal], [], [], 0.1)
    if readable:
        try:
            output.extend(os.read(terminal, 4096))
        except OSError as error:
            if error.errno != errno.EIO:
                raise

if not output:
    os.killpg(pid, signal.SIGTERM)
    os.waitpid(pid, 0)
    sys.exit("Copilot produced no interactive terminal output.")

os.write(terminal, b"\x03")
deadline = time.monotonic() + 2
while time.monotonic() < deadline:
    ended, _ = os.waitpid(pid, os.WNOHANG)
    if ended:
        break
    time.sleep(0.05)
else:
    os.killpg(pid, signal.SIGTERM)
    os.waitpid(pid, 0)

os.close(terminal)
print("Copilot opened an interactive pseudo-terminal.")
PY
EOF
)"

  run vagrant_in_project ssh -c "${smoke_command}"
  [ "${status}" -eq 0 ]
  [ -n "${output}" ]

  init_command="$(cat <<'EOF'
set -eu
copilot-init
test -L "$HOME/.copilot/copilot-instructions.md"
test "$(readlink -f "$HOME/.copilot/copilot-instructions.md")" = \
  "/workspace/rmz-ai-vm/.github/copilot-instructions.md"
test -L "$HOME/.copilot/skills/rmz-test"
test "$(readlink -f "$HOME/.copilot/skills/rmz-test")" = \
  "/workspace/rmz-ai-vm/.github/skills/rmz-test"
test -f "$HOME/.copilot/skills/rmz-test/SKILL.md"
copilot skill list | grep -F 'rmz-test'
copilot --version
test ! -e "$HOME/.copilot/settings.json"
EOF
)"

  run vagrant_in_project ssh -c "${init_command}"
  [ "${status}" -eq 0 ]
  [ -n "${output}" ]
}
