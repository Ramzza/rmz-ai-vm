#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  DEVCONTAINER_DIRECTORY="${REPO_ROOT}/.devcontainer"
}

@test "PRD-011: devcontainer mounts the parent and installs required runtimes" {
  run ruby -rjson -ryaml -e '
    config_path, compose_path, dockerfile_path = ARGV
    raise "Missing devcontainer configuration" unless File.file?(config_path)
    raise "Missing Compose configuration" unless File.file?(compose_path)
    raise "Missing devcontainer Dockerfile" unless File.file?(dockerfile_path)

    config = JSON.parse(File.read(config_path))
    compose = YAML.safe_load(File.read(compose_path))
    dockerfile = File.read(dockerfile_path)
    service = compose.fetch("services").fetch("workspace")
    workspace_mount = service.fetch("volumes").find { |volume| volume["target"] == "/workspace" }

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
  ' \
    "${DEVCONTAINER_DIRECTORY}/devcontainer.json" \
    "${DEVCONTAINER_DIRECTORY}/compose.yaml" \
    "${DEVCONTAINER_DIRECTORY}/Dockerfile"

  [ "$status" -eq 0 ]
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
