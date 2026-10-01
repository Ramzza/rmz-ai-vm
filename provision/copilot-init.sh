#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="$(readlink -f -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_SOURCE
REPOSITORY_ROOT="$(cd "$(dirname -- "${SCRIPT_SOURCE}")/.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly SKILLS_SOURCE="${REPOSITORY_ROOT}/.github/skills"
readonly INSTRUCTIONS_SOURCE="${REPOSITORY_ROOT}/.github/copilot-instructions.md"
readonly COPILOT_HOME="${HOME:?HOME must be set}/.copilot"
readonly COPILOT_SKILLS="${COPILOT_HOME}/skills"

if [[ ! -d "${SKILLS_SOURCE}" ]]; then
  printf 'Copilot skills directory not found: %s\n' "${SKILLS_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${INSTRUCTIONS_SOURCE}" ]]; then
  printf 'Copilot instructions file not found: %s\n' "${INSTRUCTIONS_SOURCE}" >&2
  exit 1
fi

install -d "${COPILOT_SKILLS}"

shopt -s nullglob
for skill_target in "${COPILOT_SKILLS}"/*; do
  if [[ -L "${skill_target}" ]] &&
    [[ "$(readlink "${skill_target}")" == "${SKILLS_SOURCE}/"* ]]; then
    skill_name="${skill_target##*/}"
    if [[ ! -f "${SKILLS_SOURCE}/${skill_name}/SKILL.md" ]]; then
      rm -- "${skill_target}"
    fi
  fi
done

for skill_file in "${SKILLS_SOURCE}"/*/SKILL.md; do
  skill_source="${skill_file%/SKILL.md}"
  skill_name="${skill_source##*/}"
  skill_target="${COPILOT_SKILLS}/${skill_name}"

  if [[ -L "${skill_target}" ]] &&
    [[ "$(readlink "${skill_target}")" == "${skill_source}" ]]; then
    :
  elif [[ -e "${skill_target}" || -L "${skill_target}" ]]; then
    printf 'Skipping Copilot skill %s; target already exists: %s\n' \
      "${skill_name}" "${skill_target}" >&2
  else
    ln -s "${skill_source}" "${skill_target}"
  fi
done

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
