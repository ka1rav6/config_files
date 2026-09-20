import QtQuick
import Quickshell
import qs

// =============================================================================
// DockMenu — the right-click menu on a dock tile.
// =============================================================================
// One menu instance per dock surface, re-pointed at whichever tile was clicked,
// rather than one menu per tile. A menu per tile would build six of these on
// every dock and put them inside the Row, where their width would stretch it.
//
// It sits above the dock and points at the tile it acts on. The dock's own mask
// goes full-surface while this is open (see Dock.qml), so a click anywhere else
// dismisses it instead of falling through into the window underneath.
// =============================================================================

Item {
    id: root

    required property var dock

    // The dock bar this menu hangs above. Anchoring to the real item rather
    // than computing a y from its height is deliberate: the arithmetic version
    // put the card at a negative y on a short surface, where it was laid out
    // correctly and clipped away to nothing. Anchors cannot do that silently.
    required property Item dockBar

    property bool open: false
    property var target: null
    property int targetIndex: -1
    property real targetX: 0

    anchors.fill: parent
    visible: root.open || card.opacity > 0.01

    function openFor(item, index, x) {
        root.target = item;
        root.targetIndex = index;
        root.targetX = x;
        root.open = true;
    }

    function close() { root.open = false; }

    readonly property bool targetPinned:
        !!(root.target && root.target.entry && root.dock.isPinned(root.target.entry.id))

    readonly property bool targetRunning: !!(root.target && root.target.live)

    // Only pinned tiles can be reordered: the running ones are ordered by the
    // compositor, and moving one would be a promise the dock cannot keep.
    readonly property int pinnedCount: (Settings.dock.pinned || []).length

    readonly property var entries: {
        if (!root.target) return [];
        const out = [];

        out.push({
            icon: root.targetPinned ? "close" : "pin",
            label: root.targetPinned ? "Unpin from dock" : "Pin to dock",
            act: "pin"
        });

        if (root.targetPinned && root.pinnedCount > 1) {
            const i = root.dock.pinnedIndex(root.target.entry.id);
            if (i > 0) out.push({ icon: "chevron-left", label: "Move left", act: "left" });
            if (i < root.pinnedCount - 1) out.push({ icon: "chevron-right", label: "Move right", act: "right" });
        }

        if (root.targetRunning) {
            out.push({ icon: "plus", label: "New window", act: "launch" });
            out.push({ icon: "close", label: root.target.live.count > 1
                ? "Close all windows" : "Close window", act: "close", danger: true });
        } else {
            out.push({ icon: "play", label: "Open", act: "launch" });
        }

        return out;
    }

    function run(act) {
        const item = root.target;
        root.close();
        if (!item) return;

        switch (act) {
        case "pin":    root.dock.togglePin(item); break;
        case "left":   root.dock.movePinned(item.entry.id, -1); break;
        case "right":  root.dock.movePinned(item.entry.id, 1); break;
        case "launch": if (item.entry) item.entry.execute(); break;
        case "close":  root.dock.closeAll(item); break;
        }
    }

    Card {
        id: card

        elevation: 2
        width: 208
        height: list.implicitHeight + Appearance.sm * 2

        // Centred on the tile, then clamped so a menu on the first or last
        // tile does not hang off the screen.
        x: Math.max(Appearance.screenMargin,
             Math.min(root.width - width - Appearance.screenMargin,
                      root.targetX - width / 2))

        // Sits directly above the dock bar, with the same gap the tooltips use.
        //
        // Anchored to THIS item's bottom rather than to dockBar.top, because
        // dockBar is a sibling of the menu, not of this card -- QML refuses to
        // anchor across that ("Cannot anchor to an item that isn't a parent or
        // sibling") and the anchor is silently dropped.
        //
        // The margin is still derived from the live dockBar rather than from
        // constants, so it cannot drift out of step with the dock's height,
        // and anchoring to parent.bottom guarantees the card stays inside the
        // surface -- which is the failure this replaces.
        //
        // The extra 10px while closed is the slide-down of the exit animation.
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (root.height - root.dockBar.y)
            + Appearance.md - (root.open ? 0 : 10)

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        transformOrigin: Item.Bottom

        Behavior on anchors.bottomMargin {
            enabled: !Appearance.motionless
            NumberAnimation {
                duration: Appearance.durationNormal
                easing.type: Appearance.easeEnter
            }
        }

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationFast }
        }

        Behavior on scale {
            enabled: !Appearance.motionless
            NumberAnimation {
                duration: Appearance.durationNormal
                easing.type: Appearance.easeEnter
            }
        }

        Column {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.sm
            spacing: 1

            // The app's own name, so a menu opened on the wrong tile is
            // obvious before you click something in it.
            Text {
                width: parent.width
                text: root.target && root.target.entry ? root.target.entry.name : ""
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                font.weight: Appearance.weightMedium
                font.letterSpacing: Appearance.trackingLabel
                elide: Text.ElideRight
                leftPadding: Appearance.sm
                bottomPadding: Appearance.xs
            }

            Repeater {
                model: root.entries

                Rectangle {
                    id: rowItem

                    required property var modelData

                    width: list.width
                    height: 34
                    radius: Appearance.radiusSmall
                    color: rowMouse.containsMouse
                        ? Theme.wash(modelData.danger ? Theme.error : Theme.accent, 0.16)
                        : "transparent"

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.sm

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: rowItem.modelData.icon
                            size: 15
                            color: rowItem.modelData.danger ? Theme.error
                                : rowMouse.containsMouse ? Theme.accent : Theme.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: rowItem.modelData.label
                            color: rowItem.modelData.danger ? Theme.error : Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontSmall
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(rowItem.modelData.act)
                    }
                }
            }
        }
    }
}
