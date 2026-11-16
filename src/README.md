# Ansible Proxmox Orchestration

## Description
This directory contains the Ansible code responsible for the initial configuration of Proxmox and the complete deployment of the environment.

The project automates the following:
- **Proxmox Initialization:** Configures storage and creates the necessary infrastructure for guests.
- **Ubuntu Customization:** Downloads the **Ubuntu 24.04** Generic Cloud image and uses `virt-customize` to inject configurations (SSH, etc.).
- **VM Template Creation:** Creates a Cloud-Init VM template on Proxmox.
- **Resource Provisioning:** Creates the Virtual Machines directly via Ansible (no Terraform required).
- **Environment Configuration:** Sets up users, SSH keys, DNS client and system packages across the Ubuntu guests.
- **Docker Host (`netuno`):** Installs Docker Engine + Compose, frees port 53 and enables IP forwarding. The compose stacks (AdGuard, Tailscale, Duplicati) are deployed by `homelab-deploys`.
- **Home Assistant OS (`terra`):** Creates the VM from the official HAOS image (UEFI/q35).

## Troubleshooting & Manual Fixes
While the goal is full automation, some initial Proxmox tweaks might be necessary for a smoother experience:

### 1. Proxmox Subscription Nag & Repositories
By default, Proxmox comes with enterprise repositories that require a subscription. You might need to comment them out to avoid `apt-get update` errors:
- `/etc/apt/sources.list.d/ceph.list`
- `/etc/apt/sources.list.d/pve-enterprise.list`

### 2. Remove "No Valid Subscription" Pop-up
To hide the subscription nag when logging into the Proxmox UI:

1.  Open `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js`.
2.  Search for the check that triggers the pop-up (usually checking if `status !== 'active'`).
3.  Modify the logic to `if (false)` to bypass it.
4.  Restart the proxy service: `systemctl restart pveproxy.service`.

## Usage
Create `src/hosts.yaml` from `config-files/sample/hosts.yaml` (`just init-hosts`) and edit it with `just secrets-edit`.

```bash
# Full deployment (Proxmox init + VM creation + guest configuration)
just deploy-homelab

# Destroy everything (VMs and VM templates)
just destroy-homelab
```

## Main Playbooks

- `main.yaml`: The primary entry point. It triggers the entire lifecycle: Proxmox init, image customization, VM creation, user configuration, Docker host setup and the vzdump job.
- `configure-ssh.yaml`: Used for the initial SSH key exchange with the Proxmox host.
- `destroy.yaml`: Orchestrates the destruction of the environment to return to a clean state.
- `update-os.yaml` / `power-management.yaml`: OS updates and start/stop of all guests.

## Structure
- `roles/`: Contains modular tasks for each part of the infrastructure (e.g., `create-proxmox-vms`, `docker-host`, `proxmox-backup-jobs`).
- `library/`: Custom Ansible modules (e.g., `ssh_copy_key.py`).
- `callback_plugins/`: Custom plugins for better output formatting.
