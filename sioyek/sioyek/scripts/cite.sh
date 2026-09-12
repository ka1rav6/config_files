#!/usr/bin/env bash
# Copy a ready-to-paste citation for the current spot.
#   with a selection:  > quoted text
#                      — Document Title, p. 42
#   without:           Document Title, p. 42
# Usage: cite.sh <sioyek_path> <file_name> <page_number(0-indexed)> <selected_text>
set -uo pipefail
SIOYEK="$1"; NAME="$2"; PAGE="${3:-0}"; shift 3
TEXT="${*:-}"

status() { "$SIOYEK" --execute-command set_status_string --execute-command-data "$1" >/dev/null 2>&1 || true; }

TITLE="${NAME%.*}"
PAGE_1=$(( ${PAGE%%.*} + 1 ))

if [[ -n "${TEXT// }" ]]; then
    QUOTE=$(printf '%s' "$TEXT" | python3 -c '
import sys, re
t = re.sub(r"[­‐-—-]\n\s*", "", sys.stdin.read())
t = re.sub(r"\s*\n\s*", " ", t)
print(re.sub(r"\s{2,}", " ", t).strip(), end="")
')
    OUT="> $QUOTE"$'\n'$'\n'"— *${TITLE}*, p. ${PAGE_1}"
else
    OUT="*${TITLE}*, p. ${PAGE_1}"
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null; then
    printf '%s' "$OUT" | wl-copy
elif command -v xclip >/dev/null; then
    printf '%s' "$OUT" | xclip -selection clipboard
else
    status "  no clipboard tool"; exit 1
fi
status "  citation copied — p. ${PAGE_1}"
