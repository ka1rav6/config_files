import QtQuick
import qs

// =============================================================================
// DashClock — the big clock, the date and the connection status line
// =============================================================================
// One section of the dashboard, split out so the left drawer's pages
// (modules/drawer) can show the very same thing instead of a copy that drifts.
// It reads services only; whatever it needs polled (seconds, /proc, the MPRIS
// position) is demanded by its HOST while the host is on screen -- see
// Dashboard.qml and modules/drawer/Drawer.qml.
// =============================================================================

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
