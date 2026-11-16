# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab IaC is a fully automated Infrastructure-as-Code solution for deploying a reproducible homelab on **Proxmox** using **Ansible** for orchestration and **Ubuntu** as guest OS.

**Current scope = Phase 1 (Foundation)** of the expansion plan: one Docker VM (`netuno`) running docker-compose stacks (AdGuard, Tailscale, Duplicati — deployed by `homelab-deploys`), one Home Assistant OS VM (`terra`). There are no LXC containers, no Garage S3, no rclone and no PostgreSQL in this phase: backup is Duplicati (in `homelab-deploys`) plus the Proxmox `vzdump`. **Kubernetes/K3s is paused** (planned for a later phase) and its code was removed; later phases (PostgreSQL/Garage consolidation into compose, user apps, media/cloud, K8s + GitOps, monitoring) are re-introduced into the code gradually, one phase at a time. Do not re-add code for phases that are not being implemented.

All entry points go through `just` (the Justfile task runner). Never run `ansible-playbook` directly unless debugging.

## Common Commands

```bash
# First-time setup
just init-hosts        # Copy sample hosts.yaml (once only)
just secrets-keygen    # Generate vault password at ~/.config/homelab-iac/.vault_pass
just secrets-edit      # Edit encrypted hosts.yaml (decrypt → edit → re-encrypt)
just init              # Install hooks + Ansible Galaxy collections + configure SSH

# Deployment
just deploy-homelab    # Full deploy (VMs netuno/terra + weekly vzdump job)
just deploy-vms        # Only VMs (netuno Docker host + terra Home Assistant OS)
# Then, in homelab-deploys: `just deploy-stacks` brings up AdGuard/Tailscale/Duplicati on netuno

# Maintenance
just homelab-update    # Update all OS packages (Proxmox + VMs)
just homelab-start     # Power on all guests
just homelab-stop      # Gracefully shut down all guests
just doctor            # Health check (requires `gum` binary)

# Teardown
just destroy-homelab   # Full teardown

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
- **VM `netuno`** (inventory key `docker`, `192.168.1.51`) → Docker Engine + Compose host, role `docker-host`. Hosts the AdGuard (DNS), Tailscale (subnet router) and Duplicati (backup) stacks, which live in `homelab-deploys`. The IP `.51` is deliberately the LAN's DNS address, so router/DHCP and Tailscale split-DNS don't change.
- **VM `terra`** (inventory key `haos`) → Home Assistant OS. Not Ubuntu, no cloud-init: it boots from the official HAOS qcow2 (OVMF + q35), created in `create-proxmox-vms/tasks/4-provision-haos.yml`. HAOS gets its IP by DHCP: reserve the IP in the router (or set it with `ha network update`), then keep `haos_ip` in `homelab-deploys` in sync for the `ha.<domain>` DNS rewrite.
- **No LXC containers in this phase** (PostgreSQL, Garage S3 and rclone are not part of Phase 1; PostgreSQL returns in Phase 2 as a compose stack).
- **Inventory groups:** `docker_hosts`, `haos_hosts`, `ubuntu_vms` (cloud-init clones; get guest-OS config), `vms_all` (all VMs, used by power/destroy/notes).

### Local files managed by Ansible
The playbooks automatically update on the control node:
- `~/.ssh/config` (via `configure-local-ssh` role)
- `/etc/hosts`

## Ansible Conventions

- **Task names**: always in double quotes, written in English
- **Inventory format**: YAML only — `.ini` format is prohibited
- **Module priority**: always prefer native Ansible modules over `shell`/`command`
- **Idempotency**: all roles must be safe to run multiple times
- **`gather_facts`**: set `false` by default; enable only when needed
- **Tags** for granular runs: `proxmox-init`, `deploy-infra`, `vms`, `vzdump`, `docker`, `destroy-infra`, `update-all`, `update-guests`, `update-proxmox`

When adding a new role:
1. Add it to the appropriate play in `src/main.yaml` with correct tags and host group
2. Update `config-files/sample/hosts.yaml` if new host vars are introduced

## Naming Conventions

| Resource | Naming scheme |
|---|---|
| Service VMs and LXC containers (`netuno`, `terra`) | Solar system planets (in Portuguese): `netuno` (Docker VM), `terra` (Home Assistant). Free: `mercurio`, `venus`, `marte`, `jupiter`, `saturno`, `urano` |
| K8s nodes (future phase) | masters: major Hindu gods (Indra, Brahma, Varuna); workers: minor Hindu gods (Ganesha, Lakshmi, Krishna) |

Inventory keys are role names (`docker`, `haos`); the planet goes in `proxmox_vm_name`. Never name the Docker VM's Linux user `docker` (clashes with the `docker` group).

## Secrets Management

- `src/hosts.yaml` is **always encrypted** in Git — the pre-commit hook blocks unencrypted commits
- Vault password lives at `~/.config/homelab-iac/.vault_pass` (must be `chmod 600`)
- Use `just secrets-edit` for interactive edits (atomic decrypt/edit/re-encrypt)
- For programmatic edits (e.g. by Claude Code): run `just secrets-decrypt`, edit the file, then `just secrets-encrypt`
- If you manually decrypt, always run `just secrets-encrypt` before committing
- After updating `src/hosts.yaml` structure, mirror changes to `config-files/sample/hosts.yaml` (empty/placeholder values only)

## Agent & Skill Usage

**MUST use the appropriate skill or agent before writing code manually.** This is non-negotiable for the tasks below.

### Skills (invoke via `/skill-name`)

| Task | Skill | When to invoke |
|---|---|---|
| Write or improve Ansible roles/playbooks | `/ansible-expert` | Any new role, task file, or handler change |
| Docker, CI/CD, K8s manifests, IaC templates | `/devops-engineer` | Dockerfiles, GitHub Actions, Helm charts |
| Infrastructure architecture, deployment strategy | `/devops-infrastructure` | Design decisions, new service topology |
| GitHub CLI operations (PRs, issues, releases) | `/gh-cli` | Any `gh` command or GitHub API interaction |
| Create a git commit with conventional message | `/git-commit` | Every commit — do not write commit messages manually |
| Refactor existing roles or tasks | `/refactor` | When restructuring without changing behavior |
| Review changed code for quality/efficiency | `/simplify` | After implementing a feature or fix |
| Update or audit this CLAUDE.md | `/claude-md-improver` | When CLAUDE.md needs changes |
| Arch Linux system issues | `/arch-linux-triage` | Any host-level Linux/systemd issue |

### Agents (spawn via `Agent` tool)

Use the appropriate specialized agent instead of doing open-ended research inline:

| Scenario | Agent type |
|---|---|
| Explore codebase, find files/patterns, answer "how does X work?" | `Explore` |
| Plan implementation strategy before touching code | `Plan` |
| Any git/GitHub operation: branching, rebases, PRs | `git-specialist` |
| Linux/systemd failures, pacman, disk, network on hosts | `linux-specialist` |
| Cross-layer homelab issues (Proxmox + Docker host + networking + backups) | `homelab-troubleshooter` |
| **Backup/recovery verification** (Duplicati, vzdump, restore flow) | `homelab-troubleshooter` |
| Questions about Claude Code features, API, SDK | `claude-code-guide` |

**Rules:**
- Run independent agent tasks in parallel when possible (single message, multiple `Agent` calls)
- Delegate open-ended codebase searches to `Explore` rather than chaining Glob/Grep manually
- Always use `git-specialist` for anything beyond `git status` / `git diff`

## Backup & Recovery Troubleshooting

**Invoke the `homelab-troubleshooter` agent** for any backup/recovery investigation — all commands, cron checks, vzdump/Duplicati verification, and known failure patterns are documented there.

### Backup layers (Phase 1)

| What | How | Where |
|---|---|---|
| `netuno` volumes (`/opt/stacks/*/data`) + HA backups | **Duplicati** (encrypted, versioned, off-site) | configured in `homelab-deploys` (manual job in the UI + restore test) |
| VMs `netuno`, `terra` (whole guest) | Proxmox `vzdump`, role `proxmox-backup-jobs`, job `homelab-weekly` (Sundays 03:00, `snapshot` + `zstd`, keeps last 3, storage `local`) | Proxmox host |

The vzdump storage defaults to `local` (same Proxmox host): point it to an external destination in a later step if you need protection against host loss.

## Gotchas

- **`just doctor`** requires the `gum` binary from [charmbracelet/gum](https://github.com/charmbracelet/gum)
- The **beautiful_output** callback plugin can hide error details — run `just plugin off` when debugging
- **Pre-commit hook** auto-enables the aesthetic plugin and checks vault encryption; run `just install-hooks` after modifying `scripts/pre-commit.sh`
- After any `Justfile` or major architectural change, update `README.md` (the only other doc besides this file)
- **Port 53 on `netuno`**: `systemd-resolved` must not hold it; the `docker-host` role disables the stub listener before AdGuard starts. Deploy order matters: AdGuard (DNS) before HAOS rewrite and Tailscale split-DNS
- **HAOS image version** is pinned in `roles/create-proxmox-vms/defaults/main.yml` (`haos_version`); check the release exists before changing it
- The cloud-init template (ID 900) is deleted at the end of `just deploy-homelab` (post-deploy play)
