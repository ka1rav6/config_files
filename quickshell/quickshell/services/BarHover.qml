pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// =============================================================================
// BarHover — Waybar pills that drop their panel when hovered.
// =============================================================================
// Waybar (GTK) has no hover event to hand anyone, and a Quickshell surface laid
// over the bar would steal its clicks. So the qs-pointer Hyprland plugin is
// given a rectangle per pill (services/Pointer.qml, "zones") and reports only
// the moment the pointer enters or leaves one. Waybar still gets every click,
// scroll and tooltip exactly as before; this only adds the hover.
//
//   media pill (custom/media, centre, left of the clock)  ->  MediaDropdown ("media")
//   clock (centre)                                 ->  the dashboard dropdown
//   bell (custom/notifications, far right)         ->  NotificationCenter
//
// WHERE THE PILLS ARE
//   The pills have fixed widths (title-len and min-width in ~/.config/waybar),
//   so their positions follow from the screen size alone: the centre group is
//   [media][clock] centred on the bar (or just the clock when no player
//   is showing, which is when the media pill is hidden -- Media.shown), and the bell is the
//   last thing on the right. The numbers live in Settings.bar so they can be
//   adjusted if the bar's CSS is changed.
//
// BEHAVIOUR
//   Rest on a pill for Appearance.hoverRevealDelay and its panel drops out of
//   the bar in peek mode: move off both the pill and the panel and it slides
//   back up; press anything inside it and it stays (ui/Panel.qml). Sliding
//   along the bar from one pill to the next swaps the dropdowns. A panel you
//   opened deliberately (key, click) is never closed by a hover.
//
// OFF WHEN IT WOULD BE WRONG
//   Not while a window is fullscreen (the bar is hidden under it), not while
//   waybar's layer is closed (SUPER+ALT+SPACE hides it), not without the
//   plugin, and not when Settings > Appearance > "Open dropdowns on hover" is
//   off. With no zones registered the plugin does nothing at all.
//
// It also tells waybar's bell when to re-read the notification count, with
// SIGRTMIN+10 -- no polling on either side.
// =============================================================================
Singleton {
    id: root

    property bool waybarShown: true

    readonly property bool active: Settings.bar.hover
        && Pointer.available
        && root.waybarShown
        && !Hypr.fullscreen

    // Rebuilt whenever anything that moves a pill changes.
    readonly property var layout: {
        const out = [];
        if (!root.active) return out;
        const b = Settings.bar;
        const hasMedia = Media.shown && Settings.features.music;
        for (const s of Quickshell.screens) {
            const cx = s.x + s.width / 2;
            const y = s.y + b.top;
            const total = hasMedia ? b.mediaWidth + b.gap + b.clockWidth : b.clockWidth;
            const left = cx - total / 2;
            if (hasMedia && Settings.features.music)
                out.push({ name: "media@" + s.name, panel: "media", screen: s, x: left, y: y, w: b.mediaWidth, h: b.height,
                           hang: left + b.mediaWidth / 2 - s.x });
            if (Settings.features.dashboard)
                out.push({ name: "clock@" + s.name, panel: "dashboard", screen: s, x: left + total - b.clockWidth, y: y, w: b.clockWidth, h: b.height,
                           hang: left + total - b.clockWidth / 2 - s.x });
            if (Settings.features.notifications)
                out.push({ name: "bell@" + s.name, panel: "notifications", screen: s, x: s.x + s.width - b.right - b.bellWidth, y: y, w: b.bellWidth, h: b.height,
                           hang: -1 });
        }
        return out;
    }

    property var registered: []

    onLayoutChanged: root.sync()

    function sync() {
        const names = root.layout.map(z => z.name);
        for (const old of root.registered)
            if (names.indexOf(old) < 0) Pointer.clearZone(old);
        for (const z of root.layout)
            Pointer.setZone(z.name, z.x, z.y, z.w, z.h);
        root.registered = names;
    }

    // ---- hovering -------------------------------------------------------------
    property var pending: null

    Connections {
        target: Pointer
        function onZoneChanged(name, inside) {
            const z = root.layout.find(x => x.name === name);
            if (!z) return;
            if (inside) {
                Shell.edgeHover = z.panel;       // holds a peeking panel open
                root.pending = z;
                dwell.restart();
            } else {
                if (Shell.edgeHover === z.panel) Shell.edgeHover = "";
                if (root.pending && root.pending.name === name) {
                    root.pending = null;
                    dwell.stop();
                }
            }
        }
    }

    Timer {
        id: dwell
        interval: Appearance.hoverRevealDelay
        onTriggered: {
            const z = root.pending;
            root.pending = null;
            if (z && Pointer.inside(z.name)) Shell.hoverOpen(z.panel, z.screen, z.hang);
        }
    }

    // ---- is waybar up? ----------------------------------------------------------
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.data !== "waybar") return;
            if (event.name === "openlayer") root.waybarShown = true;
            else if (event.name === "closelayer") root.waybarShown = false;
        }
    }

    // ---- the bell's count ---------------------------------------------------------
    readonly property string bellState: Notifications.count + "/" + Notifications.dnd
    onBellStateChanged: bellSignal.restart()

    Timer {
        id: bellSignal
        interval: 150   // a burst of notifications is one signal
        onTriggered: bellProc.running = true
    }

    Process {
        id: bellProc
        command: ["pkill", "-RTMIN+10", "-x", "waybar"]
    }

    // ---- the media pill ------------------------------------------------------------
    // Same shape as the bell, on SIGRTMIN+11: waybar re-asks
    // `quickshell ipc call media bar` only when what it shows has changed.
    readonly property string mediaState: Settings.features.music + "/" + Media.shown + "/" + Media.playing + "/" + Media.title
    onMediaStateChanged: mediaSignal.restart()

    Timer {
        id: mediaSignal
        interval: 150   // a track change flips title and state in quick succession
        onTriggered: mediaProc.running = true
    }

    Process {
        id: mediaProc
        command: ["pkill", "-RTMIN+11", "-x", "waybar"]
    }

    Component.onDestruction: {
        for (const old of root.registered) Pointer.clearZone(old);
    }
}
