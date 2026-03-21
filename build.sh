#!/bin/bash
set -euo pipefail

SDK="/Users/persjo/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
DEVICE="fr970"

mkdir -p build

HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "dev")

"$SDK/bin/monkeyc" \
    -e \
    -f monkey.jungle \
    -o "build/SugarField-${HASH}.iq" \
    -d "$DEVICE" \
    -y "$KEY" \
    -w

echo "Built: build/SugarField-${HASH}.iq"
