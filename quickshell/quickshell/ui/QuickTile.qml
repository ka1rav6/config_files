import QtQuick
import qs

// =============================================================================
// QuickTile — the big on/off tile in the Control Center.
// =============================================================================
// Two targets in one control, which is what makes a quick-settings panel feel
// quick rather than fiddly:
//
//   the tile body    toggles the thing         (Wi-Fi on/off)
//   the chevron      opens its detail page     (pick a network)
//
// Both are optional: a tile with no `expandable` is a plain toggle, and a tile
// with no `toggled` handler is a plain navigation row.
//
// The active state is a filled accent ground rather than a small indicator
// light. At a glance across four tiles you should be able to read what is on
// without focusing on any of them, and filled-vs-empty is the strongest signal
// available that survives every theme.
// =============================================================================

Item {
    id: root

    property string icon: "info"
    property string label: ""
    property string detail: ""
    property bool active: false
    property bool enabled: true
    property bool expandable: false
    property bool busy: false

    signal toggled()
    signal expand()

    implicitHeight: Appearance.compact ? 62 : 70

    Rectangle {
        id: ground

        anchors.fill: parent
        radius: Appearance.radiusInner
        color: root.active ? Theme.accent : Theme.wash(Theme.text, 0.06)
        opacity: root.enabled ? 1 : 0.45

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation {
                duration: Appearance.durationNormal
                easing.type: Appearance.easeStandard
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.text
            opacity: body.containsMouse && root.enabled ? 0.07 : 0
            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }
    }

    readonly property color fg: root.active ? Theme.onAccent(Theme.accent) : Theme.text

    scale: body.pressed && root.enabled ? 0.97 : 1.0
    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.durationFast }
    }

    Icon {
        id: tileIcon

        name: root.icon
        size: Appearance.iconSizeLarge
        color: root.fg
        anchors.left: parent.left
        anchors.leftMargin: Appearance.md
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationNormal }
        }

        // A slow pulse while a connection is in progress. Cheaper and calmer
        // than a spinner, and it stops the tile looking frozen while BlueZ
        // takes its time pairing.
        SequentialAnimation on opacity {
            running: root.busy && !Appearance.motionless
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    Column {
        anchors.left: tileIcon.right
        anchors.leftMargin: Appearance.sm
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: Appearance.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            color: root.fg
            font.family: Appearance.font
            font.pixelSize: Appearance.fontLabel
            font.weight: Appearance.weightMedium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            // Muted text on an accent ground would fail contrast, so on an
            // active tile the subtitle uses the same foreground at reduced
            // opacity instead of a different colour.
            color: root.fg
            opacity: root.active ? 0.72 : 0.6
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            elide: Text.ElideRight
        }
    }

    // --- toggle half ---------------------------------------------------
    MouseArea {
        id: body

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: chevron.visible ? chevron.left : parent.right
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    // --- detail half ---------------------------------------------------
    Item {
        id: chevron

        visible: root.expandable
        width: visible ? Appearance.touchTarget : 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 6
            height: parent.height - 10
            radius: Appearance.radiusSmall
            color: Theme.text
            opacity: chevronMouse.containsMouse ? 0.1 : 0
            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "chevron-right"
            size: Appearance.iconSize
            color: root.fg
            opacity: 0.8
        }

        MouseArea {
            id: chevronMouse

            anchors.fill: parent
            enabled: root.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expand()
        }
    }
}
