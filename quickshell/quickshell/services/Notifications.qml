pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// =============================================================================
// Notifications — the notification daemon itself, plus do-not-disturb.
// =============================================================================
// THIS PROCESS IS NOW THE DAEMON. mako is gone.
//
// The previous version of this file drove mako's mode system over `makoctl`
// and said the decision to take notifications over entirely was "deliberately
// not made here". This is that decision. What it bought:
//
//   * Popups in the shell's own visual language, themed from services/Theme.qml
//     like every other surface, instead of a second styling system that
//     ~/.local/bin/theme-switch had to write a colour block into.
//   * Actions and inline replies, which mako cannot draw at all. A KDE Connect
//     SMS can be answered from the popup.
//   * A history panel (SUPER + N) that is part of the shell rather than
//     ~/.local/bin/mako-fzf-history running fzf inside a Ghostty window.
//   * DND that is a boolean in this process rather than a subprocess per
//     toggle.
//
// THERE CAN ONLY BE ONE
//   org.freedesktop.Notifications is a single D-Bus name. Whoever claims it
//   first wins and the other gets nothing -- so mako had to stop being started
//   in ~/.config/hypr/autostart.lua for this to work at all. That is also the
//   rollback: put `spawn("mako")` back, set features.notifications to false,
//   and the old world returns. ~/.config/mako/config is still on disk.
//
// WHAT HAPPENS IF THIS PROCESS DIES
//   Notifications are lost until it comes back, which IS a change: mako was a
//   separate process and survived a shell crash. Weighed against one visual
//   language and one place to look, and `just qs-restart` brings it back.
//
// HISTORY IS THE TRACKED LIST
//   A notification the server does not track is destroyed the moment the
//   signal handler returns, and anything still pointing at it is pointing at a
//   freed QObject -- one of the few ways to take a QML process down hard. So
//   everything is tracked, and the list is capped instead (see trim()). The
//   cap is what stops a chatty application growing this without bound.
// =============================================================================

Singleton {
    id: root

    // Nothing external can be missing any more. Kept because the Control
    // Center tile and the Command Center both read it, and a tile that can
    // never be unavailable is cheaper than editing three call sites.
    readonly property bool available: true

    // Runtime only, exactly as mako's mode was: a DND left on at shutdown
    // should not silence the machine for the next login with no clue why.
    property bool dnd: false

    // How many notifications to keep. Fifty is far more than anyone scrolls
    // back through and small enough that the images they hold are irrelevant.
    readonly property int historyLimit: 50

    // Newest first, which is the order both the panel and mako's old
    // `sort=-time` show them in.
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length

    // The ones currently on screen. The toast layer renders this and each toast
    // times out its own entry -- a timer per notification, living with the
    // thing it times, rather than a schedule kept in here.
    property var popups: []

    function hidePopup(n) {
        root.popups = root.popups.filter(x => x !== n);
    }

    function clearPopups() {
        root.popups = [];
    }

    // Close one for good: tells the sending application it was dismissed, which
    // is what the close button on a toast means.
    function dismiss(n) {
        root.hidePopup(n);
        if (n) n.dismiss();
    }

    function clear() {
        root.clearPopups();
        // Untrack rather than dismiss: clearing the history pane is this
        // shell's bookkeeping, not a message to every application that sent
        // something hours ago.
        for (const n of server.trackedNotifications.values.slice()) n.tracked = false;
    }

    function setDnd(value) {
        root.dnd = value;
        // Anything already on screen when DND goes on should go away -- a
        // silence that leaves three toasts sitting there is not a silence.
        if (value) root.clearPopups();
    }

    function toggle() {
        root.setDnd(!root.dnd);
    }

    // Drop the oldest beyond the cap. Called on arrival, which is the only
    // moment the list can grow.
    function trim() {
        const all = server.trackedNotifications.values;
        const excess = all.length - root.historyLimit;
        for (let i = 0; i < excess; i++) all[i].tracked = false;
    }

    NotificationServer {
        id: server

        // Survive a config reload. This shell reloads whenever settings.json
        // changes -- which is every time a slider moves -- and dropping every
        // notification on screen because the volume was adjusted is not
        // acceptable behaviour for a daemon.
        keepOnReload: true

        // Everything the toast layer can actually draw, and nothing it cannot:
        // these are advertised over D-Bus, and an application told that
        // hyperlinks work will send markup this shell would render as literal
        // angle brackets.
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: false
        bodyHyperlinksSupported: false
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: (n) => {
            // Tracked first, unconditionally. See the header: an untracked
            // notification is freed as soon as this returns.
            n.tracked = true;
            root.trim();

            if (root.dnd) return;

            root.popups = root.popups.concat([n]);
        }
    }
}
