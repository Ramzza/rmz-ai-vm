# Copilot CLI Ubuntu VM

This is a small, reproducible Ubuntu 22.04 development VM for GitHub Copilot CLI. It uses [Vagrant](https://www.vagrantup.com/) with VirtualBox and mounts the parent projects directory at `/workspace`.

Business requirements are defined in [`PRD.md`](PRD.md), with every requirement mapped to automated tests.

## Host prerequisites

- Vagrant
- VirtualBox
- Hardware virtualization enabled in firmware
- At least 16 GB of host RAM is recommended, with 8 GB available for the VM

The VM defaults to 4 CPUs and 8 GB of memory. Its editable VirtualBox attributes are in the root-level `vm-config.json`.

### Windows installation

Install the prerequisites from an elevated PowerShell:

```powershell
winget install --id Oracle.VirtualBox --exact --accept-source-agreements --accept-package-agreements
winget install --id Hashicorp.Vagrant --exact --accept-source-agreements --accept-package-agreements
```

Close and reopen PowerShell after installation so the updated `PATH` is loaded.

### Ubuntu installation

Install the prerequisites with APT:

```bash
sudo apt update
sudo apt install -y virtualbox vagrant
```

If your Ubuntu release does not provide a suitable Vagrant package, use the official package from [Vagrant Downloads](https://developer.hashicorp.com/vagrant/install):

```bash
curl -fsSL https://releases.hashicorp.com/vagrant/latest/index.txt
```

Then download and install the current `vagrant_*.deb` for your architecture. Log out and back in if your user needs to be added to the `vboxusers` group:

```bash
sudo usermod -aG vboxusers "$USER"
```

## Create and use the VM

### Start with `rmz-copilot` from the host

Run the setup script once from this repository to add `rmz-copilot` to your current user's shell profile.

**Windows PowerShell:**

```powershell
.\scripts\setup-rmz-copilot.ps1
```

Open a new PowerShell session, then run:

```powershell
rmz-copilot
```

**Linux Bash or Zsh:**

```bash
bash scripts/setup-rmz-copilot.sh
```

Open a new terminal, then run:

```bash
rmz-copilot
```

The command runs on the host: it changes to this repository, runs `vagrant up`, and then runs `vagrant ssh` only if startup succeeds. The guest shell starts in `/workspace`, the mounted projects directory.

### Manual startup

From this directory:

```sh
vagrant up
vagrant ssh
copilot-init # optional: register the plugin marketplace and import instructions/settings
copilot
rmz-autopilot # optional: start in Autopilot and YOLO modes with a 30 AI-credit session limit
```

`copilot-init` registers the RMZ plugin marketplace, links this repository's instructions, and applies its managed settings. To load the RMZ skills, install the plugin after initialization:

```sh
copilot plugin install rmz-ai-skills@rmz-ai-marketplace
```

On the first Copilot CLI launch, authenticate with `/login`, or provide `GH_TOKEN`/`GITHUB_TOKEN` when starting the VM. Run `rmz-autopilot` to start Copilot in Autopilot and YOLO modes with a 30 AI-credit limit for that session. You can also press `Shift+Tab` in Copilot CLI to change modes; Copilot persists the selected mode in its user configuration.

The host directory containing this repository's parent is available at `/workspace`; this repository is mounted under `/workspace/<repository-folder>`, and future projects can be created alongside it. Edits made there remain on the host and are available after recreating the VM.

## Recreate or tune the VM

Edit `vm-config.json` to set a fixed VirtualBox machine name, CPU count, or memory allocation (`memory_mb`, in MB). The default `"name": null` lets Vagrant generate a unique VM name instead of reusing a global `copilot-dev` directory. For a running VM, apply CPU or memory changes with `vagrant reload`.

```sh
vagrant destroy -f
vagrant up
```

The `VM_NAME`, `VM_CPUS`, and `VM_MEMORY_MB` environment variables override the corresponding config-file values for a Vagrant command. Use `VM_NAME` only when you need a fixed name that is not already used by another VM or leftover VM directory:

```sh
# PowerShell
$env:VM_CPUS = "6"
$env:VM_MEMORY_MB = "12288"
vagrant up
```

```sh
# Bash
VM_CPUS=6 VM_MEMORY_MB=12288 vagrant up
```

To rerun provisioning after changing `provision/bootstrap.sh` or to install new system dependencies in an existing VM:

```sh
vagrant provision
```

The first `vagrant provision` after this settings update installs `jq`, which `copilot-init` uses to merge managed settings. After that, VM repository instruction or settings changes only require rerunning `copilot-init`; marketplace plugin changes are managed with `copilot plugin update <plugin-name>`.

## Copilot CLI recovery

If Copilot exits unexpectedly and the terminal begins printing mouse-report sequences, run `reset` or open a new terminal. A `no platform package found` error indicates an incomplete Copilot CLI installation; reinstall the current upstream release with:

```sh
vagrant provision
```

If the process was terminated with `SIGKILL`, check for an out-of-memory kill from inside the VM:

```sh
journalctl -k --since "10 minutes ago" | grep -Ei 'oom|out of memory|killed process'
```

Increase `memory_mb` in `vm-config.json` (or override it with `VM_MEMORY_MB`) if the kernel log confirms memory pressure, then reload the VM.

## Run tests

The VM includes [Bats](https://bats-core.readthedocs.io/). Run the unit tests from the repository root:

```sh
bats tests
bash tests/shell-line-endings.sh
```

The default suite does not boot a VM. To run the separate end-to-end Vagrant smoke test, use a host with Vagrant, VirtualBox, hardware virtualization, and internet access:

```sh
RUN_VAGRANT_SMOKE=1 bats tests/vagrant-smoke.bats
```

The smoke test uses an isolated project copy, a unique VirtualBox name, and a temporary `VAGRANT_HOME`; it checks that Copilot opens in a pseudo-terminal before initialization, runs `copilot-init`, verifies the marketplace registration and imported instructions/settings, and destroys the test VM.

## Copilot configuration

Provisioning installs the system-wide `copilot-init` command but leaves the VM user's `~/.copilot` profile untouched. Run `copilot-init` inside the VM to register `Ramzza/rmz-ai-marketplace`, link this repository's `.github/copilot-instructions.md`, and merge `provision/copilot-settings.json` into `~/.copilot/settings.json`. The managed settings select `gpt-6-luna` at `max` effort, hide the Gists tab, and enable every documented `footer.show*` status-line field (the CLI calls this display the footer). Each run reapplies those managed values, avoids duplicate marketplace registration, preserves unrelated preferences and conflicting user-owned instruction targets, and removes only stale skill symlinks from the VM repository's former `.github/skills/` directory. Marketplace plugins are not installed automatically; install the skill collection with `copilot plugin install rmz-ai-skills@rmz-ai-marketplace`.

The `rmz-ai-skills` plugin in the marketplace contains all former VM skills, including the document/PDFtk, `playwright-explore-website`, and RMZ workflow skills with their scripts, references, and test instructions. Third-party attribution is preserved in the plugin's `THIRD-PARTY-LICENSES.md`. The `pdftk-server` skill uses the `pdftk` package installed by provisioning.

## Installed tooling

The provisioner installs Git, Git LFS, GitHub CLI, GitHub Copilot CLI using the [official Linux install script](https://gh.io/copilot-install), Microsoft Visual Studio Code, Python 3 with virtual-environment support, Node.js v22 and npm, `pdftk`, jq, ripgrep, fd, direnv, tmux, zsh, build tools, ShellCheck, and Bats. The installer runs as root and places the CLI in `/usr/local/bin`, so `copilot` is available system-wide; `copilot-init` is registered there as a separate manual command. Node.js v22 and npm are installed from NodeSource's 22.x APT repository for development; Copilot itself is installed separately with GitHub's official installer.

During provisioning, `npm config set bin-links false --location=user` runs as the development user. This avoids npm's executable symlinks on the host-shared VirtualBox workspace; npm therefore does not create `node_modules/.bin` links there. Reprovision with `vagrant provision` to install the latest stable CLI release and apply provisioning changes.

Autopilot is selected inside the CLI with `Shift+Tab`. The `code` command is also available.

The default VM is headless (`vb.gui = false`), so the graphical VS Code application is installed but is not displayed inside the VM unless you add a graphical desktop and display support. For a typical workflow, use VS Code on the host with the `/workspace` folder, or connect using VS Code Remote - SSH.
