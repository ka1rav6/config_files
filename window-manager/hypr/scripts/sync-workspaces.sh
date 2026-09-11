#!/usr/bin/env bash
# Reassign workspaces to monitors when the display layout changes.
#
# Called on monitor.added / monitor.removed (see ~/.config/hypr/monitors.lua)
# and directly by display-layout.sh after a mirror toggle.
#
# ---------------------------------------------------------------------------
# TWO BUGS THIS FILE USED TO HAVE. Both are easy to reintroduce.
#
# 1. It used `hyprctl keyword "workspace N, monitor:M"`.
#    Under the Lua config that is rejected outright:
#        keyword can't work with non-legacy parsers. Use eval.
#    and -- this is the part that made it invisible -- hyprctl STILL EXITS 0
#    while printing that to stdout. `set -e` therefore never fired, the script
#    reported success, and not one assignment was ever applied. Everything here
#    goes through `hyprctl eval` with the Lua API instead, and return values
#    are checked explicitly rather than trusted.
#
# 2. It only ever set workspace *rules*. A rule decides which monitor a
#    workspace is created on; it does NOT move a workspace that already
#    exists. So an EMPTY workspace appeared to obey the rule (it was destroyed
#    and recreated in the right place), while a workspace WITH WINDOWS stayed
#    stranded on the old monitor forever. That is the "workspace 8 no longer
#    opens on my laptop screen" symptom: ws8 was empty and looked fine, ws9 had
#    a window and was stuck on the external monitor.
#    Rules are now followed by an explicit move for every workspace that
#    already exists on the wrong output.
# ---------------------------------------------------------------------------

set -uo pipefail

EXTERNAL="HDMI-A-1"
INTERNAL="eDP-1"

log() { printf '%s sync-workspaces: %s\n' "$(date +'%H:%M:%S')" "$*"; }

# hyprctl eval exits 0 even on a Lua error, so match the output instead.
ev() {
    local out
    out=$(hyprctl eval "$1" 2>&1)
    if [[ "$out" != "ok" ]]; then
        log "FAILED: $1 -> $out"
        return 1
    fi
    return 0
}

monitors=$(hyprctl monitors -j 2>/dev/null) || { log "cannot reach hyprctl"; exit 1; }

# A monitor that is mirroring another does not appear here at all, which is
# what makes the mirror case fall through to the single-monitor branch below.
has_external=$(jq -r --arg m "$EXTERNAL" 'any(.[]; .name == $m)' <<<"$monitors")
has_internal=$(jq -r --arg m "$INTERNAL" 'any(.[]; .name == $m)' <<<"$monitors")

# Workspace id -> monitor it is currently on, for workspaces that exist.
existing=$(hyprctl workspaces -j 2>/dev/null | jq -r '.[]|"\(.id) \(.monitor)"')

# assign <monitor> <ws...>
#   Sets the creation rule, then moves the workspace if it already exists
#   somewhere else. Skips the move when it is already correct, so this is
#   idempotent and safe to run on every display event.
assign() {
    local monitor=$1; shift
    local ws current
    for ws in "$@"; do
        ev "hl.workspace_rule({ workspace = \"$ws\", monitor = \"$monitor\" })" || continue

        current=$(awk -v w="$ws" '$1 == w { print $2 }' <<<"$existing")
        if [[ -n "$current" && "$current" != "$monitor" ]]; then
            if ev "hl.dispatch(hl.dsp.workspace.move({ workspace = \"$ws\", monitor = \"$monitor\" }))"; then
                log "moved ws$ws: $current -> $monitor"
            fi
        fi
    done
}

if [[ "$has_external" == "true" && "$has_internal" == "true" ]]; then
    log "both monitors present — 1-7 on $EXTERNAL, 8-10 on $INTERNAL"
    assign "$EXTERNAL" 1 2 3 4 5 6 7
    assign "$INTERNAL" 8 9 10
elif [[ "$has_internal" == "true" ]]; then
    log "internal only — all workspaces on $INTERNAL"
    assign "$INTERNAL" $(seq 1 10)
elif [[ "$has_external" == "true" ]]; then
    # Also the mirrored case: the internal panel is mirroring and so is absent
    # from `hyprctl monitors`, leaving the external as the only real output.
    log "external only (or mirroring) — all workspaces on $EXTERNAL"
    assign "$EXTERNAL" $(seq 1 10)
else
    log "no known monitor present — nothing to do"
fi
