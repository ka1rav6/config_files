#!/bin/sh

sleep 2

exec /home/kairav/.local/bin/nwg-dock-hyprland \
    -d \
    -hl top \
    -hd 0 \
    -i 48 \
    -mb 10 \
    -ml 8 \
    -mr 8 \
    -c "nwg-drawer -wm hyprland"
