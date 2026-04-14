#!/bin/bash
# backup-logs.sh - Display last backup run logs from remote hosts
# Managed by "homelab-iac"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"

DNS_USER="adguard"
DNS_HOST="192.168.1.51"
S3_USER="garage"
S3_HOST="192.168.1.52"
ADGUARD_LOG="/var/log/rclone/adguard-backup.log"
GARAGE_LOG="/var/log/rclone/garage-backup.log"

# --- Colors ---
COLOR_HEADER="5"
COLOR_SUCCESS="2"
COLOR_ERROR="1"
COLOR_WARNING="3"
COLOR_DIM="8"

# --- Checks ---
if ! command -v gum &>/dev/null; then
  echo "Error: 'gum' is not installed. Please install it to run this script."
  echo "Visit: https://github.com/charmbracelet/gum"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is not installed."
  exit 1
fi

# --- Helpers ---

function fmt_bytes() {
  local b=$1
  if   [ "$b" -eq 0 ];                      then echo "0 B"
  elif [ "$b" -lt 1024 ];                   then echo "${b} B"
  elif [ "$b" -lt $((1024 * 1024)) ];       then printf "%.1f KB" "$(echo "scale=1; $b/1024" | bc)"
  elif [ "$b" -lt $((1024*1024*1024)) ];    then printf "%.1f MB" "$(echo "scale=1; $b/1024/1024" | bc)"
  else                                           printf "%.2f GB" "$(echo "scale=2; $b/1024/1024/1024" | bc)"
  fi
}

function fmt_elapsed() {
  local s
  s=$(printf "%.0f" "$1")
  if [ "$s" -lt 60 ]; then
    echo "${s}s"
  else
    printf "%dm %ds" "$((s / 60))" "$((s % 60))"
  fi
}

function display_phase() {
  local label=$1
  local user=$2
  local host=$3
  local logfile=$4

  echo

  # Fetch last run block from remote
  local raw
  if ! raw=$(ssh $SSH_OPTS "${user}@${host}" \
    "tac '$logfile' | sed '/--- Backup Started/q' | tac" 2>/dev/null); then
    gum style --foreground="$COLOR_ERROR" --bold "  ✗ ${label}"
    gum style --foreground="$COLOR_DIM"   "    Could not connect to ${user}@${host}"
    return
  fi

  if [ -z "$raw" ]; then
    gum style --foreground="$COLOR_WARNING" --bold "  ⚠ ${label}"
    gum style --foreground="$COLOR_DIM"     "    Log file is empty or not found: ${logfile}"
    return
  fi

  # Parse metadata
  local started finished
  started=$(echo "$raw"  | grep "^--- Backup Started"  | sed 's/--- Backup Started at //;s/ ---//')
  finished=$(echo "$raw" | grep "^--- Backup Finished" | sed 's/--- Backup Finished at //;s/ ---//')

  # Extract stats from the last JSON entry that contains a "stats" object
  local stats_line
  stats_line=$(echo "$raw" | grep '^{' | jq -c 'select(.stats != null)' 2>/dev/null | tail -1)

  local error_msgs
  error_msgs=$(echo "$raw" | grep '^{' | jq -r 'select(.level == "error") | "    • " + .msg' 2>/dev/null)

  if [ -z "$stats_line" ]; then
    gum style --foreground="$COLOR_WARNING" --bold "  ⚠ ${label}"
    gum style --foreground="$COLOR_DIM"     "    No stats found in last run"
    return
  fi

  # Extract individual stats fields
  local bytes transfers checks elapsed errors fatal
  bytes=$(    echo "$stats_line" | jq '.stats.bytes     // 0')
  transfers=$(echo "$stats_line" | jq '.stats.transfers // 0')
  checks=$(   echo "$stats_line" | jq '.stats.checks    // 0')
  elapsed=$(  echo "$stats_line" | jq '.stats.elapsedTime // 0')
  errors=$(   echo "$stats_line" | jq '.stats.errors    // 0')
  fatal=$(    echo "$stats_line" | jq '.stats.fatalError // false')

  local bytes_fmt elapsed_fmt
  bytes_fmt=$(fmt_bytes "$bytes")
  elapsed_fmt=$(fmt_elapsed "$elapsed")

  # Status
  if [ "$errors" -gt 0 ] || [ "$fatal" = "true" ]; then
    gum style --foreground="$COLOR_ERROR" --bold "  ✗ ${label}"
  else
    gum style --foreground="$COLOR_SUCCESS" --bold "  ✓ ${label}"
  fi

  # Table
  printf "    %-18s  %s\n" "Started:"     "$started"
  printf "    %-18s  %s\n" "Finished:"    "$finished"
  printf "    %-18s  %s\n" "Transferred:" "${bytes_fmt} (${transfers} file(s))"
  printf "    %-18s  %s\n" "Checks:"      "$checks"
  printf "    %-18s  %s\n" "Elapsed:"     "$elapsed_fmt"

  if [ "$errors" -gt 0 ]; then
    printf "    %-18s  " "Errors:"
    gum style --foreground="$COLOR_ERROR" "${errors}"
    if [ -n "$error_msgs" ]; then
      echo
      gum style --foreground="$COLOR_ERROR" "$error_msgs"
    fi
  else
    printf "    %-18s  %s\n" "Errors:"    "0"
  fi
}

# --- Main ---

gum style \
  --foreground="$COLOR_HEADER" --border-foreground="$COLOR_HEADER" --border double \
  --align center --width 54 --margin "1 2" --padding "0 2" --bold \
  "Backup Logs"

display_phase "Phase 1 — AdGuard → S3"   "$DNS_USER" "$DNS_HOST" "$ADGUARD_LOG"
display_phase "Phase 2 — S3 → GDrive"    "$S3_USER"  "$S3_HOST"  "$GARAGE_LOG"

echo
