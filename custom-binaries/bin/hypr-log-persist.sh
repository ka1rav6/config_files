#!/bin/sh
# Mirrors Hyprland's run-time log (which lives on tmpfs and is lost on reboot)
# into ~/.local/state/hypr-debug/ so a suspend/resume failure can be read back
# after the forced reboot it usually requires. Started by hypr-log-persist.service.
OUT_DIR="$HOME/.local/state/hypr-debug"
mkdir -p "$OUT_DIR"
# Wait for Hyprland to create its instance directory and log.
LOG=""
while [ -z "$LOG" ]; do
    LOG=$(find "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" -name hyprland.log -type f 2>/dev/null | head -1)
    [ -z "$LOG" ] && sleep 2
done
STAMP=$(date +%Y-%m-%d_%H-%M-%S)
echo "=== mirroring $LOG from boot at $(uptime -s), started $STAMP ===" \
    >> "$OUT_DIR/hyprland-$STAMP.log"
exec tail -F -n +1 "$LOG" >> "$OUT_DIR/hyprland-$STAMP.log"
