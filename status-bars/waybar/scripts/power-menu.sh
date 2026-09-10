#!/bin/bash
#
# Power menu, reached from the waybar 󰐥 button and from SUPER+M.
#
# Prefers wlogout (a row of large buttons). Falls back to the old wofi
# dmenu list if wlogout isn't installed, so the bind never dead-ends.
#
# Both entry points run this script, so pressing SUPER+M while the menu is
# already up would stack a second instance on the layer. Toggle instead:
# a running wlogout means the user wants it gone.

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

# --- fallback: original wofi menu ---------------------------------------

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
