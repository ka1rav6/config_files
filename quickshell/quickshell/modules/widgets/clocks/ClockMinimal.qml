import QtQuick
import qs

// =============================================================================
// ClockMinimal — a thin time and the day, and nothing else.
// =============================================================================
// Frameless, light weight, left-aligned: the quiet style for a busy
// wallpaper. Minute resolution, so no seconds tick.
// =============================================================================

DesktopWidget {
    id: root

    defaultX: 0.04
    defaultY: 0.12
    contentWidth: 320
    contentHeight: 128
    bare: true

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            text: Time.time
            color: Theme.text
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
            font.family: Appearance.font
            font.pixelSize: Appearance.size(76)
            font.weight: Font.Light
            font.letterSpacing: Appearance.trackingDisplay
            font.features: ({ "tnum": 1 })
        }

        Text {
            text: Time.longDate.toUpperCase()
            color: Theme.muted
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            font.weight: Appearance.weightMedium
            font.letterSpacing: 2
        }
    }
}
