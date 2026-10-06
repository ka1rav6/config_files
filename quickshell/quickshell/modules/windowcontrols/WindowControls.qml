import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// =============================================================================
// WindowControls — a macOS-style control cluster on the active window's
// top-right corner.
// =============================================================================
//
//     [ window contents ..................................... ● ● ● ]
//
// Close (red), minimize (amber), maximize/restore (green), right-aligned -- the
// mirror of the macOS placement, deliberately, because the left corner is where
// applications put their own controls.
//
// -----------------------------------------------------------------------------
// WHY THIS IS A LAYER SURFACE AND NOT A DECORATION
//
// Hyprland has no server-side titlebars. Three mechanisms were looked at before
// this one was written:
//
//   hyprbars (hyprpm plugin)   The only REAL decoration for Hyprland, and the
//                              technically correct answer in the abstract. Not
//                              used here, for four reasons that compound:
//                              it draws a bar ABOVE the content rather than
//                              controls inside the corner; it loads third-party
//                              C++ into the compositor process, so a fault in
//                              it takes the session with it -- which is exactly
//                              the dependency ~/.config/quickshell/shell.qml's
//                              header forbids; it has to be rebuilt against
//                              matching headers after every Hyprland upgrade,
//                              and this machine tracks a PPA; and on this
//                              machine it is broken today (hyprpm's state store
//                              /var/cache/hyprpm/kairav is root-owned from a
//                              `sudo hyprpm` that hyprpm itself refuses to
//                              support, headersRoot is empty, and the recorded
//                              ABI is aq_0.14 against a live aq_0.15 -- all four
//                              plugins report "Plugin failed to build").
//
//   a waybar module            Would put window controls on the BAR, not on the
//                              window. A different feature wearing the same name.
//
//   this                       A layer-shell surface per output, positioned over
//                              the active window's corner.
//
// WHAT THE LAYER-SHELL APPROACH COSTS, HONESTLY
//   * It draws OVER the top-right of the window contents, because that is where
//     it was asked to be. `controlsInset` moves it if an application's own
//     controls are underneath.
//   * It follows geometry rather than being attached to it. See the long note in
//     services/WindowPolicy.qml: Hyprland emits no geometry event, so a drag is
//     followed at 8 Hz and a client-side-titlebar drag within a second.
//   * It is on the active window only. That is also the macOS behaviour, and it
//     is what keeps the whole feature down to one tracked rectangle.
//
// -----------------------------------------------------------------------------
// THE SURFACE IS FULL-OUTPUT AND THE CLUSTER IS POSITIONED INSIDE IT
//
// Exactly the pattern ui/Panel.qml documents, and for exactly the same reason:
// a PanelWindow anchored to only some edges takes its size from
// implicitWidth/implicitHeight and comes out ZERO-SIZED if those are unset, at
// which point the content renders outside the surface and nothing appears at
// all -- Hyprland lists the layer, Qt reports frames, the screen stays empty.
//
// So the surface covers the output and `mask` is narrowed to the cluster's own
// rectangle. Every other pixel stays click-through to the window underneath.
// That mask is the whole reason this does not "interfere with applications":
// outside ~66x20 logical px, this surface does not exist as far as input is
// concerned.
//
// NEVER set `mask: null` here. Upstream treats null as "the entire window takes
// input", which would make the focused monitor unclickable.
//
// -----------------------------------------------------------------------------
// INPUT AND SUPER+DRAG
//
// Hyprland resolves keybinds -- mouse binds included -- before delivering the
// click to any surface, and `binds.pass_mouse_when_bound` is false by default.
// So a SUPER (or SUPER+SHIFT) left-drag over this cluster still starts the
// window drag from ~/.config/hypr/bindings.lua rather than pressing a button.
// Plain clicks, with no modifier, are the cluster's.
//
// NO BLUR RULE, DELIBERATELY. Blur on this system is opt-in per namespace in
// ~/.config/hypr/rules.lua, and "qs-windowcontrols" is deliberately not listed:
// the dots are opaque and the hover pill is a 66x20 sliver, so blurring behind
// it would be GPU work for an effect nobody can see. Same reasoning as the
// qs-visualizer / qs-widgets exclusions noted in that file.
// =============================================================================

