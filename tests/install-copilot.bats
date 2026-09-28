#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  INSTALLER="${REPO_ROOT}/provision/install-copilot.sh"
  BOOTSTRAP="${REPO_ROOT}/provision/bootstrap.sh"
  TEST_DIRECTORY="$(mktemp -d)"
  MOCK_BIN="${TEST_DIRECTORY}/bin"
  INSTALL_LOG="${TEST_DIRECTORY}/npm-arguments"
  mkdir -p "${MOCK_BIN}"

  cat >"${MOCK_BIN}/runuser" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[ "$1" = "-u" ]
[ "$2" = "vagrant" ]
[ "$3" = "--" ]
shift 3
"$@"
EOF
  chmod +x "${MOCK_BIN}/runuser"

  cat >"${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" >"${INSTALL_LOG:?}"
EOF
  chmod +x "${MOCK_BIN}/npm"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

@test "reconciles the pinned Copilot package" {
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

@test "bootstrap delegates Copilot installation to the reconciler" {
  run grep -F \
    'bash "$(dirname "$0")/install-copilot.sh" \' \
    "${BOOTSTRAP}"

  [ "${status}" -eq 0 ]
}
