#!/bin/bash
#
# SUPER + SHIFT + A -- stash the focused window away, and bring it back, on one
# key.
#
# Semantics, a LIFO stash toggle:
#   * this workspace has stashed windows -> restore the most recent one
#   * otherwise                          -> stash the focused window
#
# The scoping is the load-bearing part. Every stashed window is recorded
# together with the workspace it was hidden *from*, and a press only ever looks
# at the entries belonging to the workspace you are standing on. So the key can
# never reach into what you stashed on workspace 3 while you are on workspace 1
# -- and, just as importantly, can never yank your focus over to workspace 3 to
# hand it back, which is what the old global oldest-first stack did.
#
# Windows all live on the one `special:minimized` workspace regardless; that is
# just where Hyprland parks them, and it is never shown. The per-workspace
# behaviour comes from the state file, not from the compositor.

set -u

STATE="$HOME/.cache/hyprland-minimized-windows"
mkdir -p "$(dirname "$STATE")"
touch "$STATE"

# The *real* workspace of the focused monitor. Deliberately not the focused
# window's workspace: while a scratchpad is showing, that would be
# "special:scratch", and the stash has no business being keyed to a scratchpad.
current_ws=$(hyprctl monitors -j | jq -r 'first(.[] | select(.focused)) | .activeWorkspace.name')
if [ -z "$current_ws" ] || [ "$current_ws" = "null" ]; then
    exit 0
fi

# Drop entries whose window was closed while it was stashed, so a dead address
# can never shadow a live one further down the stack.
live=$(hyprctl clients -j | jq -r '.[].address')
pruned=$(mktemp)
while IFS='|' read -r address ws_name; do
    [ -z "$address" ] && continue
    if printf '%s\n' "$live" | grep -qxF "$address"; then
        printf '%s|%s\n' "$address" "$ws_name" >>"$pruned"
    fi
done <"$STATE"
mv "$pruned" "$STATE"

# The most recently stashed window belonging to this workspace, by line number.
# awk rather than grep so the workspace name is compared as a whole field --
# a named workspace is free to contain regex metacharacters.
line=$(awk -F'|' -v ws="$current_ws" '$2 == ws { n = NR } END { if (n) print n }' "$STATE")

# ---------------------------------------------------------------------------
# Something stashed here -> restore it
# ---------------------------------------------------------------------------
if [ -n "$line" ]; then
    address=$(sed -n "${line}p" "$STATE" | cut -d'|' -f1)

    # Workspace selector: numbers stay bare, named ones need the name: prefix.
    if [[ "$current_ws" =~ ^[0-9]+$ ]]; then
        target="$current_ws"
    else
        target="\"name:$current_ws\""
    fi

    # Focus the hidden window, pull it back, and re-focus it there -- as ONE
    # strictly ordered Lua chunk, so separate IPC connections cannot interleave.
    hyprctl eval "
local w = hl.get_window(\"address:$address\")
if w == nil then return end
hl.dispatch(hl.dsp.focus({ window = w }))
hl.dispatch(hl.dsp.window.move({ workspace = $target }))
hl.dispatch(hl.dsp.focus({ window = w }))
for _, monitor in ipairs(hl.get_monitors()) do
    local shown = monitor.active_special_workspace
    if shown ~= nil and shown.name == \"special:minimized\" then
        monitor:set_special_workspace(\"\")
    end
end
" >/dev/null

    sed -i "${line}d" "$STATE"
    exit 0
fi

# ---------------------------------------------------------------------------
# Nothing stashed here -> stash the focused window
# ---------------------------------------------------------------------------
window=$(hyprctl activewindow -j)
address=$(echo "$window" | jq -r '.address')
ws_name=$(echo "$window" | jq -r '.workspace.name')

# Nothing focused.
if [ "$address" = "0x0" ] || [ "$address" = "null" ] || [ -z "$address" ]; then
    exit 0
fi

# Never stash a scratchpad window, or one already stashed. Those have their own
# toggle keys, and hiding them here would strand them outside it.
case "$ws_name" in
    special:*) exit 0 ;;
esac

echo "$address|$ws_name" >>"$STATE"

# Unfullscreen (if needed) and hide the focused window in ONE atomic, strictly
# ordered Lua chunk, so IPC can never reorder the steps. Remaining tiled
# windows reflow automatically.
#
# The trailing loop is what actually makes this a *stash* rather than a move.
# Dropping a window onto a special workspace makes that workspace VISIBLE, and
# `silent` does not prevent it -- silent only stops focus from following. A
# shown special workspace then overlays every workspace you switch to, so the
# window you just stashed would hover over workspaces 2, 3, 4... until something
# toggled it off. Clearing it per-monitor puts it back out of sight; the window
# stays parked there, it is just no longer on screen.
#
# monitor:set_special_workspace("") rather than the toggle_special dispatcher
# because the dispatcher only ever acts on the FOCUSED monitor, and on a
# two-monitor setup the stash can surface on the other one.
hyprctl eval "
local w = hl.get_active_window()
if w == nil then return end
if w.fullscreen ~= 0 then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"unset\" }))
end
hl.dispatch(hl.dsp.window.move({ workspace = \"special:minimized\", silent = true }))
for _, monitor in ipairs(hl.get_monitors()) do
    local shown = monitor.active_special_workspace
    if shown ~= nil and shown.name == \"special:minimized\" then
        monitor:set_special_workspace(\"\")
    end
end
" >/dev/null
