import QtQuick
// Quickshell, for execDetached() -- see the handler that opens the external
// tool below. WITHOUT THIS IMPORT the `Quickshell` name is simply undefined,
// the click handler dies on a ReferenceError, and the button does nothing at
// all with no visible error: the qmldir header's warning about singletons,
// one level up.
import Quickshell
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

        // Eight rather than six, now that the list holds only devices with real
        // names. The old cap was six because the list was mostly anonymous BLE
        // beacons and showing more of those was pointless -- but it also meant
        // the beacons could crowd the actual device off the end.
        Repeater {
            model: Bluetooth.availableDevices.slice(0, 8)

            BtRow {
                width: parent.width
                device: modelData
                required property var modelData
            }
        }

        Text {
            width: parent.width
            visible: Bluetooth.availableDevices.length === 0
            wrapMode: Text.WordWrap
            text: Bluetooth.discovering
                  ? "Nothing with a name yet. Put the device into pairing mode — usually holding its power button until it flashes."
                  : "No new devices found yet."
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
        }
    }

    // --- anonymous devices -------------------------------------------------
    //
    // Devices that have not advertised a name. Behind a disclosure because they
    // are overwhelmingly BLE beacons -- other people's trackers, phones using
    // privacy addresses, earbud cases -- and listing them inline is what made
    // this page look like a wall of MAC addresses with the real device nowhere
    // in sight. They are still REACHABLE, because occasionally one of them is
    // the thing you want (a cheap dongle that never sends a name), and because
    // hiding something the radio can plainly see is its own kind of lie.
    Column {
        id: unnamedSection

        width: parent.width
        spacing: Appearance.xs
        visible: Bluetooth.enabled && Bluetooth.unnamedDevices.length > 0

        property bool expanded: false

        // Collapse when the page is left, so reopening it never starts out
        // showing the noise.
        Connections {
            target: Bluetooth
            function onScanningChanged() {
                if (!Bluetooth.scanning) unnamedSection.expanded = false;
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.controlHeightSmall
            radius: Appearance.radiusInner
            color: unnamedMouse.containsMouse ? Theme.hover : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.sm
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.xs

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: unnamedSection.expanded ? "close" : "plus"
                    size: 12
                    color: Theme.muted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const n = Bluetooth.unnamedDevices.length;
                        return (unnamedSection.expanded ? "Hide " : "Show ") + n
                               + (n === 1 ? " unnamed device" : " unnamed devices");
                    }
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }

            MouseArea {
                id: unnamedMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: unnamedSection.expanded = !unnamedSection.expanded
            }
        }

        Repeater {
            model: unnamedSection.expanded ? Bluetooth.unnamedDevices.slice(0, 12) : []

            BtRow {
                width: unnamedSection.width
                device: modelData
                required property var modelData
            }
        }
    }

    // --- pairing fallback --------------------------------------------------
    //
    // Pairing happens in the lists above now: clicking an unpaired row runs
    // ~/.local/bin/bt-connect, which holds a bluetoothctl session open as the
    // BlueZ pairing agent for the length of one pairing, then pairs, trusts and
    // connects. Before that this page had no pairing path at all -- it called
    // BluetoothDevice.pair(), BlueZ rejected it for want of an agent, and the
    // row did nothing.
    //
    // THIS BUTTON IS WHAT bt-connect CANNOT DO
    //   An agent can answer "confirm this passkey" unattended. It cannot answer
    //   "enter this PIN" -- a keyboard showing a code you have to type IN needs
    //   a dialog and a person. blueman has those dialogs, so that case still
    //   goes to ~/.local/bin/bt-pair, which starts blueman-applet for its
    //   AuthAgent and stops it again when the window closes.
    //
    //   Also still the place to go for anything beyond connecting: file
    //   transfer, per-device service toggles, network access points.
    //
    // THE BUTTON ITSELF WAS DEAD UNTIL NOW, FOR AN UNRELATED REASON
    //   This file never imported Quickshell, so `Quickshell.execDetached` in
    //   the handler below threw a ReferenceError on every click and nothing
    //   happened -- silently, because an undefined singleton reference is not a
    //   load-time error. CcWifi.qml and CcAudio.qml had exactly the same
    //   missing import, and the same two dead buttons.
    Column {
        width: parent.width
        spacing: Appearance.xs
        visible: Bluetooth.enabled

        Rectangle {
            width: parent.width
            height: Appearance.controlHeight
            radius: Appearance.radiusInner
            // Highlighted when a pairing has just failed specifically because
            // the device needs a PIN typed in -- that is the one failure this
            // button is the answer to, so point at it rather than making the
            // user guess.
            color: pairMouse.containsMouse || Bluetooth.pairingNeedsManager
                   ? Theme.wash(Theme.accent, 0.16)
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
                    color: pairMouse.containsMouse || Bluetooth.pairingNeedsManager
                           ? Theme.accent : Theme.text
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open Bluetooth manager…"
                    color: pairMouse.containsMouse || Bluetooth.pairingNeedsManager
                           ? Theme.accent : Theme.text
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
            text: Bluetooth.pairingNeedsManager
                  ? "That device needs a PIN typed in, which only the manager can do."
                  : "For devices that need a PIN typed in, and for file transfer. Only running while its window is open."
            color: Bluetooth.pairingNeedsManager ? Theme.accent : Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
        }
    }
}
