import QtQuick
import qs

// Connection at a glance: what you are on, and how well.
DesktopWidget {
    id: root

    widgetId: "network"
    defaultX: 0.035
    defaultY: 0.56
    contentWidth: 240
    contentHeight: 96

    Row {
        anchors.fill: parent
        spacing: Appearance.md

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Network.wiredConnected ? "ethernet"
                : Network.wifiEnabled ? "wifi-" + Network.signalBars : "wifi-off"
            size: 30
            color: Network.connected ? Theme.accent : Theme.muted
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 30 - Appearance.md
            spacing: 3

            Text {
                width: parent.width
                text: Network.summary
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontLabel
                font.weight: Appearance.weightSemi
                elide: Text.ElideRight
            }

            Text {
                text: Network.wiredConnected ? "Wired"
                    : Network.wifiConnected ? Network.signalStrength + "% signal"
                    : "Not connected"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
            }

            // Four ticks rising left to right -- the signal read without a
            // number, which is how most people actually read Wi-Fi.
            Row {
                spacing: 3
                // Explicit height: the ticks anchor to this Row's bottom edge,
                // and a positioner sizing itself from children that anchor to
                // it is a binding loop.
                height: 13
                visible: Network.wifiConnected

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: 6
                        height: 4 + index * 3
                        radius: 1
                        color: Network.signalBars > index
                            ? Theme.accent : Theme.wash(Theme.text, 0.14)
                        anchors.bottom: parent.bottom

                        Behavior on color {
                            enabled: !Appearance.motionless
                            ColorAnimation { duration: Appearance.durationNormal }
                        }
                    }
                }
            }
        }
    }
}
