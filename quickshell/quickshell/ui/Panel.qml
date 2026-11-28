import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// =============================================================================
// Panel — the base for every popup surface in the shell.
// =============================================================================
// The Control Center, Settings, the launcher, the calendar and the power menu
// are all this component with different content. That is what guarantees they
// open the same way, close the same way, and sit the same distance from the
// screen edge.
//
// -----------------------------------------------------------------------------
// WHY THE SURFACE IS FULL-SCREEN AND THE CARD IS POSITIONED INSIDE IT
//
// The obvious design is a small layer-shell surface anchored to the corner the
// panel appears in. That does not work: a PanelWindow anchored to only some
// edges takes its size from implicitWidth/implicitHeight, and if those are not
// set it comes out zero-sized. The card then renders outside the surface
// bounds and nothing is visible at all -- Hyprland lists the layer, Qt reports
// frames rendering, and the screen stays empty. That exact mistake cost an hour
// here; do not "simplify" this back.
//
// So the surface covers the output, is fully transparent, and the card is
// anchored inside it. Three things fall out of that, all of them wanted:
//
//   * `mask` can be set to just the card, so every pixel outside it stays
//     click-through to the desktop. The surface being large costs nothing --
//     an empty transparent region is not composited.
//   * The scrim below can dim the whole screen and animate with the panel,
//     which a Hyprland `dim_around` layer rule cannot (it is instant, and it
//     cannot fade out with the panel it belongs to).
//   * Panels can animate from anywhere on screen without being clipped by
//     their own surface.
// -----------------------------------------------------------------------------
//
// WHY IT IS A LAZY LOADER, NOT A HIDDEN WINDOW
//   Content is built on first open and destroyed after close. A
//   hidden-but-constructed panel keeps its bindings live, its timers running
//   and its service subscriptions attached -- a Control Center that is never
//   opened would still be scanning Bluetooth. Nothing here exists while closed.
//
// FOCUS GRAB
//   HyprlandFocusGrab is what makes click-outside-to-close work and routes the
//   keyboard here, so Escape works and the launcher can be typed into.
// =============================================================================

