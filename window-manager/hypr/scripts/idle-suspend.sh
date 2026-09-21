#!/bin/sh
# Battery-gated idle suspend, driven by the 900s listener in hypridle.conf.
#
# Rule: as long as BAT0 is above THRESHOLD, the machine never suspends on idle
# -- plugged in or not, AC state is deliberately not consulted. At or below the
# threshold, idle suspends as it always did.
#
# Why a poller and not a single check: hypridle fires on-timeout exactly once
# and does not re-evaluate while the session stays idle. A one-shot `if battery
# > 20` would mean idling away at 50% disarms the suspend for the rest of that
# idle stretch, so the laptop would keep draining to 0 and hard-cut instead of
# suspending. This watcher re-checks every POLL seconds and suspends the moment
# the battery actually crosses the line. hypridle's on-resume kills it.
set -eu

THRESHOLD=20
POLL=60
battery=/sys/class/power_supply/BAT0
pidfile="${XDG_RUNTIME_DIR:-/tmp}/hypr-idle-suspend.pid"
lockfile="${XDG_RUNTIME_DIR:-/tmp}/hypr-idle-suspend.lock"

# Echoes the charge percentage, or nothing if it cannot be read. Only BAT0 is
# consulted: /sys/class/power_supply also carries the touchpad and the Logitech
# mouse, whose percentages have nothing to do with whether the laptop may sleep.
capacity() {
    [ -r "$battery/capacity" ] || return 0
    cat "$battery/capacity"
}

case "${1:-}" in
start)
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        exit 0
    fi
    # A stale pidfile from a SIGKILLed watcher would otherwise block every
    # later start for the rest of the session.
    rm -f "$pidfile"

    setsid "$0" watch >/dev/null 2>&1 </dev/null &

    # WAIT FOR THE PIDFILE BEFORE RETURNING. This is not tidiness, it closes a
    # real race.
    #
    # The watcher writes its own pidfile (it has to -- setsid means the pid
    # this shell sees in $! is not necessarily the watcher's). So between this
    # `start` returning and the watcher writing the file there was a window in
    # which the pidfile did not exist. hypridle fires `stop` from on-resume,
    # and a `stop` landing in that window found no pidfile, did nothing, and
    # returned success -- leaving a watcher running that had then dropped its
    # own pidfile on exit, so NOTHING could address it again. It would go on to
    # suspend the machine mid-use the next time the battery dipped below the
    # threshold. That is the worst failure mode this script has.
    #
    # Bounded so a watcher that fails to start can never hang the caller.
    i=0
    while [ "$i" -lt 50 ] && [ ! -f "$pidfile" ]; do
        i=$((i + 1))
        sleep 0.1
    done
    ;;
watch)
    # Refuse to run two watchers at once. Without this, two overlapping
    # start/stop cycles could leave a second watcher that the single pidfile
    # cannot name.
    exec 9>"$lockfile"
    if ! flock -n 9; then
        exit 0
    fi
    echo $$ >"$pidfile"
    # Two traps, not one. A bare `trap 'cleanup' TERM` runs the handler and
    # then RESUMES the loop -- the watcher would shrug off `stop`, lose its
    # pidfile so nothing could kill it later, and still suspend the machine
    # after you had come back. The signal trap must exit explicitly.
    trap 'rm -f "$pidfile"' EXIT
    trap 'rm -f "$pidfile"; exit 0' INT TERM
    while :; do
        level=$(capacity)
        # Unreadable battery: fall back to the old unconditional suspend
        # rather than silently keeping a laptop awake until it dies.
        if [ -z "$level" ] || [ "$level" -le "$THRESHOLD" ]; then
            systemctl suspend
            exit 0
        fi
        sleep "$POLL"
    done
    ;;
stop)
    if [ -f "$pidfile" ]; then
        pid=$(cat "$pidfile")
        # Signal the whole process group (setsid made the watcher its
        # leader) so the in-flight `sleep` dies too. Signalling just the
        # shell leaves it blocked in sleep, deferring the trap by up to
        # POLL seconds before it actually goes away.
        kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
        # Escalate rather than trust a single TERM. A watcher that outlives
        # `stop` is the worst failure mode here: it has dropped its pidfile,
        # so nothing can address it again, and it will suspend the machine
        # mid-use the next time the battery dips. Give it a moment, then
        # make sure.
        i=0
        while [ "$i" -lt 20 ] && kill -0 "$pid" 2>/dev/null; do
            i=$((i + 1))
            sleep 0.1
        done
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
        fi
        rm -f "$pidfile"
    fi
    ;;
*)
    echo "Usage: idle-suspend.sh start|stop" >&2
    exit 2
    ;;
esac
