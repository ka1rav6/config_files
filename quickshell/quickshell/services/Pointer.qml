pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// =============================================================================
// Pointer — where the mouse is, from the qs-pointer Hyprland plugin.
// =============================================================================
// Quickshell only sees the pointer while it is over one of its own surfaces.
// The cursor effects and the hover dropdowns over the bar need it everywhere,
// so ~/.config/hypr/plugins/qs-pointer (loaded at login by its load.sh) posts
// it on Hyprland's event socket and this singleton turns that into properties.
//
// NOTHING FLOWS UNLESS SOMETHING ASKS
//   The plugin starts with every stream off. Consumers declare what they need
//   through the `want*` properties below (bindings, not calls), and this file
//   switches the plugin's streams on and off to match. With the cursor effects
//   off and no hover zones registered, the plugin posts nothing at all and
//   this file does nothing at all.
//
// ZONES
//   For hover, the plugin itself tests the pointer against rectangles and posts
//   only the enter/leave edges, so hovering costs nothing while the pointer is
//   anywhere else. Register with setZone(name, x, y, w, h) in Hyprland layout
//   coordinates; listen to zoneChanged(name, inside), or read inside(name).
//
// WITHOUT THE PLUGIN
//   `available` stays false, nothing here is ever sent, and every consumer is
//   expected to treat that as "feature off". It is probed at start and again
//   whenever Hyprland reloads, since load.sh may still be rebuilding the plugin
//   (~10 s) when the shell comes up after a Hyprland update.
// =============================================================================
Singleton {
    id: root

    // ---- what the plugin reports -------------------------------------------
    property bool available: false

    // Layout coordinates (the same space as Hyprland's monitor x/y).
    property real x: 0
    property real y: 0
    // Smoothed velocity in px per ms, for effects that lead the pointer.
    property real vx: 0
    property real vy: 0
    // ms timestamp of the last position event.
    property double lastMove: 0

    // Cursor shape name, "" while a client draws its own cursor.
    property string shape: ""

    signal pressed()
    signal released()
    signal moved()
    signal zoneChanged(string name, bool inside)

    // ---- what consumers want -------------------------------------------------
    // Each is a plain OR of the things that need it; consumers set these from
    // their own bindings (see CursorFx and BarHover).
    property bool wantTrack: false
    property bool wantClicks: false
    property bool wantShapes: false
    // Press bounce: on a click the plugin shows the theme's pop_<shape>
    // cursor. Only meaningful for the accent Fluent theme (CursorTheme sets it).
    property bool wantPop: false

    readonly property bool tracking: root.available && root.wantTrack

    // name -> { x, y, w, h }
    property var zones: ({})
    // name -> bool
    property var insideZones: ({})

    function inside(name) {
        return !!root.insideZones[name];
    }

    function setZone(name, x, y, w, h) {
        const z = { x: Math.round(x), y: Math.round(y), w: Math.round(w), h: Math.round(h) };
        const old = root.zones[name];
        if (old && old.x === z.x && old.y === z.y && old.w === z.w && old.h === z.h)
            return;
        const next = Object.assign({}, root.zones);
        next[name] = z;
        root.zones = next;
        if (root.available)
            root.send(["zone", name, z.x, z.y, z.w, z.h]);
    }

    function clearZone(name) {
        if (!(name in root.zones)) return;
        const next = Object.assign({}, root.zones);
        delete next[name];
        root.zones = next;
        if (root.insideZones[name]) {
            const ins = Object.assign({}, root.insideZones);
            delete ins[name];
            root.insideZones = ins;
            root.zoneChanged(name, false);
        }
        if (root.available)
            root.send(["unzone", name]);
    }

    // ---- talking to the plugin -----------------------------------------------
    // Commands are queued and sent one hyprctl at a time, in order, so a quick
    // on-off-on can never arrive reordered.
    property var queue: []

    function send(args) {
        root.queue = root.queue.concat([["hyprctl", "qspointer"].concat(args.map(String))]);
        if (!sender.running) root.flush();
    }

    function flush() {
        if (root.queue.length === 0) return;
        sender.command = root.queue[0];
        root.queue = root.queue.slice(1);
        sender.running = true;
    }

    Process {
        id: sender
        onExited: root.flush()
    }

    // Everything the plugin should currently be doing, sent in one go -- after
    // it (re)appears, and that is the only time all of it is needed.
    function pushAll() {
        root.send(["track", root.wantTrack ? 1 : 0]);
        root.send(["clicks", root.wantClicks ? 1 : 0]);
        root.send(["shapes", root.wantShapes ? 1 : 0]);
        root.send(["pop", root.wantPop ? 1 : 0]);
        root.send(["unzone", "*"]);
        for (const name in root.zones) {
            const z = root.zones[name];
            root.send(["zone", name, z.x, z.y, z.w, z.h]);
        }
    }

    onWantTrackChanged: if (root.available) root.send(["track", root.wantTrack ? 1 : 0])
    onWantClicksChanged: if (root.available) root.send(["clicks", root.wantClicks ? 1 : 0])
    onWantShapesChanged: if (root.available) root.send(["shapes", root.wantShapes ? 1 : 0])
    onWantPopChanged: if (root.available) root.send(["pop", root.wantPop ? 1 : 0])
    onAvailableChanged: if (root.available) root.pushAll()

    // ---- probing -------------------------------------------------------------
    property int probes: 0

    function probe() {
        if (prober.running) return;
        prober.running = true;
    }

    Process {
        id: prober
        command: ["hyprctl", "qspointer", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = this.text.indexOf("shape-hooks") >= 0;
                if (ok && !root.available) {
                    root.available = true;
                } else if (ok && root.available) {
                    // Plugin was reloaded under us: its state is fresh, ours
                    // is not. Hand it everything again.
                    if (this.text.indexOf("track 0") >= 0 && root.wantTrack) root.pushAll();
                } else {
                    root.available = false;
                    // load.sh may still be building it after an update.
                    if (root.probes < 12) retry.restart();
                }
            }
        }
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: { root.probes++; root.probe(); }
    }

    Component.onCompleted: root.probe()

    // ---- events --------------------------------------------------------------
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = event.name;
            if (name === "qspos") {
                const comma = event.data.indexOf(",");
                const nx = Number(event.data.slice(0, comma));
                const ny = Number(event.data.slice(comma + 1));
                const now = Date.now();
                const dt = Math.max(1, Math.min(100, now - root.lastMove));
                // Exponential smoothing: one twitchy frame must not throw a
                // lead-the-pointer effect across the screen.
                root.vx = root.vx * 0.6 + ((nx - root.x) / dt) * 0.4;
                root.vy = root.vy * 0.6 + ((ny - root.y) / dt) * 0.4;
                root.x = nx;
                root.y = ny;
                root.lastMove = now;
                root.moved();
            } else if (name === "qsclick") {
                if (event.data === "1") root.pressed();
                else root.released();
            } else if (name === "qsshape") {
                root.shape = event.data;
            } else if (name === "qszone") {
                const comma = event.data.lastIndexOf(",");
                const zone = event.data.slice(0, comma);
                const isIn = event.data.slice(comma + 1) === "1";
                const ins = Object.assign({}, root.insideZones);
                ins[zone] = isIn;
                root.insideZones = ins;
                root.zoneChanged(zone, isIn);
            } else if (name === "qspointer" && event.data === "loaded") {
                // A fresh plugin: nothing registered. Hand it everything.
                retry.stop();
                if (root.available) root.pushAll();
                else root.available = true;   // onAvailableChanged pushes
            } else if (name === "configreloaded") {
                root.probes = 0;
                root.probe();
            }
        }
    }
}
