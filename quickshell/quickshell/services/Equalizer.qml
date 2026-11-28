pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

// =============================================================================
// Equalizer — a system-wide 10-band EQ on PipeWire's own filter-chain.
// =============================================================================
// Asked for alongside the drawer's Media page. Anserin's equalizer drives its
// own compiled audio engine over a socket, so none of it carries over; this is
// the stock PipeWire way instead, and needs nothing installed.
//
// HOW IT IS WIRED
//   On:  a child process `pipewire -c <generated config>` loads
//        libpipewire-module-filter-chain, which creates a virtual output called
//        "Equalizer" (node qs_eq_sink). Its graph is a pre-amp followed by ten
//        biquads -- low shelf at 31 Hz, peaking 62 Hz .. 8 kHz, high shelf at
//        16 kHz -- and its own output is pinned (target.object) to the device
//        you were actually listening on. The Equalizer node is then made the
//        default output, so every app plays through it.
//   Off: the default goes back to the real device, the process exits, and the
//        Equalizer output disappears. Off means no process at all.
//
// WHY THE SHELL ROUTES IT, NOT WIREPLUMBER
//   WirePlumber 0.5 can splice a filter in front of the default device by
//   itself ("smart filters"). This machine has 0.4.17, which cannot, so the
//   two steps above (pin the output, make the EQ the default) are done here.
//
// FOLLOWING YOUR OUTPUT
//   Picking another output while the EQ is on (the Control Center's audio
//   page, or headphones connecting) makes that device the default, which
//   would silently bypass the EQ. So whenever the default changes to a real
//   device, the EQ takes the default back -- restarting pointed at the new
//   device first if it is a different one. Re-picking the device it already
//   feeds counts too (that was a bypass in the first version).
//
// MOVING A SLIDER IS LIVE
//   Gains change on the running filter with one `pw-cli set-param` -- no
//   restart, no gap in the audio. Writes are debounced, because a slider drag
//   emits a value per frame.
//
// CLIPPING
//   Boosting a band can push a full-scale signal past 0 dBFS, which clips.
//   The pre-amp lowers the whole signal by the largest boost, so the curve's
//   SHAPE is what you set and the loudest band lands at unity. (Quieter
//   overall, never distorted -- turn the volume up.)
//
// The process is a child of the shell: if the shell restarts or crashes, the
// Equalizer output vanishes and WirePlumber falls back to the real device, so
// audio never ends up routed into a sink that no longer exists. When the shell
// comes back with the EQ still switched on, it starts it again.
// =============================================================================

