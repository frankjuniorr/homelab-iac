# GEMINI.md - Homelab IaC

This document serves as the foundational mandate for Gemini CLI when working on the **Homelab IaC** project. It outlines the project's architecture, conventions, and operational guidelines.


## Project Overview

**Homelab IaC** is a fully automated Infrastructure-as-Code (IaC) solution for deploying and managing a reproducible homelab on **Proxmox**. It leverages Ansible for orchestration, K3s for Kubernetes, and Ubuntu as the primary guest OS.

This project is part of a larger initiative of mine to build a homelab. In this case, this repository is responsible for creating the infrastructure based on Proxmox. This repository is also available on GitHub, and the link is: https://github.com/frankjuniorr/homelab-iac

### Key Technologies:
- **Orchestration:** Ansible (Playbooks, Roles, Collections).
- **Virtualization:** Proxmox VE (VMs and LXC Containers).
- **Guest OS:** Ubuntu (Cloud-Init for VMs).
- **Kubernetes:** K3s cluster (Masters and Workers).
- **Task Runner:** Just (via `Justfile`).
- **Secret Management:** Ansible-Vault via `~/.config/homelab-iac/.vault_pass`.
- **Networking:** DNS Client/Server configuration.

---

## Architecture & Structure

### Directory Layout
- `src/`: Core Ansible project.
    - `roles/`: Modular tasks for infrastructure components.
    - `library/`: Custom Ansible modules (e.g., `ssh_copy_key.py`).
    - `callback_plugins/`: Custom output formatting (e.g., `beautiful_output.py`).
    - `main.yaml`: Primary deployment playbook.
    - `destroy.yaml`: Infrastructure cleanup playbook.
- `config-files/`: Configuration templates and user-specific `hosts.yaml`.
- `Justfile`: Entry point for all automation tasks.
- `scripts/`: Auxiliary scripts.

### Logic Flow
1. **Control Node:** Runs `just` commands which execute Ansible playbooks.
2. **Proxmox Host:** Target for VM/LXC creation and management via API and SSH.
3. **Guest Nodes:** Provisioned with Ubuntu, then configured via Ansible for specific roles (DNS, K3s, etc.).
4. VMs in Proxmox: These are exclusively intended for the Kubernetes cluster (k3s)
5. LXC Containers: These are intended for services that are intentionally run outside the Kubernetes cluster (k3s) (e.g., AdGuard)

---

## Core Mandates & Conventions

### 0. Security First
- **Credential Protection:** NEVER log, print, or commit secrets, API keys, or sensitive credentials.
- **Secret Management:** Always use Ansible-Vault for `src/hosts.yaml` (`$ANSIBLE_VAULT` header must be present before any commit).
- **Git Hygiene:** Ensure that all non-encrypted sensitive data, `.env` files, and local configurations are strictly excluded via `.gitignore`.
- **Pre-commit Validation:** Always ensure that sensitive files are encrypted before committing.

### 1. Tooling First
- **Always use `just`** for common tasks (init, build, reset, save-data, update).
- Avoid running `ansible-playbook` directly unless a specific subset of tasks or debugging is required.

### 2. Secret Management (Ansible-Vault)
- **Never hardcode secrets.** All sensitive data in `src/hosts.yaml` is encrypted with Ansible-Vault.
- **Vault Password:** Stored at `~/.config/homelab-iac/.vault_pass` (permissions `600`). NEVER commit this file.
- **Hosts File Management:** ALWAYS use `just secrets-edit` to open the encrypted file in your editor (decrypt → edit → re-encrypt atomically). Alternatively, use `just secrets-decrypt` to decrypt manually, then ALWAYS run `just secrets-encrypt` before committing. NEVER leave the file decrypted in the repository.
- **Sync Sample:** Whenever `src/hosts.yaml` is updated, you MUST also update `config-files/sample/hosts.yaml` with the same structure (but empty/placeholder values) to keep it in sync.

### 3. Ansible Best Practices
- **Roles:** Keep logic modular within `src/roles/`.
- **Module Prioritization:** ALWAYS prioritize native Ansible modules over the `shell` or `command` modules. Only use `shell` when a specialized module does not exist or cannot fulfill the task's requirements.
- **Task Naming:** The `name` field of every Ansible task MUST be enclosed in double quotes and written in English.
- **Inventory Format:** Inventory files MUST always be written in `.yaml` format. The use of the legacy `.ini` format is strictly prohibited.
- **Tags:** Rigorously use tags (`proxmox-init`, `deploy-infra`, `k3s-install`, `destroy-infra`, `update-all`) to allow granular execution.
- **Idempotency:** ALWAYS ensure all roles and tasks are idempotent. Idempotency is a core requirement; tasks must be designed to be safe to run multiple times without causing errors or unnecessary changes.
- **OS Support:** Focus on Ubuntu compatibility for guests and Debian for Proxmox nodes.

### 4. Configuration
- The source of truth for inventory is `src/hosts.yaml` (encrypted with Ansible-Vault).
- Template files should use `.j2` extension and reside in role `templates/` folders.
- **Garage Buckets:** The array `garage_buckets` in `src/roles/garage-s3/defaults/main.yaml` is used to provision base buckets. Ansible will create missing buckets from this list, but it will NOT delete buckets that are not present in this array (allowing for standalone bucket creation).


