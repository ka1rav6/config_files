pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

// =============================================================================
// Audio — the one authoritative view of PipeWire.
// =============================================================================
// Replaces four separate implementations that used to disagree with each other:
// waybar's `pulseaudio` module, its `pulseaudio#microphone` twin, the GTK
// slider popup each of them spawned, and pavucontrol. All of them polled or
// shelled out to wpctl; this subscribes to PipeWire directly and is told about
// changes rather than asking.
//
// WHY PwObjectTracker IS REQUIRED
//   PipeWire objects are unbound by default -- Quickshell knows a node exists
//   but does not mirror its volume, mute state or channel layout until
//   something asks it to. A PwObjectTracker declaring the nodes we care about
//   is what turns them live. Read a volume off an untracked node and you get a
//   stale zero, silently.
//
//   Only the default sink and source are tracked, plus whatever streams the
//   Control Center is showing. Tracking every node on the system would mean
//   mirroring every browser tab's audio stream for no reason.
//
// VOLUME ABOVE 1.0
//   PipeWire happily accepts volumes over 1.0 by applying software gain, which
//   clips and distorts. The existing keybindings in ~/.config/hypr/bindings.lua
//   already guard against this with `wpctl set-volume -l 1.0`; setVolume() here
//   applies the same ceiling so the GUI cannot do what the keyboard refuses to.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // --- Output -------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: !!(root.sink && root.sink.ready && root.sink.audio)

    readonly property real volume: root.sinkReady ? root.sink.audio.volume : 0
    readonly property bool muted: root.sinkReady ? root.sink.audio.muted : true

    // A human name for the device. PipeWire's `description` is the friendly
    // one ("Built-in Audio Speaker"); `nickname` is shorter but often absent,
    // and `name` is the raw alsa id nobody wants to read.
    readonly property string sinkName: {
        if (!root.sink) return "No output";
        return root.sink.description || root.sink.nickname || root.sink.name || "Output";
    }

    // --- Input --------------------------------------------------------
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: !!(root.source && root.source.ready && root.source.audio)

    readonly property real micVolume: root.sourceReady ? root.source.audio.volume : 0
    readonly property bool micMuted: root.sourceReady ? root.source.audio.muted : true

    readonly property string sourceName: {
        if (!root.source) return "No input";
        return root.source.description || root.source.nickname || root.source.name || "Input";
    }

    // --- Devices, for the Control Center's picker ----------------------
    // Filtered on demand rather than kept as a live model, because the lists
    // are short and only read while a panel is open.
    function sinks() {
        return Pipewire.nodes.values.filter(n => n.isSink && !n.isStream);
    }

    function sources() {
        return Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio);
    }

    // Per-application streams, for the mixer.
    function streams() {
        return Pipewire.nodes.values.filter(n => n.isStream && n.audio && n.isSink);
    }

    // --- Mutation -----------------------------------------------------
    // Written through the PipeWire objects rather than by shelling out to
    // wpctl. A subprocess per scroll-tick was measurable in the old waybar
    // path; this is a D-Bus-free in-process write.

    function setVolume(value) {
        if (!root.sinkReady) return;
        // Clamp to unity. Above 1.0 PipeWire applies software gain, which
        // clips -- the same reason the keybindings pass `-l 1.0`.
        root.sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function addVolume(delta) {
        root.setVolume(root.volume + delta);
    }

    function toggleMute() {
        if (root.sinkReady) root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setMicVolume(value) {
        if (!root.sourceReady) return;
        root.source.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMicMute() {
        if (root.sourceReady) root.source.audio.muted = !root.source.audio.muted;
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // --- Binding ------------------------------------------------------
    // Without this the properties above read stale zeros. See the header.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }

    // --- Peak level ---------------------------------------------------
    // The cheapest possible "is sound actually coming out of the speakers"
    // signal: PipeWire computes it as part of the graph, so reading it costs
    // nothing extra. services/Cava.qml uses this to decide whether to run a
    // cava process at all, which is the single biggest battery win in the
    // shell -- a silent machine runs no FFT.
    //
    // `enabled` is gated on something actually wanting it, so the monitor is
    // not attached when the visualizer is off.
    property bool peakMonitorWanted: false

    readonly property real peak: peakMonitor.peak

    // True while sound is genuinely playing, with hysteresis so a quiet
    // passage in a track does not flap the visualizer off and on. The
    // threshold is above PipeWire's noise floor but well below speech level.
    property bool audible: false

    PwNodePeakMonitor {
        id: peakMonitor

        node: root.peakMonitorWanted ? root.sink : null
        enabled: root.peakMonitorWanted && !!root.sink

        onPeakChanged: {
            if (peakMonitor.peak > 0.005) {
                root.audible = true;
                silence.restart();
            }
        }
    }

    // Declare silence only after a gap, not on the first quiet frame.
    Timer {
        id: silence

        interval: 1500
        onTriggered: root.audible = false
    }
}
