import QtQuick
import Quickshell
import qs

// =============================================================================
// Settings — Audio.
// =============================================================================
// The full version of what the Control Center shows in brief. The Control
// Center is for "switch to my headphones, now"; this is for "which of these is
// the HDMI output and why is my microphone so quiet".
//
// Everything here writes straight to PipeWire through services/Audio.qml. No
// wpctl subprocesses, no pavucontrol -- though pavucontrol is one button away
// for the per-application mixer, which is genuinely its job.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    SettingsGroup {
        width: parent.width
        title: "OUTPUT"
        subtitle: Audio.sinkReady ? Audio.sinkName : "no output device"

        SettingRow {
            width: parent.width
            label: "Volume"
            description: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
            Row {
                spacing: Appearance.sm
                Button {
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    variant: Audio.muted ? "accent" : "ghost"
                    icon: Audio.muted ? "volume-mute" : "volume-high"
                    onClicked: Audio.toggleMute()
                }
                Slider {
                    width: 240
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: (v) => Audio.setVolume(v)
                }
            }
        }

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

    SettingsGroup {
        width: parent.width
        title: "INPUT"
        subtitle: Audio.sourceReady ? Audio.sourceName : "no input device"

        SettingRow {
            width: parent.width
            label: "Microphone"
            description: Audio.micMuted ? "Muted" : Math.round(Audio.micVolume * 100) + "%"
            Row {
                spacing: Appearance.sm
                Button {
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    variant: Audio.micMuted ? "accent" : "ghost"
                    icon: Audio.micMuted ? "mic-mute" : "mic"
                    onClicked: Audio.toggleMicMute()
                }
                Slider {
                    width: 240
                    value: Audio.micMuted ? 0 : Audio.micVolume
                    onMoved: (v) => Audio.setMicVolume(v)
                }
            }
        }

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

    SettingsGroup {
        width: parent.width
        title: "ON-SCREEN DISPLAY"
        subtitle: "The indicator that appears when volume or brightness changes"

        SettingRow {
            width: parent.width
            label: "Show for volume"
            Toggle {
                checked: Settings.osd.showVolume
                enabled: Settings.features.osd
                onToggled: (v) => Settings.osd.showVolume = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Show for brightness"
            Toggle {
                checked: Settings.osd.showBrightness
                enabled: Settings.features.osd
                onToggled: (v) => Settings.osd.showBrightness = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Show for microphone"
            Toggle {
                checked: Settings.osd.showMic
                enabled: Settings.features.osd
                onToggled: (v) => Settings.osd.showMic = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Show for track changes"
            Toggle {
                checked: Settings.osd.showMedia
                enabled: Settings.features.osd
                onToggled: (v) => Settings.osd.showMedia = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Position"
            Row {
                spacing: Appearance.xs
                Repeater {
                    model: ["top", "bottom"]
                    Button {
                        required property string modelData
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        variant: Settings.osd.position === modelData ? "accent" : "soft"
                        onClicked: Settings.osd.position = modelData
                    }
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Time on screen"
            description: "How long the indicator stays after the last change"
            Row {
                spacing: Appearance.sm
                Text {
                    text: (Settings.osd.timeout / 1000).toFixed(1) + "s"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 180
                    value: (Settings.osd.timeout - 600) / 4400
                    onMoved: (v) => Settings.osd.timeout = Math.round(600 + v * 4400)
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "ADVANCED"

        SettingRow {
            width: parent.width
            label: "Per-application volume and routing"
            description: "pavucontrol does this better than a panel could"
            Button {
                text: "Open pavucontrol"
                variant: "soft"
                onClicked: {
                    Quickshell.execDetached(["pavucontrol"]);
                    Shell.close("settings");
                }
            }
        }
    }
}
