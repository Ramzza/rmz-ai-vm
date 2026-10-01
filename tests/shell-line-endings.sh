#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly LF_ENFORCED_FILES=(
  "provision/bootstrap.sh"
  "provision/copilot-init.sh"
  "scripts/rmz-copilot.sh"
  "scripts/setup-rmz-copilot.sh"
  "tests/rmz-copilot.bats"
)

for relative_path in "${LF_ENFORCED_FILES[@]}"; do
  file_path="${REPO_ROOT}/${relative_path}"
  file_attribute="$(git -C "${REPO_ROOT}" check-attr eol -- "${relative_path}")"
  if [[ "${file_attribute}" != "${relative_path}: eol: lf" ]]; then
    printf 'Expected %s to use LF line endings\n' "${relative_path}" >&2
    exit 1
  fi

  if LC_ALL=C grep -q $'\r' "${file_path}"; then
    printf '%s contains CRLF line endings\n' "${relative_path}" >&2
    exit 1
  fi
done
