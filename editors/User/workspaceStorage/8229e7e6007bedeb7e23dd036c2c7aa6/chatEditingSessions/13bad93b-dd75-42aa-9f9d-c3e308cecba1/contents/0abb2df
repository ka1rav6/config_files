#!/usr/bin/env bash
# Waybar custom/hyprtodo module (design doc section 15).
#
# This calls hyprtodo-cli directly against the SQLite database rather than
# launching the full GUI, per "The Waybar module should not launch a
# complete GUI process just to obtain the count."
#
# `hyprtodo-cli` currently only prints task lines, so counts are derived
# with grep here. Once `task_counts` (already exposed as a Tauri command in
# src-tauri/src/commands/mod.rs) is also exposed as `hyprtodo-cli counts
# --json`, replace this whole body with that single call.
#
# waybar config.jsonc:
#   "custom/hyprtodo": {
#     "exec": "~/.config/waybar/scripts/waybar-hyprtodo.sh",
#     "return-type": "json",
#     "interval": 30,
#     "on-click": "hyprctl dispatch togglespecialworkspace todo"
#   }

set -euo pipefail

# `hyprtodo-cli list` doesn't print criticality today, so this module only
# shows the pending count for now. Add a criticality column to the CLI's
# list output (or a `counts --json` subcommand) before wiring the critical
# badge below.
counts=$(hyprtodo-cli counts --json)
pending=$(printf '%s' "$counts" | sed -n 's/.*"pending":\([0-9]*\).*/\1/p')
critical=$(printf '%s' "$counts" | sed -n 's/.*"critical_pending":\([0-9]*\).*/\1/p')
overdue=$(printf '%s' "$counts" | sed -n 's/.*"overdue":\([0-9]*\).*/\1/p')
class="hyprtodo"
if [ "${critical:-0}" -gt 0 ] || [ "${overdue:-0}" -gt 0 ]; then class="$class urgent"; fi

printf '{"text": "󰄱 %s", "tooltip": "%s pending | %s critical | %s overdue", "class": "%s"}\n' \
  "${pending:-0}" "${pending:-0}" "${critical:-0}" "${overdue:-0}" "$class"
