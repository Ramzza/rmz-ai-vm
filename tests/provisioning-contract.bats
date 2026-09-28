#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT_PATH:-${REPO_ROOT}/provision/bootstrap.sh}"
  TEST_DIRECTORY="$(mktemp -d)"
  MOCK_BIN="${TEST_DIRECTORY}/bin"
  TEST_DEV_HOME="${TEST_DIRECTORY}/home"
  TEST_DEV_USER="developer"
  TEST_NPM_LOG="${TEST_DIRECTORY}/npm.log"
  TEST_RUNUSER_LOG="${TEST_DIRECTORY}/runuser.log"
  mkdir -p "${MOCK_BIN}" "${TEST_DEV_HOME}/.copilot"
  export TEST_DEV_HOME TEST_DEV_USER TEST_NPM_LOG TEST_RUNUSER_LOG
  export PATH="${MOCK_BIN}:${PATH}"

  for command in apt-get git node code chown; do
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${MOCK_BIN}/${command}"
    chmod +x "${MOCK_BIN}/${command}"
  done

  cat >"${MOCK_BIN}/getent" <<'EOF'
#!/usr/bin/env bash
printf '%s:x:1000:1000::%s:/bin/bash\n' "${TEST_DEV_USER}" "${TEST_DEV_HOME}"
EOF

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

  cat >"${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TEST_NPM_LOG}"
mkdir -p "${TEST_DEV_HOME}/.local/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${TEST_DEV_HOME}/.local/bin/copilot"
chmod +x "${TEST_DEV_HOME}/.local/bin/copilot"
EOF

  cat >"${MOCK_BIN}/rm" <<'EOF'
#!/usr/bin/env bash
for path in "$@"; do
  case "${path}" in
    /var/lib/apt/lists/*) exit 0 ;;
  esac
done
exec /usr/bin/rm "$@"
EOF

  chmod +x \
    "${MOCK_BIN}/getent" \
    "${MOCK_BIN}/install" \
    "${MOCK_BIN}/runuser" \
    "${MOCK_BIN}/npm" \
    "${MOCK_BIN}/rm"
  printf '{"theme":"dim","tabs":{"sort":["issues"],"hide":["issues"]}}\n' \
    >"${TEST_DEV_HOME}/.copilot/settings.json"
}

teardown() {
  /usr/bin/rm -rf -- "${TEST_DIRECTORY}"
}

@test "PRD-003: provisions the selected user with pinned CLI and repository Copilot assets" {
  run bash "${BOOTSTRAP_SCRIPT}" \
    "${TEST_DEV_USER}" \
    "${REPO_ROOT}/.github/skills" \
    "${REPO_ROOT}/.github/copilot-instructions.md" \
    "${REPO_ROOT}/provision/copilot-settings.json" \
    "${REPO_ROOT}/provision/configure-copilot-settings.sh" \
    "${REPO_ROOT}/provision/install-copilot.sh"

  [ "${status}" -eq 0 ]
  [ -x "${TEST_DEV_HOME}/.local/bin/copilot" ]
  for skill_path in "${REPO_ROOT}/.github/skills"/*/; do
    [ -f "${skill_path}SKILL.md" ] || continue
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    skill_target="${TEST_DEV_HOME}/.copilot/skills/${skill_name}"
    [ -L "${skill_target}" ]
    [ "$(readlink -f "${skill_target}")" = "$(readlink -f "${skill_path}")" ]
  done
  [ -L "${TEST_DEV_HOME}/.copilot/copilot-instructions.md" ]
  [ "$(readlink "${TEST_DEV_HOME}/.copilot/copilot-instructions.md")" = \
    "${REPO_ROOT}/.github/copilot-instructions.md" ]

  run grep -E -q -- '@github/copilot@[0-9]+\.[0-9]+\.[0-9]+' "${TEST_NPM_LOG}"
  [ "${status}" -eq 0 ]
  run grep -F -q -- "-u ${TEST_DEV_USER} -- npm install" "${TEST_RUNUSER_LOG}"
  [ "${status}" -eq 0 ]
  run jq -e '
    .theme == "dim"
    and .model == "gpt-6-luna"
    and .effortLevel == "max"
    and .tabs.sort == ["issues"]
    and .tabs.hide == ["issues", "gists"]
  ' "${TEST_DEV_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
}
