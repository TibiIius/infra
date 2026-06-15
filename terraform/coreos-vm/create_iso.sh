#!/bin/bash
set -euo pipefail

# Usage: ./create_iso.sh <coreos_iso_path> <ignition_json_path> <output_iso_path>
# Creates a Fedora CoreOS ISO with the ignition config baked in.

COREOS_ISO="${1:?No CoreOS ISO path provided}"
IGNITION_JSON="${2:?No ignition JSON path provided}"
OUTPUT_ISO="${3:?No output ISO path provided}"

if [ ! -f "$COREOS_ISO" ]; then
  echo "CoreOS ISO not found: $COREOS_ISO" >&2
  exit 1
fi

if [ ! -f "$IGNITION_JSON" ]; then
  echo "Ignition JSON not found: $IGNITION_JSON" >&2
  exit 1
fi

echo "Injecting ignition config into ISO..."
docker run --rm \
  -v "$(dirname "$COREOS_ISO"):/data:ro" \
  -v "$(dirname "$OUTPUT_ISO"):/output" \
  quay.io/coreos/coreos-installer:release \
  iso customize ignition \
  --ignition-file "/data/$(basename "$IGNITION_JSON")" \
  "/data/$(basename "$COREOS_ISO")" \
  "/output/$(basename "$OUTPUT_ISO")"

echo "ISO created: $OUTPUT_ISO"
echo "Size: $(du -h "$OUTPUT_ISO" | cut -f1)"
