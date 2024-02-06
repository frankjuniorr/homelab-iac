# Proxmox Config

## Description
Project to make initial configuration on Proxmox and create all the environment.

This project is responsable to:

- Create user in Proxmox and generate APi Token (this user will be used by terraform code)
- Donwload and customize Cloud Image **Rocky Linux 8**
- Create a Cloud Init Template Vm on Proxmox

## Troubleshooting
First of all, I had to made some modifications **manually**:

### 1. [ERROR] `apt-get update` with error:
I need to comments two repositories in Proxmox, relative of a enterprise version on it.

So, a comment the content of this files:
- `/etc/apt/sources.list.d/ceph.list`
- `/etc/apt/sources.list.d/pve-enterprise.list`

### 2. [Improvment] Remove the pop-up "No Valid Subscription"

![alt Proxmox pop-up no valid subscription](images/proxmox-no-valid-subscription.png "Proxmox pop-up no valid subscription")

This modification is not necessary, is only improvment, to hide this pop-up in every login.
So, just do this:

open the correct file like the example, and search for this peace of code:
```javascript
if (res === null || res === undefined || !res || res
.data.status.toLowerCase() !== 'active') {
    // The pop-up show here
}
```

so, make this change
```javascript
if (false) {
    // The pop-up show here
}
```

The full code:
```bash
# install vim
apt-get update && apt-get install vim -y && export EDITOR=vim

# create a backup of a file:
cd /usr/share/javascript/proxmox-widget-toolkit
cp proxmoxlib.js proxmoxlib.js.bkp
vim proxmoxlib.js

# restart service
systemctl restart pveproxy.service
```

## Run the code

Review the files `hosts.yaml`,  `group_vars/all.yaml` and `group_vars/vm_template_config.yaml`

```bash

# full deploy
make proxmox-build

# or

# to full destroy
make proxmox-reset
```

## Output
This code generate a credentials proxmox file, and send to terraform code in `create-vms/modules/proxmox_vms` called `proxmox-variables.tfvars`

## Playbooks

Here in code have 3 playbooks files, that are triggered in different moments:
Take a look in Makefile

- `main.yaml`: principal playbook that make all this things and run the initial proxmox configure
- `proxmox-post-config.yaml`: Playbook to run **after** Terraform code (`create-vms` folder) to finalizing the configurations in Proxmox.
- `reset-nfs.yaml`: PLaybok to reset NFS storage on Proxmox.
- `reset.yaml`: Playbook that undo all configurations.