Singleton {
    id: root

    readonly property var frequencies: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    function bandLabel(i) {
        const f = root.frequencies[i];
        return f >= 1000 ? (f / 1000) + "k" : String(f);
    }

    // dB per band. Broad, gentle curves -- a preset should be a starting
    // point you can live with, not a demonstration.
    readonly property var presets: ({
        "Flat":       [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
        "Bass boost": [ 6,  5,  4,  2,  0,  0,  0,  0,  0,  0],
        "Bass cut":   [-6, -5, -3, -1,  0,  0,  0,  0,  0,  0],
        "Treble":     [ 0,  0,  0,  0,  0,  1,  2,  4,  5,  6],
        "Vocal":      [-3, -2, -1,  1,  3,  4,  3,  1,  0, -1],
        "Loudness":   [ 5,  4,  2,  0, -1, -1,  0,  2,  4,  5],
        "Laptop":     [-4, -3, -1,  1,  2,  2,  2,  3,  2,  1],
        "Podcast":    [-6, -4, -1,  2,  3,  3,  2,  0, -2, -4]
    })

    readonly property var presetNames: ["Flat", "Bass boost", "Bass cut", "Treble", "Vocal", "Loudness", "Laptop", "Podcast"]

    readonly property real maxGain: 12

    readonly property bool enabled: Settings.equalizer.enabled
    readonly property string preset: Settings.equalizer.preset

    // Settings' list, copied into a real array of 10 numbers. JsonAdapter
    // returns lists that are only array-LIKE, so nothing here trusts it.
    readonly property var gains: {
        const g = Settings.equalizer.gains;
        const out = [];
        for (let i = 0; i < 10; i++) {
            const v = g && g.length !== undefined ? Number(g[i]) : 0;
            out.push(isFinite(v) ? Math.max(-root.maxGain, Math.min(root.maxGain, v)) : 0);
        }
        return out;
    }

    // --- controls ------------------------------------------------------------

    function setEnabled(on) { Settings.equalizer.enabled = on; }
    function toggle() { root.setEnabled(!root.enabled); }

    function setBand(i, db) {
        const next = root.gains.slice();
        next[i] = Math.round(Math.max(-root.maxGain, Math.min(root.maxGain, db)) * 2) / 2;
        Settings.equalizer.gains = next;
        Settings.equalizer.preset = "Custom";
    }

    function applyPreset(name) {
        const p = root.presets[name];
        if (!p) return;
        Settings.equalizer.gains = p.slice();
        Settings.equalizer.preset = name;
    }

    // --- routing state -----------------------------------------------------------

    readonly property string sinkName: "qs_eq_sink"

    // The Equalizer node, once the process has created it.
    readonly property var eqNode: {
        for (const n of Pipewire.nodes.values)
            if (n.name === root.sinkName) return n;
        return null;
    }

    readonly property bool active: !!root.eqNode && eqProcess.running

    // The real device the EQ plays into (its node name), and that node.
    property string targetName: ""
    readonly property var targetNode: {
        for (const n of Pipewire.nodes.values)
            if (n.name === root.targetName) return n;
        return null;
    }

    readonly property string targetDescription: root.targetNode
        ? (root.targetNode.description || root.targetNode.nickname || root.targetNode.name) : ""

    function isHardwareSink(n) {
        return !!n && n.isSink && !n.isStream && n.name !== root.sinkName
            && root.deadSinks.indexOf(n.name) < 0;
    }

    // Outputs with nothing plugged in (an HDMI port with no monitor, or a
    // monitor without speakers): PipeWire still lists them as sinks, and the
    // first-real-output fallback in pickTarget() used to land on one, routing
    // everything into silence. Asked of pactl just before every (re)start,
    // since it is the one that reports port availability.
    property var deadSinks: []

    Process {
        id: deadProbe
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                let dead = [];
                try {
                    for (const sink of JSON.parse(this.text)) {
                        const port = (sink.ports || []).find(p => p.name === sink.active_port);
                        if (port && port.availability === "not available") dead.push(sink.name);
                    }
                } catch (e) {
                    dead = [];
                }
                root.deadSinks = dead;
                root.startNow();
            }
        }
        onExited: (code) => { if (code !== 0) root.startNow(); }
    }

    // Where the EQ should play right now: the current default, unless the
    // default IS the EQ, in which case wherever it was already going; failing
    // both, the first real output.
    function pickTarget() {
        const d = Pipewire.defaultAudioSink;
        if (root.isHardwareSink(d)) return d.name;
        if (root.targetName !== "" && root.targetNode) return root.targetName;
        for (const n of Pipewire.nodes.values)
            if (root.isHardwareSink(n)) return n.name;
        return "";
    }

    // Wait for the saved settings (they land a moment after startup -- see
    // the loaded-timing note in modules/widgets/Widgets.qml) and for PipeWire
    // to have told us about at least one output.
    readonly property bool shouldRun: Settings.loaded && root.enabled
        && Pipewire.ready && root.pickTarget() !== ""

    onShouldRunChanged: {
        if (root.shouldRun) root.start();
        else root.stop();
    }

    Component.onCompleted: if (root.shouldRun) root.start()

    // Find out which outputs are actually connected, then start.
    function start() {
        if (!deadProbe.running) deadProbe.running = true;
    }

    function startNow() {
        if (!root.shouldRun) return;
        root.targetName = root.pickTarget();
        if (root.targetName === "") return;
        configFile.setText(root.config(root.targetName));
        if (eqProcess.running) {
            // A restart (new target). Process cannot be stopped and started in
            // the same breath -- the second write would land while the old
            // child is still exiting -- so stop now, start once it is gone.
            root.pendingStart = true;
            eqProcess.running = false;
        } else {
            eqProcess.running = true;
        }
    }

    property bool pendingStart: false

    function stop() {
        root.pendingStart = false;
        // Hand the default back BEFORE the Equalizer disappears, so nothing
        // plays into a vanishing sink for the instant in between.
        if (root.targetNode && Pipewire.defaultAudioSink === root.eqNode)
            Pipewire.preferredDefaultAudioSink = root.targetNode;
        eqProcess.running = false;
    }

    // The Equalizer appeared: make it the default output.
    onEqNodeChanged: {
        if (root.eqNode && root.enabled)
            Pipewire.preferredDefaultAudioSink = root.eqNode;
    }

    // Follow the user's choice of output (see header).
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (!root.enabled || !eqProcess.running) return;
            if (root.isHardwareSink(Pipewire.defaultAudioSink)) followTimer.restart();
        }
    }

    // A device change arrives as a burst of node events; settle first.
    Timer {
        id: followTimer

        interval: 600
        onTriggered: {
            const d = Pipewire.defaultAudioSink;
            if (!root.enabled || !root.isHardwareSink(d)) return;
            // Picked the device the EQ already plays into: just take the
            // default back. Anything else: re-point the EQ at it first.
            if (d.name === root.targetName && root.eqNode)
                Pipewire.preferredDefaultAudioSink = root.eqNode;
            else
                root.start();
        }
    }

    // --- live gain changes ------------------------------------------------------

    // Pre-amp as a linear factor: down by the largest boost (see CLIPPING).
    function preampFor(gains) {
        const boost = Math.max(0, Math.max.apply(null, gains));
        return Math.pow(10, -boost / 20);
    }

    onGainsChanged: if (root.active) pushTimer.restart()

    Timer {
        id: pushTimer

        interval: 60
        onTriggered: {
            if (!root.active) return;
            const params = [];
            for (let i = 0; i < 10; i++) params.push('"band' + (i + 1) + ':Gain" ' + root.gains[i].toFixed(1));
            params.push('"preamp:Gain 1" ' + root.preampFor(root.gains).toFixed(4));
            // argv, not a shell string: the node id and the SPA-JSON go in as
            // two plain arguments.
            Quickshell.execDetached(["pw-cli", "set-param", String(root.eqNode.id), "Props",
                "{ params = [ " + params.join(" ") + " ] }"]);
        }
    }

    // --- the process -------------------------------------------------------------

    // In the runtime dir: regenerated on every start, never meant to be edited.
    readonly property string configPath: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-equalizer.conf"

    FileView {
        id: configFile

        path: root.configPath
        // Synchronous, so the file is complete before pipewire reads it.
        blockWrites: true
        printErrors: false
    }

    Process {
        id: eqProcess

        // A previous shell's filter survives `just qs-reload` (it is not
        // killed with its parent) and keeps its "Equalizer" sink -- nine of
        // them piled up once, the default pointing at a stale one aimed at a
        // dead HDMI port. So any filter on this config not owned by us is
        // stopped first; `exec` then makes pipewire this Process's own child.
        command: ["sh", "-c",
            "pkill -f \"^(/usr/bin/)?pipewire -c " + root.configPath + "$\"; exec pipewire -c \"$0\"",
            root.configPath]

        // The filter dying on its own (PipeWire restarted underneath it, say)
        // must not leave the default pointing at nothing.
        onExited: (code) => {
            if (root.pendingStart) {
                root.pendingStart = false;
                if (root.enabled) eqProcess.running = true;
                return;
            }
            if (code !== 0) console.warn("[equalizer] filter process exited with", code);
            if (root.targetNode && Pipewire.defaultAudioSink === null)
                Pipewire.preferredDefaultAudioSink = root.targetNode;
        }
    }

    // The filter-chain config. Same skeleton as PipeWire's own
    // /usr/share/pipewire/filter-chain.conf, with the graph inline. The node
    // names are what the live pw-cli writes above address.
    function config(target) {
        const nodes = ['{ type = builtin name = preamp label = mixer control = { "Gain 1" = '
            + root.preampFor(root.gains).toFixed(4) + ' } }'];
        for (let i = 0; i < 10; i++) {
            const label = i === 0 ? "bq_lowshelf" : i === 9 ? "bq_highshelf" : "bq_peaking";
            nodes.push('{ type = builtin name = band' + (i + 1) + ' label = ' + label
                + ' control = { "Freq" = ' + root.frequencies[i].toFixed(1)
                + ' "Q" = 1.0 "Gain" = ' + root.gains[i].toFixed(1) + ' } }');
        }
        const links = ['{ output = "preamp:Out" input = "band1:In" }'];
        for (let i = 1; i < 10; i++)
            links.push('{ output = "band' + i + ':Out" input = "band' + (i + 1) + ':In" }');

        return 'context.properties = { log.level = 0 }\n'
            + 'context.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }\n'
            + 'context.modules = [\n'
            + '  { name = libpipewire-module-rt args = { } flags = [ ifexists nofail ] }\n'
            + '  { name = libpipewire-module-protocol-native }\n'
            + '  { name = libpipewire-module-client-node }\n'
            + '  { name = libpipewire-module-adapter }\n'
            + '  { name = libpipewire-module-filter-chain\n'
            + '    args = {\n'
            + '      node.description = "Equalizer"\n'
            + '      media.name = "Equalizer"\n'
            + '      filter.graph = {\n'
            + '        nodes = [ ' + nodes.join('\n          ') + ' ]\n'
            + '        links = [ ' + links.join('\n          ') + ' ]\n'
            + '        inputs = [ "preamp:In 1" ]\n'
            + '        outputs = [ "band10:Out" ]\n'
            + '      }\n'
            + '      audio.channels = 2\n'
            + '      audio.position = [ FL FR ]\n'
            + '      capture.props = { node.name = "' + root.sinkName + '" media.class = Audio/Sink }\n'
            + '      playback.props = { node.name = "' + root.sinkName + '.out" node.passive = true'
            + ' target.object = "' + target + '" }\n'
            + '    }\n'
            + '  }\n'
            + ']\n';
    }
}
