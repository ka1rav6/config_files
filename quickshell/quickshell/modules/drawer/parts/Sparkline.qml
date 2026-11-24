import QtQuick
import qs

// =============================================================================
// Sparkline — a small area chart of recent values.
// =============================================================================
// `values` is a plain array of 0..1 numbers, oldest first; the chart is always
// scaled to `capacity` points so it scrolls left as samples arrive instead of
// stretching. A smooth line in `tint` over a fill that fades to nothing.
//
// It repaints when `values` is reassigned -- once per sample, i.e. once per
// SysInfo poll -- and at no other time. Callers append by building a new array
// (see the System page), because an in-place push would not notify.
// =============================================================================

Canvas {
    id: root

    property var values: []
    property int capacity: 60
    property color tint: Theme.accent
    // Fixed 0..1 scale, or fit to the largest value seen (network rates).
    property bool autoScale: false

    renderStrategy: Canvas.Cooperative

    onValuesChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = root.values;
        if (!v || v.length < 2) return;

        let top = 1;
        if (root.autoScale) {
            top = 0;
            for (const x of v) top = Math.max(top, x);
            if (top <= 0) top = 1;
            top *= 1.15;
        }

        const step = root.width / (root.capacity - 1);
        const x0 = root.width - (v.length - 1) * step;
        const pts = v.map((val, i) => ({
            x: x0 + i * step,
            y: root.height - 2 - Math.max(0, Math.min(1, val / top)) * (root.height - 4)
        }));

        // Midpoint quadratic smoothing: soft, and never overshoots the data.
        function trace() {
            ctx.moveTo(pts[0].x, pts[0].y);
            for (let i = 1; i < pts.length - 1; i++) {
                const mx = (pts[i].x + pts[i + 1].x) / 2, my = (pts[i].y + pts[i + 1].y) / 2;
                ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my);
            }
            const last = pts[pts.length - 1];
            ctx.lineTo(last.x, last.y);
        }

        const grad = ctx.createLinearGradient(0, 0, 0, root.height);
        grad.addColorStop(0, Theme.wash(root.tint, 0.35));
        grad.addColorStop(1, Theme.wash(root.tint, 0.0));
        ctx.fillStyle = grad;
        ctx.beginPath();
        trace();
        ctx.lineTo(pts[pts.length - 1].x, root.height);
        ctx.lineTo(pts[0].x, root.height);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = root.tint;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.beginPath();
        trace();
        ctx.stroke();
    }
}
