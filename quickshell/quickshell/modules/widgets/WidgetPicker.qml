import QtQuick
import qs

// =============================================================================
// WidgetPicker — the bar along the bottom while arranging widgets.
// =============================================================================
// Anserin's widget picker, on this shell's parts. Three columns:
//
//   categories   Clocks / System / Media
//   gallery      every style of every widget in the category, as a LIVE
//                preview -- the real widget file, drawn small -- click to add
//   inspector    for the widget selected on the desktop: its style (switch in
//                place, keeping position and size), a size slider, Remove
//
// plus Reset and Done at the end.
//
// COST
//   Exists only while arranging (Widgets.qml builds it inside edit mode), and
//   only the current category's previews exist at a time: the gallery is one
//   Repeater whose model is that category. Previews are real widgets with
//   `preview: true`, so a clock preview does tick -- but only for as long as
//   you are looking at it. The System previews need SysInfo, which is
//   demanded here only while that category is showing.
// =============================================================================

Card {
    id: root

    required property var widgets

    elevation: 2
    height: 262

    property string category: "clocks"

    readonly property var selected: root.widgets.selectedUid !== ""
        ? root.widgets.widget(root.widgets.selectedUid) : null

    // When something is picked on the desktop, show its category, so its
    // siblings are right there to switch to.
    onSelectedChanged: {
        if (!root.selected) return;
        const t = WidgetCatalog.typeInfo(root.selected.type);
        if (t) root.category = t.category;
    }

    // The selected widget's saved size multiplier, 1 when it has none.
    function savedScale() {
        if (!root.selected) return 1;
        const s = (Settings.desktop.widgetScale || ({}))[root.selected.uid];
        return s > 0 ? s : 1;
    }

    readonly property bool wantsSysInfo: root.visible && root.category === "system"
    onWantsSysInfoChanged: {
        if (root.wantsSysInfo) SysInfo.want("widget-picker");
        else SysInfo.drop("widget-picker");
    }
    Component.onDestruction: SysInfo.drop("widget-picker")

    // Flatten the category into one tile per style.
    readonly property var tiles: {
        const out = [];
        for (const t of WidgetCatalog.typesIn(root.category))
            for (const v of t.variants)
                out.push({ type: t.type, typeLabel: t.label, variant: v.id, label: v.label, file: v.file, props: v.props });
        return out;
    }

    // Swallow clicks on the bar itself, so they do not fall through to the
    // scrim, which would deselect or end arranging.
    MouseArea {
        anchors.fill: parent
    }

    Row {
        anchors.fill: parent
        anchors.margins: Appearance.md
        spacing: Appearance.md

        // --- categories -----------------------------------------------------------
        Column {
            id: categoriesColumn

            width: 112
            spacing: Appearance.xs

            Repeater {
                model: WidgetCatalog.categories

                Rectangle {
                    id: cat

                    required property var modelData
                    readonly property bool current: root.category === cat.modelData.id

                    width: parent.width
                    height: Appearance.controlHeight
                    radius: Appearance.radiusInner
                    color: cat.current ? Theme.wash(Theme.accent, 0.18)
                         : catMouse.containsMouse ? Theme.hover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.sm

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: cat.modelData.icon
                            size: Appearance.iconSize
                            color: cat.current ? Theme.accent : Theme.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cat.modelData.label
                            color: cat.current ? Theme.text : Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontBody
                        }
                    }

                    MouseArea {
                        id: catMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.category = cat.modelData.id
                    }
                }
            }
        }

        // --- gallery ----------------------------------------------------------------
        Flickable {
            id: gallery

            width: parent.width - categoriesColumn.width - inspector.width - actions.width - parent.spacing * 3
            height: parent.height
            contentWidth: tileRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // A mouse wheel scrolls the strip sideways.
            WheelHandler {
                onWheel: (event) => {
                    const max = Math.max(0, gallery.contentWidth - gallery.width);
                    gallery.contentX = Math.max(0, Math.min(max, gallery.contentX - event.angleDelta.y));
                }
            }

            Row {
                id: tileRow

                spacing: Appearance.sm

                Repeater {
                    model: root.tiles

                    Rectangle {
                        id: tile

                        required property var modelData

                        readonly property bool isCurrentStyle: !!root.selected
                            && root.selected.type === tile.modelData.type
                            && root.selected.variant === tile.modelData.variant

                        width: 176
                        height: gallery.height
                        radius: Appearance.radiusInner
                        color: tileMouse.containsMouse ? Theme.wash(Theme.accent, 0.12) : Theme.wash(Theme.text, 0.05)
                        border.width: tile.isCurrentStyle ? 2 : 0
                        border.color: Theme.accent

                        // The preview: the real widget, scaled to fit the tile.
                        Item {
                            id: stage

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: tileLabel.top
                            anchors.margins: Appearance.sm
                            clip: true

                            Item {
                                id: fit

                                width: previewLoader.width
                                height: previewLoader.height
                                anchors.centerIn: parent
                                scale: (width > 0 && height > 0)
                                    ? Math.min(1, stage.width / width, stage.height / height) : 1

                                Loader {
                                    id: previewLoader

                                    Component.onCompleted: {
                                        const props = { widgetId: "preview-" + tile.modelData.type + "-" + tile.modelData.variant, preview: true };
                                        for (const k in tile.modelData.props) props[k] = tile.modelData.props[k];
                                        previewLoader.setSource(Qt.resolvedUrl(tile.modelData.file), props);
                                    }
                                }
                            }
                        }

                        Column {
                            id: tileLabel

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Appearance.sm
                            spacing: 0

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.typeLabel
                                color: Theme.text
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontSmall
                                font.weight: Appearance.weightMedium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.label
                                color: Theme.muted
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontCaption
                            }
                        }

                        // Above the preview, so the preview's own buttons
                        // (a media player's) never take the click.
                        MouseArea {
                            id: tileMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // With a widget of this same type selected, a
                                // click restyles it; otherwise it adds one.
                                if (root.selected && root.selected.type === tile.modelData.type)
                                    root.widgets.setVariant(root.selected.uid, tile.modelData.variant);
                                else
                                    root.widgets.add(tile.modelData.type, tile.modelData.variant);
                            }
                        }
                    }
                }
            }
        }

        // --- inspector -----------------------------------------------------------------
        Rectangle {
            id: inspector

            width: 236
            height: parent.height
            radius: Appearance.radiusInner
            color: Theme.wash(Theme.text, 0.04)

            Column {
                anchors.fill: parent
                anchors.margins: Appearance.md
                spacing: Appearance.sm
                visible: !!root.selected

                Text {
                    width: parent.width
                    text: root.selected
                        ? WidgetCatalog.typeInfo(root.selected.type).label + " · "
                          + WidgetCatalog.variantInfo(root.selected.type, root.selected.variant).label
                        : ""
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontLabel
                    font.weight: Appearance.weightSemi
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "Click a style on the left to switch to it."
                    visible: !!root.selected && WidgetCatalog.typeInfo(root.selected.type).variants.length > 1
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: "SIZE  " + Math.round(sizeSlider.scaleValue * 100) + "%"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.letterSpacing: Appearance.trackingLabel
                }

                Slider {
                    id: sizeSlider

                    // 0..1 on the track maps to 60%..160% of natural size.
                    readonly property real scaleValue: 0.6 + sizeSlider.value
                    width: parent.width
                    stepSize: 0.05
                    value: root.savedScale() - 0.6
                    onMoved: (v) => { if (root.selected) root.widgets.setScale(root.selected.uid, 0.6 + v); }

                    // A drag writes `value` directly, which ends the binding
                    // above -- so a different selection, or the 100% button,
                    // puts the handle back explicitly.
                    Connections {
                        target: root
                        function onSelectedChanged() { sizeSlider.value = root.savedScale() - 0.6; }
                    }
                }

                Row {
                    spacing: Appearance.sm

                    Button {
                        text: "Remove"
                        icon: "trash"
                        variant: "danger"
                        onClicked: root.widgets.remove(root.selected.uid)
                    }

                    Button {
                        text: "100%"
                        variant: "ghost"
                        onClicked: {
                            root.widgets.setScale(root.selected.uid, 1);
                            sizeSlider.value = 0.4;
                        }
                    }
                }
            }

            Text {
                anchors.fill: parent
                anchors.margins: Appearance.md
                visible: !root.selected
                text: "Click a style to add it to the desktop.\n\nClick a widget on the desktop to restyle, resize or remove it. Drag to move."
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }

        // --- finish --------------------------------------------------------------------
        Column {
            id: actions

            width: 104
            anchors.bottom: parent.bottom
            spacing: Appearance.sm

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.widgets.placedList.length + (root.widgets.placedList.length === 1 ? " widget" : " widgets")
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
            }

            Button {
                width: parent.width
                text: "Reset"
                icon: "refresh"
                variant: "ghost"
                onClicked: root.widgets.resetLayout()
            }

            Button {
                width: parent.width
                text: "Done"
                variant: "accent"
                onClicked: root.widgets.done()
            }
        }
    }
}
