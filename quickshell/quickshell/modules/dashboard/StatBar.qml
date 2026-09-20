import QtQuick
import qs

// One labelled usage bar. Used for CPU, memory and battery, so all three read
// identically instead of each inventing its own layout.
Item {
    id: root

    property string icon: "info"
    property string label: ""
    property string detail: ""
    property real value: 0             // 0..1
    property color tint: Theme.accent

    implicitHeight: 38

    Icon {
        id: statIcon

        name: root.icon
        size: Appearance.iconSize
        color: Theme.muted
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    Column {
        anchors.left: statIcon.right
        anchors.leftMargin: Appearance.sm
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Item {
            width: parent.width
            implicitHeight: labelText.implicitHeight

            Text {
                id: labelText
                anchors.left: parent.left
                text: root.label
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
            }

            Text {
                anchors.right: parent.right
                text: root.detail
                color: Theme.muted
                font.family: Appearance.fontMono
                font.pixelSize: Appearance.fontCaption
            }
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.wash(Theme.border, 0.35)

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
                height: parent.height
                radius: parent.radius
                color: root.tint

                // These update every few seconds, so a gentle glide reads much
                // better than a jump -- and at that rate the animation is free.
                Behavior on width {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: Appearance.durationSlow
                        easing.type: Appearance.easeStandard
                    }
                }
                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationSlow }
                }
            }
        }
    }
}
