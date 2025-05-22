
SHELL := /bin/bash

# Variables
MY_CONFIG_FILES = "config-files/my-configs"


##############################################################################################################
# INITIAL CONFIGURATION
init:
	@cd scripts && ./check_dependencies.sh
	@ansible-galaxy install -r src/requirements.yml
	@cd src && ansible-playbook --ask-become-pass -i hosts.yaml configure-ssh.yaml


# Command to copy config-files/sample folder, to you fill yours settings
init-config-files:
	@test ! -d ${MY_CONFIG_FILES} && cp -rv config-files/sample ${MY_CONFIG_FILES} || echo "folder ${MY_CONFIG_FILES} already exists"

# Command to install all the main config files, from 'config-files/my-configs', to correct place
install-config-files:
	@cp -v "${MY_CONFIG_FILES}/hosts.yaml" src/hosts.yaml


##############################################################################################################
# BACKUP

# Command to make backup files from servers to my localhost
servers-backup:
	@bash scripts/install-scripts-dependencies.sh && clear
	@python3 scripts/servers-backup.py ${SERVERS_HOST_FILE}


##############################################################################################################
# FULL DEPLOY
proxmox-build:
	@cd src && ansible-playbook -i hosts.yaml main.yaml --tags "proxmox-init,deploy-infra"
#	@kubecolor get nodes -o wide --kubeconfig=$${HOME}/.kube/config.k3s

##############################################################################################################
# FULL DESTROY
# proxmox-reset: destroy-infra
proxmox-reset:
	@cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "destroy-infra,reset-proxmox"


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
	@cd src && ansible-playbook -i hosts.yaml main.yaml --tags "deploy-infra"

##############################################################################################################
# DESTROY ONLY INFRA

# Command to destroy all infrastructure
destroy-infra:
	@cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "destroy-infra"



##############################################################################################################
# DEPLOY ONLY K3S
k3s-install:
	@cd src && ansible-playbook -i hosts.yaml main.yaml --tags "k3s-install"


##############################################################################################################
# DESTROY ONLY K3S
k3s-uninstall:
	@cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "k3s-uninstall"