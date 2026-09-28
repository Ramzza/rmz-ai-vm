# Product requirements

## Outcome

Provide a reproducible Ubuntu development VM for GitHub Copilot CLI while keeping project files and shared Copilot configuration on the host.

## Requirements

- **PRD-001 - Persistent development environment:** `vagrant up` provides a headless Ubuntu 22.04 VM and mounts the host directory containing this repository at `/workspace`, so project files persist outside the guest.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-001`.
- **PRD-002 - Tunable VM resources:** The VM defaults to 2 CPUs and 4096 MB of memory; `VM_CPUS` and `VM_MEMORY_MB` override those defaults.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-002`.
- **PRD-003 - Repository-managed Copilot setup:** Provisioning uses `VM_USER` (default `vagrant`), installs the pinned Copilot CLI for that account, and connects that account to the repository's skills, instructions, and managed settings.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-003`; `tests/provisioning-contract.bats::PRD-003`.
- **PRD-004 - Safe managed preferences:** Managed Copilot settings are validated and applied idempotently, preserve unrelated user preferences, and fail without corrupting existing settings when managed input is invalid or missing.
  **Verification:** `tests/configure-copilot-settings.bats` tests prefixed `PRD-004`.
