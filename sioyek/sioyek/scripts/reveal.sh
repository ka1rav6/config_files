#!/usr/bin/env bash
# Open the current document's folder in the file manager.
# Usage: reveal.sh <sioyek_path> <file_path>
set -uo pipefail
SIOYEK="$1"; FILE="${2:-}"
status() { "$SIOYEK" --execute-command set_status_string --execute-command-data "$1" >/dev/null 2>&1 || true; }
[[ -e "$FILE" ]] || { status "  no file open"; exit 0; }
DIR=$(dirname "$FILE")
if command -v nautilus >/dev/null; then nautilus --select "$FILE" >/dev/null 2>&1 &
elif command -v dolphin >/dev/null; then dolphin --select "$FILE" >/dev/null 2>&1 &
elif command -v thunar  >/dev/null; then thunar "$DIR" >/dev/null 2>&1 &
else xdg-open "$DIR" >/dev/null 2>&1 & fi
status "  opened $DIR"
