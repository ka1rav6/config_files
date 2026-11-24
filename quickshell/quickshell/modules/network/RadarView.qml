import QtQuick
import qs

// =============================================================================
// RadarView — every visible Wi-Fi network as a point on a radar.
// =============================================================================
// The idea is Anserin's (github.com/lukpednoi/Anserin, network/orbit): your
// router is the hub in the middle and each network is a node, so you see at a
// glance what is near, what is strong, and what you have been on before. None
// of its code is used. Anserin's version is an AGPL file set built around its
// own nmcli-polling store and a 60 fps physics loop; this one is written for
// this shell's event-driven services/Network.qml and draws only when something
// changed.
//
// HOW A NODE IS PLACED
//   Distance from the hub is signal strength: the strongest networks sit on
//   the inner ring, the faintest on the outer one. The rings are labelled, so
//   the picture doubles as a signal meter.
//
//   The angle is a hash of the SSID. Not random, and not by list position --
//   both of those would reshuffle every node on every scan result, which turns
//   a radar into noise. A hash means "home-5G" is always in the same direction,
//   scan after scan, session after session, and only its distance moves.
//
//   The field is an ellipse rather than a circle, to use a panel that is wider
//   than it is tall and to give it the tilted-disc look of the original.
//
//   Two networks can hash close together, so after placing, a few rounds of
//   pairwise repulsion push overlapping nodes apart. The connected network is
//   never pushed -- it is the one you are looking for, so everything else
//   moves out of its way.
//
// WHAT IT COSTS
//   * Layout runs only when the SET of networks or a node's signal bucket
//     changes (see `signature`). NetworkManager refreshes signal strength
//     constantly while scanning; a 1% wobble is not worth moving anything for,
//     so strengths are rounded to 5% buckets before deciding to re-layout.
//   * Movement is ONE animated number, `t`, that every node and the link canvas
//     interpolate against. So the canvas repaints for the ~0.4 s a move takes,
//     and not at all while nothing is moving. There is no per-frame loop.
//   * The rings are their own canvas and repaint only on resize -- i.e. once.
//   * The scan pulse is a transform-only animation (scale + opacity) on two
//     circles: composited, never repainted. It runs only while scanning is
//     actually on and motion is allowed (Performance.motionScale).
//   * The whole view exists only while the radar panel is open -- Panel tears
//     the window down on close, which takes all of the above with it.
// =============================================================================

