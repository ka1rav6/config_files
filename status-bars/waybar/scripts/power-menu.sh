#!/bin/bash

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
