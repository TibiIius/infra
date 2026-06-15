#!/bin/bash
set -euo pipefail

# Usage: ./generate_user_data.sh <base_dir> <ip_address>
# Decrypts SOPS-encrypted Butane config and NM connection,
# templates the NM config with the provided IP,
# merges them, and outputs merged Butane YAML as JSON for Terraform.

BASE_DIR="${1:?No base directory provided}"
IP_ADDRESS="${2:?No IP address provided}"

BU_FILE="$BASE_DIR/terraform/coreos-vm/config.bu"
NM_FILE="$BASE_DIR/terraform/coreos-vm/Wired Connection 1.nmconnection"

if [ ! -f "$BU_FILE" ] || [ ! -f "$NM_FILE" ]; then
  echo "{\"error\": \"Missing required files in $BASE_DIR\"}" >&2
  exit 1
fi

# Decrypt files
BU_CONTENT=$(sops -d "$BU_FILE") || { echo "{\"error\": \"Failed to decrypt config.bu\"}" >&2; exit 1; }
NM_CONTENT=$(sops -d "$NM_FILE") || { echo "{\"error\": \"Failed to decrypt nmconnection\"}" >&2; exit 1; }

# Template NM config with IP (replace the default IP with the provided one)
NM_CONTENT_TEMPLATED=$(echo "$NM_CONTENT" | sed "s/192\.168\.178\.[0-9]\+/$IP_ADDRESS/g")

# Merge NM content into Butane config using python, output as JSON for Terraform external provider
python3 -c "
import sys, yaml, json

bu = yaml.safe_load(sys.stdin)
nm_content = '''$NM_CONTENT_TEMPLATED'''

nm_file = {
    'path': '/etc/NetworkManager/system-connections/Wired Connection 1.nmconnection',
    'mode': 0o600,
    'contents': {'inline': nm_content}
}

if 'storage' not in bu:
    bu['storage'] = {}
if 'files' not in bu['storage']:
    bu['storage']['files'] = []

bu['storage']['files'].append(nm_file)
merged_yaml = yaml.dump(bu, default_flow_style=False)
print(json.dumps({'config': merged_yaml}))
" <<< "$BU_CONTENT" || { echo "{\"error\": \"Failed to merge NM config\"}" >&2; exit 1; }
