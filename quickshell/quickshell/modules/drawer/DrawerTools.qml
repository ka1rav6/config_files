import QtQuick
import Quickshell
import qs
import "calc.js" as Calc

// =============================================================================
// DrawerTools — the drawer's Tools page: a countdown timer and a calculator.
// =============================================================================
// Anserin's quick actions, the two that earn a place on a laptop: "remind me
// in ten minutes" and "what is 18% of 2,340" without opening an app.
//
// TIMER
//   State lives on the Drawer panel (`drawer`), not here, so it keeps counting
//   with this page closed, the drawer closed, or another page showing. When it
//   ends it sends a notification. Presets for the usual lengths, or type
//   minutes and press Enter.
//
// CALCULATOR
//   Live result as you type; Enter commits it to the history and leaves the
//   answer in the box to keep going from. Parsing is calc.js -- a real
//   expression parser, deliberately not eval() of whatever was typed.
//   Clicking a history line puts its answer back in the box; the copy button
//   puts the current answer on the clipboard (wl-copy).
// =============================================================================

Column {
    id: root

    required property var drawer

    spacing: Appearance.lg

    readonly property var result: Calc.evaluate(field.text)

    function commit() {
        if (!root.result.ok) return;
        const line = { expr: field.text, value: String(root.result.value) };
        const next = [line];
        const old = root.drawer.calcHistory;
        for (let i = 0; i < old.length && next.length < 6; i++) next.push(old[i]);
        root.drawer.calcHistory = next;
        field.text = line.value;
    }

    PageHeader {
        title: "Tools"
        subtitle: root.drawer.timerRunning
            ? "Timer running · " + root.drawer.formatDuration(root.drawer.timerLeft) + " left"
            : "Utilities, a timer and a calculator"
    }

    // --- utilities ---------------------------------------------------------------
    // The same scripts and binaries the keybinds use, so a tile does exactly
    // what its key does. The ones that capture the screen wait a beat after the
    // drawer closes, or the drawer would be in the screenshot.
    Grid {
        width: parent.width
        columns: 3
        spacing: Appearance.sm

        readonly property real cell: (width - spacing * 2) / 3
        readonly property string hyprScripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"

        Repeater {
            model: [
                { icon: "camera",     label: "Screenshot",   hint: "SUPER + P",
                  run: ["sh", "-c", "sleep 0.4; exec \"$0\" region", Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot.sh"], close: true },
                { icon: "eyedropper", label: "Pick colour",  hint: "SUPER + I",
                  run: ["sh", "-c", "sleep 0.4; exec hyprpicker -a"], close: true },
                { icon: "record",     label: "Record",       hint: "SUPER + ALT + R",
                  run: [Quickshell.env("HOME") + "/.config/hypr/scripts/record.sh", "toggle"], close: true },
                { icon: "emoticon",   label: "Emoji",        hint: "SUPER + F2",   panel: "emoji" },
                { icon: "clipboard",  label: "Clipboard",    hint: "SUPER + V",
                  run: [Quickshell.env("HOME") + "/.config/hypr/scripts/wofi-launch.sh", "clip"], close: true },
                { icon: "lock",       label: "Lock",         hint: "SUPER + ESC",
                  run: [Quickshell.env("HOME") + "/.local/bin/lock-session"], close: true }
            ]

            Rectangle {
                id: util

                required property var modelData

                width: parent.cell
                height: 78
                radius: Appearance.radiusInner
                color: utilMouse.containsMouse ? Theme.wash(Theme.accent, 0.16) : Theme.wash(Theme.text, 0.05)
                scale: utilMouse.pressed ? 0.95 : 1

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }
                Behavior on scale {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationFast; easing.type: Appearance.easeStandard }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: util.modelData.icon
                        size: Appearance.iconSize
                        color: utilMouse.containsMouse ? Theme.accent : Theme.text
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: util.modelData.label
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: util.modelData.hint
                        color: Theme.muted
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption - 2
                    }
                }

                MouseArea {
                    id: utilMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (util.modelData.panel) {
                            Shell.open(util.modelData.panel);
                            return;
                        }
                        if (util.modelData.close) Shell.close("drawer");
                        Quickshell.execDetached(util.modelData.run);
                    }
                }
            }
        }
    }

    // --- timer -------------------------------------------------------------------
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: timerColumn.implicitHeight + Appearance.md * 2

        Column {
            id: timerColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: Appearance.md

            Row {
                spacing: Appearance.sm

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "timer"
                    size: Appearance.iconSize
                    color: Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TIMER"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.weight: Appearance.weightMedium
                    font.letterSpacing: Appearance.trackingLabel
                }
            }

            // A countdown exists (running or paused): show it.
            Column {
                width: parent.width
                spacing: Appearance.sm
                visible: root.drawer.timerLeft > 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.drawer.formatDuration(root.drawer.timerLeft)
                    color: root.drawer.timerRunning ? Theme.text : Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.size(44)
                    font.weight: Appearance.weightMedium
                    font.letterSpacing: Appearance.trackingDisplay
                    font.features: ({ "tnum": 1 })
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.wash(Theme.text, 0.08)

                    Rectangle {
                        width: root.drawer.timerTotal > 0
                            ? parent.width * root.drawer.timerLeft / root.drawer.timerTotal : 0
                        height: parent.height
                        radius: 3
                        color: Theme.accent

                        Behavior on width {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: 900; easing.type: Easing.Linear }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.sm

                    Button {
                        text: root.drawer.timerRunning ? "Pause" : "Resume"
                        icon: root.drawer.timerRunning ? "pause" : "play"
                        variant: "soft"
                        onClicked: root.drawer.timerRunning = !root.drawer.timerRunning
                    }

                    Button {
                        text: "Stop"
                        icon: "stop"
                        variant: "ghost"
                        onClicked: root.drawer.stopTimer()
                    }
                }
            }

            // No countdown: presets and a minutes box.
            Column {
                width: parent.width
                spacing: Appearance.sm
                visible: root.drawer.timerLeft <= 0

                Flow {
                    width: parent.width
                    spacing: Appearance.sm

                    Repeater {
                        model: [1, 5, 10, 15, 25, 45, 60]

                        Button {
                            required property var modelData

                            text: modelData + " min"
                            variant: "soft"
                            onClicked: root.drawer.startTimer(modelData * 60)
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Appearance.sm

                    Rectangle {
                        width: parent.width - startButton.width - Appearance.sm
                        height: Appearance.controlHeight
                        radius: Appearance.radiusInner
                        color: Theme.wash(Theme.bg, 0.6)
                        border.width: 1
                        border.color: minutes.activeFocus ? Theme.accent : Theme.wash(Theme.border, 0.4)

                        TextInput {
                            id: minutes

                            anchors.fill: parent
                            anchors.leftMargin: Appearance.sm
                            anchors.rightMargin: Appearance.sm
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontBody
                            validator: DoubleValidator { bottom: 0; top: 1440; decimals: 2 }
                            onAccepted: startButton.clicked()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: minutes.text === "" && !minutes.activeFocus
                                text: "Minutes, e.g. 7 or 0.5"
                                color: Theme.wash(Theme.muted, 0.7)
                                font: minutes.font
                            }
                        }
                    }

                    Button {
                        id: startButton

                        text: "Start"
                        variant: "accent"
                        enabled: Number(minutes.text) > 0
                        onClicked: {
                            const s = Math.round(Number(minutes.text) * 60);
                            if (s > 0) root.drawer.startTimer(s);
                            minutes.text = "";
                        }
                    }
                }
            }
        }
    }

    // --- calculator -----------------------------------------------------------------
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: calcColumn.implicitHeight + Appearance.md * 2

        Column {
            id: calcColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: Appearance.sm

            Row {
                spacing: Appearance.sm

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "calculator"
                    size: Appearance.iconSize
                    color: Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CALCULATOR"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.weight: Appearance.weightMedium
                    font.letterSpacing: Appearance.trackingLabel
                }
            }

            Rectangle {
                width: parent.width
                height: Appearance.controlHeight
                radius: Appearance.radiusInner
                color: Theme.wash(Theme.bg, 0.6)
                border.width: 1
                border.color: field.activeFocus ? Theme.accent : Theme.wash(Theme.border, 0.4)

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.sm
                    anchors.rightMargin: clearButton.width + Appearance.xs
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontLabel
                    selectByMouse: true
                    onAccepted: root.commit()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === "" && !field.activeFocus
                        text: "Type a sum, e.g. 2340 * 18 / 100"
                        color: Theme.wash(Theme.muted, 0.7)
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontBody
                    }
                }

                Button {
                    id: clearButton

                    anchors.right: parent.right
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    variant: "ghost"
                    icon: "backspace"
                    visible: field.text !== ""
                    onClicked: field.text = ""
                }
            }

            Item {
                width: parent.width
                implicitHeight: Appearance.controlHeight

                Text {
                    anchors.left: parent.left
                    anchors.right: copyButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.result.ok ? "= " + root.result.value
                        : (field.text !== "" && root.result.error !== "" ? root.result.error : "")
                    color: root.result.ok ? Theme.accent : Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: root.result.ok ? Appearance.fontTitle : Appearance.fontCaption
                    elide: Text.ElideRight
                }

                Button {
                    id: copyButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.result.ok
                    text: "Copy"
                    icon: "paste"
                    variant: "ghost"
                    // argv, so the value is one argument, never shell text.
                    onClicked: Quickshell.execDetached(["wl-copy", String(root.result.value)])
                }
            }

            Repeater {
                model: root.drawer.calcHistory

                Rectangle {
                    id: line

                    required property var modelData

                    width: calcColumn.width
                    height: Appearance.controlHeightSmall
                    radius: Appearance.radiusSmall
                    color: lineMouse.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: answer.left
                        anchors.leftMargin: Appearance.sm
                        anchors.rightMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.expr
                        color: Theme.muted
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption
                        elide: Text.ElideRight
                    }

                    Text {
                        id: answer

                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: "= " + line.modelData.value
                        color: Theme.text
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption
                    }

                    MouseArea {
                        id: lineMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: field.text = line.modelData.value
                    }
                }
            }
        }
    }
}
