import QtQuick
import qs

// =============================================================================
// SettingRow — label, description, and a control on the right.
// =============================================================================
// Every setting in the app is one of these, which is what stops the pages
// drifting into different layouts. The control slot takes anything: a Toggle,
// a Slider, a Button, a row of choices.
//
// The description is not decoration. A setting whose effect is not obvious from
// its name gets one, because the alternative is the user flipping it to find
// out -- and some of these cost battery.
// =============================================================================

Item {
    id: root

    property string label: ""
    property string description: ""
    property bool enabled: true

    default property alias control: controlSlot.data

    implicitHeight: Math.max(textColumn.implicitHeight, controlSlot.implicitHeight) + Appearance.sm * 2

    opacity: root.enabled ? 1 : 0.45
    Behavior on opacity {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.durationNormal }
    }

    Column {
        id: textColumn

        anchors.left: parent.left
        anchors.right: controlSlot.left
        anchors.rightMargin: Appearance.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.label
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontBody
            font.weight: Appearance.weightMedium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: controlSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
