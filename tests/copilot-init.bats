#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  COPILOT_INIT_SOURCE="${REPO_ROOT}/provision/copilot-init.sh"
  COPILOT_SETTINGS_SOURCE="${REPO_ROOT}/provision/copilot-settings.json"
  TEST_DIRECTORY="$(mktemp -d)"
  TEST_REPOSITORY="${TEST_DIRECTORY}/repo"
  TEST_HOME="${TEST_DIRECTORY}/home"
  TEST_INSTRUCTIONS_SOURCE="${TEST_REPOSITORY}/.github/copilot-instructions.md"
  TEST_BIN="${TEST_DIRECTORY}/bin"
  COPILOT_MARKETPLACE_STATE="${TEST_DIRECTORY}/marketplace-registered"
  COPILOT_COMMAND_LOG="${TEST_DIRECTORY}/copilot.log"
  TEST_CLAUDE_BIN="${TEST_DIRECTORY}/claude-bin"
  CLAUDE_COMMAND_LOG="${TEST_DIRECTORY}/claude.log"
  BASE_PATH=""
  IFS=':' read -r -a path_entries <<<"${PATH}"
  for path_entry in "${path_entries[@]}"; do
    if [[ -n "${path_entry}" && ! -x "${path_entry}/claude" ]]; then
      BASE_PATH="${BASE_PATH:+${BASE_PATH}:}${path_entry}"
    fi
  done
  mkdir -p \
    "${TEST_CLAUDE_BIN}" \
    "${TEST_REPOSITORY}/provision" \
    "${TEST_REPOSITORY}/.github" \
    "${TEST_REPOSITORY}/.github/skills" \
    "${TEST_HOME}" \
    "${TEST_BIN}"
  : >"${COPILOT_COMMAND_LOG}"
  : >"${CLAUDE_COMMAND_LOG}"
  if [[ -f "${COPILOT_INIT_SOURCE}" ]]; then
    cp "${COPILOT_INIT_SOURCE}" "${TEST_REPOSITORY}/provision/copilot-init.sh"
  fi
  cp "${COPILOT_SETTINGS_SOURCE}" \
    "${TEST_REPOSITORY}/provision/copilot-settings.json"
  printf '%s\n' 'Test-only Copilot instructions' >"${TEST_INSTRUCTIONS_SOURCE}"
  cat >"${TEST_BIN}/copilot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2 $3" == "plugin marketplace list" ]]; then
  if [[ "${COPILOT_LIST_STATUS:-0}" -ne 0 ]]; then
    printf '%s\n' 'Simulated marketplace list failure' >&2
    false
  fi
  if [[ -f "${COPILOT_MARKETPLACE_STATE}" ]]; then
    printf '%s\n' 'rmz-ai-marketplace'
  fi
elif [[ "$1 $2 $3" == "plugin marketplace add" ]]; then
  if [[ "${COPILOT_ADD_STATUS:-0}" -ne 0 ]]; then
    printf '%s\n' 'Simulated marketplace add failure' >&2
    false
  fi
  [[ "$4" == "Ramzza/rmz-ai-marketplace" ]]
  printf '%s\n' "$*" >>"${COPILOT_COMMAND_LOG}"
  touch "${COPILOT_MARKETPLACE_STATE}"
else
  printf 'Unexpected Copilot command: %s\n' "$*" >&2
  false
fi
EOF
  chmod +x "${TEST_BIN}/copilot"
  cat >"${TEST_CLAUDE_BIN}/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${CLAUDE_COMMAND_LOG}"
if [[ "$*" == "plugin marketplace add Ramzza/rmz-ai-marketplace" ]]; then
  if [[ "${CLAUDE_ADD_STATUS:-0}" -ne 0 ]]; then
    printf '%s\n' 'Simulated Claude marketplace add failure' >&2
    false
  fi
elif [[ "$*" == "plugin install rmz-ai-skills@rmz-ai-marketplace --scope user" ]]; then
  if [[ "${CLAUDE_INSTALL_STATUS:-0}" -ne 0 ]]; then
    printf '%s\n' 'Simulated Claude plugin install failure' >&2
    false
  fi
else
  printf 'Unexpected Claude command: %s\n' "$*" >&2
  false
fi
EOF
  chmod +x "${TEST_CLAUDE_BIN}/claude"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

run_init() {
  local init_path="${TEST_BIN}:${BASE_PATH}"
  if [[ "${CLAUDE_ON_PATH:-1}" -eq 1 ]]; then
    init_path="${TEST_BIN}:${TEST_CLAUDE_BIN}:${BASE_PATH}"
  fi
  env -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_HOME}" \
    PATH="${init_path}" \
    CLAUDE_COMMAND_LOG="${CLAUDE_COMMAND_LOG}" \
    CLAUDE_ADD_STATUS="${CLAUDE_ADD_STATUS:-0}" \
    CLAUDE_INSTALL_STATUS="${CLAUDE_INSTALL_STATUS:-0}" \
    COPILOT_MARKETPLACE_STATE="${COPILOT_MARKETPLACE_STATE}" \
    COPILOT_COMMAND_LOG="${COPILOT_COMMAND_LOG}" \
    COPILOT_LIST_STATUS="${COPILOT_LIST_STATUS:-0}" \
    COPILOT_ADD_STATUS="${COPILOT_ADD_STATUS:-0}" \
    bash "${TEST_REPOSITORY}/provision/copilot-init.sh"
}

