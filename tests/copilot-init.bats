#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  COPILOT_INIT_SOURCE="${REPO_ROOT}/provision/copilot-init.sh"
  COPILOT_SETTINGS_SOURCE="${REPO_ROOT}/provision/copilot-settings.json"
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
  cp "${COPILOT_SETTINGS_SOURCE}" \
    "${TEST_REPOSITORY}/provision/copilot-settings.json"
  printf '%s\n' 'Test-only Copilot instructions' >"${TEST_INSTRUCTIONS_SOURCE}"
  printf '%s\n' 'name: rmz-test' >"${TEST_SKILLS_SOURCE}/rmz-test/SKILL.md"
}

teardown() {
  rm -rf -- "${TEST_DIRECTORY}"
}

run_init() {
  env HOME="${TEST_HOME}" bash "${TEST_REPOSITORY}/provision/copilot-init.sh"
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

@test "PRD-004: links repository instructions and skills idempotently" {
  mkdir -p "${TEST_HOME}/.copilot"
  printf '{"theme":"dim","model":"user-model","effortLevel":"low","tabs":{"sort":["issues"],"hide":["issues"]},"footer":{"showBranch":false}}\n' \
    >"${TEST_HOME}/.copilot/settings.json"

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
}

@test "PRD-004: creates managed settings when no user settings exist" {
  run run_init

  [ "${status}" -eq 0 ]
  run assert_managed_settings "${TEST_HOME}/.copilot/settings.json" '["gists"]'
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
  run assert_managed_settings "${TEST_HOME}/.copilot/settings.json" '["gists"]'
  [ "${status}" -eq 0 ]
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
}

@test "PRD-004: rejects missing repository Copilot assets" {
  rm -- "${TEST_INSTRUCTIONS_SOURCE}"

  run run_init

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Copilot instructions file not found"* ]]
  [ ! -e "${TEST_HOME}/.copilot/skills" ]
}

@test "PRD-009: links bundled non-rmz skills and their resources" {
  run env HOME="${TEST_HOME}" bash "${COPILOT_INIT_SOURCE}"

  [ "${status}" -eq 0 ]
  for skill_name in \
    convert-excel-to-md \
    convert-pdf-to-md \
    convert-word-to-md \
    md-to-docx \
    pdftk-server; do
    skill_source="${REPO_ROOT}/.github/skills/${skill_name}"
    skill_target="${TEST_HOME}/.copilot/skills/${skill_name}"

    [ -f "${skill_source}/SKILL.md" ]
    [ -L "${skill_target}" ]
    run readlink -f -- "${skill_target}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "${skill_source}" ]
    run grep -Fqx "name: ${skill_name}" "${skill_source}/SKILL.md"
    [ "${status}" -eq 0 ]
  done

  for resource in \
    convert-excel-to-md/references/setup.md \
    convert-excel-to-md/scripts/convert_excel_to_md.py \
    convert-excel-to-md/scripts/requirements.txt \
    convert-pdf-to-md/references/setup.md \
    convert-pdf-to-md/scripts/convert_pdf_to_md.py \
    convert-pdf-to-md/scripts/requirements.txt \
    convert-word-to-md/references/setup.md \
    convert-word-to-md/scripts/convert_word_to_md.py \
    convert-word-to-md/scripts/requirements.txt \
    md-to-docx/scripts/md-to-docx.mjs \
    md-to-docx/scripts/package.json \
    pdftk-server/references/download.md \
    pdftk-server/references/pdftk-cli-examples.md \
    pdftk-server/references/pdftk-man-page.md \
    pdftk-server/references/pdftk-server-license.md \
    pdftk-server/references/third-party-materials.md; do
    [ -f "${TEST_HOME}/.copilot/skills/${resource}" ]
  done
}

@test "PRD-010: links the Playwright website exploration skill" {
  skill_name=playwright-explore-website
  skill_source="${REPO_ROOT}/.github/skills/${skill_name}"
  skill_target="${TEST_HOME}/.copilot/skills/${skill_name}"

  run env HOME="${TEST_HOME}" bash "${COPILOT_INIT_SOURCE}"

  [ "${status}" -eq 0 ]
  [ -f "${skill_source}/SKILL.md" ]
  [ -L "${skill_target}" ]
  run readlink -f -- "${skill_target}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${skill_source}" ]
  run grep -Fqx "name: ${skill_name}" "${skill_source}/SKILL.md"
  [ "${status}" -eq 0 ]
  run grep -Fqx '# Website Exploration for Testing' \
    "${skill_source}/SKILL.md"
  [ "${status}" -eq 0 ]
  run grep -Fqx '6. Propose and generate test cases based on the exploration.' \
    "${skill_source}/SKILL.md"
  [ "${status}" -eq 0 ]
  [ -f "${skill_target}/SKILL.md" ]
}