Scope {
    id: root

    Variants {
        // One surface per output. Never index Quickshell.screens by number and
        // never hardcode a name -- the multi-monitor rule from
        // services/Hypr.qml's header applies here more than anywhere, because
        // this surface's whole job is arithmetic on monitor origins.
        model: Quickshell.screens

        PanelWindow {
            id: surface

            required property var modelData

            screen: surface.modelData
            visible: true
            color: "transparent"

            // The Hyprland monitor behind this Quickshell screen. Null for a
            // frame or two after a hotplug, which is why every use below is
            // guarded rather than assumed.
            readonly property var monitor: Hypr.monitorFor(surface.modelData)

            // Is the active window on THIS output? `lastIpcObject.monitor` is
            // Hyprland's numeric monitor ID, not a name, so this compares IDs.
            readonly property bool mine: !!surface.monitor
                && !!WindowPolicy.active
                && WindowPolicy.active.monitor === surface.monitor.id

            readonly property bool shown: WindowPolicy.visible && surface.mine

            anchors { top: true; bottom: true; left: true; right: true }

            // A popup must never make windows reflow. Ignore rather than a zero
            // zone: see the note in modules/dock/Dock.qml about how writing any
            // exclusive zone at all flips the exclusion mode upstream.
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "qs-windowcontrols"
            // Never takes the keyboard. The cluster is pointer-only by design:
            // stealing focus from the window you are about to close would be a
            // strange way to close it.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // --- input region ---------------------------------------------
            //
            // Explicit geometry rather than `item: cluster`, so that the region
            // is provably EMPTY while the cluster is hidden. Binding it to an
            // invisible item leaves "does an invisible item contribute to a
            // region" as an upstream detail this feature's click-through
            // correctness would rest on. It does not rest on it.
            mask: Region {
                x: surface.shown ? cluster.x : 0
                y: surface.shown ? cluster.y : 0
                width: surface.shown ? cluster.width : 0
                height: surface.shown ? cluster.height : 0
            }

            // --- position -------------------------------------------------
            //
            // hyprctl reports window `at` and `size` in LOGICAL layout
            // coordinates (verified: eDP-1 at scale 1.5 is 2880x1800 physical
            // and reports a maximised window as 1896 wide inside a 1920 logical
            // output, gaps included). A layer surface covering the output shares
            // that space with its origin at the monitor's origin, so placing the
            // cluster is a subtraction and not a scale conversion. Do not
            // "correct" this by dividing by monitor.scale.
            readonly property int inset: Settings.windows.controlsInset

            readonly property int targetX: {
                if (!surface.shown) return 0;
                const win = WindowPolicy.active;
                const right = win.x - surface.monitor.x + win.width;
                // Clamp inside the output. A window can legitimately extend past
                // the edge (a floating window dragged half off), and a cluster
                // outside the surface is a cluster that is silently clipped away.
                const maxX = surface.width - cluster.width - 2;
                return Math.max(2, Math.min(maxX, right - cluster.width - surface.inset));
            }

            readonly property int targetY: {
                if (!surface.shown) return 0;
                const win = WindowPolicy.active;
                const top = win.y - surface.monitor.y;
                const maxY = surface.height - cluster.height - 2;
                return Math.max(2, Math.min(maxY, top + surface.inset));
            }

            // --- the cluster ----------------------------------------------
            Item {
                id: cluster

                x: surface.targetX
                y: surface.targetY
                width: WindowPolicy.clusterWidth + Appearance.sm * 2
                height: WindowPolicy.dotSize + Appearance.xs * 2

                visible: opacity > 0.01
                opacity: surface.shown ? 1 : 0

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: Appearance.durationFast
                        easing.type: Appearance.easeStandard
                    }
                }

                // Follow the window rather than teleporting. Short enough that
                // the cluster never lags visibly behind a drag, long enough that
                // a tiling reflow reads as the cluster moving WITH the window.
                //
                // Disabled entirely while an interaction is in flight: during a
                // drag the position updates are already a 125 ms staircase, and
                // animating between the steps turns a staircase into a wobble.
                Behavior on x {
                    enabled: !Appearance.motionless && !WindowPolicy.interacting
                    NumberAnimation { duration: Appearance.durationFast; easing.type: Appearance.easeStandard }
                }

                Behavior on y {
                    enabled: !Appearance.motionless && !WindowPolicy.interacting
                    NumberAnimation { duration: Appearance.durationFast; easing.type: Appearance.easeStandard }
                }

                // Backing pill, revealed on hover only. At rest the dots sit
                // directly on the window's own pixels, which is what keeps this
                // reading as part of the window rather than as a floating
                // widget parked on top of it.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.panel(0.55)
                    border.width: Appearance.borderWidth
                    border.color: Theme.wash(Theme.border, 0.5)
                    opacity: hover.containsMouse ? 1 : 0

                    Behavior on opacity {
                        enabled: !Appearance.motionless
                        NumberAnimation { duration: Appearance.durationFast }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: WindowPolicy.dotGap

                    // macOS order, preserved left-to-right inside the cluster
                    // even though the cluster itself is on the right: close,
                    // minimize, zoom. Colours come from the theme's semantic
                    // triple, so they track whatever theme-switch has applied
                    // rather than being three hardcoded macOS hex values.
                    Repeater {
                        model: [
                            { id: "close",    colour: Theme.error,   glyph: "×" },
                            { id: "minimize", colour: Theme.warning, glyph: "−" },
                            { id: "maximize", colour: Theme.success, glyph: "⬌" }
                        ]

                        Rectangle {
                            id: dot

                            required property var modelData

                            width: WindowPolicy.dotSize
                            height: WindowPolicy.dotSize
                            radius: width / 2

                            // Dimmed until the pointer is on the cluster, the
                            // way macOS greys the lights on an unfocused window.
                            // Full colour on hover, plus the glyph.
                            color: hover.containsMouse
                                ? (dotMouse.containsMouse
                                    ? Qt.lighter(dot.modelData.colour, 1.15)
                                    : dot.modelData.colour)
                                : Theme.wash(dot.modelData.colour, 0.72)

                            Behavior on color {
                                enabled: !Appearance.motionless
                                ColorAnimation { duration: Appearance.durationFast }
                            }

                            scale: dotMouse.pressed ? 0.88 : 1

                            Behavior on scale {
                                enabled: !Appearance.motionless
                                NumberAnimation { duration: Appearance.durationFast }
                            }

                            Text {
                                anchors.centerIn: parent

                                // The green dot's glyph tracks what the button
                                // will actually DO next, read from the same
                                // WindowPolicy.zoomAction the click dispatches
                                // on -- so the icon can never promise one
                                // action and perform another.
                                //
                                //   maximize -> ⬌  fill the monitor
                                //   restore  -> ⬍  back to the size it had
                                //   tile     -> ⊞  back into the layout
                                //
                                // Inter has none of these three, so all of them
                                // come from fontconfig fallback. ⊞ (U+229E) was
                                // picked over the other "put it in the grid"
                                // candidates because it has far the widest
                                // coverage on this machine -- 63 installed
                                // families, against 18 for the ⬌/⬍ pair that
                                // has been rendering here all along.
                                text: {
                                    if (dot.modelData.id !== "maximize") return dot.modelData.glyph;
                                    switch (WindowPolicy.zoomAction) {
                                    case "restore": return "⬍";
                                    case "tile":    return "⊞";
                                    default:        return dot.modelData.glyph;
                                    }
                                }
                                color: Theme.onAccent(dot.color)
                                font.family: Appearance.font
                                font.pixelSize: Math.round(WindowPolicy.dotSize * 0.72)
                                font.weight: Appearance.weightBold
                                opacity: hover.containsMouse ? 1 : 0

                                Behavior on opacity {
                                    enabled: !Appearance.motionless
                                    NumberAnimation { duration: Appearance.durationFast }
                                }
                            }

                            MouseArea {
                                id: dotMouse

                                anchors.fill: parent
                                // A hair of slop, so a 12 px target is not a
                                // 12 px target. The mask is the cluster, not
                                // this, so widening it costs nothing outside.
                                anchors.margins: -2
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton

                                onClicked: {
                                    switch (dot.modelData.id) {
                                    case "close":    WindowPolicy.close(); break;
                                    case "minimize": WindowPolicy.minimize(); break;
                                    case "maximize": WindowPolicy.toggleMaximize(); break;
                                    }
                                }
                            }
                        }
                    }
                }

                // One hover area over the whole cluster, so approaching any dot
                // lights all three -- the dots are 12 px and hunting for the
                // exact one while they are still dim is not a control.
                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
