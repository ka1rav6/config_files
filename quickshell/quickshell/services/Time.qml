pragma Singleton

import QtQuick
import Quickshell
import qs

// =============================================================================
// Time — the one clock in the shell.
// =============================================================================
// Every surface that shows a time or a date reads it from here, rather than
// keeping its own Timer. Three reasons:
//
//   1. Cost. One clock ticking once a minute, versus one per widget. The
//      desktop clock, the Control Center header, the calendar and the lock
//      screen would otherwise be four timers doing the same arithmetic.
//   2. Agreement. Two clocks started a few hundred milliseconds apart tick at
//      different moments, so the bar and the desktop widget can visibly
//      disagree for a second every minute.
//   3. One place to honour the 12/24-hour setting.
//
// PRECISION
//   SystemClock's `precision` decides how often it wakes. Minutes is the
//   default because almost nothing here shows seconds; `secondsWanted` below
//   lets a surface that does (the lock screen, a stopwatch) opt in while it is
//   visible, and the clock drops straight back to per-minute when it closes.
//
//   This matters more than it sounds: a per-second clock is 60 wakeups a minute
//   forever, and it is the single most common reason a QML shell shows
//   measurable idle CPU.
// =============================================================================

Singleton {
    id: root

    // Set true by any surface that genuinely displays seconds, false when it
    // goes away. Reference-counted rather than boolean so two such surfaces
    // cannot fight over it.
    property var secondsConsumers: ({})

    function wantSeconds(id) {
        if (root.secondsConsumers[id]) return;
        const next = {};
        for (const k in root.secondsConsumers) next[k] = true;
        next[id] = true;
        root.secondsConsumers = next;
    }

    function dropSeconds(id) {
        if (!root.secondsConsumers[id]) return;
        const next = {};
        for (const k in root.secondsConsumers) { if (k !== id) next[k] = true; }
        root.secondsConsumers = next;
    }

    readonly property bool secondsWanted: Object.keys(root.secondsConsumers).length > 0

    SystemClock {
        id: clock

        enabled: true
        precision: root.secondsWanted ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property date now: clock.date

    // --- formatted forms -------------------------------------------------
    // Exposed as properties rather than functions so they are cached bindings
    // that update once per tick, not re-formatted on every paint.

    readonly property bool use24Hour: true

    readonly property string time: Qt.formatDateTime(root.now, root.use24Hour ? "HH:mm" : "h:mm AP")
    readonly property string timeWithSeconds: Qt.formatDateTime(root.now, root.use24Hour ? "HH:mm:ss" : "h:mm:ss AP")
    readonly property string hours: Qt.formatDateTime(root.now, root.use24Hour ? "HH" : "hh")
    readonly property string minutes: Qt.formatDateTime(root.now, "mm")
    readonly property string meridiem: root.use24Hour ? "" : Qt.formatDateTime(root.now, "AP")

    // "Saturday, 20 September"  — the Control Center and dashboard header.
    readonly property string longDate: Qt.formatDateTime(root.now, "dddd, d MMMM")
    // "Sat 20 Sep"              — compact surfaces.
    readonly property string shortDate: Qt.formatDateTime(root.now, "ddd d MMM")
    readonly property string dayName: Qt.formatDateTime(root.now, "dddd")
    readonly property string monthName: Qt.formatDateTime(root.now, "MMMM")
    readonly property int year: root.now.getFullYear()
    readonly property int month: root.now.getMonth()
    readonly property int day: root.now.getDate()
}
