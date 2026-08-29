#!/usr/bin/env bash
# Update the shared wallpaper path and apply it to hyprpaper.

set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: apply-wallpaper.sh /absolute/path/to/image\n' >&2
    exit 2
fi

path=$(realpath "$1")
conf="$HOME/.config/hypr/wallpaper.conf"

printf '$wallpaper = %s\n' "$path" >"$conf"

hyprctl hyprpaper preload "$path" >/dev/null
hyprctl hyprpaper wallpaper ",$path,cover" >/dev/null

for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$monitor,$path,cover" >/dev/null
done

notify-send "Wallpaper updated" "$path"
