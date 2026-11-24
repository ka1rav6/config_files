import QtQuick
// Quickshell, for execDetached() -- see the handler that opens the external
// tool below. WITHOUT THIS IMPORT the `Quickshell` name is simply undefined,
// the click handler dies on a ReferenceError, and the button does nothing at
// all with no visible error: the qmldir header's warning about singletons,
// one level up.
import Quickshell
// For PwObjectTracker. The streams this page shows are unbound without it --
// see the tracker below.
import Quickshell.Services.Pipewire
import qs

// =============================================================================
// Control Center — audio devices.
// =============================================================================
// Output and input device selection, the microphone level, and a volume slider
// per playing application. The routing matrix stays pavucontrol's job, one
// button away at the bottom.
//
// WHY THE TRACKER IS SCOPED TO THIS PAGE
//   PipeWire nodes are unbound by default: read a volume off an untracked node
//   and you get a stale zero, silently. services/Audio.qml deliberately tracks
//   only the default sink and source, because tracking every node on the system
//   would mean mirroring every browser tab's stream for no reason.
//
//   ControlCenter.qml builds its pages with Loaders, so this file exists only
//   while the Sound page is actually on screen. That makes a tracker declared
//   here exactly the panel-scoped binding Audio.qml's header asks for: the
//   streams are bound while you are looking at them and unbound the moment you
//   press back.
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
                // With the equalizer on the default is the Equalizer, so the
                // device it plays into is the one to mark as current.
                selected: Audio.sink === modelData
                    || (Audio.sink === Equalizer.eqNode && Equalizer.targetNode === modelData)
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

    // --- applications ------------------------------------------------------
    // Binds every stream this page lists, for as long as the page lives.
    PwObjectTracker {
        objects: Audio.streams
    }

    Text {
        visible: Audio.streams.length > 0
        text: "Applications"
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
            model: Audio.streams

            Column {
                id: stream

                required property var modelData

                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    // `application.name` is the app's own name ("Spotify");
                    // description is the stream's ("Playback"). Prefer the app.
                    // Both come from the bound properties, so this is empty for
                    // the first frame after a stream appears and fills in.
                    text: stream.modelData.properties["application.name"]
                        || stream.modelData.description
                        || stream.modelData.name
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                    elide: Text.ElideRight
                }

                Slider {
                    width: parent.width
                    icon: stream.modelData.audio.muted ? "volume-mute" : "volume-high"
                    value: stream.modelData.audio.muted ? 0 : stream.modelData.audio.volume
                    onMoved: (v) => Audio.setStreamVolume(stream.modelData, v)
                }
            }
        }
    }

    Button {
        width: parent.width
        variant: "ghost"
        text: "Routing and more"
        icon: "settings"
        onClicked: {
            Quickshell.execDetached(["pavucontrol"]);
            Shell.close("control-center");
        }
    }
}
