#!/usr/bin/env bash
# Validate keys_user.config by booting a throwaway sioyek and reading the
# warnings it prints at load time.
#
# Run this after editing your keybindings. It cannot disturb your running
# sioyek: --ipc puts it in its own IPC namespace, so it starts as a primary
# instance instead of handing the file to your open window.
#
# Two classes of warning matter:
#   unreachable  a longer sequence is dead because a shorter one is already
#                a complete binding (e.g. `]]` is dead because `]` is bound)
#   duplicate    the same key bound twice inside your own file
# Overrides of /etc/sioyek/keys.config are listed separately; those are
# deliberate, and sioyek prints them on every startup no matter what
# (should_warn_about_user_key_override does not suppress them in 2.0.0).
set -uo pipefail

OUT=$(mktemp -t sioyek-keycheck.XXXXXX)
trap 'rm -f "$OUT"' EXIT

# stdbuf: sioyek block-buffers stdout when it is not a tty, and the SIGINT
# below would otherwise discard everything it printed.
QT_QPA_PLATFORM=offscreen timeout -s INT 12 \
  stdbuf -o0 -e0 unshare --user --map-root-user --ipc \
  sioyek --nofocus /usr/share/sioyek/tutorial.pdf >"$OUT" 2>&1

tidy() { sed 's/^Warning: //; s|'"$HOME"'/.config/sioyek/|~/|g; s|/etc/sioyek/|/etc/|g'; }

fail=0

echo "── unreachable keys ──"
if grep -q 'unreachable' "$OUT"; then
    grep 'unreachable' "$OUT" | tidy
    fail=1
else
    echo "  none"
fi

echo "── duplicate keys within your own file ──"
if grep -qE 'defined in .*\.config/sioyek.*overwritten by .*\.config/sioyek' "$OUT"; then
    grep -E 'defined in .*\.config/sioyek.*overwritten by .*\.config/sioyek' "$OUT" | tidy
    fail=1
else
    echo "  none"
fi

echo "── deliberate overrides of the default keyfile ──"
grep 'overwritten by' "$OUT" | grep 'defined in /etc/sioyek' \
  | sed 's/.*Overriding command: //' | sort | sed 's/^/  /' || echo "  none"

echo
(( fail )) && { echo "problems found"; exit 1; }
echo "keybindings are clean"
