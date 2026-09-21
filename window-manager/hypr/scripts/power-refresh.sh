#!/bin/sh
#
# Drop the internal panel to 60 Hz on battery, put it back to 120 Hz on AC.
#
#   power-refresh.sh apply    apply once for the current power state
#   power-refresh.sh watch    apply, then re-apply on every power-supply event
#
# Why: eDP-1 is 2880x1800 at 120 Hz with a 1.5x scale. That is the single most
# expensive thing the compositor does on this machine, and on battery it buys
# nothing you notice -- halving the refresh rate roughly halves the per-second
# render work for the whole desktop.
#
# `watch` is event-driven off udev, not a poll loop, so it costs nothing while
# the power state is not changing.
#
# Started by autostart.lua. Run `power-refresh.sh apply` by hand after changing
# the modes below.
#
# -----------------------------------------------------------------------------
# SINGLE INSTANCE
#   This holds its own flock rather than being guarded by a `pgrep` in
#   autostart.lua. That is deliberate and load-bearing: the pgrep form was
#   `pgrep -f '[p]ower-refresh.sh watch'`, and `pgrep -f` matches the whole
#   command line of every process -- including the `sh -c` wrapper that was
#   about to launch this script, whose argv contains this very path. The guard
#   matched itself, reported "already running", and THIS SCRIPT NEVER STARTED
#   ONCE. The panel sat at 120 Hz on battery for the life of that line.
#
#   A lock held by the running process cannot be fooled that way, and it also
#   covers being started by hand while a watcher is already up.
# -----------------------------------------------------------------------------

set -eu

INTERNAL="eDP-1"
AC_ONLINE="/sys/class/power_supply/ADP1/online"

# Keep these in sync with monitors.lua -- position and scale have to be repeated
# because hl.monitor replaces the whole entry rather than patching the mode.
MODE_AC="2880x1800@120"
MODE_BATTERY="2880x1800@60"
POSITION="auto-right"
SCALE="1.5"

LOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-power-refresh.lock"

# Seconds before the event window closes and the power state is re-checked
# unconditionally. See the note in the watch branch.
RECHECK=120

on_ac() {
    # Missing file (desktop, or a kernel that names it differently) reads as
    # "on AC", which is the safe default: full refresh rate.
    [ ! -r "$AC_ONLINE" ] || [ "$(cat "$AC_ONLINE")" = "1" ]
}

# The refresh rate eDP-1 is actually running at, rounded, or empty if it cannot
# be read.
#
# jq, not python3: this runs on every udev power_supply event, and a python
# interpreter start is ~40 ms against jq's ~5 ms for pulling one number out of
# one object. Every sibling script in this directory already uses jq.
current_hz() {
    hyprctl monitors -j 2>/dev/null \
        | jq -r --arg m "$INTERNAL" 'map(select(.name == $m)) | .[0].refreshRate // empty | round' 2>/dev/null \
        || true
}

apply() {
    if on_ac; then
        mode="$MODE_AC"
    else
        mode="$MODE_BATTERY"
    fi

    # Only touch the monitor if the rate actually needs to change; re-applying
    # an identical mode still makes Hyprland re-do a modeset, which flickers.
    want_hz=${mode##*@}
    want_hz=${want_hz%%.*}
    have_hz=$(current_hz)

    [ "$want_hz" = "$have_hz" ] && return 0

    hyprctl eval "hl.monitor({
        output   = '$INTERNAL',
        mode     = '$mode',
        position = '$POSITION',
        scale    = $SCALE,
    })" >/dev/null 2>&1 || true
}

case "${1:-apply}" in
    apply)
        apply
        ;;
    watch)
        # Refuse to start a second watcher. -n so this exits quietly rather
        # than queueing behind the one already running.
        exec 9>"$LOCK"
        if ! flock -n 9; then
            exit 0
        fi

        apply

        # -------------------------------------------------------------
        # EVENT-DRIVEN, WITH A SAFETY RE-CHECK. Both halves are needed.
        #
        # The pure-udev version of this loop did not work on this machine.
        # Measured: the watcher accumulated ZERO CPU time across an AC unplug
        # that definitely happened (ADP1/online went 1 -> 0 and the panel stayed
        # at 120 Hz), so no power_supply event ever reached it. Whether udev
        # simply does not republish these here, or does so in a form the
        # monitor filter misses, is not something this script can find out --
        # and `udevadm trigger` needs root, so it cannot even be tested.
        #
        # Rather than trust an event source that has been observed not to
        # arrive, wrap the monitor in a bounded window: events still act within
        # milliseconds when they DO arrive, and when the window closes the
        # state is re-checked regardless. So the worst case is a stale refresh
        # rate for one window rather than for the rest of the session.
        #
        # Both --kernel and --udev: kernel uevents are emitted directly by the
        # power_supply driver on every state change, so they do not depend on
        # any rule processing.
        #
        # The re-check costs one `hyprctl monitors -j` plus one jq every two
        # minutes, and apply() returns immediately when the rate already
        # matches. That is a rounding error against a panel left at 120 Hz.
        # -------------------------------------------------------------
        while :; do
            timeout "$RECHECK" udevadm monitor --kernel --udev \
                --subsystem-match=power_supply 2>/dev/null 9>&- \
            | while IFS= read -r line; do
                # Real event lines are "KERNEL[123.45] change /devices/..."
                # or "UDEV[...]". Everything else is udevadm's two-line banner
                # ("KERNEL - the kernel uevent") or the blank separator it
                # prints after each event.
                #
                # Matching the bracket is what distinguishes them, and it
                # matters because the banner is reprinted every time the
                # RECHECK window restarts udevadm -- filtering only blanks ran
                # apply() four times per cycle instead of once.
                #
                # Safe to pattern-match here in a way it would not have been on
                # its own: if this prefix ever stopped matching, the
                # unconditional re-check below still corrects the rate every
                # RECHECK seconds. The filter is an optimisation, not the
                # correctness guarantee.
                case "$line" in
                    KERNEL\[*|UDEV\[*) apply ;;
                esac
              done 9>&-

            # The window closed (or udevadm died). Re-check, then re-listen.
            apply
        done
        ;;
    *)
        echo "usage: power-refresh.sh [apply|watch]" >&2
        exit 1
        ;;
esac
