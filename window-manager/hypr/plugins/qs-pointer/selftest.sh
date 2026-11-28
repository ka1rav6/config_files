#!/usr/bin/env bash
# Usage: selftest.sh PLUGIN.so
#
# Loads a plugin into a throwaway nested Hyprland (it appears for a few
# seconds as a window on the current desktop), exercises it, and reports
# whether that instance survived. Exit 0 means it is safe to load for real.
#
# WHY THIS EXISTS
#   A plugin built with a different compiler than Hyprland can crash the
#   compositor the moment it loads (that happened on 2026-11-28: GCC 15's
#   std::format internals against a Hyprland built with GCC 14). Loading into
#   the live session is the one step that can take the whole desktop down, so
#   load.sh never does it without this passing first.
#
# The live session is never touched: the nested instance is the one that did
# not exist before, and it is refused unless all its outputs are WAYLAND-*.
set -u
dir="$(cd "$(dirname "$0")" && pwd)"
so="$1"
live="${HYPRLAND_INSTANCE_SIGNATURE:-}"
runtime="$XDG_RUNTIME_DIR/hypr"
before=$(ls "$runtime")

logdir="${QS_POINTER_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/qs-pointer}"
mkdir -p "$logdir"
Hyprland -c "$dir/selftest.lua" >"$logdir/selftest.log" 2>&1 &
pid=$!
# The process started above is not necessarily the compositor (it may fork
# away), and a nested Hyprland ignores SIGTERM -- so the instance's own pid is
# looked up from hyprctl once it is up, and it is killed outright. Without
# this every selftest left a hidden nested Hyprland running.
real=""
cleanup() {
    for p in $pid $real; do kill -TERM "$p" 2>/dev/null; done
    sleep 0.5
    for p in $pid $real; do kill -KILL "$p" 2>/dev/null; done
    # ...and anything it forked that is still running its config.
    pkill -KILL -f "^Hyprland -c $dir/selftest.lua\$" 2>/dev/null
}
trap cleanup EXIT

sig=""
for _ in $(seq 50); do
    sleep 0.2
    for d in $(ls "$runtime"); do
        [[ "$d" == *.shim || "$d" == "$live" ]] && continue
        grep -qx "$d" <<<"$before" && continue
        [[ -S "$runtime/$d/.socket.sock" ]] && sig="$d"
    done
    [[ -n "$sig" ]] && break
done
[[ -n "$sig" && "$sig" != "$live" ]] || { echo "selftest: nested Hyprland did not start" >&2; exit 2; }
real="$(hyprctl instances -j 2>/dev/null | python3 -c "import json,sys; print(next((str(i['pid']) for i in json.load(sys.stdin) if i['instance']=='$sig'), ''))" 2>/dev/null)"
# Never the live session's own process.
livepid="$(hyprctl instances -j 2>/dev/null | python3 -c "import json,sys; print(next((str(i['pid']) for i in json.load(sys.stdin) if i['instance']=='$live'), ''))" 2>/dev/null)"
[[ -n "$real" && "$real" != "$livepid" ]] || real=""

H() { hyprctl -i "$sig" "$@"; }
H monitors -j | python3 -c 'import json,sys; ms=[m["name"] for m in json.load(sys.stdin)]; sys.exit(0 if ms and all(n.startswith("WAYLAND") for n in ms) else 1)' \
    || { echo "selftest: instance $sig is not nested, refusing" >&2; exit 2; }

H plugin load "$so" >/dev/null 2>&1
sleep 1
kill -0 "${real:-$pid}" 2>/dev/null || { echo "selftest: CRASHED on load" >&2; exit 1; }
H qspointer zone selftest 0 0 100 100 >/dev/null
H qspointer track 1 >/dev/null
H qspointer clicks 1 >/dev/null
H qspointer shapes 1 >/dev/null
H qspointer pop 1 >/dev/null
# invert hooks the renderer, so make it draw a few frames with it on
H qspointer invert 1 >/dev/null
H eval "hl.dispatch(hl.dsp.cursor.move({x=200,y=200}))" >/dev/null
H qspointer status | grep -q 'track 1' || { echo "selftest: plugin did not answer" >&2; exit 1; }
sleep 0.3
H eval "hl.dispatch(hl.dsp.cursor.move({x=400,y=300}))" >/dev/null
sleep 0.3
kill -0 "${real:-$pid}" 2>/dev/null || { echo "selftest: CRASHED after enabling" >&2; exit 1; }
# the inverted trail draws through that same hook: run every mode
for mode in comet dots sparks; do
    H qspointer trail "$mode" 300 8 >/dev/null
    for i in 0 1 2 3 4 5; do
        H eval "hl.dispatch(hl.dsp.cursor.move({x=$((200 + i * 30)),y=$((200 + i * 15))}))" >/dev/null
    done
    H qspointer status | grep -q "trail $mode" || { echo "selftest: trail $mode not taken" >&2; exit 1; }
    sleep 0.4
    kill -0 "${real:-$pid}" 2>/dev/null || { echo "selftest: CRASHED drawing the $mode trail" >&2; exit 1; }
done
H qspointer invert 0 >/dev/null
sleep 0.2
kill -0 "${real:-$pid}" 2>/dev/null || { echo "selftest: CRASHED turning invert off" >&2; exit 1; }
H qspointer invert 1 >/dev/null
H plugin unload "$so" >/dev/null 2>&1
sleep 0.3
kill -0 "${real:-$pid}" 2>/dev/null || { echo "selftest: CRASHED on unload" >&2; exit 1; }
echo "selftest: ok"
exit 0
