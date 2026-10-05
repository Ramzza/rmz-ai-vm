# AGENTS.md

## Project context
This repository builds a headless Ubuntu 22.04 development VM using Vagrant and VirtualBox; `Vagrantfile` mounts the parent projects folder at `/workspace`, `provision/` installs guest tools and `copilot-init`, `scripts/` provides host launchers, `.github/` holds canonical Copilot instructions and skills, and `tests/` covers shell, Vagrant, and Windows host behavior. See [ARCHITECTURE.md](ARCHITECTURE.md) and [PRD.md](PRD.md).

## Conventions
- Keep VM resource defaults in `vm-config.json`; the Vagrant configuration also supports `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` overrides.
- Use Bash for Linux provisioning and launchers, PowerShell for Windows host commands, and Ruby syntax in `Vagrantfile`.
- Treat `.github/copilot-instructions.md` and `.github/skills/*/SKILL.md` as canonical workflow guidance; reuse existing scripts and helpers.

## Scripts
- `bats tests` runs the Bats suite.
- `bash tests/shell-line-endings.sh` checks shell-script line endings.
- `bash -n provision/bootstrap.sh scripts/rmz-copilot.sh scripts/setup-rmz-copilot.sh tests/shell-line-endings.sh` checks Bash syntax.
- `ruby -c Vagrantfile` checks the Vagrant configuration syntax.
- `./tests/rmz-copilot-windows.ps1` runs the Windows host-command test in PowerShell.
- `RUN_VAGRANT_SMOKE=1 bats tests/vagrant-smoke.bats` runs the opt-in smoke test and requires Vagrant, VirtualBox, hardware virtualization, and internet access.

## Constraints
- Treat `PRD.md` as the requirements source of truth and follow `.github/copilot-instructions.md` for test-first behavior changes and requirement-to-test mappings.
- Provisioning must leave the guest user's `~/.copilot` profile untouched; `copilot-init` is an explicit manual step.
- Preserve the host-shared workspace behavior, including the development user's npm `bin-links=false` setting.
- Do not commit tokens or credentials; edit canonical repository assets rather than copied/generated VM state.
