import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// =============================================================================
// OSD — the on-screen display for volume, brightness, microphone and media.
// =============================================================================
// Replaces ~/.config/waybar/scripts/slider-popup.py: 433 lines of Python + GTK3
// + GtkLayerShell, spawned as a fresh process (via `setsid -f`) every time the
// volume icon was clicked, in three separate modes. This is the same job with
// no subprocess, no GTK, and the shell's own visual language.
//
// WHAT TRIGGERS IT
//   Any change to the values it shows, from any source -- the hardware keys
//   bound in ~/.config/hypr/bindings.lua, the Control Center's sliders, or
//   another application changing the volume. It watches the SERVICES, not the
//   keybindings, so there is exactly one code path and nothing to keep in step.
//
// WHY IT DOES NOT FIRE ON STARTUP
//   The services populate asynchronously: Audio's volume goes 0 -> 0.65 a
//   second after launch, and Brightness' goes 0 -> 49% when sysfs is first
//   read. Both look exactly like a user change. `armed` below stays false until
//   each service has settled, so logging in does not throw three OSDs on screen.
//
// COST WHEN IDLE
//   Nothing. The window is inside a LazyLoader keyed on `visible`, so while no
//   OSD is showing there is no window, no surface and no bindings -- only the
//   Connections blocks, which are signal handlers and cost nothing until they
//   fire.
// =============================================================================

