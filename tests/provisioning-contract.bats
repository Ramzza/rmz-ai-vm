#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT_PATH:-${REPO_ROOT}/provision/bootstrap.sh}"
  TEST_DIRECTORY="$(mktemp -d)"
  MOCK_BIN="${TEST_DIRECTORY}/bin"
  TEST_DEV_HOME="${TEST_DIRECTORY}/home"
  TEST_DEV_USER="developer"
  TEST_REAL_RM="$(command -v rm)"
  TEST_INSTALL_PREFIX="${TEST_DIRECTORY}/usr-local"
  TEST_CURL_LOG="${TEST_DIRECTORY}/curl.log"
  TEST_VERSION_LOG="${TEST_DIRECTORY}/installer-version"
  TEST_NPM_LOG="${TEST_DIRECTORY}/npm.log"
  TEST_RUNUSER_LOG="${TEST_DIRECTORY}/runuser.log"
  mkdir -p "${MOCK_BIN}" "${TEST_DEV_HOME}"
  export TEST_DEV_HOME TEST_DEV_USER TEST_REAL_RM TEST_INSTALL_PREFIX \
    TEST_CURL_LOG TEST_VERSION_LOG TEST_NPM_LOG TEST_RUNUSER_LOG
  export PATH="${MOCK_BIN}:${TEST_INSTALL_PREFIX}/bin:${PATH}"

  for command in apt-get git node code chown direnv; do
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${MOCK_BIN}/${command}"
    chmod +x "${MOCK_BIN}/${command}"
  done

  cat >"${MOCK_BIN}/install" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
while [ "$#" -gt 0 ]; do
  case "$1" in
    -d) shift ;;
    -g|-m|-o) shift 2 ;;
    *) mkdir -p -- "$1"; shift ;;
  esac
done
EOF

  cat >"${MOCK_BIN}/getent" <<'EOF'
#!/usr/bin/env bash
printf '%s:x:1000:1000::%s:/bin/bash\n' "${TEST_DEV_USER}" "${TEST_DEV_HOME}"
EOF

  cat >"${MOCK_BIN}/runuser" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TEST_RUNUSER_LOG}"
if [ "$1" = "-u" ]; then
  shift 2
fi
if [ "$1" = "--" ]; then
  shift
fi
exec "$@"
EOF

  cat >"${MOCK_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"${TEST_CURL_LOG:?}"
cat <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${VERSION-unset}" "${PREFIX-unset}" >"${TEST_VERSION_LOG:?}"
mkdir -p "${TEST_INSTALL_PREFIX:?}/bin"
cat >"${TEST_INSTALL_PREFIX}/bin/copilot" <<'CLI'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'GitHub Copilot CLI test binary'
CLI
chmod +x "${TEST_INSTALL_PREFIX}/bin/copilot"
INSTALLER
EOF

  TEST_SKILLS_SOURCE="${TEST_DIRECTORY}/skills"
  TEST_INSTRUCTIONS_SOURCE="${TEST_DIRECTORY}/copilot-instructions.md"
  mkdir -p "${TEST_SKILLS_SOURCE}/rmz-test" "${TEST_SKILLS_SOURCE}/notes"
  printf '%s\n' 'name: rmz-test' >"${TEST_SKILLS_SOURCE}/rmz-test/SKILL.md"
  printf '%s\n' 'Test-only Copilot instructions' >"${TEST_INSTRUCTIONS_SOURCE}"

  cat >"${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TEST_NPM_LOG}"
EOF

  cat >"${MOCK_BIN}/rm" <<'EOF'
