import QtQuick
import qs

// A titled group of settings, drawn as a card. Grouping is what makes a long
// settings page scannable -- an undifferentiated list of forty rows is not.
Column {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias rows: inner.data

    spacing: Appearance.sm

    Column {
        width: parent.width
        spacing: 1
        visible: root.title !== ""

        Text {
            text: root.title
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            font.weight: Appearance.weightMedium
            font.letterSpacing: Appearance.trackingLabel
        }

        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.muted
            opacity: 0.75
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
        }
    }

    Card {
        width: parent.width
        elevation: 0
        implicitHeight: inner.implicitHeight + Appearance.md * 2

        Column {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: 0
        }
    }
}
