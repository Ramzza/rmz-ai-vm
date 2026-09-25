# frozen_string_literal: true

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "copilot-dev"
  config.vm.boot_timeout = 600

  config.vm.synced_folder ".", "/workspace", owner: "vagrant", group: "vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "copilot-dev"
    vb.cpus = ENV.fetch("VM_CPUS", "2").to_i
    vb.memory = ENV.fetch("VM_MEMORY_MB", "4096").to_i
    vb.gui = false
  end

  config.vm.provision "shell",
    path: "provision/bootstrap.sh",
    args: ENV.fetch("VM_USER", "vagrant")
end
