import QtQuick
import qs

// =============================================================================
// CmdDragGrid — a reorderable grid of CmdTiles, and the owner of the drag.
// =============================================================================
// Used twice: once for the Quick Actions, once for the category cards. Both are
// hand-ordered lists persisted in settings.json, and this is the one place that
// knows how to turn a pointer position back into a list index.
//
// WHY THE POSITIONS ARE ARITHMETIC AND NOT A LAYOUT
//   * A Flow or Grid positions its children itself, so a tile cannot be moved
//     without fighting the layout for its x and y.
//   * A GridView needs a QAbstractItemModel to reorder, and the order lives in
//     a JSON array in settings.json. Wrapping that in a model just to get a
//     move() the view understands is more machinery than the twenty lines
//     below.
//
// So positions are computed from the index, every tile is a plain Item at an
// x/y, and `Behavior on x`/`on y` in CmdTile animates them. Dropping rewrites
// the array in Settings, the array re-reads, the indices change, and every tile
// glides to its new slot. The animation falls out of the data model rather than
// having to be choreographed -- and because the array is what persists, the
// layout you see is by definition the layout that was saved.
//
// WHAT A DROP MEANS
//   The dragged tile's top-left becomes a row and a column, that becomes a
//   target index, and the owner splices its list. Splice, not swap: dragging a
//   tile three places along should push the three it passed over back by one,
//   not scatter them.
//
// THE LIVE PREVIEW
//   `restingSlot` applies exactly the same splice the drop will perform, to
//   every OTHER tile, continuously. So the gap opens under the cursor before
//   you let go, and what you see is what you get. Without it you are dropping
//   blind and the result is a surprise about half the time.
// =============================================================================

Item {
    id: root

    // [command] or [category] -- whatever CmdTile's variant expects.
    required property var model

    property string variant: "action"

    property int minCellWidth: 168
    property int cellHeight: Appearance.compact ? 54 : 60

    signal activate(var payload)
    signal move(int from, int to)

    // Recomputed from the available width rather than fixed, so this survives
    // a density change, a font-scale change and a different panel width.
    readonly property int columns: Math.max(1, Math.floor(
        (root.width + Appearance.gap) / (root.minCellWidth + Appearance.gap)))

    readonly property real cellWidth: root.columns > 0
        ? (root.width - Appearance.gap * (root.columns - 1)) / root.columns
        : root.width

    readonly property int rows: Math.ceil(root.model.length / Math.max(1, root.columns))

    implicitHeight: root.model.length === 0
        ? 0
        : root.rows * root.cellHeight + Math.max(0, root.rows - 1) * Appearance.gap

    Behavior on implicitHeight {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationNormal
            easing.type: Appearance.easeStandard
        }
    }

    // --- drag state -----------------------------------------------------

    // Index of the tile in the air, or -1.
    property int draggedIndex: -1
    // The slot it would land in, updated continuously.
    property int targetIndex: -1

    function slotX(i) {
        return (i % root.columns) * (root.cellWidth + Appearance.gap);
    }

    function slotY(i) {
        return Math.floor(i / root.columns) * (root.cellHeight + Appearance.gap);
    }

    // Turn a pixel position back into a slot.
    //
    // Math.round, not Math.floor. With floor, a tile dragged one place to the
    // RIGHT can never land: its top-left is still inside its own cell when you
    // let go, so the target is always its own index and the drop is a no-op.
    // Rounding means the tile takes the slot it is more than halfway into,
    // which is what the gesture looks like it is doing.
    function slotAt(x, y) {
        const col = Math.round(x / (root.cellWidth + Appearance.gap));
        const row = Math.round(y / (root.cellHeight + Appearance.gap));
        const c = Math.max(0, Math.min(root.columns - 1, col));
        const r = Math.max(0, Math.min(Math.max(0, root.rows - 1), row));
        return Math.max(0, Math.min(root.model.length - 1, r * root.columns + c));
    }

    // Where tile `i` rests, given that `draggedIndex` is on its way to
    // `targetIndex`. The same splice the drop performs, applied as a preview.
    function restingSlot(i) {
        if (root.draggedIndex === -1 || root.targetIndex === -1) return i;
        if (i === root.draggedIndex) return root.targetIndex;
        if (root.draggedIndex < root.targetIndex)
            return (i > root.draggedIndex && i <= root.targetIndex) ? i - 1 : i;
        return (i >= root.targetIndex && i < root.draggedIndex) ? i + 1 : i;
    }

    // --- tiles ----------------------------------------------------------
    Repeater {
        // [{ i, item }] rather than the bare list: the position travels inside
        // modelData because the `index` a Repeater injects is NOT reliable
        // here. See the long note on CommandRegistry.enumerate() -- every tile
        // read index 0 and they rendered stacked.
        model: CommandRegistry.enumerate(root.model)

        CmdTile {
            id: tile

            required property var modelData

            readonly property int slot: tile.modelData.i

            payload: tile.modelData.item
            variant: root.variant

            width: root.cellWidth
            height: root.cellHeight

            dragging: root.draggedIndex === tile.slot

            // The binding stays in charge of the resting position; the drag
            // only contributes an offset. See the header of CmdTile.qml for
            // why this must not be `x: <written by the drag>`.
            x: root.slotX(root.restingSlot(tile.slot)) + tile.dragOffsetX
            y: root.slotY(root.restingSlot(tile.slot)) + tile.dragOffsetY

            onActivated: root.activate(tile.payload)

            onDragStarted: {
                root.draggedIndex = tile.slot;
                root.targetIndex = tile.slot;
            }

            onDragMoved: (x, y) => {
                // Offset = where the pointer has put the tile, minus where its
                // binding would otherwise rest it. So the tile tracks the
                // cursor exactly while the binding survives.
                tile.dragOffsetX = x - root.slotX(root.restingSlot(tile.slot));
                tile.dragOffsetY = y - root.slotY(root.restingSlot(tile.slot));
                root.targetIndex = root.slotAt(x, y);
            }

            onDragEnded: {
                const from = root.draggedIndex;
                const to = root.targetIndex;

                // Clear the offset FIRST, so the tile animates from where the
                // cursor left it into its new slot rather than teleporting.
                tile.dragOffsetX = 0;
                tile.dragOffsetY = 0;
                root.draggedIndex = -1;
                root.targetIndex = -1;

                if (from !== -1 && to !== -1 && from !== to) root.move(from, to);
            }
        }
    }
}
