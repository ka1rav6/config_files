#!/usr/bin/env bash
# Battery readout for hyprlock. Prints nothing on desktops without a battery.

readonly MINT="#8ee3c1"
readonly AMBER="#f4c47b"
readonly CORAL="#ff9b85"
readonly MUTED="#bec7d0"

icons=("󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰁹")

for bat in /sys/class/power_supply/BAT*; do
    [[ -r "$bat/capacity" ]] || continue

    cap=$(<"$bat/capacity")
    status=$(<"$bat/status" 2>/dev/null)

    idx=$((cap / 10))
    (( idx > 9 )) && idx=9
    icon="${icons[$idx]}"

    if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
        icon="󰂄"
        color="$MINT"
        suffix='<span foreground="'"$MUTED"'" size="small"> charging</span>'
    elif (( cap <= 15 )); then
        color="$CORAL"
        suffix=""
    else
        color="$AMBER"
        suffix=""
    fi

    printf '<span foreground="%s"><b>%s</b></span>  <span foreground="%s" size="large"><b>%d%%</b></span>%s' \
        "$color" "$icon" "$color" "$cap" "$suffix"
    exit 0
done
