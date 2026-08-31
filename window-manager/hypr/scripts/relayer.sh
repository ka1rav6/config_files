#!/usr/bin/env bash
# Re-arrange layer surfaces after a display change.
#
# THE BUG: when a monitor is added or removed, the remaining monitor gets a new
# position, but Hyprland does NOT move the layer surfaces that live on it. They
# keep their old coordinates and render off-screen. Unplugging the external
# left waybar and hyprpaper sitting at x=2560 while eDP-1 had moved to x=0, so
# the bar vanished and Hyprland's default background showed through where
# hyprpaper should have been.
#
# They were never crashing and never unpainted -- just drawn out of view. That
# is why force_renderer_reload and grim (wlr-screencopy) both did nothing:
# the surfaces were rendering correctly, at the wrong place.
#
# THE FIX: remapping any layer surface makes Hyprland re-arrange every layer
# surface on that output. Restarting waybar is enough -- it snaps hyprpaper
# back into place too. That is exactly what pressing SUPER+P did by accident,
# via slurp's fullscreen overlay.
#
# Locking: a previous version held an flock on fd 9, the backgrounded waybar
# inherited that fd, and every later run then deadlocked. The lock is back --
# `hyprctl reload` re-emits monitor.added once per connected monitor, so two
# copies of this script raced and each spawned its own waybar -- but every
# long-lived child is now started with 9>&- so nothing inherits the lock.

LOG="${XDG_RUNTIME_DIR:-/tmp}/hypr-relayer.log"
exec >>"$LOG" 2>&1
ts() { date +'%H:%M:%S.%3N'; }

echo "--- $(ts) relayer.sh (event=${1:-unknown}) ---"

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-relayer.lock"
if ! flock -n 9; then
    echo "$(ts)   another relayer run is in flight -- skipping"
    exit 0
fi

# Wait for the output list and monitor positions to stop moving.
prev=""
for _ in $(seq 1 12); do
    sleep 0.25
    cur=$(hyprctl monitors -j 2>/dev/null | jq -Sc '[.[]|{name,x,y}]' 2>/dev/null)
    [[ -n "$cur" && "$cur" == "$prev" ]] && break
    prev="$cur"
done
echo "$(ts)   monitors settled: $prev"

# True if every layer surface sits inside the monitor it belongs to.
layers_aligned() {
    hyprctl monitors -j > /tmp/.relayer-mons.json 2>/dev/null || return 1
    hyprctl layers -j  > /tmp/.relayer-lay.json  2>/dev/null || return 1
    python3 - <<'PY'
import json, sys
mons = {m["name"]: m for m in json.load(open("/tmp/.relayer-mons.json"))}
lay = json.load(open("/tmp/.relayer-lay.json"))
bad = []
for name, v in lay.items():
    m = mons.get(name)
    if not m:
        continue
    x0, y0 = m["x"], m["y"]
    x1 = x0 + m["width"] / m["scale"]
    y1 = y0 + m["height"] / m["scale"]
    for lvl in v.get("levels", {}).values():
        for it in lvl:
            if not (x0 - 1 <= it.get("x", 0) <= x1 and y0 - 1 <= it.get("y", 0) <= y1):
                bad.append(f"{name}:{it.get('namespace')}@{it.get('x')},{it.get('y')}")
print("MISALIGNED " + ", ".join(bad) if bad else "ALIGNED")
sys.exit(1 if bad else 0)
PY
}

restart_waybar() {
    pkill -x waybar 2>/dev/null
    sleep 0.4
    setsid --fork waybar -c "$HOME/.config/waybar/config.jsonc" \
        -s "$HOME/.config/waybar/style.css" >/tmp/waybar.log 2>&1 </dev/null 9>&-
    sleep 1.2
}

restart_hyprpaper() {
    local wp=""
    [[ -f "$HOME/.config/hypr/wallpaper.conf" ]] && \
        wp=$(awk -F' = ' '/^\$wallpaper = / { print $2 }' "$HOME/.config/hypr/wallpaper.conf")
    pkill -x hyprpaper 2>/dev/null
    sleep 0.4
    setsid --fork hyprpaper >/dev/null 2>&1 </dev/null 9>&-
    sleep 1.2
    if [[ -n "$wp" && -f "$wp" ]]; then
        hyprctl hyprpaper preload "$wp" >/dev/null 2>&1
        hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null | while IFS= read -r m; do
            [[ -n "$m" ]] && hyprctl hyprpaper wallpaper "$m,$wp,cover" >/dev/null 2>&1
        done
    fi
}

# A plain `hyprctl reload` also lands here (it re-emits monitor.added) but moves
# nothing, so bail out before killing a perfectly good bar.
before=$(layers_aligned) && { echo "$(ts)   before: $before -- nothing to do"; echo "$(ts) done"; exit 0; }
echo "$(ts)   before: $before"

# Remapping waybar re-arranges every layer surface on the output, hyprpaper included.
restart_waybar
status=$(layers_aligned) && { echo "$(ts)   after waybar restart: $status"; echo "$(ts) done"; exit 0; }

echo "$(ts)   still $status -- restarting hyprpaper too"
restart_hyprpaper
echo "$(ts)   final: $(layers_aligned)"
echo "$(ts) done"
