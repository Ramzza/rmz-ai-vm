#!/usr/bin/env bash
set -euo pipefail

readonly DEV_USER="${1:-vagrant}"
DEV_HOME="$(getent passwd "${DEV_USER}" | cut -d: -f6)"
readonly DEV_HOME
readonly COPILOT_INIT_SOURCE="${2:?Copilot init script path is required}"

if [[ ! -f "${COPILOT_INIT_SOURCE}" ]]; then
  printf 'Copilot init script not found: %s\n' "${COPILOT_INIT_SOURCE}" >&2
  [[ -f "${COPILOT_INIT_SOURCE}" ]]
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install --yes --no-install-recommends \
  build-essential \
  bats \
  ca-certificates \
  curl \
  direnv \
  fd-find \
  git \
  git-lfs \
  gnupg \
  jq \
  ripgrep \
  tmux \
  unzip \
  zsh \
  python3 \
  python3-pip \
  python3-venv \
  shellcheck

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
  tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
printf '%s\n' \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
  tee /etc/apt/sources.list.d/github-cli.list >/dev/null
apt-get update
apt-get install --yes --no-install-recommends gh

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get update
apt-get install --yes --no-install-recommends nodejs

runuser -u "${DEV_USER}" -- env HOME="${DEV_HOME}" \
  npm config set bin-links false --location=user

git lfs install --system

curl -fsSL https://gh.io/copilot-install | bash

if ! command -v copilot >/dev/null 2>&1; then
  printf 'Copilot CLI executable not found after installation.\n' >&2
  exit 1
fi

COPILOT_COMMAND_PATH="$(command -v copilot)"
readonly COPILOT_COMMAND_PATH
COPILOT_BIN_DIR="${COPILOT_COMMAND_PATH%/*}"
readonly COPILOT_BIN_DIR
readonly COPILOT_INIT_TARGET="${COPILOT_BIN_DIR}/copilot-init"

if [[ -L "${COPILOT_INIT_TARGET}" ]] &&
  [[ "$(readlink -f "${COPILOT_INIT_TARGET}")" == "$(readlink -f "${COPILOT_INIT_SOURCE}")" ]]; then
  rm -- "${COPILOT_INIT_TARGET}"
fi

if [[ -f "${COPILOT_INIT_TARGET}" ]] &&
  [[ ! -L "${COPILOT_INIT_TARGET}" ]] &&
  grep -Fqx '# Managed by rmz-ai-vm Copilot init wrapper' "${COPILOT_INIT_TARGET}"; then
  :
elif [[ -e "${COPILOT_INIT_TARGET}" || -L "${COPILOT_INIT_TARGET}" ]]; then
  printf 'Cannot expose copilot-init; target already exists: %s\n' \
    "${COPILOT_INIT_TARGET}" >&2
  exit 1
fi

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' '# Managed by rmz-ai-vm Copilot init wrapper'
  printf 'exec bash %q "$@"\n' "${COPILOT_INIT_SOURCE}"
} >"${COPILOT_INIT_TARGET}"
chmod 0755 "${COPILOT_INIT_TARGET}"

if ! command -v code >/dev/null 2>&1; then
  install -d -m 0755 /etc/apt/keyrings
  curl --fail --silent --show-error https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor --yes -o /etc/apt/keyrings/packages.microsoft.gpg
  chmod 0644 /etc/apt/keyrings/packages.microsoft.gpg
  printf '%s\n' \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list
  apt-get update
  apt-get install --yes --no-install-recommends code
fi

cat > "${DEV_HOME}/.bashrc.d-copilot" <<'EOF'
# Coding environment helpers
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  alias fd='fdfind'
fi

eval "$(direnv hook bash)"

export EDITOR="${EDITOR:-nano}"
export VISUAL="${VISUAL:-${EDITOR}}"
export WORKSPACE="/workspace"

alias croot='cd /workspace'
alias gs='git status --short --branch'

cd /workspace
EOF

touch "${DEV_HOME}/.bashrc"
grep -qxF 'source ~/.bashrc.d-copilot' "${DEV_HOME}/.bashrc" ||
  printf '\nsource ~/.bashrc.d-copilot\n' >> "${DEV_HOME}/.bashrc"

chown "${DEV_USER}:${DEV_USER}" \
  "${DEV_HOME}/.bashrc" \
  "${DEV_HOME}/.bashrc.d-copilot"

apt-get clean
rm -rf /var/lib/apt/lists/*

printf '\nProvisioning complete. Run: vagrant ssh\n'
