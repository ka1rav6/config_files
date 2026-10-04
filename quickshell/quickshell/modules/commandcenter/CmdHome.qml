import QtQuick
import qs

// =============================================================================
// CmdHome — what you see with an empty search box.
// =============================================================================
// Three bands, in the order you are most likely to want them:
//
//   QUICK ACTIONS   the things you pinned. Toggles show their state, so this
//                   band is also the status strip -- one glance says whether
//                   night light is on and whether notifications are held.
//   CATEGORIES      everything else, grouped, each card carrying the one live
//                   readout that best represents what is inside it.
//   RECENT          the last few things you ran, because a command centre's
//                   most common request is "that again".
//
// Both grids are reorderable by dragging, and both orders persist. Recents are
// deliberately NOT reorderable: the order is "when you ran it", which is a
// fact rather than a preference, and a hand-sorted recents list is just a
// second favourites list.
//
// WHY THERE IS NO STATUS BAND
//   An earlier shape had a row of readouts across the top -- Wi-Fi, Bluetooth,
//   battery, theme. It was the fourth place on this desktop showing the same
//   four numbers (waybar has them, the Control Center has them, the dashboard
//   has them), and a panel that opens to tell you things you can already see
//   is a panel you stop opening. The status is attached to the commands it
//   belongs to instead, where it answers a question you are about to act on.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg

    signal activate(var command)
    signal openCategory(string id)

    // --- Quick Actions --------------------------------------------------
    Column {
        width: parent.width
        spacing: Appearance.sm

        CmdSectionLabel {
            width: parent.width
            text: "QUICK ACTIONS"
            hint: CommandRunner.favourites.length > 1 ? "drag to reorder" : ""
        }

        CmdDragGrid {
            width: parent.width
            visible: CommandRunner.favourites.length > 0
            model: CommandRunner.favouriteCommands
            variant: "action"
            // The SAME minimum as the category grid below, so both resolve to
            // the same column count and the two bands line up as one grid
            // rather than as two of different pitch. It is also what stops a
            // longer name truncating: at 168 the text column was 153 px and
            // "Re-derive palette from wallpaper" came out as "Re-derive
            // palette from w...".
            minCellWidth: 250
            cellHeight: Appearance.compact ? 54 : 60

            onActivate: (payload) => root.activate(payload)
            onMove: (from, to) => CommandRunner.moveFavourite(from, to)
        }

        Text {
            width: parent.width
            visible: CommandRunner.favourites.length === 0
            text: "Nothing pinned yet. Use the pin on any command's row, or press Ctrl+D with it selected."
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            wrapMode: Text.WordWrap
        }
    }

    // --- Categories -----------------------------------------------------
    Column {
        width: parent.width
        spacing: Appearance.sm

        CmdSectionLabel {
            width: parent.width
            text: "EVERYTHING"
            hint: "drag to reorder"
        }

        CmdDragGrid {
            width: parent.width
            model: CommandRunner.categoryOrder
            variant: "category"
            minCellWidth: 250
            cellHeight: Appearance.compact ? 92 : 102

            onActivate: (payload) => root.openCategory(payload.id)
            onMove: (from, to) => CommandRunner.moveCategory(from, to)
        }
    }

    // --- Recent ---------------------------------------------------------
    Column {
        width: parent.width
        visible: CommandRunner.recentCommands.length > 0
        spacing: Appearance.sm

        CmdSectionLabel {
            width: parent.width
            text: "RECENT"
            action: "Clear"
            onActionClicked: CommandRunner.clearRecent()
        }

        Card {
            width: parent.width
            elevation: 0
            implicitHeight: recentList.implicitHeight + Appearance.md * 2

            Column {
                id: recentList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.md
                spacing: 0

                Repeater {
                    id: recentRepeater

                    // Five is enough to cover "that again" and short enough
                    // that the categories above stay on screen. Enumerated
                    // because the injected `index` is 0 for every delegate --
                    // see CommandRegistry.enumerate().
                    readonly property var entries:
                        CommandRunner.recentCommands.slice(0, 5)

                    model: CommandRegistry.enumerate(recentRepeater.entries)

                    CmdRow {
                        id: recentRow

                        required property var modelData

                        width: recentList.width
                        command: recentRow.modelData.item
                        showCategory: true
                        showSeparator: recentRow.modelData.i
                            < recentRepeater.entries.length - 1

                        onActivated: root.activate(recentRow.modelData.item)
                        onExpand: root.activate(recentRow.modelData.item)
                    }
                }
            }
        }
    }

    // Trailing space, so the last row is not flush against the panel edge
    // when the content is scrolled to the bottom.
    Item {
        width: parent.width
        height: Appearance.md
    }
}
