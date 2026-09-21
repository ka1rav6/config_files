pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Cava — real audio spectrum data for the visualizer.
// =============================================================================
// THIS IS GENUINE FFT, NOT ANIMATED NOISE.
//
//   PipeWire capture of the default sink's monitor
//        |
//   cava  -- FFT, band grouping, its own smoothing
//        |  [output] method = raw, data_format = ascii
//        |  one line per frame, values 0..1000, ';' separated
//        v
//   Process { stdout: SplitParser }   <- this file
//        |
//   levels[]  0..1 per band, smoothed
//        v
//   modules/visualizer/  <- draws it
//
// cava is already installed (/usr/bin/cava) and does the DSP in C. Doing the
// FFT in QML instead would be both slower and pointless.
//
// -----------------------------------------------------------------------------
// WHAT IS DIFFERENT HERE FROM THE REFERENCE IMPLEMENTATIONS
//
// Both the CachyOS rice and Lucid run cava at 60 fps for as long as the
// visualizer is enabled -- through silence, on battery, behind a fullscreen
// game. Lucid dims the bars when nothing moves; neither stops the process.
// That is a decoded-audio-stream plus 60 wakeups a second, forever, to render
// a flat line.
//
// This version runs NO cava process at all unless every one of these is true:
//
//   1. Something is on screen that wants it        (demand refcount, below)
//   2. The performance profile allows it           (Performance.allowVisualizer:
//                                                   false in battery saver and
//                                                   while a window is fullscreen)
//   3. Audio is actually playing                   (Audio.audible, derived from
//                                                   PipeWire's own peak meter,
//                                                   which costs nothing because
//                                                   the graph computes it anyway)
//
// Condition 3 is the important one and is what neither reference does. A silent
// laptop runs zero FFT. Sound starts, cava spawns within a frame or two; sound
// stops, it exits after `idleTimeout` seconds.
//
// Framerate is also halved on battery (see Performance.visualizerFramerate),
// which halves the wakeup count for a difference that is not visible on bars
// that are already smoothed.
// -----------------------------------------------------------------------------
//
// THE CONFIG FILE
//   cava takes its band count only from a config file, never from argv, so the
//   file is rewritten and the process restarted whenever the count changes.
//   That is why band count changes are debounced -- dragging the slider in
//   Settings would otherwise respawn cava on every frame of the drag.
//
// TROUBLESHOOTING
//   Bars stay flat while music plays:
//     * check cava sees the monitor source, not the microphone:
//         cava -p ~/.cache/quickshell/cava.conf
//       should print rising numbers. `[input] method = pulse, source = auto`
//       follows the default OUTPUT's monitor, headphones included.
//     * check `quickshell ipc call visualizer status`
// -----------------------------------------------------------------------------

Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.cache/quickshell/cava.conf"

    // --- Demand -------------------------------------------------------
    // Several surfaces may want spectrum data (the desktop visualizer, a media
    // card in the Control Center). One cava process serves all of them at the
    // finest resolution anyone asked for, rather than one process each.
    //
    // Consumers call want(id, bands) when they appear and drop(id) when they
    // go. A Component.onDestruction that forgets to drop leaks a demand and
    // keeps cava alive -- so every consumer pairs them.
    property var demands: ({})

    readonly property int bands: {
        let best = 0;
        for (const key in root.demands)
            best = Math.max(best, root.demands[key]);
        return Math.min(256, best);
    }

    function want(id, count) {
        if (!id) return;
        const value = Math.max(8, Math.min(256, Math.round(count)));
        if (root.demands[id] === value) return;
        // Rebuild rather than mutate: a `var` property only emits its change
        // signal on assignment, so an in-place edit would leave `bands` stale.
        const next = {};
        for (const key in root.demands) next[key] = root.demands[key];
        next[id] = value;
        root.demands = next;
    }

    function drop(id) {
        if (!id || root.demands[id] === undefined) return;
        const next = {};
        for (const key in root.demands) {
            if (key !== id) next[key] = root.demands[key];
        }
        root.demands = next;
    }

    // --- Gating -------------------------------------------------------

    readonly property bool wanted: root.bands > 0

    // Tell Audio to attach its peak monitor only while we might need it.
    // Without this the monitor runs whenever the shell does.
    Binding {
        target: Audio
        property: "peakMonitorWanted"
        value: root.wanted && Performance.allowVisualizer
    }

    // The full gate. All three conditions from the header.
    readonly property bool shouldRun: {
        if (!root.wanted) return false;
        if (!Performance.allowVisualizer) return false;
        if (!Settings.visualizer.gateOnPlayback) return true;   // user opted out of gating
        // Either PipeWire hears something, or a player says it is playing.
        // The second covers the first half-second before the peak meter has
        // reported, so the bars do not lag the start of a track.
        return Audio.audible || Media.playing;
    }

    // --- Output -------------------------------------------------------

    // 0..1 per band, smoothed. Read by the renderer.
    property var levels: []

    // Perceptual response curve, precomputed over cava's entire output domain.
    //
    // cava is close to linear in amplitude, and linear amplitude looks dead:
    // ordinary music sits in the bottom third of the range and the bars barely
    // leave the floor. Raising the value to a power below 1 expands the quiet
    // end and compresses the loud end -- the same reason audio meters are
    // drawn in dB. 0.55 was picked by ear at normal listening volume.
    //
    // ascii_max_range is 1000, so the input is an integer 0..1000 and the
    // curve has exactly 1001 possible results. Computing them once turns 9,600
    // Math.pow calls a second (160 bands x 60 fps) into 9,600 array lookups.
    readonly property var curveTable: {
        const table = new Array(1001);
        for (let i = 0; i <= 1000; i++)
            table[i] = Math.pow(i / 1000, 0.55);
        return table;
    }

    // True while the bars are actually moving, as opposed to cava running but
    // the music being between tracks. Lets a widget fade out gracefully.
    property bool active: false

    // What the running process was started with. Compared against the wanted
    // values to decide whether a restart is needed.
    property int liveBands: 0
    property string liveConfig: ""

    // --- Process ------------------------------------------------------

    function configText(count) {
        // ascii_max_range 1000 gives three significant figures per band, which
        // is more than the eye resolves but makes the parse a plain integer
        // divide. bar_delimiter 59 is ';', frame_delimiter 10 is newline --
        // the newline is what SplitParser splits on.
        return "# Generated by ~/.config/quickshell/services/Cava.qml.\n"
             + "# Rewritten whenever the band count or framerate changes.\n"
             + "# Not the place to edit these -- use Settings > Desktop > Visualizer.\n"
             + "\n[general]\n"
             + "bars = " + count + "\n"
             + "framerate = " + Performance.visualizerFramerate + "\n"
             + "autosens = 1\n"
             + "\n[input]\n"
             // `pulse` + `auto` follows the default OUTPUT's monitor, so it
             // tracks headphone/speaker switches with no restart. Explicitly
             // NOT the default source, which is the microphone.
             + "method = pulse\n"
             + "source = auto\n"
             + "\n[output]\n"
             + "method = raw\n"
             + "raw_target = /dev/stdout\n"
             + "data_format = ascii\n"
             + "ascii_max_range = 1000\n"
             + "bar_delimiter = 59\n"
             + "frame_delimiter = 10\n"
             + "channels = mono\n"
             + "mono_option = average\n"
             + "\n[smoothing]\n"
             + "noise_reduction = " + Math.round(Settings.visualizer.noiseReduction) + "\n";
    }

    function apply() {
        if (!root.shouldRun) {
            proc.running = false;
            root.liveBands = 0;
            root.liveConfig = "";
            return;
        }
        // `liveConfig` and not just the band count: a framerate or
        // noise-reduction change alters the file without altering `bands`, and
        // comparing only bands made those changes no-ops until the next spawn.
        const wanted = root.configText(root.bands);
        if (proc.running && root.liveBands === root.bands && root.liveConfig === wanted)
            return;

        root.liveBands = root.bands;
        root.liveConfig = wanted;
        proc.running = false;

        // cava reads the band count only from a file, so write one and exec
        // over it in a single shell so there is no window where the file is
        // half-written. "$2%/*" strips the filename to get the directory.
        proc.command = ["sh", "-c",
            "mkdir -p \"${2%/*}\" && printf '%s' \"$1\" > \"$2\" && exec cava -p \"$2\"",
            "qs-cava", wanted, root.configPath];
        proc.running = true;
    }

    // Consecutive unexpected exits, reset whenever the gate legitimately
    // re-opens so a later session always gets a fresh set of attempts.
    property int restartAttempts: 0

    Timer {
        id: respawnDelay

        // Grows with each attempt: 400 ms, 800, 1200 ... Enough for a sink
        // switch to settle without hammering a condition that will not clear.
        interval: 400 * Math.max(1, root.restartAttempts)
        onTriggered: if (root.shouldRun) root.apply()
    }

    onShouldRunChanged: {
        root.restartAttempts = 0;
        if (root.shouldRun) {
            // Start immediately -- waiting for the debounce would clip the
            // first second of every track.
            stopDelay.stop();
            root.apply();
        } else {
            // Linger briefly before killing the process. Between two tracks in
            // a playlist there is a short silence, and respawning cava each
            // time would cost more than staying up through it.
            stopDelay.restart();
        }
    }

    onBandsChanged: restartDelay.restart()

    // cava reads EVERY one of these from the config file at startup and has no
    // way to be reconfigured while running, so anything that changes
    // configText() has to respawn it -- not just the band count.
    //
    // This was the band count alone, which made two documented behaviours
    // quietly untrue:
    //
    //   * the framerate slider in Settings > Visualizer did nothing until
    //     cava next happened to restart;
    //   * Performance.visualizerFramerate halves to 30 on battery, so
    //     "unplugging halves cava's wakeups" -- the headline battery saving in
    //     the header above -- did NOT happen if music was already playing when
    //     the charger came out, which is the exact moment it is meant to.
    //
    // Debounced through the same timer as the band count: dragging a slider
    // walks through every intermediate value, and each one would otherwise be
    // a process respawn.
    readonly property int watchedFramerate: Performance.visualizerFramerate
    readonly property int watchedNoiseReduction: Math.round(Settings.visualizer.noiseReduction)

    onWatchedFramerateChanged: if (proc.running) restartDelay.restart()
    onWatchedNoiseReductionChanged: if (proc.running) restartDelay.restart()

    // Resizing a widget walks the band count through every intermediate value.
    // Settle before respawning.
    Timer {
        id: restartDelay

        interval: 260
        onTriggered: root.apply()
    }

    Timer {
        id: stopDelay

        interval: Math.max(1, Settings.visualizer.idleTimeout) * 1000
        onTriggered: {
            if (!root.shouldRun) {
                proc.running = false;
                root.liveBands = 0;
                root.liveConfig = "";
                root.levels = [];
                root.active = false;
            }
        }
    }

    // Declare the bars still after a moment with no movement, so a widget can
    // fade rather than freeze. Only runs while the process does.
    Timer {
        interval: 120
        repeat: true
        running: proc.running
        onTriggered: root.active = Date.now() - root.lastMotion < 500
    }

    property double lastMotion: 0

    Process {
        id: proc

        running: false

        onRunningChanged: {
            if (!proc.running) {
                root.levels = [];
                root.active = false;
            }
        }

        onExited: (code, status) => {
            if (!root.shouldRun)
                return;

            // cava exiting while it was meant to be running means something
            // went wrong -- usually the PipeWire monitor source disappearing
            // when the default sink changes (plugging in headphones), which is
            // both common and recoverable.
            //
            // The old comment here said "let the gate re-trigger it". It could
            // not: the gate is onShouldRunChanged, which only fires on a
            // CHANGE, and shouldRun is still true. So a cava that died
            // mid-track stayed dead until the music stopped and started again
            // -- the bars simply never came back and nothing said why.
            //
            // Retry with backoff rather than immediately: if cava is failing
            // because there is genuinely no monitor source, an instant respawn
            // is a fork bomb against a condition that will not clear.
            root.liveBands = 0;
            root.liveConfig = "";
            root.restartAttempts += 1;
            if (root.restartAttempts > 5) {
                console.warn("[cava] exited repeatedly (code", code,
                             ") — giving up until playback restarts; run `quickshell ipc call shell viz` to diagnose");
                return;
            }
            console.warn("[cava] exited unexpectedly (code", code, ") — retry",
                         root.restartAttempts, "of 5");
            respawnDelay.restart();
        }

        stdout: SplitParser {
            // One frame per line.
            onRead: line => {
                const raw = line.trim();
                if (raw === "") return;

                const parts = raw.split(";");
                const count = root.liveBands;
                const previous = root.levels;
                const out = new Array(count);
                const fall = Math.max(0, Math.min(0.98, Settings.visualizer.smoothing));
                const gain = Settings.visualizer.sensitivity;
                let moving = false;

                // `sensitivity` multiplies AFTER the curve, so it behaves like
                // a gain trim rather than re-shaping the response.
                // Precomputed -- see root.curveTable. This inner loop runs
                // bands x framerate times a second (160 x 60 = 9,600), and
                // Math.pow is by far the most expensive thing in it. cava's
                // output is an integer 0..1000, so the whole domain fits in a
                // 1001-entry table built once.
                const table = root.curveTable;

                for (let i = 0; i < count; i++) {
                    let raw = parseInt(parts[i]);
                    if (!(raw >= 0)) raw = 0;          // NaN / undefined / negative
                    else if (raw > 1000) raw = 1000;
                    let value = table[raw] * gain;
                    if (value > 1) value = 1;

                    const p = previous[i];
                    // Asymmetric smoothing: snap up with the beat, ramp down
                    // afterwards. Smoothing the rise too makes the bars feel
                    // laggy and disconnected from what you are hearing; only
                    // the fall wants easing.
                    const smoothed = (p === undefined || value >= p)
                        ? value
                        : p * fall + value * (1 - fall);

                    out[i] = smoothed;
                    if (smoothed > 0.015) moving = true;
                }

                root.levels = out;
                if (moving) {
                    root.lastMotion = Date.now();
                    root.active = true;
                }
            }
        }
    }

    // --- Diagnostics --------------------------------------------------
    // Surfaced over IPC so "why are my bars flat" is answerable without
    // reading QML. See the troubleshooting note in the header.
    readonly property string status: {
        if (!root.wanted) return "no consumer";
        if (!Performance.allowVisualizer)
            return Performance.gameMode ? "suppressed (fullscreen)" : "suppressed (" + Performance.profile + ")";
        if (!root.shouldRun) return "idle (silent)";
        if (!proc.running) return "starting";
        return "running · " + root.liveBands + " bands @ " + Performance.visualizerFramerate + "fps"
             + (root.active ? " · active" : " · quiet");
    }
}
