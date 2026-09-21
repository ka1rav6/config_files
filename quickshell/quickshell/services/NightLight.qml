pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// NightLight — the blue-light filter.
// =============================================================================
// Wraps wlsunset, because wlsunset has no runtime interface of its own: the
// only way to change anything is to stop the process and start a new one.
//
// -----------------------------------------------------------------------------
// IT CANNOT WORK ON THIS MACHINE RIGHT NOW, AND IT SAYS SO
//
// Colour temperature needs the wlr-gamma-control protocol. Hyprland advertises
// it, but aquamarine REFUSES to apply gamma on the legacy DRM interface, which
// ~/.config/hypr/defaults.lua deliberately pins us to with AQ_NO_ATOMIC=1 (an
// aquamarine 0.15.0 atomic-commit hang that blanks the panel -- a far worse
// bug than having no night light). Every modeset logs:
//
//     ERR from aquamarine ]: No support for gamma on the legacy iface
//
// So `wlsunset -t 4000` ran at every login as a resident no-op: a process, a
// wrapper shell and a Wayland connection producing an effect the compositor
// threw away. It has been removed from autostart.lua, and this service now
// reports `available = false` with a reason instead of offering a toggle that
// changes nothing.
//
// THE PROBE
//   AQ_NO_ATOMIC is set by the compositor's own config, so every process
//   Hyprland spawns -- this shell included -- inherits it. Reading it is an
//   in-process environment lookup: no subprocess, no log parsing, no guessing.
//   It is also exactly the variable that CAUSES the limitation, so the two can
//   never drift apart. Remove AQ_NO_ATOMIC from defaults.lua when aquamarine
//   is fixed and this lights up again on its own, with no edit here.
//
// WHY NOT gammastep
//   It has a D-Bus interface and would be nicer to drive. It is not installed,
//   wlsunset is, and both would hit exactly the same aquamarine refusal.
// =============================================================================

Singleton {
    id: root

    // Kelvin, the NIGHT temperature. Lower is warmer.
    property int temperature: 4000

    // The daytime temperature. 6500 K is neutral daylight, and it is what
    // wlsunset itself defaults to; named here so the two ends of the ramp are
    // visible together rather than one being implicit.
    readonly property int dayTemperature: 6500

    // -----------------------------------------------------------------
    // Availability
    // -----------------------------------------------------------------

    // See the header: the legacy DRM interface has no gamma support.
    readonly property bool gammaSupported: Quickshell.env("AQ_NO_ATOMIC") !== "1"

    property bool binaryPresent: false
    readonly property bool available: root.gammaSupported && root.binaryPresent

    // Shown in the UI instead of a dead switch, so "why is this greyed out"
    // is answerable without reading QML.
    readonly property string unavailableReason: {
        if (!root.gammaSupported)
            return "The compositor is on the legacy DRM interface (AQ_NO_ATOMIC=1), "
                 + "which cannot apply gamma. See ~/.config/hypr/defaults.lua.";
        if (!root.binaryPresent)
            return "wlsunset is not installed.";
        return "";
    }

    property bool active: false

    Process {
        id: probeBinary

        command: ["sh", "-c", "command -v wlsunset >/dev/null 2>&1"]
        running: true
        onExited: (code) => root.binaryPresent = (code === 0)
    }

    // Is an instance already up? Only meaningful where gamma works at all --
    // and autostart.lua no longer starts one, so this is now only ever true
    // because this service started it.
    Process {
        id: probeRunning

        command: ["pgrep", "-x", "wlsunset"]
        running: root.gammaSupported
        onExited: (code) => root.active = (code === 0)
    }

    // -----------------------------------------------------------------
    // Control
    // -----------------------------------------------------------------

    function setActive(value) {
        if (!root.available || value === root.active) return;
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

        // Start ONLY once the old process is genuinely gone.
        //
        // stop and start used to be fired in the same tick:
        //     stopProc.running = true; startProc.running = true;
        // which is a race, not a restart -- `pkill -x wlsunset` and the new
        // `wlsunset` are two independent processes, and pkill matches by name,
        // so it could just as easily kill the replacement as the original.
        // Losing that race left night light switched on in the UI with no
        // process behind it.
        onExited: if (root.pendingStart) { root.pendingStart = false; startProc.running = true; }
    }

    property bool pendingStart: false

    Process {
        id: startProc

        // -t is the night temperature, -T the day one. Both are passed
        // explicitly: the previous invocation was `wlsunset -t 4000`, where
        // 4000 is already wlsunset's own default for -t, so the flag changed
        // nothing -- and with no -l/-L and no -S/-s there was no schedule for
        // it to enter night mode on either.
        //
        // -S/-s give a fixed ramp rather than a location. Deliberate: a
        // latitude and longitude is a piece of personal data to hard-code into
        // a config for a feature that only dims the screen, and fixed times
        // are more predictable anyway.
        command: ["wlsunset",
                  "-t", root.temperature + "",
                  "-T", root.dayTemperature + "",
                  "-S", "07:00",
                  "-s", "19:30"]
        running: false
    }

    // Changing the temperature while it is on has to restart the daemon --
    // wlsunset reads its arguments once at launch. Debounced so dragging a
    // temperature slider does not respawn it on every frame.
    onTemperatureChanged: if (root.active) restart.restart()

    Timer {
        id: restart

        interval: 400
        onTriggered: {
            if (!root.active) return;
            // Sequenced, not simultaneous -- see stopProc.onExited.
            root.pendingStart = true;
            stopProc.running = true;
        }
    }
}
