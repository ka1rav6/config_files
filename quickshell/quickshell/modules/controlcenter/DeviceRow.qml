import QtQuick
import qs

// One selectable audio device. A check rather than a radio button: the list is
// short, and a tick reads as "this is the one" faster than a filled circle.
Rectangle {
    id: root

    required property var node
    property bool selected: false
    property string icon: "headphones"

    signal chosen()

    height: Appearance.controlHeight
    radius: Appearance.radiusInner
    color: root.selected ? Theme.wash(Theme.accent, 0.16)
         : mouse.containsMouse ? Theme.hover : "transparent"

    Behavior on color {
        enabled: !Appearance.motionless
        ColorAnimation { duration: Appearance.durationFast }
    }

    Icon {
        id: deviceIcon

        name: root.icon
        size: Appearance.iconSize
        color: root.selected ? Theme.accent : Theme.muted
        anchors.left: parent.left
        anchors.leftMargin: Appearance.sm
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        anchors.left: deviceIcon.right
        anchors.leftMargin: Appearance.sm
        anchors.right: tick.left
        anchors.rightMargin: Appearance.sm
        anchors.verticalCenter: parent.verticalCenter
        // `description` is PipeWire's friendly name ("Built-in Audio Speaker");
        // the raw `name` is an alsa id nobody wants to read.
        text: root.node ? (root.node.description || root.node.nickname || root.node.name) : ""
        color: Theme.text
        font.family: Appearance.font
        font.pixelSize: Appearance.fontBody
        font.weight: root.selected ? Appearance.weightMedium : Appearance.weightNormal
        elide: Text.ElideRight
    }

    Icon {
        id: tick

        name: "check"
        size: Appearance.iconSize
        color: Theme.accent
        opacity: root.selected ? 1 : 0
        anchors.right: parent.right
        anchors.rightMargin: Appearance.sm
        anchors.verticalCenter: parent.verticalCenter

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationNormal }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }
}
