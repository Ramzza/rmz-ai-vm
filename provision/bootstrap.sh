#!/usr/bin/env bash
set -euo pipefail

readonly DEV_USER="${1:-vagrant}"
DEV_HOME="$(getent passwd "${DEV_USER}" | cut -d: -f6)"
readonly DEV_HOME
readonly SKILLS_SOURCE="${2:?Copilot skills source path is required}"
readonly INSTRUCTIONS_SOURCE="${3:?Copilot instructions source path is required}"

if [[ ! -d "${SKILLS_SOURCE}" ]]; then
  printf 'Copilot skills directory not found: %s\n' "${SKILLS_SOURCE}" >&2
  [[ -d "${SKILLS_SOURCE}" ]]
fi

if [[ ! -f "${INSTRUCTIONS_SOURCE}" ]]; then
  printf 'Copilot instructions file not found: %s\n' "${INSTRUCTIONS_SOURCE}" >&2
  [[ -f "${INSTRUCTIONS_SOURCE}" ]]
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
  gh \
  gnupg \
  ripgrep \
  tmux \
  unzip \
  zsh \
  python3 \
  python3-pip \
  python3-venv \
  shellcheck

git lfs install --system

curl -fsSL https://gh.io/copilot-install | bash

readonly COPILOT_HOME="${DEV_HOME}/.copilot"
readonly COPILOT_SKILLS="${COPILOT_HOME}/skills"
install -d -o "${DEV_USER}" -g "${DEV_USER}" "${COPILOT_SKILLS}"

for skill_path in "${SKILLS_SOURCE}"/*/; do
  if [[ -f "${skill_path}SKILL.md" ]]; then
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    skill_target="${COPILOT_SKILLS}/${skill_name}"

    if [[ -L "${skill_target}" ]] &&
      [[ "$(readlink "${skill_target}")" == "${skill_path}" ]]; then
      :
    elif [[ -e "${skill_target}" || -L "${skill_target}" ]]; then
      printf 'Skipping Copilot skill %s; target already exists: %s\n' \
        "${skill_name}" "${skill_target}" >&2
    else
      ln -s "${skill_path}" "${skill_target}"
    fi
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
