import QtQuick
import qs

// =============================================================================
// ClockStacked — hours over minutes, very large, no card.
// =============================================================================
// The Material "stacked digits" clock from Anserin's picker. Hours in the text
// colour, minutes in the accent, so the two lines read as one time. Frameless:
// the digits sit straight on the wallpaper, with a faint raised edge so they
// survive a light image. Minute resolution, so no seconds tick.
// =============================================================================

DesktopWidget {
    id: root

    defaultX: 0.04
    defaultY: 0.10
    contentWidth: 190
    contentHeight: 220
    bare: true

    Column {
        anchors.centerIn: parent
        spacing: -Appearance.size(30)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.hours
            color: Theme.text
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
            font.family: Appearance.font
            font.pixelSize: Appearance.size(108)
            font.weight: Appearance.weightBold
            font.letterSpacing: Appearance.trackingDisplay
            font.features: ({ "tnum": 1 })
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.minutes
            color: Theme.accent
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
            font.family: Appearance.font
            font.pixelSize: Appearance.size(108)
            font.weight: Appearance.weightBold
            font.letterSpacing: Appearance.trackingDisplay
            font.features: ({ "tnum": 1 })
        }
    }
}
