#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  INSTALLER="${REPO_ROOT}/provision/install-copilot.sh"
  BOOTSTRAP="${REPO_ROOT}/provision/bootstrap.sh"
  TEST_DIRECTORY="$(mktemp -d)"
  MOCK_BIN="${TEST_DIRECTORY}/bin"
  INSTALL_LOG="${TEST_DIRECTORY}/npm-arguments"
  TEST_HOME="${TEST_DIRECTORY}/home"
  mkdir -p "${MOCK_BIN}"

  cat >"${MOCK_BIN}/runuser" <<'EOF'
#!/bin/bash
set -euo pipefail

[ "$1" = "-u" ]
[ "$2" = "vagrant" ]
[ "$3" = "--" ]
shift 3
"$@"
EOF
  chmod +x "${MOCK_BIN}/runuser"

  cat >"${MOCK_BIN}/npm" <<'EOF'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$@" >"${INSTALL_LOG:?}"
if [[ -n "${MOCK_COPILOT_HOME:-}" ]]; then
  mkdir -p "${MOCK_COPILOT_HOME}/.local/bin"
  cat >"${MOCK_COPILOT_HOME}/.local/bin/copilot" <<'CLI'
#!/bin/bash
set -euo pipefail
[ "${1:-}" = "--version" ]
printf '%s\n' 'Copilot CLI 1.0.88'
CLI
  chmod +x "${MOCK_COPILOT_HOME}/.local/bin/copilot"
fi
EOF
  chmod +x "${MOCK_BIN}/npm"

  cat >"${MOCK_BIN}/getent" <<'EOF'
#!/bin/bash
set -euo pipefail

[ "$1" = "passwd" ]
[ "$2" = "vagrant" ]
printf 'vagrant:x:1000:1000::%s:/bin/bash\n' "${TEST_HOME:?}"
EOF
  chmod +x "${MOCK_BIN}/getent"

  for command_name in apt-get git node code chown; do
    cat >"${MOCK_BIN}/${command_name}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${MOCK_BIN}/${command_name}"
  done

  cat >"${MOCK_BIN}/install" <<'EOF'
#!/bin/bash
set -euo pipefail

[ "$1" = "-d" ]
shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|-g|-m) shift 2 ;;
    *) break ;;
  esac
done
mkdir -p -- "$@"
EOF
  chmod +x "${MOCK_BIN}/install"

  cat >"${MOCK_BIN}/rm" <<'EOF'
#!/bin/bash
# Ignore bootstrap cleanup that would otherwise target the host package lists.
exit 0
EOF
  chmod +x "${MOCK_BIN}/rm"

  cat >"${MOCK_BIN}/bash" <<'EOF'
#!/bin/bash
exec /bin/bash "$@"
EOF
  chmod +x "${MOCK_BIN}/bash"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

@test "PRD-003: reconciles the pinned Copilot package" {
  run env \
    PATH="${MOCK_BIN}:${PATH}" \
    INSTALL_LOG="${INSTALL_LOG}" \
    bash "${INSTALLER}" "vagrant" "/home/vagrant" "1.0.88"

  [ "${status}" -eq 0 ]
  run diff -u - "${INSTALL_LOG}" <<'EOF'
install
--global
--prefix
/home/vagrant/.local
@github/copilot@1.0.88
EOF
  [ "${status}" -eq 0 ]
}

@test "PRD-002: defaults the VM memory to 8 GiB" {
  run ruby -rjson -e '
    memory_mb = JSON.parse(File.read(ARGV.fetch(0))).fetch("memory_mb")
    abort "Unexpected VM memory: #{memory_mb}" unless memory_mb == 8192
  ' "${REPO_ROOT}/vm-config.json"

  [ "${status}" -eq 0 ]
}

@test "PRD-003: bootstrap provisions from Vagrant's temporary script path" {
  PROVISIONER_DIRECTORY="${TEST_DIRECTORY}/vagrant-tmp"
  PROVISIONER_SCRIPT="${PROVISIONER_DIRECTORY}/vagrant-shell"
  mkdir -p "${PROVISIONER_DIRECTORY}"
  cp "${BOOTSTRAP}" "${PROVISIONER_SCRIPT}"
  [ ! -e "${PROVISIONER_DIRECTORY}/install-copilot.sh" ]

  run env \
    "PATH=${MOCK_BIN}:${PATH}" \
    "TEST_HOME=${TEST_HOME}" \
    "INSTALL_LOG=${INSTALL_LOG}" \
    "MOCK_COPILOT_HOME=${TEST_HOME}" \
    /bin/bash "${PROVISIONER_SCRIPT}" \
    "vagrant" \
    "${REPO_ROOT}/.github/skills" \
    "${REPO_ROOT}/.github/copilot-instructions.md" \
    "${REPO_ROOT}/provision/copilot-settings.json" \
    "${REPO_ROOT}/provision/configure-copilot-settings.sh" \
    "${INSTALLER}"

  [ "${status}" -eq 0 ]
  run diff -u - "${INSTALL_LOG}" <<EOF
install
--global
--prefix
${TEST_HOME}/.local
@github/copilot@1.0.88
EOF
  [ "${status}" -eq 0 ]

  run "${TEST_HOME}/.local/bin/copilot" --version
  [ "${status}" -eq 0 ]
  [ "${output}" = "Copilot CLI 1.0.88" ]

  run jq -e '
    .model == "gpt-6-luna"
    and .effortLevel == "max"
    and .tabs.hide == ["gists"]
  ' "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]

  [ -L "${TEST_HOME}/.copilot/copilot-instructions.md" ]
  [ "$(readlink "${TEST_HOME}/.copilot/copilot-instructions.md")" = \
    "${REPO_ROOT}/.github/copilot-instructions.md" ]
  [ -L "${TEST_HOME}/.copilot/skills/rmz-create-skill" ]
  [ "$(readlink "${TEST_HOME}/.copilot/skills/rmz-create-skill")" = \
    "${REPO_ROOT}/.github/skills/rmz-create-skill/" ]
}
