#!/usr/bin/env bash
# Reassign workspace monitors when displays are connected or disconnected.

set -euo pipefail

EXTERNAL="HDMI-A-1"
INTERNAL="eDP-1"

monitors=$(hyprctl monitors -j)

has_external=$(jq -r --arg m "$EXTERNAL" 'any(.[]; .name == $m)' <<<"$monitors")
has_internal=$(jq -r --arg m "$INTERNAL" 'any(.[]; .name == $m)' <<<"$monitors")

assign() {
    local monitor=$1
    shift
    for ws in "$@"; do
        hyprctl keyword "workspace $ws, monitor:$monitor" >/dev/null
    done
}

if [[ "$has_external" == "true" && "$has_internal" == "true" ]]; then
    assign "$EXTERNAL" 1 2 3 4 5 6 7
    assign "$INTERNAL" 8 9 10
elif [[ "$has_internal" == "true" ]]; then
    assign "$INTERNAL" $(seq 1 10)
elif [[ "$has_external" == "true" ]]; then
    assign "$EXTERNAL" $(seq 1 10)
fi
