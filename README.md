# Copilot CLI Ubuntu VM

This is a small, reproducible Ubuntu 24.04 development VM for GitHub Copilot CLI. It uses [Vagrant](https://www.vagrantup.com/) with VirtualBox and keeps the project directory mounted at `/workspace`.

## Host prerequisites

- Vagrant
- VirtualBox
- Hardware virtualization enabled in firmware
- At least 4 GB of host RAM available for the VM

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

From this directory:

```sh
vagrant up
vagrant ssh
cd /workspace
copilot
```

On the first Copilot CLI launch, authenticate with `/login`, or provide `GH_TOKEN`/`GITHUB_TOKEN` when starting the VM. To use Autopilot mode, press `Shift+Tab` in Copilot CLI until Autopilot is selected. Copilot persists the selected mode in its user configuration.

The mounted host directory is available at `/workspace`; edits made there remain on the host and are available after recreating the VM.

## Recreate or tune the VM

```sh
vagrant destroy -f
vagrant up
```

Optional environment variables adjust the VM before `vagrant up`:

```sh
# PowerShell
$env:VM_CPUS = "4"
$env:VM_MEMORY_MB = "8192"
vagrant up
```

```sh
# Bash
VM_CPUS=4 VM_MEMORY_MB=8192 vagrant up
```

To rerun provisioning after changing `provision/bootstrap.sh`:

```sh
vagrant provision
```

## Installed tooling

The provisioner installs Git, Git LFS, GitHub CLI, Node.js 22, the official Copilot CLI, Microsoft Visual Studio Code, Python 3 with virtual-environment support, ripgrep, fd, jq, direnv, tmux, zsh, build tools, and ShellCheck.

The `copilot-auto` alias starts Copilot CLI; Autopilot itself is selected inside the CLI with `Shift+Tab`. The `code` command is also available.

The default VM is headless (`vb.gui = false`), so the graphical VS Code application is installed but is not displayed inside the VM unless you add a graphical desktop and display support. For a typical workflow, use VS Code on the host with the `/workspace` folder, or connect using VS Code Remote - SSH.