assert_managed_settings() {
  local settings_path="$1"
  local expected_hidden_tabs="$2"

  jq -e --argjson expected_hidden_tabs "${expected_hidden_tabs}" '
    .model == "gpt-6-luna"
    and .effortLevel == "max"
    and .tabs.hide == $expected_hidden_tabs
    and (
      [
        .footer.showModelEffort,
        .footer.showDirectory,
        .footer.showBranch,
        .footer.showContextWindow,
        .footer.showQuota,
        .footer.showAgent,
        .footer.showAiUsed,
        .footer.showCodeChanges,
        .footer.showUsername,
        .footer.showSandbox,
        .footer.showYolo,
        .footer.showCustom
      ] | all(.[]; . == true)
    )
  ' "${settings_path}" >/dev/null
}

@test "PRD-004: provides a standalone copilot-init script" {
  [ -f "${COPILOT_INIT_SOURCE}" ]
}

@test "PRD-004: registers the marketplace and links instructions idempotently" {
  mkdir -p "${TEST_HOME}/.copilot"
  printf '{"theme":"dim","model":"user-model","effortLevel":"low","tabs":{"sort":["issues"],"hide":["issues"]},"footer":{"showBranch":false}}\n' \
    >"${TEST_HOME}/.copilot/settings.json"

  run run_init

  [ "${status}" -eq 0 ]
  [ -L "${TEST_HOME}/.copilot/copilot-instructions.md" ]
  run readlink -f "${TEST_HOME}/.copilot/copilot-instructions.md"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${TEST_INSTRUCTIONS_SOURCE}" ]
  [ "$(wc -l <"${COPILOT_COMMAND_LOG}")" -eq 1 ]
  grep -Fqx 'plugin marketplace add Ramzza/rmz-ai-marketplace' \
    "${COPILOT_COMMAND_LOG}"
  [ ! -e "${TEST_HOME}/.copilot/skills" ]
  run assert_managed_settings "${TEST_HOME}/.copilot/settings.json" \
    '["issues","gists"]'
  [ "${status}" -eq 0 ]
  run jq -e '.theme == "dim" and .tabs.sort == ["issues"]' \
    "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
  cp "${TEST_HOME}/.copilot/settings.json" "${TEST_DIRECTORY}/settings-after.json"

  run run_init

  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/settings-after.json" \
    "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
  [ "$(wc -l <"${COPILOT_COMMAND_LOG}")" -eq 1 ]
}

@test "PRD-004: creates managed settings when no user settings exist" {
  run run_init

  [ "${status}" -eq 0 ]
  run assert_managed_settings "${TEST_HOME}/.copilot/settings.json" '["gists"]'
  [ "${status}" -eq 0 ]
}

@test "PRD-004: reports marketplace lookup and registration failures" {
  COPILOT_LIST_STATUS=1
  run run_init
  unset COPILOT_LIST_STATUS

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Could not list Copilot plugin marketplaces"* ]]
  [[ "${output}" == *"Simulated marketplace list failure"* ]]
  [ ! -e "${TEST_HOME}/.copilot" ]

  COPILOT_ADD_STATUS=1
  run run_init
  unset COPILOT_ADD_STATUS

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Could not add Copilot plugin marketplace"* ]]
  [[ "${output}" == *"Simulated marketplace add failure"* ]]
  [ ! -e "${TEST_HOME}/.copilot" ]
}

@test "PRD-009: removes stale repository skill links and preserves user skills" {
  old_skill_target="${TEST_REPOSITORY}/.github/skills/rmz-test"
  mkdir -p "${TEST_HOME}/.copilot/skills/user-skill"
  ln -s "${old_skill_target}" "${TEST_HOME}/.copilot/skills/rmz-test"
  printf '%s\n' 'User-owned skill' \
    >"${TEST_HOME}/.copilot/skills/user-skill/SKILL.md"

  run run_init

  [ "${status}" -eq 0 ]
  [ ! -L "${TEST_HOME}/.copilot/skills/rmz-test" ]
  [ -f "${TEST_HOME}/.copilot/skills/user-skill/SKILL.md" ]
  [ "$(wc -l <"${COPILOT_COMMAND_LOG}")" -eq 1 ]
}

