#!/usr/bin/env bash
# Open the sioyek cheatsheet, rebuilding it first if your config has changed.
# Usage: help.sh <sioyek_path> [--rebuild]
set -uo pipefail

SIOYEK="${1:-/usr/bin/sioyek}"
FORCE="${2:-}"
PDF="$HOME/.local/share/sioyek/help/sioyek-cheatsheet.pdf"
GEN="$HOME/.config/sioyek/scripts/gen-cheatsheet.py"
KEYS="$HOME/.config/sioyek/keys_user.config"
LOG="$HOME/.local/share/sioyek/help/build.log"

status() { "$SIOYEK" --execute-command set_status_string --execute-command-data "$1" >/dev/null 2>&1 || true; }

needs_build=0
[[ -f "$PDF" ]]              || needs_build=1
[[ "$KEYS" -nt "$PDF" ]]     && needs_build=1
[[ "$GEN"  -nt "$PDF" ]]     && needs_build=1
[[ "$FORCE" == "--rebuild" ]] && needs_build=1

if (( needs_build )); then
    status "  building cheatsheet from your keybindings…"
    mkdir -p "$(dirname "$LOG")"
    if ! python3 "$GEN" "$PDF" >"$LOG" 2>&1; then
        status "  cheatsheet build failed — see $LOG"
        exit 1
    fi
fi

status "  cheatsheet"
exec "$SIOYEK" --new-window "$PDF"
