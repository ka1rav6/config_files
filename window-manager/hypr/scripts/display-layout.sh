#!/usr/bin/env bash
# Display layout switcher for the Hyprland *Lua* config.
#
# NOTE: `hyprctl keyword` is rejected under the Lua parser ("keyword can't work
# with non-legacy parsers. Use eval."), so everything here goes through
# `hyprctl eval` with the Lua API.
#
# Deliberately does NOT touch waybar, hyprpaper, or monitor hotplug events.
# It only changes the layout, nothing is backgrounded, and it holds no locks.
#
# Usage:
#   display-layout.sh toggle-mirror
#   display-layout.sh place <left|right|up|down>
#   display-layout.sh status

set -uo pipefail

EXTERNAL="HDMI-A-1"
INTERNAL="eDP-1"
INTERNAL_MODE="2880x1800@120"
INTERNAL_SCALE="1.5"

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-display-mode"

ev() { hyprctl eval "$1" >/dev/null 2>&1; }

note() { command -v notify-send >/dev/null 2>&1 && notify-send -a Display "Displays" "$1" || true; }

read_state() { [[ -r "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "extend:left"; }

external_present() {
    hyprctl monitors all -j 2>/dev/null \
        | jq -e --arg m "$EXTERNAL" 'any(.[]; .name == $m)' >/dev/null 2>&1
}

apply() {
    local mode="$1" placement="$2"

    if ! external_present; then
        ev "hl.monitor({ output = \"$INTERNAL\", disabled = false, mirror = \"none\", mode = \"$INTERNAL_MODE\", position = \"0x0\", scale = $INTERNAL_SCALE })"
        return
    fi

    if [[ "$mode" == "mirror" ]]; then
        ev "hl.monitor({ output = \"$EXTERNAL\", disabled = false, mirror = \"none\", mode = \"preferred\", position = \"0x0\", scale = \"auto\" })"
        ev "hl.monitor({ output = \"$INTERNAL\", disabled = false, mirror = \"$EXTERNAL\", mode = \"$INTERNAL_MODE\", scale = $INTERNAL_SCALE })"
        return
    fi

    local ext_pos int_pos
    case "$placement" in
        right) ext_pos="auto-right"; int_pos="0x0" ;;
        up)    ext_pos="auto-up";    int_pos="0x0" ;;
        down)  ext_pos="auto-down";  int_pos="0x0" ;;
        *)     ext_pos="0x0";        int_pos="auto-right" ;;   # left (default)
    esac

    ev "hl.monitor({ output = \"$INTERNAL\", disabled = false, mirror = \"none\", mode = \"$INTERNAL_MODE\", position = \"$int_pos\", scale = $INTERNAL_SCALE })"
    ev "hl.monitor({ output = \"$EXTERNAL\", disabled = false, mirror = \"none\", mode = \"preferred\", position = \"$ext_pos\", scale = \"auto\" })"
}

state=$(read_state)
mode="${state%%:*}"
placement="${state#*:}"
[[ "$placement" == "$mode" ]] && placement="left"

case "${1:-status}" in
    toggle-mirror)
        if [[ "$mode" == "mirror" ]]; then
            mode="extend"; note "Extended"
        else
            mode="mirror";  note "Duplicated"
        fi
        printf '%s:%s\n' "$mode" "$placement" >"$STATE_FILE"
        apply "$mode" "$placement"
        ;;
    place)
        placement="${2:-left}"
        mode="extend"
        printf '%s:%s\n' "$mode" "$placement" >"$STATE_FILE"
        note "External monitor: ${placement} of laptop"
        apply "$mode" "$placement"
        ;;
    status)
        printf 'mode=%s placement=%s\n' "$mode" "$placement"
        ;;
    *)
        printf 'Usage: %s [toggle-mirror|place <left|right|up|down>|status]\n' "$0" >&2
        exit 2
        ;;
esac
