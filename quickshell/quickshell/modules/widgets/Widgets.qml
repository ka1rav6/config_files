import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// =============================================================================
// Desktop widgets.
// =============================================================================
// A layer of cards that live on the wallpaper: clock, calendar, now playing,
// CPU, memory, battery, network. Each one is independently toggleable in
// Settings > Desktop, and each remembers where it was dragged to.
//
// WHERE IT SITS
//   WlrLayer.Bottom -- above the wallpaper, below every window, on every
//   workspace, with ExclusionMode.Ignore so it never reflows a tiled layout.
//   Outside edit mode `mask: Region {}` makes the entire surface
//   click-through, so widgets are wallpaper decoration and cannot swallow a
//   click meant for the desktop.
//
// WHY THE SURFACE DISAPPEARS WHEN THE DESKTOP IS COVERED
//   Same reasoning as the visualiser: this layer is below every window, so on
//   a workspace with one tiled window on it nothing here is visible. The
//   screen list is filtered through Hypr.desktopVisibleOn, so a covered output
//   has no surface, no items and no bindings at all -- and in particular the
//   /proc reads behind the CPU and memory gauges stop, because the SysInfo
//   demand is released with the last visible surface.
//
//   Floating windows do not count as covering; see services/Hypr.qml.
//
// EDIT MODE
//   `quickshell ipc call widgets edit` lifts the layer to Overlay, makes it
//   take input, and lets every widget be dragged. Positions are saved as
//   screen fractions (see DesktopWidget.qml). `done` puts it back.
// =============================================================================

