pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

// =============================================================================
// Performance — turns the chosen profile into the live switches the shell reads.
// =============================================================================
// Every expensive thing in the shell asks this singleton whether it is allowed
// to run, instead of checking the battery or the profile itself. That keeps the
// policy in one place: changing what "Battery Saver" means is an edit here, not
// a sweep through a dozen components.
//
// THE THREE PROFILES
//
//   saver     No visualizer. No blur. Minimal motion. Widgets update slowly.
//             The target is a desktop that costs as close to nothing as a
//             desktop can while still being the same desktop.
//
//   balanced  The designed experience. Visualizer runs but only while audio is
//             actually playing, blur is on, animations are full speed.
//
//   visual    Everything on, nothing gated. Higher visualizer framerate, more
//             bands. Intended for AC power on the external monitor.
//
// AUTOMATIC DOWNSHIFT
//   With `autoSaverOnBattery`, unplugging drops the *effective* profile to
//   saver without touching the *chosen* profile, so plugging back in restores
//   whatever was picked. The Settings UI shows both -- "Balanced (on battery:
//   saver)" -- so the downshift is never a mystery.
//
// GAME MODE
//   Orthogonal to the profile. Triggered by a fullscreen window rather than by
//   power state, and it suppresses shell *work* (the visualizer process, widget
//   timers) rather than shell *pixels*. Hiding widgets over a fullscreen window
//   is a separate setting, desktop.hideOnFullscreen, because wanting a clean
//   screen and wanting a cheap screen are different wants.
//
//   `fullscreenActive` is set by services/Hypr.qml, which is the only thing
//   that knows about windows. This singleton deliberately does not import
//   Hyprland -- it would make a policy object depend on a compositor.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // Set by services/Hypr.qml when any monitor has a fullscreen window.
    property bool fullscreenActive: false

    // -----------------------------------------------------------------
    // Profile resolution
    // -----------------------------------------------------------------

    // What the user picked, straight from settings.json.
    readonly property string chosenProfile: Settings.performance.profile

    // UPower's own AC/battery state. Event-driven over D-Bus -- no polling,
    // no reading /sys on a timer.
    readonly property bool onBattery: UPower.onBattery

    // What is actually in force right now.
    readonly property string profile: {
        if (Settings.performance.autoSaverOnBattery && root.onBattery)
            return "saver";
        return root.chosenProfile;
    }

    // True when the downshift above is what is holding the profile down, so
    // the Settings UI can explain itself rather than appearing to ignore the
    // user's choice.
    readonly property bool downshifted: root.profile !== root.chosenProfile

    readonly property bool saver: root.profile === "saver"
    readonly property bool visual: root.profile === "visual"

    // True while an expensive foreground app should be left alone.
    readonly property bool gameMode: Settings.performance.gameMode && root.fullscreenActive

    // -----------------------------------------------------------------
    // The switches components actually read
    // -----------------------------------------------------------------

    // May the audio visualizer run at all? Note this is only the *policy*
    // gate. services/Cava.qml adds the playback gate on top, so even here
    // being true does not mean a cava process exists.
    //
    // UNPLUGGING DOES NOT TURN THE VISUALISER OFF.
    //   It used to: autoSaverOnBattery drops the effective profile to saver,
    //   and saver blocked the visualiser outright. So the bars vanished the
    //   moment the charger came out, with no visible cause -- which read as
    //   "the visualiser broke again" rather than as a power policy.
    //
    //   Battery should mean a CHEAPER visualiser, not none, and the machinery
    //   for that already exists: visualizerFramerate halves to 30 Hz and
    //   visualizerBands drops. That takes it from ~15 % of a core to ~7 %,
    //   which is a reasonable thing to spend while music is playing and the
    //   desktop is actually on screen.
    //
    //   So an AUTOMATIC downshift no longer blocks it. Deliberately CHOOSING
    //   saver in Settings still does, because that is an explicit "make
    //   everything cheap" instruction rather than a side effect of a cable.
    //   Settings.performance.visualizerOnBattery turns the leniency off.
    readonly property bool allowVisualizer: {
        if (root.gameMode) return false;
        if (root.chosenProfile === "saver") return false;
        if (root.saver && !Settings.performance.visualizerOnBattery) return false;
        return true;
    }

    // May shell surfaces ask Hyprland to blur behind them? Blur is the
    // compositor's most expensive effect (see the long note in
    // ~/.config/hypr/looknfeel.lua), so it is the first thing saver drops.
    readonly property bool allowBlur: Settings.appearance.blur && !root.saver && !root.gameMode

    readonly property bool allowShadows: Settings.appearance.shadows && !root.saver

    // Animation duration multiplier. Zero means "jump straight to the end
    // state", which every Behavior in the shell handles correctly because
    // ui/Motion.qml routes all of them through this.
    readonly property real motionScale: {
        if (Settings.appearance.motion <= 0)
            return 0;               // explicit reduced-motion, honoured always
        if (root.gameMode)
            return 0;               // never animate over a game
        if (root.saver)
            return 0.6;             // shorter, not absent -- still legible
        return Settings.appearance.motion;
    }

    // How often widgets that read /proc or shell out may refresh, in ms.
    // Widgets multiply their natural interval by this rather than picking a
    // number, so one policy change moves all of them.
    readonly property int pollInterval: {
        if (root.gameMode)
            return 30000;           // effectively parked
        if (root.saver)
            return 10000;
        if (root.visual)
            return 2000;
        return 5000;
    }

    // Visualizer detail, scaled by profile. The band count is the dominant
    // cost in both cava and the renderer, so saver never gets here (the
    // allowVisualizer gate above stops it first) and visual gets more.
    readonly property int visualizerBands: {
        const base = Settings.visualizer.bands;
        if (root.visual)
            return Math.min(128, Math.round(base * 1.5));
        // Running on a battery downshift: fewer bands as well as fewer frames.
        if (root.saver)
            return Math.max(32, Math.round(base * 0.6));
        return base;
    }

    readonly property int visualizerFramerate: {
        const base = Settings.visualizer.framerate;
        if (root.onBattery)
            return Math.min(base, 30);   // halves cava's wakeups on battery
        return base;
    }

    // -----------------------------------------------------------------
    // Battery, exposed here so widgets and the Control Center share one
    // reading rather than each opening their own UPower subscription.
    // -----------------------------------------------------------------

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool hasBattery: root.batteryDevice && root.batteryDevice.isLaptopBattery
    readonly property real batteryPercent: root.hasBattery ? root.batteryDevice.percentage : 0
    readonly property bool batteryCharging: root.hasBattery && root.batteryDevice.state === UPowerDeviceState.Charging
    readonly property real batteryHealth: root.hasBattery && root.batteryDevice.healthSupported ? root.batteryDevice.healthPercentage : 0

    // Seconds remaining, or 0 when UPower has not worked it out yet (it needs
    // a few minutes of discharge history after a resume before this is real).
    readonly property real batteryTimeRemaining: {
        if (!root.hasBattery)
            return 0;
        return root.batteryCharging ? root.batteryDevice.timeToFull : root.batteryDevice.timeToEmpty;
    }
}
