#!/bin/sh
#
# Focus the first live window matching any of the given classes.
#
#   focus-window.sh com.mitchellh.ghostty
#   focus-window.sh chromium google-chrome        # tries each, in order
#
# Used by ~/.config/mako/config, so clicking a notification jumps to the window
# that raised it.
#
# Why a script: the old `hyprctl dispatch focuswindow class:^(foo)$` form is
# pre-Lua syntax. Under the Lua config `hyprctl dispatch` evaluates its argument
# as Lua, so that string threw a parse error and the click did nothing. The Lua
# focus dispatcher wants a real window object rather than a selector string, so
# the lookup has to happen first -- and it has to be guarded, because focusing
# nil is an error rather than a no-op.
#
# Classes are matched exactly (hl.get_windows takes a literal app_id, not a
# regex), which is why alternatives are passed as separate arguments.

set -eu

for class in "$@"; do
    # %q-style quoting is not available in POSIX sh; class names are plain
    # app_ids from our own config, so a simple substitution is safe here.
    if hyprctl eval "
        local w = hl.get_windows({ class = '$class' })[1]
        if w then hl.dispatch(hl.dsp.focus({ window = w })) return 'hit' end
        return 'miss'
    " 2>/dev/null | grep -q hit; then
        exit 0
    fi
done

exit 0
