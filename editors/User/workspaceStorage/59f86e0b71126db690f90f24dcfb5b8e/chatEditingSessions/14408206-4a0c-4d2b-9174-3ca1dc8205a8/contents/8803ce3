#!/bin/sh

if pgrep -x waybar >/dev/null 2>&1; then
    pkill -x waybar
else
    nohup waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/tmp/waybar.log 2>&1 &
fi
