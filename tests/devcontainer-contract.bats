#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  DEVCONTAINER_DIRECTORY="${REPO_ROOT}/.devcontainer"
  TEST_TMP_DIR="$(mktemp -d)"
  COMPOSE_PROJECT_STARTED=0
  COMPOSE_PROJECT_NAME=""
}

teardown() {
  if [[ "${COMPOSE_PROJECT_STARTED:-0}" == "1" ]]; then
    docker compose \
      --project-name "${COMPOSE_PROJECT_NAME}" \
      --file "${DEVCONTAINER_DIRECTORY}/compose.yaml" \
      down --volumes --remove-orphans
  fi
  rm -rf -- "${TEST_TMP_DIR}"
}

@test "PRD-011: devcontainer mounts the parent and installs required runtimes and CLIs" {
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
    keyring_packages = %w[dbus gnome-keyring libsecret-1-0 libsecret-tools]

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
    claude_mount = service.fetch("volumes").find { |volume| volume["target"] == "/home/vscode/.claude" }
    claude_install = dockerfile.index("https://claude.ai/install.sh")
    raise "Container must install Claude Code with the official installer" unless claude_install
    raise "Claude Code must be installed for the vscode user" unless dockerfile.index(/^USER vscode$/) < claude_install
    raise "User-local directories must be writable by vscode" unless dockerfile.include?("install -d -o vscode -g vscode -m 0755 /home/vscode/.local /home/vscode/.local/bin /home/vscode/.local/share")
    raise "Claude Code must be on PATH" unless dockerfile.match?(%r{^ENV PATH="/home/vscode/\.local/bin:\$\{PATH\}"$})
    raise "Claude config directory must be writable only by vscode" unless dockerfile.include?("install -d -o vscode -g vscode -m 0700 /home/vscode/.claude")
    raise "Compose must set the Claude config directory" unless service.fetch("environment").fetch("CLAUDE_CONFIG_DIR") == "/home/vscode/.claude"
    raise "Compose must persist Claude Code state in a named volume" unless claude_mount && claude_mount["type"] == "volume" && claude_mount["source"] == "claude-config" && compose.fetch("volumes").key?("claude-config")
    raise "Container must run as vscode" unless dockerfile.match?(/^USER vscode$/)
    raise "Container must install D-Bus, GNOME Keyring, and libsecret tools" unless keyring_packages.all? { |package| dockerfile.include?(package) }
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

@test "PRD-011: initializes Copilot after devcontainer creation" {
  grep -F -q \
    '"postCreateCommand": "bash provision/copilot-init.sh"' \
    "${DEVCONTAINER_DIRECTORY}/devcontainer.json"
  grep -E -q '^[[:space:]]+jq([[:space:]]|$)' \
    "${DEVCONTAINER_DIRECTORY}/Dockerfile"
}

@test "PRD-011: keyring entrypoint initializes the empty login keyring" {
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
if [[ "$*" == "--start --components=secrets" ]]; then
  printf 'GNOME_KEYRING_CONTROL=%q; export GNOME_KEYRING_CONTROL\n' "${KEYRING_CONTROL}"
fi
if [[ "$*" == "--login" ]]; then
  keyring_input="$(cat)"
  [[ -z "${keyring_input}" ]]
fi
printf 'gnome-keyring-daemon %s\n' "$*" >>"${KEYRING_CALL_LOG}"
SH
  chmod +x "${stub_directory}/dbus-daemon" "${stub_directory}/gnome-keyring-daemon"

  run env \
    "PATH=${stub_directory}:${PATH}" \
    "KEYRING_CALL_LOG=${call_log}" \
    "KEYRING_CONTROL=${TEST_TMP_DIR}/keyring-control" \
    "DBUS_SESSION_BUS_ADDRESS=unix:path=${bus_socket}" \
    "XDG_RUNTIME_DIR=${runtime_directory}" \
    "${DEVCONTAINER_DIRECTORY}/keyring-entrypoint.sh" \
    bash -c 'printf "%s|%s|%s|%s\n" "$DBUS_SESSION_BUS_ADDRESS" "$XDG_RUNTIME_DIR" "$GNOME_KEYRING_CONTROL" "$1"' _ "keyring ready"

  [ "$status" -eq 0 ]
  [ "$output" = "unix:path=${bus_socket}|${runtime_directory}|${TEST_TMP_DIR}/keyring-control|keyring ready" ]
  [ ! -e "${runtime_directory}/keyring" ]
  [ ! -e "${bus_socket}" ]
  [ "$(sed -n '1p' "${call_log}")" = "dbus-daemon --session --address=unix:path=${bus_socket} --fork --nopidfile" ]
  [ "$(sed -n '2p' "${call_log}")" = "gnome-keyring-daemon --login" ]
  [ "$(sed -n '3p' "${call_log}")" = "gnome-keyring-daemon --start --components=secrets" ]
  [ "$(wc -l <"${call_log}")" -eq 3 ]
}

@test "PRD-011: Secret Service stores and retrieves a keyring secret" {
  if [[ "${RUN_DEVCONTAINER_SMOKE:-0}" != "1" ]]; then
    skip "set RUN_DEVCONTAINER_SMOKE=1 to run the Docker integration test"
  fi

  COMPOSE_PROJECT_NAME="rmz-keyring-smoke-$$"
  COMPOSE_PROJECT_STARTED=1
  run docker compose \
    --project-name "${COMPOSE_PROJECT_NAME}" \
    --file "${DEVCONTAINER_DIRECTORY}/compose.yaml" \
    up --build --detach workspace
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }

  run docker compose \
    --project-name "${COMPOSE_PROJECT_NAME}" \
    --file "${DEVCONTAINER_DIRECTORY}/compose.yaml" \
    exec -T workspace bash -lc '
      set -euo pipefail
      command -v secret-tool >/dev/null
      gh --version >/dev/null
      trap "secret-tool clear service copilot-cli smoke test >/dev/null 2>&1 || true" EXIT
      printf "%s" "synthetic-keyring-test" |
        secret-tool store --label="rmz-keyring-smoke" service copilot-cli smoke test
      secret_value="$(secret-tool lookup service copilot-cli smoke test)"
      test "${secret_value}" = "synthetic-keyring-test"
    '
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
}

