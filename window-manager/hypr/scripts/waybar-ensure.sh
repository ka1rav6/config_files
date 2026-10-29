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
# IT IS ALSO THE ONLY PLACE THAT LAUNCHES WAYBAR.
# That is not tidiness, it is the fix for a real bug. waybar has to be started
# as a child of hypr-ipc-shim (see start_waybar below) or clicking a workspace
# number does nothing. relayer.sh and toggle-waybar.sh each had their own
# `setsid waybar ...` line, so a monitor hotplug -- which is routine on a
# machine that is docked and undocked -- replaced the shimmed bar with an
# unshimmed one, and the bar silently lost click and scroll until the next
# login. Both now call this script instead, so there is one launch line to
# keep correct.
#
# IT IS SERIALISED BY A LOCK OF ITS OWN.
# "Exactly one process, one bar per monitor" is a read-then-repair, and six
# independent callers can reach it: autostart.lua, relayer.sh (twice),
# display-layout.sh, lid.sh and toggle-waybar.sh. relayer.sh holds
# hypr-relayer.lock and display-layout.sh holds hypr-display-settle.lock --
# two locks that do NOT exclude each other, so a monitor hotplug arriving
# during a mirror toggle ran two copies of this script at once. Both saw
# `procs != 1`, both pkill'd, both started a bar, and the result was the pile
# this script exists to remove. Private mktemp files (below) fixed the
# half-written-JSON half of that race; the lock here fixes the other half.
#
# Usage:  waybar-ensure.sh [--verbose] [--restart | --start]
#
#   (no mode)   assert the healthy state; do nothing if it already holds
#   --restart   kill and relaunch unconditionally (relayer.sh, after a remap)
#   --start     launch only if nothing is running (toggle-waybar.sh)
#   --verbose   also echo the trace to stderr; it goes to the log either way

set -uo pipefail

VERBOSE=0
MODE=assert
for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=1 ;;
        --restart) MODE=restart ;;
        --start)   MODE=start ;;
    esac
done

# --- log -------------------------------------------------------------------
# THE TRACE IS WRITTEN UNCONDITIONALLY, AND IT SURVIVES THE RESTART.
# This used to be `>/tmp/waybar.log` plus a log() gated on --verbose that no
# caller passed. Both halves defeated the same debugging session: every launch
# truncated the previous launch's output -- including the launch that failed --
# and the one trace that says WHICH of the six callers did the restart was
# discarded by every one of them (`>/dev/null 2>&1`). An intermittent bar
# cannot be diagnosed from a log that only ever holds the healthy run.
#
# Same shape as ~/.local/bin/hypr-log-persist.sh: append, under
# ~/.local/state, pruned by size before writing so it cannot grow unbounded.
# waybar emits ~11 lines per start, so one previous generation is plenty.
LOG_DIR="$HOME/.local/state/waybar"
LOG="$LOG_DIR/waybar.log"
mkdir -p "$LOG_DIR" 2>/dev/null
if [[ $(stat -c %s "$LOG" 2>/dev/null || echo 0) -gt 262144 ]]; then
    mv -f "$LOG" "$LOG.1" 2>/dev/null
fi
log() {
    printf '%s waybar-ensure[%d]: %s\n' "$(date +'%H:%M:%S')" "$$" "$*" >>"$LOG"
    [[ $VERBOSE -eq 1 ]] && printf '%s waybar-ensure: %s\n' "$(date +'%H:%M:%S')" "$*" >&2
    return 0
}

# --- lock ------------------------------------------------------------------
# fd 8, NOT fd 9: relayer.sh holds its own lock on fd 9, and start_waybar below
# closes fd 9 for exactly that reason. Using 9 here would have made that
# comment a lie and reintroduced the inherited-lock deadlock it describes.
#
# Blocking with a bound, not `-n`: a second caller must WAIT for the repair
# rather than skip it (skipping is how a real hotplug event gets dropped), but
# a holder that has wedged must not block the desktop forever. A run that
# takes longer than this is itself mid-restart, so whatever this run wanted
# has just been done by the holder.
#
# The lock is best-effort by design. If the fd cannot be opened at all we run
# unserialised rather than bail: `flock` on a closed fd fails, and treating
# that as "someone else is repairing" would mean no bar at all. A race is
# recoverable; a missing bar during login is not.
# NO `2>/dev/null` ON THIS exec. `exec` with redirections and no command
# rewires the SHELL, permanently -- so a `2>/dev/null` tacked on here to hide a
# failure message silently discarded every later stderr write in the script,
# --verbose included. The one line a failed open would print is worth keeping.
if exec 8>"${XDG_RUNTIME_DIR:-/tmp}/waybar-ensure.lock"; then
    if ! flock -w 15 8; then
        log "another run has held the lock for 15s -- skipping (mode=$MODE)"
        exit 0
    fi
else
    log "could not open the lock file -- proceeding unserialised"
fi

CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

# Wait for SIGTERM teardown to finish instead of assuming it fits in 400 ms.
# A bar blocked on a redraw or a stalled module pipe still owns its layer
# surfaces after the old `sleep 0.4`, so the new process mapped its own on top
# and this script created the very pile it exists to remove.
wait_gone() {
    local _unused
    for _unused in $(seq 1 60); do
        pgrep -x waybar >/dev/null 2>&1 || return 0
        sleep 0.05
    done
    log "waybar still alive 3s after SIGTERM -- starting anyway"
    return 1
}

