#!/usr/bin/env bash
set -euo pipefail

bus_socket="${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 0700 "${XDG_RUNTIME_DIR}"
rm -rf "${XDG_RUNTIME_DIR}/keyring"
rm -f "${bus_socket}"
dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --fork --nopidfile
printf '\n' | gnome-keyring-daemon --login >/dev/null
keyring_environment="$(gnome-keyring-daemon --start --components=secrets)"
eval "${keyring_environment}"

exec "$@"
