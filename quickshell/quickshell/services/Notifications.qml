pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Notifications — do-not-disturb, via mako.
// =============================================================================
// mako stays the notification daemon. This service does not replace it, does
// not register as a second daemon (two notification daemons on one bus is a
// race, not a feature), and does not draw notifications. It drives mako's
// mode system, which is how mako does DND:
//
//     makoctl mode -a do-not-disturb     silence
//     makoctl mode -r do-not-disturb     restore
//
// mako's own config in ~/.config/mako/config already understands the
// `do-not-disturb` mode by convention; if no matching [mode=do-not-disturb]
// block exists there, adding one is what makes the silence actually happen.
//
// Whether Quickshell should eventually take over notifications entirely is a
// separate decision, deliberately not made here -- mako works, is themed by
// theme-switch, and has a history browser bound to SUPER + N.
// =============================================================================

Singleton {
    id: root

    property bool dnd: false
    property bool available: true

    // Read mako's current mode list at startup so a DND left on from a previous
    // session is reflected rather than silently forgotten.
    Process {
        id: probe

        command: ["makoctl", "mode"]
        running: true

        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("do-not-disturb") !== -1) root.dnd = true;
            }
        }

        onExited: (code) => {
            // A non-zero exit means makoctl is missing or mako is not running.
            // Disable the tile rather than letting it silently do nothing.
            if (code !== 0) root.available = false;
        }
    }

    function setDnd(value) {
        if (!root.available) return;
        root.dnd = value;
        apply.command = ["makoctl", "mode", value ? "-a" : "-r", "do-not-disturb"];
        apply.running = true;
    }

    function toggle() {
        root.setDnd(!root.dnd);
    }

    Process {
        id: apply

        running: false
        onExited: (code) => {
            if (code !== 0)
                console.warn("[notifications] makoctl mode failed with", code);
        }
    }

    // Restore any notifications mako suppressed while DND was on. Same action
    // as the existing SUPER + CTRL + N bind.
    function restore() {
        restoreProc.running = true;
    }

    Process {
        id: restoreProc
        command: ["makoctl", "restore"]
        running: false
    }
}
