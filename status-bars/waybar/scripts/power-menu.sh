#!/bin/bash
# =============================================================================
# power-menu.sh — the session's one power menu.
# =============================================================================
# Called from SUPER + M (~/.config/hypr/bindings.lua). There used to be a
# second entry point on a waybar button, and the two did not agree: the bind
# and the button both ran this script, but the Control Center's power button
# opened the Quickshell menu instead, so the desktop had two different power
# UIs depending on where you clicked. Now every route ends up in the same
# place.
#
# ORDER OF PREFERENCE
#   1. The Quickshell power menu. Same visual language as the rest of the
#      shell, and the destructive actions (log out, restart, shut down) arm
#      before they commit, which wlogout's five big buttons do not.
#   2. wlogout, if Quickshell is not running.
#   3. A wofi list, if wlogout is missing too.
#
# The fallbacks matter: rebooting is exactly the thing you may want when the
# shell has crashed, so this must never dead-end.
# -----------------------------------------------------------------------------

# --- 1. Quickshell -----------------------------------------------------------
# `ipc call power toggle` returns non-zero if the shell is not running, so this
# falls through cleanly.
if command -v quickshell >/dev/null 2>&1; then
    if quickshell ipc call power toggle >/dev/null 2>&1; then
        exit 0
    fi
fi

# --- 2. wlogout --------------------------------------------------------------
# Pressing SUPER+M while it is already up should close it, not stack a second
# instance on the overlay layer.
if pkill -x wlogout 2>/dev/null; then
    exit 0
fi

if command -v wlogout >/dev/null 2>&1; then
    # The five actions sit in one row, inset to a centred band rather than
    # filling the screen. Margins are logical pixels -- the panel is
    # 2880x1800 at scale 1.5, so the usable canvas is 1920x1200.
    #
    # -p layer-shell keeps it on the overlay layer so the layer rule in
    #    rules.lua (blur + dim_around) applies.
    exec wlogout -b 5 -p layer-shell \
        -T 440 -B 440 -L 220 -R 220 \
        -c 14 -r 14
fi

# --- 3. wofi -----------------------------------------------------------------
options="󰌾  Lock
󰍃  Logout
󰜉  Restart
󰐥  Shutdown"

chosen=$(printf '%s\n' "$options" | wofi \
    --dmenu \
    --prompt "Power" \
    --width 300 \
    --height 250 \
    --cache-file /dev/null)

case "$chosen" in
"󰌾  Lock")
    hyprlock
    ;;

"󰍃  Logout")
    hyprctl dispatch 'hl.dsp.exit()'
    ;;

"󰜉  Restart")
    systemctl reboot
    ;;

"󰐥  Shutdown")
    systemctl poweroff
    ;;
esac
