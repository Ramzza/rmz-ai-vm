#!/usr/bin/env bash
set -euo pipefail

readonly SETTINGS_SOURCE="${1:?Copilot settings source path is required}"
readonly SETTINGS_TARGET="${2:?Copilot settings target path is required}"

if [[ ! -f "${SETTINGS_SOURCE}" ]]; then
  printf 'Copilot settings file not found: %s\n' "${SETTINGS_SOURCE}" >&2
  exit 1
fi

jq -e '
  (.tabs.hide | type == "array" and all(.[]; type == "string"))
  and (if (.model | type) == "string" then (.model | length) > 0 else false end)
  and (
    .effortLevel as $effort
    | ($effort | type) == "string"
      and (["low", "medium", "high", "xhigh", "max"] | index($effort)) != null
  )
' \
  "${SETTINGS_SOURCE}" >/dev/null

SETTINGS_DIRECTORY="$(dirname "${SETTINGS_TARGET}")"
readonly SETTINGS_DIRECTORY
mkdir -p "${SETTINGS_DIRECTORY}"

TEMP_FILE="$(mktemp "${SETTINGS_TARGET}.XXXXXX")"
readonly TEMP_FILE
trap 'rm -f "${TEMP_FILE}"' EXIT

if [[ -f "${SETTINGS_TARGET}" ]]; then
  jq --slurpfile managed "${SETTINGS_SOURCE}" '
    (.tabs // {}) as $user_tabs
    | . + ($managed[0] | del(.tabs))
    | .tabs = ($user_tabs + ($managed[0].tabs // {}))
    | .tabs.hide = (
        ($user_tabs.hide // []) as $existing
        | $existing + [
            ($managed[0].tabs.hide // [])[]
            | select(. as $tab | ($existing | index($tab)) == null)
          ]
      )
  ' "${SETTINGS_TARGET}" >"${TEMP_FILE}"
else
  cp "${SETTINGS_SOURCE}" "${TEMP_FILE}"
fi

chmod 0600 "${TEMP_FILE}"
mv "${TEMP_FILE}" "${SETTINGS_TARGET}"
trap - EXIT
