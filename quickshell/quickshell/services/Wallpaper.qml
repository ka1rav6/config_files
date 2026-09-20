pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Wallpaper — the picker's view of the wallpaper, and the way to change it.
// =============================================================================
// hyprpaper remains the daemon that draws the wallpaper, and
// ~/.config/hypr/wallpaper.conf remains the single source of truth for which
// image it is -- hyprpaper, hyprlock and theme-switch all read that one line.
//
// NO NEW DAEMON
//   swww and awww were both considered and both rejected. They exist to give
//   transitions that hyprpaper does not have, at the cost of another resident
//   process holding decoded bitmaps. hyprpaper is already running, already has
//   a live IPC socket, and already keeps images preloaded so a change is
//   instant. Adding a second wallpaper daemon to cross-fade between images
//   would be exactly the duplication this migration exists to remove.
//
// CHANGING IT GOES THROUGH THE EXISTING SCRIPT
//   apply() runs ~/.config/hypr/scripts/apply-wallpaper.sh, which patches
//   wallpaper.conf in place, preloads and switches every monitor, unloads the
//   images no longer in use, and re-derives the `auto` palette if that is the
//   active theme. All of that logic lives in one place and the GUI is a caller
//   of it, not a reimplementation.
// =============================================================================

Singleton {
    id: root

    readonly property string directory: Settings.wallpaper.directory
    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/wallpaper.conf"
    readonly property string applyScript: Quickshell.env("HOME") + "/.config/hypr/scripts/apply-wallpaper.sh"

    // --- current ---------------------------------------------------------
    // Parsed out of wallpaper.conf rather than tracked separately, so the
    // picker cannot disagree with what is actually on screen -- including when
    // the wallpaper was changed from the command line.

    property string current: ""

    readonly property string name: {
        if (root.current === "") return "";
        const parts = root.current.split("/");
        return parts[parts.length - 1];
    }

    FileView {
        id: conf

        path: root.confPath
        preload: true
        printErrors: false
        watchChanges: true
        onFileChanged: { conf.reload(); root.parseConf(); }
        onLoaded: root.parseConf()
    }

    function parseConf() {
        // `$wallpaper = /absolute/path` — Hyprland config syntax, so it is
        // matched rather than parsed as anything structured.
        const match = /^\s*\$wallpaper\s*=\s*(.+?)\s*$/m.exec(conf.text());
        root.current = match ? match[1] : "";
    }

    // --- available images --------------------------------------------------
    // Listed on demand rather than watched: the folder changes rarely, and a
    // directory watcher plus a re-scan is cost the desktop pays forever for a
    // list that is looked at once a week.

    property var images: []
    readonly property int count: root.images.length

    function refresh() {
        // Matched by CONTENT, not by extension.
        //
        // The folder contains a file with no extension at all (it is an AVIF),
        // and an extension-only filter silently dropped it from the picker --
        // a wallpaper that exists, works perfectly in hyprpaper, and simply
        // never appeared. `file --mime-type` is the honest test for "is this
        // an image".
        //
        // One `file` call per entry rather than a single batched call with a
        // field separator: the batched form has to split the output back into
        // path and type, which is ambiguous for any filename containing the
        // separator. This folder already has a name with a space in it, so the
        // simple, correct form wins. It runs once per picker open over a dozen
        // files -- a few milliseconds.
        //
        // -print0 / read -d '' carries names with spaces and newlines intact.
        //
        // bash, not sh: /bin/sh is dash on Ubuntu and its `read` has no -d
        // flag, so the sh form fails with "Illegal option -d" and returns
        // nothing at all.
        list.command = ["bash", "-c",
            'find "$1" -maxdepth 1 -type f -print0 2>/dev/null |\n' +
            'while IFS= read -r -d "" f; do\n' +
            '  case "$(file -b --mime-type "$f" 2>/dev/null)" in\n' +
            '    image/*) printf "%s\\n" "$f" ;;\n' +
            '  esac\n' +
            'done | sort',
            "qs-wallpaper", root.directory];
        list.running = true;
    }

    Process {
        id: list

        running: false
        property var collected: []

        onRunningChanged: if (list.running) list.collected = []

        stdout: SplitParser {
            onRead: (line) => {
                const path = line.trim();
                if (path !== "") list.collected.push(path);
            }
        }

        onExited: root.images = list.collected
    }

    // --- thumbnails --------------------------------------------------------
    // The picker cannot use the wallpapers directly, for two reasons:
    //
    //   1. The Qt build in ~/Qt/6.8.3 ships imageformat plugins for gif, ico,
    //      jpeg and svg only. It cannot decode .webp or .avif at all, and this
    //      folder contains both -- they rendered as empty tiles with
    //      "Unsupported image format" in the log. (The system Qt6 has
    //      libqwebp.so, but it is 6.4.2 against a 6.8.3 runtime, so its plugins
    //      cannot be borrowed.) hyprpaper itself handles every one of these
    //      formats, so the files are perfectly usable as wallpapers -- it is
    //      only the preview that fails.
    //
    //   2. Size. The folder holds a 6.3 MB JPEG and a 3.2 MB PNG. Decoding
    //      those at native resolution to draw them 200 px wide costs a visible
    //      stall and tens of megabytes while the picker is open.
    //
    // So every wallpaper gets a small JPEG thumbnail, generated once by
    // ImageMagick into ~/.cache/quickshell/thumbs and reused afterwards. The
    // cache key is the source path's basename plus its size, so replacing an
    // image with a different one of the same name regenerates the thumbnail.

    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/thumbs"

    // path -> thumbnail path, for the ones already generated.
    property var thumbs: ({})

    property bool generating: false

    function thumbFor(path) {
        return root.thumbs[path] || "";
    }

    // Generate any missing thumbnails, all in one shell invocation rather than
    // one process per image -- fourteen `convert` spawns from QML would be
    // fourteen round trips and a visibly staggered grid.
    function buildThumbs() {
        if (root.images.length === 0 || root.generating) return;
        root.generating = true;

        // `identify`-free: the size suffix comes from stat, which is cheap.
        // -thumbnail (rather than -resize) strips metadata and uses a fast
        // path; [0] takes the first frame of an animated source.
        const script =
            'mkdir -p "$1" || exit 1\n' +
            'shift\n' +
            'for src; do\n' +
            '  key=$(printf "%s" "$src" | md5sum | cut -c1-16)\n' +
            '  sz=$(stat -c %s "$src" 2>/dev/null || echo 0)\n' +
            '  out="$THUMBS/${key}-${sz}.jpg"\n' +
            '  [ -f "$out" ] || convert "$src[0]" -thumbnail 420x -quality 82 "$out" 2>/dev/null\n' +
            '  [ -f "$out" ] && printf "%s\\t%s\\n" "$src" "$out"\n' +
            'done\n';

        thumbProc.command = ["bash", "-c",
            "THUMBS=\"$1\"; export THUMBS; " + script,
            "qs-thumbs", root.thumbDir].concat(root.images);
        thumbProc.collected = {};
        thumbProc.running = true;
    }

    Process {
        id: thumbProc

        running: false
        property var collected: ({})

        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.split("\t");
                if (parts.length === 2) thumbProc.collected[parts[0]] = parts[1];
            }
        }

        onExited: {
            root.generating = false;
            // Reassign rather than mutate: a `var` property does not notice an
            // in-place edit, so the grid would never see the new thumbnails.
            root.thumbs = thumbProc.collected;
        }
    }

    // Build thumbnails whenever the list changes.
    onImagesChanged: root.buildThumbs()

    // --- changing ----------------------------------------------------------

    property bool applying: false

    signal changed(string path)

    function apply(path) {
        if (root.applying || path === "") return;
        root.applying = true;
        applyProc.target = path;
        applyProc.command = [root.applyScript, path];
        applyProc.running = true;
    }

    Process {
        id: applyProc

        property string target: ""

        running: false
        onExited: (code) => {
            root.applying = false;
            if (code === 0) {
                // wallpaper.conf is watched, so `current` updates on its own.
                root.changed(applyProc.target);
            } else {
                console.warn("[wallpaper] apply-wallpaper.sh exited", code);
            }
        }
    }

    // Automatic rotation. Off by default; the interval is in minutes.
    //
    // Stopped entirely while the setting is off rather than running with a
    // huge interval, and it never fires while a change is already in flight --
    // apply-wallpaper.sh can take a moment when the `auto` theme has to
    // re-derive a palette from the new image.
    Timer {
        interval: Math.max(1, Settings.wallpaper.randomInterval) * 60000
        repeat: true
        running: Settings.wallpaper.random
            && Settings.wallpaper.randomInterval > 0
            && Settings.features.wallpaperManager
        onTriggered: if (!root.applying) root.random()
    }

    function random() {
        if (root.images.length === 0) return;
        // Avoid picking the one already showing, which otherwise happens
        // often enough with a small folder to look broken.
        let candidates = root.images.filter(p => p !== root.current);
        if (candidates.length === 0) candidates = root.images;
        root.apply(candidates[Math.floor(Math.random() * candidates.length)]);
    }

    Component.onCompleted: root.refresh()
}