Item {
    id: root

    // Name of the selected node, or "" for none. Owned by the parent so the
    // detail sheet and this view agree on it.
    property string selectedName: ""

    signal nodeClicked(string name)
    signal backgroundClicked()

    // More than this and the outer ring is just a cloud. The list arrives
    // connected-first, then saved, then by strength, so the cut drops the
    // faintest strangers first -- the ones nobody is about to join.
    readonly property int maxNodes: 22

    // --- geometry ---------------------------------------------------------

    readonly property real cx: root.width / 2
    readonly property real cy: root.height / 2

    // Room left at the sides for labels under the outermost nodes.
    readonly property real rx: Math.max(40, root.width / 2 - 64)
    readonly property real ry: Math.max(30, root.height / 2 - 30)

    readonly property real hubSize: 52

    // Normalised ring radius for a 0..1 signal. 0.3 keeps even a 100% network
    // clear of the hub; 1.0 is the outer edge.
    function ringFor(strength) {
        const s = Math.max(0, Math.min(1, strength));
        return 0.3 + (1 - s) * 0.7;
    }

    // djb2 over the SSID, folded into an angle. Any stable hash would do; this
    // one is four lines and spreads short similar names (home, home-5G) well.
    function angleFor(name) {
        let h = 5381;
        for (let i = 0; i < name.length; i++)
            h = ((h << 5) + h + name.charCodeAt(i)) | 0;
        return ((h >>> 0) % 3600) / 3600 * Math.PI * 2;
    }

    // --- layout ---------------------------------------------------------

    // The laid-out nodes: { name, strength, known, connected, locked,
    // x0, y0, x1, y1, links: [index, index] }. x0/y0 is where it was drawn
    // before this layout, x1/y1 where it is going; `t` runs between them.
    property var nodes: []
    property real t: 1

    // What the last layout was computed from. Re-layout only when this
    // changes, which is the whole of the "not on every signal tick" promise.
    property string signature: ""

    readonly property var source: Network.wifiEnabled
        ? Network.networks.slice(0, root.maxNodes) : []

    onSourceChanged: relayoutDebounce.restart()
    onWidthChanged: relayoutDebounce.restart()
    onHeightChanged: relayoutDebounce.restart()

    // Scan results arrive in bursts -- a dozen APs reporting within a few
    // hundred milliseconds. Waiting for the burst to settle means one move
    // instead of a dozen overlapping ones.
    Timer {
        id: relayoutDebounce

        interval: 300
        onTriggered: root.relayout(false)
    }

    Component.onCompleted: root.relayout(true)

    // Where a node is drawn right now, for the next layout to start from.
    function currentPosition(n) {
        return {
            x: n.x0 + (n.x1 - n.x0) * root.t,
            y: n.y0 + (n.y1 - n.y0) * root.t
        };
    }

    function relayout(force) {
        if (root.width <= 0 || root.height <= 0) return;

        const sig = root.source.map(n =>
            n.name + ":" + Math.round(n.signalStrength * 20)
            + (n.connected ? "c" : "") + (n.known ? "k" : "")
        ).join("|") + "@" + Math.round(root.width) + "x" + Math.round(root.height);

        if (!force && sig === root.signature) return;
        root.signature = sig;

        // Remember where everything currently is, so a node that was already
        // on screen glides from there rather than jumping.
        const previous = {};
        for (const n of root.nodes) previous[n.name] = root.currentPosition(n);

        const placed = root.source.map(n => {
            const r = root.ringFor(n.signalStrength);
            const a = root.angleFor(n.name);
            return {
                name: n.name,
                strength: n.signalStrength,
                known: n.known,
                connected: n.connected,
                locked: Network.needsPassphrase(n),
                x: root.cx + Math.cos(a) * r * root.rx,
                y: root.cy + Math.sin(a) * r * root.ry
            };
        });

        // Pairwise repulsion. N is at most maxNodes, so this is ~250 distance
        // checks a round, six rounds, once per layout -- nothing.
        const minGap = 44;
        for (let round = 0; round < 6; round++) {
            for (let i = 0; i < placed.length; i++) {
                for (let j = i + 1; j < placed.length; j++) {
                    const a = placed[i], b = placed[j];
                    let dx = b.x - a.x, dy = b.y - a.y;
                    let d = Math.sqrt(dx * dx + dy * dy);
                    if (d >= minGap) continue;
                    if (d < 0.01) { dx = 1; dy = 0; d = 1; }
                    const push = (minGap - d) / 2;
                    const ux = dx / d, uy = dy / d;
                    // The connected node is immovable; its neighbour takes
                    // the whole push instead of half.
                    if (a.connected) {
                        b.x += ux * push * 2; b.y += uy * push * 2;
                    } else if (b.connected) {
                        a.x -= ux * push * 2; a.y -= uy * push * 2;
                    } else {
                        a.x -= ux * push; a.y -= uy * push;
                        b.x += ux * push; b.y += uy * push;
                    }
                }
            }
            // Keep everything on the canvas and off the hub.
            for (const p of placed) {
                p.x = Math.max(18, Math.min(root.width - 18, p.x));
                p.y = Math.max(14, Math.min(root.height - 30, p.y));
                const hx = p.x - root.cx, hy = p.y - root.cy;
                const hd = Math.sqrt(hx * hx + hy * hy);
                const clear = root.hubSize / 2 + 22;
                if (hd < clear) {
                    const k = hd < 0.01 ? 1 : clear / hd;
                    p.x = root.cx + (hd < 0.01 ? clear : hx * k);
                    p.y = root.cy + (hd < 0.01 ? 0 : hy * k);
                }
            }
        }

        // The constellation lines: each node to its two nearest neighbours.
        // Computed from the FINAL positions, once, rather than per frame.
        for (let i = 0; i < placed.length; i++) {
            const dists = [];
            for (let j = 0; j < placed.length; j++) {
                if (i === j) continue;
                const dx = placed[j].x - placed[i].x, dy = placed[j].y - placed[i].y;
                dists.push({ j: j, d: dx * dx + dy * dy });
            }
            dists.sort((p, q) => p.d - q.d);
            placed[i].links = dists.slice(0, 2).map(e => e.j);
        }

        root.nodes = placed.map(p => {
            // New arrivals fly out of the hub, which reads as "just found".
            const from = previous[p.name] || { x: root.cx, y: root.cy };
            return {
                name: p.name,
                strength: p.strength,
                known: p.known,
                connected: p.connected,
                locked: p.locked,
                links: p.links,
                x0: from.x, y0: from.y,
                x1: p.x, y1: p.y
            };
        });

        settle.stop();
        if (Appearance.motionless) {
            root.t = 1;
        } else {
            root.t = 0;
            settle.start();
        }
        links.requestPaint();
    }

    NumberAnimation {
        id: settle

        target: root
        property: "t"
        from: 0
        to: 1
        duration: Appearance.durationSlower
        easing.type: Appearance.easeStandard
    }

    onTChanged: links.requestPaint()
    onSelectedNameChanged: links.requestPaint()

    // --- background: clicking empty space clears the selection --------------
    MouseArea {
        anchors.fill: parent
        onClicked: root.backgroundClicked()
    }

    // --- rings (static) -------------------------------------------------------
    Canvas {
        id: rings

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineWidth = 1;
            // Outermost first so the faint ones sit under the brighter ones.
            const steps = [0, 0.25, 0.5, 0.75];
            for (let i = 0; i < steps.length; i++) {
                const r = root.ringFor(steps[i]);
                ctx.strokeStyle = Theme.wash(Theme.text, 0.05 + i * 0.02);
                ctx.beginPath();
                ctx.ellipse(root.cx - r * root.rx, root.cy - r * root.ry,
                            r * root.rx * 2, r * root.ry * 2);
                ctx.stroke();
            }
        }
    }

    // Ring labels: the radar is also a signal meter. Text items rather than
    // fillText so they use the shell's font and theme like everything else.
    Repeater {
        model: [75, 50, 25]

        Text {
            required property var modelData

            x: root.cx + root.ringFor(modelData / 100) * root.rx + 4
            y: root.cy - height / 2
            text: modelData + "%"
            color: Theme.wash(Theme.muted, 0.55)
            font.family: Appearance.fontMono
            font.pixelSize: Appearance.fontCaption - 1
        }
    }

    // --- scan pulse -----------------------------------------------------------
    // Two rings leaving the hub, staggered, while the radio is scanning. Pure
    // scale/opacity, so the GPU composites it and nothing is repainted.
    Repeater {
        model: 2

        Rectangle {
            id: pulse

            required property int index

            readonly property bool active: Network.scanning && Network.wifiEnabled
                && !Appearance.motionless && root.visible

            width: root.ry * 2
            height: root.ry * 2
            x: root.cx - width / 2
            y: root.cy - height / 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.wash(Theme.accent, 0.7)
            opacity: 0
            scale: 0.1
            visible: pulse.active

            // Stretch the circle into the field's ellipse.
            transform: Scale {
                origin.x: pulse.width / 2
                origin.y: pulse.height / 2
                xScale: root.rx / root.ry
            }

            SequentialAnimation {
                running: pulse.active
                loops: Animation.Infinite

                PauseAnimation { duration: pulse.index * 1400 }
                ParallelAnimation {
                    NumberAnimation {
                        target: pulse; property: "scale"
                        from: 0.12; to: 1.0; duration: 2800
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: pulse; property: "opacity"
                        from: 0.45; to: 0; duration: 2800
                        easing.type: Easing.InQuad
                    }
                }
                PauseAnimation { duration: (1 - pulse.index) * 1400 }
            }
        }
    }

    // --- constellation lines -------------------------------------------------
    Canvas {
        id: links

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const pts = root.nodes.map(n => root.currentPosition(n));

            // Neighbour links: the "constellation". Drawn once per pair.
            ctx.lineWidth = 1;
            ctx.strokeStyle = Theme.wash(Theme.text, 0.09);
            ctx.beginPath();
            for (let i = 0; i < root.nodes.length; i++) {
                for (const j of root.nodes[i].links) {
                    if (j < i && root.nodes[j].links.indexOf(i) >= 0) continue;
                    ctx.moveTo(pts[i].x, pts[i].y);
                    ctx.lineTo(pts[j].x, pts[j].y);
                }
            }
            ctx.stroke();

            // Tethers to the hub: solid accent for the network you are on,
            // fainter for the one you are looking at.
            for (let i = 0; i < root.nodes.length; i++) {
                const n = root.nodes[i];
                const selected = n.name === root.selectedName;
                if (!n.connected && !selected) continue;
                ctx.lineWidth = n.connected ? 1.6 : 1;
                ctx.strokeStyle = Theme.wash(Theme.accent, n.connected ? 0.75 : 0.4);
                ctx.beginPath();
                ctx.moveTo(root.cx, root.cy);
                ctx.lineTo(pts[i].x, pts[i].y);
                ctx.stroke();
            }
        }
    }

    // --- the hub: this machine's radio -----------------------------------------
    Rectangle {
        id: hub

        width: root.hubSize
        height: root.hubSize
        x: root.cx - width / 2
        y: root.cy - height / 2
        radius: width / 2
        color: Theme.wash(Network.wifiEnabled ? Theme.accent : Theme.muted, 0.14)
        border.width: 1
        border.color: Theme.wash(Network.wifiEnabled ? Theme.accent : Theme.muted, 0.55)

        Icon {
            anchors.centerIn: parent
            name: !Network.wifiEnabled ? "wifi-off"
                : (Network.wiredConnected && !Network.wifiConnected) ? "ethernet"
                : "router"
            size: Appearance.iconSizeLarge
            color: Network.wifiEnabled ? Theme.accent : Theme.muted
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backgroundClicked()
        }
    }

    // --- nodes -----------------------------------------------------------------
    Repeater {
        // Delegates read only `modelData`, never `index` -- a Repeater over a
        // plain JS array does not inject `index`, and every delegate would
        // silently read 0. Each node carries everything it needs instead.
        model: root.nodes

        RadarNode {
            required property var modelData

            node: modelData
            t: root.t
            selected: modelData.name === root.selectedName
            onClicked: root.nodeClicked(modelData.name)
        }
    }

    // --- empty states --------------------------------------------------------
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + root.hubSize / 2 + Appearance.md
        visible: Network.wifiEnabled && root.nodes.length === 0
        text: "Searching for networks…"
        color: Theme.muted
        font.family: Appearance.font
        font.pixelSize: Appearance.fontSmall
    }
}
