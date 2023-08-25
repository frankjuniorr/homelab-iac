#!/usr/bin/env python

import yaml
import sys
import paramiko
import os
import datetime


local_home_folder = os.getenv('HOME')
LOCAL_BACKUP_FOLDER = f"{local_home_folder}/Dropbox/development/homelab_data_backup"

ERROR_CODE = 1

def get_parameters():
    hosts_file = None
    try:
        hosts_file = sys.argv[1]
        return hosts_file

    except IndexError:
        print("type a valid hosts.yaml by argument")
        sys.exit(ERROR_CODE)


def get_hosts_from_yaml(hosts_file):
    """
    Function to read yaml file
    """
    if os.path.exists(hosts_file):
        with open(hosts_file, "r") as f:
            data = yaml.safe_load(f)
            hosts = data["all"]["hosts"]
            return hosts
    else:
        print(f"file {hosts_file} not found in current directory")
        sys.exit(1)

def connect_remote_host(host, user, password):
    """
    Function to connect in remote host
    """
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(host, username=user, password=password)
        return client

    except paramiko.AuthenticationException:
        printt("Authentication failed: Check credentials")
        sys.exit(1)


def execute_remote_commands(client, command):
    """
    Function to execute any command in remote host
    """
    stdin, stdout, stderr = client.exec_command(command)
    result = stdout.read().decode().strip()
    return result

def pihole_backup_filename():
    date = datetime.date.today()
    formatted_date = date.strftime('%d-%m-%Y')

    pihole_backup_filename = f"{formatted_date}-pihole-backup.tar.gz"
    return pihole_backup_filename

def create_dns_backup(client):
    pihole_backup_file = pihole_backup_filename()
    docker_container_name = "pihole"

    home_folder = execute_remote_commands(client, "echo $HOME")

    # 1º command: create a backup file, with 'pihole' CLI
    # 2º command: copy the file from container to remote host
    # 3º command: remove file created in container
    commands = [
        f"docker exec {docker_container_name} pihole -a -t {pihole_backup_file}",
        f"docker cp {docker_container_name}:/{pihole_backup_file} {home_folder}",
        f"docker exec {docker_container_name} rm -rf {pihole_backup_file}"
    ]

    for command in commands:
        execute_remote_commands(client, command)


def dns_backup(host_data):
    ansible_host = host_data["ansible_host"]
    vm_user = host_data["vm_user"]
    vm_user_passwd = host_data["vm_user_passwd"]

    print(f"connecting in {ansible_host}...")
    client = connect_remote_host(ansible_host, vm_user, vm_user_passwd)

    print("creating backup file")
    create_dns_backup(client)

    home_folder = execute_remote_commands(client, "echo $HOME")
    pihole_backup_file = pihole_backup_filename()

    remote_backup_file = f"{home_folder}/{pihole_backup_file}"
    local_backup_file = f"{LOCAL_BACKUP_FOLDER}/{pihole_backup_file}"

    sftp = client.open_sftp()

    print(f"copying file from {remote_backup_file} to {local_backup_file}")
    sftp.get(remote_backup_file, local_backup_file)

    print("remove file from server")
    remove_file_from_server = f"rm -rf {remote_backup_file}"
    execute_remote_commands(client, remove_file_from_server)

    sftp.close()
    client.close()


#########################################################
# MAIN
#########################################################
if __name__ == "__main__":

    hosts_file = get_parameters()
    hosts = get_hosts_from_yaml(hosts_file)

    for host, host_data in hosts.items():

        if host == 'pihole':
            dns_backup(host_data)
