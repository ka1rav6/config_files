import QtQuick
import qs

// =============================================================================
// CmdOutput — what the command actually printed.
// =============================================================================
// Several of these commands exist only for their output: `portal-check` is a
// report, `restore-check` is a listing, `qs-ipc` is documentation. Running them
// and showing a tick would be useless, so a command with `output: true` keeps
// its stdout and stderr and offers them here.
//
// IT IS NOT A TERMINAL
//   Read-only, selectable, monospaced, no input. The panel is a curated
//   launcher, and an output pane that could be typed into would be a shell by
//   the back door. This also means nothing here needs a terminal window --
//   which was the point of the whole exercise: `just portal-check` previously
//   required opening ghostty, and now it does not.
//
// stderr IS SHOWN SEPARATELY AND FIRST
//   Several of these scripts print progress to stdout and the actual problem to
//   stderr. Interleaving them in arrival order would be more faithful and far
//   less useful -- the question being asked of this pane is almost always "what
//   went wrong", and that is on stderr.
//
// WHY THERE IS NO "RUN AGAIN WITH -v"
//   There is nowhere to put the flag. Every command here is a fixed argv from
//   the registry, deliberately, because a GUI that lets you append arguments is
//   a GUI that can run anything. If a run needs flags, it needs a terminal, and
//   the CLI line at the top of this pane is the command to paste into one.
// =============================================================================

Item {
    id: root

    // The history entry to display, or null.
    property var run: null

    readonly property bool active: root.run !== null

    signal closed()

    readonly property var command: root.active ? CommandRegistry.get(root.run.id) : null

    visible: opacity > 0
    opacity: root.active ? 1 : 0

    Behavior on opacity {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationNormal
            easing.type: Appearance.easeStandard
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            enabled: root.active
            onClicked: root.closed()
        }
    }

    Card {
        id: sheet

        elevation: 2
        anchors.centerIn: parent
        width: parent.width - Appearance.xl * 2
        height: parent.height - Appearance.xl * 2

        MouseArea { anchors.fill: parent }

        transform: Translate {
            y: root.active ? 0 : 12

            Behavior on y {
                enabled: !Appearance.motionless
                NumberAnimation {
                    duration: Appearance.durationNormal
                    easing.type: Appearance.easeEnter
                }
            }
        }

        // --- header -----------------------------------------------------
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding
            height: headerText.implicitHeight

            Column {
                id: headerText

                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.rightMargin: Appearance.md
                spacing: 2

                Row {
                    width: parent.width
                    spacing: Appearance.sm

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.active && root.run.ok ? "check" : "close"
                        size: Appearance.iconSize
                        color: root.active && root.run.ok ? Theme.success : Theme.error
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.active ? root.run.label : ""
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontTitle
                        font.weight: Appearance.weightSemi
                        font.letterSpacing: Appearance.trackingHeading
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.active
                            ? (root.run.ok ? "exit 0" : "exit " + root.run.code)
                            : ""
                        color: root.active && root.run.ok ? Theme.muted : Theme.error
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption
                    }
                }

                // The command to paste into a terminal, which is where this
                // goes next if the output says something needs doing.
                Text {
                    width: parent.width
                    text: root.active ? root.run.cli : ""
                    color: Theme.muted
                    opacity: 0.7
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontCaption
                    elide: Text.ElideRight
                }
            }

            Button {
                id: closeButton

                anchors.right: parent.right
                anchors.top: parent.top
                icon: "close"
                variant: "ghost"
                onClicked: root.closed()
            }
        }

        // --- output -----------------------------------------------------
        Rectangle {
            id: pane

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.padding
            anchors.topMargin: Appearance.md

            radius: Appearance.radiusSmall
            color: Theme.wash(Theme.bg, 0.65)
            border.width: 1
            border.color: Theme.wash(Theme.border, 0.3)

            Flickable {
                id: scroll

                anchors.fill: parent
                anchors.margins: Appearance.sm
                contentWidth: width
                contentHeight: streams.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 4000

                Column {
                    id: streams

                    width: scroll.width
                    spacing: Appearance.sm

                    // stderr first: it is what the question is usually about.
                    Text {
                        width: parent.width
                        visible: root.active && (root.run.stderr || "") !== ""
                        text: root.active ? root.run.stderr.replace(/\n+$/, "") : ""
                        color: Theme.error
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        textFormat: Text.PlainText
                    }

                    Text {
                        width: parent.width
                        visible: root.active && (root.run.stdout || "") !== ""
                        text: root.active ? root.run.stdout.replace(/\n+$/, "") : ""
                        color: Theme.text
                        opacity: 0.9
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        textFormat: Text.PlainText
                    }

                    Text {
                        width: parent.width
                        visible: root.active
                            && (root.run.stdout || "") === ""
                            && (root.run.stderr || "") === ""
                        text: root.active && root.run.detached
                            ? "This command was started outside the shell's process tree, so its output is not captured here. Run it in a terminal to see it."
                            : "The command printed nothing."
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: (event) => { root.closed(); event.accepted = true; }

    focus: root.active
    onActiveChanged: if (root.active) root.forceActiveFocus()
}
