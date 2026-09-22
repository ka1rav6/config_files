#!/bin/sh
set -eu

screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"

# Cleanup state. Both are set later; the trap has to exist before anything can
# fail, and it must never touch a lock this run does not own -- the "someone
# else is selecting" path below exits through this same trap.
tmp=""
have_lock=0
lock_dir="${XDG_RUNTIME_DIR:-/tmp}/screenshot-region.lock"

cleanup() {
    if [ "$have_lock" = 1 ]; then
        rm -rf "$lock_dir"
        have_lock=0
    fi
    if [ -n "$tmp" ]; then
        rm -f "$tmp"
        tmp=""
    fi
    return 0
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM HUP

# --- One selection at a time -------------------------------------------------
# SUPER + P is easy to press twice before the first overlay has even drawn.
# slurp is a layer-shell surface that dims the whole screen and grabs the
# pointer, so a second one stacks on the first: two dimmers (the screen goes
# visibly darker), two rubber bands, and finishing one leaves the other still
# holding the grab with nothing to cancel it but Esc.
#
# `mkdir` is the atomic test-and-set -- checking with `pgrep slurp` first would
# lose the race this is here to close, since two keypresses can both look and
# both find nothing before either has spawned.
#
# The lock records its pid because $XDG_RUNTIME_DIR outlives the process: a run
# that is SIGKILLed never reaches its trap, and the directory it left behind
# would block every screenshot for the rest of the login with nothing to say
# why. So only defer to a lock whose owner is still alive.
take_lock() {
    if ! mkdir "$lock_dir" 2>/dev/null; then
        if [ -r "$lock_dir/pid" ] && kill -0 "$(cat "$lock_dir/pid")" 2>/dev/null; then
            # A selection is already on screen; let that one finish.
            exit 0
        fi
        rm -rf "$lock_dir"
        mkdir "$lock_dir" 2>/dev/null || exit 0
    fi
    have_lock=1
    echo $$ >"$lock_dir/pid"
}

# --- Capture -----------------------------------------------------------------
# Everything lands in a temp file first, and nothing after it runs unless that
# file exists and is non-empty.
#
# The previous shape was `capture_region - | tee "$file" | wl-copy`, which had
# no way to fail: a pipeline reports the status of its LAST command, so slurp
# cancelled with Esc took grim with it and the pipeline still "succeeded"
# because wl-copy was happy to accept zero bytes. The notification fired for a
# screenshot that was never taken, and in the save modes `tee` had already
# created an empty .png in ~/Pictures/Screenshots to go with it.

capture_region() {
    take_lock
    # slurp exits non-zero on Esc and prints nothing on an empty drag. Both
    # mean "cancelled", and cancelled means leave with no file and no message.
    region=$(slurp) || exit 0
    [ -n "$region" ] || exit 0
    grim -g "$region" "$tmp"
}

capture_full() {
    grim "$tmp"
}

# Refuses to go on unless there is a real image. grim exiting non-zero already
# aborts under `set -e`; this also catches a zero-byte write.
require_capture() {
    [ -s "$tmp" ] || exit 1
}

# -t is explicit rather than left to wl-copy's content sniffing, so the
# clipboard is always offered as image/png.
copy() {
    wl-copy -t image/png <"$tmp"
}

# Moving (not copying) hands the file over and clears $tmp, so the trap has
# nothing left to delete.
save() {
    mv "$tmp" "$1"
    tmp=""
}

tmp=$(mktemp --suffix=.png "${TMPDIR:-/tmp}/screenshot.XXXXXX")

# The *-save modes write the file AND put the same PNG on the clipboard, so a
# screenshot is immediately pasteable without digging the file out again.
case "${1:-}" in
    region|copy)
        capture_region
        require_capture
        copy
        notify-send "Screenshot copied" "Selected area is in the clipboard"
        ;;
    region-save|save)
        file="$screenshot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        capture_region
        require_capture
        save "$file"
        wl-copy -t image/png <"$file"
        notify-send "Screenshot saved & copied" "$file"
        ;;
    full)
        capture_full
        require_capture
        copy
        notify-send "Screenshot copied" "Full screen is in the clipboard"
        ;;
    full-save)
        file="$screenshot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        capture_full
        require_capture
        save "$file"
        wl-copy -t image/png <"$file"
        notify-send "Screenshot saved & copied" "$file"
        ;;
    *)
        cat >&2 <<'EOF'
Usage: screenshot.sh <mode>

Modes:
  region, copy       Select an area and copy to clipboard
  region-save, save  Select an area, save to ~/Pictures/Screenshots and copy
  full               Copy the full screen to clipboard
  full-save          Save the full screen to ~/Pictures/Screenshots and copy
EOF
        exit 2
        ;;
esac
