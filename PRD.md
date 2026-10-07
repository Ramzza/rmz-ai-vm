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
- **PRD-004 - Optional Copilot initialization:** Provisioning installs the `copilot-init` command but does not create or modify the VM user's `~/.copilot` profile. When manually invoked, `copilot-init` registers the `rmz-ai-marketplace` marketplace, links repository instructions, and applies managed settings (GPT-6 Luna at maximum effort, hidden Gists tab, and all supported footer status fields enabled). Repeat runs avoid duplicate marketplace registration, remove only stale skill links owned by this repository, and preserve unrelated user preferences and conflicting user-owned targets.
  **Verification:** `tests/vagrantfile-contract.bats::PRD-004` checks the init-script path; `tests/provisioning-contract.bats::PRD-004` checks provisioning leaves the profile untouched and exposes the command; `tests/copilot-init.bats::PRD-004` checks marketplace registration, managed settings, repeat-run updates, and preservation; `tests/vagrant-smoke.bats` exercises manual initialization in Ubuntu.
- **PRD-005 - Host-side Copilot launcher:** A host command starts Vagrant from this repository on the host, runs `vagrant up` before `vagrant ssh`, and can be installed for Bash/Zsh on Linux or PowerShell on Windows. The Windows launcher does not treat the interactive guest shell's exit status as an SSH launch failure.
  **Verification:** `tests/rmz-copilot.bats` tests prefixed `PRD-005`; `tests/rmz-copilot-windows.ps1` in the Windows CI job verifies nonzero guest shell exit statuses.
- **PRD-006 - Workspace-first SSH sessions:** An interactive `vagrant ssh` session starts in `/workspace`, the mounted host projects directory.
  **Verification:** `tests/provisioning-contract.bats::PRD-006`.
- **PRD-007 - Latest GitHub CLI provisioning:** Provisioning configures GitHub's official stable APT repository and installs `gh` without a version pin, so new VMs receive the latest stable GitHub CLI available at provisioning time (currently v2.102.0).
  **Verification:** `tests/provisioning-contract.bats::PRD-007` verifies the official signing key and `signed-by` source, refreshes package metadata after repository setup, and installs the unpinned `gh` package.
- **PRD-008 - Autopilot alias:** Provisioning adds the `rmz-autopilot` alias to the development user's Bash environment. It starts Copilot in Autopilot and YOLO modes with a 30 AI-credit limit for the session.
  **Verification:** `tests/provisioning-contract.bats::PRD-008` sources the provisioned Bash helper and verifies the alias invokes Copilot with `--autopilot`, `--max-ai-credits 30`, and `--yolo`.
- **PRD-009 - Marketplace skills and PDFtk prerequisite:** All former VM skills, including the document/PDFtk and RMZ workflow skills, are distributed from the `rmz-ai-skills` plugin in `Ramzza/rmz-ai-marketplace`; installing that plugin is separate from registering the marketplace. The VM repository no longer stores or links skill files. Provisioning retains `pdftk` for the `pdftk-server` skill.
  **Verification:** `tests/copilot-init.bats::PRD-009` checks stale repository-owned skill links are removed without modifying user skills; `tests/provisioning-contract.bats::PRD-009` checks that the APT package install includes `pdftk`; `Ramzza/rmz-ai-marketplace:tests/marketplace.bats::MKT-005` checks the complete plugin skill bundle and resources.
- **PRD-010 - Playwright website exploration skill:** The `rmz-ai-skills` plugin includes the upstream `playwright-explore-website` skill with its website exploration and test-case instructions. Users install it from the marketplace rather than through `copilot-init`.
  **Verification:** `tests/copilot-init.bats::PRD-010` checks marketplace documentation and confirms initialization does not create a local skill link; `Ramzza/rmz-ai-marketplace:tests/marketplace.bats::MKT-005` checks the skill's presence, instructions, and attribution in the plugin.

The Vagrant smoke test is an opt-in end-to-end check requiring Vagrant, VirtualBox, hardware virtualization, and internet access.
