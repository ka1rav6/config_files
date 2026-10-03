import QtQuick
import Quickshell
import qs

// =============================================================================
// Settings — Network and Bluetooth.
// =============================================================================
// Both on one page deliberately: they are the same kind of thing (radios you
// turn on and devices you connect to), they are short, and splitting them would
// mean two sidebar entries that are each half empty.
//
// Scanning is gated on this page being visible, exactly as it is in the Control
// Center -- see the Bindings at the bottom. Leaving Settings open on another
// page does not leave the radios scanning.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    // Scanning costs battery, so it runs only while this page exists. The page
    // is inside a Loader in SettingsWindow.qml, so leaving it destroys this
    // object and the Bindings release automatically.
    Binding {
        target: Network
        property: "scanning"
        value: true
    }

    Binding {
        target: Bluetooth
        property: "scanning"
        value: Bluetooth.enabled
    }

    // --- Wi-Fi -----------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "WI-FI"
        subtitle: Network.summary + (Network.signalStrength > 0 ? " · " + Network.signalStrength + "% signal" : "")

        SettingRow {
            width: parent.width
            label: "Wi-Fi"
            description: Network.wifiHardwareEnabled
                ? "Radio power" : "Disabled by a hardware switch"
            Toggle {
                checked: Network.wifiEnabled
                enabled: Network.wifiHardwareEnabled
                onToggled: (v) => Network.setWifiEnabled(v)
            }
        }

        Repeater {
            model: Network.wifiEnabled ? Network.networks.slice(0, 10) : []

            Rectangle {
                id: row

                required property var modelData

                // Whether this row's Forget button is armed. Per row, so
                // arming one disarms nothing else and nothing else arms it.
                property bool confirming: false

                width: parent.width
                height: Appearance.controlHeight
                radius: Appearance.radiusInner
                color: modelData.connected ? Theme.wash(Theme.accent, 0.16)
                     : netMouse.containsMouse ? Theme.hover : "transparent"

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }

                Icon {
                    id: netIcon
                    // Via the service, not modelData.signalStrength directly:
                    // that property is a 0.0-1.0 fraction, so comparing it
                    // against 75/50/25 here always picked the weakest icon.
                    name: "wifi-" + Network.signalBarsFor(modelData)
                    size: Appearance.iconSize
                    color: modelData.connected ? Theme.accent : Theme.muted
                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.left: netIcon.right
                    anchors.leftMargin: Appearance.sm
                    anchors.right: netState.left
                    anchors.rightMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                    elide: Text.ElideRight
                }

                Text {
                    id: netState
                    anchors.right: forgetButton.left
                    anchors.rightMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.connected ? "Connected"
                        : modelData.known ? "Saved"
                        : Network.signalPercent(modelData) + "%"
                    color: modelData.connected ? Theme.accent : Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        row.confirming = false;
                        // A passphrase prompt belongs in the Control Center,
                        // which is built around one-handed operation. From here
                        // an unknown network opens the proper editor.
                        if (modelData.connected) Network.disconnect();
                        else if (Network.needsPassphrase(modelData)) {
                            Shell.close("settings");
                            Shell.open("control-center");
                            Shell.panels["control-center"].page = "wifi";
                        } else Network.connect(modelData);
                    }
                }

                // Forget, so a router whose password changed can be re-joined
                // at all: a `known` network never prompts, so until the stored
                // profile is deleted (or overwritten from the Control Center's
                // key button) the stale secret is retried forever.
                //
                // DECLARED AFTER THE ROW'S MouseArea ON PURPOSE -- later
                // siblings are on top, and a fill-the-row MouseArea written
                // after this would swallow every click aimed at it.
                //
                // Confirmed in place rather than with a dialog: the first click
                // turns the icon into the word, the second does it. A Settings
                // list row is not worth a modal, but deleting a passphrase you
                // may not have written down anywhere is worth a second look.
                Button {
                    id: forgetButton

                    visible: modelData.known
                    width: visible ? implicitWidth : 0
                    height: Appearance.controlHeight
                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.confirming ? "Forget?" : ""
                    icon: row.confirming ? "" : "trash"
                    variant: row.confirming ? "danger" : "ghost"
                    onClicked: {
                        if (row.confirming) {
                            Network.forget(modelData);
                            row.confirming = false;
                            confirmTimeout.stop();
                        } else {
                            row.confirming = true;
                            confirmTimeout.restart();
                        }
                    }
                }

                // An armed Forget that is walked away from disarms itself, so
                // it can never be the thing sitting under the next stray click.
                Timer {
                    id: confirmTimeout
                    interval: 4000
                    onTriggered: row.confirming = false
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Advanced"
            description: "Static addresses, VPNs, editing saved profiles"
            Button {
                text: "nm-connection-editor"
                variant: "soft"
                onClicked: {
                    Quickshell.execDetached(["nm-connection-editor"]);
                    Shell.close("settings");
                }
            }
        }
    }

    // --- Bluetooth ---------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "BLUETOOTH"
        subtitle: Bluetooth.summary

        SettingRow {
            width: parent.width
            label: "Bluetooth"
            description: Bluetooth.available ? "Adapter power" : "No adapter found"
            Toggle {
                checked: Bluetooth.enabled
                enabled: Bluetooth.available
                onToggled: (v) => Bluetooth.setEnabled(v)
            }
        }

        Repeater {
            model: Bluetooth.enabled ? Bluetooth.pairedDevices : []

            BtRow {
                required property var modelData
                width: parent.width
                device: modelData
            }
        }

        Repeater {
            model: Bluetooth.enabled ? Bluetooth.availableDevices.slice(0, 8) : []

            BtRow {
                required property var modelData
                width: parent.width
                device: modelData
            }
        }

        SettingRow {
            width: parent.width
            label: "Advanced"
            description: "File transfer, full device management"
            Button {
                text: "blueman-manager"
                variant: "soft"
                onClicked: {
                    Quickshell.execDetached(["blueman-manager"]);
                    Shell.close("settings");
                }
            }
        }
    }
}
