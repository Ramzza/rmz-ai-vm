#!/usr/bin/env bash
set -euo pipefail

readonly DEV_USER="${1:-vagrant}"
readonly DEV_HOME="$(getent passwd "${DEV_USER}" | cut -d: -f6)"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install --yes --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  direnv \
  fd-find \
  git \
  git-lfs \
  gh \
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

git lfs install --system

if ! command -v node >/dev/null 2>&1; then
  curl --fail --silent --show-error https://deb.nodesource.com/setup_22.x | bash -
  apt-get install --yes --no-install-recommends nodejs
fi

if ! command -v copilot >/dev/null 2>&1; then
  curl --fail --silent --show-error https://gh.io/copilot-install | bash
fi

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

install -d -o "${DEV_USER}" -g "${DEV_USER}" "${DEV_HOME}/.config"

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
alias copilot-auto='copilot'
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
