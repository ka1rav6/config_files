import QtQuick
import QtQuick.Particles
import Quickshell
import Quickshell.Wayland
import qs

// =============================================================================
// Cursor effects — trail, click effect, and a ring visualizer round the pointer.
// =============================================================================
// One transparent, click-through overlay per screen. The pointer position comes
// from services/Pointer.qml (the qs-pointer Hyprland plugin); without the
// plugin this is never loaded (see the Loader in shell.qml).
//
// COST
//   Qt only renders a frame when something on it changed, so an overlay with a
//   still pointer and no music costs nothing per frame. The trail animates only
//   while the pointer moves (plus the ~0.2 s it takes to shrink away); a click
//   effect animates for under half a second; the ring animates only while music
//   is actually playing. Every effect is off by default.
//
//   It is never loaded in Battery Saver (with "stop animations" on), in game
//   mode, or with motion turned off -- see the Loader in shell.qml.
// =============================================================================
Scope {
    id: root

    // The same colour the pointer itself is drawn in (services/CursorTheme).
    readonly property color tint: {
        const c = CursorTheme.color;

        if (!Pointer.inverted)
            return c;

        return Qt.rgba(
            1.0 - c.r,
            1.0 - c.g,
            1.0 - c.b,
            c.a
        );
    }

    readonly property bool trailOn: Settings.cursor.trail !== "off"
    // While the pointer is inverted the plugin draws the trail, inverted the
    // same way, so the two are always one colour; this layer's trail hides.
    readonly property bool pluginTrail: Pointer.inverted && Pointer.drawsTrail
    readonly property real trailLife: 90 + Settings.cursor.trailLength * 260
    // As wide as the pointer itself (the accent dot is a fifth of the cursor
    // size), so the trail reads as the cursor streaking.
    readonly property real trailHead: Math.max(4, Settings.cursor.size * (CursorTheme.isAccent ? 0.22 : 0.3))
    readonly property bool clickOn: Settings.cursor.click !== "off"
    readonly property bool ringOn: Settings.cursor.ring

    // The ring only needs the spectrum while something is playing.
    readonly property bool ringLive: root.ringOn && Media.playing
    readonly property string cavaId: "cursor-ring"
    onRingLiveChanged: root.ringLive ? Cava.want(root.cavaId, 48) : Cava.drop(root.cavaId)

    // Ask the plugin for exactly what is on.
    Binding { target: Pointer; property: "wantTrack"; value: root.trailOn || root.clickOn || root.ringOn }
    Binding { target: Pointer; property: "wantClicks"; value: root.clickOn }
    Binding { target: Pointer; property: "trailMode"; value: root.trailOn ? Settings.cursor.trail : "off" }
    Binding { target: Pointer; property: "trailLife"; value: root.trailLife }
    Binding { target: Pointer; property: "trailHead"; value: root.trailHead }

    Component.onCompleted: if (root.ringLive) Cava.want(root.cavaId, 48)
    Component.onDestruction: {
        Cava.drop(root.cavaId);
        Pointer.wantTrack = false;
        Pointer.wantClicks = false;
        Pointer.trailMode = "off";
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData
            screen: modelData

            // Pointer in this screen's local coordinates.
            readonly property real cx: Pointer.x - (modelData.x ?? 0)
            readonly property real cy: Pointer.y - (modelData.y ?? 0)
            readonly property bool here: cx >= 0 && cy >= 0 && cx < width && cy < height

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-cursorfx"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            // ---- trail -----------------------------------------------------
            // A short history of where the pointer was; each point lives for
            // `life` ms. Gaps from fast flicks are filled in so the comet stays
            // one continuous ribbon.
            Item {
                id: trail

                anchors.fill: parent
                visible: root.trailOn && !root.pluginTrail

                readonly property string mode: Settings.cursor.trail
                readonly property real life: root.trailLife
                readonly property int maxPoints: 40
                readonly property real head: root.trailHead
                readonly property real spacing: mode === "dots" ? Math.max(10, head * 1.6) : Math.max(2, head * 0.3)

                property var points: []      // [{x, y, t}]
                property double now: 0

                function add(x, y) {
                    const t = Date.now();
                    const pts = trail.points.filter(p => t - p.t < trail.life);
                    const last = pts.length ? pts[pts.length - 1] : null;
                    if (last) {
                        const dx = x - last.x, dy = y - last.y;
                        const dist = Math.sqrt(dx * dx + dy * dy);
                        if (dist < trail.spacing) return;
                        const steps = Math.min(12, Math.floor(dist / trail.spacing));
                        for (let i = 1; i < steps; i++)
                            pts.push({ x: last.x + dx * i / steps, y: last.y + dy * i / steps, t: last.t + (t - last.t) * i / steps });
                    }
                    pts.push({ x: x, y: y, t: t });
                    trail.points = pts.slice(-trail.maxPoints);
                    trail.now = t;
                }

                Connections {
                    target: Pointer
                    enabled: trail.visible && panel.here
                    // The overlay draws a frame behind Hyprland's pointer, so
                    // the head leads by ~a frame along the current velocity.
                    function onMoved() { trail.add(panel.cx + Pointer.vx * 14, panel.cy + Pointer.vy * 14); }
                }

                // Only runs while there is something left to fade.
                FrameAnimation {
                    running: trail.visible && trail.points.length > 0 && trail.mode !== "sparks"
                    onTriggered: {
                        trail.now = Date.now();
                        const alive = trail.points.filter(p => trail.now - p.t < trail.life);
                        if (alive.length !== trail.points.length) trail.points = alive;
                    }
                }

                Repeater {
                    model: trail.mode === "sparks" ? 0 : trail.maxPoints

                    Rectangle {
                        required property int index
                        readonly property var p: trail.points[trail.points.length - 1 - index]
                        // 1 at the head, falling to 0 at the end of its life.
                        readonly property real k: p ? Math.max(0, 1 - (trail.now - p.t) / trail.life) : 0
                        readonly property real d: trail.mode === "dots" ? trail.head * 0.55 * (0.4 + 0.6 * k)
                                                                        : trail.head * k

                        visible: !!p && k > 0
                        width: d
                        height: d
                        radius: d / 2
                        x: (p ? p.x : 0) - d / 2
                        y: (p ? p.y : 0) - d / 2
                        color: root.tint
                        opacity: (trail.mode === "dots" ? 0.9 : 0.85) * Math.sqrt(k)
                    }
                }

                // Sparks: particles shed from the pointer while it moves.
                ParticleSystem {
                    id: sparks
                    running: trail.mode === "sparks" && trail.visible
                }

                ImageParticle {
                    system: sparks
                    source: "qrc:///particleresources/glowdot.png"
                    color: root.tint
                    colorVariation: 0.15
                    alpha: 0.9
                    entryEffect: ImageParticle.Fade
                }

                Emitter {
                    id: sparkEmitter
                    system: sparks
                    enabled: false
                    x: panel.cx
                    y: panel.cy
                    emitRate: 140
                    lifeSpan: 160 + Settings.cursor.trailLength * 500
                    lifeSpanVariation: 120
                    size: 7
                    sizeVariation: 4
                    endSize: 1
                    velocity: AngleDirection { angleVariation: 360; magnitude: 40; magnitudeVariation: 30 }
                    acceleration: PointDirection { y: 60 }
                }

                // Emit only while moving: stop a beat after the last move.
                Connections {
                    target: Pointer
                    enabled: trail.mode === "sparks" && trail.visible && panel.here
                    function onMoved() { sparkEmitter.enabled = true; sparkStop.restart(); }
                }
                Timer {
                    id: sparkStop
                    interval: 60
                    onTriggered: sparkEmitter.enabled = false
                }
            }

            // ---- click effect ----------------------------------------------
            // A small pool, so quick double clicks each get their own effect.
            Item {
                id: clicks

                anchors.fill: parent
                visible: root.clickOn
                property int next: 0

                Connections {
                    target: Pointer
                    enabled: root.clickOn && panel.here
                    function onPressed() {
                        const fx = pool.itemAt(clicks.next);
                        clicks.next = (clicks.next + 1) % pool.count;
                        if (fx) fx.play(panel.cx, panel.cy);
                    }
                }

                Repeater {
                    id: pool
                    model: 4

                    Item {
                        id: fx

                        required property int index
                        property real t: 1
                        readonly property string mode: Settings.cursor.click
                        readonly property real reach: Math.max(18, Settings.cursor.size * 1.1)

                        visible: t < 1
                        width: 0
                        height: 0

                        function play(px, py) {
                            fx.x = px;
                            fx.y = py;
                            anim.duration = fx.mode === "burst" ? 420 : fx.mode === "pop" ? 260 : 380;
                            anim.restart();
                        }

                        NumberAnimation {
                            id: anim
                            target: fx
                            property: "t"
                            from: 0
                            to: 1
                            easing.type: Easing.OutCubic
                        }

                        // ripple: an expanding ring
                        Rectangle {
                            visible: fx.mode === "ripple"
                            readonly property real d: fx.reach * 2 * (0.25 + 0.75 * fx.t)
                            width: d; height: d; radius: d / 2
                            x: -d / 2; y: -d / 2
                            color: "transparent"
                            border.color: root.tint
                            border.width: Math.max(1.5, 3 * (1 - fx.t))
                            opacity: 1 - fx.t
                        }

                        // pop: a soft filled disc that swells and fades
                        Rectangle {
                            visible: fx.mode === "pop"
                            readonly property real d: fx.reach * (0.5 + 1.0 * fx.t)
                            width: d; height: d; radius: d / 2
                            x: -d / 2; y: -d / 2
                            color: root.tint
                            opacity: 0.45 * (1 - fx.t)
                        }

                        // burst: eight dots thrown outward
                        Repeater {
                            model: fx.mode === "burst" ? 8 : 0
                            Rectangle {
                                required property int index
                                readonly property real a: index * Math.PI / 4
                                readonly property real r: fx.reach * (0.2 + 0.9 * fx.t)
                                readonly property real d: Math.max(1.5, 5 * (1 - fx.t))
                                width: d; height: d; radius: d / 2
                                x: Math.cos(a) * r - d / 2
                                y: Math.sin(a) * r - d / 2
                                color: root.tint
                                opacity: 1 - fx.t
                            }
                        }
                    }
                }
            }

            // ---- ring visualizer -------------------------------------------
            Item {
                id: ring

                visible: root.ringLive && panel.here && Cava.active
                x: panel.cx
                y: panel.cy
                width: 0
                height: 0

                readonly property int n: 36
                readonly property string style: Settings.cursor.ringStyle
                readonly property real radius: Settings.cursor.ringRadius
                readonly property real reach: Math.max(8, Settings.cursor.ringRadius * 0.7)

                opacity: visible ? 0.85 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: ring.visible ? ring.n : 0

                    Item {
                        required property int index
                        // Sample the spectrum evenly, mirrored so the ring is
                        // symmetric left to right (bass at the top).
                        readonly property int band: {
                            const len = Cava.levels.length;
                            if (len === 0) return 0;
                            const half = ring.n / 2;
                            const i = index < half ? index : ring.n - 1 - index;
                            return Math.min(len - 1, Math.floor(i / half * len * 0.75));
                        }
                        readonly property real level: Cava.levels[band] || 0

                        rotation: index * 360 / ring.n
                        width: 0
                        height: 0

                        Rectangle {
                            readonly property bool dot: ring.style === "dots"
                            readonly property real len: dot ? 3.5 : Math.max(2, level * ring.reach)
                            width: dot ? 3.5 : 2.5
                            height: len
                            radius: width / 2
                            x: -width / 2
                            y: dot ? -ring.radius - level * ring.reach - len : ring.style === "wave"
                                ? -ring.radius - len / 2 : -ring.radius - len
                            color: root.tint
                        }
                    }
                }
            }
        }
    }
}
