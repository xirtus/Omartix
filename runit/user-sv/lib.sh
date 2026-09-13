# Shared helpers for Omartix per-user runit services.
# Sourced by each user-sv/<name>/run script.

OMARTIX_RUNIT_DIR="${OMARTIX_RUNIT_DIR:-/usr/share/omartix/runit}"
OMARTIX_SESSION_ENV="${OMARTIX_SESSION_ENV:-$HOME/.local/state/omartix/session-env}"

# Wait for the session wrapper to publish the base environment, then source it.
# Returns non-zero after ~2 minutes so a TTY-only session doesn't spin forever.
wait_session_env() {
  local i=0
  while [ ! -r "$OMARTIX_SESSION_ENV" ]; do
    sleep 1
    i=$((i + 1))
    [ "$i" -gt 120 ] && return 1
  done
  . "$OMARTIX_SESSION_ENV"
  return 0
}

# Wait for the compositor to publish WAYLAND_DISPLAY (written by
# omartix-session-up), then (re)source the environment. Returns non-zero after
# ~5 minutes.
wait_wayland() {
  local i=0
  while [ ! -r "$OMARTIX_SESSION_ENV" ] || ! grep -q '^WAYLAND_DISPLAY=' "$OMARTIX_SESSION_ENV" 2>/dev/null; do
    sleep 1
    i=$((i + 1))
    [ "$i" -gt 300 ] && return 1
  done
  . "$OMARTIX_SESSION_ENV"
  return 0
}
