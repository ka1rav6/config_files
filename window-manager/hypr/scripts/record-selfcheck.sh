#!/bin/sh
# Checks record.sh's state machine, which is the only part of it with a way to
# be silently wrong: a stale pid file in $XDG_RUNTIME_DIR outlives the process,
# pids are reused, and a `stop` that trusted such a file would SIGINT whatever
# program happens to hold that pid now.
#
# Run it after touching running(), stop() or the status output:
#     ~/.config/hypr/scripts/record-selfcheck.sh
#
# It never starts a real recording -- the "live recorder" case is a copy of
# /bin/sleep renamed to wf-recorder, because /proc/<pid>/comm is what running()
# actually looks at.
set -u

R="$(dirname "$0")/record.sh"
S="${XDG_RUNTIME_DIR:-/tmp}/record.state"
fail=0

check() {
    if [ "$2" = "$3" ]; then
        echo "ok   $1"
    else
        echo "FAIL $1: got [$2] want [$3]"
        fail=1
    fi
}

gone() {
    if [ -d "$S" ]; then echo "FAIL $1: state dir left behind"; fail=1; else echo "ok   $1"; fi
}

rm -rf "$S"
check "no state -> module hidden" "$("$R" status)" '{"text":""}'

mkdir -p "$S"; echo $$ >"$S/pid"; echo /tmp/x.mp4 >"$S/file"
check "live pid, not a recorder -> hidden" "$("$R" status)" '{"text":""}'
gone "that stale state was cleaned"

mkdir -p "$S"; sh -c 'echo $$' >"$S/pid"; sleep 0.1
check "dead pid -> hidden" "$("$R" status)" '{"text":""}'
gone "that dead state was cleaned"

tmpd=$(mktemp -d); cp /bin/sleep "$tmpd/wf-recorder"; "$tmpd/wf-recorder" 5 &
p=$!
mkdir -p "$S"; echo "$p" >"$S/pid"; echo /tmp/demo.mp4 >"$S/file"
check "live wf-recorder -> REC" "$("$R" status)" \
    '{"text":"REC","class":"recording","tooltip":"Recording to /tmp/demo.mp4\nClick to stop"}'
kill "$p" 2>/dev/null
rm -rf "$S" "$tmpd"

echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; exit 1; fi
