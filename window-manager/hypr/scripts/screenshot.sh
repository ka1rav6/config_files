#!/bin/sh
set -eu

screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"

# Cleanup state. Both are set later; the trap has to exist before anything can
# fail, and it must never touch a lock this run does not own -- the "someone
# else is selecting" path below exits through this same trap.
tmp=""
have_lock=0
freeze_pid=""
slurp_pid=""
submap_armed=0
# What the notification should call this capture. capture_region overwrites it
# when RETURN turns the selection into a full-screen grab.
scope="Selected area"
lock_dir="${XDG_RUNTIME_DIR:-/tmp}/screenshot-region.lock"

cleanup() {
    # Unfreeze first and unconditionally: a frozen screen left behind by a
    # cancelled or crashed run is indistinguishable from a hung machine. The
    # submap matters just as much -- stranded in one, every global keybind on
    # the machine is gone.
    unfreeze
    disarm_return
    if [ -n "$slurp_pid" ]; then
        kill "$slurp_pid" 2>/dev/null || true
        slurp_pid=""
    fi
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

# --- Freeze the screen ---------------------------------------------------------
# Without this, slurp dims the *live* screen: anything that moves while you are
# dragging -- a video, a progress bar, a notification sliding in -- is captured
# as it is at the moment grim runs, not as it looked when you hit the key. The
# Windows snipping tool freezes instead, and so does this.
#
# hyprpicker is the freeze: `-r` makes it screencopy every output and render
# that still image back as a fullscreen overlay layer, `-z`/`-d` strip the
# colour-picker chrome (zoom lens and live preview) so nothing but the frozen
# screen is left. slurp maps after it on the same overlay layer, so slurp sits
# on top and takes the pointer and keyboard; grim then captures the composited
# frame, which is hyprpicker's frozen copy rather than whatever is live.
#
# Everything here is optional by design. No hyprpicker, no hyprctl, or a
# hyprpicker that dies early just means the old unfrozen behaviour -- never a
# failed screenshot.
freeze() {
    command -v hyprpicker >/dev/null 2>&1 || return 0
    hyprpicker -r -z -d -q >/dev/null 2>&1 &
    freeze_pid=$!
    wait_for_freeze
}

# slurp must not map until the overlay is actually on screen, or it ends up
# *under* the freeze and gets no input at all. A fixed sleep either races on a
# slow frame or adds lag to every screenshot, so poll for the layer instead and
# keep the fixed sleep only for the case where hyprctl cannot answer (no
# instance signature in the environment).
wait_for_freeze() {
    if ! hyprctl version >/dev/null 2>&1; then
        sleep 0.2
        return 0
    fi
    i=0
    while [ "$i" -lt 80 ]; do
        if ! kill -0 "$freeze_pid" 2>/dev/null; then
            # Died on its own; carry on live rather than wait out the loop.
            freeze_pid=""
            return 0
        fi
        if hyprctl layers 2>/dev/null | grep -q 'namespace: hyprpicker'; then
            return 0
        fi
        sleep 0.015
        i=$((i + 1))
    done
    return 0
}

unfreeze() {
    if [ -n "$freeze_pid" ]; then
        kill "$freeze_pid" 2>/dev/null || true
        freeze_pid=""
    fi
    return 0
}

# --- RETURN means "the whole screen" -----------------------------------------
# slurp 1.5.0 reads exactly two keys, Escape and Space, and neither can be
# retargeted -- so the Enter key has to be caught by the compositor instead.
#
# A submap rather than a plain bind, because a global RETURN bind would have to
# be non-consuming to leave Enter working everywhere else, and would then fork
# a process on every newline typed on this machine for the rest of the login.
# The submap is armed only while slurp is actually on screen.
# The Lua form is not a stylistic choice: `hyprctl dispatch` is fed straight to
# the Lua parser on this config, so the documented `submap screenshot` comes
# back as "')' expected near 'screenshot'". Related to -- but not the same trap
# as -- `hyprctl keyword` being a no-op here.
#
# Read back rather than trusted, because hyprctl reports a parse error on
# stdout and still exits 0, so an unarmed submap would look armed.
arm_return() {
    hyprctl dispatch 'hl.dsp.submap("screenshot")' >/dev/null 2>&1 || true
    [ "$(hyprctl submap 2>/dev/null)" = "screenshot" ] || return 0
    submap_armed=1
    return 0
}

disarm_return() {
    if [ "$submap_armed" = 1 ]; then
        hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true
        submap_armed=0
    fi
    return 0
}

# --- Signal from the selection submap ----------------------------------------
# The submap's RETURN bind cannot hand a value back to the run that is sitting
# in `wait`, so it re-enters this script to drop a flag in the lock directory
# and kill slurp. Handled up here, ahead of the temp file and the usage text,
# because it is not a capture mode -- it is one process poking another.
if [ "${1:-}" = "select-all" ]; then
    # No lock means no selection is in progress and there is nothing to tell.
    [ -d "$lock_dir" ] || exit 0
    # Flag first, kill second. The other side only looks at the flag once slurp
    # has exited, so writing it after the kill races and reads as a cancel.
    : >"$lock_dir/fullscreen"
    if [ -r "$lock_dir/slurp.pid" ]; then
        kill "$(cat "$lock_dir/slurp.pid")" 2>/dev/null || true
    fi
    exit 0
fi

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
    freeze
    arm_return

    # slurp runs as a background job rather than in a `$(...)` substitution
    # because the RETURN handler needs a pid to kill, and a substitution never
    # exposes one. Its output goes to a file in the lock directory, which is
    # removed wholesale by the trap.
    selection="$lock_dir/selection"
    : >"$selection"
    slurp >"$selection" 2>/dev/null &
    slurp_pid=$!
    echo "$slurp_pid" >"$lock_dir/slurp.pid"
    # `|| true` because every way out of slurp except a completed drag is a
    # non-zero exit -- Esc, and the kill that RETURN sends -- and `set -e`
    # would turn both into a crash.
    wait "$slurp_pid" || true
    slurp_pid=""
    disarm_return

    # Still frozen from here on, which is the whole point: grim has to read the
    # frozen overlay and not the live screen. Dropped immediately after each
    # capture so the desktop comes back before the notification, not after it.
    if [ -e "$lock_dir/fullscreen" ]; then
        # RETURN without dragging anything: the whole frozen screen, uncropped.
        scope="Full screen"
        grim "$tmp"
        unfreeze
        return 0
    fi

    # slurp exits non-zero on Esc and prints nothing on an empty drag. Both
    # mean "cancelled", and cancelled means leave with no file and no message.
    # Either way the trap unfreezes and disarms on the way out.
    region=$(cat "$selection")
    [ -n "$region" ] || exit 0
    grim -g "$region" "$tmp"
    unfreeze
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
        notify-send "Screenshot copied" "$scope is in the clipboard"
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

The screen freezes while you select. Press RETURN instead of dragging to take
the whole screen, or ESCAPE to cancel.

(`select-all` is also accepted, but it is the selection submap's RETURN bind
talking to a run already in progress, not something to call by hand.)
EOF
        exit 2
        ;;
esac
