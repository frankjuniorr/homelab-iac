#!/bin/bash

function command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

function python_lib_exists() {
    local lib="$1"
    pip3 freeze | grep "$lib" >/dev/null 2>&1
}

function python_ubuntu_install(){
    local lib="$1"
    sudo apt install python3-${lib} -y
}

function python_arch_install(){
    local lib="$1"
    sudo pacman -S --needed --noconfirm python-${lib}
}

#########################################################################
# MAIN
#########################################################################

os_name=$(grep "^NAME=" /etc/os-release | cut -d '=' -f2 | sed 's/"//g')

# Check if this OS commands are installed.
# This commands must be installed by "Dotfiles" project
os_commands=(
    "op"        # 1password-cli - installed by Dotfiles project
    "ansible"   # Ansible       - installed by Dotfiles project
    "python3"   # Python        - installed by Dotfiles project
    "pip3"      # pip3          - installed by Dotfiles project
)

python_libs=(
    "watchdog"    # Used by "beatiful_output.py"
    "paramiko"    # Used by custom ansible library in "src/roles/configure-remote-ssh/library/ssh_copy_key.py"
    "proxmoxer"   # Used by ansible-collection "community.general.proxmox_kvm"
    "requests"    # Used by ansible-collection "community.general.proxmox_kvm"
)

for cmd in "${os_commands[@]}"; do
  if ! command_exists "$cmd"; then
    echo "❌ Command '$cmd' is NOT installed."
    echo "Check the 'Dotfiles' project fisrt"
    exit 1
  fi
done

for lib in "${python_libs[@]}"; do
  if ! python_lib_exists "$lib"; then
    echo "❌ Python lib '$lib' is NOT installed."
    echo "installing python lib: $lib"
    case $os_name in
        "Ubuntu") python_ubuntu_install "$lib" ;;
        "Arch Linux") python_arch_install "$lib" ;;
        *) print_message "Unsupported OS" && exit 1 ;;
    esac
  fi
done