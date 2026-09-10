#!/usr/bin/env bash
# Wi-Fi picker for waybar's network module.
#
# The module used to open nm-connection-editor on click, which only lists
# connections that already exist - no help at all when the network you want is
# one you have never joined. This scans for what is actually in range, connects
# to the pick, and asks for a passphrase only when NetworkManager does not
# already have one saved.
#
# Right click on the module still opens nm-connection-editor for the cases it
# is genuinely better at (static IPs, VPNs, editing a saved profile).

set -uo pipefail

# waybar fires on-click on every click, so without this a second click while
# the picker is open stacks another wofi on top of the first.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/waybar-wifi-menu.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

STYLE="$HOME/.config/wofi/style.css"

# The drun config sets show=drun and a 6-column grid, which turns a dmenu list
# into an unreadable mosaic, so pick up the stylesheet but not the config.
menu() { # menu <prompt> <height px> [extra wofi args...]
    local prompt=$1 height=$2
    shift 2
    wofi --dmenu --insensitive --location center \
        --conf /dev/null --style "$STYLE" \
        --width 520 --height "$height" --prompt "$prompt" "$@"
}

notify() { notify-send -a "Wi-Fi" -i network-wireless "$1" "${2-}"; }
fail()   { notify-send -a "Wi-Fi" -u critical -i network-error "$1" "${2-}"; exit 1; }

dev=$(nmcli -t -f DEVICE,TYPE,STATE device \
    | awk -F: '$2 == "wifi" && $3 != "unavailable" {print $1; exit}')
[[ -n $dev ]] || dev=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "wifi" {print $1; exit}')
[[ -n $dev ]] || fail "No Wi-Fi device" "NetworkManager reports no wifi interface."

# Radio off: there is nothing to scan for, so offer to turn it back on.
if [[ $(nmcli -t -f WIFI general) != enabled ]]; then
    choice=$(printf '󰖩  Turn Wi-Fi on\n󰅖  Cancel\n' | menu "Wi-Fi is off" 180)
    [[ $choice == *"Turn Wi-Fi on"* ]] || exit 0
    nmcli radio wifi on || fail "Could not enable Wi-Fi"
    # The card needs a moment before it will return any scan results.
    sleep 2
fi

# Rescan so networks that appeared since the last scan show up. This is rate
# limited by NetworkManager and fails harmlessly when it was scanned recently,
# hence the discarded status.
nmcli device wifi rescan ifname "$dev" >/dev/null 2>&1 || true

bars() { # bars <signal 0-100>
    local s=$1
    if   (( s >= 75 )); then echo "󰤨"
    elif (( s >= 50 )); then echo "󰤥"
    elif (( s >= 25 )); then echo "󰤢"
    elif (( s >  0  )); then echo "󰤟"
    else                     echo "󰤯"
    fi
}

# nmcli terse output escapes literal colons as '\:', so swap those for a byte
# that cannot appear in the fields before splitting, then swap them back.
unescape() { printf '%s' "${1//$'\x01'/:}"; }

# Which SSID is actually joined. Worked out up front rather than from the
# IN-USE column below, because the connected AP is often a weaker duplicate of
# an SSID that also has a stronger one in range - the dedupe would then drop
# the very row carrying the marker.
active_ssid=""
while IFS= read -r raw; do
    IFS=: read -r inuse ssid <<<"${raw//\\:/$'\x01'}"
    if [[ $inuse == "*" ]]; then
        active_ssid=$(unescape "$ssid")
        break
    fi
done < <(nmcli -t -f IN-USE,SSID device wifi list ifname "$dev" --rescan no)

declare -A ACTION=() SEEN=()
entries=""

while IFS= read -r raw; do
    [[ -n $raw ]] || continue
    IFS=: read -r inuse signal security ssid <<<"${raw//\\:/$'\x01'}"
    ssid=$(unescape "$ssid")

    # Hidden APs advertise an empty SSID; they cannot be joined by name from
    # this list, and the "Hidden network" entry below covers them properly.
    [[ -n $ssid ]] || continue
    # The same SSID shows up once per AP and per band. The list is already
    # sorted by signal, so the first sighting is the strongest one.
    [[ -z ${SEEN[$ssid]-} ]] || continue
    SEEN[$ssid]=1

    mark="  "
    [[ -n $active_ssid && $ssid == "$active_ssid" ]] && mark="󰄬 "
    lock=""
    [[ -n $security ]] && lock=" 󰌾"

    label=$(printf '%s%s  %s%s  ·  %s%%' "$mark" "$(bars "${signal:-0}")" "$ssid" "$lock" "${signal:-0}")
    ACTION[$label]="connect:$ssid:$security"
    entries+="$label"$'\n'
done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list ifname "$dev" --rescan no)

l_hidden="󰘓  Hidden network…"
l_off="󰖪  Turn Wi-Fi off"
l_editor="󰒓  Connection editor…"
ACTION[$l_hidden]="hidden"
ACTION[$l_off]="off"
ACTION[$l_editor]="editor"
entries+="$l_hidden"$'\n'"$l_off"$'\n'"$l_editor"

choice=$(printf '%s\n' "$entries" | menu "Wi-Fi" 420) || exit 0
[[ -n $choice ]] || exit 0
action=${ACTION[$choice]-}
[[ -n $action ]] || exit 0

# Try the plain join first: a saved profile brings its own secrets, so this
# succeeds without ever prompting for a network you have been on before. Only
# when that fails on a secured network do we ask for a passphrase.
join() { # join <ssid> <security> [extra nmcli args...]
    local ssid=$1 security=$2
    shift 2
    local out
    if out=$(nmcli --wait 25 device wifi connect "$ssid" ifname "$dev" "$@" 2>&1); then
        notify "Connected" "$ssid"
        return 0
    fi
    if [[ -z $security ]]; then
        fail "Could not connect to $ssid" "$out"
    fi

    local pass
    pass=$(menu "Password for $ssid" 120 --password </dev/null) || exit 0
    [[ -n $pass ]] || exit 0

    if out=$(nmcli --wait 25 device wifi connect "$ssid" ifname "$dev" password "$pass" "$@" 2>&1); then
        notify "Connected" "$ssid"
        return 0
    fi
    fail "Could not connect to $ssid" "$out"
}

case $action in
connect:*)
    rest=${action#connect:}
    ssid=${rest%:*}
    security=${rest##*:}
    join "$ssid" "$security"
    ;;
hidden)
    ssid=$(menu "Network name (SSID)" 120 </dev/null) || exit 0
    [[ -n $ssid ]] || exit 0
    # Security is unknown for a network that never showed up in a scan, so
    # assume it is secured and let join() fall through to the prompt.
    join "$ssid" "unknown" hidden yes
    ;;
off)
    nmcli radio wifi off && notify "Wi-Fi off"
    ;;
editor)
    setsid nm-connection-editor >/dev/null 2>&1 &
    ;;
esac
