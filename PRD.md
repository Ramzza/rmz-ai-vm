# Product Requirements

This repository provides a reproducible Ubuntu development VM for GitHub Copilot CLI.

| ID | Requirement | Verification |
| --- | --- | --- |
| VM-001 | The VM defaults to 6144 MB of RAM to provide more capacity for Copilot CLI, while retaining the `VM_MEMORY_MB` override. | `tests/install-copilot.bats`: “defaults the VM memory to 6 GiB” |
| CLI-001 | Provisioning installs the pinned Copilot CLI for the VM user and repairs incomplete package installations on every run. | `tests/install-copilot.bats`: “reconciles the pinned Copilot package” and “bootstrap provisions from Vagrant's temporary script path”; `tests/vagrant-smoke.bats` |
| CLI-002 | Managed Copilot settings enforce the configured model, effort, and hidden tabs while preserving unrelated user preferences. | `tests/configure-copilot-settings.bats`: “creates settings from the managed defaults” and “merges managed settings and preserves user preferences”; `tests/vagrant-smoke.bats` |
| CLI-003 | Repository-managed Copilot instructions and skills are available in the VM user's global Copilot configuration. | `tests/install-copilot.bats`: “bootstrap provisions from Vagrant's temporary script path” |

The Vagrant smoke test is an opt-in end-to-end check requiring Vagrant, VirtualBox, hardware virtualization, and internet access.
