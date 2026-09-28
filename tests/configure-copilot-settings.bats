#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  SETTINGS_SOURCE="${REPO_ROOT}/provision/copilot-settings.json"
  SETTINGS_MERGER="${REPO_ROOT}/provision/configure-copilot-settings.sh"
  TEST_DIRECTORY="$(mktemp -d)"
  SETTINGS_TARGET="${TEST_DIRECTORY}/.copilot/settings.json"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

@test "creates settings from the managed defaults" {
  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"

  [ "${status}" -eq 0 ]
  run jq -e '.tabs.hide == ["gists"]' "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "merges managed settings and preserves user preferences" {
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
    and .tabs.sort == ["issues", "gists"]
    and .tabs.hide == ["issues", "gists"]
  ' "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "does not change settings when run repeatedly" {
  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
  cp "${SETTINGS_TARGET}" "${TEST_DIRECTORY}/before.json"

  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"

  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/before.json" "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "preserves malformed user settings when merging fails" {
  mkdir -p "$(dirname "${SETTINGS_TARGET}")"
  printf '{invalid json\n' >"${SETTINGS_TARGET}"

  run bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"

  [ "${status}" -ne 0 ]
  run grep -qxF '{invalid json' "${SETTINGS_TARGET}"
  [ "${status}" -eq 0 ]
}

@test "fails when the managed settings file is missing" {
  run bash "${SETTINGS_MERGER}" "${TEST_DIRECTORY}/missing.json" "${SETTINGS_TARGET}"

  [ "${status}" -ne 0 ]
}

@test "preserves existing settings when managed settings are malformed" {
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
