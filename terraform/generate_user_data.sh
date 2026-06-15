#!/bin/bash
set -euo pipefail

# Usage: ./generate_user_data.sh <base_dir>
# Decrypts SOPS-encrypted Butane config and NM connection,
# merges them, and outputs JSON for Terraform external provider.

BASE_DIR="${1:?No base directory provided}"

BU_FILE="$BASE_DIR/terraform/coreos-vm/config.bu"
NM_FILE="$BASE_DIR/terraform/coreos-vm/Wired Connection 1.nmconnection"

if [ ! -f "$BU_FILE" ] || [ ! -f "$NM_FILE" ]; then
  echo "{\"error\": \"Missing required files in $BASE_DIR\"}" >&2
  exit 1
fi

# Decrypt files
BU_CONTENT=$(sops -d "$BU_FILE") || { echo "{\"error\": \"Failed to decrypt config.bu\"}" >&2; exit 1; }
NM_CONTENT=$(sops -d "$NM_FILE") || { echo "{\"error\": \"Failed to decrypt nmconnection\"}" >&2; exit 1; }

# Export NM_CONTENT as environment variable for yq env()
export NM_CONTENT

# Merge NM content into the Butane config using yq v4 syntax
MERGED_YAML=$(echo "$BU_CONTENT" | yq '.storage.files += [{"path": "/etc/NetworkManager/system-connections/Wired Connection 1.nmconnection", "mode": 0600, "contents": {"inline": env(NM_CONTENT)}}]') || { echo "{\"error\": \"Failed to merge content using yq\"}" >&2; exit 1; }

# Return as JSON for Terraform external provider
echo "$MERGED_YAML" | jq -R -s '{"config": .}'
