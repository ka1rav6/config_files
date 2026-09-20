import QtQuick
import qs

// =============================================================================
// Button — text and/or icon, with the shell's standard press feel.
// =============================================================================
// Three variants, and no component may invent a fourth:
//   "ghost"   transparent until hovered — toolbar and list actions
//   "soft"    a tinted ground — the default
//   "accent"  filled with the accent — the one primary action in a panel
//   "danger"  filled with the error colour — destructive, used sparingly
//
// The press animation is a 4% scale-down rather than a colour flash. Scale is
// a transform, so it is free on the GPU and, unlike a colour change, it reads
// identically against every one of the nine themes.
// =============================================================================

FocusScope {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "soft"       // ghost | soft | accent | danger
    property bool enabled: true
    property bool busy: false

    signal clicked()

    readonly property bool iconOnly: root.text === "" && root.icon !== ""

    readonly property color groundColor: {
        switch (root.variant) {
        case "accent": return Theme.accent;
        case "danger": return Theme.error;
        case "ghost": return "transparent";
        default: return Theme.wash(Theme.text, 0.07);
        }
    }

    readonly property color labelColor: {
        if (root.variant === "accent") return Theme.onAccent(Theme.accent);
        if (root.variant === "danger") return Theme.onAccent(Theme.error);
        return Theme.text;
    }

    implicitHeight: Appearance.controlHeight
    implicitWidth: root.iconOnly
        ? Appearance.controlHeight
        : row.implicitWidth + Appearance.lg * 2

    activeFocusOnTab: root.enabled
    Keys.onSpacePressed: if (root.enabled) root.clicked()
    Keys.onReturnPressed: if (root.enabled) root.clicked()

    Rectangle {
        id: ground

        anchors.fill: parent
        radius: Appearance.radiusInner
        color: root.groundColor
        opacity: root.enabled ? 1 : 0.4

        // Hover is a brightening wash laid over the ground, rather than a
        // second colour to keep in step per variant.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.text
            opacity: mouse.containsMouse && root.enabled ? 0.08 : 0

            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }

        border.width: root.variant === "ghost" && root.activeFocus ? 1 : 0
        border.color: Theme.accent

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationNormal }
        }
    }

    scale: mouse.pressed && root.enabled ? 0.96 : 1.0
    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationFast
            easing.type: Appearance.easeStandard
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: root.iconOnly ? 0 : Appearance.sm

        Icon {
            visible: root.icon !== ""
            name: root.icon === "" ? "info" : root.icon
            size: Appearance.iconSize
            color: root.labelColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: root.labelColor
            font.family: Appearance.font
            font.pixelSize: Appearance.fontLabel
            font.weight: Appearance.weightMedium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
