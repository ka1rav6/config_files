#!/bin/sh
set -eu

screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"

pick_region() {
    slurp
}

capture_region() {
  dest=$1
  region=$(pick_region)
  grim -g "$region" "$dest"
}

# The *-save modes write the file AND put the same PNG on the clipboard, so a
# screenshot is immediately pasteable without digging the file out again. tee
# forks the one grim capture: the file gets a copy, wl-copy gets the stream.
case "${1:-}" in
    region|copy)
        capture_region - | wl-copy
        notify-send "Screenshot copied" "Selected area is in the clipboard"
        ;;
    region-save|save)
        file="$screenshot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        capture_region - | tee "$file" | wl-copy
        notify-send "Screenshot saved & copied" "$file"
        ;;
    full)
        grim - | wl-copy
        notify-send "Screenshot copied" "Full screen is in the clipboard"
        ;;
    full-save)
        file="$screenshot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        grim - | tee "$file" | wl-copy
        notify-send "Screenshot saved & copied" "$file"
        ;;
    *)
        cat >&2 <<'EOF'
Usage: screenshot.sh <mode>

Modes:
  region, copy       Select an area and copy to clipboard
  region-save, save  Select an area, save to ~/Pictures/Screenshots and copy
  full               Copy the full screen to clipboard
  full-save          Save the full screen to ~/Pictures/Screenshots and copy
EOF
        exit 2
        ;;
esac
