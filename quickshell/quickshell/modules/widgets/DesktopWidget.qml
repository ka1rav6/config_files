import QtQuick
import qs

// =============================================================================
// DesktopWidget — the frame every desktop widget sits in.
// =============================================================================
// One component owns position, persistence and dragging, so the individual
// widgets are pure content and cannot each invent their own idea of how a
// desktop widget behaves.
//
// POSITION AND PERSISTENCE
//   Saved into Settings.desktop.widgetLayout as { x, y } fractions of the
//   screen, NOT pixels. Fractions survive plugging in a different monitor --
//   a widget parked at the top right of the laptop panel is still at the top
//   right of the 2560px one, instead of being stranded in the middle.
//
//   Writes are debounced: dragging emits a position change every frame, and
//   settings.json is not a scratchpad.
//
// EDIT MODE
//   Widgets are inert until the desktop is put into edit mode
//   (`quickshell ipc call widgets edit`). Outside it the whole surface is
//   click-through, so a widget can never eat a click meant for the desktop.
//   In edit mode each one lifts, grows a dashed outline and a grab handle, and
//   snaps to the grid while it moves.
// =============================================================================

Item {
    id: root

    // Stable key in the saved layout. Must not change between releases or the
    // user's arrangement is silently forgotten.
    required property string widgetId

    // Where it goes the first time it is ever shown, as screen fractions.
    property real defaultX: 0.04
    property real defaultY: 0.12

    property bool editing: false

    // Content sets these; the frame sizes itself to them.
    property int contentWidth: 240
    property int contentHeight: 120

    // Fractions are resolved against the surface, which is the whole output.
    readonly property var saved: {
        const layout = Settings.desktop.widgetLayout || ({});
        return layout[root.widgetId];
    }

    width: root.contentWidth
    height: root.contentHeight

    // -----------------------------------------------------------------
    // POSITION IS ASSIGNED, NOT BOUND -- AND THAT IS DELIBERATE.
    //
    // x and y used to be bindings on `saved`. A MouseArea with
    // `drag.target: root` writes x and y directly, and in QML writing a
    // property DESTROYS its binding. So the first drag of a session silently
    // severed the link to the saved layout, and after that:
    //
    //   * pressing Reset cleared Settings.desktop.widgetLayout but the widget
    //     stayed exactly where it was -- the comment on resetLayout() promises
    //     it animates home, and it did not;
    //   * plugging in a monitor (which changes the parent's size) no longer
    //     re-resolved the fraction, so the widget kept a stale pixel position.
    //
    // Both came back on the next rebuild of the surface, which happens
    // whenever the desktop is covered and uncovered, so it looked intermittent.
    //
    // Assigning from a function that every relevant change calls keeps the
    // behaviour a binding was supposed to give, without a binding to break.
    // The Behaviors on x/y still animate it, so Reset glides home as intended.
    // -----------------------------------------------------------------

    function applyPosition() {
        const pw = root.parent ? root.parent.width : 0;
        const ph = root.parent ? root.parent.height : 0;
        if (pw <= 0 || ph <= 0)
            return;

        const fx = (root.saved && root.saved.x !== undefined) ? root.saved.x : root.defaultX;
        const fy = (root.saved && root.saved.y !== undefined) ? root.saved.y : root.defaultY;

        // Clamped so a widget can never be dragged (or restored) off screen --
        // a saved position from a wider monitor would otherwise be unreachable.
        root.x = Math.max(0, Math.min(pw - root.width, Math.round(fx * pw)));
        root.y = Math.max(0, Math.min(ph - root.height, Math.round(fy * ph)));
    }

    // Re-resolve whenever the stored layout changes (including Reset, which
    // empties it) or the surface is resized (monitor hotplug, rotation).
    onSavedChanged: root.applyPosition()
    onWidthChanged: root.applyPosition()
    onHeightChanged: root.applyPosition()

    Connections {
        target: root.parent
        enabled: !!root.parent
        function onWidthChanged() { root.applyPosition(); }
        function onHeightChanged() { root.applyPosition(); }
    }

    // Entrance: widgets fade up rather than blinking into existence when the
    // desktop becomes visible or a toggle is flipped in Settings.
    opacity: 0
    scale: 0.94
    Component.onCompleted: {
        root.applyPosition();
        root.opacity = 1;
        root.scale = 1;
    }

    Behavior on opacity {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.durationSlower; easing.type: Appearance.easeEnter }
    }

    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.durationSlow; easing.type: Appearance.easeEnter }
    }

    // Only animate the resting position, never the drag itself -- animating a
    // dragged item makes it lag behind the cursor.
    Behavior on x {
        enabled: !Appearance.motionless && !drag.drag.active
        NumberAnimation { duration: Appearance.durationNormal; easing.type: Appearance.easeStandard }
    }

    Behavior on y {
        enabled: !Appearance.motionless && !drag.drag.active
        NumberAnimation { duration: Appearance.durationNormal; easing.type: Appearance.easeStandard }
    }

    // --- the card ---------------------------------------------------------
    Card {
        id: frame

        anchors.fill: parent
        elevation: root.editing ? 2 : 1
        radius: Appearance.radius

        // A widget lives on the wallpaper, not on another surface, so it is
        // deliberately lighter than a panel: enough ground to stay readable
        // over a busy image, not so much that the desktop looks like a form.
        color: Theme.wash(Theme.surface, root.editing ? 0.95 : 0.72)

        scale: drag.pressed && root.editing ? 1.03 : 1.0

        Behavior on scale {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationFast; easing.type: Appearance.easeStandard }
        }

        Item {
            id: slot
            anchors.fill: parent
            anchors.margins: Appearance.md
        }
    }

    // Content declared by the caller lands in the padded slot.
    default property alias body: slot.data

    // --- edit affordances --------------------------------------------------
    Rectangle {
        anchors.fill: parent
        visible: root.editing
        radius: Appearance.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.wash(Theme.accent, drag.pressed ? 0.9 : 0.45)
    }

    Rectangle {
        visible: root.editing
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -6
        width: 22
        height: 22
        radius: 11
        color: Theme.accent

        Icon {
            anchors.centerIn: parent
            name: "drag"
            size: 12
            color: Theme.onAccent(Theme.accent)
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        enabled: root.editing
        cursorShape: root.editing ? Qt.SizeAllCursor : Qt.ArrowCursor
        drag.target: root.editing ? root : null
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (root.parent ? root.parent.width : 0) - root.width
        drag.maximumY: (root.parent ? root.parent.height : 0) - root.height

        onReleased: {
            let px = root.x;
            let py = root.y;

            if (Settings.desktop.snapToGrid) {
                const g = Math.max(2, Settings.desktop.gridSize);
                px = Math.round(px / g) * g;
                py = Math.round(py / g) * g;
            }

            const w = root.parent ? root.parent.width : 1;
            const h = root.parent ? root.parent.height : 1;
            root.store(px / w, py / h);
        }
    }

    // Rewrites the whole map rather than mutating it in place: JsonAdapter only
    // notices a `var` property changing by identity, so an in-place edit would
    // never reach settings.json.
    function store(fx, fy) {
        const layout = {};
        const current = Settings.desktop.widgetLayout || ({});
        for (const key in current) layout[key] = current[key];
        layout[root.widgetId] = { x: fx, y: fy };
        Settings.desktop.widgetLayout = layout;
    }
}
