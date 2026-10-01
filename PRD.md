# Product Requirements

## Outcome

Provide a reproducible Ubuntu development VM with GitHub Copilot CLI while keeping project files on the host, importing repository instructions and skills, and preserving user-managed Copilot settings.

## Requirements

- **PRD-001 - Persistent development environment:** `vagrant up` provides a headless Ubuntu 22.04 VM and mounts the host directory containing this repository at `/workspace`, so project files persist outside the guest.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-001`.
- **PRD-002 - Editable VM resources:** Root-level `vm-config.json` lists the optional VirtualBox name, CPU count, and memory in MB; a `null` name lets Vagrant generate a unique machine name by default. Resource defaults are 4 CPUs and 8192 MB. `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` override their respective settings.
  **Verification:** `tests/vagrantfile-contract.bats` tests prefixed `PRD-002`.
- **PRD-003 - Official Copilot installation:** Provisioning installs the latest stable Copilot CLI with GitHub's official Linux installer, without npm, and makes `copilot` available system-wide.
  **Verification:** `tests/provisioning-contract.bats::PRD-003` verifies the official installer URL, default stable-version behavior, and absence of npm/Node.js; `tests/vagrant-smoke.bats` verifies the CLI path and version in Ubuntu.
- **PRD-004 - Repository Copilot assets:** Provisioning links `.github/copilot-instructions.md` to the VM user's `~/.copilot/copilot-instructions.md` and every `.github/skills/<name>/` containing `SKILL.md` to `~/.copilot/skills/<name>`. Imports are idempotent and preserve existing settings and conflicting user-owned instruction or skill files.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-004` checks the mounted repository asset paths; `tests/provisioning-contract.bats::PRD-004` checks the links, idempotency, and preservation behavior; `tests/vagrant-smoke.bats` verifies imported assets in Ubuntu.
- **PRD-005 - Host-side Copilot launcher:** A host command starts Vagrant from this repository on the host, runs `vagrant up` before `vagrant ssh`, and can be installed for Bash/Zsh on Linux or PowerShell on Windows. The Windows launcher does not treat the interactive guest shell's exit status as an SSH launch failure.
  **Verification:** `tests/rmz-copilot.bats` tests prefixed `PRD-005`; `tests/rmz-copilot-windows.ps1` in the Windows CI job verifies nonzero guest shell exit statuses.
- **PRD-006 - Workspace-first SSH sessions:** An interactive `vagrant ssh` session starts in `/workspace`, the mounted host projects directory.
  **Verification:** `tests/provisioning-contract.bats::PRD-006`.

The Vagrant smoke test is an opt-in end-to-end check requiring Vagrant, VirtualBox, hardware virtualization, and internet access.
