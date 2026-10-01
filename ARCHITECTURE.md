# Architecture

This repository defines a reproducible Ubuntu development VM. Vagrant configures VirtualBox; host-side repository files remain the source of truth and are mounted into the guest.

## Components and provisioning

- `Vagrantfile` selects the Ubuntu 22.04 box, configures VM resources, and mounts the repository's parent directory at `/workspace`. The shell provisioner runs as root; `bootstrap.sh` uses `VM_USER` (`vagrant` by default) for the guest user's shell setup.
- `vm-config.json` holds the optional VirtualBox name and editable CPU/memory defaults loaded by `Vagrantfile`. A `null` name delegates to Vagrant's instance-specific name generation to avoid fixed VM-directory collisions; `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` can override the settings.
- `provision/bootstrap.sh` installs system tools (including `jq`), GitHub Copilot CLI using the official Linux install script, and VS Code. The installer runs as root and places `copilot` in `/usr/local/bin`; it does not use Node.js/npm or modify user settings.
- `Vagrantfile` passes the mounted repository's `provision/copilot-init.sh` path to the root provisioner. `bootstrap.sh` installs an executable `copilot-init` wrapper beside the Copilot CLI without running it or modifying the guest user's profile.
- `provision/copilot-init.sh` runs manually as the guest user. It derives the repository root from its script path, merges `provision/copilot-settings.json` into `~/.copilot/settings.json`, and links repository instructions and skills into `~/.copilot`. Repeat runs reapply managed settings and reconcile repository-owned skill links while preserving unrelated preferences and conflicting targets.
- `scripts/rmz-copilot.sh` and `scripts/rmz-copilot.ps1` run on the host, resolve the repository root, and start Vagrant before opening SSH. Their setup scripts register the `rmz-copilot` function in the user's Bash/Zsh or PowerShell profile.
- `.github/skills/*/SKILL.md`, `.github/copilot-instructions.md`, and `provision/copilot-settings.json` are the canonical repository assets. `copilot-init` links the instructions and skills into `~/.copilot` and merges managed settings over their corresponding user keys; unrelated user preferences and conflicting instruction or skill targets remain unchanged.

## Lifecycle and data flow

`vagrant up` creates or starts the VM and runs provisioning on initial creation by default. The root provisioner installs the current stable Copilot CLI release system-wide, registers the separate `copilot-init` command, and configures the guest user's shell. It does not create or modify `~/.copilot`; the guest user opts in by running `copilot-init` after provisioning. Project files are edited in the mounted workspace, so they persist independently of VM recreation.

`vagrant provision` or `vagrant up --provision` reapplies setup after provisioning changes. The VM defaults to 4 CPUs and 8192 MB of memory as defined in `vm-config.json`; the `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` environment variables override their respective values.

## Validation

The shell configuration tests run with `bats tests`; the GitHub Actions workflow runs the repository checks.
