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
                required property var modelData

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
                    name: "wifi-" + (modelData.signalStrength >= 75 ? 4
                                   : modelData.signalStrength >= 50 ? 3
                                   : modelData.signalStrength >= 25 ? 2 : 1)
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
                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.connected ? "Connected"
                        : modelData.known ? "Saved"
                        : modelData.signalStrength + "%"
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
