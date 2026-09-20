import QtQuick
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
    property string placement: "center"

    property int panelWidth: Appearance.panelWidth
    property int panelHeight: 0               // 0 = size to content

    // Dim the desktop behind the panel. For surfaces that should feel modal --
    // the launcher, the power menu -- rather than for quick glances.
    property bool scrim: false

    property bool closeOnClickOutside: true

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
            lifetime.restart();
            root.closed();
        }
    }

    // Keeps the window alive long enough for the exit animation to play, then
    // tears everything down.
    Timer {
        id: lifetime

        interval: Appearance.durationSlow + 80
        onTriggered: if (!root.open) loader.activeAsync = false
    }

    LazyLoader {
        id: loader

        activeAsync: false

        PanelWindow {
            id: window

            // Follow the focused output rather than a fixed screen, so a panel
            // opens where the user is looking. Hypr.activeScreen also handles
            // the focused monitor having just been unplugged.
            screen: Hypr.activeScreen

            visible: true
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-" + root.name
            WlrLayershell.keyboardFocus: root.open
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Cover the output, but never reserve space -- windows must not
            // reflow because a popup appeared. See the header for why the
            // surface is full-screen.
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            // Only the card (and the scrim, when there is one) takes clicks.
            // Everything else stays click-through to the desktop below.
            mask: root.scrim ? null : maskRegion

            Region {
                id: maskRegion
                item: card
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
                height: root.panelHeight > 0 ? root.panelHeight : contentLoader.implicitHeight + Appearance.padding * 2

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
                anchors.verticalCenter: root.placement === "center" ? parent.verticalCenter : undefined
                anchors.right: root.placement === "top-right" ? parent.right : undefined
                anchors.left: root.placement === "top-left" ? parent.left : undefined
                anchors.top: root.placement.indexOf("top") === 0 ? parent.top : undefined
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
                scale: root.open ? 1 : 0.96

                transformOrigin: {
                    switch (root.placement) {
                    case "top-right": return Item.TopRight;
                    case "top-left": return Item.TopLeft;
                case "top-center": return Item.Top;
                    case "bottom": return Item.Bottom;
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
                transform: Translate {
                    y: root.open ? 0
                        : root.placement === "bottom" ? 18 : -18

                    Behavior on y {
                        enabled: !Appearance.motionless
                        NumberAnimation {
                            duration: root.open ? Appearance.durationSlow : Appearance.durationNormal
                            easing.type: root.open ? Appearance.easeEnter : Appearance.easeExit
                        }
                    }
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

            HyprlandFocusGrab {
                active: root.open && root.closeOnClickOutside
                windows: [window]
                onCleared: root.hide()
            }
        }
    }
}
