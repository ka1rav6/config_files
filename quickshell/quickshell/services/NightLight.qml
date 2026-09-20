pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// NightLight — the blue-light filter.
// =============================================================================
// Wraps wlsunset, which ~/.config/hypr/autostart.lua already starts at login
// with `wlsunset -t 4000`. This does NOT introduce a second implementation: it
// controls that same daemon, by stopping and starting it, because wlsunset has
// no runtime interface of its own.
//
// WHY NOT gammastep
//   gammastep has a D-Bus interface and would be nicer to drive. It is not
//   installed, wlsunset is, and both do the same job -- adding a second
//   colour-temperature daemon to get a cleaner toggle would be exactly the
//   kind of duplication this migration exists to remove.
//
// STATE
//   Derived from whether the process is running, checked once at startup and
//   then tracked by this service, since this service is the only thing that
//   starts or stops it after login. No polling.
// =============================================================================

Singleton {
    id: root

    // Kelvin. 4000 matches the value in autostart.lua; lower is warmer.
    property int temperature: 4000

    property bool active: false
    readonly property bool available: true

    // Look once at startup to find out whether autostart.lua's instance is up,
    // so the tile does not claim "Off" while the screen is visibly warm.
    Process {
        id: probe

        command: ["pgrep", "-x", "wlsunset"]
        running: true
        onExited: (code) => root.active = (code === 0)
    }

    function setActive(value) {
        if (value === root.active) return;
        root.active = value;
        if (value) startProc.running = true;
        else stopProc.running = true;
    }

    function toggle() {
        root.setActive(!root.active);
    }

    Process {
        id: stopProc

        command: ["pkill", "-x", "wlsunset"]
        running: false
    }

    Process {
        id: startProc

        // -t is the night temperature. Without -S/-s wlsunset uses its own
        // sunrise/sunset schedule, which is what autostart.lua relies on too,
        // so the toggle and the login state stay equivalent.
        command: ["wlsunset", "-t", root.temperature + ""]
        running: false
    }

    // Changing the temperature while it is on has to restart the daemon --
    // wlsunset reads -t once at launch. Debounced so dragging a temperature
    // slider does not respawn it on every frame.
    onTemperatureChanged: if (root.active) restart.restart()

    Timer {
        id: restart

        interval: 400
        onTriggered: {
            if (!root.active) return;
            stopProc.running = true;
            startProc.running = true;
        }
    }
}
