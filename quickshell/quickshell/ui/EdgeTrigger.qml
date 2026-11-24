import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// =============================================================================
// EdgeTrigger — open a panel by resting the pointer on a screen edge.
// =============================================================================
// Anserin's left and right panels come out of the screen edges on hover. This
// is that, for any Panel with a "left" or "right" placement: a strip
// Appearance.edgeTrigger (3 px) wide, centred on the edge, a quarter of the
// screen tall. Rest on it for Appearance.hoverRevealDelay and the panel peeks
// out (see `peek` in ui/Panel.qml); move away without touching it and it goes
// back.
//
// WHERE A STRIP IS NOT PUT, AND WHY
//   * On an INNER edge. With the laptop panel and an external monitor side by
//     side, the laptop's right edge and the monitor's left edge are the same
//     line, and the pointer crosses it every time it moves between screens. A
//     strip there would open a panel on every crossing. So a screen only gets
//     a strip on an edge that no other screen touches. Geometry comes from
//     Quickshell's own screen objects, not Hyprland's monitor records: Hyprland
//     sends no event when a surviving monitor MOVES, so after an undock its
//     record keeps the old x (this is what once parked the window-control dots
//     on the wrong edge). Quickshell's screen geometry does update.
//   * While a window is fullscreen. A game or a video pushed against the edge
//     must not pop a panel over itself.
//   * On the edge the dock lives on, if it is ever moved to the side: the dock
//     has its own reveal strip there.
//
// Gaps keep windows 10 px off every edge (looknfeel.lua gaps_out), so a
// scrollbar is never under a 3 px strip.
//
// COST
//   One tiny transparent layer surface per qualifying edge. It is never
//   painted; it exists to receive hover. The dwell Timer runs only while the
//   pointer is actually on it.
// =============================================================================

Scope {
    id: root

    // "left" | "right"
    required property string edge

    // The Shell panel name to peek.
    required property string target

    property bool enabled: true

    readonly property bool active: root.enabled && !Hypr.fullscreen
        && Settings.dock.position !== root.edge

    // True if no other screen shares this screen's `edge`.
    function isOuter(screen) {
        for (const other of Quickshell.screens) {
            if (other === screen) continue;
            const touches = root.edge === "left"
                ? other.x + other.width === screen.x
                : screen.x + screen.width === other.x;
            const overlaps = other.y < screen.y + screen.height
                && screen.y < other.y + other.height;
            if (touches && overlaps) return false;
        }
        return true;
    }

    Variants {
        model: root.active ? Quickshell.screens.filter(s => root.isOuter(s)) : []

        PanelWindow {
            id: strip

            required property var modelData

            screen: strip.modelData
            visible: true
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "qs-edge-" + root.edge
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            // Anchored to one edge only, so the compositor centres it along
            // that edge -- which is where a short edge panel sits too.
            anchors.left: root.edge === "left"
            anchors.right: root.edge === "right"
            implicitWidth: Appearance.edgeTrigger
            implicitHeight: Math.round(strip.modelData.height * 0.25)

            HoverHandler {
                id: hover

                onHoveredChanged: {
                    if (hover.hovered) Shell.edgeHover = root.target;
                    else if (Shell.edgeHover === root.target) Shell.edgeHover = "";
                }
            }

            Timer {
                interval: Appearance.hoverRevealDelay
                running: hover.hovered
                onTriggered: Shell.peek(root.target, strip.modelData)
            }

            Component.onDestruction: if (Shell.edgeHover === root.target) Shell.edgeHover = ""
        }
    }
}
