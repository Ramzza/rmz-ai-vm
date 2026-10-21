#!/usr/bin/env bash
set -euo pipefail

bus_socket="${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 0700 "${XDG_RUNTIME_DIR}"
rm -rf "${XDG_RUNTIME_DIR}/keyring"
rm -f "${bus_socket}"
dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --fork --nopidfile
gnome-keyring-daemon --start --components=secrets >/dev/null
printf '\n' | gnome-keyring-daemon --unlock >/dev/null

exec "$@"
