#!/bin/sh
# =============================================================================
# hypr-log-persist.sh — keep the useful part of Hyprland's log across a reboot.
# =============================================================================
# Hyprland's log lives in $XDG_RUNTIME_DIR (tmpfs, i.e. RAM) and is lost on
# reboot -- which is exactly when you need it, because the failures worth
# debugging here (a suspend/resume that wedges the panel) usually END in a
# forced reboot. Started by hypr-log-persist.service.
#
# -----------------------------------------------------------------------------
# WHY THIS FILTERS RATHER THAN MIRRORING VERBATIM
#
# It used to be a plain `tail -F >> file`. Measured: 54 MB across 12 runs in 8
# days, with no pruning, and 99.8% of every one of those files was
#
#     DEBUG from aquamarine ]: [libinput] event4 - tap: touch 0 ...
#
# aquamarine puts libinput at DEBUG priority and logs one line per touchpad
# event, and Hyprland's `debug:disable_logs` does not gate it (it only covers
# Hyprland's own messages -- see the note in ~/.config/hypr/looknfeel.lua).
#
# Those lines are worthless for the failure this file exists to catch. What IS
# worth keeping is the DRM/modeset/output traffic and anything at ERR or WARN:
#
#     DEBUG from aquamarine ]: drm: Modesetting eDP-1 with 2880x1800@120.00Hz
#     ERR from aquamarine ]: No support for gamma on the legacy iface
#
# So the input spam is dropped on the way to disk. That keeps a resume failure
# fully diagnosable while cutting the written volume by ~99%.
#
# grep is line-buffered with --line-buffered so a crash cannot lose the last
# few lines to a stdio buffer that was never flushed.
# -----------------------------------------------------------------------------

OUT_DIR="$HOME/.local/state/hypr-debug"
KEEP=5                      # how many previous runs to retain

mkdir -p "$OUT_DIR"

# --- retention ---------------------------------------------------------------
# Prune before writing, so the directory can never grow without bound. Nothing
# else ever deleted these; they simply accumulated one file per login, reaching
# 54 MB over 8 days.
#
# find -printf + sort, deliberately NOT `ls -t`: `ls` may be shadowed by an
# alias or a replacement (eza is installed here, and its -t takes a mandatory
# argument, so `ls -1t DIR` silently means something else entirely). Sorting an
# explicit mtime field cannot be misread that way, and -print0 survives any
# filename.
find "$OUT_DIR" -maxdepth 1 -name 'hyprland-*.log' -type f -printf '%T@\t%p\0' 2>/dev/null \
    | sort -zrn \
    | tail -z -n +$((KEEP + 1)) \
    | cut -z -f2- \
    | xargs -0 -r rm -f

# Wait for Hyprland to create its instance directory and log.
LOG=""
while [ -z "$LOG" ]; do
    LOG=$(find "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" -name hyprland.log -type f 2>/dev/null | head -1)
    [ -z "$LOG" ] && sleep 2
done

STAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUT="$OUT_DIR/hyprland-$STAMP.log"

{
    echo "=== mirroring $LOG"
    echo "=== boot at $(uptime -s), mirror started $STAMP"
    echo "=== libinput event lines are filtered out; see hypr-log-persist.sh"
} >>"$OUT"

# -v drops the input spam. Everything else -- DRM, modesetting, ERR, WARN,
# plugin and config messages -- is kept verbatim.
exec tail -F -n +1 "$LOG" 2>/dev/null \
    | grep --line-buffered -v -e '\[libinput\]' >>"$OUT"
