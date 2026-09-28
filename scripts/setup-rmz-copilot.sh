#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER_PATH="${REPO_ROOT}/scripts/rmz-copilot.sh"

if [[ -z "${SHELL:-}" ]]; then
  printf 'Cannot detect the login shell because SHELL is empty or unset.\n' >&2
  exit 1
fi

SHELL_NAME="${SHELL##*/}"
case "${SHELL_NAME}" in
  bash) SHELL_RC="${HOME}/.bashrc" ;;
  zsh) SHELL_RC="${HOME}/.zshrc" ;;
  *)
    printf 'Unsupported login shell: %s (supported: Bash and Zsh).\n' \
      "${SHELL_NAME}" >&2
    exit 1
    ;;
esac

CONFIG_DIRECTORY="${HOME}/.config/rmz-ai-vm"
FUNCTION_FILE="${CONFIG_DIRECTORY}/rmz-copilot.sh"
SOURCE_LINE='. "$HOME/.config/rmz-ai-vm/rmz-copilot.sh" # rmz-copilot setup'

mkdir -p -- "${CONFIG_DIRECTORY}"
printf -v QUOTED_LAUNCHER_PATH '%q' "${LAUNCHER_PATH}"
cat >"${FUNCTION_FILE}" <<EOF
rmz-copilot() {
  bash ${QUOTED_LAUNCHER_PATH}
}
EOF

if [[ ! -f "${SHELL_RC}" ]]; then
  mkdir -p -- "$(dirname -- "${SHELL_RC}")"
  : >"${SHELL_RC}"
fi

if ! grep -Fqx -- "${SOURCE_LINE}" "${SHELL_RC}"; then
  if [[ -s "${SHELL_RC}" ]] && [[ "$(tail -c 1 "${SHELL_RC}" | wc -l)" -eq 0 ]]; then
    printf '\n' >>"${SHELL_RC}"
  fi
  printf '%s\n' "${SOURCE_LINE}" >>"${SHELL_RC}"
fi

printf 'Installed rmz-copilot for %s in %s. Open a new terminal to use it.\n' \
  "${SHELL_NAME}" "${SHELL_RC}"
