import QtQuick
import qs

// =============================================================================
// EqualizerCard — the Media page's equalizer.
// =============================================================================
// A switch, a row of presets, and ten bands you drag up and down, drawn over
// the curve they make. Everything here is a view of services/Equalizer.qml:
// it owns the audio routing, the persistence and the live updates, and the
// header of that file says how the EQ is wired into PipeWire.
//
// The bands stay editable while the EQ is off -- you can shape a curve first
// and switch it on to hear it -- but are dimmed, so it is obvious they are
// not doing anything yet.
//
// Dragging is ±12 dB in 0.5 dB steps. Double-click a band to put it back to 0.
// The curve repaints when the gains change and at no other time.
// =============================================================================

Card {
    id: root

    elevation: 0
    implicitHeight: column.implicitHeight + Appearance.md * 2

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.md
        spacing: Appearance.md

        // --- header -------------------------------------------------------------
        Item {
            width: parent.width
            implicitHeight: Appearance.controlHeight

            Icon {
                id: eqIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "equalizer"
                size: Appearance.iconSize
                color: Equalizer.enabled ? Theme.accent : Theme.muted
            }

            Column {
                anchors.left: eqIcon.right
                anchors.leftMargin: Appearance.sm
                anchors.right: eqToggle.left
                anchors.rightMargin: Appearance.sm
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: "EQUALIZER"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.weight: Appearance.weightMedium
                    font.letterSpacing: Appearance.trackingLabel
                }

                Text {
                    width: parent.width
                    text: !Equalizer.enabled ? "Off · " + Equalizer.preset
                        : Equalizer.active ? Equalizer.preset + " · on " + Equalizer.targetDescription
                        : "Starting…"
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                    elide: Text.ElideRight
                }
            }

            Toggle {
                id: eqToggle

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Equalizer.enabled
                onToggled: (v) => Equalizer.setEnabled(v)
            }
        }

        // --- presets ------------------------------------------------------------
        Flow {
            width: parent.width
            spacing: Appearance.xs

            Repeater {
                model: Equalizer.presetNames

                Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool current: Equalizer.preset === chip.modelData

                    width: chipText.implicitWidth + Appearance.md * 2
                    height: Appearance.controlHeightSmall
                    radius: height / 2
                    color: chip.current ? Theme.accent
                         : chipMouse.containsMouse ? Theme.wash(Theme.accent, 0.16)
                         : Theme.wash(Theme.text, 0.06)

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    Text {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData
                        color: chip.current ? Theme.onAccent(Theme.accent) : Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        font.weight: chip.current ? Appearance.weightSemi : Appearance.weightNormal
                    }

                    MouseArea {
                        id: chipMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Equalizer.applyPreset(chip.modelData)
                    }
                }
            }
        }

        // --- bands --------------------------------------------------------------
        Item {
            id: bands

            width: parent.width
            height: 190
            opacity: Equalizer.enabled ? 1 : 0.55

            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationNormal }
            }

            readonly property real labelHeight: 18
            readonly property real plotTop: 18
            readonly property real plotHeight: height - labelHeight - plotTop
            readonly property real colWidth: width / 10

            function yFor(db) {
                return bands.plotTop + (1 - (db + Equalizer.maxGain) / (2 * Equalizer.maxGain)) * bands.plotHeight;
            }

            // Grid and curve, behind the handles.
            Canvas {
                id: curve

                anchors.fill: parent
                renderStrategy: Canvas.Cooperative

                readonly property var gains: Equalizer.gains
                readonly property color tint: Theme.accent
                onGainsChanged: requestPaint()
                onTintChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    // 0 dB, ±6 dB guides.
                    for (const db of [-6, 0, 6]) {
                        ctx.strokeStyle = Theme.wash(Theme.text, db === 0 ? 0.16 : 0.07);
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        const y = Math.round(bands.yFor(db)) + 0.5;
                        ctx.moveTo(0, y);
                        ctx.lineTo(width, y);
                        ctx.stroke();
                    }

                    const pts = curve.gains.map((g, i) => ({
                        x: (i + 0.5) * bands.colWidth,
                        y: bands.yFor(g)
                    }));
                    function trace() {
                        ctx.moveTo(0, pts[0].y);
                        ctx.lineTo(pts[0].x, pts[0].y);
                        for (let i = 0; i < pts.length - 1; i++) {
                            const mx = (pts[i].x + pts[i + 1].x) / 2;
                            ctx.bezierCurveTo(mx, pts[i].y, mx, pts[i + 1].y, pts[i + 1].x, pts[i + 1].y);
                        }
                        ctx.lineTo(width, pts[pts.length - 1].y);
                    }

                    const zero = bands.yFor(0);
                    const grad = ctx.createLinearGradient(0, bands.plotTop, 0, bands.plotTop + bands.plotHeight);
                    grad.addColorStop(0, Theme.wash(curve.tint, 0.30));
                    grad.addColorStop(0.5, Theme.wash(curve.tint, 0.06));
                    grad.addColorStop(1, Theme.wash(curve.tint, 0.30));
                    ctx.fillStyle = grad;
                    ctx.beginPath();
                    trace();
                    ctx.lineTo(width, zero);
                    ctx.lineTo(0, zero);
                    ctx.closePath();
                    ctx.fill();

                    ctx.strokeStyle = curve.tint;
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    trace();
                    ctx.stroke();
                }
            }

            // One draggable column per band.
            Repeater {
                // Enumerated: delegates here cannot rely on an injected index.
                model: Equalizer.frequencies.map((f, i) => ({ i: i }))

                Item {
                    id: band

                    required property var modelData
                    readonly property int i: band.modelData.i
                    readonly property real gain: Equalizer.gains[band.i]

                    x: band.i * bands.colWidth
                    width: bands.colWidth
                    height: bands.height

                    // Track.
                    Rectangle {
                        x: (parent.width - width) / 2
                        y: bands.plotTop
                        width: 3
                        height: bands.plotHeight
                        radius: 1.5
                        color: Theme.wash(Theme.text, 0.08)
                    }

                    // Value while hovering or dragging.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        visible: dragArea.containsMouse || dragArea.pressed
                        text: (band.gain > 0 ? "+" : "") + band.gain.toFixed(1)
                        color: Theme.accent
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption - 1
                    }

                    // Handle.
                    Rectangle {
                        width: dragArea.pressed ? 18 : 14
                        height: width
                        radius: width / 2
                        x: (parent.width - width) / 2
                        y: bands.yFor(band.gain) - height / 2
                        color: Theme.accent
                        border.width: 3
                        border.color: Theme.wash(Theme.surface, 0.95)

                        Behavior on width {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationFast }
                        }
                        Behavior on y {
                            enabled: !Appearance.motionless && !dragArea.pressed
                            NumberAnimation { duration: Appearance.durationNormal; easing.type: Appearance.easeStandard }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: Equalizer.bandLabel(band.i)
                        color: Theme.muted
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption - 1
                    }

                    MouseArea {
                        id: dragArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        // The drawer's page scrolls; without this a vertical
                        // drag on a band is stolen to scroll the page instead.
                        preventStealing: true

                        function setFromY(y) {
                            const t = 1 - (y - bands.plotTop) / bands.plotHeight;
                            Equalizer.setBand(band.i, t * 2 * Equalizer.maxGain - Equalizer.maxGain);
                        }

                        onPressed: (mouse) => setFromY(mouse.y)
                        onPositionChanged: (mouse) => { if (pressed) setFromY(mouse.y); }
                        onDoubleClicked: Equalizer.setBand(band.i, 0)
                    }
                }
            }
        }
    }
}
