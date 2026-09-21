#!/usr/bin/env bash
# Preview the fastfetch Rubik's cube logo.
#   ./rubiks.sh            -> print the generated logo
#   ./rubiks.sh regen [W]  -> re-render logo.txt (W = cube half-cell width, default 7.5)
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "regen" ]]; then
    python3 "$dir/rubiks.py" "${2:-7.5}" > "$dir/logo.txt"
fi
cat "$dir/logo.txt"
