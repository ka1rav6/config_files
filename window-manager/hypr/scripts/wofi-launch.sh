#!/usr/bin/env bash
# =============================================================================
# wofi-launch.sh — the single-instance front door to wofi.
# =============================================================================
# Bound to SUPER + S (drun) and SUPER + V (clipboard) through the `launcher`
# variable in ~/.config/hypr/defaults.lua and the binds in bindings.lua.
#
# THE PROBLEM THIS SOLVES
#   `hl.bind(mod .. " + S", hl.dsp.exec_cmd(launcher))` ran the launcher on every
#   press, unconditionally. Hold the key, or press it twice while the first wofi
#   is still mapping, and you get two overlapping layer surfaces both holding a
#   keyboard grab. The second is usually invisible behind the first and eats half
#   your keystrokes.
#
# WHY NOT `pgrep wofi || wofi`
#   Two reasons, and the second is the one that actually bites:
#
#   1. It is a textbook race. Two presses 5 ms apart both run pgrep before
#      either has launched anything, both see nothing, both launch. The race
#      window is exactly wofi's startup time -- which is precisely the window a
#      double-press lands in, so the "rare" race is the common case.
#
#   2. `pgrep -f wofi` MATCHES ITSELF. The `sh -c` wrapper Hyprland spawns
#      carries the whole command line -- the word "wofi" included -- in its own
#      argv, so the guard finds its own launcher, concludes "already running",
#      and the `||` never fires. The launcher then never opens again, silently
#      and permanently. Two daemons in this config were dead this way for
#      months; see the long note on `spawn_once` in ~/.config/hypr/autostart.lua.
#
#      Nothing here greps a command line. Liveness is decided from a process
#      GROUP this script recorded itself, which cannot see a shell's argv.
#
# ---------------------------------------------------------------------------
# THE MECHANISM
#
#   One flock per mode, held only across the DECISION -- microseconds -- and
#   never across wofi's lifetime. Inside the lock:
#
#       is a wofi alive in the process group we recorded?
#         yes, younger than GRACE_MS -> do nothing   (key repeat / double-tap)
#         yes, older                 -> dismiss it   (the press is a toggle)
#         no                         -> launch, record the group
#
#   WHY A PROCESS GROUP AND NOT A PID
#     `drun` mode is one process (wofi). `clip` mode is a four-stage pipeline
#     with wofi in the middle, so there is no single pid that is "the launcher"
#     in both. Recording the group leader and then asking "is there a wofi in
#     this group" is the one test that is exact for both, and it stays exact if
#     the pipeline ever grows another stage.
#
#     It is also pid-reuse safe in the way a bare pidfile is not: the check is
#     scoped to our own group AND to the process name, so a recycled pid
#     belonging to something unrelated can never be sent a signal.
#
#   WHY THE LOCK IS NOT HELD ACROSS wofi
#     Because a long-lived child inherits every open fd. Holding the lock on
#     fd 9 while launching wofi would hand the lock to wofi -- and then to
#     whatever application wofi launches, which keeps it for its entire life.
#     The launcher would lock itself out the first time you started a browser
#     from it. This is not hypothetical: it is the exact bug
#     ~/.config/hypr/scripts/relayer.sh carries its own warning about, where a
#     backgrounded waybar inherited fd 9 and deadlocked every later run. Every
#     child here is started with `9>&-`.
#
#     Liveness therefore comes from the recorded group, not from the lock, which
#     also means a wofi killed with -9, OOM-reaped or crashed needs no cleanup:
#     its group empties and the next press simply launches.
#
# WHY A PRESS ON AN OPEN LAUNCHER DISMISSES IT
#   "Focus the existing instance" has no meaning for wofi: it is a layer surface
#   holding an exclusive keyboard grab, so if it is open it is ALREADY focused --
#   there is nothing to raise. That leaves do-nothing or toggle, and toggle is
#   what every other panel key in this desktop does (SUPER+A, SUPER+D,
#   SUPER+comma). GRACE_MS is what makes it safe: a held key or a double-tap
#   cannot open-then-immediately-close, because a press inside the grace window
#   is ignored rather than treated as the second half of a toggle.
#
# Usage:
#   wofi-launch.sh drun     application launcher   (SUPER + S)
#   wofi-launch.sh clip     clipboard history      (SUPER + V)
#   wofi-launch.sh status   what is running, for debugging
# =============================================================================

set -uo pipefail

MODE="${1:-drun}"

CONF="$HOME/.config/wofi/config"
STYLE="$HOME/.config/wofi/style.css"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"

# How long after a launch a further press is ignored rather than treated as
# "dismiss". Long enough to cover key repeat and a human double-tap, far shorter
# than any deliberate second press.
GRACE_MS=600

state_file() { printf '%s/wofi-%s.group\n' "$RUNTIME" "$1"; }

now_ms() { printf '%s\n' "$(($(date +%s%N) / 1000000))"; }

# Print the pid of the wofi belonging to mode $1, if one is alive.
#
# Reads the recorded process group, then looks for a process in that group whose
# executable name is exactly "wofi". `pgrep -g <pgid> -x wofi` does both halves
# in one call and cannot match a command line.
mode_wofi_pid() {
    local file pgid
    file=$(state_file "$1")
    [[ -r "$file" ]] || return 1
    read -r pgid _ <"$file" 2>/dev/null || return 1
    [[ "$pgid" =~ ^[0-9]+$ ]] || return 1
    pgrep -g "$pgid" -x wofi 2>/dev/null | head -1
}

