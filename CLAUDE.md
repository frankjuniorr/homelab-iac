# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab IaC is a fully automated Infrastructure-as-Code solution for deploying a reproducible homelab on **Proxmox** using **Ansible** for orchestration, **K3s** for Kubernetes, and **Ubuntu/Rocky Linux** as guest OS.

All entry points go through `just` (the Justfile task runner). Never run `ansible-playbook` directly unless debugging.

## Common Commands

```bash
# First-time setup
just init-hosts        # Copy sample hosts.yaml (once only)
just secrets-keygen    # Generate vault password at ~/.config/homelab-iac/.vault_pass
just secrets-edit      # Edit encrypted hosts.yaml (decrypt → edit → re-encrypt)
just init              # Install hooks + Ansible Galaxy collections + configure SSH

# Deployment
just deploy-homelab    # Full deploy (VMs + LXC + K3s)
just deploy-lxc        # Only LXC containers (DNS/AdGuard, Garage S3)
just deploy-vms        # Only VMs (K3s nodes)
just k3s-install       # Install/update K3s cluster only

# Maintenance
just homelab-update    # Update all OS packages (Proxmox + VMs + LXC)
just homelab-start     # Power on all guests
just homelab-stop      # Gracefully shut down all guests
just backup            # Backup AdGuard → S3 → GDrive
just doctor            # Health check (requires `gum` binary)

# Teardown
just destroy-homelab   # Full teardown
just k3s-uninstall     # Remove K3s only (keep VMs)

# Secrets
just secrets-view      # View decrypted hosts.yaml in terminal
just secrets-encrypt   # Encrypt (run before committing if manually decrypted)
just secrets-decrypt   # Decrypt permanently (use with caution)

# Debugging
just plugin off        # Disable aesthetic plugin to see raw Ansible output
just plugin on         # Re-enable aesthetic plugin
```

## Architecture

```
Justfile → Ansible playbooks (src/) → Proxmox API + SSH
```

- **`src/main.yaml`** — Primary deployment playbook; uses tags to target subsets
- **`src/destroy.yaml`** — Teardown playbook
- **`src/hosts.yaml`** — Encrypted Ansible inventory (Ansible-Vault); source of truth for all host vars
- **`src/roles/`** — Modular roles; each with `tasks/main.yml`, optional `defaults/`, `templates/`, `handlers/`
- **`config-files/sample/hosts.yaml`** — Template with empty placeholders; keep in sync with `src/hosts.yaml` structure

### Infrastructure split
- **VMs** → exclusively K3s cluster nodes
- **LXC containers** → services intentionally outside K8s (AdGuardHome DNS, Garage S3)

### Local files managed by Ansible
The playbooks automatically update on the control node:
- `~/.ssh/config` (via `configure-local-ssh` role)
- `~/.aws/` config and credentials
- `/etc/hosts`
- `~/.kube/config.k3s`

## Ansible Conventions

- **Task names**: always in double quotes, written in English
- **Inventory format**: YAML only — `.ini` format is prohibited
- **Module priority**: always prefer native Ansible modules over `shell`/`command`
- **Idempotency**: all roles must be safe to run multiple times
- **`gather_facts`**: set `false` by default; enable only when needed
- **Tags** for granular runs: `proxmox-init`, `deploy-infra`, `lxc`, `vms`, `k3s-install`, `destroy-infra`, `update-all`, `update-guests`, `update-proxmox`

When adding a new role:
1. Add it to the appropriate play in `src/main.yaml` with correct tags and host group
2. Update `config-files/sample/hosts.yaml` if new host vars are introduced

## Naming Conventions

| Resource | Naming scheme |
|---|---|
| K8s master nodes | Hindu trinity: Indra, Vishnu, Shiva |
| K8s worker nodes | Hindu mythology: Ganesha, Krishna, Lakshmi |
| LXC containers | Solar system planets: Jupiter, Saturn, Neptune |

## Secrets Management

- `src/hosts.yaml` is **always encrypted** in Git — the pre-commit hook blocks unencrypted commits
- Vault password lives at `~/.config/homelab-iac/.vault_pass` (must be `chmod 600`)
- Use `just secrets-edit` for all edits (atomic decrypt/edit/re-encrypt)
- If you manually decrypt, always run `just secrets-encrypt` before committing
- After updating `src/hosts.yaml` structure, mirror changes to `config-files/sample/hosts.yaml` (empty/placeholder values only)

## Gotchas

- **`just doctor`** requires the `gum` binary from [charmbracelet/gum](https://github.com/charmbracelet/gum)
- The **beautiful_output** callback plugin can hide error details — run `just plugin off` when debugging
- **Pre-commit hook** auto-enables the aesthetic plugin and checks vault encryption; run `just install-hooks` after modifying `scripts/pre-commit.sh`
- After any `Justfile` or major architectural change, update both `README.md` and `AGENTS.md`/`GEMINI.md`
