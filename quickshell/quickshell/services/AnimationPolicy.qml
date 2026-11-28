pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// =============================================================================
// AnimationPolicy — Hyprland's window/workspace animations follow battery saver.
// =============================================================================
// When Performance.stopAnimations turns on, Hyprland's animations are switched
// off with `hyprctl eval` (the way this desktop writes to its Lua config; see
// services/WindowPolicy.qml for why not `keyword`). When it turns off they are
// put back to whatever they were before -- read from Hyprland at that moment,
// not assumed -- so a looknfeel.lua with animations disabled stays disabled.
//
// THE REMEMBERED VALUE
//   Kept in `remembered` and mirrored to a small cache file, so a shell restart
//   while saver is on does not read back "off" (our own doing) and later
//   "restore" that. Read from Hyprland only when nothing is remembered yet.
//
// `hyprctl reload` re-runs looknfeel.lua and turns them back on, so the off
// state is re-asserted after every reload while saver is still in force.
// =============================================================================
Singleton {
    id: root

    readonly property bool stop: Performance.stopAnimations && Settings.loaded
    // "" = nothing remembered (saver not in force); else "true" / "false".
    property string remembered: ""
    property bool fileReady: false

    function push(enabled) {
        setter.exec(["hyprctl", "eval", "hl.config({ animations = { enabled = " + (enabled ? "true" : "false") + " } })"]);
    }

    function remember(value) {
        root.remembered = value;
        memory.setText(value);
    }

    function enterSaver() {
        if (root.remembered !== "") root.push(false);   // already know what to restore
        else if (!reader.running) reader.running = true;
    }

    function leaveSaver() {
        if (root.remembered === "") return;
        root.push(root.remembered === "true");
        root.remember("");
    }

    function sync() {
        if (!root.fileReady) return;
        if (root.stop) root.enterSaver();
        else root.leaveSaver();
    }

    onStopChanged: root.sync()

    FileView {
        id: memory
        path: Quickshell.env("HOME") + "/.cache/quickshell/animations-before-saver"
        printErrors: false
        onLoaded: {
            root.remembered = memory.text().trim();
            root.fileReady = true;
            root.sync();
        }
        onLoadFailed: {
            root.fileReady = true;   // no file yet: nothing remembered
            root.sync();
        }
    }

    Process {
        id: reader
        command: ["hyprctl", "getoption", "animations:enabled"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.stop || root.remembered !== "") return;
                const m = this.text.match(/(?:bool|int):\s*(\w+)/);
                root.remember(!m || (m[1] !== "false" && m[1] !== "0") ? "true" : "false");
                root.push(false);
            }
        }
    }

    Process { id: setter }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // looknfeel.lua just switched them back on; switch them off again.
            if (event.name === "configreloaded" && root.stop)
                root.push(false);
        }
    }
}
