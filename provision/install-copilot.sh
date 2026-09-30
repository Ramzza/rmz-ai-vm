#!/usr/bin/env bash
set -euo pipefail

readonly DEV_USER="${1:?Development user is required}"
readonly DEV_HOME="${2:?Development home directory is required}"
readonly COPILOT_VERSION="${3:?Copilot version is required}"

runuser -u "${DEV_USER}" -- \
  env HOME="${DEV_HOME}" VERSION="${COPILOT_VERSION}" \
  bash -o pipefail -c 'curl -fsSL https://gh.io/copilot-install | bash'
