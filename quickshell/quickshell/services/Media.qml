pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs

// =============================================================================
// Media — the active MPRIS player.
// =============================================================================
// One place that decides WHICH player the desktop is talking about. Without
// that decision made centrally, the OSD, the dock, the desktop media widget and
// the Control Center each pick their own "first player" and end up controlling
// different applications -- which is exactly the fragmentation this migration
// is meant to remove.
//
// HOW THE ACTIVE PLAYER IS CHOSEN
//   1. A player that is actually playing wins. If two are, the first found --
//      two simultaneously playing players is already a strange state and any
//      choice is arbitrary.
//   2. Otherwise the last one that WAS playing, remembered across pauses, so
//      pausing a track does not make the widget jump to a different app.
//   3. Otherwise the first player that exists at all, so the controls are
//      populated rather than blank before anything has been played.
//
// The YouTube Music PWA in ~/.config/hypr/scratchpads.lua (SUPER + Y) is the
// usual subject here; it reports over MPRIS like any other player.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // dbusName of the last player seen playing. Plain string rather than an
    // object reference because players disappear, and holding a reference to a
    // destroyed QObject is how QML crashes.
    property string lastActiveName: ""

    readonly property var players: Mpris.players ? Mpris.players.values : []

    readonly property var player: {
        const list = root.players;
        if (list.length === 0) return null;

        for (const p of list) {
            if (p.isPlaying) return p;
        }
        if (root.lastActiveName !== "") {
            for (const p of list) {
                if (p.dbusName === root.lastActiveName) return p;
            }
        }
        return list[0];
    }

    readonly property bool available: !!root.player
    readonly property bool playing: root.available && root.player.isPlaying

    onPlayingChanged: {
        if (root.playing && root.player)
            root.lastActiveName = root.player.dbusName;
    }

    // --- Track --------------------------------------------------------
    // Every one of these is guarded, because a player can exist with no track
    // loaded and MPRIS metadata is famously inconsistent between applications.

    readonly property string title: root.available && root.player.trackTitle ? root.player.trackTitle : ""
    readonly property string artist: root.available && root.player.trackArtist ? root.player.trackArtist : ""
    readonly property string album: root.available && root.player.trackAlbum ? root.player.trackAlbum : ""
    readonly property string artUrl: root.available && root.player.trackArtUrl ? root.player.trackArtUrl : ""
    readonly property string identity: root.available ? root.player.identity : ""

    // A single line for compact surfaces (the OSD, the dock tooltip).
    readonly property string summary: {
        if (!root.available || root.title === "") return "";
        return root.artist !== "" ? root.title + " — " + root.artist : root.title;
    }

    // --- Position -----------------------------------------------------
    // MPRIS position does not tick on its own: it is a value you ask for. The
    // timer below is the one poll in this service, and it is gated three ways
    // -- it stops when nothing is playing, when the player cannot report a
    // position, and when nothing is watching. A progress bar nobody can see is
    // the definition of work not worth doing.
    // -----------------------------------------------------------------
    // Position demand, reference counted.
    //
    // Three separate surfaces want the seek position (the dashboard, the
    // Control Center and the desktop media widget) and they open and close
    // independently. A single bool meant whichever closed last switched the
    // tick off underneath the others, so a seek bar would silently freeze
    // whenever you closed an unrelated panel. Counting demand is the only
    // thing that composes.
    // -----------------------------------------------------------------

    property var positionConsumers: ({})

    function wantPosition(id) {
        if (root.positionConsumers[id]) return;
        const next = {};
        for (const k in root.positionConsumers) next[k] = true;
        next[id] = true;
        root.positionConsumers = next;
    }

    function dropPosition(id) {
        if (!root.positionConsumers[id]) return;
        const next = {};
        for (const k in root.positionConsumers) { if (k !== id) next[k] = true; }
        root.positionConsumers = next;
    }

    readonly property bool positionWanted: Object.keys(root.positionConsumers).length > 0

    readonly property bool hasPosition: root.available && root.player.positionSupported && root.player.lengthSupported
    readonly property real length: root.hasPosition ? root.player.length : 0
    property real position: 0

    readonly property real progress: root.length > 0 ? Math.min(1, root.position / root.length) : 0

    Timer {
        // 1 Hz. A seek bar does not need more, and each tick is one D-Bus
        // property read.
        interval: 1000
        repeat: true
        running: root.positionWanted && root.playing && root.hasPosition
        onTriggered: root.position = root.player.position

        // Read once on start rather than waiting a second for the first tick,
        // so opening a panel shows the real position immediately.
        onRunningChanged: if (running && root.player) root.position = root.player.position
    }

    // --- Control ------------------------------------------------------
    // Guarded on the player's own can* properties. A play button that does
    // nothing is worse than one that is visibly disabled, and these are what
    // the UI binds `enabled` to.

    function playPause() {
        if (root.available && root.player.canTogglePlaying) root.player.togglePlaying();
    }

    function next() {
        if (root.available && root.player.canGoNext) root.player.next();
    }

    function previous() {
        if (root.available && root.player.canGoPrevious) root.player.previous();
    }

    function seek(fraction) {
        if (!root.hasPosition || !root.player.canSeek) return;
        root.player.position = Math.max(0, Math.min(1, fraction)) * root.length;
        root.position = root.player.position;
    }

    function raise() {
        if (root.available && root.player.canRaise) root.player.raise();
    }

    // mm:ss for a number of seconds. Used by every surface that shows a time,
    // so they cannot format it three different ways.
    function formatTime(seconds) {
        if (!(seconds > 0)) return "0:00";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
