#!/bin/sh
set -eu

screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"

case "${1:-}" in
    copy)
        grim -g "$(slurp)" - | wl-copy
        notify-send "Screenshot copied" "Selected area is in the clipboard"
        ;;
    save)
        file="$screenshot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        grim -g "$(slurp)" "$file"
        notify-send "Screenshot saved" "$file"
        ;;
    full)
        grim - | wl-copy
        notify-send "Screenshot copied" "Full screen is in the clipboard"
        ;;
    *)
        printf '%s\n' "Usage: screenshot.sh {copy|save|full}" >&2
        exit 2
        ;;
esac
