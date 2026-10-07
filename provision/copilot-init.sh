#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="$(readlink -f -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_SOURCE
REPOSITORY_ROOT="$(cd "$(dirname -- "${SCRIPT_SOURCE}")/.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly INSTRUCTIONS_SOURCE="${REPOSITORY_ROOT}/.github/copilot-instructions.md"
readonly SETTINGS_SOURCE="${REPOSITORY_ROOT}/provision/copilot-settings.json"
readonly COPILOT_HOME="${HOME:?HOME must be set}/.copilot"
readonly COPILOT_SKILLS="${COPILOT_HOME}/skills"
readonly MARKETPLACE_NAME="rmz-ai-marketplace"
readonly MARKETPLACE_SOURCE="Ramzza/rmz-ai-marketplace"

if [[ ! -f "${INSTRUCTIONS_SOURCE}" ]]; then
  printf 'Copilot instructions file not found: %s\n' "${INSTRUCTIONS_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${SETTINGS_SOURCE}" ]]; then
  printf 'Copilot settings file not found: %s\n' "${SETTINGS_SOURCE}" >&2
  exit 1
fi

if ! command -v copilot >/dev/null 2>&1; then
  printf 'copilot is required by copilot-init; run vagrant provision to install it.\n' >&2
  false
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required by copilot-init; run vagrant provision to install it.\n' >&2
  exit 1
fi

if ! jq -e '
  (if (.model | type) == "string" then (.model | length) > 0 else false end)
  and (
    .effortLevel as $effort
    | ($effort | type) == "string"
      and (["low", "medium", "high", "xhigh", "max"] | index($effort)) != null
  )
  and (.tabs.hide | type == "array" and all(.[]; type == "string"))
  and (
    .footer as $footer
    | ($footer | type) == "object"
      and all(
        [
          "showModelEffort",
          "showDirectory",
          "showBranch",
          "showContextWindow",
          "showQuota",
          "showAgent",
          "showAiUsed",
          "showCodeChanges",
          "showUsername",
          "showSandbox",
          "showYolo",
          "showCustom"
        ][];
        $footer[.] == true
      )
  )
' "${SETTINGS_SOURCE}" >/dev/null; then
  printf 'Invalid managed Copilot settings: %s\n' "${SETTINGS_SOURCE}" >&2
  exit 1
fi

readonly SETTINGS_LINK="${COPILOT_HOME}/settings.json"
if [[ -L "${SETTINGS_LINK}" ]]; then
  SETTINGS_TARGET="$(readlink -f -- "${SETTINGS_LINK}")"
  if [[ ! -f "${SETTINGS_TARGET}" ]]; then
    printf 'Copilot settings symlink does not resolve to a file: %s\n' \
      "${SETTINGS_LINK}" >&2
    exit 1
  fi
else
  SETTINGS_TARGET="${SETTINGS_LINK}"
fi
readonly SETTINGS_TARGET

if [[ -e "${SETTINGS_TARGET}" && ! -f "${SETTINGS_TARGET}" ]]; then
  printf 'Copilot settings target is not a file: %s\n' "${SETTINGS_TARGET}" >&2
  exit 1
fi

SETTINGS_DIRECTORY="$(dirname -- "${SETTINGS_TARGET}")"
readonly SETTINGS_DIRECTORY

# shellcheck disable=SC2016
readonly SETTINGS_MERGE_FILTER='
  (.tabs // {}) as $user_tabs
  | (.footer // {}) as $user_footer
  | . + ($managed[0] | del(.tabs, .footer))
  | .tabs = ($user_tabs + ($managed[0].tabs // {}))
  | .tabs.hide = (
      ($user_tabs.hide // []) as $existing
      | $existing + [
          ($managed[0].tabs.hide // [])[]
          | select(. as $tab | ($existing | index($tab)) == null)
        ]
    )
  | .footer = ($user_footer + ($managed[0].footer // {}))
'

if [[ -f "${SETTINGS_TARGET}" ]]; then
  if jq --slurpfile managed "${SETTINGS_SOURCE}" \
    "${SETTINGS_MERGE_FILTER}" "${SETTINGS_TARGET}" >/dev/null; then
    :
  else
    printf 'Invalid user Copilot settings: %s\n' "${SETTINGS_TARGET}" >&2
    false
  fi
fi

if MARKETPLACE_LIST="$(copilot plugin marketplace list)"; then
  :
else
  printf 'Could not list Copilot plugin marketplaces.\n' >&2
  false
fi

if [[ "${MARKETPLACE_LIST}" != *"${MARKETPLACE_NAME}"* ]]; then
  if copilot plugin marketplace add "${MARKETPLACE_SOURCE}"; then
    :
  else
    printf 'Could not add Copilot plugin marketplace: %s\n' \
      "${MARKETPLACE_SOURCE}" >&2
    false
  fi
fi

install -d "${COPILOT_HOME}"
install -d "${SETTINGS_DIRECTORY}"

TEMP_SETTINGS="$(mktemp "${SETTINGS_TARGET}.XXXXXX")"
readonly TEMP_SETTINGS
trap 'rm -f -- "${TEMP_SETTINGS}"' EXIT

if [[ -f "${SETTINGS_TARGET}" ]]; then
  jq --slurpfile managed "${SETTINGS_SOURCE}" \
    "${SETTINGS_MERGE_FILTER}" "${SETTINGS_TARGET}" >"${TEMP_SETTINGS}"
else
  cp "${SETTINGS_SOURCE}" "${TEMP_SETTINGS}"
fi

chmod 0600 "${TEMP_SETTINGS}"
mv -- "${TEMP_SETTINGS}" "${SETTINGS_TARGET}"
trap - EXIT

if [[ -d "${COPILOT_SKILLS}" ]]; then
  shopt -s nullglob
  for skill_target in "${COPILOT_SKILLS}"/*; do
    if [[ -L "${skill_target}" ]] &&
      [[ "$(readlink "${skill_target}")" == "${REPOSITORY_ROOT}/.github/skills/"* ]]; then
      rm -- "${skill_target}"
    fi
  done
  shopt -u nullglob
fi

readonly INSTRUCTIONS_TARGET="${COPILOT_HOME}/copilot-instructions.md"
if [[ -L "${INSTRUCTIONS_TARGET}" ]] &&
  [[ "$(readlink "${INSTRUCTIONS_TARGET}")" == "${INSTRUCTIONS_SOURCE}" ]]; then
  :
elif [[ -e "${INSTRUCTIONS_TARGET}" || -L "${INSTRUCTIONS_TARGET}" ]]; then
  printf 'Skipping Copilot instructions; target already exists: %s\n' \
    "${INSTRUCTIONS_TARGET}" >&2
else
  ln -s "${INSTRUCTIONS_SOURCE}" "${INSTRUCTIONS_TARGET}"
fi

printf 'Copilot profile initialized from %s\n' "${REPOSITORY_ROOT}"
