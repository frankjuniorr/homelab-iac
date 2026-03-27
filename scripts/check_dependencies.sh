#!/bin/bash

function command_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

function python_lib_exists() {
  local lib="$1"
  pip3 freeze | grep -i "$lib" >/dev/null 2>&1
}

function install_python_lib() {
  local lib="$1"
  echo "Attempting to install python lib: $lib"

  # Try OS package manager first
  case $os_name in
  "Ubuntu") sudo apt install python3-${lib} -y && return 0 ;;
  "Arch Linux") sudo pacman -S --needed --noconfirm python-${lib} && return 0 ;;
  esac

  # Fallback to pip if OS package fails or is unknown
  echo "OS package failed, falling back to pip3..."
  pip3 install "$lib"
}

#########################################################################
# MAIN
#########################################################################

os_name=$(grep "^NAME=" /etc/os-release | cut -d '=' -f2 | sed 's/"//g')

# Check if this OS commands are installed.
os_commands=(
  "op"      # 1password-cli
  "ansible" # Ansible
  "python3" # Python
  "pip3"    # pip3
  "sops"    # SOPS CLI
  "age"     # Age
)

python_libs=(
  "watchdog"  # Used by "beatiful_output.py"
  "paramiko"  # Used by custom ansible library
  "proxmoxer" # Used by community.general.proxmox_kvm
  "requests"  # Used by community.general.proxmox_kvm
)

for cmd in "${os_commands[@]}"; do
  if ! command_exists "$cmd"; then
    echo "❌ Command '$cmd' is NOT installed."
    exit 1
  fi
done

for lib in "${python_libs[@]}"; do
  if ! python_lib_exists "$lib"; then
    echo "❌ Python lib '$lib' is NOT installed."
    install_python_lib "$lib"
  fi
done
