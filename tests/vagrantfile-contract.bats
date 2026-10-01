#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  VAGRANTFILE="${VAGRANTFILE_PATH:-${REPO_ROOT}/Vagrantfile}"
  VM_CONFIG_TEST_DIRECTORY=""
}

teardown() {
  if [[ -n "${VM_CONFIG_TEST_DIRECTORY}" &&
    -d "${VM_CONFIG_TEST_DIRECTORY}" ]]; then
    rm -rf -- "${VM_CONFIG_TEST_DIRECTORY}"
  fi
}

assert_contains() {
  run grep -F -q -- "$1" "${VAGRANTFILE}"
  [ "${status}" -eq 0 ]
}

evaluate_vagrantfile() {
  local vagrantfile="$1"
  shift

  env "$@" ruby - "${vagrantfile}" <<'RUBY'
class TestProviderSettings
  attr_accessor :name, :cpus, :memory, :gui
end

class TestVM
  attr_accessor :box, :hostname, :boot_timeout
  attr_reader :provider_settings, :provision_call

  def initialize
    @provider_settings = TestProviderSettings.new
  end

  def synced_folder(*args, **options)
  end

  def provider(name)
    raise "Unexpected provider: #{name}" unless name == "virtualbox"

    yield provider_settings
  end

  def provision(*args, **options)
    @provision_call = [args, options]
  end
end

class TestConfig
  attr_reader :vm

  def initialize
    @vm = TestVM.new
  end
end

module Vagrant
  class << self
    attr_reader :config

    def configure(version)
      raise "Unexpected Vagrant config version: #{version}" unless version == "2"

      @config = TestConfig.new
      yield @config
    end
  end
end

load ARGV.fetch(0)
if ENV["TEST_CAPTURE_PROVISION"] == "1"
  provision_options = Vagrant.config.vm.provision_call.fetch(1)
  puts [provision_options.fetch(:path), *provision_options.fetch(:args)].join("|")
else
  settings = Vagrant.config.vm.provider_settings
  name = settings.name.nil? ? "auto" : settings.name
  puts [name, settings.cpus, settings.memory].join("|")
end
RUBY
}

@test "PRD-001: provisions a persistent headless Ubuntu 22.04 workspace" {
  assert_contains 'config.vm.box = "ubuntu/jammy64"'
  assert_contains 'config.vm.synced_folder File.expand_path("..", __dir__),'
  assert_contains '"/workspace",'
  assert_contains 'vb.gui = false'
}

@test "PRD-002: lets Vagrant generate the name and defaults to 4 CPUs and 8192 MB" {
  run evaluate_vagrantfile "${VAGRANTFILE}" \
    -u VM_CPUS -u VM_MEMORY_MB -u VM_NAME
  [ "${status}" -eq 0 ]
  [ "${output}" = "auto|4|8192" ]
}

@test "PRD-002: exposes VM defaults in a root-level JSON config" {
  [ -f "${REPO_ROOT}/vm-config.json" ]
  run ruby -rjson -e '
    settings = JSON.parse(File.read(ARGV.fetch(0)))
    expected = {
      "name" => nil,
      "cpus" => 4,
      "memory_mb" => 8192
    }
    expected.each do |key, value|
      abort "Unexpected #{key}: #{settings.fetch(key)}" unless settings.fetch(key) == value
    end
  ' "${REPO_ROOT}/vm-config.json"
  [ "${status}" -eq 0 ]
}

@test "PRD-002: reads edited VM attributes from the config file" {
  [ -f "${REPO_ROOT}/vm-config.json" ]
  VM_CONFIG_TEST_DIRECTORY="$(mktemp -d)"
  cp "${VAGRANTFILE}" "${VM_CONFIG_TEST_DIRECTORY}/Vagrantfile"
  cp "${REPO_ROOT}/vm-config.json" "${VM_CONFIG_TEST_DIRECTORY}/vm-config.json"
  ruby -rjson -e '
    path = ARGV.fetch(0)
    settings = JSON.parse(File.read(path))
    settings["name"] = "custom-dev"
    settings["cpus"] = 6
    settings["memory_mb"] = 12288
    File.write(path, JSON.pretty_generate(settings) + "\n")
  ' "${VM_CONFIG_TEST_DIRECTORY}/vm-config.json"

  run evaluate_vagrantfile "${VM_CONFIG_TEST_DIRECTORY}/Vagrantfile" \
    -u VM_CPUS -u VM_MEMORY_MB -u VM_NAME
  [ "${status}" -eq 0 ]
  [ "${output}" = "custom-dev|6|12288" ]
}

@test "PRD-002: preserves environment variable overrides" {
  run evaluate_vagrantfile "${VAGRANTFILE}" \
    VM_NAME=override-dev VM_CPUS=2 VM_MEMORY_MB=4096
  [ "${status}" -eq 0 ]
  [ "${output}" = "override-dev|2|4096" ]
}

@test "PRD-004: passes the manual initialization script to bootstrap" {
  repo_name="${REPO_ROOT##*/}"
  run evaluate_vagrantfile "${VAGRANTFILE}" \
    -u VM_USER TEST_CAPTURE_PROVISION=1
  [ "${status}" -eq 0 ]
  expected_output="provision/bootstrap.sh|vagrant"
  expected_output="${expected_output}|/workspace/${repo_name}/provision/copilot-init.sh"
  [ "${output}" = "${expected_output}" ]
}
