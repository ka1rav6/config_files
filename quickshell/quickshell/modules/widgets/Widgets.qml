import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// =============================================================================
// Desktop widgets.
// =============================================================================
// A layer of widgets that live on the wallpaper. Which widgets, in which
// style, is the list in Settings.desktop.placed, edited with the widget picker
// (SUPER + SHIFT + G): any number of each type, each in any of its styles
// (modules/widgets/WidgetCatalog.qml lists them), each dragged where you want
// it and sized with the inspector.
//
// WHERE IT SITS
//   WlrLayer.Bottom -- above the wallpaper, below every window, on every
//   workspace, with ExclusionMode.Ignore so it never reflows a tiled layout.
//   Outside edit mode the surface is click-through except where an
//   interactive widget (a media player) sits; see the mask below.
//
// WHY THE SURFACE DISAPPEARS WHEN THE DESKTOP IS COVERED
//   Same reasoning as the visualiser: this layer is below every window, so on
//   a workspace with one tiled window on it nothing here is visible. The
//   screen list is filtered through Hypr.desktopVisibleOn, so a covered output
//   has no surface, no items and no bindings at all -- and in particular the
//   /proc reads behind the gauges stop, because the SysInfo demand is released
//   with the last visible surface, and every seconds tick a clock asked for is
//   dropped with the clock.
//
//   Floating windows do not count as covering; see services/Hypr.qml.
//
// EDIT MODE (the picker)
//   `quickshell ipc call widgets edit` lifts the layer to Overlay, makes it
//   take input, and opens WidgetPicker along the bottom of the focused screen:
//   categories, a gallery of live previews to add from, and an inspector for
//   the selected widget (style, size, remove). Drag widgets to move them.
//   Click the empty desktop to deselect, again (or Escape) to finish.
//
// MIGRATION FROM THE OLD ON/OFF SWITCHES
//   Before the picker the desktop had exactly one of each of seven widgets,
//   each on or off in Settings > Desktop. On the first run with `placed` still
//   null, migrate() turns the ones that were on into placed widgets whose ids
//   ARE the old names ("clock", "media", "cpu"...), which are the keys their
//   positions were already saved under -- so nothing moves. It runs once;
//   after that `placed` is a list (possibly empty) and the switches are never
//   read again.
// =============================================================================

