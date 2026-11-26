#!/usr/bin/env bash
# Close the gaps between occupied workspaces (SUPER + Z, see bindings.lua).
#
#   docked (HDMI-A-1 + eDP-1)
#     external packs UP from 1:      1 4 6  ->  1 2 3
#     laptop   packs DOWN to 10:     8 10   ->  9 10
#   single screen (laptop only, or mirrored onto the external)
#     packs up from 1:               1 4 6 9 -> 1 2 3 4
#
# The split mirrors sync-workspaces.sh: 1-7 belong to the external, 8-10 to the
# laptop, so packing each side toward its own end keeps every workspace inside
# the range its monitor rule expects.
#
# Hyprland cannot renumber a workspace -- `renameworkspace` only changes the
# label, and every SUPER+<n> bind targets the id -- so "workspace 4 becomes 2"
# really means "every window on 4 moves to 2". Moves are silent and ordered so
# a window never lands on a workspace that still holds something waiting to
# move. Focus is put back where it was afterwards.
#
# All of it runs as ONE `hyprctl eval` chunk, so nothing can interleave with
# the moves halfway through.
#
#   compact-workspaces.sh            do it
#   compact-workspaces.sh --dry-run  print the plan, move nothing

set -uo pipefail

EXTERNAL="HDMI-A-1"
INTERNAL="eDP-1"
TOP=10

dry=false
case "${1:-}" in
    -n|--dry-run) dry=true ;;
    "") ;;
    *) echo "usage: ${0##*/} [--dry-run]" >&2; exit 2 ;;
esac

# Unquoted heredoc on purpose: only the four values above are substituted.
# The Lua below must not contain a dollar sign or a backtick.
read -r -d '' lua <<LUA
local EXTERNAL, INTERNAL, TOP, DRY = "$EXTERNAL", "$INTERNAL", $TOP, $dry

local monitors, focused = {}, nil
local active_before = {}
for _, m in ipairs(hl.get_monitors()) do
    monitors[m.name] = m
    if m.focused then focused = m end
    if m.active_workspace and m.active_workspace.id then
        active_before[m.name] = m.active_workspace.id
    end
end
local docked = monitors[EXTERNAL] ~= nil and monitors[INTERNAL] ~= nil
local active_win = hl.get_active_window()

-- Occupied, ordinary (non-special, positive id) workspaces per monitor.
local by_mon = {}
for _, ws in ipairs(hl.get_workspaces()) do
    if not ws.special and ws.id and ws.id > 0 and (ws.windows or 0) > 0 and ws.monitor then
        local name = ws.monitor.name
        by_mon[name] = by_mon[name] or {}
        table.insert(by_mon[name], ws.id)
    end
end

-- Plan: src id -> dst id.
local map, owner, pending = {}, {}, {}
for mon, ids in pairs(by_mon) do
    if docked and mon == INTERNAL then
        table.sort(ids, function(a, b) return a > b end)
        for i, id in ipairs(ids) do map[id] = TOP - i + 1 end
    else
        table.sort(ids)
        for i, id in ipairs(ids) do map[id] = i end
    end
    for _, id in ipairs(ids) do
        local dst = map[id]
        if dst < 1 then error("too many workspaces on " .. mon .. " to pack below " .. TOP) end
        if owner[dst] then
            error("workspace " .. dst .. " is wanted by both " .. owner[dst] .. " and " .. mon .. ", nothing moved")
        end
        owner[dst] = mon
        if dst ~= id then table.insert(pending, { src = id, dst = dst, orig = id }) end
    end
end

-- Windows per workspace, top-left first, so a re-tiled workspace comes out in
-- roughly the reading order it had.
local windows_on = {}
for _, w in ipairs(hl.get_windows()) do
    local ws = w.workspace
    if ws and ws.id and not ws.special then
        windows_on[ws.id] = windows_on[ws.id] or {}
        table.insert(windows_on[ws.id], w)
    end
end
for _, list in pairs(windows_on) do
    table.sort(list, function(a, b)
        if a.at.y ~= b.at.y then return a.at.y < b.at.y end
        return a.at.x < b.at.x
    end)
end

local function move_all(src, dst)
    for _, w in ipairs(windows_on[src] or {}) do
        hl.dispatch(hl.dsp.window.move({ window = w, workspace = dst, silent = true }))
    end
    windows_on[dst], windows_on[src] = windows_on[src], nil
end

local report = {}
local tmp = 1000
while #pending > 0 do
    local srcs = {}
    for _, m in ipairs(pending) do srcs[m.src] = true end

    local pick
    for i, m in ipairs(pending) do
        if not srcs[m.dst] then pick = i break end
    end

    if pick then
        local m = table.remove(pending, pick)
        if not DRY then move_all(m.src, m.dst) end
        table.insert(report, m.orig .. "->" .. m.dst)
    else
        -- Only reachable when a workspace was stranded on the wrong monitor
        -- and two moves want each other's slot: park one out of the way.
        while windows_on[tmp] or hl.get_workspace(tmp) do tmp = tmp + 1 end
        local m = pending[1]
        if not DRY then move_all(m.src, tmp) end
        m.src, tmp = tmp, tmp + 1
    end
end

if #report == 0 then error("NOOP") end
if DRY then error("PLAN " .. table.concat(report, " ")) end

-- A target id outside its monitor's rule range (only when one screen holds
-- more than its share) gets created on the rule's monitor; pull it back.
for dst, mon in pairs(owner) do
    local ws = hl.get_workspace(dst)
    if ws and ws.monitor and ws.monitor.name ~= mon then
        hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(dst), monitor = mon }))
    end
end

-- Restore what each screen was showing: other screens first, the focused one
-- last so keyboard focus ends up where it started.
for name, id in pairs(active_before) do
    if monitors[name] ~= focused and map[id] and map[id] ~= id then
        hl.dispatch(hl.dsp.focus({ workspace = map[id] }))
    end
end
local fid = focused and active_before[focused.name]
if fid and map[fid] and map[fid] ~= fid then
    hl.dispatch(hl.dsp.focus({ workspace = map[fid] }))
    if active_win then hl.dispatch(hl.dsp.focus({ window = active_win })) end
end
LUA

out=$(hyprctl eval "$lua" 2>&1)

# hyprctl eval exits non-zero on a Lua error but prints "ok" on success; the
# plan and the no-op case come back through error() on purpose.
msg=$(sed -n 's/^error: \[string .*\]:[0-9]*: //p' <<<"$out")
case "$out" in
    ok)
        exit 0 ;;
    *NOOP*)
        $dry && echo "nothing to compact"
        exit 0 ;;
    *PLAN*)
        echo "${msg#PLAN }"
        exit 0 ;;
    *)
        echo "compact-workspaces: ${msg:-$out}" >&2
        notify-send -a Hyprland "Compact workspaces failed" "${msg:-$out}" 2>/dev/null
        exit 1 ;;
esac
