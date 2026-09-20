import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// =============================================================================
// Audio visualizer — real spectrum bars on the desktop.  SUPER + SHIFT + B
// =============================================================================
// The data is genuine FFT from cava (see services/Cava.qml for the pipeline and
// the gating). This file is only the renderer.
//
// WHERE IT SITS
//   WlrLayer.Bottom: above the wallpaper, below every window, on every
//   workspace. `mask: Region {}` makes it entirely click-through, and
//   ExclusionMode.Ignore means it never reserves space, so windows tile exactly
//   as they did before. Turning it on cannot change your layout.
//
//   Deliberately NOT given a blur layer rule in ~/.config/hypr/rules.lua: there
//   is nothing behind it but the wallpaper, so blurring would be wasted work.
//
// -----------------------------------------------------------------------------
// WHY A Repeater OF RECTANGLES AND NOT A Canvas
//
// A Canvas looks like the right tool -- one node, one path, one fill, instead
// of a hundred items. It is catastrophically the wrong one here. Measured on
// this machine (Intel Lunar Lake, Mesa 25.2), one surface, 60 Hz:
//
//     Canvas, FramebufferObject + Threaded, 160 bands   140 % CPU
//     Canvas, FramebufferObject + Threaded,  96 bands   139 % CPU
//     Canvas, Image + Cooperative,          160 bands     1.6 %
//     Repeater of Rectangles,               160 bands    15   %
//
// The band count barely moved the FBO figure, which is the tell: with a
// framebuffer render target the cost is per FRAME, not per primitive -- a
// full-width texture re-rendered and re-uploaded sixty times a second, and on
// this driver that pegs multiple cores. Changing rect to roundedRect made no
// difference, because drawing was never the expensive part.
//
// (The 1.6 % Image-target figure is not reproducible under load and is not
// trusted. The Repeater was chosen because the scene graph updates geometry
// nodes in a batch without touching a texture, and because it gets rounded
// corners, per-bar colour and opacity for free.)
//
// WHAT IT ACTUALLY COSTS, AND WHY THAT IS ACCEPTABLE
//   Sweeping the real structure, one surface:
//
//                    62 Hz     45 Hz     30 Hz
//       160 bands    15.0 %    10.7 %     7.4 %
//        96 bands    12.7 %     9.3 %     6.0 %
//        64 bands    11.6 %     8.0 %     5.4 %
//
//   Frame rate dominates; band count barely matters. The fixed per-frame cost
//   is a full-monitor-width surface being damaged and recomposited, which is
//   also why Hyprland itself shows ~7 % alongside this.
//
//   60 Hz and 160 bands are kept anyway, because a visualiser that stutters is
//   not worth having and thin bars are the point of the design. What makes
//   that affordable is that it runs almost never:
//
//     * nothing playing            -> no cava process, no surface   (0.12 %)
//     * desktop covered by a window-> no cava process, no surface   (0.12 %)
//     * battery                    -> 30 Hz automatically            (7.4 %)
//
//   So the 15 % is paid only while music is playing AND the wallpaper is
//   actually on screen -- which is exactly when you want it.
//
// WHY IT STOPS WHEN NOTHING CAN SEE IT
//   This layer is below every window. On a tiling compositor a workspace with
//   one tiled window on it hides the bars completely, and rendering pixels
//   behind an opaque window is the most obviously wasted work a shell can do.
//   The surface list is filtered to outputs whose wallpaper is visible
//   (Hypr.desktopVisibleOn), and when no output qualifies the Cava demand is
//   released too, so the FFT process stops as well.
//
//   Floating windows do NOT suppress it: they leave the desktop showing around
//   them, and the scratchpad terminals are translucent Ghostty with blur, so
//   the visualiser genuinely is visible through them.
// -----------------------------------------------------------------------------

