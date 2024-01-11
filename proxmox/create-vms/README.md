# Create Vms

Terraform code to create all necessary servers in a Proxmox server.

## Vms

This code will create some Vms cloning from a VM Template:

- DNS Server
- NFS Server
- k8s-master (1)
- k8s-worker (2)

## Modules

There are two modules in this code:
- `proxmox_vms`: Module to create a specific VM in Proxmox resource
- `generate_template`: Module to create a hosts.yaml file from template

## Configuration files

- `terraform.tfvars`: principal variables file with all variables values.
- `variables.tf`: Just declarations of all variables

## Run this code

Execute:
```bash
make deploy-infra
```

## Output

This code generate a ansible hosts file, with all Servers configurations that were created, and send to `servers-setup` code