### 5. Naming
- Kubernetes VMs - Master Nodes: Every VM that is part of the Kubernetes cluster is named after a Hindu mythology deity. The Kubernetes master nodes are named after the main Hindu trinity: Brahma, Vishnu, Shiva.
- Kubernetes VMs - Worker Nodes: The worker VMs in the Kubernetes cluster are also named after figures from Hindu mythology, but from a lower tier in the hierarchy of deities. Examples: Ganesha, Krishna, Lakshmi.
- LXC Containers - Services outside the cluster: For LXC containers that run outside the Kubernetes cluster, I use names of planets from the Solar System, e.g., Saturn, Jupiter, Neptune, Pluto.

---

## Common Workflows

### Initial Setup
1. `just init-hosts`: Initialize the `src/hosts.yaml` file from sample template.
2. `just secrets-keygen`: Generate the Ansible-Vault password file at `~/.config/homelab-iac/.vault_pass`.
3. `just secrets-edit`: Configure your infrastructure secrets.
4. `just init`: Install git hooks, Ansible Galaxy collections, and configure initial Proxmox SSH access.

### Infrastructure Deployment
- `just deploy-homelab`: Full infrastructure deployment (VMs + Containers + K3s).
- `just deploy-infra`: Provision VMs/Containers and configure basic services.
- `just deploy-lxc`: Provisions and configures only the LXC Containers (DNS, S3).
- `just deploy-vms`: Provisions and configures only the Virtual Machines (K3s).
- `just k3s-install`: Specifically install or update the K3s cluster.

### Cleanup & Maintenance
- `just destroy-homelab`: Full teardown of the environment.
- `just backup`: Backup critical application data from nodes to remote S3/GDrive.

### Maintenance & Updates
- `just homelab-update`: Full system update (Proxmox nodes + VMs + Containers).
- `just homelab-update-guests`: Update only the guest VMs and LXC containers (Ubuntu).
- `just homelab-update-proxmox`: Update only the Proxmox host nodes (Debian).

### Power Management
- just homelab-start: Turn on all hosts (Containers LXC and VMs)
- just homelab-stop: Shutdown all hosts (Containers LXC and VMs)

### Utils
- just plugin <state>: Turn ON/OFF the aesthetic plugin

---

## Debugging & Troubleshooting
- **Aesthetic Plugin:** For better debugging and visibility into exact Ansible errors, it is RECOMMENDED to disable the aesthetic plugin by running `just plugin off`. Once the issue is resolved, you can reactivate it using `just plugin on`.

---

## VM Management (Refactoring)

### Consolidated Role: `create-proxmox-vms`
To improve maintainability and reduce redundancy, the following roles were consolidated into a single orchestrator:
- `proxmox-customize-rocky-linux-cloud-image` -> `tasks/1-prepare-image.yml`
- `proxmox-create-cloud-init-vm-template` -> `tasks/2-create-template.yml`
- `proxmox-create-vms` -> `tasks/3-provision-vms.yml`

### Consolidated Role: `configure-guest-os`
A unified role to configure the internal operating system for both VMs and Containers:
- Replaced the old `configure_container.sh.j2` shell script and `configure-vm-user` role.
- Handles bootstrapping (Python/DNF), package installation, user management, sudoers, MOTD, and base services.
- Uses `ansible.builtin.raw` for initial bootstrapping on minimal environments.

**Operational Note:** These roles ensure a consistent and idempotent guest environment across all infrastructure nodes.

---

## Remote Access & Debugging

### SSH Configuration
- The SSH configuration is managed by this project (see `src/roles/configure-local-ssh/`).
- The main config file is `~/.ssh/config`, which includes individual server configurations from `~/.ssh/servers/*.conf`.
- Gemini can use these configurations to connect to any host defined in the inventory.

### Connecting to Hosts
- To execute commands on a remote host, use `ssh <hostname> "<command>"`.
- The hostnames are defined in `src/hosts.yaml` (e.g., `proxmox`, `dns`, `s3`, `k8s-master`).
- **Example:** `ssh dns "systemctl status AdGuardHome"`

### Debugging & Testing
- Use standard Linux tools (`journalctl`, `systemctl`, `df -h`, `ip a`) via SSH to investigate issues on guest nodes.
- For Ansible-specific issues, you can run tasks with increased verbosity if needed, but the primary method for ad-hoc debugging should be direct SSH command execution.
- If a script (like those in `rclone` role) is failing, you can run it manually via SSH to see immediate output: `ssh dns "/bin/bash ~/backups/backup-adguard-to-s3.sh"`

---

## Development Guidelines for Gemini
- **Technical Rationale:** ALWAYS provide a technical explanation of the logic behind any change BEFORE performing it.
- **Proactive Strategy:** If a user request is suboptimal or technically questionable, you MUST provide your professional opinion and suggest a better alternative or strategy before proceeding.
- **Git Hooks:** ALWAYS run `just install-hooks` after modifying `scripts/pre-commit.sh` to ensure the local `.git/hooks/pre-commit` is updated.
- **Documentation Sync:** ALWAYS update `GEMINI.md` and `README.md` when new commands or major changes are added to the `Justfile`.
- **Verification:** When modifying roles, verify against `src/main.yaml` to ensure tags and host groups are correctly targeted.
- **Testing:** New features should include a corresponding role or task in a playbook, ideally verified with a dry-run (`--check`) if applicable.
- **Documentation:** Update `README.md` or role-specific READMEs if architectural changes are made.
- README file: The README file should always be written in English

## 🤖 Model Selection Guidelines
To optimize quota usage and ensure efficiency, follow these prioritization rules:

`gemini-2.5-flash-lite` Model:
Use for: Conceptual doubts, quick explanations, term translations, or "Yes/No" questions.

Triggers: Questions starting with "o que é...", "como funciona...", "Explique...", "Dúvida: ....".
