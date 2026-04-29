#!/bin/bash
# s3-manager.sh - Homelab S3 Bucket Management Tool
# Managed by "homelab-iac"

# --- Configuration ---
# You can override this if your endpoint is different
ENDPOINT_URL=${S3_ENDPOINT_URL:-"http://192.168.1.52:3900"}

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

# Check if aws-cli is installed
if ! command -v aws &>/dev/null; then
  echo "Error: 'aws-cli' is not installed."
  exit 1
fi

function header() {
  gum style \
    --foreground="$COLOR_HEADER" --border-foreground="$COLOR_HEADER" --border double \
    --align center --width=70 --margin "1 2" --padding "0 2" --bold \
    "$1"
}

function list_buckets() {
  header "🪣 LISTING BUCKETS"

  local bucket_list total_bytes=0 total_objects=0
  bucket_list=$(aws s3 ls --endpoint-url "$ENDPOINT_URL" 2>/dev/null)

  local table_data=""
  while IFS= read -r line; do
    local bname bdate btime
    bdate=$(echo "$line" | awk '{print $1}')
    btime=$(echo "$line" | awk '{print $2}')
    bname=$(echo "$line" | awk '{print $3}')
    [ -z "$bname" ] && continue

    local size_info
    size_info=$(aws s3 ls "s3://${bname}/" --endpoint-url "$ENDPOINT_URL" --recursive 2>/dev/null | \
      awk '{sum+=$3; count++} END {printf "%d objects / %.2f MB", count, sum/1024/1024}')
    [ -z "$size_info" ] && size_info="0 objects / 0.00 MB"

    local raw_bytes raw_objs
    raw_bytes=$(aws s3 ls "s3://${bname}/" --endpoint-url "$ENDPOINT_URL" --recursive 2>/dev/null | awk '{sum+=$3} END {print sum+0}')
    raw_objs=$(aws s3 ls "s3://${bname}/" --endpoint-url "$ENDPOINT_URL" --recursive 2>/dev/null | wc -l)
    total_bytes=$((total_bytes + raw_bytes))
    total_objects=$((total_objects + raw_objs))

    table_data+="${bdate},${btime},${bname},${size_info}\n"
  done <<< "$bucket_list"

  echo -e "$table_data" | sed '/^$/d' | gum table --print --columns "Date,Time,Bucket,Size"

  local total_mb
  total_mb=$(awk "BEGIN {printf \"%.2f\", $total_bytes/1024/1024}")
  echo
  gum style --foreground "$COLOR_SUBHEADER" --bold "Total: ${total_objects} objects / ${total_mb} MB across $(echo "$bucket_list" | wc -l) buckets"
}

