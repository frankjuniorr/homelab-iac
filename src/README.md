# Ansible Proxmox Orchestration

## Description
This directory contains the Ansible code responsible for the initial configuration of Proxmox and the complete deployment of the environment.

The project automates the following:
- **Proxmox Initialization:** Configures storage and creates the necessary infrastructure for guests.
- **Rocky Linux Customization:** Downloads the **Rocky Linux 8** Generic Cloud image and uses `virt-customize` to inject configurations (SSH, SELinux, etc.).
- **VM Template Creation:** Creates a Cloud-Init VM template on Proxmox.
- **Resource Provisioning:** Creates both LXC Containers and Virtual Machines directly via Ansible (no Terraform required).
- **Environment Configuration:** Sets up users, SSH keys, DNS (AdGuardHome), and system packages across all nodes.
- **Kubernetes Deployment:** Installs a **K3s** cluster (masters and nodes) automatically.

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
Ensure your `hosts.yaml` is correctly configured in the root's `config-files/my-configs/` folder and installed via `just install-config-files`.

```bash
# Full deployment (Proxmox init + VM/LXC creation + K3s install)
just homelab-build

# Destroy everything (VMs, Containers, and VM templates)
just homelab-reset
```

## Main Playbooks

- `main.yaml`: The primary entry point. It triggers the entire lifecycle: Proxmox init, image customization, VM/LXC creation, user configuration, and K3s installation.
- `configure-ssh.yaml`: Used for the initial SSH key exchange with the Proxmox host.
- `destroy.yaml`: Orchestrates the destruction of the environment to return to a clean state.
- `save-data.yaml`: Handles backups of critical data (e.g., AdGuardHome configurations) to your local machine.

## Structure
- `roles/`: Contains modular tasks for each part of the infrastructure (e.g., `proxmox-create-vms`, `kubernetes-install-masters`).
- `library/`: Custom Ansible modules (e.g., `ssh_copy_key.py`).
- `callback_plugins/`: Custom plugins for better output formatting.
