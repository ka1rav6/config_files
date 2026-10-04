import QtQuick
import qs

// =============================================================================
// CmdToast — did that work, and if not, why.
// =============================================================================
// Every run gets one of these. The rules are asymmetric on purpose:
//
//   SUCCESS fades after a few seconds. You already know it worked, because the
//   thing you asked for happened; the toast exists to close the loop on
//   commands whose effect is not visible from here (a backup, a portal
//   restart).
//
//   FAILURE STAYS. It does not time out, it keeps its output, and it has to be
//   dismissed. A command that failed and then quietly disappeared is worse
//   than no feedback at all: it teaches you the panel is unreliable rather than
//   that the command is.
//
// WHY NOT mako
//   It would be the obvious integration -- there is a notification daemon
//   right there, themed by the same theme-switch. Two reasons not to:
//
//     * mako's notifications are themed by theme-switch but they are not THIS
//       surface. A failure toast needs a "Show output" button that opens the
//       panel's own output view, and a notification cannot reach back into the
//       panel it came from.
//     * Do Not Disturb is one of the commands in this panel. A DND toggle
//       whose own confirmation is swallowed by DND is a trap, and special-
//       casing it would mean this panel's notifications were the ones that
//       ignore the user's quiet hours.
//
//   mako keeps everything it already handles. This is scoped to the one thing
//   it cannot do: speak for a surface that is on screen.
//
// Only ever one toast. Commands are serialised by CommandRunner, so a second
// result replacing the first is the correct behaviour -- a stack of toasts in
// a panel this size would cover the thing you were reading.
// =============================================================================

Item {
    id: root

    property string commandId: ""
    property string title: ""
    property string message: ""
    property string tone: "good"

    readonly property bool showing: root.title !== ""
    readonly property bool failed: root.tone === "bad"

    // Whether the run behind this toast left any output worth opening.
    readonly property bool hasOutput: {
        if (root.commandId === "") return false;
        const run = CommandRunner.lastRun(root.commandId);
        return !!run && !run.detached
            && ((run.stdout || "") !== "" || (run.stderr || "") !== "");
    }

    signal showOutput(string commandId)

    function show(id, title, message, tone) {
        root.commandId = id;
        root.title = title;
        root.message = message;
        root.tone = tone;

        // A success toast is transient; a failure has to be read. An "idle"
        // toast ("Applying catppuccin…") is progress and is superseded by the
        // real result, so it gets the long timeout as a safety net in case the
        // result never arrives.
        if (tone === "bad") life.stop();
        else { life.interval = tone === "idle" ? 12000 : 3600; life.restart(); }
    }

    function dismiss() {
        life.stop();
        root.title = "";
        root.message = "";
        root.commandId = "";
    }

    Timer {
        id: life
        interval: 3600
        onTriggered: root.dismiss()
    }

    readonly property color toneColour: CommandState.toneColour(root.tone)

    // Derived from the content, NOT from the card -- the card is anchored to
    // this item's edges, so `implicitHeight: card.height` would be a binding
    // loop (height depends on the card, the card's geometry depends on height).
    implicitHeight: Math.max(Appearance.controlHeight,
                             toastBody.implicitHeight + Appearance.sm * 2)

    visible: opacity > 0
    opacity: root.showing ? 1 : 0

    Behavior on opacity {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationNormal
            easing.type: Appearance.easeStandard
        }
    }

    Card {
        id: card

        elevation: 2
        anchors.fill: parent

        // Tinted ground rather than a coloured border: at this size a 1px
        // border is hard to attribute and a wash is unmissable.
        color: Theme.wash(root.toneColour, 0.14)
        borderColor: Theme.wash(root.toneColour, 0.4)

        // Rises into place. The fade alone reads as a glitch at this size.
        transform: Translate {
            y: root.showing ? 0 : 10

            Behavior on y {
                enabled: !Appearance.motionless
                NumberAnimation {
                    duration: Appearance.durationNormal
                    easing.type: Appearance.easeEnter
                }
            }
        }

        Icon {
            id: toastIcon

            name: root.failed ? "close" : root.tone === "idle" ? "refresh" : "check"
            size: Appearance.iconSize
            color: root.toneColour
            anchors.left: parent.left
            anchors.leftMargin: Appearance.md
            anchors.verticalCenter: parent.verticalCenter

            // The progress toast spins slowly, so "applying" does not look
            // like "applied".
            RotationAnimation on rotation {
                running: root.tone === "idle" && root.showing && !Appearance.motionless
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1600
            }
        }

        Column {
            id: toastBody

            anchors.left: toastIcon.right
            anchors.leftMargin: Appearance.sm
            anchors.right: actions.left
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.title
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
                font.weight: Appearance.weightMedium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.message !== ""
                text: root.message
                color: root.failed ? Theme.error : Theme.muted
                font.family: root.failed ? Appearance.fontMono : Appearance.font
                font.pixelSize: Appearance.fontSmall
                elide: Text.ElideRight
            }
        }

        Row {
            id: actions

            anchors.right: parent.right
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.xs

            Button {
                visible: root.hasOutput
                text: "Show output"
                variant: "ghost"
                onClicked: root.showOutput(root.commandId)
            }

            Button {
                icon: "close"
                variant: "ghost"
                onClicked: root.dismiss()
            }
        }
    }
}
