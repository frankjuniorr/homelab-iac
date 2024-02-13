# Scripts folder

This folder contains all the necessary auxiliar scripts

## Scripts

- `ssh-copy-to-host`: Auxiliar script to sendo public ssh key to any remote host. This is help ansible code to connect automatically in the remote hosts

## `ssh-copy-to-host` Description
Python script that add my ssh public key (`id_rsa.pub` or another one) into `~/.ssh/authorized_keys` in remote host. This script has the same effect of '`ssh-copy-id`' command.

But, `ssh-copy-id` is interactive (when it ask the user password on terminal). This python code isn't.

So, to solve this interactive problem, this python script check if exist and add "manually" my ssh public key, into `~/.ssh/authorized_keys` of server

## Run
Install dependencies and after, running the codes:
```bash
./install-scripts-dependencies.sh
python3 ssh-copy-to-host.py "proxmox/proxmox-config/hosts.yaml"
```

## How it works (Parameters)
The script receive an `.yaml` file by parameter:

- `ssh-copy-to-host`: This script receive the `proxmox/proxmox-config/hosts.yaml` file, to connect of all hosts in file and send ssh public key.