@test "PRD-004: preserves unrelated preferences and conflicting targets" {
  mkdir -p "${TEST_HOME}/.copilot/skills/rmz-test"
  printf '%s\n' '{"theme":"dark","model":"gpt-5.4"}' \
    >"${TEST_HOME}/.copilot/settings.json"
  printf '%s\n' 'User-owned instructions' \
    >"${TEST_HOME}/.copilot/copilot-instructions.md"
  printf '%s\n' 'User-owned skill' \
    >"${TEST_HOME}/.copilot/skills/rmz-test/SKILL.md"
  cp "${TEST_HOME}/.copilot/copilot-instructions.md" \
    "${TEST_DIRECTORY}/instructions-before.md"
  cp "${TEST_HOME}/.copilot/skills/rmz-test/SKILL.md" \
    "${TEST_DIRECTORY}/skill-before.md"

  run run_init

  [ "${status}" -eq 0 ]
  [ ! -L "${TEST_HOME}/.copilot/copilot-instructions.md" ]
  [ ! -L "${TEST_HOME}/.copilot/skills/rmz-test" ]
  run assert_managed_settings "${TEST_HOME}/.copilot/settings.json" '["gists"]'
  [ "${status}" -eq 0 ]
  run jq -e '.theme == "dark"' \
    "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/instructions-before.md" \
    "${TEST_HOME}/.copilot/copilot-instructions.md"
  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/skill-before.md" \
    "${TEST_HOME}/.copilot/skills/rmz-test/SKILL.md"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: rejects malformed user settings without changing the profile" {
  mkdir -p "${TEST_HOME}/.copilot"
  printf '{invalid json\n' >"${TEST_HOME}/.copilot/settings.json"
  cp "${TEST_HOME}/.copilot/settings.json" "${TEST_DIRECTORY}/settings-before.json"

  run run_init

  [ "${status}" -ne 0 ]
  run cmp "${TEST_DIRECTORY}/settings-before.json" \
    "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_HOME}/.copilot/skills" ]
  [ ! -e "${TEST_HOME}/.copilot/copilot-instructions.md" ]
  [ "$(wc -l <"${COPILOT_COMMAND_LOG}")" -eq 0 ]
}

@test "PRD-004: rejects missing repository Copilot assets" {
  rm -- "${TEST_INSTRUCTIONS_SOURCE}"

  run run_init

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Copilot instructions file not found"* ]]
  [ ! -e "${TEST_HOME}/.copilot/skills" ]
}

@test "PRD-009: registers the marketplace instead of copying marketplace skills" {
  run run_init

  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_HOME}/.copilot/skills" ]
  [ "$(wc -l <"${COPILOT_COMMAND_LOG}")" -eq 1 ]
  grep -Fqx 'plugin marketplace add Ramzza/rmz-ai-marketplace' \
    "${COPILOT_COMMAND_LOG}"
}

@test "PRD-010: documents the Playwright skill as a marketplace plugin" {
  grep -Fq '`playwright-explore-website`' "${REPO_ROOT}/README.md"
  grep -Fq 'copilot plugin install rmz-ai-skills@rmz-ai-marketplace' \
    "${REPO_ROOT}/README.md"

  run run_init

  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_HOME}/.copilot/skills/playwright-explore-website" ]
  grep -Fqx 'plugin marketplace add Ramzza/rmz-ai-marketplace' \
    "${COPILOT_COMMAND_LOG}"
}

@test "PRD-013: installs the RMZ skills plugin for Claude Code idempotently" {
  expected_claude_commands="$(printf '%s\n' \
    'plugin marketplace add Ramzza/rmz-ai-marketplace' \
    'plugin install rmz-ai-skills@rmz-ai-marketplace --scope user')"

  run run_init

  [ "${status}" -eq 0 ]
  [ "$(cat "${CLAUDE_COMMAND_LOG}")" = "${expected_claude_commands}" ]
  [ ! -e "${TEST_HOME}/.claude" ]

  : >"${CLAUDE_COMMAND_LOG}"
  run run_init

  [ "${status}" -eq 0 ]
  [ "$(cat "${CLAUDE_COMMAND_LOG}")" = "${expected_claude_commands}" ]
}

@test "PRD-013: skips Claude Code setup when Claude Code is not installed" {
  CLAUDE_ON_PATH=0
  run run_init
  unset CLAUDE_ON_PATH

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Claude Code not found; skipping RMZ skills for Claude Code"* ]]
  [ ! -s "${CLAUDE_COMMAND_LOG}" ]
  [ -L "${TEST_HOME}/.copilot/copilot-instructions.md" ]
}

@test "PRD-013: warns about Claude Code failures without blocking Copilot setup" {
  CLAUDE_ADD_STATUS=1
  run run_init
  unset CLAUDE_ADD_STATUS

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Warning: could not add Claude Code plugin marketplace: Ramzza/rmz-ai-marketplace"* ]]
  [[ "${output}" == *"Simulated Claude marketplace add failure"* ]]
  [ -L "${TEST_HOME}/.copilot/copilot-instructions.md" ]
  run grep -Fq 'plugin install' "${CLAUDE_COMMAND_LOG}"
  [ "${status}" -ne 0 ]

  : >"${CLAUDE_COMMAND_LOG}"
  CLAUDE_INSTALL_STATUS=1
  run run_init
  unset CLAUDE_INSTALL_STATUS

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Warning: could not install Claude Code plugin: rmz-ai-skills@rmz-ai-marketplace"* ]]
  [[ "${output}" == *"Simulated Claude plugin install failure"* ]]
}

@test "PRD-013: documents RMZ skills for Claude Code" {
  grep -Fq 'claude plugin install rmz-ai-skills@rmz-ai-marketplace' \
    "${REPO_ROOT}/README.md"
}
