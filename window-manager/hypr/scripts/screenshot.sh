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

case "${1:-}" in
    region|copy)
        capture_region - | wl-copy
        notify-send "Screenshot copied" "Selected area is in the clipboard"
        ;;
    region-save|save)
        file="$screenshot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        capture_region "$file"
        notify-send "Screenshot saved" "$file"
        ;;
    full)
        grim - | wl-copy
        notify-send "Screenshot copied" "Full screen is in the clipboard"
        ;;
    full-save)
        file="$screenshot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        grim "$file"
        notify-send "Screenshot saved" "$file"
        ;;
    *)
        cat >&2 <<'EOF'
Usage: screenshot.sh <mode>

Modes:
  region, copy       Select an area and copy to clipboard
  region-save, save  Select an area and save to ~/Pictures/Screenshots
  full               Copy the full screen to clipboard
  full-save          Save the full screen to ~/Pictures/Screenshots
EOF
        exit 2
        ;;
esac
