#!/bin/bash
# pacman-snap.sh — take a snapper snapshot before running pacman, then run
# pacman with the given arguments. Safe to alias as `pacman`.
set -e

DESC="pre-pacman $(date '+%Y-%m-%d %H:%M:%S')"
echo "Creating snapshot: $DESC"
snapper -c root create --description "$DESC" >/dev/null 2>&1 || true
echo "Executing pacman $*"
exec pacman "$@"
