# Architecture

This repository defines a reproducible Ubuntu development VM. Vagrant configures VirtualBox; host-side repository files remain the source of truth and are mounted into the guest.

## Components and provisioning

- `Vagrantfile` selects the Ubuntu 22.04 box, configures VM resources, and mounts the repository's parent directory at `/workspace`. The shell provisioner runs with root privileges and configures the `vagrant` account by default.
- `provision/bootstrap.sh` installs system tools, Node.js, the pinned Copilot CLI, and VS Code. It also registers the repository's Copilot configuration in the guest user's home directory.
- `.github/skills/*/SKILL.md` and `.github/copilot-instructions.md` are linked into `~/.copilot`; edits to these host-mounted files are immediately visible in the guest.
- `provision/copilot-settings.json` contains VM-managed Copilot settings. `provision/configure-copilot-settings.sh` validates and merges them into `~/.copilot/settings.json`, preserving unrelated settings and replacing the file atomically.

## Lifecycle and data flow

`vagrant up` creates or starts the VM and runs provisioning on initial creation by default. The provisioner uses paths under `/workspace/<repository>` to find the versioned skills, instructions, and settings, then installs links or merges settings into the guest user's home. Project files are edited in the mounted workspace, so they persist independently of VM recreation; installed tools and user-home state belong to the guest.

`vagrant provision` or `vagrant up --provision` reapplies setup after provisioning changes. VM CPU and memory can be set with `VM_CPUS` and `VM_MEMORY_MB`. Copilot settings changes are applied by reprovisioning.

## Validation

The shell configuration tests run with `bats tests`; the GitHub Actions workflow runs the repository checks.
