# frozen_string_literal: true

require "json"

vm_settings = JSON.parse(File.read(File.join(__dir__, "vm-config.json")))

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "copilot-dev"
  config.vm.boot_timeout = 600

  config.vm.synced_folder File.expand_path("..", __dir__),
                          "/workspace",
                          owner: "vagrant",
                          group: "vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.name = ENV.fetch("VM_NAME", vm_settings.fetch("name"))
    vb.cpus = Integer(ENV.fetch("VM_CPUS", vm_settings.fetch("cpus").to_s), 10)
    vb.memory = Integer(ENV.fetch("VM_MEMORY_MB", vm_settings.fetch("memory_mb").to_s), 10)
    vb.gui = false
  end

  config.vm.provision "shell",
    path: "provision/bootstrap.sh",
    args: [
      ENV.fetch("VM_USER", "vagrant"),
      File.join("/workspace", File.basename(__dir__), ".github", "skills"),
      File.join("/workspace", File.basename(__dir__), ".github", "copilot-instructions.md"),
      File.join("/workspace", File.basename(__dir__), "provision", "copilot-settings.json"),
      File.join("/workspace", File.basename(__dir__), "provision", "configure-copilot-settings.sh"),
      File.join("/workspace", File.basename(__dir__), "provision", "install-copilot.sh")
    ]
end
