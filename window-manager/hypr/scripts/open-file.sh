#!/bin/sh
#
# Type-aware opener for yazi's `o` bind (~/.config/yazi/keymap.toml).
#
#   .pdf                          -> zathura
#   .md / .markdown               -> ghostwriter
#   .doc .docx .ppt .pptx .xls*   -> Google Chrome
#   .mp4 .mkv .webm .avi .mov ... -> VLC
#   anything else                 -> $EDITOR in a new terminal
#
# Adding a type is one line in the case block below.
#
# ---------------------------------------------------------------------------
# Why this script exists at all, rather than a bare `ghostty -e nvim <file>`:
#
# yazi normally runs inside the SUPER+E scratchpad, and Hyprland maps a newly
# created window onto the *active* workspace -- which, while a special workspace
# is showing, is that special workspace. Anything launched from the scratchpad
# therefore opened hidden, tiled beside yazi, and vanished again on the next
# toggle. Dismissing the scratchpad first hands focus back to the real
# workspace, so the app lands where you are actually looking.
#
# hyprctl eval is a synchronous IPC round-trip, so the switch has already
# happened before any app is started -- no race with the new window mapping.
# scratchpads.dismiss_active() is a no-op when no scratchpad is involved (the
# tiled yazi on SUPER+ALT+E, or yazi in any ordinary terminal), so this stays
# correct there too.
#
# Note: images still deliberately fall through to the editor here. SHIFT+O is
# the key for those -- it runs yazi's own opener table in
# ~/.config/yazi/yazi.toml, which routes them to eog.
#
# Video used to fall through too, on the same reasoning, and that was the one
# case where the rule was actively wrong: `o` is the key the hand reaches for,
# and a 4GB .mkv loaded into nvim is a frozen terminal, not a useful buffer.
# There is no scenario where an editor is the right answer for a video the way
# it occasionally is for a stray binary, so video now goes to VLC directly and
# matches what Enter already does via yazi's own rules. nvim is still reachable
# for a suspect file: SHIFT+Enter offers it as the last entry of the `play`
# opener list.

set -eu

hyprctl eval 'scratchpads.dismiss_active()' >/dev/null 2>&1 || true

# setsid detaches the child, so it survives this script and yazi exiting.
spawn() {
    setsid "$@" >/dev/null 2>&1 &
}

# Files that need an editor are collected rather than opened one at a time, so
# a multi-file selection gets a single editor with several buffers instead of a
# terminal per file.
#
# The positional parameters are the only array POSIX sh has, so the loop shifts
# each argument off the front and either handles it or re-appends it to the
# back. After exactly $# iterations, only the editor files are left in "$@".
count=$#
i=0

while [ "$i" -lt "$count" ]; do
    i=$((i + 1))
    file=$1
    shift

    # Lowercased copy purely for matching; the app always gets the real name.
    lower=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')

    case "$lower" in
    *.pdf)
        spawn zathura "$file"
        ;;
    *.md | *.markdown | *.mdown | *.mkd)
        spawn ghostwriter "$file"
        ;;
    *.ts)
        # .ts is two unrelated formats: TypeScript source and an MPEG transport
        # stream. Extension alone cannot tell them apart, and guessing wrong
        # either throws source code at VLC or a 4GB video at nvim, so this is
        # the one arm that pays for a look at the bytes.
        #
        # The test names the video cases rather than excluding the text ones,
        # because `file` does not call TypeScript text/* — it answers
        # application/javascript, so a "not text" test would have sent every
        # .ts source file to VLC. A transport stream has no magic bytes at
        # offset 0 and comes back application/octet-stream, hence the second
        # pattern; anything unrecognised is safer in an editor than in VLC.
        case $(file -bL --mime-type "$file" 2>/dev/null) in
        video/* | application/octet-stream) spawn vlc "$file" ;;
        *) set -- "$@" "$file" ;;
        esac
        ;;
    *.mp4 | *.mkv | *.webm | *.avi | *.mov | *.m4v | *.flv | *.wmv | *.mpeg | *.mpg | *.m2ts | *.mts)
        # One VLC per file rather than one VLC with a playlist: `o` on a
        # multi-selection of videos almost always means "show me each of
        # these", and VLC's default single-instance setting already folds them
        # into one window for anyone who has turned it on.
        spawn vlc "$file"
        ;;
    *.doc | *.docx | *.ppt | *.pptx | *.xls | *.xlsx)
        # Chrome wants an absolute path for a local file; a relative one is
        # interpreted as a search term.
        abs=$(realpath "$file" 2>/dev/null || printf '%s' "$file")
        spawn google-chrome "$abs"
        ;;
    *)
        set -- "$@" "$file"
        ;;
    esac
done

if [ "$#" -gt 0 ]; then
    # yazi runs this with the cwd already set to the directory being browsed,
    # so the new terminal inherits the right working directory.
    spawn ghostty --working-directory="$PWD" -e "${EDITOR:-nvim}" "$@"
fi
