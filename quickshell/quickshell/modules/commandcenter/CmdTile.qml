import QtQuick
import qs

// =============================================================================
// CmdTile — a draggable tile. The Quick Actions and the category cards.
// =============================================================================
// One component for both, because they are the same object at two sizes: an
// icon, a label, a sub-label, a click, and a grab handle. Writing them as two
// components meant writing the drag threshold, the offset dance and the
// press-versus-drag disambiguation twice, and that is exactly the code you do
// not want two copies of.
//
//   variant: "action"    a Quick Action. Fills with the accent when its
//                        command is on, so the grid doubles as a status strip.
//   variant: "category"  a category card. Shows how many commands are inside
//                        and the one status line that best represents it.
//
// -----------------------------------------------------------------------------
// DRAG AND DROP
//
// Reordering is the one place in this panel where dragging is the natural
// gesture rather than a novelty: the order of these tiles IS the user's
// layout, it is hand-made rather than sorted, and there is no sensible
// non-drag interface for "put this one first". Both grids persist their order
// (Settings.commands.favourites and .order), so it survives a shell restart
// and a reboot.
//
// WHY NOT DragHandler / DropArea
//   A DropArea per tile means N drop zones, each of which has to be told about
//   the others to know which way to shuffle. Instead the tile reports its
//   pointer position to the grid, which already computes every tile's geometry
//   from its index, and the grid decides which slot that lands in. One owner of
//   the layout, one place the arithmetic lives, and the tiles stay independent
//   of each other -- see CmdDragGrid.qml.
//
// WHY THE TILE KEEPS ITS BINDING AND MOVES BY AN OFFSET
//   The drag does NOT write x and y. In QML, assigning to a property destroys
//   its binding permanently -- so a tile dragged once would be severed from the
//   layout for the rest of the session and would never find a slot again.
//   (modules/widgets/DesktopWidget.qml carries the same warning; for free
//   positioning that severance is what is wanted, here it is not.) Instead the
//   grid adds `dragOffsetX/Y` on top of the position the binding computes. When
//   the offset returns to zero the tile glides home on its own Behavior, with
//   no special case and no cleanup.
//
// THE PRESS THRESHOLD IS LOAD-BEARING
//   A tile is a BUTTON first. Qt's default drag threshold would start a drag on
//   a few pixels of touchpad twitch during a click, so a tap meant as "turn
//   night light on" would come out as a two-pixel reorder and nothing would
//   happen. The drag only arms once the pointer has actually travelled
//   `dragThreshold`, and a release before that is unambiguously a click. That
//   is the difference between drag-and-drop that feels polished and
//   drag-and-drop that eats your clicks.
// -----------------------------------------------------------------------------

