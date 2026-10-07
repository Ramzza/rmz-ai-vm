#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT_PATH:-${REPO_ROOT}/provision/bootstrap.sh}"
  TEST_DIRECTORY="$(mktemp -d)"
  MOCK_BIN="${TEST_DIRECTORY}/bin"
  TEST_DEV_HOME="${TEST_DIRECTORY}/home"
  TEST_DEV_USER="developer"
  TEST_REAL_RM="$(command -v rm)"
  TEST_REAL_CHMOD="$(command -v chmod)"
  TEST_INSTALL_PREFIX="${TEST_DIRECTORY}/usr-local"
  TEST_CURL_LOG="${TEST_DIRECTORY}/curl.log"
  TEST_VERSION_LOG="${TEST_DIRECTORY}/installer-version"
  TEST_NPM_LOG="${TEST_DIRECTORY}/npm.log"
  TEST_NODE_SOURCE_LOG="${TEST_DIRECTORY}/nodesource-setup.log"
  TEST_RUNUSER_LOG="${TEST_DIRECTORY}/runuser.log"
  TEST_APT_LOG="${TEST_DIRECTORY}/apt-get.log"
  TEST_INSTALL_LOG="${TEST_DIRECTORY}/install.log"
  TEST_CHMOD_LOG="${TEST_DIRECTORY}/chmod.log"
  TEST_TEE_LOG="${TEST_DIRECTORY}/tee.log"
  TEST_SEQUENCE_LOG="${TEST_DIRECTORY}/sequence.log"
  TEST_COPILOT_INIT_SOURCE="${TEST_DIRECTORY}/copilot-init.sh"
  TEST_INIT_LOG="${TEST_DIRECTORY}/copilot-init.log"
  mkdir -p "${MOCK_BIN}" "${TEST_DEV_HOME}"
  export TEST_DEV_HOME TEST_DEV_USER TEST_REAL_RM TEST_INSTALL_PREFIX \
    TEST_CURL_LOG TEST_VERSION_LOG TEST_NPM_LOG TEST_NODE_SOURCE_LOG \
    TEST_RUNUSER_LOG TEST_APT_LOG TEST_INSTALL_LOG TEST_CHMOD_LOG \
    TEST_TEE_LOG TEST_SEQUENCE_LOG TEST_REAL_CHMOD TEST_INIT_LOG
  : >"${TEST_TEE_LOG}"
  : >"${TEST_SEQUENCE_LOG}"
  : >"${TEST_INSTALL_LOG}"
  : >"${TEST_CHMOD_LOG}"
  export PATH="${MOCK_BIN}:${TEST_INSTALL_PREFIX}/bin:${PATH}"

  for command in git node code chown direnv; do
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${MOCK_BIN}/${command}"
    chmod +x "${MOCK_BIN}/${command}"
  done

  cat >"${MOCK_BIN}/apt-get" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TEST_APT_LOG:?}"
