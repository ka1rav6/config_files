#!/usr/bin/env bash
set -euo pipefail
counts=$(hyprtodo-cli counts --json)
pending=$(printf '%s' "$counts" | sed -n 's/.*"pending":\([0-9]*\).*/\1/p')
critical=$(printf '%s' "$counts" | sed -n 's/.*"critical_pending":\([0-9]*\).*/\1/p')
overdue=$(printf '%s' "$counts" | sed -n 's/.*"overdue":\([0-9]*\).*/\1/p')
class="hyprtodo"
if [ "${critical:-0}" -gt 0 ] || [ "${overdue:-0}" -gt 0 ]; then class="$class urgent"; fi
printf '{"text": "󰄱 %s", "tooltip": "%s pending | %s critical | %s overdue", "class": "%s"}\n' \
  "${pending:-0}" "${pending:-0}" "${critical:-0}" "${overdue:-0}" "$class"
