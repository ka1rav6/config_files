#!/usr/bin/env bash
# Guarantee exactly one healthy waybar: one process, one bar per monitor.
#
# WHY THIS EXISTS
# Several independent things restart waybar -- relayer.sh on monitor hotplug,
# toggle-waybar.sh on SUPER+ALT+SPACE, display-layout.sh after a mirror toggle,
# the theme switcher, and autostart.lua at login. Each one individually is
# fine; overlapping, they can leave either several waybar processes or a single
# process holding stale layer surfaces from outputs that have come and gone.
# The visible result is a stack of bars piled on one screen.
#
# Rather than try to make every caller perfectly ordered, this asserts the
# desired end state and repairs it. It is cheap, idempotent, and safe to call
# from anywhere, as often as you like.
#
# It is deliberately CONSERVATIVE: if everything already looks right it does
# nothing at all, so calling it after every display change costs one hyprctl
# query and no visible flicker.
#
# Usage:  waybar-ensure.sh [--verbose]

set -uo pipefail

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1
log() { [[ $VERBOSE -eq 1 ]] && printf '%s waybar-ensure: %s\n' "$(date +'%H:%M:%S')" "$*" || true; }

CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

start_waybar() {
    # 9>&- closes the relayer.sh lock fd if we were invoked from there, so a
    # long-lived waybar can never inherit and hold that lock. This exact bug
    # deadlocked every later relayer run once before.
    setsid --fork waybar -c "$CONFIG" -s "$STYLE" \
        >/tmp/waybar.log 2>&1 </dev/null 9>&-
}

# --- 1. Exactly one process ------------------------------------------------
procs=$(pgrep -cx waybar 2>/dev/null || echo 0)
if [[ "$procs" -ne 1 ]]; then
    log "found $procs waybar processes, want 1 — restarting"
    pkill -x waybar 2>/dev/null
    sleep 0.4
    start_waybar
    sleep 1.5
    log "now $(pgrep -cx waybar 2>/dev/null || echo 0) process(es)"
    exit 0
fi

# --- 2. Exactly one bar per monitor ----------------------------------------
# A surface count that does not match the monitor list means waybar is holding
# bars for outputs that no longer exist, or has failed to create one for an
# output that does. Neither self-corrects.
read -r monitors surfaces mismatch <<<"$(
    hyprctl monitors -j 2>/dev/null > /tmp/.wbe-mons.json
    hyprctl layers -j   2>/dev/null > /tmp/.wbe-lay.json
    python3 - <<'PY'
import json
try:
    mons = [m["name"] for m in json.load(open("/tmp/.wbe-mons.json"))]
    lay = json.load(open("/tmp/.wbe-lay.json"))
except Exception:
    print("0 0 0"); raise SystemExit

counts = {}
for name, v in lay.items():
    n = 0
    for lvl in v.get("levels", {}).values():
        n += sum(1 for it in lvl if it.get("namespace") == "waybar")
    counts[name] = n

total = sum(counts.values())
# Bad if any live monitor does not have exactly one bar, or if a bar is
# attached to an output that is not a live monitor.
bad = any(counts.get(m, 0) != 1 for m in mons) or any(
    c > 0 and m not in mons for m, c in counts.items()
)
print(f"{len(mons)} {total} {1 if bad else 0}")
PY
)"
rm -f /tmp/.wbe-mons.json /tmp/.wbe-lay.json

if [[ "${mismatch:-0}" -eq 1 ]]; then
    log "$monitors monitor(s) but $surfaces waybar surface(s) — restarting"
    pkill -x waybar 2>/dev/null
    sleep 0.4
    start_waybar
    sleep 1.5
else
    log "healthy: $monitors monitor(s), $surfaces bar(s)"
fi
