#!/bin/bash

dest_dir="$(dirname "$0")/kubespray"

echo "creating kubespray virtualenv..."
cd "$dest_dir"
python3 -m venv .venv
source .venv/bin/activate

echo "Installing kubespray dependencies..."
pip3 install -r requirements.txt

echo "Installing kubespray..."
ansible-playbook -i inventory/homelab/sample/inventory.ini --become --become-user=root cluster.yml

sleep 1
cd ..
rm -rf "$dest_dir"