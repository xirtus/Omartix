#!/bin/sh
set -e
DESC="pre-pacman $(date '+%Y-%m-%d %H:%M:%S')"
echo "Creating snapshot: $DESC"
snapper -c root create --description "$DESC"
echo "Executing pacman $@"
pacman "$@"
