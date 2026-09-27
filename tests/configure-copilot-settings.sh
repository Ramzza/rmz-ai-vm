#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SETTINGS_SOURCE="${REPO_ROOT}/provision/copilot-settings.json"
readonly SETTINGS_MERGER="${REPO_ROOT}/provision/configure-copilot-settings.sh"
TEST_DIRECTORY="$(mktemp -d)"
readonly TEST_DIRECTORY

cleanup() {
  rm -f "${TEST_DIRECTORY}/.copilot/settings.json" \
    "${TEST_DIRECTORY}/before.json" \
    "${TEST_DIRECTORY}/invalid-settings.json"
  if [[ -d "${TEST_DIRECTORY}/.copilot" ]]; then
    rmdir "${TEST_DIRECTORY}/.copilot"
  fi
  rmdir "${TEST_DIRECTORY}"
}

trap cleanup EXIT

readonly SETTINGS_TARGET="${TEST_DIRECTORY}/.copilot/settings.json"
bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"
jq -e '.tabs.hide == ["gists"]' "${SETTINGS_TARGET}" >/dev/null

cat >"${SETTINGS_TARGET}" <<'EOF'
{
  "theme": "dim",
  "tabs": {
    "sort": ["issues", "gists"],
    "hide": ["issues"]
  }
}
EOF

bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"
jq -e '
  .theme == "dim"
  and .tabs.sort == ["issues", "gists"]
  and .tabs.hide == ["issues", "gists"]
' "${SETTINGS_TARGET}" >/dev/null

cp "${SETTINGS_TARGET}" "${TEST_DIRECTORY}/before.json"
bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"
cmp "${TEST_DIRECTORY}/before.json" "${SETTINGS_TARGET}"

printf '{invalid json\n' >"${SETTINGS_TARGET}"
if bash "${SETTINGS_MERGER}" "${SETTINGS_SOURCE}" "${SETTINGS_TARGET}"; then
  printf 'Expected malformed user settings to fail\n' >&2
  exit 1
fi
grep -qxF '{invalid json' "${SETTINGS_TARGET}"

if bash "${SETTINGS_MERGER}" "${TEST_DIRECTORY}/missing.json" "${SETTINGS_TARGET}" 2>/dev/null; then
  printf 'Expected a missing managed settings file to fail\n' >&2
  exit 1
fi

printf '{invalid json\n' >"${TEST_DIRECTORY}/invalid-settings.json"
if bash "${SETTINGS_MERGER}" "${TEST_DIRECTORY}/invalid-settings.json" "${SETTINGS_TARGET}" 2>/dev/null; then
  printf 'Expected malformed managed settings to fail\n' >&2
  exit 1
fi
grep -qxF '{invalid json' "${SETTINGS_TARGET}"
