pragma Singleton

import QtQuick
import Quickshell
import qs

// =============================================================================
// Appearance — the design system's numbers.
// =============================================================================
// Every measurement in the shell comes from here. No component picks its own
// padding, radius, duration or type size. That is the whole reason the desktop
// reads as one environment rather than as a pile of widgets: not that the
// colours match, but that the *rhythm* does -- the same 12 px step, the same
// 16 px radius, the same 180 ms ease everywhere.
//
// THE SCALE
//   Spacing is a single base unit (Settings.appearance.spacing, default 12)
//   multiplied by a small set of named steps. Using xs/sm/md/lg/xl rather than
//   raw numbers means "tighten the whole UI" is one setting change, and means
//   a reviewer can see at a glance that two components are on the same rhythm.
//
//   Radius works the same way, but scaled DOWN from the card radius rather than
//   up: a pill inside a card must be rounder than the card or the corners look
//   pinched, so `inner` is derived from `card` rather than declared separately.
//
// DENSITY
//   "compact" tightens spacing and control heights without touching type size.
//   That is deliberate -- shrinking text to fit more in is a readability
//   regression, shrinking whitespace is a density preference.
//
// MOTION
//   Durations route through Performance.motionScale, so reduced-motion, battery
//   saver and game mode all take effect without any component knowing about
//   them. A duration of 0 makes Behaviors jump, which QML handles correctly.
//
//   The easing curves are the taste, not the timing. `standard` is a gentle
//   out-cubic for things entering; `emphasised` overshoots very slightly for
//   things the user summoned and should feel land.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    readonly property bool compact: Settings.appearance.density === "compact"

    // -----------------------------------------------------------------
    // Spacing scale
    // -----------------------------------------------------------------

    readonly property int unit: Settings.appearance.spacing

    readonly property int xs: Math.round(root.unit * 0.25)   //  3
    readonly property int sm: Math.round(root.unit * 0.5)    //  6
    readonly property int md: root.unit                      // 12
    readonly property int lg: Math.round(root.unit * 1.5)    // 18
    readonly property int xl: Math.round(root.unit * 2)      // 24
    readonly property int xxl: Math.round(root.unit * 3)     // 36

    // Padding inside a card. The single most-used number in the shell.
    readonly property int padding: root.compact ? root.md : root.lg

    // Gap between sibling cards in a stack or grid.
    readonly property int gap: root.compact ? root.sm : root.md

    // Distance a floating surface keeps from the screen edge. Matches waybar's
    // 14 px side margin in ~/.config/waybar/config.jsonc, so the bar and the
    // panels below it share one left edge rather than being 2 px apart.
    readonly property int screenMargin: 14

    // -----------------------------------------------------------------
    // Radius scale
    // -----------------------------------------------------------------

    readonly property int radius: Settings.appearance.radius          // cards, panels
    readonly property int radiusInner: Math.round(root.radius * 0.6)  // controls in a card
    readonly property int radiusSmall: Math.round(root.radius * 0.35) // chips, bars
    readonly property int radiusFull: 999                             // pills, avatars

    // -----------------------------------------------------------------
    // Control metrics
    //
    // Hit targets stay at or above 36 px even when compact. This is a
    // convertible laptop -- these get touched, not just clicked.
    // -----------------------------------------------------------------

    readonly property int controlHeight: root.compact ? 36 : 44
    readonly property int controlHeightSmall: root.compact ? 28 : 32
    readonly property int iconSize: root.compact ? 18 : 20
    readonly property int iconSizeLarge: root.compact ? 24 : 28
    readonly property int touchTarget: 40                    // minimum, never scaled down

    readonly property int borderWidth: 1

    // -----------------------------------------------------------------
    // Typography
    //
    // A modular scale at roughly 1.2x per step, rounded to whole pixels
    // because fractional font sizes render blurry at 1.5x panel scaling.
    // -----------------------------------------------------------------

    readonly property string font: Settings.appearance.font
    readonly property string fontMono: Settings.appearance.fontMono
    readonly property real fontScale: Settings.appearance.fontScale

    function size(px) {
        return Math.round(px * root.fontScale);
    }

    readonly property int fontCaption: root.size(11)   // timestamps, units
    readonly property int fontSmall: root.size(12)     // secondary labels
    readonly property int fontBody: root.size(13)      // default
    readonly property int fontLabel: root.size(14)     // control labels
    readonly property int fontTitle: root.size(17)     // card headings
    readonly property int fontHeading: root.size(22)   // panel headings
    readonly property int fontDisplay: root.size(48)   // the desktop clock

    // Weights, named so the intent survives a font change. Inter has the full
    // range; the fallback stack degrades gracefully.
    readonly property int weightNormal: Font.Normal
    readonly property int weightMedium: Font.Medium
    readonly property int weightSemi: Font.DemiBold
    readonly property int weightBold: Font.Bold

    // Letter spacing. Large display type needs negative tracking to stop it
    // looking loose; small caps-ish labels need positive.
    readonly property real trackingDisplay: -1.5
    readonly property real trackingHeading: -0.4
    readonly property real trackingLabel: 0.2

    // -----------------------------------------------------------------
    // Motion
    //
    // Four durations, and no component may invent a fifth. Multiplied by
    // Performance.motionScale so reduced-motion / saver / game mode all work
    // without the component knowing.
    // -----------------------------------------------------------------

    function duration(ms) {
        return Math.round(ms * Performance.motionScale);
    }

    readonly property int durationFast: root.duration(120)      // hover, press
    readonly property int durationNormal: root.duration(180)    // most transitions
    readonly property int durationSlow: root.duration(280)      // panels opening
    readonly property int durationSlower: root.duration(420)    // wallpaper crossfade

    // True when motion is off entirely, so a component can skip building an
    // animation object rather than building one with duration 0.
    readonly property bool motionless: Performance.motionScale <= 0

    // Easing. Exposed as enum + optional bezier overshoot so every Behavior in
    // the shell pulls from the same two curves.
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeEmphasised: Easing.OutBack
    readonly property int easeEnter: Easing.OutQuint
    readonly property int easeExit: Easing.InCubic

    // How far `easeEmphasised` overshoots. The QML default of 1.7 is a cartoon
    // bounce; 0.6 is a settle you feel rather than watch.
    readonly property real overshoot: 0.6

    // -----------------------------------------------------------------
    // Surfaces
    //
    // Opacity is a setting, but it is clamped: a fully transparent panel is
    // unreadable, and a fully opaque one makes the blur layer rule in
    // ~/.config/hypr/rules.lua pure wasted GPU work (see the note there about
    // blurring behind opaque surfaces).
    // -----------------------------------------------------------------

    readonly property real surfaceOpacity: Math.max(0.35, Math.min(0.98, Settings.appearance.opacity))

    // Cards sitting inside an already-translucent panel must be more opaque
    // than it, or the layers stop reading as layers.
    readonly property real cardOpacity: Math.min(1.0, root.surfaceOpacity + 0.08)

    readonly property bool blur: Performance.allowBlur
    readonly property bool shadows: Performance.allowShadows

    // Shadow geometry. Kept shallow deliberately -- the Hyprland window shadow
    // in looknfeel.lua is range 10 / offset 0,3, and shell surfaces that cast a
    // deeper shadow than windows look like they are floating off the screen.
    readonly property int shadowRadius: 18
    readonly property int shadowOffset: 4

    // -----------------------------------------------------------------
    // Layout
    // -----------------------------------------------------------------

    // Space to leave clear at the top for waybar: its margin-top (8) plus its
    // height (38), plus a gap. Panels anchored to the top start below this so
    // they never collide with the bar. Kept in step with
    // ~/.config/waybar/config.jsonc by hand -- there is no way to query it.
    readonly property int barClearance: 8 + 38 + 8

    // Default width for a side panel (Control Center, notification centre).
    readonly property int panelWidth: 400

    // Default width for a centred modal (Settings, launcher).
    readonly property int modalWidth: 880
    readonly property int modalHeight: 620
}
