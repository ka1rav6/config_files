import QtQuick
import qs

// The desktop clock. Big, quiet, and the one widget that is on by default.
DesktopWidget {
    id: root

    widgetId: "clock"
    defaultX: 0.035
    defaultY: 0.10
    contentWidth: 300
    contentHeight: 148

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            text: Time.time
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontDisplay
            font.weight: Appearance.weightBold
            font.letterSpacing: Appearance.trackingDisplay
            // Tabular figures so the minute rolling over does not shuffle the
            // line sideways.
            font.features: ({ "tnum": 1 })
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: Time.longDate
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontLabel
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
