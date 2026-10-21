#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  DEVCONTAINER_DIRECTORY="${REPO_ROOT}/.devcontainer"
  TEST_TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf -- "${TEST_TMP_DIR}"
}

@test "PRD-011: devcontainer mounts the parent and installs required runtimes" {
  run ruby -rjson -ryaml -e '
    config_path, compose_path, dockerfile_path = ARGV
    keyring_entrypoint_path = File.join(File.dirname(dockerfile_path), "keyring-entrypoint.sh")
    raise "Missing devcontainer configuration" unless File.file?(config_path)
    raise "Missing Compose configuration" unless File.file?(compose_path)
    raise "Missing devcontainer Dockerfile" unless File.file?(dockerfile_path)
    raise "Missing keyring entrypoint" unless File.executable?(keyring_entrypoint_path)

    config = JSON.parse(File.read(config_path))
    compose = YAML.safe_load(File.read(compose_path))
    dockerfile = File.read(dockerfile_path)
    service = compose.fetch("services").fetch("workspace")
    workspace_mount = service.fetch("volumes").find { |volume| volume["target"] == "/workspace" }
    keyring_mount = service.fetch("volumes").find { |volume| volume["target"] == "/home/vscode/.local/share/keyrings" }
    keyring_packages = %w[dbus gnome-keyring libsecret-1-0]

    raise "Devcontainer must use the Compose configuration" unless config["dockerComposeFile"] == "compose.yaml"
    raise "Devcontainer must use the workspace service" unless config["service"] == "workspace"
    raise "Workspace must resolve to the mounted repository" unless config["workspaceFolder"] == "/workspace/${localWorkspaceFolderBasename}"
    raise "Devcontainer must use the vscode user" unless config["remoteUser"] == "vscode"
    raise "Compose must mount the repository parent at /workspace" unless workspace_mount && workspace_mount["source"] == "../.."
    raise "Compose must build the devcontainer Dockerfile" unless service.fetch("build").fetch("dockerfile") == ".devcontainer/Dockerfile"
    raise "Container must use Python 3.15" unless dockerfile.match?(/^FROM python:3\.15-slim\b/)
    raise "Container must install Node.js 22" unless dockerfile.include?("https://deb.nodesource.com/setup_22.x")
    raise "Container must install the nodejs package" unless dockerfile.include?("apt-get install --yes --no-install-recommends nodejs")
    raise "Container must install Copilot CLI with the official installer" unless dockerfile.include?("https://gh.io/copilot-install")
    raise "Container must run as vscode" unless dockerfile.match?(/^USER vscode$/)
    raise "Container must install D-Bus, GNOME Keyring, and libsecret" unless keyring_packages.all? { |package| dockerfile.include?(package) }
    raise "Container must copy the keyring entrypoint" unless dockerfile.include?("COPY .devcontainer/keyring-entrypoint.sh /usr/local/bin/keyring-entrypoint")
    raise "Container must start the keyring entrypoint" unless dockerfile.include?("ENTRYPOINT [\"/usr/local/bin/keyring-entrypoint\"]")
    raise "Keyring directory must be writable only by vscode" unless dockerfile.include?("install -d -o vscode -g vscode -m 0700 /home/vscode/.local/share/keyrings")
    raise "Compose must set the D-Bus session address" unless service.fetch("environment").fetch("DBUS_SESSION_BUS_ADDRESS") == "unix:path=/tmp/copilot-keyring-bus"
    raise "Compose must set the D-Bus runtime directory" unless service.fetch("environment").fetch("XDG_RUNTIME_DIR") == "/tmp/copilot-keyring-runtime"
    raise "Compose must persist the keyring data in a named volume" unless keyring_mount && keyring_mount["type"] == "volume" && keyring_mount["source"] == "copilot-keyring" && compose.fetch("volumes").key?("copilot-keyring")
  ' \
    "${DEVCONTAINER_DIRECTORY}/devcontainer.json" \
    "${DEVCONTAINER_DIRECTORY}/compose.yaml" \
    "${DEVCONTAINER_DIRECTORY}/Dockerfile"

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
}

@test "PRD-011: keyring entrypoint starts D-Bus and unlocks the persistent keyring" {
  local stub_directory="${TEST_TMP_DIR}/bin"
  local call_log="${TEST_TMP_DIR}/calls"
  local bus_socket="${TEST_TMP_DIR}/dbus"
  local runtime_directory="${TEST_TMP_DIR}/runtime"
  mkdir -p "${stub_directory}"
  mkdir -p "${runtime_directory}/keyring"
  touch "${runtime_directory}/keyring/control" "${bus_socket}"

  cat >"${stub_directory}/dbus-daemon" <<'SH'
#!/usr/bin/env bash
printf 'dbus-daemon %s\n' "$*" >>"${KEYRING_CALL_LOG}"
SH
  cat >"${stub_directory}/gnome-keyring-daemon" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "--unlock" ]]; then
  keyring_input="$(cat)"
  [[ -z "${keyring_input}" ]]
fi
printf 'gnome-keyring-daemon %s\n' "$*" >>"${KEYRING_CALL_LOG}"
SH
  chmod +x "${stub_directory}/dbus-daemon" "${stub_directory}/gnome-keyring-daemon"

  run env \
    "PATH=${stub_directory}:${PATH}" \
    "KEYRING_CALL_LOG=${call_log}" \
    "DBUS_SESSION_BUS_ADDRESS=unix:path=${bus_socket}" \
    "XDG_RUNTIME_DIR=${runtime_directory}" \
    "${DEVCONTAINER_DIRECTORY}/keyring-entrypoint.sh" \
    bash -c 'printf "%s|%s|%s\n" "$DBUS_SESSION_BUS_ADDRESS" "$XDG_RUNTIME_DIR" "$1"' _ "keyring ready"

  [ "$status" -eq 0 ]
  [ "$output" = "unix:path=${bus_socket}|${runtime_directory}|keyring ready" ]
  [ ! -e "${runtime_directory}/keyring" ]
  [ ! -e "${bus_socket}" ]
  [ "$(sed -n '1p' "${call_log}")" = "dbus-daemon --session --address=unix:path=${bus_socket} --fork --nopidfile" ]
  [ "$(sed -n '2p' "${call_log}")" = "gnome-keyring-daemon --start --components=secrets" ]
  [ "$(sed -n '3p' "${call_log}")" = "gnome-keyring-daemon --unlock" ]
  [ "$(wc -l <"${call_log}")" -eq 3 ]
}

@test "PRD-011: README documents Docker installation on Windows and Ubuntu" {
  grep -F -q \
    'winget install --id Docker.DockerDesktop --exact --accept-source-agreements --accept-package-agreements' \
    "${REPO_ROOT}/README.md"
  grep -F -q \
    'sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin' \
    "${REPO_ROOT}/README.md"
  grep -F -q 'sudo usermod -aG docker "$USER"' "${REPO_ROOT}/README.md"
}
