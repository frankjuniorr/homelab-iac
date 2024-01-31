
SHELL := /bin/bash

# Variables
PROXMOX_HOSTS_FILE = "src-deploy/hosts.yaml"
SERVERS_HOST_FILE = "servers-setup/hosts.yaml"
MY_CONFIG_FILES = "config-files/my-configs"

##############################################################################################################
# INITIAL CONFIGURATION

# Command to copy config-files/sample folder, to you fill yours settings
init-config-files:
	@test ! -d ${MY_CONFIG_FILES} && cp -rv config-files/sample ${MY_CONFIG_FILES} || echo "folder ${MY_CONFIG_FILES} already exists"

# Command to install all the main config files, from 'config-files/my-configs', to correct place
install-config-files:
	@cp -v "${MY_CONFIG_FILES}/hosts.yaml" ${PROXMOX_HOSTS_FILE}
	@cp -v "${MY_CONFIG_FILES}/vm_template_config.yaml" proxmox/proxmox-config/group_vars/vm_template_config.yaml
	@cp -v "${MY_CONFIG_FILES}/terraform.tfvars.template" proxmox/create-vms/terraform.tfvars
	@cp -v "${MY_CONFIG_FILES}/dns_and_k3s_config.yaml" servers-setup/group_vars/dns_and_k3s_config.yaml


##############################################################################################################
# BACKUP

# Command to make backup files from servers to my localhost
servers-backup:
	@bash scripts/install-scripts-dependencies.sh && clear
	@python3 scripts/servers-backup.py ${SERVERS_HOST_FILE}


##############################################################################################################
# FULL DEPLOY
proxmox-build:
	@ansible-playbook -i ${PROXMOX_HOSTS_FILE} src-deploy/main.yaml --tags "proxmox-init,deploy-infra"
#	@kubecolor get nodes -o wide --kubeconfig=$${HOME}/.kube/config.k3s

##############################################################################################################
# FULL DESTROY
# proxmox-reset: destroy-infra
proxmox-reset:
	@ansible-playbook -i ${PROXMOX_HOSTS_FILE} src-deploy/reset.yaml --tags "destroy-infra,reset-proxmox"


##############################################################################################################
# DEPLOY ONLY INFRA

# Command to make deploy of all infrastructure on Proxmox.
# basically, this command execute:
#
# - Send ssh public key to root user of Proxmox server
# - Start the playbook to configure Proxmox Server
# - Start the Terraform code to deploy al necessary VMs
# - Start the playbook to configure all VMs
# - Start the playbook that make post-config Proxmox:
#		- Create the NFS Storage
deploy-infra:
	@ansible-playbook -i ${PROXMOX_HOSTS_FILE} src-deploy/main.yaml --tags "deploy-infra"

##############################################################################################################
# DESTROY ONLY INFRA

# Command to destroy all infrastructure
destroy-infra:
	@ansible-playbook -i ${PROXMOX_HOSTS_FILE} src-deploy/reset.yaml --tags "destroy-infra"
