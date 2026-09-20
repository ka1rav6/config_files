import QtQuick
import QtQuick.Controls
import qs

// One emoji: click to copy, right-click to pin. The star is only drawn when it
// is actually a favourite, so a grid of 180 cells is 180 rectangles and not 360.
Rectangle {
    id: root

    property string emoji: ""
    property string label: ""
    property bool favourite: false

    signal picked()
    signal toggleFavourite()

    width: 40
    height: 40
    radius: Appearance.radiusSmall
    color: mouse.containsMouse ? Theme.wash(Theme.accent, 0.18) : "transparent"

    Behavior on color {
        enabled: !Appearance.motionless
        ColorAnimation { duration: Appearance.durationFast }
    }

    scale: mouse.pressed ? 0.86 : mouse.containsMouse ? 1.18 : 1.0

    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationFast
            easing.type: Appearance.easeEmphasised
            easing.overshoot: Appearance.overshoot
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.emoji
        // The colour font is explicit: without it Qt can fall back to a
        // monochrome symbol face and the whole grid renders as outlines.
        font.family: "Noto Color Emoji"
        font.pixelSize: 22
    }

    // Favourite marker. A dot rather than a star glyph: at this size a star is
    // mush, and it would compete with the emoji itself.
    Rectangle {
        visible: root.favourite
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: 5
        height: 5
        radius: 2.5
        color: Theme.accent2
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (event) => {
            if (event.button === Qt.RightButton) root.toggleFavourite();
            else root.picked();
        }
    }

    ToolTip.visible: mouse.containsMouse && root.label !== ""
    ToolTip.text: root.label + (root.favourite ? "  ·  favourite" : "")
    ToolTip.delay: 420
}
