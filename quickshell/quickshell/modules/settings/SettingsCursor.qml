import QtQuick
import qs

// Settings — Cursor. Theme, size, idle hiding, and the pointer effects.
//
// Theme and size go live immediately (services/CursorTheme.qml). The effects
// need the qs-pointer Hyprland plugin (services/Pointer.qml); when it is not
// loaded, or battery saver has stopped animations, the page says so instead of
// pretending the switches do something.
Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    // A row of mutually exclusive choices, in the same buttons as the rest of
    // Settings.
    component Choice: Row {
        id: choice
        property var options: []        // [{ id, label }]
        property string current: ""
        signal picked(string id)
        spacing: Appearance.xs
        Repeater {
            model: choice.options
            Button {
                required property var modelData
                text: modelData.label
                variant: choice.current === modelData.id ? "accent" : "soft"
                onClicked: choice.picked(modelData.id)
            }
        }
    }

    component ValueText: Text {
        color: Theme.muted
        font.family: Appearance.fontMono
        font.pixelSize: Appearance.fontSmall
        anchors.verticalCenter: parent.verticalCenter
    }

    // Said up front, not in a subtitle: an effect that silently does nothing
    // looks broken.
    Rectangle {
        width: parent.width
        visible: root.pausedReason !== ""
        height: banner.implicitHeight + Appearance.md * 2
        radius: Appearance.radiusInner
        color: Theme.wash(Theme.warning, 0.14)

        Text {
            id: banner
            anchors.fill: parent
            anchors.margins: Appearance.md
            text: root.pausedReason
            wrapMode: Text.WordWrap
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
        }
    }

    readonly property string pausedReason: !Pointer.available
        ? "Cursor effects and the press bounce are off: the qs-pointer Hyprland plugin is not loaded. Run `just qs-pointer`."
        : Performance.stopAnimations
        ? "Cursor effects and the press bounce are paused: you are on battery in Battery Saver. They come back when you plug in (or turn off \"Battery saver stops animations\" in Settings › Performance)."
        : Performance.gameMode
        ? "Cursor effects are paused while a window is fullscreen."
        : ""

    // ---------------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "THEME"
        subtitle: Settings.cursor.theme === ""
            ? "Using the login default (" + CursorTheme.fallback + ")"
            : CursorTheme.generating ? "Building the accent cursor…"
            : "Using " + (CursorTheme.isAccent ? "Accent " + CursorTheme.accentStyle + ", in the theme accent" : Settings.cursor.theme)

        // The quick switch: the pulsing circle, or back to whatever was in use.
        SettingRow {
            width: parent.width
            label: "Circle cursor"
            description: CursorTheme.circle
                ? "Always a dot, whatever it is over, and it pulses bigger and smaller on every click. Turn off to go back to "
                  + (Settings.cursor.normalTheme === "" || Settings.cursor.normalTheme === "accent:Circle" ? "the login default"
                     : Settings.cursor.normalTheme.startsWith("accent:") ? "Accent " + Settings.cursor.normalTheme.slice(7)
                     : Settings.cursor.normalTheme) + "."
                : "Always a dot, whatever it is over, and it pulses bigger and smaller on every click."
            Toggle {
                checked: CursorTheme.circle
                onToggled: (v) => { if (v !== CursorTheme.circle) CursorTheme.toggleCircle(); }
            }
        }

        // Families
        Flow {
            width: parent.width
            spacing: Appearance.xs

            Button {
                text: "Login default"
                variant: Settings.cursor.theme === "" ? "accent" : "soft"
                onClicked: Settings.cursor.theme = ""
            }

            Repeater {
                model: CursorTheme.families
                Button {
                    required property string modelData
                    text: modelData
                    variant: CursorTheme.currentFamily === modelData && Settings.cursor.theme !== "" ? "accent" : "soft"
                    onClicked: {
                        const list = CursorTheme.variantsOf(modelData);
                        if (list.length && CursorTheme.currentFamily !== modelData)
                            Settings.cursor.theme = list[0].name;
                    }
                }
            }
        }

        // Variants of the chosen family, with a preview of each
        Flow {
            width: parent.width
            spacing: Appearance.sm
            visible: Settings.cursor.theme !== ""

            Repeater {
                model: CursorTheme.variantsOf(CursorTheme.currentFamily)

                Rectangle {
                    id: tile

                    required property var modelData
                    readonly property bool selected: Settings.cursor.theme === modelData.name
                    readonly property bool accent: modelData.family === "Accent"

                    width: 132
                    height: 92
                    radius: Appearance.radiusInner
                    color: selected ? Theme.wash(Theme.accent, 0.16) : tileMouse.containsMouse ? Theme.hover : Theme.surface
                    border.width: selected ? 1.5 : 0
                    border.color: Theme.accent

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    // Installed themes: their own pointer and hand (rendered once
                    // by scripts/cursor-preview.py). Accent styles: pointer, link
                    // and text in the live accent (cursor-gen.py preview).
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 14
                        height: tile.accent ? 34 : 40
                        fillMode: Image.PreserveAspectFit
                        source: tile.accent ? CursorTheme.accentPreview(tile.modelData.variant)
                                            : (CursorTheme.previews[tile.modelData.name] ?? "")
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.modelData.variant === "Fluent" ? "Fluent · animated"
                            : tile.modelData.variant === "Circle" ? "Circle · pulses"
                            : (tile.modelData.variant || tile.modelData.name)
                        color: tile.selected ? Theme.text : Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.cursor.theme = tile.modelData.name
                    }
                }
            }
        }

        // One colour for the pointer and everything it draws.
        Column {
            width: parent.width
            spacing: Appearance.xs
            topPadding: Appearance.xs

            Text {
                text: "Colour"
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: CursorTheme.isAccent || Settings.cursor.theme === ""
                    ? (CursorTheme.isAccent ? "The pointer and its trail, click effect and ring all use this colour."
                                            : "Pick an Accent style above to colour the pointer itself; the trail, click effect and ring use this colour either way.")
                    : "Installed themes keep their own colours; the trail, click effect and ring use this one."
                    + (CursorTheme.inverted ? (CursorTheme.isAccent ? " Invert draws the pointer as the opposite of whatever is under it, like Windows' inverted pointer; the effects can't invert, so they are white."
                                                                    : " Invert only works with an Accent style.") : "")
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
            }

            Gradient {
                id: splitGradient
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ffffff" }
                GradientStop { position: 0.5; color: "#ffffff" }
                GradientStop { position: 0.501; color: "#000000" }
                GradientStop { position: 1.0; color: "#000000" }
            }

            Flow {
                width: parent.width
                spacing: Appearance.sm
                topPadding: Appearance.xs

                Repeater {
                    model: [
                        { id: "accent", label: "Accent", hex: "" },
                        { id: "white", label: "White", hex: "#f4f5f7" },
                        { id: "black", label: "Black", hex: "#1b1d22" },
                        { id: "invert", label: "Invert", hex: "" },
                        { id: "#ff6b81", label: "Pink", hex: "#ff6b81" },
                        { id: "#ff5c5c", label: "Red", hex: "#ff5c5c" },
                        { id: "#ffa94d", label: "Orange", hex: "#ffa94d" },
                        { id: "#ffd43b", label: "Yellow", hex: "#ffd43b" },
                        { id: "#69db7c", label: "Green", hex: "#69db7c" },
                        { id: "#3bc9db", label: "Cyan", hex: "#3bc9db" },
                        { id: "#4dabf7", label: "Blue", hex: "#4dabf7" },
                        { id: "#b197fc", label: "Purple", hex: "#b197fc" }
                    ]

                    Column {
                        id: swatch

                        required property var modelData
                        readonly property bool selected: (Settings.cursor.color || "accent") === modelData.id
                        spacing: 4

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 30
                            height: 30
                            radius: 15
                            color: swatch.modelData.hex !== "" ? swatch.modelData.hex : Theme.accent
                            // Invert: half white, half black.
                            gradient: swatch.modelData.id === "invert" ? splitGradient : null
                            border.width: swatch.selected ? 3 : 1
                            border.color: swatch.selected ? Theme.text : Theme.wash(Theme.text, 0.25)
                            scale: swatchMouse.containsMouse ? 1.1 : 1

                            Behavior on scale {
                                enabled: !Appearance.motionless
                                NumberAnimation { duration: Appearance.durationFast }
                            }

                            MouseArea {
                                id: swatchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.cursor.color = swatch.modelData.id
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: swatch.modelData.label
                            color: swatch.selected ? Theme.text : Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                        }
                    }
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Size"
            description: "Pointer size in logical pixels. Applies to Hyprland and new apps right away; running X11 apps pick it up when restarted."
            Row {
                spacing: Appearance.sm
                ValueText { text: Settings.cursor.size + " px" }
                Slider {
                    width: 180
                    value: (Settings.cursor.size - 16) / 48
                    onMoved: (v) => Settings.cursor.size = 16 + Math.round(v * 12) * 4
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Hide when idle"
            description: "Hides the pointer after it has not moved for a while. It comes back on the first movement."
            Row {
                spacing: Appearance.sm
                ValueText { text: Settings.cursor.hideAfter > 0 ? Settings.cursor.hideAfter + " s" : "never" }
                Slider {
                    width: 180
                    value: Settings.cursor.hideAfter / 30
                    onMoved: (v) => Settings.cursor.hideAfter = Math.round(v * 30)
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        visible: CursorTheme.animated
        title: "ANIMATION"
        subtitle: CursorTheme.circle
            ? "Circle stays a dot everywhere; a click makes it swell, dip smaller and settle."
            : "Fluent morphs from the dot into each shape: a soft highlight over links, a bar over text, arrows when resizing."

        SettingRow {
            width: parent.width
            label: CursorTheme.circle ? "Pulse speed" : "Morph speed"
            Choice {
                options: [{ id: "fast", label: "Fast" }, { id: "normal", label: "Normal" }, { id: "slow", label: "Slow" }]
                current: Settings.cursor.speed
                onPicked: (id) => Settings.cursor.speed = id
            }
        }

        SettingRow {
            width: parent.width
            label: CursorTheme.circle ? "Click pulse" : "Press bounce"
            description: CursorTheme.circle ? "The dot grows and shrinks each time you click; off keeps it still."
                                            : "The cursor swells and settles each time you click."
            Toggle {
                checked: Settings.cursor.press
                onToggled: (v) => Settings.cursor.press = v
            }
        }
    }

    // ---------------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "EFFECTS"
        subtitle: root.pausedReason !== "" ? "Paused — see the note at the top" : "Drawn over everything, never in the way of a click"

        SettingRow {
            width: parent.width
            label: "Trail"
            description: "Comet is one tapering streak; dots leave a fading breadcrumb line; sparks shed particles while the pointer moves."
            Choice {
                options: [{ id: "off", label: "Off" }, { id: "comet", label: "Comet" }, { id: "dots", label: "Dots" }, { id: "sparks", label: "Sparks" }]
                current: Settings.cursor.trail
                onPicked: (id) => Settings.cursor.trail = id
            }
        }

        SettingRow {
            width: parent.width
            visible: Settings.cursor.trail !== "off"
            label: "Trail length"
            Row {
                spacing: Appearance.sm
                ValueText { text: Math.round(Settings.cursor.trailLength * 100) + "%" }
                Slider {
                    width: 180
                    value: Settings.cursor.trailLength
                    onMoved: (v) => Settings.cursor.trailLength = Math.round(v * 20) / 20
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Click"
            description: "Plays where you click, in any app."
            Choice {
                options: [{ id: "off", label: "Off" }, { id: "ripple", label: "Ripple" }, { id: "pop", label: "Pop" }, { id: "burst", label: "Burst" }]
                current: Settings.cursor.click
                onPicked: (id) => Settings.cursor.click = id
            }
        }
    }

    // ---------------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "MUSIC RING"
        subtitle: "A small visualizer round the pointer while music plays. Also on Super + D › Media."

        SettingRow {
            width: parent.width
            label: "Ring visualizer"
            description: "Only runs while something is playing; it uses the same audio analysis as the desktop visualizer."
            Toggle {
                checked: Settings.cursor.ring
                onToggled: (v) => Settings.cursor.ring = v
            }
        }

        SettingRow {
            width: parent.width
            visible: Settings.cursor.ring
            label: "Style"
            Choice {
                options: [{ id: "bars", label: "Bars" }, { id: "dots", label: "Dots" }, { id: "wave", label: "Wave" }]
                current: Settings.cursor.ringStyle
                onPicked: (id) => Settings.cursor.ringStyle = id
            }
        }

        SettingRow {
            width: parent.width
            visible: Settings.cursor.ring
            label: "Distance from the pointer"
            Row {
                spacing: Appearance.sm
                ValueText { text: Settings.cursor.ringRadius + " px" }
                Slider {
                    width: 180
                    value: (Settings.cursor.ringRadius - 16) / 48
                    onMoved: (v) => Settings.cursor.ringRadius = Math.round(16 + v * 48)
                }
            }
        }
    }
}
