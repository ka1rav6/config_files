pragma Singleton

import QtQuick
import Quickshell
import qs

// =============================================================================
// Shell — the panel registry and traffic warden.
// =============================================================================
// Every panel registers itself here on construction. That buys three things
// nothing else can:
//
//   1. MUTUAL EXCLUSION. Opening the launcher closes the Control Center.
//      Without a central registry each panel would need a reference to every
//      other one -- which is what the CachyOS rice does, and its shell.qml has
//      a closeOthers() listing eleven components by hand, plus a web of
//      cross-references wiring them together. Here a panel knows only its own
//      name.
//
//   2. ONE IPC SURFACE. shell.qml can expose `open`, `close` and `toggle` for
//      every panel generically instead of hand-writing an IpcHandler per panel.
//
//   3. GRACEFUL ABSENCE. A panel disabled in Settings is never constructed, so
//      it never registers, so asking to open it is a no-op that returns a clear
//      message rather than a crash. That is what makes the feature toggles
//      genuinely independent: turning the dock off cannot break SUPER + A.
//
// REGISTRATION
//   A Panel registers in Component.onCompleted and unregisters in
//   Component.onDestruction. Both halves matter -- a LazyLoader tearing a panel
//   down without unregistering would leave a dangling QObject reference here,
//   and calling a method on a destroyed QObject is one of the few ways to take
//   a QML process down hard.
// =============================================================================

Singleton {
    id: root

    // name -> panel object.
    property var panels: ({})

    function register(name, panel) {
        const next = {};
        for (const k in root.panels) next[k] = root.panels[k];
        next[name] = panel;
        root.panels = next;
    }

    function unregister(name) {
        if (root.panels[name] === undefined) return;
        const next = {};
        for (const k in root.panels) { if (k !== name) next[k] = root.panels[k]; }
        root.panels = next;
    }

    // The desktop widget layer. Not a Panel -- it never opens or closes -- but
    // Settings needs a way to put it into arrange mode without shelling out to
    // `quickshell ipc call`, so it registers itself here.
    property var widgets: null

    // The session lock, when the Quickshell locker is enabled. Its surfaces are
    // built from a Component and cannot see the scope that owns the lock, so
    // they unlock through here.
    property var lock: null

    function has(name) {
        return root.panels[name] !== undefined;
    }

    // --- control ---------------------------------------------------------

    function open(name) {
        const panel = root.panels[name];
        if (!panel) return false;
        root.closeAll(name);
        panel.show();
        return true;
    }

    function close(name) {
        const panel = root.panels[name];
        if (!panel) return false;
        panel.hide();
        return true;
    }

    function toggle(name) {
        const panel = root.panels[name];
        if (!panel) return false;
        if (panel.open) {
            panel.hide();
        } else {
            root.closeAll(name);
            panel.show();
        }
        return true;
    }

    // Close everything, optionally sparing one. Called before opening a panel
    // so only ever one is up -- two overlapping translucent panels are
    // unreadable, and the focus grab can only belong to one of them anyway.
    function closeAll(except) {
        for (const name in root.panels) {
            if (name === except) continue;
            const panel = root.panels[name];
            if (panel && panel.open) panel.hide();
        }
    }

    readonly property var openPanels: {
        const list = [];
        for (const name in root.panels) {
            if (root.panels[name] && root.panels[name].open) list.push(name);
        }
        return list;
    }

    readonly property bool anyOpen: root.openPanels.length > 0

    // For `quickshell ipc call shell panels`.
    readonly property string summary: {
        const names = Object.keys(root.panels).sort();
        if (names.length === 0) return "no panels registered";
        return names.map(n => n + (root.panels[n].open ? " [open]" : "")).join(", ");
    }
}
