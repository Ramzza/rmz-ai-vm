#!/usr/bin/env bash
set -euo pipefail

readonly DEV_USER="${1:-vagrant}"
readonly DEV_HOME="$(getent passwd "${DEV_USER}" | cut -d: -f6)"
readonly COPILOT_VERSION="1.0.88"
readonly SKILLS_SOURCE="${2:?Copilot skills source path is required}"
readonly INSTRUCTIONS_SOURCE="${3:?Copilot instructions source path is required}"

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
  install -d -m 0755 /etc/apt/keyrings
  curl --fail --silent --show-error \
    https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key |
    gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  chmod 0644 /etc/apt/keyrings/nodesource.gpg
  printf '%s\n' \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install --yes --no-install-recommends nodejs
fi

install -d -o "${DEV_USER}" -g "${DEV_USER}" "${DEV_HOME}/.local"
if [ ! -x "${DEV_HOME}/.local/bin/copilot" ]; then
  runuser -u "${DEV_USER}" -- \
    npm install --global --prefix "${DEV_HOME}/.local" \
    "@github/copilot@${COPILOT_VERSION}"
fi

if [ ! -d "${SKILLS_SOURCE}" ]; then
  printf 'Copilot skills directory not found: %s\n' "${SKILLS_SOURCE}" >&2
  exit 1
fi

readonly COPILOT_SKILLS="${DEV_HOME}/.copilot/skills"
install -d -o "${DEV_USER}" -g "${DEV_USER}" "${COPILOT_SKILLS}"
for skill_path in "${SKILLS_SOURCE}"/*/; do
  [ -f "${skill_path}SKILL.md" ] || continue
  skill_name="${skill_path%/}"
  skill_name="${skill_name##*/}"
  skill_target="${COPILOT_SKILLS}/${skill_name}"

  if [ -L "${skill_target}" ] && [ "$(readlink "${skill_target}")" = "${skill_path}" ]; then
    continue
  fi
  if [ -e "${skill_target}" ] || [ -L "${skill_target}" ]; then
    printf 'Skipping Copilot skill %s; target already exists: %s\n' \
      "${skill_name}" "${skill_target}" >&2
    continue
  fi

  ln -s "${skill_path}" "${skill_target}"
done

if [ ! -f "${INSTRUCTIONS_SOURCE}" ]; then
  printf 'Copilot instructions file not found: %s\n' "${INSTRUCTIONS_SOURCE}" >&2
  exit 1
fi

readonly INSTRUCTIONS_TARGET="${DEV_HOME}/.copilot/copilot-instructions.md"
if [ -L "${INSTRUCTIONS_TARGET}" ] &&
  [ "$(readlink "${INSTRUCTIONS_TARGET}")" = "${INSTRUCTIONS_SOURCE}" ]; then
  :
elif [ -e "${INSTRUCTIONS_TARGET}" ] || [ -L "${INSTRUCTIONS_TARGET}" ]; then
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

install -d -o "${DEV_USER}" -g "${DEV_USER}" "${DEV_HOME}/.config"

cat > "${DEV_HOME}/.bashrc.d-copilot" <<'EOF'
# Coding environment helpers
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  alias fd='fdfind'
fi

eval "$(direnv hook bash)"

export PATH="$HOME/.local/bin:$PATH"
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