Scope {
    id: root

    // Becomes the layer-shell namespace "qs-<name>", which is what the blur
    // rules in ~/.config/hypr/rules.lua match on. A panel whose name is not
    // listed there gets no blur -- deliberately, since blur is opt-in on this
    // system.
    required property string name

    property bool open: false

    // Where the card sits. "center" floats it; the rest hug an edge.
    // center | top-right | top-left | top-center | bottom
    //
    // "top-center" is the drop-down position: the card hangs from just under
    // the waybar, horizontally centred, so it reads as falling out of the
    // centre clock module rather than flying in from a corner.
    //
    // "left" and "right" are the EDGE placements (from Anserin's side panels):
    // the card floats just off that screen edge, inset by screenMargin like
    // every other panel, and slides in sideways rather than scaling up. They
    // are what the edge triggers (ui/EdgeTrigger.qml) open.
    //
    // The gap between the edge and the card is safe to cross: a peeking panel
    // does not auto-hide while the pointer is still on its edge strip
    // (Shell.edgeHover), and hoverHideDelay is far longer than the 14 px trip
    // from the strip onto the card. (They were flush against the edge before
    // that hold existed, which is what used to stop the hide-and-reopen loop.)
    property string placement: "center"

    readonly property bool edgePlacement: root.placement === "left" || root.placement === "right"

    property int panelWidth: Appearance.panelWidth
    property int panelHeight: 0               // 0 = size to content

    // Edge panels only: run the full height between the bar and the bottom
    // margin instead of sizing to content. The drawer wants this; the Control
    // Center (a short list) does not.
    property bool fullHeight: false

    // PEEK: opened by hovering a screen edge rather than by a key or a click.
    //
    // A peeking panel is a glance, so it must not behave like a summoned one:
    //   * no focus grab -- it never steals the keyboard from the window you
    //     were typing in, and a click elsewhere is not swallowed to close it;
    //   * it hides on its own once the pointer has been off it for
    //     Appearance.hoverHideDelay.
    // The moment you press anything inside it, it is PINNED (peek = false) and
    // becomes an ordinary panel: grab on, keyboard on demand, no auto-hide. So
    // hover-to-look and click-to-use both work without a mode switch.
    property bool peek: false

    // Which output to open on. Null means the focused one. Edge triggers set
    // it, because the edge you hovered may be on a monitor that does not have
    // focus yet; it is cleared on close.
    property var targetScreen: null

    // Dim the desktop behind the panel. For surfaces that should feel modal --
    // the launcher, the power menu -- rather than for quick glances.
    property bool scrim: false

    property bool closeOnClickOutside: true

    // For "top-center": the x (in the screen's own coordinates) to hang the
    // card under, or -1 for the middle. Set by services/BarHover.qml so a
    // hover dropdown sits under the bar pill that opened it.
    property real hangX: -1

    property Component content: null

    signal opened()
    signal closed()

    function show() { root.open = true; }
    function hide() { root.open = false; }
    function toggle() { root.open = !root.open; }

    // Register with the traffic warden so one panel opening closes the others,
    // and so `quickshell ipc call ...` can reach this without shell.qml knowing
    // it exists. Unregistering matters as much as registering -- see the header
    // of services/Shell.qml.
    Component.onCompleted: Shell.register(root.name, root)
    Component.onDestruction: Shell.unregister(root.name)

    onOpenChanged: {
        if (root.open) {
            lifetime.stop();
            loader.activeAsync = true;
            root.opened();
        } else {
            root.peek = false;
            lifetime.restart();
            root.closed();
        }
    }

    // Keeps the window alive long enough for the exit animation to play, then
    // tears everything down.
    Timer {
        id: lifetime

        interval: Appearance.durationSlow + 80
        onTriggered: {
            if (root.open) return;
            loader.activeAsync = false;
            root.targetScreen = null;
        }
    }

    LazyLoader {
        id: loader

        activeAsync: false

        PanelWindow {
            id: window

            // Follow the focused output rather than a fixed screen, so a panel
            // opens where the user is looking. Hypr.activeScreen also handles
            // the focused monitor having just been unplugged.
            screen: root.targetScreen || Hypr.activeScreen

            visible: true
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-" + root.name
            // None while peeking: hovering an edge must never take the
            // keyboard away from the window under it.
            WlrLayershell.keyboardFocus: root.open && !root.peek
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Cover the output, but never reserve space -- windows must not
            // reflow because a popup appeared. See the header for why the
            // surface is full-screen.
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            // Only the card (and the scrim, when there is one) takes clicks.
            // Everything else stays click-through to the desktop below.
            mask: root.scrim ? null : maskRegion

            // The card's RESTING rectangle, given as plain numbers -- not
            // `item: card`.
            //
            // With `item:`, the Region maps the card's rect THROUGH its
            // transforms, once, and is only recomputed when the card's own
            // geometry changes. An edge panel is built mid-slide (Translate
            // x = -width), so the input region was computed off screen and
            // stayed there: the drawer was drawn where you could see it while
            // the pointer went straight through it to the edge strip and the
            // windows behind. A peeking panel therefore never saw the pointer
            // arrive and auto-hid under it. x/y/width/height ignore
            // transforms, which is exactly right: the slide and the 96% scale
            // are decoration, and the clickable area is where the card ends up.
            Region {
                id: maskRegion

                x: card.x
                y: card.y
                width: card.width
                height: card.height
            }

            // --- scrim ---------------------------------------------------
            Rectangle {
                anchors.fill: parent
                visible: root.scrim
                color: Qt.rgba(0, 0, 0, 0.45)
                opacity: root.open ? 1 : 0

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: Appearance.durationNormal
                        easing.type: Appearance.easeStandard
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.scrim && root.closeOnClickOutside
                    onClicked: root.hide()
                }
            }

            // --- the panel itself ----------------------------------------
            Card {
                id: card

                elevation: 2
                width: root.panelWidth
                height: {
                    if (root.edgePlacement && root.fullHeight)
                        return window.height - Appearance.barClearance - Appearance.screenMargin;
                    if (root.panelHeight > 0) return root.panelHeight;
                    return contentLoader.implicitHeight + Appearance.padding * 2;
                }

                Behavior on height {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: Appearance.durationNormal
                        easing.type: Appearance.easeStandard
                    }
                }

                // --- placement ---------------------------------------
                anchors.horizontalCenter: (root.placement === "center"
                        || root.placement === "bottom"
                        || root.placement === "top-center")
                    ? parent.horizontalCenter : undefined
                // A top-center dropdown can hang under a particular point of
                // the bar (the media pill, the clock) instead of the exact
                // middle; kept on screen either way.
                anchors.horizontalCenterOffset: root.placement === "top-center" && root.hangX >= 0
                    ? Math.max(-(parent.width - card.width) / 2 + Appearance.screenMargin,
                               Math.min((parent.width - card.width) / 2 - Appearance.screenMargin,
                                        root.hangX - parent.width / 2))
                    : 0
                // A short edge panel is centred on its edge, so it sits over the
                // edge trigger (which is centred too) instead of above it.
                anchors.verticalCenter: (root.placement === "center"
                        || (root.edgePlacement && !root.fullHeight))
                    ? parent.verticalCenter : undefined
                anchors.right: (root.placement === "top-right" || root.placement === "right")
                    ? parent.right : undefined
                anchors.left: (root.placement === "top-left" || root.placement === "left")
                    ? parent.left : undefined
                anchors.top: (root.placement.indexOf("top") === 0
                        || (root.edgePlacement && root.fullHeight))
                    ? parent.top : undefined
                anchors.bottom: root.placement === "bottom" ? parent.bottom : undefined

                anchors.margins: Appearance.screenMargin
                // Start below waybar rather than under it -- the bar is on the
                // top layer, this is on overlay, so without this a top-anchored
                // panel covers it.
                anchors.topMargin: Appearance.barClearance
                anchors.bottomMargin: Appearance.screenMargin

                // --- entrance ----------------------------------------
                // Scale from 96% plus a fade: enough to read as the panel
                // arriving, not so much that it reads as a zoom. Both
                // properties are GPU-composited, so this is free on the iGPU.
                opacity: root.open ? 1 : 0
                // Edge panels slide; they do not also zoom. Scaling a full-height
                // card reads as the whole screen lurching.
                scale: root.open || root.edgePlacement ? 1 : 0.96

                transformOrigin: {
                    switch (root.placement) {
                    case "top-right": return Item.TopRight;
                    case "top-left": return Item.TopLeft;
                    case "top-center": return Item.Top;
                    case "bottom": return Item.Bottom;
                    case "left": return Item.Left;
                    case "right": return Item.Right;
                    default: return Item.Center;
                    }
                }

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: root.open ? Appearance.durationSlow : Appearance.durationNormal
                        easing.type: root.open ? Appearance.easeEnter : Appearance.easeExit
                    }
                }

                Behavior on scale {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: root.open ? Appearance.durationSlow : Appearance.durationNormal
                        easing.type: root.open ? Appearance.easeEnter : Appearance.easeExit
                    }
                }

                // A short slide along the axis the panel hangs from, on top of
                // the fade and scale. A top-anchored panel therefore drops out
                // of the bar and a bottom-anchored one rises off the edge,
                // which is what makes the drop-down read as coming FROM the
                // clock rather than simply appearing near it. A Translate is
                // used rather than `y`, so the anchors stay in charge of the
                // resting position.
                //
                // Edge panels slide the WHOLE way in, from just past their own
                // width off screen, so they read as coming out of the edge you
                // touched rather than appearing beside it.
                transform: [Translate {
                    y: root.open || root.edgePlacement ? 0
                        : root.placement === "bottom" ? 18
                        : card.dropPlacement && Settings.appearance.slideDropdowns ? -card.dropDistance * 0.6
                        : -18
                    x: (root.open || !root.edgePlacement ? 0 : card.offscreen) + card.enter * card.offscreen

                    Behavior on x {
                        enabled: !Appearance.motionless
                        NumberAnimation {
                            duration: root.open ? Appearance.durationSlow : Appearance.durationNormal
                            easing.type: root.open ? Appearance.easeEnter : Appearance.easeExit
                        }
                    }

                    Behavior on y {
                        enabled: !Appearance.motionless
                        NumberAnimation {
                            duration: root.open ? Appearance.durationSlow : Appearance.durationNormal
                            easing.type: root.open ? Appearance.easeEnter : Appearance.easeExit
                        }
                    }
                }, Translate {
                    // The drop entrance (below). Its own Translate, so the
                    // Behaviors above never see it and cannot smear it.
                    y: -card.drop * card.dropDistance
                }]

                // --- drop entrance ---------------------------------------
                // Panels that hang from the top (the clock's dashboard, the
                // notification center) are built already open too, so on
                // their first open the `open`-driven Behaviors above had
                // nothing to animate from and they simply appeared. This is
                // the same one-shot idea as the edge entrance: `drop` starts at
                // 1 -- lifted up toward the bar and transparent -- and runs to
                // 0, so the card slides down out of the bar. Settings >
                // Appearance > "Slide dropdowns from the bar" turns it off.
                readonly property bool dropPlacement: root.placement === "top-center"
                    || root.placement === "top-right" || root.placement === "top-left"
                readonly property real dropDistance: Math.min(140, 28 + card.height * 0.22)
                property real drop: card.dropPlacement && Settings.appearance.slideDropdowns
                    && !Appearance.motionless ? 1 : 0

                // While dropping, everything above the card's resting top edge
                // is masked away, so it slides out from UNDER the bar instead
                // of across it. The layer exists only for those ~0.3 s.
                layer.enabled: card.drop > 0
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: dropMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 0.1
                }

                Item {
                    id: dropMask

                    width: card.width
                    height: card.height
                    visible: false
                    layer.enabled: card.drop > 0

                    Rectangle {
                        y: card.drop * card.dropDistance
                        width: parent.width
                        height: parent.height
                        color: "white"
                    }
                }

                NumberAnimation {
                    id: dropAnim

                    target: card
                    property: "drop"
                    to: 0
                    duration: Math.round(Appearance.durationSlow * 1.2)
                    easing.type: Appearance.easeEnter
                }

                // --- edge entrance -------------------------------------
                // The window is BUILT already open (the LazyLoader activates on
                // open), so the `open`-driven Behaviors above have no "before"
                // to animate from on a first open. An edge panel's slide is the
                // whole point of it, so it gets a one-shot entrance of its own:
                // `enter` starts at 1 (fully off screen) and runs to 0.
                // Past its own width AND the margin, so it starts wholly off
                // screen now that it floats.
                readonly property real offscreen: root.placement === "left"
                    ? -(card.width + Appearance.screenMargin + 8)
                    : card.width + Appearance.screenMargin + 8
                property real enter: root.edgePlacement && !Appearance.motionless ? 1 : 0

                NumberAnimation {
                    id: enterAnim

                    target: card
                    property: "enter"
                    to: 0
                    duration: Appearance.durationSlow
                    easing.type: Appearance.easeEnter
                }

                Component.onCompleted: {
                    if (card.enter > 0) enterAnim.start();
                    if (card.drop > 0) dropAnim.start();
                }

                // --- peek: hover-out hides, a press pins ----------------
                HoverHandler {
                    id: cardHover
                }

                Timer {
                    interval: Appearance.hoverHideDelay
                    // Also held while the pointer is still on the edge strip
                    // that opened it, or a pointer parked on the edge would
                    // hide-and-reopen the panel in a loop.
                    running: root.open && root.peek && !cardHover.hovered
                        && Shell.edgeHover !== root.name
                    onTriggered: root.hide()
                }

                // DragThreshold makes this a PASSIVE grab: it sees the press
                // alongside whatever button or field actually takes it, rather
                // than stealing the click. Pinning is a side effect of using
                // the panel, never a click of its own.
                TapHandler {
                    gesturePolicy: TapHandler.DragThreshold
                    onPressedChanged: if (pressed && root.peek) root.peek = false
                }

                // Keyboard handling lives on an item INSIDE the window:
                // PanelWindow has no `focus` property of its own.
                // WlrLayershell.keyboardFocus above is the Wayland half (does
                // the compositor route keys here at all); this FocusScope is
                // the QML half (where they go once they arrive).
                FocusScope {
                    id: keys

                    anchors.fill: parent
                    focus: true

                    Keys.onEscapePressed: root.hide()

                    Loader {
                        id: contentLoader

                        anchors.fill: parent
                        anchors.margins: Appearance.padding
                        sourceComponent: root.content
                        focus: true
                    }
                }
            }

            // Pull keyboard focus in when the panel opens, so Escape and typing
            // work without clicking the panel first.
            onVisibleChanged: if (visible) keys.forceActiveFocus()

            // A pinned peek has to ask for the keyboard now: it opened with
            // none, and the grab only just switched on.
            Connections {
                target: root
                function onPeekChanged() { if (!root.peek && root.open) keys.forceActiveFocus(); }
            }

            HyprlandFocusGrab {
                // Not while peeking: see `peek`.
                active: root.open && root.closeOnClickOutside && !root.peek
                windows: [window]
                onCleared: root.hide()
            }
        }
    }
}
