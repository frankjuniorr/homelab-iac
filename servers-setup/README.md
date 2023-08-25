# Servers Setup

Project to install and configure all created servers

## Servers

What this script will make:

- add user to `wheel` group, and add a flag `NOPASSWD` in `/etc/sudoers` file, to remove password when use sudo commando
- add all servers into my `~/.ssh/config` file, here in my localhost, to facilitate future access
- Configure the NFS server, and configure the NFS client in all the others VMs.
- Configure the DNS server, and configure the DNS client in all the others VMs.
- Configure a Kubernetes cluster

## Playbooks

- `servers-setup.yaml`: Principal playbok that configure all this server, except the k8s configuration
- `kubespray-install.yaml`: Individual playbook, that install and configure ONLY the kubespray installation

## Requirements

The `kubespray-install.yaml` playbook uses a new window of `terminator` terminal, to run kubespray installation, so is ncessary:

- terminator

## Configuration Files

- `hosts.yaml`: GENERATED AUTOMATICALLY by terraform code (proxmox/create-vms folder)

## Run

```bash
ansible-playbook -i hosts.yaml servers-setup.yml
ansible-playbook -i hosts.yaml kubespray-install.yml
```