printf 'apt-get %s\n' "$*" >>"${TEST_SEQUENCE_LOG:?}"
EOF

  cat >"${MOCK_BIN}/install" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
  printf '%s\n' "$*" >>"${TEST_INSTALL_LOG:?}"
  while [ "$#" -gt 0 ]; do
  case "$1" in
    -d) shift ;;
    -g|-m|-o) shift 2 ;;
    *)
      if [[ "$1" != /etc/* ]]; then
        mkdir -p -- "$1"
      fi
      shift
      ;;
  esac
done
EOF

  cat >"${MOCK_BIN}/chmod" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *"/etc/apt/keyrings/"*)
    printf '%s\n' "$*" >>"${TEST_CHMOD_LOG:?}"
    ;;
  *) exec "${TEST_REAL_CHMOD:?}" "$@" ;;
esac
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
printf '%s\n' "$@" >>"${TEST_CURL_LOG:?}"
case "$*" in
  *https://cli.github.com/packages/githubcli-archive-keyring.gpg)
    printf '%s\n' 'GitHub CLI test signing key'
    ;;
  *https://deb.nodesource.com/setup_22.x)
    cat <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'NodeSource setup ran' >"${TEST_NODE_SOURCE_LOG:?}"
INSTALLER
    ;;
  *https://gh.io/copilot-install)
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
    ;;
  *)
    printf 'Unexpected curl invocation: %s\n' "$*" >&2
    false
    ;;
esac
EOF

  cat >"${MOCK_BIN}/tee" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
destination="${1:?}"
content="$(cat)"
printf '%s\n%s\n' "${destination}" "${content}" >>"${TEST_TEE_LOG:?}"
printf 'tee %s\n' "${destination}" >>"${TEST_SEQUENCE_LOG:?}"
EOF

  cat >"${MOCK_BIN}/dpkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -ne 1 || "$1" != "--print-architecture" ]]; then
  printf 'Unexpected dpkg invocation: %s\n' "$*" >&2
  exit 1
fi
printf '%s\n' amd64
EOF

  cat >"${TEST_COPILOT_INIT_SOURCE}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: >"${TEST_INIT_LOG:?}"
EOF
  chmod +x "${TEST_COPILOT_INIT_SOURCE}"

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
    "${MOCK_BIN}/apt-get" \
    "${MOCK_BIN}/chmod" \
    "${MOCK_BIN}/runuser" \
    "${MOCK_BIN}/curl" \
    "${MOCK_BIN}/tee" \
    "${MOCK_BIN}/dpkg" \
    "${MOCK_BIN}/npm" \
    "${MOCK_BIN}/rm"
}

teardown() {
  "${TEST_REAL_RM}" -rf -- "${TEST_DIRECTORY}"
}

run_bootstrap() {
  env -u PREFIX -u VERSION bash "${BOOTSTRAP_SCRIPT}" \
    "${TEST_DEV_USER}" \
    "${TEST_COPILOT_INIT_SOURCE}"
}

@test "PRD-003: installs Copilot officially and configures npm for shared folders" {
  run run_bootstrap

  [ "${status}" -eq 0 ]
  [ -x "${TEST_INSTALL_PREFIX}/bin/copilot" ]
  [ -f "${TEST_NODE_SOURCE_LOG}" ]
  [ "$(cat "${TEST_NODE_SOURCE_LOG}")" = "NodeSource setup ran" ]
  run copilot --version
  [ "${status}" -eq 0 ]
  [ "${output}" = "GitHub Copilot CLI test binary" ]
  run diff -u - "${TEST_NPM_LOG}" <<'EOF'
config set bin-links false --location=user
EOF
  [ "${status}" -eq 0 ]
  run diff -u - "${TEST_RUNUSER_LOG}" <<EOF
-u ${TEST_DEV_USER} -- env HOME=${TEST_DEV_HOME} npm config set bin-links false --location=user
EOF
  [ "${status}" -eq 0 ]
  run grep -E -q '(^|[[:space:]])nodejs([[:space:]]|$)' "${TEST_APT_LOG}"
  [ "${status}" -eq 0 ]
  run grep -E -q '(^|[[:space:]])npm([[:space:]]|$)' "${TEST_APT_LOG}"
  [ "${status}" -ne 0 ]
  run diff -u - "${TEST_CURL_LOG}" <<'EOF'
-fsSL
https://cli.github.com/packages/githubcli-archive-keyring.gpg
-fsSL
https://deb.nodesource.com/setup_22.x
-fsSL
https://gh.io/copilot-install
EOF
  [ "${status}" -eq 0 ]
  run diff -u - "${TEST_VERSION_LOG}" <<'EOF'
unset
unset
EOF
  [ "${status}" -eq 0 ]
}

@test "PRD-007: installs latest gh from GitHub's official stable repository" {
  run run_bootstrap

  [ "${status}" -eq 0 ]
  run grep -F -xq -- \
    'https://cli.github.com/packages/githubcli-archive-keyring.gpg' \
    "${TEST_CURL_LOG}"
  [ "${status}" -eq 0 ]
  run diff -u - "${TEST_INSTALL_LOG}" <<'EOF'
-d -m 0755 /etc/apt/keyrings
EOF
  [ "${status}" -eq 0 ]
  run diff -u - "${TEST_CHMOD_LOG}" <<'EOF'
go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
EOF
  [ "${status}" -eq 0 ]
  run diff -u - "${TEST_TEE_LOG}" <<'EOF'
/etc/apt/keyrings/githubcli-archive-keyring.gpg
GitHub CLI test signing key
/etc/apt/sources.list.d/github-cli.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main
EOF
  [ "${status}" -eq 0 ]
  run grep -Fxq 'install --yes --no-install-recommends gh' "${TEST_APT_LOG}"
  [ "${status}" -eq 0 ]
  run grep -E -q '(^|[[:space:]])gh=[^[:space:]]' "${TEST_APT_LOG}"
  [ "${status}" -ne 0 ]

  repository_line="$(grep -nFx \
    'tee /etc/apt/sources.list.d/github-cli.list' "${TEST_SEQUENCE_LOG}" |
    cut -d: -f1)"
  repository_update_line="$(awk -v repository_line="${repository_line}" \
    'NR > repository_line && $0 == "apt-get update" { print NR; exit }' \
    "${TEST_SEQUENCE_LOG}")"
  gh_install_line="$(grep -nFx \
    'apt-get install --yes --no-install-recommends gh' "${TEST_SEQUENCE_LOG}" |
    cut -d: -f1)"
  [ -n "${repository_line}" ]
  [ -n "${repository_update_line}" ]
  [ -n "${gh_install_line}" ]
  [ "${repository_line}" -lt "${repository_update_line}" ]
  [ "${repository_update_line}" -lt "${gh_install_line}" ]
}

@test "PRD-009: installs pdftk for the marketplace PDFtk skill" {
  run run_bootstrap

  [ "${status}" -eq 0 ]
  run grep -E -q \
    '^install --yes --no-install-recommends .*([[:space:]])pdftk([[:space:]]|$)' \
    "${TEST_APT_LOG}"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: exposes a manual copilot-init command" {
  run run_bootstrap

  [ "${status}" -eq 0 ]
  run grep -E -q '(^|[[:space:]])jq([[:space:]]|$)' "${TEST_APT_LOG}"
  [ "${status}" -eq 0 ]
  [ -f "${TEST_INSTALL_PREFIX}/bin/copilot-init" ]
  [ -x "${TEST_INSTALL_PREFIX}/bin/copilot-init" ]
  run grep -F -q -- "${TEST_COPILOT_INIT_SOURCE}" \
    "${TEST_INSTALL_PREFIX}/bin/copilot-init"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_INIT_LOG}" ]
  [ ! -e "${TEST_DEV_HOME}/.copilot" ]
  [ ! -e "${TEST_DEV_HOME}/.copilot/copilot-instructions.md" ]
  [ ! -e "${TEST_DEV_HOME}/.copilot/skills" ]

  run run_bootstrap

  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_INIT_LOG}" ]

  run "${TEST_INSTALL_PREFIX}/bin/copilot-init"

  [ "${status}" -eq 0 ]
  [ -e "${TEST_INIT_LOG}" ]
}

@test "PRD-004: provisioning leaves the user's Copilot profile untouched" {
  mkdir -p "${TEST_DEV_HOME}/.copilot"
  printf '{"theme":"dim","tabs":{"sort":["issues"],"hide":["issues"]}}\n' \
    >"${TEST_DEV_HOME}/.copilot/settings.json"
  cp "${TEST_DEV_HOME}/.copilot/settings.json" "${TEST_DIRECTORY}/settings-before.json"

  run run_bootstrap

  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/settings-before.json" \
    "${TEST_DEV_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_DEV_HOME}/.copilot/copilot-instructions.md" ]
  [ ! -e "${TEST_DEV_HOME}/.copilot/skills" ]
  [ ! -e "${TEST_INIT_LOG}" ]
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

@test "PRD-004: reports a missing manual initialization script" {
  run env -u PREFIX -u VERSION bash "${BOOTSTRAP_SCRIPT}" \
    "${TEST_DEV_USER}" \
    "${TEST_DIRECTORY}/missing-copilot-init.sh"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Copilot init script not found"* ]]
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

@test "PRD-008: provisions an Autopilot and YOLO alias with a 30 AI-credit session limit" {
  run run_bootstrap
  [ "${status}" -eq 0 ]

  TEST_ALIAS_BIN="${TEST_DIRECTORY}/alias-bin"
  TEST_WORKSPACE="${TEST_DIRECTORY}/workspace"
  TEST_COPILOT_ARGS_LOG="${TEST_DIRECTORY}/copilot-args.log"
  mkdir -p "${TEST_ALIAS_BIN}" "${TEST_WORKSPACE}"
  export TEST_WORKSPACE TEST_COPILOT_ARGS_LOG

  cat >"${TEST_ALIAS_BIN}/copilot" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${TEST_COPILOT_ARGS_LOG:?}"
EOF
  chmod +x "${TEST_ALIAS_BIN}/copilot"

  run env HOME="${TEST_DEV_HOME}" PATH="${TEST_ALIAS_BIN}:${PATH}" \
    bash --noprofile --norc -c '
      shopt -s expand_aliases
      cd() {
        if [[ "$#" -eq 1 && "$1" == "/workspace" ]]; then
          builtin cd -- "${TEST_WORKSPACE}"
        else
          builtin cd -- "$@"
        fi
      }
      source "$HOME/.bashrc.d-copilot"
      eval "rmz-autopilot"
    '
  [ "${status}" -eq 0 ]
  run diff -u - "${TEST_COPILOT_ARGS_LOG}" <<'EOF'
--autopilot
--max-ai-credits
30
--yolo
EOF
  [ "${status}" -eq 0 ]
}
