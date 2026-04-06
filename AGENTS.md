# AGENTS.md — Homelab IaC

> Infrastructure-as-Code for a reproducible homelab on Proxmox, using Ansible + K3s.

## Quick Reference

| Action | Command |
|--------|---------|
| Init environment | `just init-hosts` → `just secrets-keygen` → `just secrets-edit` → `just init` |
| Full deploy | `just deploy-homelab` |
| Deploy LXC only | `just deploy-lxc` |
| Deploy VMs only | `just deploy-vms` |
| Install K3s | `just k3s-install` |
| Full update | `just homelab-update` |
| Power on/off | `just homelab-start` / `just homelab-stop` |
| Health check | `just doctor` |
| Destroy all | `just destroy-homelab` |
| Edit secrets | `just secrets-edit` |
| View secrets | `just secrets-view` |
| Toggle output plugin | `just plugin on` / `just plugin off` |

## Technology Stack

- **Orchestration:** Ansible (playbooks, roles, collections)
- **Virtualization:** Proxmox VE (VMs and LXC containers)
- **Guest OS:** Ubuntu (Cloud-Init with Rocky Linux base image)
- **Kubernetes:** K3s cluster (masters + workers)
- **Task Runner:** `just` (see `Justfile`)
- **Secrets:** Ansible-Vault (`~/.config/homelab-iac/.vault_pass`)
- **Networking:** AdGuardHome (DNS), Garage S3 (storage), rclone (backups)

## Directory Structure

```
├── Justfile                        # Task runner — all entry points
├── scripts/
│   ├── check_dependencies.sh       # Dependency installer (host packages)
│   ├── doctor.sh                   # Health check (requires `gum`)
│   ├── pre-commit.sh               # Git hook — vault encryption + plugin check
│   ├── s3-manager.sh               # Interactive garage bucket management
│   └── image-tools/
│       └── process_icons.py        # Icon processing for VM notes
├── src/
│   ├── ansible.cfg                 # Ansible config (beautiful_output plugin enabled)
│   ├── main.yaml                   # Main deployment playbook
│   ├── destroy.yaml                # Infrastructure teardown playbook
│   ├── backup-recovery.yaml        # Backup and recovery
│   ├── update-os.yaml              # System updates playbook
│   ├── power-management.yaml       # Start/stop all hosts
│   ├── hosts.yaml                  # Encrypted inventory (Ansible-Vault)
│   ├── requirements.yml            # Ansible collections: ansible.posix, community.proxmox
│   ├── roles/                      # Modular Ansible roles
│   ├── callback_plugins/
│   │   └── beautiful_output.py     # Custom output formatter
│   ├── library/
│   │   └── ssh_copy_key.py         # Custom Ansible module
│   └── group_vars/
│       └── all.yml                 # Group-level variables
└── config-files/
    └── sample/
        └── hosts.yaml              # Inventory template with empty placeholders
```

## Roles Summary

### Proxmox Infrastructure
- **`proxmox-create-containers`** — Creates LXC containers (DNS, S3)
- **`create-proxmox-vms`** — Orchestrates cloud image prep → VM template creation → VM provisioning for K3s nodes
- **`proxmox-power-management`** — Start/stop all hosts
- **`proxmox-reset`** — Cleanup/reset tasks

### Guest OS Configuration
- **`configure-guest-os`** — Base OS setup: packages, users, sudoers, MOTD
- **`configure-remote-ssh`** — SSH access setup for remote hosts
- **`configure-local-ssh`** — Configures `~/.ssh/config` and `~/.ssh/servers/*.conf` on localhost
- **`dns-client`** — Resolv.conf templating on guests
- **`dns-server`** — AdGuardHome installation and configuration
- **`garage-s3`** — Garage S3 storage server setup
- **`rclone`** — Backup scripts: AdGuard→S3, S3→GDrive, with cron and logrotate

