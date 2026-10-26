#!/usr/bin/env bash
# Waybar custom/hyprtodo module (design doc section 15).
#
# This calls hyprtodo-cli directly against the SQLite database rather than
# launching the full GUI, per "The Waybar module should not launch a
# complete GUI process just to obtain the count."
#
# The CLI exposes the same count query used by the GUI, so this module never
# needs to launch the full application.
#
# waybar config.jsonc:
#   "custom/hyprtodo": {
#     "exec": "~/.config/waybar/scripts/waybar-hyprtodo.sh",
#     "return-type": "json",
#     "interval": 30,
#     "on-click": "hyprctl dispatch togglespecialworkspace todo"
#   }

set -euo pipefail

cli="$(command -v hyprtodo-cli || printf '%s' "$HOME/.local/bin/hyprtodo-cli")"
counts=$("$cli" counts --json)
pending=$(printf '%s' "$counts" | sed -n 's/.*"pending":\([0-9]*\).*/\1/p')
critical=$(printf '%s' "$counts" | sed -n 's/.*"critical_pending":\([0-9]*\).*/\1/p')
overdue=$(printf '%s' "$counts" | sed -n 's/.*"overdue":\([0-9]*\).*/\1/p')
class="hyprtodo"
if [ "${critical:-0}" -gt 0 ] || [ "${overdue:-0}" -gt 0 ]; then class="$class urgent"; fi

printf '{"text": "TODO %s", "tooltip": "%s pending | %s critical | %s overdue", "class": "%s"}\n' \
  "${pending:-0}" "${pending:-0}" "${critical:-0}" "${overdue:-0}" "$class"
