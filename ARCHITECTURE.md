# Architecture

This repository defines a reproducible Ubuntu development VM. Vagrant configures VirtualBox; host-side repository files remain the source of truth and are mounted into the guest.

## Components and provisioning

- `Vagrantfile` selects the Ubuntu 22.04 box, configures VM resources, and mounts the repository's parent directory at `/workspace`. The shell provisioner runs as root; `bootstrap.sh` configures the guest account named by `VM_USER` (`vagrant` by default) for user-scoped setup in that account's home directory.
- `provision/bootstrap.sh` installs system tools, Node.js, the pinned Copilot CLI, and VS Code. Its `install-copilot.sh` helper reconciles the pinned package on every provisioning run, so incomplete platform dependencies are repaired. It also registers the repository's Copilot configuration in the guest user's home directory.
- `scripts/rmz-copilot.sh` and `scripts/rmz-copilot.ps1` run on the host, resolve the repository root, and start Vagrant before opening SSH. Their setup scripts register the `rmz-copilot` function in the user's Bash/Zsh or PowerShell profile.
- `.github/skills/*/SKILL.md` and `.github/copilot-instructions.md` are linked into `~/.copilot`; edits to these host-mounted files are immediately visible in the guest.
- `provision/copilot-settings.json` contains VM-managed Copilot settings. `provision/configure-copilot-settings.sh` validates and merges them into `~/.copilot/settings.json`, preserving unrelated settings and replacing the file atomically.

## Lifecycle and data flow

`vagrant up` creates or starts the VM and runs provisioning on initial creation by default. The root provisioner uses paths under `/workspace/<repository>` to find the versioned skills, instructions, and settings, then switches to the configured guest user for the user-home links and settings it manages there. Project files are edited in the mounted workspace, so they persist independently of VM recreation; installed tools and user-home state belong to the guest.

`vagrant provision` or `vagrant up --provision` reapplies setup after provisioning changes. The VM defaults to 2 CPUs and 6144 MB of memory; `VM_CPUS` and `VM_MEMORY_MB` override these defaults, and `VM_NAME` overrides the VirtualBox machine name. Copilot settings changes are applied by reprovisioning.

## Validation

The shell configuration tests run with `bats tests`; the GitHub Actions workflow runs the repository checks.