Scope {
    id: root

    // "volume" | "brightness" | "mic" | "media"
    property string mode: ""
    property bool showing: false

    // See the header: suppresses the burst of "changes" that is really just
    // the services reading their initial values.
    property bool armed: false

    Timer {
        id: armDelay

        // Comfortably longer than the ~2s the D-Bus services take to settle.
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }

    function flash(which) {
        if (!root.armed) return;
        if (!Settings.features.osd) return;

        // Per-kind opt-outs, so someone who only wants a volume OSD can have
        // exactly that.
        if (which === "volume" && !Settings.osd.showVolume) return;
        if (which === "brightness" && !Settings.osd.showBrightness) return;
        if (which === "mic" && !Settings.osd.showMic) return;
        if (which === "media" && !Settings.osd.showMedia) return;

        root.mode = which;
        root.showing = true;
        hideDelay.restart();
    }

    Timer {
        id: hideDelay

        interval: Math.max(600, Settings.osd.timeout)
        onTriggered: root.showing = false
    }

    // --- triggers -------------------------------------------------------
    // Watching properties rather than keypresses means the OSD is correct no
    // matter what changed the value.

    Connections {
        target: Audio
        function onVolumeChanged() { root.flash("volume"); }
        function onMutedChanged() { root.flash("volume"); }
        function onMicMutedChanged() { root.flash("mic"); }
        function onMicVolumeChanged() { root.flash("mic"); }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() { root.flash("brightness"); }
    }

    Connections {
        target: Media
        // Only on a track change, not on every position tick.
        function onTitleChanged() { if (Media.playing) root.flash("media"); }
    }

    // --- presentation ---------------------------------------------------

    readonly property real level: {
        switch (root.mode) {
        case "volume": return Audio.muted ? 0 : Audio.volume;
        case "brightness": return Brightness.displayed;
        case "mic": return Audio.micMuted ? 0 : Audio.micVolume;
        }
        return 0;
    }

    readonly property string iconName: {
        switch (root.mode) {
        case "volume":
            if (Audio.muted) return "volume-mute";
            if (Audio.volume > 0.66) return "volume-high";
            if (Audio.volume > 0.33) return "volume-mid";
            if (Audio.volume > 0) return "volume-low";
            return "volume-off";
        case "brightness":
            return Brightness.displayed > 0.5 ? "brightness-high" : "brightness-low";
        case "mic":
            return Audio.micMuted ? "mic-mute" : "mic";
        case "media":
            return Media.playing ? "play" : "pause";
        }
        return "info";
    }

    readonly property string label: {
        switch (root.mode) {
        case "volume": return Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%";
        case "brightness": return Math.round(Brightness.displayed * 100) + "%";
        case "mic": return Audio.micMuted ? "Mic muted" : Math.round(Audio.micVolume * 100) + "%";
        case "media": return Media.title !== "" ? Media.title : Media.identity;
        }
        return "";
    }

    readonly property string sublabel: root.mode === "media" ? Media.artist : ""

    // Keeps the window alive for the exit animation, then tears it down.
    // A separate timer rather than watching the animation directly: the
    // animation lives INSIDE the loader this controls, so referencing it here
    // is a circular dependency that resolves to undefined.
    Timer {
        id: teardown

        interval: Appearance.durationSlow + 60
        onTriggered: if (!root.showing) osdLoader.activeAsync = false
    }

    onShowingChanged: {
        if (root.showing) {
            teardown.stop();
            osdLoader.activeAsync = true;
        } else {
            teardown.restart();
        }
    }

    LazyLoader {
        id: osdLoader

        // Built on the first OSD, torn down once the exit animation has
        // finished -- so an idle desktop has no OSD window at all.
        activeAsync: false

        PanelWindow {
            id: window

            screen: Hypr.activeScreen
            visible: true
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-osd"
            // Must never take focus: the OSD appears while you are typing or
            // holding a volume key, and stealing the keyboard would swallow
            // the next keystroke.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            // Entirely click-through. An OSD that eats a click because it
            // happened to be on screen is infuriating.
            mask: Region {}

            implicitWidth: 320
            implicitHeight: 96

            anchors {
                top: Settings.osd.position === "top"
                bottom: Settings.osd.position !== "top"
                left: Settings.osd.position === "left"
                right: Settings.osd.position === "right"
            }

            margins {
                top: Appearance.barClearance
                bottom: 110
                left: Appearance.screenMargin
                right: Appearance.screenMargin
            }

            Card {
                id: card

                elevation: 2
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                opacity: root.showing ? 1 : 0
                // Rises slightly into place rather than just fading -- the
                // movement is what makes it read as arriving.
                y: root.showing ? 0 : (Settings.osd.position === "top" ? -8 : 8)
                scale: root.showing ? 1 : 0.96

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: root.showing ? Appearance.durationNormal : Appearance.durationSlow
                        easing.type: root.showing ? Appearance.easeEnter : Appearance.easeExit
                    }
                }
                Behavior on y {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationNormal; easing.type: Appearance.easeEnter }
                }
                Behavior on scale {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationNormal; easing.type: Appearance.easeEnter }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding

                    Icon {
                        id: osdIcon

                        name: root.iconName
                        size: Appearance.iconSizeLarge
                        color: Theme.accent
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        // A small pulse each time the value changes, so a held
                        // volume key reads as repeated events rather than one
                        // static panel.
                        scale: 1

                        SequentialAnimation {
                            id: pulse

                            running: false
                            NumberAnimation {
                                target: osdIcon; property: "scale"; to: 1.18
                                duration: Appearance.durationFast; easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: osdIcon; property: "scale"; to: 1.0
                                duration: Appearance.durationNormal; easing.type: Easing.OutBack
                            }
                        }

                        // Pulse on every retrigger, including while already on
                        // screen -- a held volume key should read as a stream
                        // of events, not one static panel.
                        Connections {
                            target: root
                            function onLevelChanged() {
                                if (root.showing && !Appearance.motionless) pulse.restart();
                            }
                        }
                    }

                    Column {
                        anchors.left: osdIcon.right
                        anchors.leftMargin: Appearance.md
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.sm

                        Text {
                            width: parent.width
                            text: root.label
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: root.mode === "media" ? Appearance.fontLabel : Appearance.fontTitle
                            font.weight: Appearance.weightMedium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: root.sublabel !== ""
                            text: root.sublabel
                            color: Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontSmall
                            elide: Text.ElideRight
                        }

                        // The level bar. Hidden for media, which has no level.
                        Rectangle {
                            visible: root.mode !== "media"
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Theme.wash(Theme.border, 0.4)

                            Rectangle {
                                width: Math.max(parent.height, parent.width * root.level)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.accent

                                Behavior on width {
                                    enabled: !Appearance.motionless
                                    NumberAnimation {
                                        duration: Appearance.durationFast
                                        easing.type: Appearance.easeStandard
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
