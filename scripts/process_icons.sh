#!/bin/bash
# process_icons.sh - Wrapper to run image processing in a virtual environment
# Managed by "homelab-iac"

SCRIPT_DIR="scripts/image-tools"
VENV_DIR="$SCRIPT_DIR/.venv"

# --- Colors ---
COLOR_SUCCESS="\e[32m"
COLOR_INFO="\e[34m"
COLOR_RESET="\e[0m"

echo -e "${COLOR_INFO}Setting up Python virtual environment...${COLOR_RESET}"

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

# Activate venv and install requirements
source "$VENV_DIR/bin/activate"
pip install --quiet Pillow

echo -e "${COLOR_INFO}Processing icons...${COLOR_RESET}"
python3 "$SCRIPT_DIR/process_icons.py"

echo -e "${COLOR_SUCCESS}Done! All icons in images/icons/ have been resized to 100x100px.${COLOR_RESET}"
deactivate
