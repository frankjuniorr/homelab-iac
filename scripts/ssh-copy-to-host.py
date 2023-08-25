#!/usr/bin/env python

import yaml
import sys
import paramiko
import os

AUTHORIZED_KEY_FILE = ".ssh/authorized_keys"

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


def read_ssh_key(ssh_public_key):
    """
    Function to read my ssh key
    """
    with open(ssh_public_key, 'r') as file:
        line = file.read().strip()
        return line

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

def get_authorized_key_path(client):
    """
    Function to get absolute path to 'authorized_keys' file
    """
    home_folder = execute_remote_commands(client, "echo $HOME")
    authorized_keys_path = f"{home_folder}/{AUTHORIZED_KEY_FILE}"
    return authorized_keys_path

def check_if_authorized_keys_exists(client):
    """
    Function to check if 'authorized_keys' exists
    """
    authorized_keys_path = get_authorized_key_path(client)

    sftp = client.open_sftp()
    try:
        resultado = sftp.stat(authorized_keys_path)
        return True

    except FileNotFoundError:
        return False


def check_if_ssh_already_in_authorized_key(ssh_public_key):
    """
    Fuction to check if my ssh key, is already into 'authorized_keys'
    """
    authorized_keys_path = get_authorized_key_path(client)

    comando = f"cat {authorized_keys_path}"
    authorized_key_content = execute_remote_commands(client, comando)

    if ssh_public_key not in authorized_key_content:
        add_ssh_in_authorized_key(client, ssh_public_key)
    else:
        print("LOG: ssh key already in remote host")


def add_ssh_in_authorized_key(client, ssh_public_key):
    """
    Function to add mey ssh key into 'authorized_keys'
    """
    authorized_keys_path = get_authorized_key_path(client)

    comando = f"echo {ssh_public_key} >> {authorized_keys_path}"
    execute_remote_commands(client, comando)
    print(f"LOG: ssh key added")

#########################################################
# MAIN
#########################################################
if __name__ == "__main__":

    hosts_file = get_parameters()
    hosts = get_hosts_from_yaml(hosts_file)

    for host, host_data in hosts.items():
        ansible_host = host_data["ansible_host"]
        ansible_user = host_data["ansible_user"]
        root_password = host_data["root_password"]
        ssh_public_key_file = host_data["ssh_public_key_file"]

        print("\n> Sending ssh key to:")
        print("-------------------------------------")
        print(f"Host: {host}")
        print(f"ssh_public_key_file: {ssh_public_key_file}")

        ssh_public_key = read_ssh_key(ssh_public_key_file)
        client = connect_remote_host(ansible_host, ansible_user, root_password)

        if check_if_authorized_keys_exists(client):
            check_if_ssh_already_in_authorized_key(ssh_public_key)

        else:
            add_ssh_in_authorized_key(client, ssh_public_key)

        client.close()
