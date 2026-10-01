#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  COPILOT_INIT_SOURCE="${REPO_ROOT}/provision/copilot-init.sh"
  TEST_DIRECTORY="$(mktemp -d)"
  TEST_REPOSITORY="${TEST_DIRECTORY}/repo"
  TEST_HOME="${TEST_DIRECTORY}/home"
  TEST_SKILLS_SOURCE="${TEST_REPOSITORY}/.github/skills"
  TEST_INSTRUCTIONS_SOURCE="${TEST_REPOSITORY}/.github/copilot-instructions.md"
  mkdir -p \
    "${TEST_REPOSITORY}/provision" \
    "${TEST_SKILLS_SOURCE}/rmz-test" \
    "${TEST_SKILLS_SOURCE}/notes" \
    "${TEST_HOME}"
  if [[ -f "${COPILOT_INIT_SOURCE}" ]]; then
    cp "${COPILOT_INIT_SOURCE}" "${TEST_REPOSITORY}/provision/copilot-init.sh"
  fi
  printf '%s\n' 'Test-only Copilot instructions' >"${TEST_INSTRUCTIONS_SOURCE}"
  printf '%s\n' 'name: rmz-test' >"${TEST_SKILLS_SOURCE}/rmz-test/SKILL.md"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

run_init() {
  env HOME="${TEST_HOME}" bash "${TEST_REPOSITORY}/provision/copilot-init.sh"
}

@test "PRD-004: provides a standalone copilot-init script" {
  [ -f "${COPILOT_INIT_SOURCE}" ]
}

@test "PRD-004: links repository instructions and skills idempotently" {
  mkdir -p "${TEST_HOME}/.copilot"
  printf '{"theme":"dim","tabs":{"hide":["issues"]}}\n' \
    >"${TEST_HOME}/.copilot/settings.json"
  cp "${TEST_HOME}/.copilot/settings.json" "${TEST_DIRECTORY}/settings-before.json"

  run run_init

  [ "${status}" -eq 0 ]
  [ -L "${TEST_HOME}/.copilot/copilot-instructions.md" ]
  run readlink -f "${TEST_HOME}/.copilot/copilot-instructions.md"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${TEST_INSTRUCTIONS_SOURCE}" ]
  [ -L "${TEST_HOME}/.copilot/skills/rmz-test" ]
  run readlink -f "${TEST_HOME}/.copilot/skills/rmz-test"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${TEST_SKILLS_SOURCE}/rmz-test" ]
  [ -f "${TEST_HOME}/.copilot/skills/rmz-test/SKILL.md" ]
  run cmp "${TEST_DIRECTORY}/settings-before.json" \
    "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]

  run run_init

  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/settings-before.json" \
    "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: reconciles added and removed repository skills" {
  run run_init
  [ "${status}" -eq 0 ]

  printf '%s\n' 'Updated instructions' >"${TEST_INSTRUCTIONS_SOURCE}"
  mkdir -p "${TEST_SKILLS_SOURCE}/rmz-new"
  printf '%s\n' 'name: rmz-new' >"${TEST_SKILLS_SOURCE}/rmz-new/SKILL.md"
  rm -- "${TEST_SKILLS_SOURCE}/rmz-test/SKILL.md"
  rmdir -- "${TEST_SKILLS_SOURCE}/rmz-test"

  run run_init

  [ "${status}" -eq 0 ]
  run cmp "${TEST_INSTRUCTIONS_SOURCE}" \
    "${TEST_HOME}/.copilot/copilot-instructions.md"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_HOME}/.copilot/skills/rmz-test" ]
  [ -L "${TEST_HOME}/.copilot/skills/rmz-new" ]
  run readlink -f "${TEST_HOME}/.copilot/skills/rmz-new"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${TEST_SKILLS_SOURCE}/rmz-new" ]
}

@test "PRD-004: preserves user-owned settings and conflicting targets" {
  mkdir -p "${TEST_HOME}/.copilot/skills/rmz-test"
  printf '%s\n' '{"theme":"dark"}' >"${TEST_HOME}/.copilot/settings.json"
  printf '%s\n' 'User-owned instructions' \
    >"${TEST_HOME}/.copilot/copilot-instructions.md"
  printf '%s\n' 'User-owned skill' \
    >"${TEST_HOME}/.copilot/skills/rmz-test/SKILL.md"
  cp "${TEST_HOME}/.copilot/settings.json" "${TEST_DIRECTORY}/settings-before.json"
  cp "${TEST_HOME}/.copilot/copilot-instructions.md" \
    "${TEST_DIRECTORY}/instructions-before.md"
  cp "${TEST_HOME}/.copilot/skills/rmz-test/SKILL.md" \
    "${TEST_DIRECTORY}/skill-before.md"

  run run_init

  [ "${status}" -eq 0 ]
  [ ! -L "${TEST_HOME}/.copilot/copilot-instructions.md" ]
  [ ! -L "${TEST_HOME}/.copilot/skills/rmz-test" ]
  run cmp "${TEST_DIRECTORY}/settings-before.json" \
    "${TEST_HOME}/.copilot/settings.json"
  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/instructions-before.md" \
    "${TEST_HOME}/.copilot/copilot-instructions.md"
  [ "${status}" -eq 0 ]
  run cmp "${TEST_DIRECTORY}/skill-before.md" \
    "${TEST_HOME}/.copilot/skills/rmz-test/SKILL.md"
  [ "${status}" -eq 0 ]
}

@test "PRD-004: rejects missing repository Copilot assets" {
  rm -- "${TEST_INSTRUCTIONS_SOURCE}"

  run run_init

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Copilot instructions file not found"* ]]
  [ ! -e "${TEST_HOME}/.copilot/skills" ]
}
