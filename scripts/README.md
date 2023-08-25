# Scripts folder

This folder contains all the necessary auxiliar scripts

## Scripts

- `servers-backup`: Script to backup config files of servers. Currently works only with `pihole` files
- `ssh-copy-to-host`: Auxiliar script to sendo public ssh key to any remote host. This is help ansible code to connect automatically in the remote hosts

## `ssh-copy-to-host` Description
Python script that add my ssh public key (`id_rsa.pub` or another one) into `~/.ssh/authorized_keys` in remote host. This script has the same effect of '`ssh-copy-id`' command.

But, `ssh-copy-id` is interactive (when it ask the user password on terminal). This python code isn't.

So, to solve this interactive problem, this python script check if exist and add "manually" my ssh public key, into `~/.ssh/authorized_keys` of server

## `servers-backup` Description
Python script that generate and donwload backup files from servers to my localhost.

Currently, this script only works to backup file of:
- pihole

## Run
Install dependencies and after, running the codes:
```bash
./install-scripts-dependencies.sh

python3 servers-backup.py "servers-setup/hosts.yaml"
# or
python3 ssh-copy-to-host.py "proxmox/proxmox-config/hosts.yaml"
```

## How it works (Parameters)
The both script receive an `.yaml` file by parameter:

- `servers-backup`: This script receive the `servers-setup/hosts.yaml` file, to connect the remote pihole host, generate backup, and donwload it to my localhost
- `ssh-copy-to-host`: This script receive the `proxmox/proxmox-config/hosts.yaml` file, to connect of all hosts in file and send ssh public key.


