# Servers Setup

Project to install and configure all created servers

## Servers

What this script will make:

- add user to `wheel` group, and add a flag `NOPASSWD` in `/etc/sudoers` file, to remove password when use sudo commando
- Include all servers in my `~/.ssh/config` file on my localhost for easier access in the future.
- Configure the NFS server, and configure the NFS client in all the others VMs.
- Configure the DNS server, and configure the DNS client in all the others VMs.
- Configure a Kubernetes cluster

## Playbooks

- `servers-setup.yaml`: Principal playbok that configure all this server, except the k8s configuration
- `k3s-install.yaml`: Individual playbook, that install and configure ONLY the k3s installation

## Configuration Files

- `hosts.yaml`: GENERATED AUTOMATICALLY by terraform code (proxmox/create-vms folder)

## Run

```bash
make deploy-infra

# or

make destroy-infra
```