# GEMINI.md - Homelab IaC

This document serves as the foundational mandate for Gemini CLI when working on the **Homelab IaC** project. It outlines the project's architecture, conventions, and operational guidelines.


## Project Overview

**Homelab IaC** is a fully automated Infrastructure-as-Code (IaC) solution for deploying and managing a reproducible homelab on **Proxmox**. It leverages Ansible for orchestration, K3s for Kubernetes, and Rocky Linux as the primary guest OS.

This project is part of a larger initiative of mine to build a homelab. In this case, this repository is responsible for creating the infrastructure based on Proxmox. This repository is also available on GitHub, and the link is: https://github.com/frankjuniorr/homelab-iac

### Key Technologies:
- **Orchestration:** Ansible (Playbooks, Roles, Collections).
- **Virtualization:** Proxmox VE (VMs and LXC Containers).
- **Guest OS:** Rocky Linux (Cloud-Init for VMs).
- **Kubernetes:** K3s cluster (Masters and Workers).
- **Task Runner:** Just (via `Justfile`).
- **Secret Management:** 1Password CLI (`op`).
- **Networking:** DNS Client/Server configuration.

---

## Architecture & Structure

### Directory Layout
- `src/`: Core Ansible project.
    - `roles/`: Modular tasks for infrastructure components.
    - `library/`: Custom Ansible modules (e.g., `ssh_copy_key.py`).
    - `callback_plugins/`: Custom output formatting (e.g., `beautiful_output.py`).
    - `main.yaml`: Primary deployment playbook.
    - `reset.yaml`: Infrastructure cleanup playbook.
- `config-files/`: Configuration templates and user-specific `hosts.yaml`.
- `Justfile`: Entry point for all automation tasks.
- `scripts/`: Auxiliary scripts.

### Logic Flow
1. **Control Node:** Runs `just` commands which execute Ansible playbooks.
2. **Proxmox Host:** Target for VM/LXC creation and management via API and SSH.
3. **Guest Nodes:** Provisioned with Rocky Linux, then configured via Ansible for specific roles (DNS, K3s, etc.).
4. VMs in Proxmox: These are exclusively intended for the Kubernetes cluster (k3s)
5. LXC Containers: These are intended for services that are intentionally run outside the Kubernetes cluster (k3s) (e.g., AdGuard)

---

## Core Mandates & Conventions

### 0. Security First
- **Credential Protection:** NEVER log, print, or commit secrets, API keys, or sensitive credentials. 
- **Secret Management:** Always use SOPS for sensitive files that MUST be in Git (like `src/hosts.yaml`).
- **Git Hygiene:** Ensure that all non-encrypted sensitive data, `.env` files, and local configurations are strictly excluded via `.gitignore`.
- **Pre-commit Validation:** Always ensure that sensitive files are encrypted before committing.

### 1. Tooling First
- **Always use `just`** for common tasks (init, build, reset, save-data, update).
- Avoid running `ansible-playbook` directly unless a specific subset of tasks or debugging is required.

### 2. Secret Management (SOPS + age)
- **Never hardcode secrets.** Use SOPS for `src/hosts.yaml` with `age` keys.
- **Hosts File Management:** ALWAYS use `just secrets-decrypt` before editing and `just secrets-encrypt` after editing `src/hosts.yaml`. NEVER leave the file decrypted in the repository.
- **Sync Sample:** Whenever `src/hosts.yaml` is updated, you MUST also update `config-files/sample/hosts.yaml` with the same structure (but empty/placeholder values) to keep it in sync.
- Ensure the public key is configured in `.sops.yaml` (if applicable) and the private key remains in `~/.config/sops/age/keys.txt`.
- For editing, you can also use `just secrets-edit`.

### 3. Ansible Best Practices
- **Roles:** Keep logic modular within `src/roles/`.
- **Tags:** Rigorously use tags (`proxmox-init`, `deploy-infra`, `k3s-install`, `destroy-infra`, `update-all`) to allow granular execution.
- **Idempotency:** ALWAYS ensure all roles and tasks are idempotent. Idempotency is a core requirement; tasks must be designed to be safe to run multiple times without causing errors or unnecessary changes.
- **OS Support:** Focus on Rocky Linux compatibility for guests and Debian for Proxmox nodes.

### 4. Configuration
- The source of truth for inventory is `src/hosts.yaml` (managed via SOPS).
- Template files should use `.j2` extension and reside in role `templates/` folders.
- **Garage Buckets:** The array `garage_buckets` in `src/roles/garage-s3/defaults/main.yaml` is the source of truth for S3 buckets. Ansible will create missing buckets AND delete any buckets not present in this array.


### 5. Naming
- Kubernetes VMs - Master Nodes: Every VM that is part of the Kubernetes cluster is named after a Hindu mythology deity. The Kubernetes master nodes are named after the main Hindu trinity: Brahma, Vishnu, Shiva.
- Kubernetes VMs - Worker Nodes: The worker VMs in the Kubernetes cluster are also named after figures from Hindu mythology, but from a lower tier in the hierarchy of deities. Examples: Ganesha, Krishna, Lakshmi.
- LXC Containers - Services outside the cluster: For LXC containers that run outside the Kubernetes cluster, I use names of planets from the Solar System, e.g., Saturn, Jupiter, Neptune, Pluto.

---

## Common Workflows

### Initial Setup
1. `just init-hosts`: Initialize the `src/hosts.sops.yaml` file from sample.
2. `just secrets-keygen`: Generate age keys for SOPS.
3. `just secrets-edit`: Configure your infrastructure secrets.
4. `just init`: Install dependencies and configure initial Proxmox SSH access.

### Infrastructure Deployment
- `just homelab-build`: Full infrastructure deployment (VMs + Containers + K3s).
- `just deploy-infra`: Provision VMs/Containers and configure basic services.
- `just k3s-install`: Specifically install or update the K3s cluster.

### Cleanup & Maintenance
- `just homelab-reset`: Full teardown of the environment.
- `just save-data`: Backup critical application data from nodes to localhost.

### Maintenance & Updates
- `just homelab-update`: Full system update (Proxmox nodes + VMs + Containers).
- `just homelab-update-guests`: Update only the guest VMs and LXC containers (Rocky Linux).
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

## Development Guidelines for Gemini
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
