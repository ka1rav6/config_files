import QtQuick
import Quickshell
import qs

// One dock tile: icon, hover magnification, and a running indicator.
//
// The magnification is a scale transform on the icon, not a size change on the
// layout. Animating `width` would relayout the whole row on every frame of the
// hover; animating `scale` is a GPU transform that costs nothing and does not
// disturb its neighbours.
Item {
    id: root

    required property var item

    signal activated()
    signal contextRequested()

    readonly property bool running: !!root.item.live
    readonly property int windowCount: root.item.live ? root.item.live.count : 0
    readonly property string label: root.item.entry ? root.item.entry.name : ""

    width: Settings.dock.iconSize
    height: Settings.dock.iconSize

    Image {
        id: icon

        anchors.centerIn: parent
        width: Settings.dock.iconSize - 4
        height: width

        source: root.item.entry
            ? Quickshell.iconPath(root.item.entry.icon, "application-x-executable")
            : ""
        // Decode at magnified size so a scaled-up icon stays crisp.
        sourceSize.width: Settings.dock.iconSize * 2
        sourceSize.height: Settings.dock.iconSize * 2
        asynchronous: true
        smooth: true

        scale: {
            if (!Settings.dock.magnify) return mouse.pressed ? 0.92 : 1.0;
            if (mouse.pressed) return Settings.dock.magnifyScale * 0.92;
            return mouse.containsMouse ? Settings.dock.magnifyScale : 1.0;
        }

        // Grow from the bottom, so a magnified icon rises out of the dock
        // instead of pushing through its floor.
        transformOrigin: Item.Bottom

        Behavior on scale {
            enabled: !Appearance.motionless
            NumberAnimation {
                duration: Appearance.durationNormal
                easing.type: Appearance.easeEmphasised
                easing.overshoot: Appearance.overshoot
            }
        }
    }

    // Running indicator: one dot, or a short bar for several windows.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -Appearance.xs
        width: root.windowCount > 1 ? 12 : 4
        height: 4
        radius: 2
        color: Theme.accent
        opacity: root.running ? 1 : 0

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationNormal }
        }
        Behavior on width {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationNormal }
        }
    }

    // Tooltip. Positioned above the dock, fading in after a beat so sweeping
    // across the dock does not flash six labels.
    Rectangle {
        id: tooltip

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Appearance.md

        width: tooltipText.implicitWidth + Appearance.md * 2
        height: tooltipText.implicitHeight + Appearance.sm * 2
        radius: Appearance.radiusSmall
        color: Theme.card(0.95)
        border.width: 1
        border.color: Theme.wash(Theme.border, 0.4)

        opacity: mouse.containsMouse ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation {
                duration: Appearance.durationNormal
                easing.type: Appearance.easeStandard
            }
        }

        Text {
            id: tooltipText

            anchors.centerIn: parent
            text: root.label + (root.windowCount > 1 ? "  (" + root.windowCount + ")" : "")
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (event) => {
            if (event.button === Qt.RightButton) root.contextRequested();
            else root.activated();
        }
    }
}
