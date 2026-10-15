#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "${REPO_ROOT}"

if [[ "$#" -eq 0 ]]; then
  vagrant up
  exec vagrant ssh
elif [[ "$#" -eq 1 && "$1" == "--off" ]]; then
  exec vagrant suspend
else
  printf 'Usage: %s [--off]\n' "${0##*/}" >&2
  false
fi
