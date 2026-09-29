# Product Requirements

## Outcome

Provide a reproducible Ubuntu development VM for GitHub Copilot CLI while keeping project files and shared Copilot configuration on the host.

## Requirements

- **PRD-001 - Persistent development environment:** `vagrant up` provides a headless Ubuntu 22.04 VM and mounts the host directory containing this repository at `/workspace`, so project files persist outside the guest.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-001`.
- **PRD-002 - Editable VM resources:** Root-level `vm-config.json` lists the optional VirtualBox name, CPU count, and memory in MB; a `null` name lets Vagrant generate a unique machine name by default. Resource defaults are 4 CPUs and 8192 MB. `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` override their respective settings.
  **Verification:** `tests/vagrantfile-contract.bats` tests prefixed `PRD-002`.
- **PRD-003 - Repository-managed Copilot setup:** Provisioning uses `VM_USER` (default `vagrant`), reconciles the pinned Copilot CLI package on every run, and connects that account to the repository's skills and instructions.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-003`; `tests/provisioning-contract.bats::PRD-003`; `tests/install-copilot.bats::PRD-003` tests for package reconciliation and bootstrap provisioning; `tests/vagrant-smoke.bats`.
- **PRD-004 - Safe managed preferences:** Managed Copilot settings enforce the configured model, effort, and hidden tabs; they are validated and applied idempotently, preserve unrelated user preferences, and fail without corrupting existing settings when managed input is invalid or missing.
  **Verification:** `tests/configure-copilot-settings.bats` tests prefixed `PRD-004`.
- **PRD-005 - Host-side Copilot launcher:** A host command starts Vagrant from this repository on the host, runs `vagrant up` before `vagrant ssh`, and can be installed for Bash/Zsh on Linux or PowerShell on Windows. The Windows launcher does not treat the interactive guest shell's exit status as an SSH launch failure.
  **Verification:** `tests/rmz-copilot.bats` tests prefixed `PRD-005`; `tests/rmz-copilot-windows.ps1` in the Windows CI job verifies nonzero guest shell exit statuses.
- **PRD-006 - Workspace-first SSH sessions:** An interactive `vagrant ssh` session starts in `/workspace`, the mounted host projects directory.
  **Verification:** `tests/provisioning-contract.bats::PRD-006`.

The Vagrant smoke test is an opt-in end-to-end check requiring Vagrant, VirtualBox, hardware virtualization, and internet access.
