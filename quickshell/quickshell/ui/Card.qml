import QtQuick
import QtQuick.Effects
import qs

// =============================================================================
// Card — the standard surface. Everything in the shell sits on one of these.
// =============================================================================
// Using one component for every surface is what makes the desktop read as a
// single environment. Radius, opacity, border and shadow all come from
// Appearance, so there is no way for two panels to end up 2px different.
//
// ELEVATION
//   Three levels, and no component may invent a fourth:
//     0  flush     — inside another card; no shadow, no border, just a tint
//     1  raised    — a normal card on the wallpaper
//     2  floating  — a popup or modal over other content
//   Higher elevation means a more opaque ground and a deeper shadow, which is
//   the only cue a translucent UI has for what is on top of what.
//
// WHY THE SHADOW IS A MultiEffect AND NOT A BORDER TRICK
//   Qt's MultiEffect renders the shadow on the GPU from the item's own alpha,
//   so it follows the rounded corners exactly and costs a shader pass rather
//   than a second painted rectangle. It is skipped entirely when shadows are
//   off (battery saver), because a disabled MultiEffect still allocates a
//   texture if it exists at all -- hence the Loader rather than `visible:false`.
// =============================================================================

Item {
    id: root

    // 0 flush · 1 raised · 2 floating
    property int elevation: 1

    // Override the ground colour (e.g. a selected row tinted with the accent).
    property color color: root.elevation === 0 ? Theme.wash(Theme.surface2, 0.5)
                                               : Theme.surface

    property real radius: Appearance.radius
    property bool border: root.elevation > 0
    property color borderColor: Theme.wash(Theme.border, 0.35)

    // Content goes here, so callers do not have to know about the background
    // rectangle or the shadow layer sitting behind it.
    default property alias content: contentItem.data

    readonly property real groundOpacity: {
        if (root.elevation === 0) return 1.0;                    // colour already has alpha
        if (root.elevation === 2) return Appearance.cardOpacity; // popups: more solid
        return Appearance.surfaceOpacity;
    }

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight

    // --- shadow ---------------------------------------------------------
    // Behind the ground, sized to it. Only constructed when shadows are on.
    Loader {
        anchors.fill: ground
        active: Appearance.shadows && root.elevation > 0
        z: -1

        sourceComponent: MultiEffect {
            source: ground
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: root.elevation === 2 ? 1.0 : 0.55
            shadowVerticalOffset: root.elevation === 2
                ? Appearance.shadowOffset : Appearance.shadowOffset / 2
            shadowHorizontalOffset: 0
            // The shadow is drawn from the source's alpha; drawing the source
            // itself here as well would double-paint the card.
            autoPaddingEnabled: true
            blurMax: Appearance.shadowRadius
        }
    }

    // --- ground ---------------------------------------------------------
    Rectangle {
        id: ground

        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.color.r, root.color.g, root.color.b,
                       root.color.a * root.groundOpacity)

        border.width: root.border ? Appearance.borderWidth : 0
        border.color: root.borderColor

        // Colour changes come from a theme switch, which should glide rather
        // than snap -- every card in the shell recolouring on the same curve
        // is what makes `just theme auto` feel like one event.
        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation {
                duration: Appearance.durationSlow
                easing.type: Appearance.easeStandard
            }
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
