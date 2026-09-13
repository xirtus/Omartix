#!/bin/bash
# install.sh — install the Omartix runit layer into a target system.
#
# Run as root, either live or against a chroot:
#
#   runit/install.sh                 # current system
#   runit/install.sh --root /mnt     # inside the Artix live ISO, target /mnt
#
# Installs:
#   * the whole layer under /usr/share/omartix/runit/
#   * bundled system services into /etc/runit/sv/
#   * systemd shims + session scripts into /usr/local/bin/ (and /usr/bin links)
#   * translated systemd config drop-ins (elogind, earlyoom, limits)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT=""

while (($#)); do
  case "$1" in
    --root=*) ROOT="${1#--root=}" ;;
    --root) ROOT="${2:-}"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

[[ -z $ROOT ]] && ROOT=""

DEST="$ROOT/usr/share/omartix/runit"
SV_DEST="$ROOT/etc/runit/sv"
BIN_DEST="$ROOT/usr/local/bin"
SYSTEMD_BIN="$ROOT/usr/bin"

echo "==> Installing Omartix runit layer to $DEST"
install -d -m 0755 "$DEST"
cp -a "$HERE"/. "$DEST"/
chmod +x "$DEST"/install.sh "$DEST"/omartix-services

# ---------------------------------------------------------------------------
# Bundled system services (those Artix ships no `-runit` package for)
# ---------------------------------------------------------------------------
echo "==> Installing bundled runit system services"
install -d -m 0755 "$SV_DEST"
for svc in "$HERE"/sv/*/; do
  name="$(basename "$svc")"
  rm -rf "$SV_DEST/$name"
  cp -a "$svc" "$SV_DEST/$name"
  chmod +x "$SV_DEST/$name"/run 2>/dev/null || true
  chmod +x "$SV_DEST/$name"/finish 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# Shims + session scripts
# ---------------------------------------------------------------------------
echo "==> Installing systemd shims and session scripts"
install -d -m 0755 "$BIN_DEST"

# install_shim <name> [link-into-usr-bin]
# The systemd tools don't exist on Artix, so linking them under /usr/bin is safe
# and guarantees they resolve from sudo's secure_path too. dbus-update-activation-
# environment DOES exist (dbus package), so it is only shadowed in /usr/local/bin
# and must NOT be linked into /usr/bin (that would recurse into the shim).
install_shim() {
  local name="$1"
  local link_usrbin="${2:-1}"
  install -m 0755 "$HERE/shims/$name" "$BIN_DEST/$name"
  if (( link_usrbin )); then
    ln -sf "$BIN_DEST/$name" "$SYSTEMD_BIN/$name"
  fi
}

install_shim systemctl
install_shim systemd-run
install_shim systemd-cat
install_shim journalctl
install_shim timedatectl
install_shim hostnamectl
install_shim localectl
install_shim systemd-firstboot
install_shim resolvectl
install_shim dbus-update-activation-environment 0

ln -sf "$DEST/omartix-services" "$BIN_DEST/omartix-services"
for name in omartix-session omartix-session-up omartix-session-env omartix-user-services; do
  ln -sf "$DEST/session/$name" "$BIN_DEST/$name"
done
chmod +x "$BIN_DEST"/omartix-* 2>/dev/null || true

# ---------------------------------------------------------------------------
# Translated systemd configuration (runit/elogind equivalents)
# ---------------------------------------------------------------------------
echo "==> Applying translated systemd configuration"

# elogind logind.conf — mirror etc/systemd/logind.conf.d/{10-ignore-power-button,20-inhibit-delay}.conf
if [ -d "$ROOT/etc/elogind" ]; then
  touch "$ROOT/etc/elogind/logind.conf"
  grep -q '^HandlePowerKey=' "$ROOT/etc/elogind/logind.conf" 2>/dev/null \
    || echo 'HandlePowerKey=ignore' >> "$ROOT/etc/elogind/logind.conf"
  grep -q '^InhibitDelayMaxSec=' "$ROOT/etc/elogind/logind.conf" 2>/dev/null \
    || echo 'InhibitDelayMaxSec=15' >> "$ROOT/etc/elogind/logind.conf"
fi

# limits.conf — mirror etc/systemd/{system,user}.conf.d nofile limits
if [ -f "$ROOT/etc/security/limits.conf" ] && ! grep -q 'omartix-nofile' "$ROOT/etc/security/limits.conf" 2>/dev/null; then
  cat >> "$ROOT/etc/security/limits.conf" <<'EOF'
# omartix: mirror Omarchy's systemd nofile limits (see etc/systemd/*.conf.d)
* soft nofile 65536
* hard nofile 524288
EOF
fi

# earlyoom — replace systemd-oomd (see etc/systemd/oomd.conf.d/10-omarchy.conf)
if [ -d "$ROOT/etc/default" ] && command -v earlyoom >/dev/null 2>&1; then
  cat > "$ROOT/etc/default/earlyoom" <<'EOF'
# omartix: replace systemd-oomd. Kill one memory hog when free RAM *and* swap
# are both below 10%, and notify over D-Bus when possible.
EARLYOOM_ARGS="-r 60 -m 5,5 -n"
EOF
fi

echo "==> Runit layer installed."
echo "    Enable the full service set with: omartix-services enable-all"
