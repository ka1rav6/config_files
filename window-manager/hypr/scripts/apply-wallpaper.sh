#!/usr/bin/env bash
# =============================================================================
# apply-wallpaper.sh — set the desktop wallpaper.
# =============================================================================
# Usage:  apply-wallpaper.sh /absolute/path/to/image.jpg
#
# Updates the single source of truth (~/.config/hypr/wallpaper.conf), pushes the
# image to the running hyprpaper, and -- if the active theme is `auto` --
# re-derives the desktop palette from the new image.
#
# WHO READS wallpaper.conf
#   ~/.config/hypr/hyprpaper.conf   draws it on the desktop
#   ~/.config/hypr/hyprlock.conf    draws it behind the lock screen
#   ~/.local/bin/theme-switch       derives the `auto` palette from it
# Changing the path here is what keeps all three in step.
#
# WHY THE REWRITE IS SURGICAL NOW
#   This script used to do:
#
#       printf '$wallpaper = %s\n' "$path" > "$conf"
#
#   which truncated the file to that one line -- destroying all nine lines of
#   header comment in wallpaper.conf, including the comment telling you to keep
#   the `$wallpaper = <path>` shape intact. The first wallpaper change silently
#   deleted its own documentation. It now patches the single line in place and
#   leaves everything else alone, the same discipline theme-switch uses for its
#   THEME:START/THEME:END blocks.
# -----------------------------------------------------------------------------
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: apply-wallpaper.sh /absolute/path/to/image\n' >&2
    exit 2
fi

path=$(realpath "$1")
conf="$HOME/.config/hypr/wallpaper.conf"

if [[ ! -f "$path" ]]; then
    printf 'Not a file: %s\n' "$path" >&2
    exit 1
fi

# --- update the shared path --------------------------------------------------
# Patch the one line, preserving the rest of the file. If the line is somehow
# missing (a hand-edit gone wrong), append it rather than failing -- a desktop
# with no wallpaper is a worse outcome than a file with a comment out of order.
if grep -qE '^\s*\$wallpaper\s*=' "$conf" 2>/dev/null; then
    # A wallpaper path can contain & and |, which sed would interpret in the
    # replacement. Using a control character as the delimiter and escaping &
    # keeps arbitrary filenames working.
    escaped=${path//&/\\&}
    sed -i "s"$'\001'"^[[:space:]]*\$wallpaper[[:space:]]*=.*"$'\001'"\$wallpaper = ${escaped}"$'\001' "$conf"
else
    printf '$wallpaper = %s\n' "$path" >>"$conf"
fi

# --- push to the running daemon ----------------------------------------------
# hyprpaper 0.8.4 has ONE wallpaper command and it preloads implicitly.
#
# The older `preload` / `unload unused` / `listloaded` verbs that appear in most
# hyprpaper documentation DO NOT EXIST in this version -- they return
# "error: invalid hyprpaper request", and because hyprctl still exits 0 they
# failed completely silently here for a while. `listactive` and `wallpaper` are
# the only two this build accepts. Check before adding any others:
#
#     hyprctl hyprpaper listactive
#
# The `,cover` suffix is the fit mode, matching fit_mode in hyprpaper.conf.
for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$monitor,$path,cover" >/dev/null
done

# --- re-derive the palette, if the theme is wallpaper-driven -----------------
# `auto` means "this desktop's colours come from the wallpaper", so changing the
# wallpaper has to change the colours or the setting is a lie. Any other theme
# is a deliberate choice and is left completely alone.
#
# Runs in the background: theme-switch reloads waybar and Hyprland, which takes
# a couple of seconds, and the wallpaper itself has already changed by now.
theme_state="$HOME/.config/current-theme"
if [[ -r "$theme_state" && "$(cat "$theme_state")" == "auto" ]]; then
    if command -v theme-switch >/dev/null 2>&1; then
        setsid -f theme-switch auto >/dev/null 2>&1 || true
        notify-send "Wallpaper updated" "$(basename "$path") — re-deriving palette"
        exit 0
    fi
fi

notify-send "Wallpaper updated" "$(basename "$path")"
