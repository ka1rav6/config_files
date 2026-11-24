import QtQuick
import qs

// =============================================================================
// ClockDigital — HH:MM:SS in the mono face, with the date under it.
// =============================================================================
// The one clock style with a seconds readout, so it is also the one that asks
// Time for a per-second tick (wantSeconds) -- for exactly as long as it exists.
// The widget layer destroys widgets whenever the desktop is covered, so a
// covered desktop costs no seconds tick at all.
// =============================================================================

DesktopWidget {
    id: root

    defaultX: 0.035
    defaultY: 0.10
    contentWidth: 300
    contentHeight: 116

    readonly property string consumer: "clock-digital-" + root.widgetId
    Component.onCompleted: Time.wantSeconds(root.consumer)
    Component.onDestruction: Time.dropSeconds(root.consumer)

    Column {
        anchors.centerIn: parent
        spacing: Appearance.xs

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.timeWithSeconds
            color: Theme.text
            font.family: Appearance.fontMono
            font.pixelSize: Appearance.size(44)
            font.weight: Appearance.weightMedium
            font.features: ({ "tnum": 1 })
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: dateText.implicitWidth + Appearance.md * 2
            height: dateText.implicitHeight + Appearance.xs * 2
            radius: Appearance.radiusFull
            color: Theme.wash(Theme.accent, 0.16)

            Text {
                id: dateText

                anchors.centerIn: parent
                text: Time.shortDate
                color: Theme.accent
                font.family: Appearance.fontMono
                font.pixelSize: Appearance.fontSmall
            }
        }
    }
}
