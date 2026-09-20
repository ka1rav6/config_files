import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// =============================================================================
// Workspace overview — a rotating carousel of every live workspace.  SUPER + SPACE
// =============================================================================
// Replaces the Quickshell launcher on this key; wofi is the launcher now
// (SUPER + S), by choice.
//
// THE SHAPE
//   Workspace cards sit on a horizontal ring seen in perspective -- a carousel,
//   the "globe" idea flattened to the one axis that is actually navigable with
//   a mouse. Moving the pointer left and right spins the ring; the card nearest
//   the front is the selection. Cards behind the ring are scaled down, dimmed
//   and pushed back in z, which is what sells the depth without a 3D scene.
//
//   Perspective is faked rather than rendered. A real PerspectiveTransform per
//   card means an FBO per card; sin/cos driving x, scale, opacity and z gives
//   the same read for the cost of four property bindings, and stays crisp
//   because nothing is ever resampled.
//
// WHAT A CARD SHOWS
//   The workspace number and name, and the icon of every window on it, biggest
//   first. Not a live thumbnail: capturing one needs wlr-screencopy per
//   workspace per frame, which is exactly the kind of cost this desktop has
//   been avoiding everywhere else. Icons identify a workspace faster than a
//   postage-stamp screenshot does anyway.
//
// NAVIGATION
//   pointer / scroll   spin the ring
//   left, right        step one workspace
//   1-9, 0             jump straight to that workspace
//   enter              switch to the front card
//   escape             close, change nothing
// =============================================================================

