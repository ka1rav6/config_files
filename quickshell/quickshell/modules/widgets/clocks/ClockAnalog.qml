import QtQuick
import qs

// =============================================================================
// ClockAnalog — a round face with hour, minute and second hands.
// =============================================================================
// Frameless (`bare`): it draws its own disc, because a round clock on a square
// card looks like a sticker. The Canvas repaints once a second -- when Time's
// clock ticks -- and never otherwise; that per-second tick is demanded only
// while this widget exists (see ClockDigital for the same rule).
// =============================================================================

DesktopWidget {
    id: root

    defaultX: 0.80
    defaultY: 0.08
    contentWidth: 188
    contentHeight: 188
    bare: true

    readonly property string consumer: "clock-analog-" + root.widgetId
    Component.onCompleted: Time.wantSeconds(root.consumer)
    Component.onDestruction: Time.dropSeconds(root.consumer)

    Canvas {
        id: face

        // The DesktopWidget slot is inset by a margin; the disc should fill
        // the whole widget, so step back out of it.
        anchors.fill: parent
        anchors.margins: -Appearance.md
        renderStrategy: Canvas.Cooperative

        readonly property date now: Time.now
        readonly property color disc: Theme.wash(Theme.surface, 0.82)
        readonly property color ink: Theme.text
        readonly property color accent: Theme.accent

        onNowChanged: face.requestPaint()
        onDiscChanged: face.requestPaint()
        onAccentChanged: face.requestPaint()

        onPaint: {
            const ctx = face.getContext("2d");
            ctx.reset();
            const cx = face.width / 2, cy = face.height / 2;
            const r = Math.min(cx, cy) - 2;

            ctx.fillStyle = face.disc;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.fill();

            // Twelve ticks; the quarters longer. (Not named `long`: that is a
            // reserved word in QML's JavaScript and fails to parse.)
            ctx.strokeStyle = Theme.wash(face.ink, 0.35);
            ctx.lineCap = "round";
            for (let i = 0; i < 12; i++) {
                const a = i / 12 * Math.PI * 2;
                const major = i % 3 === 0;
                ctx.lineWidth = major ? 3 : 1.5;
                const r1 = r - (major ? 16 : 11), r2 = r - 6;
                ctx.beginPath();
                ctx.moveTo(cx + Math.sin(a) * r1, cy - Math.cos(a) * r1);
                ctx.lineTo(cx + Math.sin(a) * r2, cy - Math.cos(a) * r2);
                ctx.stroke();
            }

            const d = face.now;
            const s = d.getSeconds(), m = d.getMinutes() + s / 60, h = (d.getHours() % 12) + m / 60;
            function hand(angle, len, width, colour) {
                ctx.strokeStyle = colour;
                ctx.lineWidth = width;
                ctx.beginPath();
                ctx.moveTo(cx - Math.sin(angle) * 10, cy + Math.cos(angle) * 10);
                ctx.lineTo(cx + Math.sin(angle) * len, cy - Math.cos(angle) * len);
                ctx.stroke();
            }
            hand(h / 12 * Math.PI * 2, r * 0.5, 5, face.ink);
            hand(m / 60 * Math.PI * 2, r * 0.75, 3.5, face.ink);
            hand(s / 60 * Math.PI * 2, r * 0.82, 1.5, face.accent);

            ctx.fillStyle = face.accent;
            ctx.beginPath();
            ctx.arc(cx, cy, 4, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
