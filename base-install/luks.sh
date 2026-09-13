#!/bin/bash
# luks.sh <device> — format as LUKS2 and open as /dev/mapper/cryptroot.
set -e

DEVICE="$1"
MAPPER_NAME="cryptroot"

if [[ -z $DEVICE ]]; then
    echo "Usage: $0 /dev/partition" >&2
    exit 1
fi

echo "Formatting $DEVICE with LUKS2..."
cryptsetup luksFormat --type luks2 "$DEVICE"

echo "Opening $DEVICE as $MAPPER_NAME..."
cryptsetup open "$DEVICE" "$MAPPER_NAME"