#!/usr/bin/env bash
for path in "$@"; do
  case "${path}" in
    /var/lib/apt/lists/*) exit 0 ;;
  esac
done
exec "${TEST_REAL_RM}" "$@"
EOF

  chmod +x \
    "${MOCK_BIN}/getent" \
    "${MOCK_BIN}/install" \
    "${MOCK_BIN}/runuser" \
    "${MOCK_BIN}/curl" \
    "${MOCK_BIN}/npm" \
    "${MOCK_BIN}/rm"
}

teardown() {
  "${TEST_REAL_RM}" -rf -- "${TEST_DIRECTORY}"
}

run_bootstrap() {
  env -u PREFIX -u VERSION bash "${BOOTSTRAP_SCRIPT}" \
    "${TEST_DEV_USER}" \
    "${TEST_SKILLS_SOURCE}" \
    "${TEST_INSTRUCTIONS_SOURCE}"
}

@test "PRD-003: installs Copilot from GitHub's official Linux installer without npm" {
  run run_bootstrap

  [ "${status}" -eq 0 ]
  [ -x "${TEST_INSTALL_PREFIX}/bin/copilot" ]
  run copilot --version
  [ "${status}" -eq 0 ]
  [ "${output}" = "GitHub Copilot CLI test binary" ]
  [ ! -e "${TEST_NPM_LOG}" ]
  [ ! -e "${TEST_RUNUSER_LOG}" ]
  run diff -u - "${TEST_CURL_LOG}" <<'EOF'
-fsSL
https://gh.io/copilot-install
EOF
  [ "${status}" -eq 0 ]
  run diff -u - "${TEST_VERSION_LOG}" <<'EOF'
unset
unset
EOF
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_DEV_HOME}/.copilot/settings.json" ]
  run grep -E -q 'npm|nodejs|NodeSource' "${BOOTSTRAP_SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "PRD-004: imports repository instructions and skills without changing settings" {
  mkdir -p "${TEST_DEV_HOME}/.copilot"
  printf '{"theme":"dim","tabs":{"sort":["issues"],"hide":["issues"]}}\n' \
    >"${TEST_DEV_HOME}/.copilot/settings.json"
  cp "${TEST_DEV_HOME}/.copilot/settings.json" "${TEST_DIRECTORY}/settings-before.json"

  run run_bootstrap

  [ "${status}" -eq 0 ]
  [ -L "${TEST_DEV_HOME}/.copilot/copilot-instructions.md" ]
  run readlink -f "${TEST_DEV_HOME}/.copilot/copilot-instructions.md"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${TEST_INSTRUCTIONS_SOURCE}" ]
  [ -L "${TEST_DEV_HOME}/.copilot/skills/rmz-test" ]
  run readlink -f "${TEST_DEV_HOME}/.copilot/skills/rmz-test"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${TEST_SKILLS_SOURCE}/rmz-test" ]
  [ -f "${TEST_DEV_HOME}/.copilot/skills/rmz-test/SKILL.md" ]
  run cmp "${TEST_DIRECTORY}/settings-before.json" \
    "${TEST_DEV_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]

  run run_bootstrap

  [ "${status}" -eq 0 ]
  [ -L "${TEST_DEV_HOME}/.copilot/copilot-instructions.md" ]
  [ -L "${TEST_DEV_HOME}/.copilot/skills/rmz-test" ]
  run cmp "${TEST_DIRECTORY}/settings-before.json" \
    "${TEST_DEV_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: preserves user-owned instruction and skill targets" {
  mkdir -p "${TEST_DEV_HOME}/.copilot/skills/rmz-test"
  printf '%s\n' 'User instructions' \
    >"${TEST_DEV_HOME}/.copilot/copilot-instructions.md"
  printf '%s\n' 'User-owned skill' \
    >"${TEST_DEV_HOME}/.copilot/skills/rmz-test/SKILL.md"
  cp "${TEST_DEV_HOME}/.copilot/copilot-instructions.md" \
    "${TEST_DIRECTORY}/user-instructions-before.md"
  cp "${TEST_DEV_HOME}/.copilot/skills/rmz-test/SKILL.md" \
    "${TEST_DIRECTORY}/user-skill-before.md"

  run run_bootstrap

  [ "${status}" -eq 0 ]
  [ ! -L "${TEST_DEV_HOME}/.copilot/copilot-instructions.md" ]
  [ ! -L "${TEST_DEV_HOME}/.copilot/skills/rmz-test" ]
  run cmp "${TEST_DIRECTORY}/user-instructions-before.md" \
    "${TEST_DEV_HOME}/.copilot/copilot-instructions.md"
  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/user-skill-before.md" \
    "${TEST_DEV_HOME}/.copilot/skills/rmz-test/SKILL.md"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: reports missing repository asset sources" {
  run env -u PREFIX -u VERSION bash "${BOOTSTRAP_SCRIPT}" \
    "${TEST_DEV_USER}" \
    "${TEST_DIRECTORY}/missing-skills" \
    "${TEST_INSTRUCTIONS_SOURCE}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Copilot skills directory not found"* ]]
  [ ! -e "${TEST_DEV_HOME}/.copilot" ]

  run env -u PREFIX -u VERSION bash "${BOOTSTRAP_SCRIPT}" \
    "${TEST_DEV_USER}" \
    "${TEST_SKILLS_SOURCE}" \
    "${TEST_DIRECTORY}/missing-instructions"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Copilot instructions file not found"* ]]
  [ ! -e "${TEST_DEV_HOME}/.copilot" ]
}

@test "PRD-006: starts Bash sessions in the mounted workspace" {
  run run_bootstrap
  [ "${status}" -eq 0 ]

  TEST_WORKSPACE="${TEST_DIRECTORY}/workspace"
  mkdir -p "${TEST_WORKSPACE}"
  export TEST_WORKSPACE

  run env HOME="${TEST_DEV_HOME}" bash -c '
    cd() {
      if [[ "$#" -eq 1 && "$1" == "/workspace" ]]; then
        builtin cd -- "${TEST_WORKSPACE}"
      else
        builtin cd -- "$@"
      fi
    }
    source "$HOME/.bashrc"
    pwd
  '
  [ "${status}" -eq 0 ]
  [ "${output}" = "${TEST_WORKSPACE}" ]
}
