import QtQuick
import Quickshell
import qs

// =============================================================================
// Settings — Dock & Launcher.
// =============================================================================
// Everything about the two surfaces you reach for most. Split out from
// Components (which only decides whether they exist at all) because these are
// the knobs you actually turn.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    // --- dock ------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "DOCK"
        subtitle: Settings.features.dock ? "" : "Disabled in Components — these do nothing until it is turned on"

        SettingRow {
            width: parent.width
            enabled: Settings.features.dock
            label: "Visibility"
            description: "Auto reveals the dock when the pointer reaches the screen edge."
            Row {
                spacing: Appearance.xs
                Repeater {
                    model: [
                        { id: "always", label: "Always" },
                        { id: "auto", label: "On hover" },
                        { id: "never", label: "Hidden" }
                    ]
                    Button {
                        required property var modelData
                        text: modelData.label
                        variant: Settings.dock.visibility === modelData.id ? "accent" : "soft"
                        enabled: Settings.features.dock
                        onClicked: Settings.dock.visibility = modelData.id
                    }
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.features.dock
            label: "Icon size"
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.dock.iconSize + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.features.dock
                    value: (Settings.dock.iconSize - 28) / 36
                    onMoved: (v) => Settings.dock.iconSize = Math.round(28 + v * 36)
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.features.dock
            label: "Spacing"
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.dock.spacing + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.features.dock
                    value: Settings.dock.spacing / 24
                    onMoved: (v) => Settings.dock.spacing = Math.round(v * 24)
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.features.dock
            label: "Magnify on hover"
            description: "A scale transform, so it costs nothing measurable."
            Toggle {
                checked: Settings.dock.magnify
                enabled: Settings.features.dock
                onToggled: (v) => Settings.dock.magnify = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.features.dock && Settings.dock.magnify
            label: "Magnification"
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.dock.magnifyScale.toFixed(2) + "x"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.features.dock && Settings.dock.magnify
                    value: (Settings.dock.magnifyScale - 1.0) / 0.8
                    onMoved: (v) => Settings.dock.magnifyScale = Math.round((1.0 + v * 0.8) * 100) / 100
                }
            }
        }
    }

    // --- pinned ------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "PINNED APPLICATIONS"
        subtitle: "Pinned apps always show; running apps are added after them"

        Repeater {
            model: Settings.dock.pinned || []

            Rectangle {
                required property string modelData
                required property int index

                width: parent.width
                height: Appearance.controlHeight
                radius: Appearance.radiusInner
                color: pinMouse.containsMouse ? Theme.hover : "transparent"

                readonly property var entry: DesktopEntries.byId(modelData)
                    || DesktopEntries.byId(modelData.replace(/\.desktop$/, ""))

                Image {
                    id: pinIcon
                    width: 22; height: 22
                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    source: parent.entry
                        ? Quickshell.iconPath(parent.entry.icon, "application-x-executable") : ""
                    sourceSize.width: 44
                    asynchronous: true
                }

                Text {
                    anchors.left: pinIcon.right
                    anchors.leftMargin: Appearance.sm
                    anchors.right: pinControls.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.entry ? parent.entry.name : modelData + "  (not installed)"
                    color: parent.entry ? Theme.text : Theme.warning
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                    elide: Text.ElideRight
                }

                Row {
                    id: pinControls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.xs

                    Button {
                        width: Appearance.controlHeightSmall
                        height: Appearance.controlHeightSmall
                        variant: "ghost"
                        icon: "chevron-up"
                        enabled: index > 0
                        onClicked: root.movePin(index, -1)
                    }
                    Button {
                        width: Appearance.controlHeightSmall
                        height: Appearance.controlHeightSmall
                        variant: "ghost"
                        icon: "chevron-down"
                        enabled: index < (Settings.dock.pinned || []).length - 1
                        onClicked: root.movePin(index, 1)
                    }
                    Button {
                        width: Appearance.controlHeightSmall
                        height: Appearance.controlHeightSmall
                        variant: "ghost"
                        icon: "trash"
                        onClicked: root.removePin(index)
                    }
                }

                MouseArea {
                    id: pinMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Add an application"
            description: "Pick from everything installed"
            Button {
                text: addPicker.visible ? "Close" : "Add"
                icon: addPicker.visible ? "close" : "plus"
                variant: "soft"
                onClicked: addPicker.visible = !addPicker.visible
            }
        }

        Column {
            id: addPicker

            width: parent.width
            visible: false
            spacing: Appearance.xs

            Rectangle {
                width: parent.width
                height: Appearance.controlHeight
                radius: Appearance.radiusInner
                color: Theme.wash(Theme.bg, 0.5)
                border.width: 1
                border.color: Theme.wash(Theme.border, 0.4)

                TextInput {
                    id: pinSearch
                    anchors.fill: parent
                    anchors.margins: Appearance.sm
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: pinSearch.text === ""
                        text: "Search applications…"
                        color: Theme.muted
                        font: pinSearch.font
                    }
                }
            }

            Repeater {
                model: {
                    const q = pinSearch.text.trim().toLowerCase();
                    if (q === "") return [];
                    const pinned = Settings.dock.pinned || [];
                    return DesktopEntries.applications.values
                        .filter(e => !e.noDisplay
                            && e.name.toLowerCase().indexOf(q) !== -1
                            && pinned.indexOf(e.id) === -1)
                        .slice(0, 6);
                }

                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: Appearance.controlHeightSmall + 6
                    radius: Appearance.radiusInner
                    color: addMouse.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontBody
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.addPin(modelData.id);
                            pinSearch.text = "";
                            addPicker.visible = false;
                        }
                    }
                }
            }
        }
    }

    // --- launcher ----------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "LAUNCHER"

        SettingRow {
            width: parent.width
            enabled: Settings.features.launcher
            label: "Width"
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.launcher.width + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.features.launcher
                    value: (Settings.launcher.width - 420) / 500
                    onMoved: (v) => Settings.launcher.width = Math.round(420 + v * 500)
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.features.launcher
            label: "Results shown"
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.launcher.maxResults + ""
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.features.launcher
                    value: (Settings.launcher.maxResults - 4) / 12
                    onMoved: (v) => Settings.launcher.maxResults = Math.round(4 + v * 12)
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Forget launch history"
            description: (Settings.launcher.recent || []).length
                + " applications remembered, used to order results"
            Button {
                text: "Clear"
                variant: "ghost"
                onClicked: Settings.launcher.recent = []
            }
        }
    }

    // --- helpers ------------------------------------------------------------
    // A `var` property only emits its change signal on assignment, so every one
    // of these rebuilds the list rather than editing it in place. Editing in
    // place would change the data and leave the UI showing the old order.

    function addPin(id) {
        const next = (Settings.dock.pinned || []).slice();
        if (next.indexOf(id) !== -1) return;
        next.push(id);
        Settings.dock.pinned = next;
    }

    function removePin(index) {
        const next = (Settings.dock.pinned || []).slice();
        next.splice(index, 1);
        Settings.dock.pinned = next;
    }

    function movePin(index, delta) {
        const next = (Settings.dock.pinned || []).slice();
        const target = index + delta;
        if (target < 0 || target >= next.length) return;
        const item = next[index];
        next[index] = next[target];
        next[target] = item;
        Settings.dock.pinned = next;
    }
}