Scope {
    id: root

    property bool open: false

    function show() { root.open = true; }
    function hide() { root.open = false; }
    function toggle() { root.open = !root.open; }

    Component.onCompleted: Shell.register("overview", root)
    Component.onDestruction: Shell.unregister("overview")

    // --- model ------------------------------------------------------------
    //
    // Every non-special workspace that exists, plus the ones that do not exist
    // yet but are worth offering. A ring with three cards on it is not a ring,
    // and a desktop where workspace 4 is empty should still let you go there.
    readonly property var workspaces: {
        const byId = {};

        for (const ws of Hyprland.workspaces.values) {
            // Special workspaces are the scratchpads. They overlay whatever you
            // are on rather than being somewhere you travel to, so they are not
            // destinations and do not belong here.
            if (!ws || ws.id < 0) continue;
            byId[ws.id] = {
                id: ws.id,
                name: ws.name || String(ws.id),
                windows: []
            };
        }

        // Only workspaces that are actually IN USE. Hyprland already only
        // reports workspaces that exist, so this is mostly about not padding
        // the ring out to nine cards of nothing -- a carousel of empty
        // placeholders is a worse way to pick than a short ring of real ones.
        //
        // The workspace you are standing on is always included even if it is
        // empty, so the ring never opens with no selection on it.
        if (!byId[root.activeId]) {
            byId[root.activeId] = {
                id: root.activeId,
                name: String(root.activeId),
                windows: []
            };
        }

        for (const t of Hyprland.toplevels.values) {
            const ipc = t.lastIpcObject;
            if (!ipc || !t.workspace) continue;
            const slot = byId[t.workspace.id];
            if (!slot) continue;
            slot.windows.push({
                title: ipc.title || "",
                cls: ipc.class || "",
                floating: !!ipc.floating,
                address: t.address
            });
        }

        const list = [];
        for (const id in byId) list.push(byId[id]);
        list.sort((a, b) => a.id - b.id);
        return list;
    }

    readonly property int activeId: Hypr.focusedWorkspace ? Hypr.focusedWorkspace.id : 1

    // Which card is at the front. Index into `workspaces`.
    property int selected: 0

    function indexOfId(id) {
        for (let i = 0; i < root.workspaces.length; i++)
            if (root.workspaces[i].id === id) return i;
        return 0;
    }

    function step(delta) {
        const n = root.workspaces.length;
        if (n === 0) return;
        // Wraps, because a carousel that stops at the ends is a list.
        root.selected = ((root.selected + delta) % n + n) % n;
    }

    function commit() {
        const ws = root.workspaces[root.selected];
        root.hide();
        if (ws) Hypr.focusWorkspace(ws.id);
    }

    onOpenChanged: {
        if (root.open) {
            // Always open pointing at where you already are, with no leftover
            // pointer bias from last time.
            root.selected = root.indexOfId(root.activeId);
            loader.activeAsync = true;
        } else {
            lifetime.restart();
        }
    }

    Timer {
        id: lifetime
        interval: 360
        onTriggered: if (!root.open) loader.activeAsync = false
    }

    LazyLoader {
        id: loader

        activeAsync: false

        PanelWindow {
            id: window

            screen: Hypr.activeScreen
            visible: true
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-overview"
            WlrLayershell.keyboardFocus: root.open
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Takes the whole screen: the ring is navigated by moving the
            // pointer anywhere, not by hitting a card.
            mask: root.open ? null : emptyRegion
            Region { id: emptyRegion }

            // --- backdrop ---------------------------------------------------
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)
                opacity: root.open ? 1 : 0

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationNormal }
                }
            }

            FocusScope {
                id: keys

                anchors.fill: parent
                focus: true

                Keys.onPressed: (event) => {
                    switch (event.key) {
                    case Qt.Key_Escape:  root.hide(); event.accepted = true; break;
                    case Qt.Key_Left:    root.step(-1); event.accepted = true; break;
                    case Qt.Key_Right:   root.step(1); event.accepted = true; break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:   root.commit(); event.accepted = true; break;
                    default:
                        // Digits jump straight there. 0 is workspace 10, the
                        // same convention the number-row binds already use.
                        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                            root.selected = root.indexOfId(event.key - Qt.Key_0);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_0) {
                            root.selected = root.indexOfId(10);
                            event.accepted = true;
                        }
                    }
                }

                // --- the ring ------------------------------------------------
                Item {
                    id: ring

                    anchors.fill: parent

                    readonly property int count: root.workspaces.length
                    // How far apart cards sit on the circle.
                    readonly property real arc: ring.count > 0 ? (Math.PI * 2) / ring.count : 0
                    readonly property real radius: Math.min(width * 0.42, 620)

                    // -------------------------------------------------------
                    // Motion
                    //
                    // `anchor` is where the ring wants to be, in card-steps. It
                    // is moved by the keyboard, the scroll wheel and by clicking
                    // a card -- never by the pointer.
                    //
                    // `bias` is a small offset the pointer adds on top, so
                    // moving the mouse nudges the ring without ever fighting
                    // the thing that actually selects. The earlier version had
                    // the pointer assign `turn` directly, which stamped on
                    // every scroll and keypress the instant the mouse twitched:
                    // that is why scrolling appeared to do nothing.
                    //
                    // `turn` is then a plain binding of the two, and a
                    // SmoothedAnimation chases it. SmoothedAnimation rather
                    // than NumberAnimation because the target moves
                    // continuously under the pointer -- a fixed-duration
                    // animation restarts on every change and stutters, while a
                    // velocity-based one just tracks.
                    // -------------------------------------------------------

                    property real anchor: root.selected
                    property real bias: 0

                    // A fresh ring each time: no leftover pointer bias, and the
                    // anchor exactly on the selection rather than wherever the
                    // last session left it.
                    Component.onCompleted: {
                        ring.anchor = root.selected;
                        ring.bias = 0;
                        ring.turn = root.selected;
                    }

                    readonly property real target: ring.anchor + ring.bias

                    property real turn: root.selected

                    Behavior on turn {
                        enabled: !Appearance.motionless
                        SmoothedAnimation {
                            velocity: 7
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }

                    onTargetChanged: ring.turn = ring.target

                    Connections {
                        target: root
                        function onSelectedChanged() {
                            // Take the short way round the circle instead of
                            // unwinding all the way back through the middle.
                            const n = ring.count;
                            if (n === 0) { ring.anchor = 0; return; }
                            let delta = root.selected - (((ring.anchor % n) + n) % n);
                            if (delta > n / 2) delta -= n;
                            if (delta < -n / 2) delta += n;
                            ring.anchor += delta;
                        }
                    }

                    Repeater {
                        model: root.workspaces

                        OverviewCard {
                            id: card

                            required property var modelData
                            required property int index

                            workspace: modelData
                            isActive: modelData.id === root.activeId

                            // Angle of this card around the ring, with the
                            // front of the ring at -PI/2 (towards the viewer).
                            readonly property real angle: (card.index - ring.turn) * ring.arc

                            // 1 at the front, 0 at the back. Everything else is
                            // a function of this, which is what keeps the
                            // perspective consistent.
                            readonly property real front: (Math.cos(card.angle) + 1) / 2

                            isSelected: card.front > 0.995

                            x: ring.width / 2 - width / 2 + Math.sin(card.angle) * ring.radius
                            y: ring.height / 2 - height / 2
                               // Cards at the back ride a little higher, the
                               // way a ring seen from slightly above would.
                               - (1 - card.front) * 26

                            scale: 0.58 + card.front * 0.42
                            opacity: 0.18 + card.front * 0.82
                            z: Math.round(card.front * 100)

                            onClicked: {
                                if (card.isSelected) root.commit();
                                else root.selected = card.index;
                            }
                        }
                    }
                }

                // Pointer drives the ring. A HoverHandler rather than a
                // MouseArea so clicks still reach the cards underneath.
                HoverHandler {
                    id: pointer

                    // The pointer only BIASES the ring -- it never sets its
                    // position outright. Half a card of travel at each edge is
                    // enough to make the ring feel alive under the hand and
                    // to peek at the neighbours, without ever overriding what
                    // the wheel or the arrow keys just selected.
                    onPointChanged: {
                        if (!root.open || Appearance.motionless) return;
                        const frac = pointer.point.position.x / Math.max(1, keys.width);
                        ring.bias = (frac - 0.5) * 1.1;
                    }
                }

                // Scrolling steps the ring. Both axes: a mouse wheel gives y,
                // a touchpad two-finger swipe gives x, and on a carousel they
                // obviously mean the same thing.
                //
                // Touchpads emit a stream of small deltas rather than one
                // notch, so the raw event count is accumulated and a step is
                // taken per notch-worth. Without that, one swipe spun through
                // every workspace at once.
                WheelHandler {
                    id: wheel

                    property real acc: 0

                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    // Take the whole screen, so the wheel works wherever the
                    // pointer is rather than only over a card.
                    target: null

                    onWheel: (event) => {
                        const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                            ? event.angleDelta.x : event.angleDelta.y;
                        if (delta === 0) return;

                        wheel.acc += delta;
                        // One notch is 120 in Qt's units.
                        while (wheel.acc >= 120) { root.step(-1); wheel.acc -= 120; }
                        while (wheel.acc <= -120) { root.step(1); wheel.acc += 120; }
                    }
                }

                // --- caption ------------------------------------------------
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 58
                    spacing: Appearance.sm

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const ws = root.workspaces[root.selected];
                            if (!ws) return "";
                            const n = ws.windows.length;
                            return ws.name + "  ·  "
                                + (n === 0 ? "empty" : n === 1 ? "1 window" : n + " windows");
                        }
                        color: "white"
                        font.family: Appearance.font
                        font.pixelSize: Appearance.size(20)
                        font.weight: Appearance.weightMedium
                        font.letterSpacing: Appearance.trackingHeading
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "move to spin  ·  1–9 to jump  ·  enter to switch  ·  esc to cancel"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        font.letterSpacing: 1
                    }
                }
            }

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            HyprlandFocusGrab {
                active: root.open
                windows: [window]
                onCleared: root.hide()
            }
        }
    }
}
