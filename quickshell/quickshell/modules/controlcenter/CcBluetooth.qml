import QtQuick
import qs

// =============================================================================
// Control Center — Bluetooth page.
// =============================================================================
// Replaces blueman-manager for the common cases (connect a headset, forget a
// device), and blueman-applet + blueman-tray entirely -- two GTK/Python
// processes holding ~43 MiB of PSS between them purely to supply a tray icon.
//
// Discovery runs only while this page is open; the Binding is in
// ControlCenter.qml. That is deliberate and it is the difference between a
// Bluetooth panel and a Bluetooth battery drain.
// =============================================================================

Column {
    id: root

    signal back()

    spacing: Appearance.gap

    CcHeader {
        width: parent.width
        title: "Bluetooth"
        onBack: root.back()

        Toggle {
            checked: Bluetooth.enabled
            enabled: Bluetooth.available
            onToggled: (v) => Bluetooth.setEnabled(v)
        }
    }

    Text {
        width: parent.width
        visible: !Bluetooth.available
        text: "No Bluetooth adapter found."
        color: Theme.muted
        font.family: Appearance.font
        font.pixelSize: Appearance.fontSmall
        wrapMode: Text.WordWrap
    }

    // --- paired ----------------------------------------------------------
    Column {
        width: parent.width
        spacing: Appearance.xs
        visible: Bluetooth.enabled && Bluetooth.pairedDevices.length > 0

        Text {
            text: "My devices"
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            font.weight: Appearance.weightMedium
            font.letterSpacing: Appearance.trackingLabel
        }

        Repeater {
            model: Bluetooth.pairedDevices

            BtRow {
                width: parent.width
                device: modelData
                required property var modelData
            }
        }
    }

    // --- discovered --------------------------------------------------------
    Column {
        width: parent.width
        spacing: Appearance.xs
        visible: Bluetooth.enabled

        Row {
            width: parent.width
            spacing: Appearance.sm

            Text {
                text: "Available"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                font.weight: Appearance.weightMedium
                font.letterSpacing: Appearance.trackingLabel
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: Bluetooth.discovering
                text: "scanning…"
                color: Theme.accent
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: Bluetooth.discovering && !Appearance.motionless
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }
        }

        Repeater {
            model: Bluetooth.availableDevices.slice(0, 6)

            BtRow {
                width: parent.width
                device: modelData
                required property var modelData
            }
        }

        Text {
            width: parent.width
            visible: Bluetooth.availableDevices.length === 0
            text: "No new devices found yet."
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
        }
    }

    // --- pairing -----------------------------------------------------------
    //
    // Connecting a device that is already paired happens right here in the
    // list above. PAIRING a new one is different: BlueZ refuses to pair unless
    // something has registered an org.bluez.Agent1 to answer "confirm this
    // passkey", and this shell registers none -- so that step is handed to
    // blueman, started on demand by ~/.local/bin/bt-pair and stopped again
    // when its window closes. See the header of that script.
    Column {
        width: parent.width
        spacing: Appearance.xs
        visible: Bluetooth.enabled

        Rectangle {
            width: parent.width
            height: Appearance.controlHeight
            radius: Appearance.radiusInner
            color: pairMouse.containsMouse ? Theme.wash(Theme.accent, 0.16)
                                           : Theme.wash(Theme.text, 0.06)

            Behavior on color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationFast }
            }

            Row {
                anchors.centerIn: parent
                spacing: Appearance.sm

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "plus"
                    size: 16
                    color: pairMouse.containsMouse ? Theme.accent : Theme.text
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pair a new device…"
                    color: pairMouse.containsMouse ? Theme.accent : Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                    font.weight: Appearance.weightMedium
                }
            }

            MouseArea {
                id: pairMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/bt-pair"]);
                    Shell.close("control-center");
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Opens the Bluetooth manager, which handles passkey prompts. It is only running while that window is open."
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
        }
    }
}