mode_started_ms() {
    local file pgid stamp
    file=$(state_file "$1")
    [[ -r "$file" ]] || { printf '0\n'; return; }
    read -r pgid stamp <"$file" 2>/dev/null || { printf '0\n'; return; }
    [[ "$stamp" =~ ^[0-9]+$ ]] && printf '%s\n' "$stamp" || printf '0\n'
}

case "$MODE" in
status)
    for mode in drun clip; do
        if pid=$(mode_wofi_pid "$mode") && [[ -n "$pid" ]]; then
            printf '%-5s running  pid=%s  age=%sms\n' \
                "$mode" "$pid" "$(($(now_ms) - $(mode_started_ms "$mode")))"
        else
            printf '%-5s not running\n' "$mode"
        fi
    done
    exit 0
    ;;
drun | clip) ;;
*)
    printf 'Usage: %s [drun|clip|status]\n' "$0" >&2
    exit 2
    ;;
esac

STATE=$(state_file "$MODE")
LOCK="$RUNTIME/wofi-$MODE.lock"

# ---------------------------------------------------------------------------
# The decision, serialised.
#
# A BLOCKING flock, not `flock -n`. With -n a losing press would fall through
# with no idea whether the winner had launched yet -- which is the original race
# wearing a lock as a disguise. Blocking means the second press reads the state
# the first press has already written. The critical section holds no wofi and no
# I/O beyond a couple of small files, so the wait is a handful of syscalls.
# ---------------------------------------------------------------------------
exec 9>"$LOCK"
flock 9

if pid=$(mode_wofi_pid "$MODE") && [[ -n "$pid" ]]; then
    if (($(now_ms) - $(mode_started_ms "$MODE") < GRACE_MS)); then
        # Key repeat, or a double-tap. Leave it alone.
        exit 0
    fi

    # Deliberate second press: dismiss.
    #
    # TERM, never KILL. wofi's own exit path is what releases the keyboard grab,
    # and a grab leaked by a -9 leaves the session unable to type -- which is a
    # far worse outcome than a launcher that occasionally needs a second press.
    kill -TERM "$pid" 2>/dev/null || true
    rm -f "$STATE"
    exit 0
fi

# ---------------------------------------------------------------------------
# Nothing running: launch.
#
# `setsid` WITHOUT --fork, deliberately. setsid normally has to fork to become a
# session leader, but a background command in a non-interactive shell is not a
# process-group leader, so it can and does exec in place -- which means `$!` is
# the process that becomes the new group leader, and `$!` IS therefore the pgid.
# With `--fork` the parent exits immediately and `$!` is a corpse, so the
# recorded group would be wrong within milliseconds and the guard would never
# engage.
#
# 9>&- closes the lock fd in the child. See the header: without it the lock
# outlives the launcher by the lifetime of whatever wofi goes on to start.
# ---------------------------------------------------------------------------
case "$MODE" in
drun)
    # `exec` so the shell becomes wofi rather than babysitting it: the group
    # leader is then wofi itself, one process instead of two.
    setsid bash -c 'exec wofi --show drun --conf "$1" --style "$2"' \
        _ "$CONF" "$STYLE" >/dev/null 2>&1 </dev/null 9>&- &
    ;;
clip)
    # The clipboard pipeline lives here rather than in the keybind so that BOTH
    # wofi modes go through one guard. Previously SUPER+V knew nothing about
    # SUPER+S, so its wofi could open directly on top of the launcher's.
    #
    # THE SELECTION IS CHECKED BEFORE wl-copy RUNS. The original one-liner was a
    # straight pipe:
    #
    #     cliphist list | wofi --dmenu | cliphist decode | wl-copy
    #
    # and in a pipe, wl-copy runs whatever wofi does. Cancel the picker -- Escape,
    # or now a second SUPER+V -- and wofi exits having printed nothing, so
    # `cliphist decode` prints nothing and wl-copy is handed an EMPTY stdin,
    # which sets the clipboard to empty. Backing out of the clipboard history
    # therefore wiped the clipboard, which is the one thing it must never do.
    #
    # Capturing the selection and returning early on an empty one is the fix.
    # `exit 0` before wl-copy leaves the clipboard exactly as it was.
    setsid bash -c '
        selection=$(cliphist list | wofi --dmenu --conf "$1" --style "$2") || exit 0
        [ -n "$selection" ] || exit 0
        printf "%s" "$selection" | cliphist decode | wl-copy
    ' _ "$CONF" "$STYLE" >/dev/null 2>&1 </dev/null 9>&- &
    ;;
esac

pgid=$!

# Record the group immediately, while still holding the lock, so a press
# arriving 1 ms from now sees it. The timestamp is what GRACE_MS is measured
# against.
#
# The group is recorded even though wofi may not have execed yet: mode_wofi_pid
# asks whether a wofi exists IN the group, so a press during those few
# milliseconds finds none, falls through, and would launch a second one -- which
# is what GRACE_MS would not help with. That gap is closed by the lock, not by
# the timestamp: the second press cannot enter this section until the first has
# left it, and by then the group is on disk. The grace window then covers the
# remaining startup time.
printf '%s %s\n' "$pgid" "$(now_ms)" >"$STATE"

# Release the lock explicitly before waiting, rather than relying on the script
# exiting: `wait` below can sit here for as long as the launcher is open, and
# holding the lock for that whole time is the thing this script is built not to
# do.
flock -u 9
exec 9>&-

wait "$pgid" 2>/dev/null || true

# Only clear the state if it is still ours. A dismiss-then-relaunch can happen
# while this `wait` is blocked, and clobbering the newer group's record would
# make the guard forget about a launcher that is on screen.
if [[ -r "$STATE" ]]; then
    read -r recorded _ <"$STATE" 2>/dev/null || recorded=""
    [[ "$recorded" == "$pgid" ]] && rm -f "$STATE"
fi