Item {
    id: root

    // A registry command (variant "action") or a category (variant "category").
    required property var payload

    // NO `index` PROPERTY HERE, DELIBERATELY.
    //
    // `index` is the name a Repeater injects into its delegate. Declaring it on
    // this type as well means the delegate redeclares a name the type already
    // has, the injection has nowhere to land, and the delegate fails to
    // construct at all -- "Required property index was not initialized",
    // "Cannot create delegate", and a Quick Actions grid that is simply empty
    // with no error on the page. The grid's delegate declares it instead, where
    // the injection can reach it; nothing in this file ever needed it.

    property string variant: "action"

    // Set by the grid while THIS tile is the one in the air.
    property bool dragging: false

    // Added on top of the grid's computed slot position. See the header.
    property real dragOffsetX: 0
    property real dragOffsetY: 0

    readonly property int dragThreshold: 8

    signal activated()
    signal dragStarted()
    // Pointer position in the GRID's coordinates, continuously while dragging.
    signal dragMoved(real x, real y)
    signal dragEnded()

    readonly property bool isAction: root.variant === "action"

    // --- what to draw ---------------------------------------------------

    readonly property bool isToggle: root.isAction && root.payload.ui === "toggle"

    readonly property bool on: root.isToggle
        && CommandState.states[root.payload.state] === true

    readonly property bool busy: root.isAction && CommandState.isBusy(root.payload)

    // A pinned toggle whose service cannot act is drawn dimmed rather than as
    // a cheerful "Off". Night light on this machine is the live example: the
    // compositor runs with AQ_NO_ATOMIC=1 (legacy DRM, no gamma), so wlsunset
    // can never apply anything and services/NightLight.qml reports it
    // unavailable. A tile identical to a working one would make a click that
    // does nothing look like a click that did something -- CmdRow.qml dims for
    // the same reason, and its status line carries the whole explanation.
    readonly property bool unavailable: root.isToggle
        && CommandState.enabled[root.payload.state] === false

    readonly property string tileIconName: root.payload.icon

    readonly property string tileLabel: root.isAction ? root.payload.name : root.payload.label

    readonly property string tileDetail: {
        if (!root.isAction) {
            const n = CommandRegistry.countIn(root.payload.id);
            return n + (n === 1 ? " command" : " commands");
        }
        if (root.isToggle)
            return root.unavailable ? "Unavailable" : (root.on ? "On" : "Off");
        if (root.payload.ui === "select") return CommandState.labelForValue(root.payload);
        return "";
    }

    // A category card's second line is the most informative status of any
    // command inside it, so the home page reads as a dashboard rather than as
    // a menu. First match wins, and the registry's order inside a category is
    // "most worth knowing first", so this needs no ranking of its own.
    readonly property var categoryState: {
        if (root.isAction) return null;
        for (const cmd of CommandRegistry.inCategory(root.payload.id)) {
            const s = CommandState.statusFor(cmd);
            if (s) return s;
        }
        return null;
    }

    readonly property color tint: {
        if (!root.isAction) return Theme.accent;
        switch (root.payload.safety) {
        case "danger": return Theme.error;
        case "confirm": return Theme.warning;
        default: return Theme.accent;
        }
    }

    readonly property color fg: root.on ? Theme.onAccent(root.tint) : Theme.text

    // Lifted above its siblings while held, so it passes over them.
    z: root.dragging ? 10 : 0

    // Dimmed but still draggable while unavailable -- it is the user's layout
    // and they may well want to move it out of the way, which a dead tile
    // would not let them do.
    opacity: root.unavailable ? 0.45 : 1

    Behavior on opacity {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.durationNormal }
    }

    // --- ground ---------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: Appearance.radiusInner

        color: root.on ? root.tint
             : root.isAction ? Theme.wash(Theme.text, 0.06)
             : Theme.wash(Theme.surface2, 0.55)

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation {
                duration: Appearance.durationNormal
                easing.type: Appearance.easeStandard
            }
        }

        // An accent outline while this tile is the one in the air, so it is
        // obvious which one is being moved once several have shuffled.
        //
        // Otherwise a hairline on every resting tile, action and category
        // alike -- they sit in the same grid and one having an edge while the
        // other did not made the two bands read as different materials. A
        // tile that is switched ON drops the border: it is already a filled
        // accent shape and an outline on top of that reads as a mistake.
        border.width: root.dragging ? 1 : (root.on ? 0 : 1)
        border.color: root.dragging ? Theme.wash(Theme.accent, 0.9)
                                    : Theme.wash(Theme.border, 0.3)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.text
            opacity: mouse.containsMouse && !root.dragging ? 0.07 : 0

            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }
    }

    // Grows slightly while held, so it reads as picked up; shrinks on a plain
    // press, like every other button in the shell.
    scale: root.dragging ? 1.04 : (mouse.pressed ? 0.97 : 1.0)

    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationFast
            easing.type: Appearance.easeStandard
        }
    }

    // The resting position animates; the dragged one must not, or the tile
    // lags behind the cursor.
    Behavior on x {
        enabled: !Appearance.motionless && !root.dragging
        NumberAnimation {
            duration: Appearance.durationNormal
            easing.type: Appearance.easeStandard
        }
    }

    Behavior on y {
        enabled: !Appearance.motionless && !root.dragging
        NumberAnimation {
            duration: Appearance.durationNormal
            easing.type: Appearance.easeStandard
        }
    }

    // --- action layout: icon beside the label ---------------------------
    Item {
        anchors.fill: parent
        visible: root.isAction

        Icon {
            id: actionIcon

            name: root.tileIconName
            size: Appearance.iconSize
            color: root.fg
            anchors.left: parent.left
            anchors.leftMargin: Appearance.md
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationNormal }
            }

            // A slow pulse while in flight. Calmer than a spinner, and one
            // opacity animation is free on the GPU.
            SequentialAnimation on opacity {
                running: root.busy && !Appearance.motionless
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.35; duration: 620; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
            }
        }

        Column {
            anchors.left: actionIcon.right
            anchors.leftMargin: Appearance.sm
            anchors.right: parent.right
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.tileLabel
                color: root.fg
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                font.weight: Appearance.weightMedium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.tileDetail !== ""
                text: root.tileDetail
                // Muted grey on an accent-filled tile would fail contrast, so
                // an active tile reduces the foreground's opacity rather than
                // changing its colour. Same device as ui/QuickTile.qml.
                color: root.fg
                opacity: root.on ? 0.75 : 0.6
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                elide: Text.ElideRight
            }
        }
    }

    // --- category layout: icon above the label --------------------------
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.md
        visible: !root.isAction
        spacing: Appearance.xs

        Row {
            width: parent.width
            spacing: Appearance.sm

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.tileIconName
                size: Appearance.iconSize
                color: Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Appearance.iconSize * 1.25 - Appearance.sm
                text: root.tileLabel
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontLabel
                font.weight: Appearance.weightSemi
                elide: Text.ElideRight
            }
        }

        Text {
            width: parent.width
            text: root.payload.desc !== undefined ? root.payload.desc : ""
            color: Theme.muted
            opacity: 0.8
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // The card's live readout: a dot, the status, and the count.
        Row {
            width: parent.width
            spacing: Appearance.xs + 2

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.categoryState !== null
                width: 6
                height: 6
                radius: 3
                color: root.categoryState
                    ? CommandState.toneColour(root.categoryState.tone) : Theme.muted

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationNormal }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 12
                text: root.categoryState
                    ? root.categoryState.text
                    : root.tileDetail
                color: root.categoryState && root.categoryState.tone !== "idle"
                    ? CommandState.toneColour(root.categoryState.tone)
                    : Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                elide: Text.ElideRight
            }
        }
    }

    // --- interaction ----------------------------------------------------
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        // Grab origin, in this tile's own coordinates, so the tile keeps the
        // same point under the cursor for the whole gesture rather than
        // snapping its top-left to the pointer on the first frame.
        property real pressX: 0
        property real pressY: 0
        property bool armed: false

        onPressed: (event) => {
            mouse.pressX = event.x;
            mouse.pressY = event.y;
            mouse.armed = false;
        }

        onPositionChanged: (event) => {
            if (!mouse.pressed) return;

            if (!mouse.armed) {
                const dx = event.x - mouse.pressX;
                const dy = event.y - mouse.pressY;
                if (Math.sqrt(dx * dx + dy * dy) < root.dragThreshold) return;
                mouse.armed = true;
                root.dragStarted();
            }

            // Report where the tile's TOP-LEFT now is, in the grid's
            // coordinates -- so the slot being targeted is the one the tile is
            // over, not the one the fingertip is over.
            const p = root.mapToItem(root.parent,
                                     event.x - mouse.pressX,
                                     event.y - mouse.pressY);
            root.dragMoved(p.x, p.y);
        }

        onReleased: {
            if (mouse.armed) {
                mouse.armed = false;
                root.dragEnded();
            } else {
                root.activated();
            }
        }

        // A drag that leaves the window, or a press cancelled because the
        // panel closed, must still put the tile down -- otherwise the grid is
        // left believing something is still in the air and every other tile
        // holds its shuffled position.
        onCanceled: {
            if (mouse.armed) {
                mouse.armed = false;
                root.dragEnded();
            }
        }
    }
}