Scope {
    id: root

    // A stable id for the Cava demand refcount. One visualizer, one demand.
    readonly property string cavaId: "desktop-visualizer"

    readonly property bool wanted: Settings.features.musicVisualizer
        && Settings.desktop.visualizer
        && Performance.allowVisualizer
        // No output is showing its wallpaper, so there is nothing to draw on.
        // Releasing the demand here stops the cava PROCESS as well as the
        // rendering -- the FFT is pointless if the result cannot be seen.
        && (!Settings.visualizer.onlyWhenVisible || Hypr.anyDesktopVisible)

    onWantedChanged: {
        if (root.wanted) {
            Cava.want(root.cavaId, Settings.visualizer.bands);
        } else {
            Cava.drop(root.cavaId);
            // Nothing to fade out to -- drop the surface immediately rather
            // than lingering for an animation nobody asked for.
            fadeOut.stop();
        }
    }

    // Band count is a live setting. Cava debounces the restart, so dragging the
    // slider does not respawn the process on every frame.
    Connections {
        target: Settings.visualizer
        function onBandsChanged() {
            if (root.wanted) Cava.want(root.cavaId, Settings.visualizer.bands);
        }
    }

    Component.onCompleted: if (root.wanted) Cava.want(root.cavaId, Settings.visualizer.bands)
    Component.onDestruction: Cava.drop(root.cavaId)

    // Is there anything worth drawing? `Cava.active` goes false after a moment
    // with no movement, which covers both silence and the gap between tracks.
    readonly property bool showing: root.wanted && (Cava.active || fadeOut.running)

    // Holds the surface alive through the exit animation, then lets it go.
    Timer {
        id: fadeOut

        interval: Appearance.durationSlower + 60
        running: false
    }

    Connections {
        target: Cava
        function onActiveChanged() {
            if (Cava.active) fadeOut.stop();
            else if (root.wanted) fadeOut.restart();
        }
    }

    Variants {
        // Empty in silence: no window, no items, nothing. Filtered to the
        // outputs whose wallpaper is actually visible -- see the header.
        model: !root.showing ? []
            : Settings.visualizer.onlyWhenVisible
                ? Quickshell.screens.filter(s => Hypr.desktopVisibleOn(s))
                : Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            screen: panel.modelData
            visible: true
            color: "transparent"

            // "mirror" is a free-floating band lifted clear of the bottom edge;
            // "bars" grow out of the edge and must touch it.
            anchors { bottom: true; left: true; right: true }
            implicitHeight: Settings.visualizer.height
            margins.bottom: Settings.visualizer.style === "mirror"
                ? Settings.visualizer.offset : 0

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "qs-visualizer"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            // Never takes a click from the desktop.
            mask: Region {}

            Item {
                id: field

                anchors.fill: parent

                readonly property int count: Cava.levels.length
                readonly property bool mirror: Settings.visualizer.style === "mirror"

                // Derive the bar width from the output so the row spans it
                // exactly, whatever the band count or monitor.
                readonly property real gap: Settings.visualizer.barGap
                readonly property real barWidth: {
                    const configured = Settings.visualizer.barWidth;
                    if (configured > 0) return configured;
                    if (field.count <= 0) return 2;
                    return Math.max(1, (field.width - field.gap * (field.count - 1)) / field.count);
                }
                readonly property real total: field.count * field.barWidth
                    + field.gap * Math.max(0, field.count - 1)
                readonly property real originX: (field.width - field.total) / 2

                // Fades in on the first frame of audio and out when the bars
                // stop moving; the surface is destroyed shortly after.
                opacity: Cava.active ? 1 : 0

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: Appearance.durationSlower
                        easing.type: Appearance.easeStandard
                    }
                }

                Repeater {
                    model: field.count

                    Rectangle {
                        required property int index

                        // The level for this band. Read once into a property so
                        // the two geometry bindings below share one lookup.
                        readonly property real level: Cava.levels[index] || 0

                        // Half-height for mirror, full height for bars.
                        readonly property real extent: field.mirror
                            ? Math.max(field.barWidth / 2, level * field.height / 2)
                            : Math.max(2, level * field.height)

                        x: field.originX + index * (field.barWidth + field.gap)
                        width: field.barWidth

                        height: field.mirror ? extent * 2 : extent
                        y: field.mirror ? (field.height / 2 - extent) : (field.height - extent)

                        // Full pill in mirror mode -- a bar floating in the
                        // middle of the screen has no edge to grow out of.
                        // Bars mode keeps the configured radius so they stay
                        // attached to the screen edge.
                        radius: field.mirror
                            ? field.barWidth / 2
                            : Math.min(Settings.visualizer.radius, field.barWidth / 2)

                        // The gradient across the row, resolved from the index
                        // rather than recomputed per frame -- this binding only
                        // re-evaluates when the theme or the band count change,
                        // never when the level does.
                        color: {
                            const t = field.count > 1 ? index / (field.count - 1) : 0;
                            const from = t < 0.5 ? Theme.accent : Theme.accent2;
                            const to = t < 0.5 ? Theme.accent2 : Theme.accent3;
                            const u = t < 0.5 ? t * 2 : (t - 0.5) * 2;
                            return Qt.rgba(from.r + (to.r - from.r) * u,
                                           from.g + (to.g - from.g) * u,
                                           from.b + (to.b - from.b) * u,
                                           1);
                        }

                        opacity: Settings.visualizer.barOpacity

                        // Deliberately NO Behavior on height or y. The levels
                        // arrive at 60 Hz already smoothed (asymmetric fall, in
                        // services/Cava.qml); animating on top of that makes the
                        // bars lag behind what you are hearing, and it would put
                        // an animation object on every bar.
                    }
                }
            }
        }
    }
}
