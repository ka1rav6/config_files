import QtQuick
import qs

// A theme, shown as the thing it actually is: its own colours. A list of names
// tells you nothing about what "kanagawa" looks like; three accent dots on that
// theme's own background tells you immediately.
Rectangle {
    id: root

    required property var theme
    property bool current: false
    property bool busy: false

    signal chosen()

    height: 78
    radius: Appearance.radiusInner
    // Painted in the THEME'S colours, not the active one -- that is the point.
    color: root.theme.bg
    border.width: root.current ? 2 : 1
    border.color: root.current ? Theme.accent : Theme.wash(Theme.border, 0.4)

    Behavior on border.color {
        enabled: !Appearance.motionless
        ColorAnimation { duration: Appearance.durationNormal }
    }

    scale: mouse.pressed ? 0.97 : (mouse.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationFast
            easing.type: Appearance.easeStandard
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.sm
        spacing: Appearance.sm

        Row {
            spacing: Appearance.xs
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: [root.theme.a1, root.theme.a2, root.theme.a3]

                Rectangle {
                    required property var modelData
                    width: 18
                    height: 18
                    radius: 9
                    color: modelData
                }
            }
        }

        Text {
            width: parent.width
            text: root.theme.label
            // The theme's own text colour on the theme's own background, so a
            // swatch that would be unreadable is visibly unreadable here.
            color: root.theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            font.weight: root.current ? Appearance.weightMedium : Appearance.weightNormal
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    // Progress veil while theme-switch runs. It takes a couple of seconds --
    // it reloads waybar, mako and Hyprland -- and an unresponsive-looking grid
    // during that is how you end up clicking a second theme.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.bg
        opacity: root.busy ? 0.55 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationFast }
        }

        Icon {
            anchors.centerIn: parent
            name: "refresh"
            size: Appearance.iconSize
            color: Theme.accent

            RotationAnimator on rotation {
                running: root.busy && !Appearance.motionless
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 1200
            }
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
