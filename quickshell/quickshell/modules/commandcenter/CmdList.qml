import QtQuick
import qs

// =============================================================================
// CmdList — a list of commands. Search results, and a category's page.
// =============================================================================
// One component for both, because they are the same thing with a different
// filter: a heading, a back affordance where there is somewhere to go back to,
// and a column of CmdRows. Keeping them one component is what guarantees that
// a command reached by searching and the same command reached by browsing look
// and behave identically -- which matters, because the whole promise of the
// panel is that you do not have to remember which route you took last time.
//
// `selectedIndex` is driven from the panel, not from hover. Hover and the
// keyboard cursor are deliberately separate states: moving the mouse across the
// panel on its way somewhere else must not move the thing that Return will act
// on. The Control Center and the launcher make the same distinction.
// =============================================================================

Column {
    id: root

    required property var commands

    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    property bool showCategory: false

    // -1 for "nothing is selected", which is the correct state for a list the
    // user is reading with the mouse rather than driving with the keyboard.
    property int selectedIndex: -1

    signal back()
    signal activate(var command)
    signal expand(var command)

    spacing: Appearance.md

    // --- heading --------------------------------------------------------
    Item {
        width: parent.width
        visible: root.title !== ""
        // controlHeight, not touchTarget: the back button is a Button and
        // Button is controlHeight tall, so sizing this to touchTarget (40 vs
        // 44) left it overhanging the heading by 2 px at each end.
        implicitHeight: Math.max(headingText.implicitHeight, Appearance.controlHeight)

        Button {
            id: backButton

            visible: root.showBack
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron-left"
            variant: "ghost"
            onClicked: root.back()
        }

        Column {
            id: headingText

            anchors.left: root.showBack ? backButton.right : parent.left
            anchors.leftMargin: root.showBack ? Appearance.sm : 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.title
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontTitle
                font.weight: Appearance.weightSemi
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
    }

    // --- rows -----------------------------------------------------------
    Card {
        width: parent.width
        visible: root.commands.length > 0
        elevation: 0
        implicitHeight: rows.implicitHeight + Appearance.md * 2

        Column {
            id: rows

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: 0

            Repeater {
                // Positions carried inside modelData -- the injected `index`
                // is 0 for every delegate here. See CommandRegistry.enumerate().
                // Left unfixed this silently kept the keyboard cursor painted
                // on row 0 whatever the arrow keys did.
                model: CommandRegistry.enumerate(root.commands)

                CmdRow {
                    id: listRow

                    required property var modelData

                    width: rows.width
                    command: listRow.modelData.item
                    selected: root.selectedIndex === listRow.modelData.i
                    showCategory: root.showCategory
                    // No rule under the last row -- it would sit just inside
                    // the card's own bottom edge and read as a double border.
                    showSeparator: listRow.modelData.i < root.commands.length - 1

                    onActivated: root.activate(listRow.modelData.item)
                    onExpand: root.expand(listRow.modelData.item)
                }
            }
        }
    }

    // --- nothing found --------------------------------------------------
    Column {
        width: parent.width
        visible: root.commands.length === 0
        spacing: Appearance.xs

        Text {
            width: parent.width
            text: "No commands match"
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontBody
            font.weight: Appearance.weightMedium
        }

        // Says what the panel is for, rather than just that it failed. The
        // honest answer to an unmatched search here is often "that is a CLI
        // command on purpose", and the user should not have to guess which.
        Text {
            width: parent.width
            text: "This panel is a curated set of commands, not a shell. Anything taking an argument only you can supply — `just restore`, `just add`, `just phone-send` — stays on the command line deliberately; see the notes at the top of CommandRegistry.qml."
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            wrapMode: Text.WordWrap
        }
    }

    Item {
        width: parent.width
        height: Appearance.md
    }
}
