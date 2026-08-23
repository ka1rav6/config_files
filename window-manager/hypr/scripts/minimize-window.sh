#!/bin/bash

STATE="$HOME/.cache/hyprland-minimized-windows"
mkdir -p "$HOME/.cache"

window=$(hyprctl activewindow -j)

address=$(echo "$window" | jq -r '.address')
ws_name=$(echo "$window" | jq -r '.workspace.name')

# Don't minimize if there is no active window
if [ "$address" = "0x0" ] || [ "$address" = "null" ]; then
    exit 0
fi

# Don't minimize a window that is already stashed away
if [ "$ws_name" = "special:minimized" ]; then
    exit 0
fi

# Save address + original workspace name before hiding it
echo "$address|$ws_name" >>"$STATE"

# Unfullscreen (if needed) and hide the focused window in ONE atomic,
# strictly ordered Lua chunk, so IPC can never reorder the steps.
# Remaining tiled windows reflow automatically.
hyprctl eval "
local w = hl.get_active_window()
if w == nil then return end
if w.fullscreen ~= 0 then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"unset\" }))
end
hl.dispatch(hl.dsp.window.move({ workspace = \"special:minimized\" }))
" >/dev/null
