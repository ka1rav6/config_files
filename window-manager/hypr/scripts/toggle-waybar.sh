#!/bin/sh
# SUPER+ALT+SPACE: hide the bar, or bring it back.
#
# The relaunch goes through waybar-ensure.sh instead of calling waybar here.
# waybar must be a child of hypr-ipc-shim or its workspace buttons stop
# working, and keeping a second copy of that launch line in this file is how
# it would get missed the next time it changes -- which has already happened
# once, in relayer.sh.

if pgrep -x waybar >/dev/null 2>&1; then
    pkill -x waybar
else
    exec "$HOME/.config/hypr/scripts/waybar-ensure.sh" --start
fi
