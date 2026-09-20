import QtQuick
import qs

// Page header: a back arrow, a title, and an optional action on the right.
// Every sub-page uses this, so "back" is always the same size in the same
// place -- which is what lets you leave a page without looking at the panel.
Item {
    id: root

    property string title: ""
    property bool showBack: true
    default property alias action: actionSlot.data

    signal back()

    implicitHeight: Appearance.controlHeight

    Button {
        id: backButton

        visible: root.showBack
        width: visible ? Appearance.controlHeight : 0
        height: Appearance.controlHeight
        variant: "ghost"
        icon: "chevron-left"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.back()
    }

    Text {
        anchors.left: root.showBack ? backButton.right : parent.left
        anchors.leftMargin: root.showBack ? Appearance.sm : 0
        anchors.right: actionSlot.left
        anchors.rightMargin: Appearance.sm
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.text
        font.family: Appearance.font
        font.pixelSize: Appearance.fontTitle
        font.weight: Appearance.weightSemi
        font.letterSpacing: Appearance.trackingHeading
        elide: Text.ElideRight
    }

    Item {
        id: actionSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
