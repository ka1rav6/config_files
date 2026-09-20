pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Brightness — the backlight.
// =============================================================================
// The one service here that genuinely has to shell out. There is no D-Bus
// interface for the raw backlight that does not require either logind's
// session bus dance or root, and brightnessctl is already installed and already
// what ~/.config/hypr/bindings.lua uses for XF86MonBrightness{Up,Down}.
//
// SO IT IS WRITTEN TO NEVER POLL
//   The value is read ONCE at startup, straight from sysfs (a file read, not a
//   process spawn), and then only re-read when something changes it:
//
//     * this service changes it     -> the new value is already known
//     * the brightness keys change it -> sysfs is watched, see below
//     * hypridle dims at 240 s      -> same watch catches it
//
//   ~/.config/hypr/hypridle.conf dims to 10% after four minutes and restores on
//   resume, so the watch is what keeps the OSD and the Control Center slider
//   honest about what the screen is actually doing.
//
// WHY WRITES ARE THROTTLED
//   Dragging a slider at 120 Hz would spawn 120 brightnessctl processes a
//   second. The timer below collapses that to at most one write every 40 ms
//   while the UI stays perfectly smooth, because the UI binds to the value the
//   user is dragging, not to what sysfs has caught up to.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // The Intel panel's backlight. Named explicitly rather than globbed
    // because this machine has exactly one and the name is stable -- the same
    // device ~/.config/waybar/config.jsonc names in its `backlight` module.
    readonly property string device: "intel_backlight"
    readonly property string sysfsPath: "/sys/class/backlight/" + root.device

    property int maxValue: 0
    property int rawValue: 0

    readonly property bool available: root.maxValue > 0

    // 0..1.
    readonly property real brightness: root.available ? root.rawValue / root.maxValue : 0
    readonly property int percent: Math.round(root.brightness * 100)

    // What the UI shows while dragging, before the write has landed. Bound to
    // the real value except during a drag, so the slider never fights the
    // device.
    property real pending: -1
    readonly property real displayed: root.pending >= 0 ? root.pending : root.brightness

    // --- Reading ------------------------------------------------------

    // max_brightness never changes for a given panel, so this is read once and
    // the FileView is left loaded rather than watched.
    FileView {
        id: maxFile

        path: root.sysfsPath + "/max_brightness"
        preload: true
        printErrors: false
        onLoaded: root.maxValue = parseInt(maxFile.text()) || 0
    }

    // The live value. watchChanges is what makes this event-driven: the
    // brightness keys and hypridle both write here, and the kernel notifies.
    FileView {
        id: currentFile

        path: root.sysfsPath + "/brightness"
        preload: true
        printErrors: false
        watchChanges: true

        onLoaded: root.applyRead()
        onFileChanged: {
            currentFile.reload();
            root.applyRead();
        }
    }

    function applyRead() {
        const value = parseInt(currentFile.text());
        if (!isNaN(value)) root.rawValue = value;
    }

    // --- Writing ------------------------------------------------------

    function setBrightness(value) {
        if (!root.available) return;
        // Never all the way to zero. A backlight at 0 on this panel is
        // indistinguishable from the screen having failed, and with
        // AQ_NO_ATOMIC set (see ~/.config/hypr/defaults.lua) a blank panel is
        // exactly the symptom of a much worse bug -- so leave a floor and keep
        // the two states visually distinct.
        root.pending = Math.max(0.01, Math.min(1, value));
        writeThrottle.start();
    }

    function addBrightness(delta) {
        root.setBrightness(root.displayed + delta);
    }

    Timer {
        id: writeThrottle

        // ~25 writes/second at most. Below the point where the panel can
        // visibly step, and far below what a 120 Hz drag would produce.
        interval: 40
        repeat: false
        onTriggered: {
            if (root.pending < 0) return;
            const target = Math.round(root.pending * root.maxValue);
            // -n is not passed: brightnessctl's own minimum handling is less
            // useful than the explicit floor in setBrightness above.
            writeProc.command = ["brightnessctl", "--device=" + root.device,
                                 "set", target + ""];
            writeProc.running = true;
        }
    }

    Process {
        id: writeProc

        running: false
        onExited: (code) => {
            if (code !== 0)
                console.warn("[brightness] brightnessctl failed with", code);
            // Release the drag value only once the write has landed, so the
            // slider does not snap back to the old reading for one frame.
            root.pending = -1;
        }
    }

    // Keep dragging responsive: if the value moved again while a write was in
    // flight, schedule another as soon as it finishes.
    onPendingChanged: {
        if (root.pending >= 0 && !writeProc.running && !writeThrottle.running)
            writeThrottle.start();
    }
}
