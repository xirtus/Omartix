#!/bin/bash
# install-omarchy-files.sh — lay the vendored Omarchy source into the installed
# system, implementing the build-time map from docs/file-layout.md without the
# Arch omarchy/omarchy-settings packages (this is a source install).
#
# Must run as root. The vendored tree lives at ../omarchy-config relative to
# this script.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(realpath "$HERE/../omarchy-config")"
DEST="/usr/share/omarchy"

if [[ ! -d $SRC/bin ]]; then
    echo "Error: omarchy-config source not found at $SRC" >&2
    exit 1
fi

echo "==> Installing Omarchy source to $DEST"
install -d -m 0755 "$DEST"

# Full mirror under /usr/share/omarchy (bin/, install/, migrations/, themes/,
# shell/, version, config/, default/, applications/, logo/icon, etc.).
# Skip repo-only/docs trees and the systemd/uwsm trees we replace with runit.
rsync -a --delete \
  --exclude '.git' \
  --exclude '.github' \
  --exclude '.editorconfig' \
  --exclude '.gitignore' \
  --exclude '.luarc.json' \
  --exclude 'AGENTS.md' \
  --exclude 'CLAUDE.md' \
  --exclude 'README.md' \
  --exclude '.omartix-upstream' \
  --exclude 'docs' \
  --exclude 'manual' \
  --exclude 'plans' \
  --exclude 'agents' \
  --exclude 'test' \
  --exclude 'default/systemd' \
  --exclude 'default/uwsm' \
  --exclude 'etc/systemd' \
  "$SRC"/ "$DEST"/

# ---------------------------------------------------------------------------
# Runtime binaries onto PATH (production installs expect /usr/bin/omarchy-*).
# ---------------------------------------------------------------------------
echo "==> Installing omarchy-* binaries to /usr/bin"
install -d -m 0755 /usr/bin
for bin in "$SRC"/bin/omarchy-*; do
  [[ -f $bin && -x $bin ]] || continue
  install -m 0755 "$bin" /usr/bin/
done

# ---------------------------------------------------------------------------
# /etc/skel seeding (new users) + resync source
# ---------------------------------------------------------------------------
echo "==> Seeding /etc/skel"
install -d -m 0755 /etc/skel/.config
cp -a "$SRC"/config/. /etc/skel/.config/

install -d -m 0755 /etc/skel/.local/share/applications
cp -a "$SRC"/applications/*.desktop /etc/skel/.local/share/applications/ 2>/dev/null || true

install -d -m 0755 /etc/skel/.local/share/nautilus-python/extensions
cp -a "$SRC"/default/nautilus-python/extensions/. /etc/skel/.local/share/nautilus-python/extensions/ 2>/dev/null || true

install -d -m 0755 /etc/skel/.local/state/omarchy/toggles/hypr
cp -a "$SRC"/default/hypr/toggles/. /etc/skel/.local/state/omarchy/toggles/hypr/ 2>/dev/null || true

install -d -m 0755 /etc/skel/.local/state/tensaku
cp -a "$SRC"/default/tensaku/state.toml /etc/skel/.local/state/tensaku/ 2>/dev/null || true

install -d -m 0755 /etc/skel/.config/omarchy/branding
[[ -f $SRC/icon.txt ]] && cp -a "$SRC/icon.txt" /etc/skel/.config/omarchy/branding/about.txt
[[ -f $SRC/logo.txt ]] && cp -a "$SRC/logo.txt" /etc/skel/.config/omarchy/branding/screensaver.txt

install -m 0644 "$SRC"/default/bashrc /etc/skel/.bashrc

# ---------------------------------------------------------------------------
# System paths (environment, fonts, xdg-terminal, mimeapps, sddm, plymouth)
# ---------------------------------------------------------------------------
echo "==> Installing system defaults"
install -d -m 0755 /usr/lib/environment.d
cp -a "$SRC"/default/environment.d/. /usr/lib/environment.d/ 2>/dev/null || true

install -d -m 0755 /usr/share/fontconfig/conf.avail
cp -a "$SRC"/default/fontconfig/conf.avail/50-omarchy.conf /usr/share/fontconfig/conf.avail/ 2>/dev/null || true
mkdir -p /etc/fonts/conf.d
ln -sf /usr/share/fontconfig/conf.avail/50-omarchy.conf /etc/fonts/conf.d/50-omarchy.conf 2>/dev/null || true

install -d -m 0755 /usr/share/xdg-terminal-exec
cp -a "$SRC"/default/xdg-terminal-exec/. /usr/share/xdg-terminal-exec/ 2>/dev/null || true

install -d -m 0755 /usr/share/applications
cp -a "$SRC"/default/applications/mimeapps.list /usr/share/applications/ 2>/dev/null || true

install -d -m 0755 /usr/share/fonts/omarchy
cp -a "$SRC"/default/fonts/omarchy/. /usr/share/fonts/omarchy/ 2>/dev/null || true

install -d -m 0755 /usr/share/sddm/themes
cp -a "$SRC"/default/sddm/omarchy /usr/share/sddm/themes/omarchy 2>/dev/null || true
cp -a "$SRC"/default/sddm/hyprland.lua /usr/share/sddm/hyprland.lua 2>/dev/null || true

install -d -m 0755 /usr/share/plymouth/themes
cp -a "$SRC"/default/plymouth/omarchy /usr/share/plymouth/themes/omarchy 2>/dev/null || true

install -d -m 0755 /usr/share/libalpm/hooks
cp -a "$SRC"/default/libalpm/hooks/. /usr/share/libalpm/hooks/ 2>/dev/null || true

install -d -m 0755 /etc/snapper/config-templates
cp -a "$SRC"/default/snapper/root /etc/snapper/config-templates/omarchy 2>/dev/null || true

# ---------------------------------------------------------------------------
# Icons + branding
# ---------------------------------------------------------------------------
echo "==> Installing icons and branding"
install -d -m 0755 /usr/share/pixmaps
[[ -f $SRC/icon.png ]] && cp -a "$SRC/icon.png" /usr/share/pixmaps/omarchy.png

install -d -m 0755 /usr/share/icons/hicolor/256x256/apps
[[ -f $SRC/icon.png ]] && cp -a "$SRC/icon.png" /usr/share/icons/hicolor/256x256/apps/omarchy.png

# ---------------------------------------------------------------------------
# /etc drop-ins (owned outright by omarchy-settings upstream)
# ---------------------------------------------------------------------------
echo "==> Installing /etc drop-ins"
# etc/systemd is excluded (systemd-only); the runit layer already translated
# the elogind/earlyoom/limits equivalents.
rsync -a --exclude 'systemd' "$SRC"/etc/ /etc/

echo "==> Omarchy source install complete"
