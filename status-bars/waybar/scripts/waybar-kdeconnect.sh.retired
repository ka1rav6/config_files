#!/usr/bin/env bash
# =============================================================================
# waybar-kdeconnect.sh — the KDE Connect button's text, tooltip and CSS class.
# =============================================================================
# Replaces what the system tray used to give this bar: a glance at whether the
# phone is reachable. The tray is a StatusNotifier host and its one item
# belonged to kdeconnect-indicator, so its click could not be retargeted -- see
# the note on "custom/kdeconnect" in config.jsonc. This module can be, which is
# why it exists.
#
# OUTPUT
#   return-type json, so one script supplies text, tooltip and class together
#   and style.css can react to the connection state -- exactly the shape
#   waybar-hyprtodo.sh already uses next door.
#
# COST
#   One `kdeconnect-cli` every 30 s, plus an immediate refresh on
#   `pkill -SIGRTMIN+9 waybar`. The daemon is D-Bus activated and already
#   running (autostart.lua starts it at login), so this is a short-lived client
#   call, not a wake-up.
#
#   kdeconnect-cli prints its "N devices found" summary on stderr and the list
#   on stdout, hence the 2>/dev/null.
# =============================================================================
set -uo pipefail

# md-monitor_cellphone (a laptop and a phone together) when the device is
# reachable, md-cellphone_link_off when it is not -- so the shape itself says
# the state, not only the colour. Both verified present in
# ~/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf.
LINKED=$'\Uf0989'    # md-monitor_cellphone
AWAY=$'\Uf0122'      # md-cellphone_link_off

# Reachable AND paired devices, one id per line.
available=$(kdeconnect-cli -a --id-only 2>/dev/null | grep -c . || true)

if [ "${available:-0}" -gt 0 ]; then
    name=$(kdeconnect-cli -a --name-only 2>/dev/null | head -1)
    ICON=$LINKED
    class="connected"
    tooltip="${name:-Phone} — connected\rLeft-click: Command Center\rRight-click: KDE Connect app"
else
    ICON=$AWAY
    class="away"
    tooltip="No device reachable\rLeft-click: Command Center\rRight-click: KDE Connect app"
fi

# printf rather than a heredoc so the \r escapes survive into the JSON string;
# waybar renders \r as a newline in a tooltip.
printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$ICON" "$class" "$tooltip"
