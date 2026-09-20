pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// ThemeCatalogue — the list of themes, and the one way to change one.
// =============================================================================
// Reads ~/.config/quickshell/themes.json, which ~/.local/bin/theme-switch
// regenerates on every apply. Adding a theme to the THEMES dict in that script
// makes it appear in Settings with no edit here -- the catalogue is derived,
// never maintained by hand.
//
// APPLYING GOES THROUGH theme-switch, NOT THROUGH THIS FILE
//   `apply()` runs the same command the Justfile does. That is the whole
//   design: theme-switch rethemes ghostty, bat, btop, waybar, wofi, wlogout,
//   mako, tmux, the Hyprland border gradient and Quickshell in one pass, with
//   its own marker-block safety and its own verification. Reimplementing any
//   part of that here would create a second source of truth and a way for the
//   GUI and the CLI to disagree.
//
//   The shell then repaints because services/Theme.qml is watching theme.json.
//   Nothing here pushes colours anywhere.
//
// IT IS SLOW, AND THAT IS FINE
//   A theme switch reloads waybar (with a restart fallback if SIGUSR2 kills
//   it), mako, Hyprland and tmux. Two to four seconds. The UI shows progress
//   rather than pretending it is instant.
// =============================================================================

Singleton {
    id: root

    readonly property string cataloguePath: Quickshell.env("HOME") + "/.config/quickshell/themes.json"

    // Emitted when a theme-switch run finishes, successfully or not.
    signal applied(string name, bool ok, string message)

    readonly property var themes: file.loaded && Array.isArray(adapter.themes) ? adapter.themes : []
    readonly property bool busy: apply.running

    // --- catalogue ------------------------------------------------------

    FileView {
        id: file

        path: root.cataloguePath
        preload: true
        printErrors: false
        watchChanges: true
        onFileChanged: file.reload()

        // Missing on first run, before theme-switch has ever been run with the
        // catalogue support. Generate it rather than showing an empty picker.
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                console.log("[themes] no catalogue, generating");
                generate.running = true;
            }
        }

        adapter: JsonAdapter {
            id: adapter

            // theme-switch writes { "themes": [ ... ] } rather than a bare
            // array, because JsonAdapter deserialises into named properties
            // and rejects an array at the document root outright:
            //   "Failed to deserialize json: not an object"
            property var themes: []
        }
    }

    Process {
        id: generate

        command: ["theme-switch", "--catalogue"]
        running: false
        onExited: (code) => {
            if (code === 0) file.reload();
            else console.warn("[themes] could not generate catalogue, exit", code);
        }
    }

    // --- applying --------------------------------------------------------

    property string pending: ""

    function apply(name) {
        if (apply.running) return false;
        root.pending = name;
        applyProc.command = ["theme-switch", name];
        applyProc.running = true;
        return true;
    }

    // `theme-switch <name>` verifies every marker block BEFORE touching
    // anything, so a failure here means nothing was changed -- the desktop is
    // never left half-themed.
    Process {
        id: applyProc

        running: false
        property string errorOutput: ""

        stderr: SplitParser {
            onRead: (line) => applyProc.errorOutput += line + "\n"
        }

        onExited: (code) => {
            const name = root.pending;
            root.pending = "";
            const ok = code === 0;
            if (!ok)
                console.warn("[themes] theme-switch", name, "exited", code, applyProc.errorOutput);
            applyProc.errorOutput = "";
            root.applied(name, ok, ok ? "" : "theme-switch exited " + code);
        }
    }

    readonly property alias apply: applyProc

    // Re-derive the `auto` palette from the current wallpaper. Called by the
    // wallpaper picker after a change, and by the Appearance page's refresh.
    function refreshAuto() {
        if (applyProc.running) return;
        root.pending = "auto";
        applyProc.command = ["theme-switch", "auto"];
        applyProc.running = true;
    }
}
