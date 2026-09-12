#!/usr/bin/env bash
# Yank the selection with PDF artefacts repaired:
#   - "exam-\nple"  ->  "example"   (de-hyphenate across line breaks)
#   - single newlines -> spaces      (unwrap hard-wrapped lines)
#   - blank lines preserved as paragraph breaks
# Usage: copy-clean.sh <sioyek_path> <text>
set -uo pipefail
SIOYEK="$1"; shift
TEXT="${*:-}"

status() { "$SIOYEK" --execute-command set_status_string --execute-command-data "$1" >/dev/null 2>&1 || true; }

if [[ -z "${TEXT// }" ]]; then
    status "  nothing selected"
    exit 0
fi

CLEAN=$(printf '%s' "$TEXT" | python3 -c '
import sys, re
t = sys.stdin.read()
t = t.replace("\r\n", "\n").replace("\r", "\n")
t = re.sub(r"[­‐-—-]\n\s*", "", t)   # de-hyphenate
t = re.sub(r"\n{2,}", "\x00", t)                    # protect paragraph breaks
t = re.sub(r"\s*\n\s*", " ", t)                     # unwrap
t = t.replace("\x00", "\n\n")
t = re.sub(r"[ \t]{2,}", " ", t)
t = t.replace("ﬁ", "fi").replace("ﬂ", "fl").replace(" ", " ").replace("­", "")
print(t.strip(), end="")
')

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null; then
    printf '%s' "$CLEAN" | wl-copy
elif command -v xclip >/dev/null; then
    printf '%s' "$CLEAN" | xclip -selection clipboard
else
    status "  no clipboard tool (wl-copy / xclip)"
    exit 1
fi

WORDS=$(printf '%s' "$CLEAN" | wc -w)
status "  yanked $WORDS words (cleaned)"