start_waybar() {
    # 9>&- closes the relayer.sh lock fd if we were invoked from there, and
    # 8>&- closes this script's own lock, so a long-lived waybar can never
    # inherit and hold either. This exact bug deadlocked every later relayer
    # run once before, and fd 8 would have reproduced it permanently: an flock
    # is only released when the last holder of the fd closes it.
    #
    # WHY waybar IS STARTED UNDER hypr-ipc-shim
    #   waybar's workspace buttons send Hyprland's LEGACY IPC strings, which
    #   are hardcoded in the binary and which a Lua config rejects at parse
    #   time -- so clicking a workspace number did nothing at all. The shim
    #   sits on a second instance socket, rewrites those few strings into
    #   hl.dsp calls, and forwards everything else untouched. The long version
    #   is in ~/.config/hypr/daemons/hypr-ipc-shim.c and on the
    #   "hyprland/workspaces" block in config.jsonc.
    #
    #   It runs waybar as its CHILD rather than alongside it, which is what
    #   removes the startup race: the sockets exist before waybar is executed.
    #   `pgrep -x waybar` still finds the child, so every count and every
    #   `pkill -x waybar` in this script works exactly as before, and the shim
    #   exits when waybar does.
    #
    #   If the shim is missing, fall back to launching waybar directly. The
    #   bar then comes up with clicking broken, which is strictly better than
    #   no bar -- and is the state this machine was in before the shim existed.
    if command -v hypr-ipc-shim >/dev/null 2>&1; then
        setsid --fork hypr-ipc-shim -- waybar -c "$CONFIG" -s "$STYLE" \
            >>"$LOG" 2>&1 </dev/null 8>&- 9>&-
    else
        log "hypr-ipc-shim not installed — workspace clicks will not work"
        setsid --fork waybar -c "$CONFIG" -s "$STYLE" \
            >>"$LOG" 2>&1 </dev/null 8>&- 9>&-
    fi
}

case "$MODE" in
    restart)
        # Unconditional: the caller knows the bar needs rebuilding (waybar
        # does not re-lay-out its surfaces when an output is remapped).
        log "--restart"
        pkill -x waybar 2>/dev/null
        wait_gone
        start_waybar
        sleep 1.2
        exit 0
        ;;
    start)
        if pgrep -x waybar >/dev/null 2>&1; then
            log "--start: already running"
        else
            log "--start: launching"
            start_waybar
        fi
        exit 0
        ;;
esac

# --- 1. Exactly one process ------------------------------------------------
# NO `|| echo 0` HERE. `pgrep -c` PRINTS "0" AND EXITS 1 when nothing matches,
# so the fallback ran as well and $procs became the two-line string "0\n0" --
# which [[ -ne ]] then rejected with
#     waybar-ensure.sh: line 66: [[: 0
#     0: syntax error in expression (error token is "0")
# and the count was never compared at all. The bug only shows when there are
# ZERO waybar processes, which is why it went unnoticed: every caller until now
# ran against a bar that was already up. Starting the bar at login through this
# script is exactly the zero case.
procs=$(pgrep -cx waybar 2>/dev/null)
procs=${procs:-0}
if [[ "$procs" -ne 1 ]]; then
    log "found $procs waybar processes, want 1 — restarting"
    pkill -x waybar 2>/dev/null
    wait_gone
    start_waybar
    sleep 1.5
    log "now $(pgrep -cx waybar 2>/dev/null) process(es)"
    exit 0
fi

# --- 2. Exactly one bar per monitor ----------------------------------------
# A surface count that does not match the monitor list means waybar is holding
# bars for outputs that no longer exist, or has failed to create one for an
# output that does. Neither self-corrects.
# PRIVATE temp files, via mktemp.
#
# These were fixed paths (/tmp/.wbe-mons.json, /tmp/.wbe-lay.json). This script
# is called from relayer.sh -- which holds hypr-relayer.lock -- AND from
# display-layout.sh's settle(), which holds a DIFFERENT lock
# (hypr-display-settle.lock). Those two locks do not exclude each other, so a
# monitor hotplug arriving during a mirror toggle ran two copies of this script
# at once, both writing and reading the same two paths. Each then read the
# other's half-written JSON, both concluded the bar was broken, and both
# restarted waybar -- producing exactly the pile of duplicated bars this script
# exists to repair. Predictable names in a world-writable directory are also a
# symlink-clobber waiting to happen.
WBE_MONS=$(mktemp -t wbe-mons.XXXXXX.json) || exit 0
WBE_LAY=$(mktemp -t wbe-lay.XXXXXX.json) || exit 0
trap 'rm -f "$WBE_MONS" "$WBE_LAY"' EXIT

read -r monitors surfaces mismatch <<<"$(
    hyprctl monitors -j 2>/dev/null > "$WBE_MONS"
    hyprctl layers -j   2>/dev/null > "$WBE_LAY"
    WBE_MONS="$WBE_MONS" WBE_LAY="$WBE_LAY" python3 - <<'PY'
import json, os
try:
    mons = [m["name"] for m in json.load(open(os.environ["WBE_MONS"]))]
    lay = json.load(open(os.environ["WBE_LAY"]))
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

if [[ "${mismatch:-0}" -eq 1 ]]; then
    log "$monitors monitor(s) but $surfaces waybar surface(s) — restarting"
    pkill -x waybar 2>/dev/null
    wait_gone
    start_waybar
    sleep 1.5
else
    log "healthy: $monitors monitor(s), $surfaces bar(s)"
fi
