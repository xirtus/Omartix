#!/bin/sh
set -e

DEVICE=$1
MAPPER_NAME="cryptroot"

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 /dev/partition"
    exit 1
fi

echo "Formatting $DEVICE with LUKS2..."
# Force LUKS2 and verify passphrase
cryptsetup luksFormat --type luks2 "$DEVICE"

echo "Opening $DEVICE as $MAPPER_NAME..."
cryptsetup open "$DEVICE" "$MAPPER_NAME"