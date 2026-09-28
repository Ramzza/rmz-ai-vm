# Product Requirements

## Outcome

Provide a reproducible Ubuntu development VM for GitHub Copilot CLI while keeping project files and shared Copilot configuration on the host.

## Requirements

- **PRD-001 - Persistent development environment:** `vagrant up` provides a headless Ubuntu 22.04 VM and mounts the host directory containing this repository at `/workspace`, so project files persist outside the guest.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-001`.
- **PRD-002 - Tunable VM resources:** The VM defaults to 2 CPUs and 6144 MB of memory; `VM_CPUS` and `VM_MEMORY_MB` override those defaults, and `VM_NAME` overrides the VirtualBox machine name.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-002`.
- **PRD-003 - Repository-managed Copilot setup:** Provisioning uses `VM_USER` (default `vagrant`), reconciles the pinned Copilot CLI package on every run, and connects that account to the repository's skills and instructions.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-003`; `tests/provisioning-contract.bats::PRD-003`; `tests/install-copilot.bats::PRD-003` tests for package reconciliation and bootstrap provisioning; `tests/vagrant-smoke.bats`.
- **PRD-004 - Safe managed preferences:** Managed Copilot settings enforce the configured model, effort, and hidden tabs; they are validated and applied idempotently, preserve unrelated user preferences, and fail without corrupting existing settings when managed input is invalid or missing.
  **Verification:** `tests/configure-copilot-settings.bats` tests prefixed `PRD-004`.

The Vagrant smoke test is an opt-in end-to-end check requiring Vagrant, VirtualBox, hardware virtualization, and internet access.
