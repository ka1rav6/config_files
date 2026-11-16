#!/bin/sh
set -eu

# =============================================================================
# record.sh — screen recording, on the same two keys as the screenshot.
# =============================================================================
# SUPER + ALT + R           select an area and start / stop
# SUPER + ALT + SHIFT + R   whole screen, start / stop
#
# One toggle rather than separate start and stop keys: a recording you cannot
# stop with the key that started it is a recording you end up killing from a
# terminal, and a killed wf-recorder leaves an unplayable file (see stop()).
#
# WHY NOT THE SCREENSHOT SCRIPT'S FREEZE
#   screenshot.sh freezes the screen with hyprpicker while you drag, so what
#   you select is what you captured. A recording starts AFTER the selection, so
#   there is nothing to freeze -- and hyprpicker's overlay would be the first
#   thing in the video if it were still up. slurp runs on the live screen here.
#
# THE BAR INDICATOR
#   ~/.config/waybar/config.jsonc has a custom/record module that runs
#   `record.sh status` once and then only when signalled. This script signals
#   it on every state change, so an idle machine does no polling at all.
#
#   The signal is sent with `pkill -x`, EXACT match. The full story is at the
#   top of ~/.config/hypr/daemons/barfeed-hyprtodo.c: a substring pkill for
#   "waybar" also matches barfeed-hyprtodo and barfeed-kdeconnect, and a
#   real-time signal they do not handle terminates them.
# =============================================================================

out_dir="$HOME/media/video/Recordings"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/record.state"

# Deliberately OUTSIDE state_dir, which is removed when a start fails -- taking
# with it the only explanation of why. The notification quotes the last lines of
# this; the file is what you read when that is not enough.
log_file="${XDG_RUNTIME_DIR:-/tmp}/record.log"

# Remembers that VA-API did not work, so only the first recording after a boot
# pays for finding out. In $XDG_RUNTIME_DIR, so it is gone after a reboot and a
# fixed driver gets another chance without anyone having to know this exists.
novaapi="${XDG_RUNTIME_DIR:-/tmp}/record.novaapi"

# Must match "signal" in custom/record in ~/.config/waybar/config.jsonc.
bar_signal=9

# wf-recorder given neither -g nor -o on a MULTI-OUTPUT machine stops and asks
# which one, on stdin:
#
#     Please select an output from the list to capture (enter output no.):
#
# Launched from a keybind there is no stdin, so it printed "Failed to select
# output, exiting" and the key did nothing. A region capture is fine -- it works
# the output out from the geometry ("Detected output based on geometry") -- but
# a full-screen one has to be told.
#
# Parsed from the text output rather than `hyprctl monitors -j` so this needs no
# jq. Empty if hyprctl cannot answer, and the caller then omits -o and gets the
# old behaviour rather than a broken flag.
focused_output() {
    hyprctl monitors 2>/dev/null | awk '
        /^Monitor /    { name = $2 }
        /focused: yes/ { print name; exit }
    '
}

nudge_bar() {
    pkill "-RTMIN+${bar_signal}" -x waybar 2>/dev/null || true
    return 0
}

# True only while OUR wf-recorder is alive.
#
# The comm check is not paranoia: $XDG_RUNTIME_DIR outlives the process, pids
# are reused, and a stale pid file that now names something else would make
# `stop` send SIGINT to an unrelated program. Same reasoning as the lock in
# screenshot.sh, one failure mode worse.
running() {
    [ -r "$state_dir/pid" ] || return 1
    pid=$(cat "$state_dir/pid" 2>/dev/null) || return 1
    [ -n "$pid" ] || return 1
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -rf "$state_dir"
        return 1
    fi
    if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" != "wf-recorder" ]; then
        rm -rf "$state_dir"
        return 1
    fi
    return 0
}

stop() {
    running || return 0
    pid=$(cat "$state_dir/pid")
    file=$(cat "$state_dir/file" 2>/dev/null || echo "")

    # SIGINT, never SIGKILL. wf-recorder writes the container trailer when it
    # is interrupted; without it the .mp4 has no index and most players refuse
    # to open it. This is the one thing in this script that must not be cut.
    kill -INT "$pid" 2>/dev/null || true

    i=0
    while [ "$i" -lt 100 ] && kill -0 "$pid" 2>/dev/null; do
        sleep 0.05
        i=$((i + 1))
    done

    rm -rf "$state_dir"
    nudge_bar
    notify-send "Recording stopped" "${file:-Saved}"
}