Scope {
    id: root

    property bool editing: false

    // uid of the widget picked in the inspector, or "".
    property string selectedUid: ""

    // A stable id for the SysInfo demand refcount.
    readonly property string consumerId: "desktop-widgets"

    // `placed`, copied into a real array. JsonAdapter hands lists back as
    // something array-LIKE (length and map work, Array.isArray says false), so
    // nothing here trusts it to be an Array -- copy by index.
    readonly property var placedList: {
        const p = Settings.desktop.placed;
        const out = [];
        if (!p || p.length === undefined) return out;
        for (let i = 0; i < p.length; i++) {
            const w = p[i];
            if (w && w.uid && WidgetCatalog.typeInfo(w.type)) out.push(w);
        }
        return out;
    }

    readonly property bool wanted: Settings.features.widgets
        && (root.editing || Hypr.anyDesktopVisible)
        && (root.editing || !Settings.desktop.hideOnFullscreen || !Hypr.fullscreen)

    // The gauges are the only widgets that cost anything to keep fed, so the
    // /proc polling is demanded only while one of them is placed AND on screen.
    // Everything else is event-driven already.
    readonly property bool needsSysInfo: root.wanted
        && root.placedList.some(w => WidgetCatalog.needsSysInfo(w.type))

    onNeedsSysInfoChanged: {
        if (root.needsSysInfo) SysInfo.want(root.consumerId);
        else SysInfo.drop(root.consumerId);
    }

    Component.onCompleted: {
        Shell.widgets = root;
        root.migrate();
        if (root.needsSysInfo) SysInfo.want(root.consumerId);
    }

    Component.onDestruction: {
        if (Shell.widgets === root) Shell.widgets = null;
        SysInfo.drop(root.consumerId);
    }

    // The migration reads settings.json ITSELF rather than Settings.desktop.
    //
    // Settings.loaded goes true before the JsonAdapter has copied the file's
    // values into its properties, so at startup Settings.desktop still holds
    // the built-in defaults (clock and media on, the rest off). The first
    // version of this migration read those, and migrated two widgets out of
    // seven. Worse, the same timing would make `placed` read null on every
    // start, and a migration that trusted it would overwrite the real list.
    // The raw file has neither problem. blockLoading makes text() synchronous;
    // it is read once, here, and never watched.
    FileView {
        id: rawSettings

        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
        blockLoading: true
        printErrors: false
    }

    function edit() { root.editing = true; }
    function done() { root.editing = false; root.selectedUid = ""; }
    function toggleEdit() { if (root.editing) root.done(); else root.edit(); }

    // Forget every saved position and size. The widgets animate back to their
    // defaults rather than teleporting, which makes it obvious what happened.
    function resetLayout() {
        Settings.desktop.widgetLayout = ({});
        Settings.desktop.widgetScale = ({});
    }

    // --- the placed list --------------------------------------------------------
    // Every write replaces the whole value: JsonAdapter notices a `var` changing
    // by identity only, so an in-place edit would never reach settings.json.

    function migrate() {
        let d;
        try {
            d = JSON.parse(rawSettings.text()).desktop || {};
        } catch (e) {
            // No file yet (first run) or one that does not parse. Either way
            // there is nothing to migrate FROM, and an empty desktop is the
            // right answer: `placed` stays null and reads as no widgets.
            return;
        }
        if (d.placed !== null && d.placed !== undefined) return;

        // Missing keys take the old built-in defaults.
        if (d.clock === undefined) d.clock = true;
        if (d.media === undefined) d.media = true;
        const out = [];
        const old = [
            ["clock", d.clock, "classic"], ["media", d.media, "card"],
            ["calendar", d.calendar, "month"], ["network", d.network, "card"],
            ["cpu", d.cpu, "ring"], ["ram", d.ram, "ring"], ["battery", d.battery, "ring"]
        ];
        for (const [type, on, variant] of old)
            if (on) out.push({ uid: type, type: type, variant: variant });
        Settings.desktop.placed = out;
    }

    function newUid(type) {
        return type + "-" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
    }

    // Add a widget and select it. New widgets land near the middle, nudged
    // along a little per widget so several added in a row do not stack.
    function add(type, variant) {
        const t = WidgetCatalog.typeInfo(type);
        if (!t) return "";
        const v = WidgetCatalog.variantInfo(type, variant);
        const uid = root.newUid(type);
        const next = root.placedList.slice();
        next.push({ uid: uid, type: type, variant: v.id });

        const layout = {};
        const current = Settings.desktop.widgetLayout || ({});
        for (const k in current) layout[k] = current[k];
        const n = next.length % 6;
        layout[uid] = { x: 0.38 + n * 0.03, y: 0.22 + n * 0.04 };
        Settings.desktop.widgetLayout = layout;

        Settings.desktop.placed = next;
        root.selectedUid = uid;
        return uid;
    }

    function remove(uid) {
        Settings.desktop.placed = root.placedList.filter(w => w.uid !== uid);
        const layout = {}, scales = {};
        const cl = Settings.desktop.widgetLayout || ({});
        const cs = Settings.desktop.widgetScale || ({});
        for (const k in cl) if (k !== uid) layout[k] = cl[k];
        for (const k in cs) if (k !== uid) scales[k] = cs[k];
        Settings.desktop.widgetLayout = layout;
        Settings.desktop.widgetScale = scales;
        if (root.selectedUid === uid) root.selectedUid = "";
    }

    // Same uid, so position and size carry over to the new style.
    function setVariant(uid, variant) {
        Settings.desktop.placed = root.placedList.map(w =>
            w.uid === uid ? { uid: w.uid, type: w.type, variant: variant } : w);
    }

    function setScale(uid, s) {
        const scales = {};
        const cs = Settings.desktop.widgetScale || ({});
        for (const k in cs) scales[k] = cs[k];
        scales[uid] = Math.round(s * 100) / 100;
        Settings.desktop.widgetScale = scales;
    }

    function widget(uid) {
        for (const w of root.placedList) if (w.uid === uid) return w;
        return null;
    }

    Variants {
        model: root.wanted
            ? (root.editing
                ? Quickshell.screens
                : Quickshell.screens.filter(s => Hypr.desktopVisibleOn(s)))
            : []

        PanelWindow {
            id: surface

            required property var modelData

            screen: surface.modelData
            visible: true
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            // Bottom normally; Overlay while arranging, so the widgets are
            // reachable without first clearing the workspace.
            WlrLayershell.layer: root.editing ? WlrLayer.Overlay : WlrLayer.Bottom
            WlrLayershell.namespace: "qs-widgets"
            WlrLayershell.keyboardFocus: root.editing
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Input policy.
            //
            //   arranging -> the whole surface takes input (mask: null)
            //   otherwise -> ONLY the widgets that are genuinely interactive
            //
            // The default is click-through, because a decorative widget that
            // eats a click meant for the desktop is worse than no widget. The
            // media players are the exception: they have transport buttons,
            // and a play button you cannot press is not a player. Each one's
            // rectangle is punched out of the click-through mask, and nothing
            // else is.
            //
            // A FIXED POOL OF SLOTS, not one Region per widget: a Region's
            // children are declared, not modelled, so there is no clean way to
            // grow the list at runtime. Four slots is more media players than
            // anyone puts on one screen; a fifth would still draw and still
            // update, it just would not take clicks.
            //
            // A Region with no item and no children is empty, which is what
            // makes the surface click-through rather than merely transparent.
            mask: root.editing ? null : liveRegion

            property var interactiveItems: []

            function registerInteractive(item) {
                if (surface.interactiveItems.indexOf(item) >= 0) return;
                surface.interactiveItems = surface.interactiveItems.concat([item]);
            }

            function unregisterInteractive(item) {
                surface.interactiveItems = surface.interactiveItems.filter(i => i !== item);
            }

            // Dropping a hidden widget's item is what stops a player with
            // nothing to play from leaving an invisible hole in the desktop
            // that still swallows clicks.
            function slot(i) {
                const it = surface.interactiveItems[i];
                return it && it.visible ? it : null;
            }

            Region {
                id: liveRegion

                Region { item: surface.slot(0) }
                Region { item: surface.slot(1) }
                Region { item: surface.slot(2) }
                Region { item: surface.slot(3) }
            }

            // --- edit scrim ------------------------------------------------
            Rectangle {
                anchors.fill: parent
                visible: root.editing
                color: Qt.rgba(0, 0, 0, 0.35)
                opacity: root.editing ? 1 : 0

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationNormal }
                }

                // Clicking the empty desktop deselects, and with nothing
                // selected finishes arranging -- which is what everyone tries
                // before looking for a button.
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.selectedUid !== "") root.selectedUid = "";
                        else root.done();
                    }
                }
            }

            // Snap grid, drawn only while arranging so there is something for
            // the snapping to visibly line up against.
            Loader {
                anchors.fill: parent
                active: root.editing && Settings.desktop.snapToGrid
                sourceComponent: Canvas {
                    renderStrategy: Canvas.Cooperative

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = Theme.wash(Theme.text, 0.07);
                        ctx.lineWidth = 1;

                        // Drawn at a multiple of the snap step -- a line every
                        // 8px would be a grey wash, not a grid.
                        const step = Math.max(16, Settings.desktop.gridSize * 8);
                        for (let x = 0; x < width; x += step) {
                            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                        }
                        for (let y = 0; y < height; y += step) {
                            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                        }
                    }
                }
            }

            // --- the widgets ------------------------------------------------
            Item {
                id: field

                anchors.fill: parent
                // Keep everything clear of the bar, so a widget dragged to the
                // top edge does not end up half underneath it.
                anchors.topMargin: Appearance.barClearance
                anchors.margins: Appearance.screenMargin

                // DEFAULT POSITIONS MUST CLEAR THE VISUALIZER BAND.
                //
                // modules/visualizer/Visualizer.qml draws on the same
                // WlrLayer.Bottom, anchored to the bottom edge. At the current
                // 280/150 offset/height that is screen y 770..920 on this
                // 1200 px panel. The styles' default positions keep above
                // ~0.48 or below ~0.82 of the height for that reason; new
                // widgets from the picker land near the middle-top.
                Repeater {
                    // Delegates read modelData only: a Repeater over a JS array
                    // does not inject `index` here.
                    model: root.placedList

                    // Each widget is loaded from its style's file, then lifted
                    // out of the Loader onto `field`: DesktopWidget resolves its
                    // saved position against its PARENT's size, and a Loader
                    // sizes itself to its item, which would make every widget
                    // position itself inside its own box.
                    Loader {
                        id: host

                        required property var modelData

                        readonly property var style: WidgetCatalog.variantInfo(host.modelData.type, host.modelData.variant)

                        Component.onCompleted: {
                            const props = { widgetId: host.modelData.uid };
                            const extra = host.style ? host.style.props : {};
                            for (const k in extra) props[k] = extra[k];
                            host.setSource(Qt.resolvedUrl(host.style.file), props);
                        }

                        onLoaded: {
                            host.item.parent = field;
                            if (host.item.interactive) surface.registerInteractive(host.item);
                        }

                        Component.onDestruction: if (host.item) surface.unregisterInteractive(host.item)

                        Binding {
                            target: host.item
                            when: !!host.item
                            property: "editing"
                            value: root.editing
                        }

                        Binding {
                            target: host.item
                            when: !!host.item
                            property: "selected"
                            value: root.editing && root.selectedUid === host.modelData.uid
                        }

                        // Hidden, not removed, while it has nothing to show (no
                        // player, no battery) -- except while arranging, so it
                        // can still be found and moved or deleted.
                        Binding {
                            target: host.item
                            when: !!host.item
                            property: "visible"
                            value: root.editing || WidgetCatalog.available(host.modelData.type)
                        }

                        Connections {
                            target: host.item
                            ignoreUnknownSignals: true
                            function onSelectRequested() { root.selectedUid = host.modelData.uid; }
                        }
                    }
                }
            }

            // --- the picker -----------------------------------------------------
            // On the focused screen only; the others just show their widgets
            // lifted and draggable.
            WidgetPicker {
                visible: root.editing && Hypr.isActiveScreen(surface.modelData)
                widgets: root
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.xl
                width: Math.min(parent.width - Appearance.xl * 2, 1180)
            }

            // Escape leaves edit mode, matching every panel in the shell;
            // Delete removes the selected widget.
            Item {
                anchors.fill: parent
                focus: root.editing
                Keys.onEscapePressed: root.done()
                Keys.onDeletePressed: if (root.selectedUid !== "") root.remove(root.selectedUid)
            }
        }
    }
}
