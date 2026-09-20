import QtQuick
import Quickshell
import qs

// =============================================================================
// Control Center — main page.
// =============================================================================
// Ordered by how often it is reached for, top to bottom: identity, the four
// connectivity toggles, the two continuous controls, media, power profile,
// then the way out to Settings and the power menu.
// =============================================================================

Column {
    id: root

    signal navigate(string page)

    spacing: Appearance.gap

    // --- header ---------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: 52

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                // Quickshell.env is read once; the user's name does not change
                // mid-session. Falls back to the login name if the GECOS field
                // is empty, and to a greeting if even that fails.
                text: {
                    const name = Quickshell.env("USER") || "";
                    if (name === "") return "Hello";
                    return name.charAt(0).toUpperCase() + name.slice(1);
                }
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontHeading
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
            }

            Text {
                text: Time.longDate
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
            }
        }

        // Battery, top right. Only present on a machine that has one.
        Row {
            visible: Performance.hasBattery
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.xs

            Icon {
                name: {
                    if (Performance.batteryCharging) return "battery-charging";
                    const p = Performance.batteryPercent * 100;
                    if (p > 80) return "battery-full";
                    if (p > 55) return "battery-high";
                    if (p > 30) return "battery-mid";
                    if (p > 10) return "battery-low";
                    return "battery-empty";
                }
                size: Appearance.iconSize
                // Amber under 30%, red under 15% -- the same thresholds
                // ~/.config/waybar/config.jsonc uses, so the bar and the panel
                // never disagree about when to be worried.
                color: {
                    const p = Performance.batteryPercent * 100;
                    if (Performance.batteryCharging) return Theme.success;
                    if (p <= 15) return Theme.error;
                    if (p <= 30) return Theme.warning;
                    return Theme.muted;
                }
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: Math.round(Performance.batteryPercent * 100) + "%"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                font.weight: Appearance.weightMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // --- connectivity tiles ----------------------------------------------
    Grid {
        width: parent.width
        columns: 2
        spacing: Appearance.gap

        readonly property real cellWidth: (width - spacing) / 2

        QuickTile {
            width: parent.cellWidth
            icon: {
                if (Network.wiredConnected) return "ethernet";
                if (!Network.wifiEnabled) return "wifi-off";
                return "wifi-" + Network.signalBars;
            }
            label: "Wi-Fi"
            detail: Network.summary
            active: Network.wifiEnabled || Network.wiredConnected
            enabled: Network.wifiHardwareEnabled
            expandable: true
            onToggled: Network.toggleWifi()
            onExpand: root.navigate("wifi")
        }

        QuickTile {
            width: parent.cellWidth
            icon: Bluetooth.anyConnected ? "bluetooth-connected"
                : Bluetooth.enabled ? "bluetooth" : "bluetooth-off"
            label: "Bluetooth"
            detail: Bluetooth.summary
            active: Bluetooth.enabled
            enabled: Bluetooth.available
            expandable: Bluetooth.enabled
            busy: Bluetooth.discovering
            onToggled: Bluetooth.toggle()
            onExpand: root.navigate("bluetooth")
        }

        QuickTile {
            width: parent.cellWidth
            icon: "night-light"
            label: "Night Light"
            detail: NightLight.active ? "On · warm" : "Off"
            active: NightLight.active
            onToggled: NightLight.toggle()
        }

        QuickTile {
            width: parent.cellWidth
            icon: Notifications.dnd ? "bell-off" : "bell"
            label: "Do Not Disturb"
            detail: Notifications.dnd ? "Silenced" : "Notifications on"
            active: Notifications.dnd
            onToggled: Notifications.toggleDnd()
        }
    }

    // --- continuous controls ----------------------------------------------
    Slider {
        width: parent.width
        icon: {
            if (Audio.muted) return "volume-mute";
            if (Audio.volume > 0.66) return "volume-high";
            if (Audio.volume > 0.33) return "volume-mid";
            return "volume-low";
        }
        value: Audio.muted ? 0 : Audio.volume
        onMoved: (v) => Audio.setVolume(v)
    }

    Slider {
        visible: Brightness.available
        width: parent.width
        icon: Brightness.displayed > 0.5 ? "brightness-high" : "brightness-low"
        value: Brightness.displayed
        onMoved: (v) => Brightness.setBrightness(v)
    }

    // Output device, as a row rather than a tile: it is a choice, not a toggle.
    Item {
        width: parent.width
        implicitHeight: Appearance.controlHeightSmall

        Icon {
            id: outIcon
            name: "headphones"
            size: Appearance.iconSize
            color: Theme.muted
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.left: outIcon.right
            anchors.leftMargin: Appearance.sm
            anchors.right: outChevron.left
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.sinkName
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            elide: Text.ElideRight
        }

        Button {
            id: outChevron
            width: Appearance.controlHeightSmall
            height: Appearance.controlHeightSmall
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            variant: "ghost"
            icon: "chevron-right"
            onClicked: root.navigate("audio")
        }
    }

    // --- media -------------------------------------------------------------
    CcMedia {
        width: parent.width
        visible: Media.available && Settings.features.music
    }

    // --- power profile -----------------------------------------------------
    // A segmented control rather than three tiles: the options are mutually
    // exclusive, and showing them as one control says so without a label.
    Column {
        width: parent.width
        spacing: Appearance.sm

        Text {
            text: "Performance"
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            font.weight: Appearance.weightMedium
            font.letterSpacing: Appearance.trackingLabel
        }

        Row {
            width: parent.width
            spacing: Appearance.xs

            readonly property var options: [
                { id: "saver",    label: "Saver",    icon: "saver" },
                { id: "balanced", label: "Balanced", icon: "balanced" },
                { id: "visual",   label: "Visual",   icon: "performance" }
            ]
            readonly property real cell: (width - spacing * 2) / 3

            Repeater {
                model: parent.options

                Rectangle {
                    required property var modelData

                    width: parent.cell
                    height: Appearance.controlHeight
                    radius: Appearance.radiusInner

                    readonly property bool selected: Settings.performance.profile === modelData.id
                    // The profile actually in force may differ from the one
                    // chosen, when the battery downshift is active. Showing
                    // both stops the control looking like it ignored the click.
                    readonly property bool effective: Performance.profile === modelData.id && !selected

                    color: selected ? Theme.accent
                         : effective ? Theme.wash(Theme.accent, 0.18)
                         : Theme.wash(Theme.text, 0.06)

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationNormal }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Icon {
                            name: modelData.icon
                            size: Appearance.iconSize
                            color: parent.parent.selected ? Theme.onAccent(Theme.accent) : Theme.text
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: modelData.label
                            color: parent.parent.selected ? Theme.onAccent(Theme.accent) : Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.performance.profile = modelData.id
                    }
                }
            }
        }

        // Explain the downshift rather than letting the control look broken.
        Text {
            width: parent.width
            visible: Performance.downshifted
            text: "On battery — running in " + Performance.profile
            color: Theme.warning
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            wrapMode: Text.WordWrap
        }
    }

    // --- footer ------------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: Appearance.controlHeight

        Button {
            anchors.left: parent.left
            width: parent.width - Appearance.controlHeight - Appearance.sm
            height: Appearance.controlHeight
            icon: "settings"
            text: "Settings"
            variant: "soft"
            onClicked: {
                Shell.closeAll();
                Shell.open("settings");
            }
        }

        Button {
            anchors.right: parent.right
            width: Appearance.controlHeight
            height: Appearance.controlHeight
            icon: "power"
            variant: "soft"
            onClicked: {
                Shell.closeAll();
                Shell.open("power");
            }
        }
    }
}
