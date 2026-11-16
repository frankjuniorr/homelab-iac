#!/bin/bash
# doctor.sh - Homelab Healthcheck Diagnostic Tool (Enhanced with gum)
# Managed by "homelab-iac"

# --- Colors (Terminal Theme) ---
COLOR_HEADER="5"    # Magenta (Standard)
COLOR_SUBHEADER="6" # Cyan (Standard)
COLOR_SUCCESS="2"   # Green (Standard)
COLOR_ERROR="1"     # Red (Standard)
COLOR_INFO="0"      # White/Light Grey (Standard)

# Check if gum is installed
if ! command -v gum &>/dev/null; then
  echo "Error: 'gum' is not installed. Please install it to run this script."
  echo "Visit: https://github.com/charmbracelet/gum"
  exit 1
fi

# --- Helper Functions ---

function header() {
  gum style \
    --foreground="$COLOR_HEADER" --border-foreground="$COLOR_HEADER" --border double \
    --align center --width=70 --margin "1 2" --padding "0 2" --bold \
    "$1"
}

function subheader() {
  echo
  gum style --foreground="$COLOR_SUBHEADER" --bold "=== $1 ==="
}

function check_ssh() {
  local host=$1
  if ssh -q -o BatchMode=yes -o ConnectTimeout=3 "$host" exit; then
    return 0
  else
    return 1
  fi
}

# Standard table style for the script
TABLE_STYLE=" --border.foreground=$COLOR_SUBHEADER"

# --- 1. Proxmox Checks ---
header "🖥️ PROXMOX DIAGNOSTIC"
if check_ssh "root@proxmox"; then
  subheader "📂 QCOW2 Images Size (/var/lib/vz/images)"
  ssh root@proxmox "ls -lh /var/lib/vz/images/*.qcow2 2>/dev/null" | awk '{print $5 "," $9}' | gum table $TABLE_STYLE --print --columns "Size,Path"

  subheader "🖥️ Running Status (VMs)"
  ssh root@proxmox "qm list" | tail -n +2 | awk '{print $1 "," $2 "," $3 "," $4 "," $5}' | gum table $TABLE_STYLE --print --columns "VMID,Name,Status,Memory(MB),Disk(GB)"

else
  gum style --foreground "$COLOR_ERROR" --bold "❌ SSH to Proxmox failed."
fi

# --- 2. Guest Services & Reachability ---
header "🌐 GLOBAL SERVICES STATUS"
ALL_HOSTS=("root@proxmox" "docker")
service_data=""
for host in "${ALL_HOSTS[@]}"; do
  display_name=$(echo "$host" | sed 's/root@//')
  status="🔴 OFFLINE"
  ssh_ok="❌ NO"
  cockpit_ok="❌ NO"

  if check_ssh "$host"; then
    ssh_ok="✅ YES"
    # Check for both cockpit.socket (common in Ubuntu) and cockpit.service
    # Added 2>/dev/null to avoid "Transport endpoint is not connected" noise during transients
    if ssh -q "$host" "systemctl is-active --quiet cockpit.socket 2>/dev/null || systemctl is-active --quiet cockpit 2>/dev/null"; then
      cockpit_ok="✅ YES"
    fi
    status="🟢 ONLINE"
  fi
  service_data+="$display_name,$status,$ssh_ok,$cockpit_ok\n"
done
echo -e "$service_data" | sed '/^$/d' | gum table $TABLE_STYLE --print --columns "Host,Status,SSH,Cockpit"

# --- 3. Network Ports ---
header "🔌 LISTENING PORTS"
for host in "${ALL_HOSTS[@]}"; do
  display_name=$(echo "$host" | sed 's/root@//')
  subheader "Host: $display_name"
  if check_ssh "$host"; then
    # Conditionally use sudo: only if not connecting as root
    cmd_prefix=""
    [[ "$host" != root@* ]] && cmd_prefix="sudo "

    ssh -q "$host" "${cmd_prefix}lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | awk '{print \$9 \",\" \$1}' | sed 's/.*://' | sort -nu" | gum table $TABLE_STYLE --print --columns "Port,Process"
  else
    gum style --foreground "$COLOR_ERROR" "🔴 Host $display_name is OFFLINE"
  fi
done

# --- 4. Service Checks ---
header "📦 SERVICES DEEP DIVE"

# AdGuard (docker-compose on netuno)
subheader "🛡️ AdGuardHome (docker)"
if check_ssh "docker"; then
  HTTP_STATUS=$(curl -Is -o /dev/null -w "%{http_code}" http://192.168.1.51:3000)
  if [[ "$HTTP_STATUS" =~ ^(200|301|302)$ ]]; then
    gum style --foreground "$COLOR_SUCCESS" --bold "✅ AdGuard Web responding (Status: $HTTP_STATUS)"
  else
    gum style --foreground "$COLOR_ERROR" --bold "❌ AdGuard Web NOT responding on port 3000 (Status: $HTTP_STATUS)"
  fi
  echo "🐳 Containers:"
  ssh -q docker "docker ps --format '{{.Names}}	{{.Status}}'" | gum style --foreground "$COLOR_INFO" || echo "No containers found."
fi

# --- 6. Local Configuration ---
header "⚙️ LOCAL CONFIGURATION"
subheader "📝 /etc/hosts (Nodes)"
grep -E "proxmox|docker|haos" /etc/hosts | awk '{print $1 "," $2}' | gum table $TABLE_STYLE --print --columns "IP,Hostname"

subheader "🔒 Local SSH Configuration (~/.ssh/config)"
if [ -f ~/.ssh/config ]; then
  gum style --foreground "$COLOR_INFO" "$(cat ~/.ssh/config)"
else
  gum style --foreground "$COLOR_ERROR" --bold "❌ ~/.ssh/config NOT found."
fi

subheader "📂 Local SSH Config (~/.ssh/servers/homelab.conf)"
if [ -f ~/.ssh/servers/homelab.conf ]; then
  gum style --foreground "$COLOR_INFO" "$(cat ~/.ssh/servers/homelab.conf)"
else
  gum style --foreground "$COLOR_ERROR" --bold "❌ ~/.ssh/servers/homelab.conf NOT found."
fi


echo ""
gum style --foreground "$COLOR_SUCCESS" --bold "🎉 Diagnostic Complete!"
