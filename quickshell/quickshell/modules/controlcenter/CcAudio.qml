import QtQuick
import qs

// =============================================================================
// Control Center — audio devices.
// =============================================================================
// Output and input device selection, plus the microphone level. This is the
// part of pavucontrol people actually open it for; the per-application mixer
// and the routing matrix stay pavucontrol's job, one button away at the bottom.
// =============================================================================

Column {
    id: root

    signal back()

    spacing: Appearance.gap

    CcHeader {
        width: parent.width
        title: "Sound"
        onBack: root.back()
    }

    // --- output ----------------------------------------------------------
    Text {
        text: "Output"
        color: Theme.muted
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
        font.weight: Appearance.weightMedium
        font.letterSpacing: Appearance.trackingLabel
    }

    Column {
        width: parent.width
        spacing: Appearance.xs

        Repeater {
            model: Audio.sinks()

            DeviceRow {
                required property var modelData
                width: parent.width
                node: modelData
                selected: Audio.sink === modelData
                icon: "headphones"
                onChosen: Audio.setDefaultSink(modelData)
            }
        }
    }

    Slider {
        width: parent.width
        icon: Audio.muted ? "volume-mute" : "volume-high"
        value: Audio.muted ? 0 : Audio.volume
        onMoved: (v) => Audio.setVolume(v)
    }

    // --- input -------------------------------------------------------------
    Text {
        text: "Input"
        color: Theme.muted
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
        font.weight: Appearance.weightMedium
        font.letterSpacing: Appearance.trackingLabel
    }

    Column {
        width: parent.width
        spacing: Appearance.xs

        Repeater {
            model: Audio.sources()

            DeviceRow {
                required property var modelData
                width: parent.width
                node: modelData
                selected: Audio.source === modelData
                icon: "mic"
                onChosen: Audio.setDefaultSource(modelData)
            }
        }
    }

    Slider {
        width: parent.width
        icon: Audio.micMuted ? "mic-mute" : "mic"
        value: Audio.micMuted ? 0 : Audio.micVolume
        onMoved: (v) => Audio.setMicVolume(v)
    }

    Button {
        width: parent.width
        variant: "ghost"
        text: "Per-app volume and routing"
        icon: "settings"
        onClicked: {
            Quickshell.execDetached(["pavucontrol"]);
            Shell.close("control-center");
        }
    }
}
