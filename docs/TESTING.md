# Testing Omartix

The installer targets a real Artix (runit) machine, so most of this can only be
validated on hardware or in a VM. This is the checklist for a full
bring-up pass.

## 1. Phase 1 — base install (Artix runit ISO, UEFI)

- [ ] Boot the Artix **runit** ISO (UEFI), connect via `connmanctl`.
- [ ] `base-install/install.sh` partitions the disk (verify `lsblk` shows the
      EFI + LUKS partitions).
- [ ] LUKS opens and BTRFS subvolumes mount (check `/mnt` layout before chroot).
- [ ] Chroot completes: timezone, locale, hostname, user, sudo.
- [ ] Reboot reaches a TTY login; LUKS passphrase prompt appears.
- [ ] `NetworkManager` is up (`nmcli`/`nmtui` connects).

## 2. Phase 2 — Omarchy install

- [ ] `bridge/install-omarchy.sh` runs to completion as root.
- [ ] `/usr/share/omartix/runit/` and `/usr/bin/omarchy-*` exist.
- [ ] `omartix-services enable-all` reports `enabled` for the core services
      (cupsd, avahi-daemon, docker, NetworkManager, sddm, earlyoom, bluetoothd, …).
- [ ] `systemctl status NetworkManager` (via the shim) shows `run:`.
- [ ] `/usr/share/omarchy/default/hypr/autostart.lua` calls `omartix-session-up`
      (not the systemd import lines).
- [ ] `/usr/local/share/wayland-sessions/omarchy.desktop` `Exec=` is
      `omartix-session Hyprland`.
- [ ] `omarchy-apply-system` and `omarchy-provision-user` complete (watch
      `/var/log/omarchy-install.log`).

## 3. Session + user services

- [ ] Reboot; SDDM starts and logs into the Hyprland session.
- [ ] `pgrep -f runsvdir` shows the per-user `runsvdir`.
- [ ] `SVDIR=~/.local/share/omartix/runit/enabled sv status` shows `run:` for
      `bt-agent`, `omarchy-fcitx5`, `omarchy-sleep-lock`, etc.
- [ ] First-run provisioning ran (`~/.local/state/omarchy/done/first-run-user`
      exists).
- [ ] Bluetooth pairing agent, sleep lock, and input method behave.

## 4. Services & maintenance

- [ ] `omarchy dns Cloudflare` applies via NetworkManager.
- [ ] `omarchy update` works (pacman path; snapshot taken if configured).
- [ ] Snapper creates timeline snapshots (hourly) and cleans up.
- [ ] ZRAM swap is active (`swapon`).
- [ ] `omarchy reboot` / `omarchy shutdown` work (the `systemd-run` shim path).

## 5. Edge cases (best-effort, expect iteration)

- [ ] Deferred provisioning (`omarchy-provision-owner`) asks for the user on tty1
      before SDDM, then hands off to SDDM.
- [ ] Factory reset finish runs on first boot after a reset.
- [ ] Unencrypted install drops the first-boot autologin after one boot.

## Where to file issues

Note which step failed, the exact command, and `/var/log/omarchy-install.log`
or `~/.local/state/omartix/` contents.
