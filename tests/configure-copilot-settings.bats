#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  SETTINGS_SOURCE="${REPO_ROOT}/provision/copilot-settings.json"
  SETTINGS_MERGER="${SETTINGS_MERGER_PATH:-${REPO_ROOT}/provision/configure-copilot-settings.sh}"
  TEST_DIRECTORY="$(mktemp -d)"
  SETTINGS_TARGET="${TEST_DIRECTORY}/.copilot/settings.json"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

@test "PRD-004: creates settings from the managed defaults" {
  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"

  [ "${status}" -eq 0 ]
  run jq -e '
    .model == "gpt-6-luna"
    and .effortLevel == "max"
    and .tabs.hide == ["gists"]
  ' "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: merges managed settings and preserves user preferences" {
  mkdir -p "$(dirname "${SETTINGS_TARGET}")"
  cat >"${SETTINGS_TARGET}" <<'EOF'
{
  "theme": "dim",
  "tabs": {
    "sort": ["issues", "gists"],
    "hide": ["issues"]
  }
}
EOF

  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"

  [ "${status}" -eq 0 ]
  run jq -e '
    .theme == "dim"
    and .model == "gpt-6-luna"
    and .effortLevel == "max"
    and .tabs.sort == ["issues", "gists"]
    and .tabs.hide == ["issues", "gists"]
  ' "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: does not change settings when run repeatedly" {
  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
  cp "${SETTINGS_TARGET}" "${TEST_DIRECTORY}/before.json"

  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"

  [ "${status}" -eq 0 ]
  run jq -S . "${TEST_DIRECTORY}/before.json"
  [ "${status}" -eq 0 ]
  before_settings="${output}"
  run jq -S . "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${before_settings}" ]
}

@test "PRD-004: preserves malformed user settings when merging fails" {
  mkdir -p "$(dirname "${SETTINGS_TARGET}")"
  printf '{invalid json\n' >"${SETTINGS_TARGET}"

  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"

  [ "${status}" -ne 0 ]
  run grep -qxF '{invalid json' "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: preserves settings when the managed settings file is missing" {
  mkdir -p "$(dirname "${SETTINGS_TARGET}")"
  printf '{"theme":"dim"}\n' >"${SETTINGS_TARGET}"
  cp "${SETTINGS_TARGET}" "${TEST_DIRECTORY}/before.json"

  run bash "${SETTINGS_MERGER}" "${TEST_DIRECTORY}/missing.json" "${SETTINGS_TARGET}"

  [ "${status}" -ne 0 ]
  run cmp "${TEST_DIRECTORY}/before.json" "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: rejects an invalid managed model without changing existing settings" {
  bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"
  cp "${SETTINGS_TARGET}" "${TEST_DIRECTORY}/before.json"
  jq '.model = null' "${SETTINGS_SOURCE}" >"${TEST_DIRECTORY}/invalid-settings.json"

  run bash "${SETTINGS_MERGER}" \
    "${TEST_DIRECTORY}/invalid-settings.json" \
    "${SETTINGS_TARGET}"

  [ "${status}" -ne 0 ]
  run cmp "${TEST_DIRECTORY}/before.json" "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: rejects an unsupported managed effort without changing existing settings" {
  bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"
  cp "${SETTINGS_TARGET}" "${TEST_DIRECTORY}/before.json"
  jq '.effortLevel = "unsupported"' "${SETTINGS_SOURCE}" >"${TEST_DIRECTORY}/invalid-settings.json"

  run bash "${SETTINGS_MERGER}" \
    "${TEST_DIRECTORY}/invalid-settings.json" \
    "${SETTINGS_TARGET}"

  [ "${status}" -ne 0 ]
  run cmp "${TEST_DIRECTORY}/before.json" "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: preserves existing settings when managed settings are malformed" {
  printf '{invalid json\n' >"${TEST_DIRECTORY}/invalid-settings.json"
  mkdir -p "$(dirname "${SETTINGS_TARGET}")"
  printf '{"theme":"dim"}\n' >"${SETTINGS_TARGET}"
  cp "${SETTINGS_TARGET}" "${TEST_DIRECTORY}/before.json"

  run bash "${SETTINGS_MERGER}" \
    "${TEST_DIRECTORY}/invalid-settings.json" \
    "${SETTINGS_TARGET}"

  [ "${status}" -ne 0 ]
  run cmp "${TEST_DIRECTORY}/before.json" "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}
