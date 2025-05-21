#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
import paramiko

def read_ssh_key(path):
    with open(path, "r") as file:
        return file.read().strip()

def connect(host, user, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname=host, username=user, password=password)
    return client

def exec_cmd(client, cmd):
    stdin, stdout, stderr = client.exec_command(cmd)
    return stdout.read().decode().strip()

def key_already_present(client, key):
    path = exec_cmd(client, "echo $HOME") + "/.ssh/authorized_keys"
    try:
        content = exec_cmd(client, f"cat {path}")
        return key in content
    except:
        return False

def ensure_key(client, key):
    path = exec_cmd(client, "echo $HOME") + "/.ssh/authorized_keys"
    exec_cmd(client, "mkdir -p ~/.ssh && chmod 700 ~/.ssh")
    if not key_already_present(client, key):
        exec_cmd(client, f"echo '{key}' >> {path}")
        return True
    return False

def run_module():
    module_args = dict(
        host=dict(type='str', required=True),
        user=dict(type='str', required=True),
        password=dict(type='str', required=True, no_log=True),
        public_key_file=dict(type='str', required=True)
    )

    module = AnsibleModule(argument_spec=module_args, supports_check_mode=False)

    try:
        host        = module.params['host']
        user        = module.params['user']
        password    = module.params['password']
        public_key  = module.params['public_key_file']

        key = read_ssh_key(public_key)
        client = connect(host, user, password)
        changed = ensure_key(client, key)
        client.close()

        module.exit_json(changed=changed, msg="SSH key copied successfully" if changed else "SSH key already present")
    except Exception as e:
        module.fail_json(msg=str(e))

if __name__ == '__main__':
    run_module()
