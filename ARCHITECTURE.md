# Architecture

This repository defines a reproducible Ubuntu development VM. Vagrant configures VirtualBox; host-side repository files remain the source of truth and are mounted into the guest.

## Components and provisioning

- `Vagrantfile` selects the Ubuntu 22.04 box, configures VM resources, and mounts the repository's parent directory at `/workspace`. The shell provisioner runs as root; `bootstrap.sh` uses `VM_USER` (`vagrant` by default) for the guest user's shell setup.
- `vm-config.json` holds the optional VirtualBox name and editable CPU/memory defaults loaded by `Vagrantfile`. A `null` name delegates to Vagrant's instance-specific name generation to avoid fixed VM-directory collisions; `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` can override the settings.
- `provision/bootstrap.sh` installs system tools, GitHub Copilot CLI using the official Linux install script, and VS Code. The installer runs as root and places `copilot` in `/usr/local/bin`; it does not use Node.js/npm or modify the guest user's Copilot configuration.
- `scripts/rmz-copilot.sh` and `scripts/rmz-copilot.ps1` run on the host, resolve the repository root, and start Vagrant before opening SSH. Their setup scripts register the `rmz-copilot` function in the user's Bash/Zsh or PowerShell profile.
- `.github/skills/*/SKILL.md` and `.github/copilot-instructions.md` remain repository-local assets; provisioning does not link them into the guest user's `~/.copilot` directory.

## Lifecycle and data flow

`vagrant up` creates or starts the VM and runs provisioning on initial creation by default. The root provisioner installs the current stable Copilot CLI release system-wide and configures the guest user's shell. Project files are edited in the mounted workspace, so they persist independently of VM recreation; the user's Copilot settings remain untouched.

`vagrant provision` or `vagrant up --provision` reapplies setup after provisioning changes. The VM defaults to 4 CPUs and 8192 MB of memory as defined in `vm-config.json`; the `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` environment variables override their respective values.

## Validation

The shell configuration tests run with `bats tests`; the GitHub Actions workflow runs the repository checks.
