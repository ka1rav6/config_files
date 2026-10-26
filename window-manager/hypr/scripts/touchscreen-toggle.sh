#!/usr/bin/env bash
# =============================================================================
# touchscreen-toggle.sh — SUPER + SHIFT + D, and the notification that answers it.
# =============================================================================
# Called by ~/.config/hypr/touchscreen.lua. Everything this script used to
# decide now lives in hypr-digitizerd, which owns the state; all that is left
# is to ask it to flip and to say out loud what happened.
#
# WHY THERE IS STILL A SHELL HERE AT ALL
#   Notifications are feedback for a key the user has just pressed -- a device
#   that silently appears and disappears is indistinguishable from a broken
#   one. One fork per deliberate keypress is a different thing entirely from
#   the fork-per-fold chain this replaced, and notify-send is a shell's job.
#
# WHY NOT `sudo -n` ANY MORE
#   There is no root helper to call. hypr-digitizer-ctl talks to a unix socket
#   owned by this user. See ~/.config/hypr/daemons/hypr-digitizerd.c.
# =============================================================================

set -uo pipefail

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send --app-name=Hyprland --expire-time=2000 \
        --icon="${2:-input-tablet}" "Touchscreen" "$1" 2>/dev/null || true
}

if ! command -v hypr-digitizer-ctl >/dev/null 2>&1; then
    notify "Daemon not installed. Run: sudo ~/.config/hypr/scripts/install-touchscreen.sh" dialog-error
    exit 1
fi

# The client prints the resulting state, or fails with a message explaining
# that the daemon is unreachable -- which goes to the Hyprland log, since a
# keybind has no terminal.
state=$(hypr-digitizer-ctl toggle 2>&1) || {
    notify "Could not reach hypr-digitizerd (is the service running?)" dialog-error
    echo "[touchscreen] $state" >&2
    exit 1
}

case "$state" in
    on)     notify "On" input-tablet ;;
    off)    notify "Off — saving ~41k interrupts/sec" input-tablet-symbolic ;;
    absent) notify "No touchscreen on this machine" dialog-error; exit 1 ;;
    *)      notify "Unexpected reply: $state" dialog-error; exit 1 ;;
esac
