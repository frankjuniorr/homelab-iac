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

  subheader "📦 Running Status (LXCs)"
  ssh root@proxmox "pct list" | tail -n +2 | awk '{print $1 "," $2 "," $3}' | gum table $TABLE_STYLE --print --columns "VMID,Status,Name"
else
  gum style --foreground "$COLOR_ERROR" --bold "❌ SSH to Proxmox failed."
fi

# --- 2. Guest Services & Reachability ---
header "🌐 GLOBAL SERVICES STATUS"
ALL_HOSTS=("root@proxmox" "dns" "s3" "k8s-master" "k8s-worker-1" "k8s-worker-2")
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

# --- 4. LXC Specific Checks ---
header "📦 LXC CONTAINERS DEEP DIVE"

# AdGuard
subheader "🛡️ AdGuardHome (dns)"
if check_ssh "dns"; then
  # Use -L to follow redirects and check for 200 or 302 status codes
  HTTP_STATUS=$(curl -Is -o /dev/null -w "%{http_code}" http://192.168.1.51:80)
  if [[ "$HTTP_STATUS" =~ ^(200|301|302)$ ]]; then
    gum style --foreground "$COLOR_SUCCESS" --bold "✅ AdGuard Web responding (Status: $HTTP_STATUS)"
  else
    gum style --foreground "$COLOR_ERROR" --bold "❌ AdGuard Web NOT responding on port 80 (Status: $HTTP_STATUS)"
  fi

  echo "🔍 DNS Rewrites:"
  ssh -q dns "sudo yq '.filtering.rewrites[] | .domain + \" -> \" + .answer' /opt/AdGuardHome/AdGuardHome.yaml 2>/dev/null" | gum style --foreground "$COLOR_INFO" || echo "No rewrites found."
fi

# Garage S3
subheader "🗄️ Garage S3 (s3)"
if check_ssh "s3"; then
  echo "🪣 Buckets:"
  ssh -q s3 "garage bucket list" | tail -n +2 | awk '{print $1 "," $3}' | gum table $TABLE_STYLE --print --columns "ID,Name"
fi

# --- 4. Kubernetes Checks ---
header "☸️ K3s CLUSTER STATUS"
if [ -f ~/.kube/config.k3s ]; then
  subheader "🖥️ Nodes"
  kubectl --kubeconfig ~/.kube/config.k3s get nodes | tail -n +2 | awk '{print $1 "," $2 "," $3 "," $5}' | gum table $TABLE_STYLE --print --columns "Name,Status,Roles,Version"

  subheader "📂 Namespaces"
  kubectl --kubeconfig ~/.kube/config.k3s get namespaces | tail -n +2 | awk '{print $1 "," $2 "," $3}' | gum table $TABLE_STYLE --print --columns "Name,Status,Age"
else
  gum style --foreground "$COLOR_ERROR" --bold "❌ Kubeconfig ~/.kube/config.k3s NOT found locally. Skipping cluster checks."
fi

# --- 5. Backup & Logs ---
header "💾 BACKUP & LOGS DIAGNOSTIC"

subheader "📋 Logs"
log_data=""
LOGS=(
  "dns:/var/log/rclone/adguard-backup.log"
  "s3:/var/log/rclone/garage-backup.log"
)

for entry in "${LOGS[@]}"; do
  host=$(echo $entry | cut -d: -f1)
  file=$(echo $entry | cut -d: -f2)

  if check_ssh "$host"; then
    # Verify if file exists before trying to read it
    if ssh -q "$host" "[ -f $file ]"; then
      size=$(ssh -q "$host" "ls -lh $file" | awk '{print $5}')
      last_date=$(ssh -q "$host" "grep 'Backup Started' $file | tail -n 1" | sed 's/--- Backup Started at //;s/ ---//')
      log_data+="$host,$size,$last_date\n"
    else
      log_data+="$host,NOT FOUND,NEVER\n"
    fi
  fi
done
echo -e "$log_data" | sed '/^$/d' | gum table $TABLE_STYLE --print --columns "Host,Log Size,Last Backup"

# RClone & Cron
subheader "⏰ RClone & Cron (dns & s3)"
rclone_data=""

LOGS=(
  "dns:backup-adguard-to-s3.sh"
  "s3:backup-s3-to-gdrive.sh"
)

for entry in "${LOGS[@]}"; do
  host=$(echo $entry | cut -d: -f1)
  file=$(echo $entry | cut -d: -f2)

  if check_ssh "$host"; then
    cron_status="❌ NO CRON"
    # Silence stderr to avoid warnings if crontab doesn't exist yet
    ssh -q "$host" "sudo crontab -l 2>/dev/null | grep -q $file" && cron_status="✅ ACTIVE"
    rclone_data+="$host,$cron_status\n"
  fi
done
echo -e "$rclone_data" | sed '/^$/d' | gum table $TABLE_STYLE --print --columns "Host,Cron Status"

# --- 6. Local Configuration ---
header "⚙️ LOCAL CONFIGURATION"
subheader "🔑 ~/.kube/config.k3s"
if [ -f ~/.kube/config.k3s ]; then
  gum style --foreground "$COLOR_SUCCESS" --bold "✅ Found: $(ls -lh ~/.kube/config.k3s | awk '{print $5}')"
else
  gum style --foreground "$COLOR_ERROR" --bold "❌ NOT found."
fi

subheader "📝 /etc/hosts (Nodes)"
grep -E "proxmox|dns|s3|k8s-" /etc/hosts | awk '{print $1 "," $2}' | gum table $TABLE_STYLE --print --columns "IP,Hostname"

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

subheader "🔒 Local AWS Configuration (~/.aws/config)"
if [ -f ~/.aws/config ]; then
  gum style --foreground "$COLOR_INFO" "$(cat ~/.aws/config)"
else
  gum style --foreground "$COLOR_ERROR" --bold "❌ ~/.aws/config NOT found."
fi

echo ""
gum style --foreground "$COLOR_SUCCESS" --bold "🎉 Diagnostic Complete!"
