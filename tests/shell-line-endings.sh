#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SETTINGS_MERGER="${REPO_ROOT}/provision/configure-copilot-settings.sh"

SETTINGS_MERGER_ATTRIBUTE="$(git -C "${REPO_ROOT}" check-attr eol -- \
  provision/configure-copilot-settings.sh)"
readonly SETTINGS_MERGER_ATTRIBUTE
if [[ "${SETTINGS_MERGER_ATTRIBUTE}" != \
  "provision/configure-copilot-settings.sh: eol: lf" ]]; then
  printf 'Expected the Copilot settings merger to use LF line endings\n' >&2
  exit 1
fi

if LC_ALL=C grep -q $'\r' "${SETTINGS_MERGER}"; then
  printf 'Copilot settings merger contains CRLF line endings\n' >&2
  exit 1
fi