# Start wf-recorder with the args already in "$@", and report whether it
# survived its first moment. Split out because the VAAPI attempt and the
# software fallback differ only in their arguments.
launch() {
    mkdir -p "$state_dir"
    wf-recorder "$@" >"$log_file" 2>&1 &
    pid=$!
    echo "$pid" >"$state_dir/pid"

    # wf-recorder fails on the FIRST frame when an encoder is unavailable, not
    # at argument parsing, so a bad -c only shows up once it is running.
    sleep 0.4
    kill -0 "$pid" 2>/dev/null
}

start() {
    mode=$1

    if ! command -v wf-recorder >/dev/null 2>&1; then
        notify-send -u critical "Cannot record" \
            "wf-recorder is not installed.  sudo apt install wf-recorder"
        exit 1
    fi

    geom=""
    if [ "$mode" = region ]; then
        # slurp prints "X,Y WxH" -- WITH a space, so it has to stay one
        # argument. Esc or an empty drag exits non-zero or prints nothing, and
        # both mean cancelled.
        geom=$(slurp 2>/dev/null) || exit 0
        [ -n "$geom" ] || exit 0
    fi

    mkdir -p "$out_dir"
    file="$out_dir/Recording_$(date +%Y%m%d_%H%M%S).mp4"

    set -- -f "$file"
    if [ -n "$geom" ]; then
        set -- "$@" -g "$geom"
    else
        # Full screen: name the output, or wf-recorder asks on a stdin that is
        # not there. See focused_output() above.
        out=$(focused_output)
        if [ -n "$out" ]; then
            set -- "$@" -o "$out"
        fi
    fi

    # VAAPI first: the iGPU encodes, so recording costs a few percent of one
    # core instead of saturating several. If it does not come up -- no render
    # node, no h264_vaapi, a driver that refuses the pixel format -- fall back
    # to software rather than leaving the user with a key that does nothing.
    started=0
    if [ -e /dev/dri/renderD128 ] && [ ! -e "$novaapi" ]; then
        if launch "$@" -c h264_vaapi -d /dev/dri/renderD128; then
            started=1
        else
            # Remember, so every later recording this boot starts immediately
            # instead of spending the probe again. On THIS machine it fails
            # with "Failed to initialise VAAPI connection: -1 (unknown libva
            # error)" -- libva cannot talk to the iGPU at all, which is also
            # why vainfo is not installed. Software encoding is the real path
            # here until that is fixed.
            : >"$novaapi"
        fi
    fi

    if [ "$started" = 0 ]; then
        if launch "$@"; then
            started=1
        fi
    fi

    if [ "$started" = 0 ]; then
        notify-send -u critical "Recording failed" \
            "$(tail -n 3 "$log_file" 2>/dev/null || echo 'wf-recorder would not start')"
        rm -rf "$state_dir"
        nudge_bar
        exit 1
    fi

    echo "$file" >"$state_dir/file"
    nudge_bar
    notify-send "Recording" "$([ -n "$geom" ] && echo 'Selected area' || echo 'Full screen') — press the same keys to stop"
}

case "${1:-}" in
    toggle)
        if running; then stop; else start region; fi
        ;;
    toggle-full)
        if running; then stop; else start full; fi
        ;;
    stop)
        stop
        ;;
    status)
        # Read by waybar. Must stay fast and must not care whether wf-recorder
        # is installed.
        if running; then
            file=$(cat "$state_dir/file" 2>/dev/null || echo "")
            printf '{"text":"REC","class":"recording","tooltip":"Recording to %s\\nClick to stop"}\n' "$file"
        else
            # Empty text hides the module.
            printf '{"text":""}\n'
        fi
        ;;
    *)
        cat >&2 <<'USAGE'
Usage: record.sh <toggle|toggle-full|stop|status>

  toggle       select an area and record; stop if already recording
  toggle-full  record the whole screen; stop if already recording
  stop         stop a recording in progress
  status       waybar JSON for the custom/record module

Recordings land in ~/media/video/Recordings. Hardware encoded via VAAPI where
that works, software otherwise.
USAGE
        exit 2
        ;;
esac
