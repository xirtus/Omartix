#!/bin/bash
# install-omarchy.sh — Omartix Phase 2: install Omarchy (v4) on top of the
# Artix runit base installed by base-install/.
#
# Run as the user created in Phase 1 (it re-execs itself under sudo):
#
#   cd ~/artix-installer/bridge && ./install-omarchy.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$HERE/..")"
OMARCHY_ROOT="$REPO_ROOT/omarchy-config"
RUNIT_ROOT="$REPO_ROOT/runit"

# Re-exec as root via sudo when not already root.
if (( EUID != 0 )); then
    echo ">> Requesting root privileges..."
    exec sudo -E bash "$0" "$@"
fi

echo "=== Omartix: installing Omarchy (Phase 2) ==="

# ---------------------------------------------------------------------------
# 1. Determine the target user (the owner of this installer copy)
# ---------------------------------------------------------------------------
if [[ -n ${OMARTIX_USER:-} ]]; then
    TARGET_USER="$OMARTIX_USER"
else
    # The installer lives at ~/artix-installer/bridge, so the parent's parent
    # owner is the user. Fall back to the first UID 1000 user.
    OWNER="$(stat -c '%U' "$REPO_ROOT" 2>/dev/null || echo '')"
    if [[ -n $OWNER && $OWNER != root ]]; then
        TARGET_USER="$OWNER"
    else
        TARGET_USER="$(getent passwd | awk -F: '$3 >= 1000 {print $1; exit}')"
    fi
fi

if ! getent passwd "$TARGET_USER" >/dev/null; then
    echo "Error: target user '$TARGET_USER' does not exist" >&2
    exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo ">> Target user: $TARGET_USER ($TARGET_HOME)"
echo ">> Omarchy source: $OMARCHY_ROOT"
echo ">> Runit layer:    $RUNIT_ROOT"

# ---------------------------------------------------------------------------
# 2. Install the runit layer (shims + services) so Omarchy's systemctl calls
#    translate to sv while the rest of the installer runs.
# ---------------------------------------------------------------------------
echo ""
echo ">> [2/8] Installing runit adaptation layer..."
"$RUNIT_ROOT/install.sh"

# ---------------------------------------------------------------------------
# 3. Lay down the Omarchy source (binaries, install scripts, configs, skel)
# ---------------------------------------------------------------------------
echo ""
echo ">> [3/8] Installing Omarchy files..."
"$HERE/install-omarchy-files.sh"

# ---------------------------------------------------------------------------
# 4. Patch the two upstream systemd touchpoints
# ---------------------------------------------------------------------------
echo ""
echo ">> [4/8] Patching session launch (uwsm → omartix-session)"

AUTOSTART="/usr/share/omarchy/default/hypr/autostart.lua"
if [[ -f $AUTOSTART ]]; then
    sed -i '/set systemd vars before starting session services/d' "$AUTOSTART"
    sed -i '/systemctl --user import-environment/d' "$AUTOSTART"
    sed -i '/dbus-update-activation-environment --systemd/d' "$AUTOSTART"
    sed -i 's|hl.exec_cmd("omarchy-provision-first-run")|hl.exec_cmd("omartix-session-up")|' "$AUTOSTART"
    echo "  patched $AUTOSTART"
fi

DESKTOP="/usr/local/share/wayland-sessions/omarchy.desktop"
if [[ -f $DESKTOP ]]; then
    sed -i 's|^Exec=.*|Exec=omartix-session Hyprland|' "$DESKTOP"
    echo "  patched $DESKTOP"
fi

# ---------------------------------------------------------------------------
# 5. Install runit service companions (replace systemd daemons)
# ---------------------------------------------------------------------------
echo ""
echo ">> [5/8] Installing runit service companions..."
"$HERE/patch-packages.sh"

# ---------------------------------------------------------------------------
# 6. Install the Omarchy package set (best-effort; repo + AUR via yay)
# ---------------------------------------------------------------------------
echo ""
echo ">> [6/8] Installing Omarchy packages (this can take a while)..."

install_yay() {
    if command -v yay >/dev/null 2>&1; then
        return 0
    fi
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" 2>/dev/null || \
        git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    ( cd "$tmp"/yay* && makepkg -si --noconfirm )
    rm -rf "$tmp"
}

install_yay

# Repo packages first (fast, single transaction for those available).
REPO_PKGS=""
FAILED_PKGS=""
for pkg in $(grep -vE '^\s*(#|$)' "$OMARCHY_ROOT/install/omarchy-base.packages" "$OMARCHY_ROOT/install/omarchy-other.packages" 2>/dev/null); do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        REPO_PKGS+=" $pkg"
    fi
done

if [[ -n $REPO_PKGS ]]; then
    # shellcheck disable=SC2086
    pacman -S --noconfirm --needed $REPO_PKGS || echo "  (some repo packages failed — continuing)"
fi

# AUR / remaining packages, one at a time so a single miss can't abort the run.
for pkg in $(grep -vE '^\s*(#|$)' "$OMARCHY_ROOT/install/omarchy-base.packages" "$OMARCHY_ROOT/install/omarchy-other.packages" 2>/dev/null); do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        continue
    fi
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        continue  # already attempted above
    fi
    if runuser -u "$TARGET_USER" -- yay -S --noconfirm --needed --removemake "$pkg" >/dev/null 2>&1; then
        echo "  installed $pkg (AUR)"
    else
        FAILED_PKGS+=" $pkg"
    fi
done

if [[ -n $FAILED_PKGS ]]; then
    echo "  WARNING: could not install:$FAILED_PKGS" >&2
    echo "  (these are usually omarchy-pkgs/proprietary/AUR items — see docs/PORTING.md)"
fi

# ---------------------------------------------------------------------------
# 7. Enable the runit system services (replaces install/config/enable-services.sh)
# ---------------------------------------------------------------------------
echo ""
echo ">> [7/8] Enabling runit system services..."
omartix-services enable-all

# ---------------------------------------------------------------------------
# 8. Apply root-side Omarchy setup + finalize the user
# ---------------------------------------------------------------------------
echo ""
echo ">> [8/8] Applying Omarchy system setup + user finalization..."

# Root-side setup (sources install/config|hardware|login|post-install). Its
# systemctl calls go through the shim we installed in step 2.
omarchy-apply-system --install-user "$TARGET_USER" --first-install || {
    echo "  WARNING: omarchy-apply-system reported errors — see /var/log/omarchy-install.log" >&2
}

# Seed the user's home from the now-populated /etc/skel (the user was created
# in Phase 1, before these files existed) and finalize as the user.
echo ">> Seeding $TARGET_HOME from /etc/skel..."
cp -af /etc/skel/. "$TARGET_HOME"/
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

echo ">> Finalizing user ($TARGET_USER)..."
runuser -u "$TARGET_USER" -- env \
    HOME="$TARGET_HOME" \
    USER="$TARGET_USER" \
    LOGNAME="$TARGET_USER" \
    OMARCHY_PATH=/usr/share/omarchy \
    OMARCHY_INSTALL=/usr/share/omarchy/install \
    OMARCHY_SETUP_CONTEXT=runtime \
    OMARCHY_LOG_TO_STDOUT=1 \
    omarchy-provision-user --force --first-install || {
    echo "  WARNING: user finalization reported errors — rerun 'omarchy-provision-user --force' after login" >&2
}

echo ""
echo "=== OMARTIX INSTALL COMPLETE ==="
echo ""
echo "Reboot now. SDDM will start and log you into the Omartix desktop."
echo "On first login, graphical first-run setup completes automatically."
echo ""
echo "  reboot"
