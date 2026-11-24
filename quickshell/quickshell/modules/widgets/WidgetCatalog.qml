pragma Singleton

import QtQuick
import Quickshell
import qs

// =============================================================================
// WidgetCatalog — every desktop widget the picker can place, and its styles.
// =============================================================================
// Anserin's widget picker is a grid of categories, each with several faces of
// the same widget (eight clocks, four music players...). This is that list for
// this shell: pure data. Widgets.qml draws whatever `Settings.desktop.placed`
// names; WidgetPicker.qml lists what is here.
//
// SHAPE
//   type     stable id, stored in settings.json -- never rename one
//   label    what the picker calls it
//   category "clocks" | "system" | "media"
//   icon     an Icon.qml name
//   variants [{ id, label, file, props }]
//              id     stable, stored in settings.json
//              file   the DesktopWidget subclass, relative to this directory
//              props  set on it once at creation (e.g. which metric a gauge
//                     shows), so one file can serve several entries
//
// ADDING A WIDGET OR A STYLE
//   Write a DesktopWidget subclass (see DesktopWidget.qml for what it gets for
//   free: dragging, saved position, size, edit outline), add it here, done.
//   Set `interactive: true` on the subclass if it has buttons -- see the mask
//   in Widgets.qml for why that matters.
// =============================================================================

Singleton {
    id: root

    readonly property var categories: [
        { id: "clocks", label: "Clocks", icon: "clock" },
        { id: "system", label: "System", icon: "cpu" },
        { id: "media",  label: "Media",  icon: "music" }
    ]

    function metricVariants(metric) {
        return [
            { id: "ring", label: "Ring", file: "WidgetMetric.qml", props: { metric: metric, style: "ring" } },
            { id: "bar",  label: "Bar",  file: "WidgetMetric.qml", props: { metric: metric, style: "bar" } }
        ];
    }

    readonly property var types: [
        {
            type: "clock", label: "Clock", category: "clocks", icon: "clock",
            variants: [
                { id: "classic", label: "Classic", file: "WidgetClock.qml",         props: {} },
                { id: "digital", label: "Digital", file: "clocks/ClockDigital.qml", props: {} },
                { id: "analog",  label: "Analog",  file: "clocks/ClockAnalog.qml",  props: {} },
                { id: "stacked", label: "Stacked", file: "clocks/ClockStacked.qml", props: {} },
                { id: "minimal", label: "Minimal", file: "clocks/ClockMinimal.qml", props: {} }
            ]
        },
        {
            type: "calendar", label: "Calendar", category: "clocks", icon: "calendar",
            variants: [
                { id: "month", label: "Month", file: "WidgetCalendar.qml", props: {} }
            ]
        },
        { type: "cpu",     label: "Processor",   category: "system", icon: "cpu",         variants: root.metricVariants("cpu") },
        { type: "ram",     label: "Memory",      category: "system", icon: "ram",         variants: root.metricVariants("ram") },
        { type: "disk",    label: "Disk",        category: "system", icon: "folder",      variants: root.metricVariants("disk") },
        { type: "temp",    label: "Temperature", category: "system", icon: "temperature", variants: root.metricVariants("temp") },
        { type: "battery", label: "Battery",     category: "system", icon: "battery-full", variants: root.metricVariants("battery") },
        {
            type: "network", label: "Network", category: "system", icon: "wifi-4",
            variants: [
                { id: "card", label: "Card", file: "WidgetNetwork.qml", props: {} }
            ]
        },
        {
            type: "media", label: "Now playing", category: "media", icon: "music",
            variants: [
                { id: "card",  label: "Card",  file: "WidgetMedia.qml",      props: {} },
                { id: "round", label: "Round", file: "WidgetMediaRound.qml", props: {} }
            ]
        }
    ]

    function typeInfo(type) {
        for (const t of root.types) if (t.type === type) return t;
        return null;
    }

    // The variant entry, falling back to the type's first style when a saved
    // variant no longer exists -- a renamed style must not delete a widget.
    function variantInfo(type, variant) {
        const t = root.typeInfo(type);
        if (!t) return null;
        for (const v of t.variants) if (v.id === variant) return v;
        return t.variants[0];
    }

    function typesIn(category) {
        return root.types.filter(t => t.category === category);
    }

    // Whether a widget of this type has anything to show on this machine
    // right now. A placed widget that is unavailable is hidden, not deleted:
    // the media card comes back when something plays.
    function available(type) {
        switch (type) {
        case "media":    return Settings.features.music && Media.available;
        case "battery":  return Performance.hasBattery;
        case "calendar": return Settings.features.calendar;
        case "temp":     return SysInfo.cpuTempC > 0 || !SysInfo.wanted;
        default:         return true;
        }
    }

    // Types whose numbers come from SysInfo's /proc polling.
    function needsSysInfo(type) {
        return type === "cpu" || type === "ram" || type === "disk" || type === "temp";
    }
}
