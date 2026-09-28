#!/usr/bin/env bash
set -euo pipefail

readonly DEV_USER="${1:?Development user is required}"
readonly DEV_HOME="${2:?Development home directory is required}"
readonly COPILOT_VERSION="${3:?Copilot version is required}"

runuser -u "${DEV_USER}" -- \
  npm install --global --prefix "${DEV_HOME}/.local" \
  "@github/copilot@${COPILOT_VERSION}"
