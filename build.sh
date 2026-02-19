#!/bin/bash
set -euo pipefail

SDK="/Users/persjo/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
DEVICE="fr970"

VARIANTS=(combined graph)

mkdir -p build

for variant in "${VARIANTS[@]}"; do
    echo "=== Building $variant ==="
    "$SDK/bin/monkeyc" \
        -f "variants/$variant/monkey.jungle" \
        -o "build/SR_${variant}.prg" \
        -d "$DEVICE" \
        -y "$KEY" \
        -w
    echo "    -> build/SR_${variant}.prg"
done

echo ""
echo "All variants built:"
ls -lh build/SR_*.prg
