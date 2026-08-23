#!/bin/bash

STATE="$HOME/.cache/hyprland-minimized-windows"

# Restore minimized windows oldest-first until one succeeds.
while [ -f "$STATE" ] && [ -s "$STATE" ]; do
    entry=$(head -n 1 "$STATE")

    address=$(echo "$entry" | cut -d'|' -f1)
    ws_name=$(echo "$entry" | cut -d'|' -f2)

    # Drop the entry if the window was closed while minimized,
    # then try the next one.
    count=$(hyprctl clients -j | jq -r --arg a "$address" '[.[] | select(.address == $a)] | length')
    if [ "$count" = "0" ]; then
        sed -i '1d' "$STATE"
        continue
    fi

    # Build the workspace selector: numbers stay bare, special
    # workspaces are quoted as-is, named ones need the name: prefix.
    if [[ "$ws_name" =~ ^[0-9]+$ ]]; then
        target="$ws_name"
    elif [[ "$ws_name" == special:* ]]; then
        target="\"$ws_name\""
    else
        target="\"name:$ws_name\""
    fi

    # Focus the hidden window, pull it back to its original workspace,
    # and re-focus it there — all as ONE strictly ordered Lua chunk so
    # separate IPC connections can never interleave.
    hyprctl eval "
local w = hl.get_window(\"address:$address\")
if w == nil then return end
hl.dispatch(hl.dsp.focus({ window = w }))
hl.dispatch(hl.dsp.window.move({ workspace = $target }))
hl.dispatch(hl.dsp.focus({ window = w }))
" >/dev/null

    sed -i '1d' "$STATE"
    break
done