Scope {
    id: root

    property bool editing: false

    // A stable id for the SysInfo demand refcount.
    readonly property string consumerId: "desktop-widgets"

    readonly property bool wanted: Settings.features.widgets
        && (root.editing || Hypr.anyDesktopVisible)
        && (root.editing || !Settings.desktop.hideOnFullscreen || !Hypr.fullscreen)

    // The gauges are the only widgets that cost anything to keep fed, so the
    // /proc polling is demanded only while one of them is both enabled and on
    // screen. Everything else is event-driven already.
    readonly property bool needsSysInfo: root.wanted
        && (Settings.desktop.cpu || Settings.desktop.ram)

    onNeedsSysInfoChanged: {
        if (root.needsSysInfo) SysInfo.want(root.consumerId);
        else SysInfo.drop(root.consumerId);
    }

    Component.onCompleted: {
        Shell.widgets = root;
        if (root.needsSysInfo) SysInfo.want(root.consumerId);
    }

    Component.onDestruction: {
        if (Shell.widgets === root) Shell.widgets = null;
        SysInfo.drop(root.consumerId);
    }

    function edit() { root.editing = true; }
    function done() { root.editing = false; }
    function toggleEdit() { root.editing = !root.editing; }

    // Forget every saved position. The widgets animate back to their defaults
    // rather than teleporting, which makes it obvious what happened.
    function resetLayout() { Settings.desktop.widgetLayout = ({}); }

    Variants {
        model: root.wanted
            ? (root.editing
                ? Quickshell.screens
                : Quickshell.screens.filter(s => Hypr.desktopVisibleOn(s)))
            : []

        PanelWindow {
            id: surface

            required property var modelData

            screen: surface.modelData
            visible: true
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            // Bottom normally; Overlay while arranging, so the widgets are
            // reachable without first clearing the workspace.
            WlrLayershell.layer: root.editing ? WlrLayer.Overlay : WlrLayer.Bottom
            WlrLayershell.namespace: "qs-widgets"
            WlrLayershell.keyboardFocus: root.editing
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Input policy.
            //
            //   arranging -> the whole surface takes input (mask: null)
            //   otherwise -> ONLY the widgets that are genuinely interactive
            //
            // The default is click-through, because a decorative widget that
            // eats a click meant for the desktop is worse than no widget. The
            // media player is the exception: it has transport buttons, and a
            // play button you cannot press is not a player. Its region is
            // therefore punched out of the click-through mask, and nothing
            // else is.
            //
            // A Region with no item and no children is empty, which is what
            // makes the surface click-through rather than merely transparent.
            mask: root.editing ? null : liveRegion

            Region {
                id: liveRegion

                Region {
                    // Dropping the item when the widget is hidden is what
                    // stops a disabled player from leaving an invisible hole
                    // in the desktop that still swallows clicks.
                    item: media.visible ? media : null
                }
            }

            // --- edit scrim ------------------------------------------------
            Rectangle {
                anchors.fill: parent
                visible: root.editing
                color: Qt.rgba(0, 0, 0, 0.35)
                opacity: root.editing ? 1 : 0

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationNormal }
                }

                // Clicking the empty desktop finishes arranging, which is what
                // everyone tries before looking for a button.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.done()
                }
            }

            // Snap grid, drawn only while arranging so there is something for
            // the snapping to visibly line up against.
            Loader {
                anchors.fill: parent
                active: root.editing && Settings.desktop.snapToGrid
                sourceComponent: Canvas {
                    renderStrategy: Canvas.Cooperative

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = Theme.wash(Theme.text, 0.07);
                        ctx.lineWidth = 1;

                        // Drawn at a multiple of the snap step -- a line every
                        // 8px would be a grey wash, not a grid.
                        const step = Math.max(16, Settings.desktop.gridSize * 8);
                        for (let x = 0; x < width; x += step) {
                            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                        }
                        for (let y = 0; y < height; y += step) {
                            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                        }
                    }
                }
            }

            // --- the widgets ------------------------------------------------
            // A plain Item per widget rather than a Repeater over a catalogue:
            // the widgets have nothing in common beyond their frame, and a
            // model of Components buys nothing but indirection.
            Item {
                id: field

                anchors.fill: parent
                // Keep everything clear of the bar, so a widget dragged to the
                // top edge does not end up half underneath it.
                anchors.topMargin: Appearance.barClearance
                anchors.margins: Appearance.screenMargin

                WidgetClock {
                    visible: Settings.desktop.clock
                    editing: root.editing
                }

                WidgetMedia {
                    id: media

                    visible: Settings.desktop.media && Settings.features.music && Media.available
                    editing: root.editing
                }

                WidgetCalendar {
                    visible: Settings.desktop.calendar && Settings.features.calendar
                    editing: root.editing
                }

                WidgetNetwork {
                    visible: Settings.desktop.network
                    editing: root.editing
                }

                WidgetGauge {
                    widgetId: "cpu"
                    defaultX: 0.74
                    defaultY: 0.56
                    visible: Settings.desktop.cpu
                    editing: root.editing

                    icon: "cpu"
                    label: "PROCESSOR"
                    value: SysInfo.cpuUsage
                    detail: Math.round(SysInfo.cpuUsage * 100) + "%"
                    tint: SysInfo.cpuUsage > 0.85 ? Theme.error
                        : SysInfo.cpuUsage > 0.6 ? Theme.warning : Theme.accent
                }

                WidgetGauge {
                    widgetId: "ram"
                    defaultX: 0.86
                    defaultY: 0.56
                    visible: Settings.desktop.ram
                    editing: root.editing

                    icon: "ram"
                    label: "MEMORY"
                    value: SysInfo.memoryUsage
                    detail: SysInfo.memoryUsedGb.toFixed(1) + "G"
                    tint: SysInfo.memoryUsage > 0.9 ? Theme.error
                        : SysInfo.memoryUsage > 0.75 ? Theme.warning : Theme.accent
                }

                WidgetGauge {
                    widgetId: "battery"
                    defaultX: 0.86
                    defaultY: 0.78
                    visible: Settings.desktop.battery && Performance.hasBattery
                    editing: root.editing

                    icon: Performance.batteryCharging ? "battery-charging" : "battery-full"
                    label: Performance.batteryCharging ? "CHARGING" : "BATTERY"
                    value: Performance.batteryPercent
                    detail: Math.round(Performance.batteryPercent * 100) + "%"
                    tint: {
                        const p = Performance.batteryPercent * 100;
                        if (Performance.batteryCharging) return Theme.success;
                        if (p <= 15) return Theme.error;
                        if (p <= 30) return Theme.warning;
                        return Theme.accent;
                    }
                }
            }

            // --- edit toolbar -------------------------------------------------
            Card {
                id: toolbar

                visible: root.editing
                elevation: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.xxl
                width: bar.implicitWidth + Appearance.lg * 2
                height: Appearance.controlHeight + Appearance.md

                Row {
                    id: bar

                    anchors.centerIn: parent
                    spacing: Appearance.md

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Drag widgets to rearrange"
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                    }

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "ghost"
                        text: "Reset"
                        onClicked: root.resetLayout()
                    }

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "accent"
                        text: "Done"
                        onClicked: root.done()
                    }
                }
            }

            // Escape leaves edit mode, matching every panel in the shell.
            Item {
                anchors.fill: parent
                focus: root.editing
                Keys.onEscapePressed: root.done()
            }
        }
    }
}