### Kubernetes
- **`kubernetes-install-masters`** — K3s server installation on master nodes
- **`kubernetes-install-nodes`** — K3s agent installation on worker nodes
- **`kubernetes-uninstall`** — K3s removal from all nodes
- **`kubernetes-firewall`** — Opens port 6443 on cluster nodes

### Maintenance
- **`update-os`** — OS package updates (Proxmox + guests)
- **`update-proxmox`** — Proxmox host updates only
- **`manage-remote-backups`** — Remote backup execution before destroy
- **`clean-local-files`** — Cleanup local SSH configs and fingerprints
- **`proxmox-write-notes`** — VM documentation notes in Proxmox UI

## Key Conventions

### Ansible
- **All task names** in double quotes, written in English
- **Inventory** is YAML (`.yaml`), `.ini` format is prohibited
- **Tags** enable granular execution: `proxmox-init`, `deploy-infra`, `lxc`, `vms`, `k3s-install`, `destroy-infra`, `update-all`, `update-guests`, `update-proxmox`
- **Roles are modular** — each role has `tasks/main.yml` and optional `defaults/`, `templates/`, `handlers/`, `files/`
- **Idempotency is mandatory** — roles must be safe to run multiple times
- **Prioritize native Ansible modules** over `shell`/`command`
- **`gather_facts`** is set to `false` by default; enabled only when needed

### Naming
- **K8s Masters:** Hindu trinity names (Indra, Vishnu, Shiva)
- **K8s Workers:** Hindu mythology figures (Ganesha, Krishna, Lakshmi)
- **LXC Containers:** Planet names (e.g., Jupiter for S3, Saturn for DNS)

### Secrets
- `src/hosts.yaml` is **always encrypted** in Git with Ansible-Vault
- Never hardcode secrets — use Vault variables
- Password stored at `~/.config/homelab-iac/.vault_pass`
- Run `just secrets-edit` to safely edit encrypted file
- Pre-commit hook **blocks unencrypted commits**

### Garage S3
- The `garage_buckets` array in `src/roles/garage-s3/defaults/main.yaml` is source of truth
- Ansible creates missing buckets AND deletes buckets not in this array

## Inventory Groups

```
proxmox_nodes        → proxmox
dns_server_hosts     → dns
garage_hosts         → s3
containers_lxc       → dns, s3
k8s_masters_nodes    → k8s-master
k8s_worker_nodes     → k8s-worker-1, k8s-worker-2
k8s_cluster          → all k8s masters + workers
vms_all              → all VMs (k8s_cluster)
```

## Running Commands

All commands go through `just`. The command template is:
```
cd src && ansible-playbook -i src/hosts.yaml --vault-password-file ~/.config/homelab-iac/.vault_pass <playbook> --tags <tag>
```

### When adding new roles or features:
1. Add the role to the appropriate play in `src/main.yaml` with corresponding tags
2. Ensure the role follows the modular directory structure
3. Update `config-files/sample/hosts.yaml` if new host vars are needed
4. Run `just doctor` to verify nothing broke
5. Run `just install-hooks` after modifying `scripts/pre-commit.sh`

### Remote Access
- SSH to hosts: `ssh <hostname> "command"` (config managed by configure-local-ssh role)
- Hostnames: `proxmox`, `dns`, `s3`, `k8s-master`, `k8s-worker-1`, `k8s-worker-2`
- Kubeconfig: `kubectl --kubeconfig ~/.kube/config.k3s`

## Gotchas

- **`doctor.sh` requires `gum`** — install from https://github.com/charmbracelet/gum
- The **custom callback plugin** (`beautiful_output.py`) can obscure errors — disable with `just plugin off` for debugging
- **Pre-commit hook** auto-enables the aesthetic plugin and checks vault encryption
- **Cloud-Init uses Rocky Linux base** despite the variable names saying "ubuntu" (see `ubuntu_cloud_image_url` in `hosts.yaml`)
- **Vault password file** must exist at `~/.config/homelab-iac/.vault_pass` with `chmod 600`
- After editing `src/hosts.yaml`, **always encrypt before committing**: `just secrets-encrypt`
