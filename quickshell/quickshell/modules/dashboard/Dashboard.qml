import QtQuick
import Quickshell
import qs

// =============================================================================
// Dashboard.  SUPER + SHIFT + D
// =============================================================================
// The at-a-glance panel: clock, calendar, media, and system usage. Distinct
// from the Control Center, which is for CHANGING things -- this one is for
// LOOKING at them, and nothing here alters system state.
//
// System polling is reference-counted (see services/SysInfo.qml) and asked for
// only while this panel is open, so an unopened dashboard reads no /proc at
// all. Same for the MPRIS position tick.
// =============================================================================

Panel {
    id: root

    name: "dashboard"
    panelWidth: 420

    // Opened from the waybar clock it drops straight down out of the clock
    // (which is waybar's centre module, so horizontally centred); opened from
    // SUPER + SHIFT + D it comes in at the top right as before. Same panel,
    // same content -- only where it lands differs, so the gesture that opened
    // it is the one it appears to come from.
    property bool dropdown: false
    placement: root.dropdown ? "top-center" : "top-right"

    readonly property string consumerId: "dashboard"

    onOpened: {
        SysInfo.want(root.consumerId);
        Media.wantPosition(root.consumerId);
        Time.wantSeconds(root.consumerId);
    }

    onClosed: {
        // Back to the keybind position, so the next SUPER + SHIFT + D does not
        // inherit the waybar placement.
        root.dropdown = false;
        SysInfo.drop(root.consumerId);
        Media.dropPosition(root.consumerId);
        Time.dropSeconds(root.consumerId);
    }

    // A panel torn down without its onClosed running would leak the demand and
    // leave /proc being read forever.
    Component.onDestruction: {
        SysInfo.drop(root.consumerId);
        Media.dropPosition(root.consumerId);
        Time.dropSeconds(root.consumerId);
    }

    content: Column {
        spacing: Appearance.lg

        // --- clock ---------------------------------------------------------
        Column {
            width: parent.width
            spacing: 0

            Text {
                text: Time.timeWithSeconds
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.size(44)
                font.weight: Appearance.weightMedium
                font.letterSpacing: Appearance.trackingDisplay
                // Tabular figures, so the seconds ticking does not make the
                // whole line shuffle left and right once a second.
                font.features: ({ "tnum": 1 })
            }

            Text {
                text: Time.longDate
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
            }

            // A one-line summary of the things that have their own panels, so
            // the dashboard answers "is everything fine" without opening any
            // of them.
            Row {
                spacing: Appearance.md
                topPadding: Appearance.sm

                Row {
                    spacing: Appearance.xs
                    Icon {
                        name: Network.wiredConnected ? "ethernet"
                            : Network.wifiEnabled ? "wifi-" + Network.signalBars : "wifi-off"
                        size: Appearance.fontSmall
                        color: Network.connected ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Network.summary
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: Appearance.xs
                    visible: Bluetooth.available && Bluetooth.enabled
                    Icon {
                        name: Bluetooth.anyConnected ? "bluetooth-connected" : "bluetooth"
                        size: Appearance.fontSmall
                        color: Bluetooth.anyConnected ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Bluetooth.summary
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: Appearance.xs
                    Icon {
                        name: Audio.muted ? "volume-mute" : "volume-high"
                        size: Appearance.fontSmall
                        color: Audio.muted ? Theme.muted : Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // --- calendar ------------------------------------------------------
        Card {
            width: parent.width
            elevation: 0
            implicitHeight: calendar.implicitHeight + Appearance.md * 2

            Calendar {
                id: calendar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.md

                // The calendar owns the arrow keys while the dashboard is
                // open: left/right steps months, up/down steps years. It has
                // to actually hold focus for that to work -- the Panel routes
                // the keyboard to its content, and this is the only thing in
                // the content that wants it.
                focus: true

                // Always open on the current month rather than wherever it was
                // left days ago, and take focus each time.
                Connections {
                    target: root
                    function onOpened() {
                        calendar.reset();
                        calendar.forceActiveFocus();
                    }
                }
            }
        }

        // --- quick actions --------------------------------------------------
        // The four things most often wanted straight from a glance at the
        // clock. Deliberately few: this is a dashboard, and a wall of buttons
        // would make it a control panel.
        Row {
            width: parent.width
            spacing: Appearance.sm

            readonly property real cell: (width - spacing * 3) / 4

            Repeater {
                model: [
                    { icon: "palette",   label: "Themes",   target: "settings",  page: "appearance" },
                    { icon: "wallpaper", label: "Wallpaper", target: "wallpaper", page: "" },
                    { icon: "settings",  label: "Settings",  target: "settings",  page: "" },
                    { icon: "power",     label: "Power",     target: "power",     page: "" }
                ]

                Rectangle {
                    required property var modelData

                    width: parent.cell
                    height: 62
                    radius: Appearance.radiusInner
                    color: actionMouse.containsMouse ? Theme.wash(Theme.accent, 0.16)
                                                     : Theme.wash(Theme.text, 0.06)

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    scale: actionMouse.pressed ? 0.95 : 1.0
                    Behavior on scale {
                        enabled: !Appearance.motionless
                        NumberAnimation {
                            duration: Appearance.durationFast
                            easing.type: Appearance.easeStandard
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Appearance.xs

                        Icon {
                            name: modelData.icon
                            size: Appearance.iconSize
                            color: actionMouse.containsMouse ? Theme.accent : Theme.text
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: modelData.label
                            color: Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Shell.close("dashboard");
                            Shell.open(modelData.target);
                            if (modelData.page !== "" && Shell.has(modelData.target))
                                Shell.panels[modelData.target].page = modelData.page;
                        }
                    }
                }
            }
        }

        // --- media ---------------------------------------------------------
        CcMedia {
            width: parent.width
            visible: Media.available && Settings.features.music
        }

        // --- system ---------------------------------------------------------
        Card {
            width: parent.width
            elevation: 0
            implicitHeight: sys.implicitHeight + Appearance.md * 2

            Column {
                id: sys

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.md
                spacing: Appearance.sm

                Item {
                    width: parent.width
                    implicitHeight: 16

                    Text {
                        anchors.left: parent.left
                        text: "SYSTEM"
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        font.weight: Appearance.weightMedium
                        font.letterSpacing: Appearance.trackingLabel
                    }

                    Text {
                        anchors.right: parent.right
                        text: SysInfo.uptimeText === "" ? "" : "up " + SysInfo.uptimeText
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                    }
                }

                StatBar {
                    width: parent.width
                    icon: "cpu"
                    label: "Processor"
                    value: SysInfo.cpuUsage
                    detail: Math.round(SysInfo.cpuUsage * 100) + "%"
                }

                StatBar {
                    width: parent.width
                    icon: "ram"
                    label: "Memory"
                    value: SysInfo.memoryUsage
                    detail: SysInfo.memoryUsedGb.toFixed(1) + " / "
                          + SysInfo.memoryTotalGb.toFixed(1) + " GB"
                }

                StatBar {
                    width: parent.width
                    visible: SysInfo.diskTotalGb > 0
                    icon: "folder"
                    label: "Disk"
                    value: SysInfo.diskUsage
                    detail: SysInfo.diskUsedGb.toFixed(0) + " / "
                          + SysInfo.diskTotalGb.toFixed(0) + " GB"
                    tint: SysInfo.diskUsage > 0.9 ? Theme.error
                        : SysInfo.diskUsage > 0.75 ? Theme.warning : Theme.accent
                }

                StatBar {
                    width: parent.width
                    visible: Performance.hasBattery
                    icon: Performance.batteryCharging ? "battery-charging" : "battery-full"
                    label: "Battery"
                    value: Performance.batteryPercent
                    // UPower needs a few minutes of history after a resume
                    // before the estimate means anything, so it is omitted
                    // rather than shown as "0 minutes remaining".
                    detail: {
                        const pct = Math.round(Performance.batteryPercent * 100) + "%";
                        const secs = Performance.batteryTimeRemaining;
                        if (!(secs > 0)) return pct;
                        const h = Math.floor(secs / 3600);
                        const m = Math.floor((secs % 3600) / 60);
                        return pct + " · " + (h > 0 ? h + "h " + m + "m" : m + "m")
                             + (Performance.batteryCharging ? " to full" : " left");
                    }
                    // Amber then red, on the same thresholds waybar uses.
                    tint: {
                        const p = Performance.batteryPercent * 100;
                        if (Performance.batteryCharging) return Theme.success;
                        if (p <= 15) return Theme.error;
                        if (p <= 30) return Theme.warning;
                        return Theme.accent;
                    }
                }
            }
        }
    }
}
