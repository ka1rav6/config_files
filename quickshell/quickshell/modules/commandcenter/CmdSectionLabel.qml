import QtQuick
import qs

// =============================================================================
// CmdSectionLabel — the small caps heading over a band.
// =============================================================================
// Matches modules/settings/SettingsGroup.qml's title treatment exactly (muted,
// fontCaption, trackingLabel) so the two surfaces read as the same product.
// It is not a copy of SettingsGroup: that one wraps its rows in a Card, and
// the bands here are a grid and a list rather than a stack of SettingRows.
//
// The optional `hint` on the right is where an affordance is announced --
// "drag to reorder" is not discoverable otherwise, and a drag gesture nobody
// knows about is a feature that does not exist. It is deliberately quiet: once
// learned it should fade into the layout rather than keep instructing.
// =============================================================================

Item {
    id: root

    property string text: ""
    property string hint: ""
    property string action: ""

    signal actionClicked()

    implicitHeight: label.implicitHeight

    Text {
        id: label

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.muted
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
        font.weight: Appearance.weightMedium
        font.letterSpacing: Appearance.trackingLabel
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hint !== "" && root.action === ""
        text: root.hint
        color: Theme.muted
        opacity: 0.55
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
    }

    Text {
        id: actionLabel

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.action !== ""
        text: root.action
        color: actionMouse.containsMouse ? Theme.accent : Theme.muted
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
        font.weight: Appearance.weightMedium

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }

        MouseArea {
            id: actionMouse

            // Padded out beyond the text: a caption-sized click target is
            // unusable on a touchpad and impossible on a touchscreen, and this
            // is a convertible.
            anchors.centerIn: parent
            width: parent.implicitWidth + Appearance.md
            height: Appearance.touchTarget
            enabled: root.action !== ""
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }
    }
}
