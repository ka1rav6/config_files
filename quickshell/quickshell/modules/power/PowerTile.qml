import QtQuick
import qs

// One power action. Turns red and grows slightly when armed, so "this one is
// about to happen" is readable without reading.
Rectangle {
    id: root

    required property var action
    property bool armed: false
    property bool focused: false

    signal triggered()
    signal hovered()

    height: 104
    radius: Appearance.radiusInner

    color: root.armed ? Theme.error
         : (root.focused || mouse.containsMouse) ? Theme.wash(Theme.text, 0.12)
         : Theme.wash(Theme.text, 0.05)

    border.width: root.focused && !root.armed ? 1 : 0
    border.color: Theme.accent

    Behavior on color {
        enabled: !Appearance.motionless
        ColorAnimation { duration: Appearance.durationNormal }
    }

    scale: mouse.pressed ? 0.95 : (root.armed ? 1.04 : 1.0)
    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationNormal
            easing.type: Appearance.easeEmphasised
            easing.overshoot: Appearance.overshoot
        }
    }

    readonly property color fg: root.armed ? Theme.onAccent(Theme.error) : Theme.text

    Column {
        anchors.centerIn: parent
        spacing: Appearance.sm

        Icon {
            name: root.action.icon
            size: Appearance.iconSizeLarge
            color: root.fg
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationNormal }
            }
        }

        Text {
            text: root.action.label
            color: root.fg
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            font.weight: Appearance.weightMedium
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // The mnemonic, bottom-right and quiet.
    Text {
        text: root.action.key
        color: root.fg
        opacity: 0.4
        font.family: Appearance.fontMono
        font.pixelSize: Appearance.fontCaption
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.sm
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
        onEntered: root.hovered()
    }
}