@test "PRD-011: devcontainer installs latest gh from GitHub's official stable repository" {
  local dockerfile="${DEVCONTAINER_DIRECTORY}/Dockerfile"
  grep -F -q 'install -d -m 0755 /etc/apt/keyrings' "${dockerfile}"
  grep -F -q 'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg' "${dockerfile}"
  grep -F -q 'chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg' "${dockerfile}"
  grep -F -q '"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list' "${dockerfile}"
  grep -F -q 'apt-get install --yes --no-install-recommends nodejs gh' "${dockerfile}"
  ! grep -E -q '(^|[[:space:]])gh=[^[:space:]]' "${dockerfile}"

  # The repository must be configured before the apt-get update that precedes the gh install.
  local source_line install_line
  source_line="$(grep -n -F '/etc/apt/sources.list.d/github-cli.list' "${dockerfile}" | head -n 1 | cut -d: -f1)"
  install_line="$(grep -n -F 'no-install-recommends nodejs gh' "${dockerfile}" | head -n 1 | cut -d: -f1)"
  [ -n "${source_line}" ] && [ -n "${install_line}" ] && [ "${source_line}" -lt "${install_line}" ]
}

@test "PRD-012: devcontainer installs the Android build toolchain" {
  local dockerfile="${DEVCONTAINER_DIRECTORY}/Dockerfile"
  local package
  for package in openjdk-25-jdk-headless unzip wget git curl; do
    grep -E -q "^[[:space:]]+${package}([[:space:]]|$)" "${dockerfile}" ||
      { printf 'Missing APT package %s\n' "${package}" >&2; false; }
  done

  grep -F -q 'ln -s "/usr/lib/jvm/java-25-openjdk-$(dpkg --print-architecture)" /usr/lib/jvm/java-25-openjdk' "${dockerfile}"
  grep -F -x -q 'ENV JAVA_HOME=/usr/lib/jvm/java-25-openjdk' "${dockerfile}"
  grep -F -x -q 'ENV ANDROID_HOME=/opt/android-sdk' "${dockerfile}"
  grep -F -x -q 'ENV ANDROID_SDK_ROOT=/opt/android-sdk' "${dockerfile}"
  grep -F -x -q 'ENV PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"' "${dockerfile}"
  grep -F -q 'install -d -o vscode -g vscode -m 0755 /opt/android-sdk' "${dockerfile}"

  grep -E -q '^ARG ANDROID_CMDLINE_TOOLS_BUILD=[0-9]+$' "${dockerfile}"
  grep -E -q '^ARG ANDROID_CMDLINE_TOOLS_SHA1=[0-9a-f]{40}$' "${dockerfile}"
  grep -E -q '^ARG ANDROID_PLATFORM=android-[0-9.]+$' "${dockerfile}"
  grep -E -q '^ARG ANDROID_BUILD_TOOLS=[0-9]+\.[0-9]+\.[0-9]+$' "${dockerfile}"
  grep -F -q 'https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip' "${dockerfile}"
  grep -F -q 'sha1sum --check --strict' "${dockerfile}"
  grep -F -q '"${ANDROID_HOME}/cmdline-tools/latest"' "${dockerfile}"
  grep -F -q 'yes | sdkmanager --licenses' "${dockerfile}"
  grep -F -q 'sdkmanager --install platform-tools "platforms;${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}"' "${dockerfile}"

  # The SDK is populated by vscode so Gradle can add components the project needs.
  local user_line sdk_line
  user_line="$(grep -n -x 'USER vscode' "${dockerfile}" | head -n 1 | cut -d: -f1)"
  sdk_line="$(grep -n -F 'sdkmanager --install' "${dockerfile}" | head -n 1 | cut -d: -f1)"
  [ -n "${user_line}" ] && [ -n "${sdk_line}" ] && [ "${user_line}" -lt "${sdk_line}" ]
}

