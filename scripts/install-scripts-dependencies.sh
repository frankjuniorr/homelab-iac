#!/bin/bash

# Dependencie to Ansible 'beautiful_output' plugin
pip3 install watchdog

script_dir="$(dirname "$0")"
venv_folder="${script_dir}/.venv"
requirements_file="${script_dir}/requirements.txt"

echo "Installing python dependencies..."

python3 -m venv "$venv_folder"
source ${venv_folder}/bin/activate

pip3 install -r $requirements_file