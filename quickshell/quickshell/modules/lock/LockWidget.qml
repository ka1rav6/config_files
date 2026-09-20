import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs

// =============================================================================
// LockWidget — the thing you actually interact with on the lock screen.
// =============================================================================
// An avatar ring, your name, and one field. The ring is the whole status
// display: it idles as a thin circle, sweeps while PAM is thinking, flashes red
// on a rejection and green the instant it succeeds. That means there is never a
// separate spinner, a separate error box and a separate success state competing
// for the same half-second of attention.
//
// AUTHENTICATION
//   PamContext against /etc/pam.d/hyprlock (`auth include login`), so this
//   accepts exactly what hyprlock accepts -- same policy, same fingerprint
//   reader rules if one is ever configured, nothing new to audit.
//
//   PAM is asynchronous and conversational: start() begins a transaction, PAM
//   asks a question through onPamMessage, and the answer goes back through
//   respond(). The password is therefore held only between Enter and that
//   callback, and cleared the moment PAM completes either way.
// =============================================================================

Item {
    id: root

    signal unlocked()

    implicitWidth: 330
    implicitHeight: column.implicitHeight

    readonly property string username: Quickshell.env("USER") || "user"

    // idle | authenticating | failed | success
    property string state_: "idle"
    property string notice: ""

    // Held only for the length of one PAM conversation.
    property string pending: ""

    function focusField() { field.forceActiveFocus(); }

    function submit() {
        if (root.state_ === "authenticating" || root.state_ === "success") return;
        if (field.text.length === 0) {
            root.reject("Enter your password");
            return;
        }
        root.pending = field.text;
        root.state_ = "authenticating";
        root.notice = "";
        if (!pam.start()) root.reject("Could not start authentication");
    }

    function reject(message) {
        root.pending = "";
        root.state_ = "failed";
        root.notice = message;
        field.text = "";
        shake.restart();
        recover.restart();
    }

    PamContext {
        id: pam

        // Reuse hyprlock's policy rather than installing a second one.
        config: "hyprlock"

        onPamMessage: {
            if (pam.responseRequired) pam.respond(root.pending);
        }

        onCompleted: (result) => {
            root.pending = "";
            if (result === PamResult.Success) {
                root.state_ = "success";
                root.notice = "";
                // Let the ring finish closing before the session comes back,
                // so unlocking reads as a completed action.
                release.start();
            } else if (result === PamResult.MaxTries) {
                root.reject("Too many attempts");
            } else {
                root.reject("Incorrect password");
            }
        }

        onError: (err) => root.reject("Authentication error")
    }

    Timer {
        id: release
        interval: 260
        onTriggered: root.unlocked()
    }

    // Clear the failure state so the field stops looking broken.
    Timer {
        id: recover
        interval: 2600
        onTriggered: if (root.state_ === "failed") { root.state_ = "idle"; root.notice = ""; }
    }

    Column {
        id: column

        width: parent.width
        spacing: Appearance.md

        // --- avatar and status ring ---------------------------------------
        Item {
            id: ringHost

            width: 104
            height: 104
            anchors.horizontalCenter: parent.horizontalCenter

            readonly property color statusColour: {
                switch (root.state_) {
                case "failed": return Theme.error;
                case "success": return Theme.success;
                default: return "white";
                }
            }

            // Idle ring. Always there, so the sweep has something to sit on.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 2
                border.color: Qt.rgba(ringHost.statusColour.r, ringHost.statusColour.g,
                                      ringHost.statusColour.b,
                                      root.state_ === "idle" ? 0.22 : 0.85)

                Behavior on border.color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationNormal }
                }
            }

            // The sweep. A rotating arc drawn once and spun by the scene graph,
            // rather than repainted every frame -- a Canvas redrawn at 60 Hz
            // for a spinner is the same mistake the visualiser already made
            // once on this desktop.
            Canvas {
                id: sweep

                anchors.fill: parent
                visible: root.state_ === "authenticating"
                renderStrategy: Canvas.Cooperative

                onPaint: {
                    const ctx = sweep.getContext("2d");
                    ctx.reset();
                    const c = sweep.width / 2;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = "white";
                    ctx.beginPath();
                    ctx.arc(c, c, c - 1, -Math.PI / 2, Math.PI * 0.55);
                    ctx.stroke();
                }

                RotationAnimator on rotation {
                    running: sweep.visible && !Appearance.motionless
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                }
            }

            Icon {
                anchors.centerIn: parent
                name: root.state_ === "success" ? "check"
                    : root.state_ === "failed" ? "close" : "user"
                size: 40
                color: ringHost.statusColour
                opacity: root.state_ === "authenticating" ? 0.4 : 1

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationFast }
                }
            }

            scale: root.state_ === "success" ? 1.08 : 1.0

            Behavior on scale {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationSlow; easing.type: Easing.OutBack }
            }
        }

        Text {
            text: root.username
            color: "white"
            font.family: Appearance.font
            font.pixelSize: Appearance.size(19)
            font.weight: Appearance.weightMedium
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // --- password field --------------------------------------------------
        Item {
            id: fieldHost

            width: parent.width
            height: 48
            anchors.horizontalCenter: parent.horizontalCenter

            // The shake. Small and fast -- a long wobble reads as a toy.
            SequentialAnimation {
                id: shake
                running: false
                loops: 1
                NumberAnimation { target: fieldHost; property: "anchors.horizontalCenterOffset"; to:  9; duration: 45 }
                NumberAnimation { target: fieldHost; property: "anchors.horizontalCenterOffset"; to: -8; duration: 65 }
                NumberAnimation { target: fieldHost; property: "anchors.horizontalCenterOffset"; to:  5; duration: 55 }
                NumberAnimation { target: fieldHost; property: "anchors.horizontalCenterOffset"; to:  0; duration: 45 }
            }

            Rectangle {
                id: pill

                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, field.activeFocus ? 0.14 : 0.09)
                border.width: 1
                border.color: root.state_ === "failed"
                    ? Theme.error
                    : Qt.rgba(1, 1, 1, field.activeFocus ? 0.35 : 0.16)

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }

                Behavior on border.color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }

                Icon {
                    id: lockGlyph

                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    name: "lock"
                    size: 16
                    color: Qt.rgba(1, 1, 1, 0.5)
                }

                TextInput {
                    id: field

                    anchors.left: lockGlyph.right
                    anchors.leftMargin: 12
                    anchors.right: submit.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    color: "white"
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontLabel
                    // Wide spacing makes the dots read as a count rather than a
                    // smear, which is the only feedback a hidden field can give.
                    font.letterSpacing: 3

                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    passwordMaskDelay: 0

                    enabled: root.state_ !== "authenticating" && root.state_ !== "success"
                    focus: true
                    activeFocusOnTab: true
                    selectByMouse: false
                    clip: true

                    onAccepted: root.submit()

                    // Typing after a rejection clears the error rather than
                    // leaving it on screen while you fix it.
                    onTextChanged: if (root.state_ === "failed" && text.length > 0) {
                        root.state_ = "idle";
                        root.notice = "";
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: "Password"
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontLabel
                        visible: field.text.length === 0 && root.state_ !== "authenticating"
                    }

                    Component.onCompleted: field.forceActiveFocus()
                }

                // Enter is the real submit; this is for when a hand is on the
                // trackpad rather than the keyboard.
                Rectangle {
                    id: submit

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: field.text.length > 0
                        ? Qt.rgba(1, 1, 1, submitMouse.containsMouse ? 0.30 : 0.18)
                        : "transparent"

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "chevron-right"
                        size: 18
                        color: Qt.rgba(1, 1, 1, field.text.length > 0 ? 0.9 : 0.25)
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }

        // --- notice -----------------------------------------------------------
        // Reserves its line whether or not there is a message, so the field
        // never jumps up and down as errors come and go.
        Item {
            width: parent.width
            height: 18

            Text {
                anchors.centerIn: parent
                text: root.notice !== "" ? root.notice
                    : root.state_ === "authenticating" ? "Checking…" : ""
                color: root.state_ === "failed" ? Theme.error : Qt.rgba(1, 1, 1, 0.55)
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall

                opacity: text !== "" ? 1 : 0
                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationFast }
                }
            }
        }
    }
}