@test "PRD-012: Android toolchain runs in the container" {
  if [[ "${RUN_DEVCONTAINER_SMOKE:-0}" != "1" ]]; then
    skip "set RUN_DEVCONTAINER_SMOKE=1 to run the Docker integration test"
  fi

  COMPOSE_PROJECT_NAME="rmz-android-smoke-$$"
  COMPOSE_PROJECT_STARTED=1
  run docker compose \
    --project-name "${COMPOSE_PROJECT_NAME}" \
    --file "${DEVCONTAINER_DIRECTORY}/compose.yaml" \
    up --build --detach workspace
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }

  run docker compose \
    --project-name "${COMPOSE_PROJECT_NAME}" \
    --file "${DEVCONTAINER_DIRECTORY}/compose.yaml" \
    exec -T workspace bash -c '
      set -euo pipefail
      test "${ANDROID_HOME}" = /opt/android-sdk
      test "${ANDROID_SDK_ROOT}" = /opt/android-sdk
      test "${JAVA_HOME}" = /usr/lib/jvm/java-25-openjdk
      test "$(command -v java)" = "${JAVA_HOME}/bin/java"
      java -version 2>&1 | grep -E -q "version \"25[.\"]"
      test "$(command -v sdkmanager)" = "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
      test "$(command -v adb)" = "${ANDROID_HOME}/platform-tools/adb"
      adb version >/dev/null
      installed="$(sdkmanager --list_installed 2>/dev/null)"
      grep -E -q "^[[:space:]]*platform-tools[[:space:]]" <<<"${installed}"
      grep -E -q "^[[:space:]]*platforms;android-" <<<"${installed}"
      grep -E -q "^[[:space:]]*build-tools;" <<<"${installed}"
      test -w "${ANDROID_HOME}"
      command -v git unzip curl wget >/dev/null
    '
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
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
