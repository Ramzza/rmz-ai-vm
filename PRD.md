# Product Requirements

## Outcome

Provide a reproducible Ubuntu development VM with GitHub Copilot CLI while keeping project files on the host and leaving the user's Copilot profile untouched until they manually run `copilot-init`.

## Requirements

- **PRD-001 - Persistent development environment:** `vagrant up` provides a headless Ubuntu 22.04 VM and mounts the host directory containing this repository at `/workspace`, so project files persist outside the guest.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-001`.
- **PRD-002 - Editable VM resources:** Root-level `vm-config.json` lists the optional VirtualBox name, CPU count, and memory in MB; a `null` name lets Vagrant generate a unique machine name by default. Resource defaults are 4 CPUs and 8192 MB. `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` override their respective settings.
  **Verification:** `tests/vagrantfile-contract.bats` tests prefixed `PRD-002`.
- **PRD-003 - Official Copilot and Node.js v22 provisioning:** Provisioning installs the latest stable Copilot CLI with GitHub's official Linux installer and makes `copilot` available system-wide. It configures NodeSource's 22.x APT repository and installs `nodejs`, providing Node.js v22 and npm for development, then configures the development user's npm with `bin-links=false` so installs work on the host-shared VirtualBox workspace; the Copilot CLI installation remains independent of this development runtime.
  **Verification:** `tests/provisioning-contract.bats::PRD-003` verifies the official installer URL and default stable-version behavior, configures NodeSource's 22.x repository, requests `nodejs` rather than Ubuntu's separate `npm` package, and sets the development user's npm config; `tests/vagrant-smoke.bats` verifies the Copilot CLI path, Node.js v22 and npm availability, the user-level `bin-links=false` setting, and interactive startup in Ubuntu before profile initialization.
- **PRD-004 - Optional Copilot initialization:** Provisioning installs the `copilot-init` command but does not create or modify the VM user's `~/.copilot` profile. When manually invoked, `copilot-init` links repository instructions and skills, applies managed settings (GPT-6 Luna at maximum effort, hidden Gists tab, and all supported footer status fields enabled), reconciles added or removed skills on repeat runs, and preserves unrelated user preferences and conflicting user-owned targets.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-004` checks the init-script path; `tests/provisioning-contract.bats::PRD-004` checks provisioning leaves the profile untouched and exposes the command; `tests/copilot-init.bats::PRD-004` checks managed settings, repeat-run updates, and preservation; `tests/vagrant-smoke.bats` exercises manual initialization in Ubuntu.
- **PRD-005 - Host-side Copilot launcher:** A host command starts Vagrant from this repository on the host, runs `vagrant up` before `vagrant ssh`, and can be installed for Bash/Zsh on Linux or PowerShell on Windows. The Windows launcher does not treat the interactive guest shell's exit status as an SSH launch failure.
  **Verification:** `tests/rmz-copilot.bats` tests prefixed `PRD-005`; `tests/rmz-copilot-windows.ps1` in the Windows CI job verifies nonzero guest shell exit statuses.
- **PRD-006 - Workspace-first SSH sessions:** An interactive `vagrant ssh` session starts in `/workspace`, the mounted host projects directory.
  **Verification:** `tests/provisioning-contract.bats::PRD-006`.

The Vagrant smoke test is an opt-in end-to-end check requiring Vagrant, VirtualBox, hardware virtualization, and internet access.