function _browse_bucket() {
  local bucket=$1
  local prefix=""

  while true; do
    local raw dirs files entries=() idx=0

    raw=$(aws s3 ls "s3://${bucket}/${prefix}" --endpoint-url "$ENDPOINT_URL" 2>/dev/null)

    [ -n "$prefix" ] && entries+=("..")

    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*PRE[[:space:]]+(.+)$ ]]; then
        entries+=("📁  ${BASH_REMATCH[1]}")
      elif [[ "$line" =~ ^([0-9-]+)[[:space:]]+([0-9:]+)[[:space:]]+([0-9]+)[[:space:]]+(.+)$ ]]; then
        local fdate="${BASH_REMATCH[1]}" ftime="${BASH_REMATCH[2]}" fsize="${BASH_REMATCH[3]}" fname="${BASH_REMATCH[4]}"
        entries+=("📄  ${fname}  (${fsize} B, ${fdate} ${ftime})")
      fi
    done <<< "$raw"

    if [ ${#entries[@]} -eq 0 ]; then
      echo "(empty)" | fzf --header "s3://${bucket}/${prefix}  [Esc to exit]" --no-sort --height=40% --disabled
      return
    fi

    local selected
    selected=$(printf '%s\n' "${entries[@]}" | fzf \
      --header "s3://${bucket}/${prefix}  [Enter=open dir, Esc=exit]" \
      --prompt "Browse > " \
      --no-sort \
      --height=60%)

    [ -z "$selected" ] && return  # Esc

    if [[ "$selected" == ".." ]]; then
      prefix="${prefix%*/}"       # strip trailing /
      prefix="${prefix%/*}/"      # go up one level
      [[ "$prefix" == "/" ]] && prefix=""
    elif [[ "$selected" == 📁* ]]; then
      local dir
      dir=$(echo "$selected" | sed 's/^📁[[:space:]]*//')
      prefix="${prefix}${dir}"
    fi
    # 📄 = file: just re-show the current level
  done
}

function list_contents() {
  local bucket=$1
  if [ -z "$bucket" ]; then
    bucket=$(aws s3 ls --endpoint-url "$ENDPOINT_URL" | awk '{print $3}' | gum choose --header "Select bucket to browse" --header.foreground "$COLOR_SUBHEADER" --item.foreground "$COLOR_INFO" --selected.foreground "$COLOR_HEADER")
  fi
  [ -z "$bucket" ] && return

  header "📂 BROWSING: $bucket"
  _browse_bucket "$bucket"
}

function create_bucket() {
  local name=$1
  if [ -z "$name" ]; then
    name=$(gum input --placeholder "Enter bucket name")
  fi
  [ -z "$name" ] && return

  header "🆕 CREATING BUCKET: $name"
  if aws s3 mb "s3://$name" --endpoint-url "$ENDPOINT_URL"; then
    gum style --foreground "$COLOR_SUCCESS" "✅ Bucket '$name' created successfully!"
  else
    gum style --foreground "$COLOR_ERROR" "❌ Failed to create bucket."
  fi
}

function upload_file() {
  local bucket=$1
  local file=$2

  if [ -z "$bucket" ]; then
    bucket=$(aws s3 ls --endpoint-url "$ENDPOINT_URL" | awk '{print $3}' | gum choose --header "Select target bucket" --header.foreground "$COLOR_SUBHEADER" --item.foreground "$COLOR_INFO" --selected.foreground "$COLOR_HEADER")
  fi
  [ -z "$bucket" ] && return

  if [ -z "$file" ]; then
    file=$(gum input --placeholder "Path to local file")
  fi
  [ -f "$file" ] || {
    gum style --foreground "$COLOR_ERROR" "❌ File not found: $file"
    return
  }

  header "📤 UPLOADING TO: $bucket"
  if aws s3 cp "$file" "s3://$bucket/" --endpoint-url "$ENDPOINT_URL"; then
    gum style --foreground "$COLOR_SUCCESS" "✅ Upload complete!"
  else
    gum style --foreground "$COLOR_ERROR" "❌ Upload failed."
  fi
}

function download_items() {
  local bucket=$1
  if [ -z "$bucket" ]; then
    bucket=$(aws s3 ls --endpoint-url "$ENDPOINT_URL" | awk '{print $3}' | gum choose --header "Select source bucket" --header.foreground "$COLOR_SUBHEADER" --item.foreground "$COLOR_INFO" --selected.foreground "$COLOR_HEADER")
  fi
  [ -z "$bucket" ] && return

  local choice=$(gum choose "📄 Download single file" "🔄 Download all files (Sync)" --item.foreground "$COLOR_INFO" --selected.foreground "$COLOR_HEADER")

  if [[ "$choice" == "📄 Download single file" ]]; then
    local remote_file=$(aws s3 ls "s3://$bucket/" --endpoint-url "$ENDPOINT_URL" | awk '{print $4}' | gum choose --header "Select file to download" --header.foreground "$COLOR_SUBHEADER" --item.foreground "$COLOR_INFO" --selected.foreground "$COLOR_HEADER")
    [ -z "$remote_file" ] && return
    local dest=$(gum input --placeholder "Destination path (e.g., ./$remote_file)")
    [ -z "$dest" ] && dest="./$remote_file"

    header "📥 DOWNLOADING: $remote_file"
    aws s3 cp "s3://$bucket/$remote_file" "$dest" --endpoint-url "$ENDPOINT_URL"
  else
    local dest=$(gum input --placeholder "Destination directory (e.g., ./$bucket-backup)")
    [ -z "$dest" ] && dest="./$bucket-backup"
    mkdir -p "$dest"

    header "📥 SYNCING BUCKET: $bucket"
    aws s3 sync "s3://$bucket/" "$dest/" --endpoint-url "$ENDPOINT_URL"
  fi
}

# --- Main CLI Router ---
case "$1" in
ls | list) list_buckets ;;
cat | content | files) list_contents "$2" ;;
create | mb) create_bucket "$2" ;;
upload | up | cp) upload_file "$2" "$3" ;;
download | down | sync) download_items "$2" ;;
*)
  header "🛰️ S3 MANAGER"
  ACTION=$(gum choose "🪣 List Buckets" "📂 List Bucket Contents" "🆕 Create Bucket" "📤 Upload File" "📥 Download / Sync" "❌ Exit" --item.foreground="$COLOR_INFO" --cursor.foreground="$COLOR_SUBHEADER")
  case "$ACTION" in
  "🪣 List Buckets") list_buckets ;;
  "📂 List Bucket Contents") list_contents ;;
  "🆕 Create Bucket") create_bucket ;;
  "📤 Upload File") upload_file ;;
  "📥 Download / Sync") download_items ;;
  "❌ Exit") exit 0 ;;
  esac
  ;;
esac
