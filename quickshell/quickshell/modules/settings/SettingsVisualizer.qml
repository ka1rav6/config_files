import QtQuick
import qs

// =============================================================================
// Settings — Visualizer.
// =============================================================================
// The live status line at the top is the important part of this page. "Why are
// my bars not moving" has several correct answers -- nothing is playing, the
// profile suppressed it, a window is fullscreen -- and the status says which
// one, rather than leaving you to guess.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    // --- live status ------------------------------------------------------
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: statusRow.implicitHeight + Appearance.md * 2

        Row {
            id: statusRow

            anchors.fill: parent
            anchors.margins: Appearance.md
            spacing: Appearance.md

            Icon {
                name: "visualizer"
                size: Appearance.iconSizeLarge
                color: Cava.active ? Theme.accent : Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Appearance.iconSizeLarge * 1.25 - Appearance.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Status"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.weight: Appearance.weightMedium
                    font.letterSpacing: Appearance.trackingLabel
                }

                Text {
                    width: parent.width
                    text: Cava.status
                    color: Theme.text
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // Why it is or is not drawing right now. The visualiser has several
    // independent gates and every one of them is a good reason on its own, so
    // when it is off the useful thing is not another toggle -- it is being told
    // WHICH gate is closed.
    SettingsGroup {
        width: parent.width
        title: "STATUS"

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            leftPadding: Appearance.md
            rightPadding: Appearance.md
            bottomPadding: Appearance.sm
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            color: Cava.active ? Theme.success : Theme.muted
            text: {
                if (!Settings.features.musicVisualizer) return "Off — the component is disabled in Components.";
                if (!Settings.desktop.visualizer) return "Off — switched off below.";
                if (Performance.gameMode) return "Paused — Game Mode is on (a window is fullscreen).";
                if (Performance.chosenProfile === "saver") return "Off — the Saver performance profile is selected.";
                if (Performance.saver && !Settings.performance.visualizerOnBattery) return "Off — on battery, and \"Keep running on battery\" is off.";
                if (Settings.visualizer.onlyWhenVisible && !Hypr.anyDesktopVisible) return "Waiting — every monitor is covered by a window. It draws below windows, so there is nothing to show. Move to an empty workspace, or turn off \"Only when the desktop is visible\" below.";
                if (!Audio.audible && !Media.playing) return "Waiting — nothing is playing.";
                if (Cava.active) return "Running — " + Performance.visualizerBands + " bands at " + Performance.visualizerFramerate + " fps.";
                return "Ready — waiting for audio.";
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "BEHAVIOUR"

        SettingRow {
            width: parent.width
            label: "Only run while audio is playing"
            description: "With this on, no cava process exists at all while the machine is silent. It is the single biggest battery saving in the shell — leave it on unless you want the bars to idle visibly."
            Toggle {
                checked: Settings.visualizer.gateOnPlayback
                onToggled: (v) => Settings.visualizer.gateOnPlayback = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Stop after"
            description: "Seconds of silence before the process exits. Long enough to cover the gap between two tracks."
            enabled: Settings.visualizer.gateOnPlayback
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.visualizer.idleTimeout + "s"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 160
                    value: (Settings.visualizer.idleTimeout - 1) / 29
                    onMoved: (v) => Settings.visualizer.idleTimeout = Math.round(1 + v * 29)
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "APPEARANCE"

        SettingRow {
            width: parent.width
            label: "Style"
            description: "Mirror is a waveform about a centre line; bars grow out of the screen edge."
            Row {
                spacing: Appearance.xs
                Repeater {
                    model: [{ id: "mirror", label: "Waveform" }, { id: "bars", label: "Bars" }]
                    Button {
                        required property var modelData
                        text: modelData.label
                        variant: Settings.visualizer.style === modelData.id ? "accent" : "soft"
                        onClicked: Settings.visualizer.style = modelData.id
                    }
                }
            }
        }

        SettingRow {
            width: parent.width
            visible: Settings.visualizer.style === "mirror"
            label: "Distance from the bottom"
            description: "How far the waveform floats above the screen edge."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.visualizer.offset + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: Settings.visualizer.offset / 700
                    onMoved: (v) => Settings.visualizer.offset = Math.round(v * 700)
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Bar gap"
            description: "Wider gaps make thinner bars — this is what controls the thinness."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.visualizer.barGap + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: Settings.visualizer.barGap / 16
                    onMoved: (v) => Settings.visualizer.barGap = Math.round(v * 16)
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Frame rate"
            description: "The dominant cost. 30 Hz roughly halves the CPU for a difference you have to look for; battery forces 30 regardless."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.visualizer.framerate + " Hz"
                        + (Performance.visualizerFramerate !== Settings.visualizer.framerate
                            ? "  (running at " + Performance.visualizerFramerate + ")" : "")
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 160
                    value: (Settings.visualizer.framerate - 20) / 40
                    onMoved: (v) => Settings.visualizer.framerate = Math.round((20 + v * 40) / 5) * 5
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Bands"
            description: "More bands is smoother and linearly more expensive, in both cava and the renderer."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.visualizer.bands + ""
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: (Settings.visualizer.bands - 16) / 112
                    onMoved: (v) => Settings.visualizer.bands = Math.round((16 + v * 112) / 8) * 8
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Height"
            description: "How far the bars rise from the bottom edge."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.visualizer.height + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: (Settings.visualizer.height - 60) / 440
                    onMoved: (v) => Settings.visualizer.height = Math.round(60 + v * 440)
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Opacity"
            description: "The bars sit under every window, so they can afford to be subtle."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Math.round(Settings.visualizer.barOpacity * 100) + "%"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: Settings.visualizer.barOpacity
                    onMoved: (v) => Settings.visualizer.barOpacity = Math.max(0.05, v)
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "RESPONSE"

        SettingRow {
            width: parent.width
            label: "Sensitivity"
            description: "Multiplies the incoming levels. Raise it for quiet material."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.visualizer.sensitivity.toFixed(1) + "x"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: (Settings.visualizer.sensitivity - 0.3) / 2.2
                    onMoved: (v) => Settings.visualizer.sensitivity = Math.round((0.3 + v * 2.2) * 10) / 10
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Fall speed"
            description: "How quickly a bar drops after a beat. Rises are always instant — smoothing the rise makes the bars feel disconnected from what you are hearing."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Math.round(Settings.visualizer.smoothing * 100) + "%"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: Settings.visualizer.smoothing
                    onMoved: (v) => Settings.visualizer.smoothing = Math.min(0.95, v)
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Noise reduction"
            description: "cava's own smoothing, applied before the levels reach the shell."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Math.round(Settings.visualizer.noiseReduction) + ""
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: Settings.visualizer.noiseReduction / 100
                    onMoved: (v) => Settings.visualizer.noiseReduction = Math.round(v * 100)
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "WHEN IT RUNS"

        SettingRow {
            width: parent.width
            label: "Only when the desktop is visible"
            description: "The bars are drawn below every window, so a workspace with one tiled window on it hides them completely. Stopping then is what keeps this at 0.12% of a core most of the time."
            Toggle {
                checked: Settings.visualizer.onlyWhenVisible
                onToggled: (v) => Settings.visualizer.onlyWhenVisible = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Keep running on battery"
            description: "Unplugging drops the effective profile to Saver. With this on, the visualizer keeps going at the reduced frame rate and band count instead of stopping. Choosing Saver by hand still switches it off."
            Toggle {
                checked: Settings.performance.visualizerOnBattery
                onToggled: (v) => Settings.performance.visualizerOnBattery = v
            }
        }
    }
}
