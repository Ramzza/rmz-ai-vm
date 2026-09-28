#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  PRD_FILE="${PRD_FILE_PATH:-${REPO_ROOT}/PRD.md}"
  TESTS_DIRECTORY="${TESTS_DIRECTORY_PATH:-${REPO_ROOT}/tests}"
}

@test "every PRD requirement maps to a named test" {
  [ -f "${PRD_FILE}" ]
  mapfile -t requirement_ids < <(
    sed -nE 's/^- \*\*(PRD-[0-9]{3}) - .*/\1/p' "${PRD_FILE}"
  )
  [ "${#requirement_ids[@]}" -gt 0 ]

  for requirement_id in "${requirement_ids[@]}"; do
    if ! grep -R -F -q --include='*.bats' \
      "@test \"${requirement_id}:" "${TESTS_DIRECTORY}"; then
      printf 'No named test found for %s\n' "${requirement_id}" >&2
      return 1
    fi
  done
}
