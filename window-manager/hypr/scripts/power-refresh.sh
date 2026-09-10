#!/bin/sh
#
# Drop the internal panel to 60 Hz on battery, put it back to 120 Hz on AC.
#
#   power-refresh.sh apply    apply once for the current power state
#   power-refresh.sh watch    apply, then re-apply on every power-supply event
#
# Why: eDP-1 is 2880x1800 at 120 Hz with a 1.5x scale. That is the single most
# expensive thing the compositor does on this machine, and on battery it buys
# nothing you notice -- halving the refresh rate roughly halves the per-second
# render work for the whole desktop.
#
# `watch` is event-driven off udev, not a poll loop, so it costs nothing while
# the power state is not changing.
#
# Started by autostart.lua. Run `power-refresh.sh apply` by hand after changing
# the modes below.

set -eu

INTERNAL="eDP-1"
AC_ONLINE="/sys/class/power_supply/ADP1/online"

# Keep these in sync with monitors.lua -- position and scale have to be repeated
# because hl.monitor replaces the whole entry rather than patching the mode.
MODE_AC="2880x1800@120"
MODE_BATTERY="2880x1800@60"
POSITION="auto-right"
SCALE="1.5"

on_ac() {
    # Missing file (desktop, or a kernel that names it differently) reads as
    # "on AC", which is the safe default: full refresh rate.
    [ ! -r "$AC_ONLINE" ] || [ "$(cat "$AC_ONLINE")" = "1" ]
}

apply() {
    if on_ac; then
        mode="$MODE_AC"
    else
        mode="$MODE_BATTERY"
    fi

    # Only touch the monitor if the rate actually needs to change; re-applying
    # an identical mode still makes Hyprland re-do a modeset, which flickers.
    want_hz=${mode##*@}
    have_hz=$(hyprctl monitors -j 2>/dev/null \
        | python3 -c "
import json,sys
try:
    for m in json.load(sys.stdin):
        if m['name'] == '$INTERNAL':
            print(round(m['refreshRate'])); break
except Exception:
    pass
" 2>/dev/null || true)

    [ "$want_hz" = "$have_hz" ] && return 0

    hyprctl eval "hl.monitor({
        output   = '$INTERNAL',
        mode     = '$mode',
        position = '$POSITION',
        scale    = $SCALE,
    })" >/dev/null 2>&1 || true
}

case "${1:-apply}" in
    apply)
        apply
        ;;
    watch)
        apply
        # Any power_supply event: AC plugged, unplugged, battery state change.
        # Re-applying is cheap and idempotent thanks to the guard in apply().
        udevadm monitor --udev --subsystem-match=power_supply 2>/dev/null \
        | while read -r _; do
            apply
        done
        ;;
    *)
        echo "usage: power-refresh.sh [apply|watch]" >&2
        exit 1
        ;;
esac
