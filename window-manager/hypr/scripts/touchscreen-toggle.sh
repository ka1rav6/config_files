#!/usr/bin/env bash
# =============================================================================
# touchscreen-toggle.sh — the session side of the touchscreen toggle.
# =============================================================================
# Called by ~/.config/hypr/touchscreen.lua, which binds:
#
#     switch:on:<tablet switch>   -> touchscreen-toggle.sh on
#     switch:off:<tablet switch>  -> touchscreen-toggle.sh off
#     SUPER + SHIFT + D           -> touchscreen-toggle.sh toggle
#     hyprland.start              -> touchscreen-toggle.sh reconcile
#
# This script is UNPRIVILEGED and stays in $HOME, exactly like lid.sh. All it
# does is decide what should happen and then ask the root-owned helper to do the
# one privileged part. Everything about why the privileged part exists, and the
# interrupt measurements behind it, is documented in scripts/touchscreen.sh.
#
# ---------------------------------------------------------------------------
# THE DEFAULT IS OFF, AND THAT IS A DELIBERATE TRADE
#
# The digitizer costs ~41,600 interrupts/sec whenever it is attached, whether or
# not anyone is touching it, and holds one core out of deep idle. There is no
# setting that makes it cheap while attached (see touchscreen.sh), so the only
# question left is WHEN it should be attached.
#
# This machine is a flip convertible, which makes the answer unusually clean:
#
#   * Folded into tablet or tent mode, touch is the only input there is. The
#     tablet-mode switch fires, and this attaches the digitizer.
#   * Open as a laptop, there is a keyboard and a touchpad, and touch is a
#     convenience rather than a necessity. It stays detached and costs nothing.
#   * Wanting it anyway in laptop mode is one keypress: SUPER + SHIFT + D.
#
# So touch is never unavailable -- it is either already on because of the form
# factor, or one key away. Set START_ENABLED=true in touchscreen.lua if the
# keypress is still one too many; the cost of that choice is the figure above.
# =============================================================================

set -uo pipefail

HELPER="/usr/local/lib/hypr/touchscreen"
DEVICE="${HYPR_TOUCHSCREEN_DEVICE:-ELAN2514:00}"
DEVICE_DIR="/sys/bus/i2c/devices/i2c-${DEVICE}"

# What the session should settle on at startup, overridden by touchscreen.lua
# exporting HYPR_TOUCHSCREEN_START. Kept as an env var rather than a second
# constant so there is exactly one place (the .lua) to change it.
START_ENABLED="${HYPR_TOUCHSCREEN_START:-false}"

# --- State, read without privileges ------------------------------------------
# The `driver` symlink is world-readable, so the session can always tell whether
# the digitizer is attached without going through sudo. Only CHANGING it needs
# the helper.
is_bound() { [[ -e "$DEVICE_DIR/driver" ]]; }
is_present() { [[ -d "$DEVICE_DIR" ]]; }

notify() {
    # Notifications are feedback for the MANUAL toggle. A device that silently
    # appears and disappears is indistinguishable from a broken one, and this is
    # a key the user has just pressed, so it deserves an answer.
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send --app-name=Hyprland --expire-time=2000 \
        --icon="${2:-input-tablet}" "Touchscreen" "$1" 2>/dev/null || true
}

# Ask the helper to do the privileged part.
#
# `sudo -n` is non-interactive on purpose: if the drop-in from
# install-touchscreen.sh is missing, this must fail immediately rather than
# block a keybind on a password prompt that has nowhere to appear. A compositor
# keybind has no terminal.
helper() {
    if [[ ! -x "$HELPER" ]]; then
        notify "Helper not installed. Run: sudo ~/.config/hypr/scripts/install-touchscreen.sh" dialog-error
        echo "[touchscreen] $HELPER is missing -- run install-touchscreen.sh" >&2
        return 1
    fi
    if ! sudo -n "$HELPER" "$1" >/dev/null 2>&1; then
        notify "Could not turn the touchscreen $1 (sudo rule missing?)" dialog-error
        echo "[touchscreen] sudo -n $HELPER $1 failed" >&2
        return 1
    fi
    return 0
}

# --- Actions -----------------------------------------------------------------

do_on() {
    is_bound && return 0
    helper on || return 1
}

do_off() {
    is_bound || return 0
    helper off || return 1
}

case "${1:-}" in
    on)
        # Tablet mode engaged. Quiet: the flip itself is the feedback, and a
        # notification on every rotation of the screen would be noise.
        do_on
        ;;

    off)
        # Back to laptop mode. Also quiet, same reasoning.
        do_off
        ;;

    toggle)
        if ! is_present; then
            notify "No touchscreen on this machine" dialog-error
            exit 1
        fi
        if is_bound; then
            do_off && notify "Off — saving ~41k interrupts/sec" input-tablet-symbolic
        else
            do_on && notify "On" input-tablet
        fi
        ;;

    reconcile)
        # Startup, and after a compositor restart. A switch event never arrives
        # for a state that was already true, so without this the digitizer would
        # keep whatever state the previous session left it in -- including
        # attached-and-storming after a crash.
        #
        # Note this runs on EVERY `hyprctl reload`, which is why it is a
        # no-op when the state already matches.
        #
        # SILENT IF THE HELPER IS NOT INSTALLED YET. This path is not something
        # the user asked for -- it fires at login and on every reload -- so a
        # missing install must not throw a notification each time. The manual
        # toggle, which IS a deliberate keypress, still reports the problem.
        [[ -x "$HELPER" ]] || {
            echo "[touchscreen] $HELPER not installed, nothing to reconcile" >&2
            exit 0
        }
        if [[ "$START_ENABLED" == "true" ]]; then
            do_on
        else
            do_off
        fi
        ;;

    status)
        if ! is_present; then echo "absent"
        elif is_bound; then echo "on"
        else echo "off"
        fi
        ;;

    *)
        echo "usage: ${0##*/} on|off|toggle|reconcile|status" >&2
        exit 2
        ;;
esac
