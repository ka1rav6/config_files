#!/usr/bin/env bash
# Build (if needed), prove, and load the qs-pointer plugin into the running Hyprland.
#
# Run at login by autostart.lua; safe to run by hand any time.
#
#   1. A plugin is tied to the exact Hyprland build it was compiled against, so
#      the Hyprland commit it was built for is kept in .built-for. When Hyprland
#      changes (an update) or main.cpp changes, it is rebuilt.
#   2. Every new build is loaded into a throwaway nested Hyprland first
#      (selftest.sh -- a window flashes up for a few seconds). Only a build that
#      survived that is ever loaded into the real session. Compilers are tried
#      in order until one passes, because the right one is whichever Hyprland
#      itself was built with.
#   3. The proven build is loaded -- only if none is loaded yet. A running
#      plugin is never swapped live (that crashed the session once); a new
#      build is picked up at the next login.
#
# If nothing passes, Hyprland simply runs without it: the shell's cursor
# effects and bar hovers stay off and nothing else is affected. Logs are left
# in ~/.cache/qs-pointer (build.log, selftest.log).
set -u
dir="$(cd "$(dirname "$0")" && pwd)"
# Build output lives in the cache, not next to the source: this folder is
# backed up to a public dotfiles repo, which should hold source, not binaries.
out="${XDG_CACHE_HOME:-$HOME/.cache}/qs-pointer"
mkdir -p "$out"
so="$out/qs-pointer.so"
stamp="$out/built-for"
log="$out/build.log"

running="$(hyprctl version -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("commit",""))' 2>/dev/null)"
[[ -n "$running" ]] || { echo "qs-pointer: Hyprland is not answering" >&2; exit 1; }
headers="$(grep -s -m1 'GIT_COMMIT_HASH' /usr/include/hyprland/src/version.h | sed 's/.*"\(.*\)".*/\1/')"

if [[ ! -f "$so" || "$(cat "$stamp" 2>/dev/null)" != "$running" || "$dir/main.cpp" -nt "$so" ]]; then
    if [[ "$headers" != "$running" ]]; then
        echo "qs-pointer: headers are for '$headers' but Hyprland is '$running'; not building" >&2
        exit 1
    fi
    # Build in a scratch folder and only ever mv the result into place: a
    # compiler writing over the .so a running Hyprland has mapped rewrites its
    # code under it (random crashes anywhere).
    : >"$log"
    work="$out/build"
    mkdir -p "$work"
    candidate="$work/candidate.so"
    built=0
    for cxx in g++-14 clang++-20 g++-15 c++; do
        command -v "$cxx" >/dev/null || continue
        echo "== $cxx" >>"$log"
        rm -f "$work/qs-pointer.so"
        make -C "$dir" -B CXX="$cxx" OUT="$work" >>"$log" 2>&1 || continue
        mv "$work/qs-pointer.so" "$candidate"
        if QS_POINTER_OUT="$out" "$dir/selftest.sh" "$candidate" >>"$log" 2>&1; then
            mv -f "$candidate" "$so"
            echo "$running" >"$stamp"
            built=1
            echo "qs-pointer: built with $cxx, selftest passed" >&2
            break
        fi
        echo "qs-pointer: $cxx build failed its selftest" >>"$log"
    done
    rm -f "$candidate"
    [[ "$built" == 1 ]] || { echo "qs-pointer: no build passed, see $log" >&2; exit 1; }
fi

if hyprctl plugin list 2>/dev/null | grep -q 'qs-pointer'; then
    # Already loaded: leave it. Swapping a plugin inside a live session has
    # crashed Hyprland (2026-11-28), so a new build takes over at next login.
    echo "qs-pointer: already loaded; a new build is used from the next login" >&2
    exit 0
fi
# Load a uniquely named copy. dlopen hands back the copy it already has for a
# path it has seen, and the cache file itself must stay free to be replaced.
live="$out/loaded-$(date +%s%N).so"
cp "$so" "$live"
find "$out" -maxdepth 1 -name 'loaded-*.so' ! -path "$live" -delete
if hyprctl plugin load "$live"; then
    echo "$live" >"$out/loaded-from"
else
    rm -f "$live"
fi
