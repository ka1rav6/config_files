import QtQuick
import qs

// =============================================================================
// PageHeader — the title line at the top of every drawer page.
// =============================================================================
// A large title, a muted one-line subtitle under it, and an optional slot on
// the right for a page-level control (a switch, a button). One component so
// every page starts at the same height and the page transition reads as the
// content changing under a fixed frame rather than the whole layout jumping.
// =============================================================================

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias trailing: slot.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(textColumn.implicitHeight, slot.childrenRect.height)

    Column {
        id: textColumn

        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: Appearance.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.size(26)
            font.weight: Appearance.weightBold
            font.letterSpacing: Appearance.trackingHeading
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            elide: Text.ElideRight
        }
    }

    Item {
        id: slot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
