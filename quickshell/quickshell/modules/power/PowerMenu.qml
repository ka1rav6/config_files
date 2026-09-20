import QtQuick
import Quickshell
import qs

// =============================================================================
// Power menu.  SUPER + M  (and the power button in the Control Center)
// =============================================================================
// Replaces wlogout, which ~/.config/waybar/scripts/power-menu.sh shells out to.
// That script stays in place and still works -- it is the fallback for when
// Quickshell is not running, which is exactly when you might most need to
// reboot. Nothing here removes it.
//
// SAFETY: THE DESTRUCTIVE ACTIONS ARE BEHIND A CONFIRMATION
//   Lock and Suspend are one click: they are trivially reversible and you do
//   them a dozen times a day. Logout, Reboot and Shutdown lose unsaved work, so
//   they arm first and commit second, with a visible countdown that cancels
//   itself. That is deliberately more friction than wlogout had -- wlogout's
//   five big buttons mean a mistyped SUPER+M then Enter can power the machine
//   off, and this is a laptop that gets its lid closed mid-thought.
//
// KEYBOARD
//   Arrow keys / hjkl move, Enter activates, Escape cancels. Every action also
//   has a mnemonic shown on its tile.
// =============================================================================

Panel {
    id: root

    name: "power"
    placement: "center"
    panelWidth: 560
    // Modal: this is the one panel where a misclick has consequences, so the
    // desktop behind it is dimmed to make it unmistakably a mode.
    scrim: true

    // Which action is armed and awaiting confirmation. Empty means none.
    property string arming: ""

    onClosed: root.arming = ""

    readonly property var actions: [
        { id: "lock",     label: "Lock",     icon: "lock",     key: "L", confirm: false },
        { id: "suspend",  label: "Suspend",  icon: "suspend",  key: "S", confirm: false },
        { id: "logout",   label: "Log out",  icon: "logout",   key: "O", confirm: true  },
        { id: "reboot",   label: "Restart",  icon: "restart",  key: "R", confirm: true  },
        { id: "shutdown", label: "Shut down",icon: "power",    key: "P", confirm: true  }
    ]

    function run(id) {
        switch (id) {
        case "lock":
            // hyprlock, with the same --grace 5 the rest of the system passes.
            // See ~/.config/hypr/hypridle.conf: the grace period is a
            // command-line flag since hyprlock 0.9.6 dropped the config option,
            // and the value has to match in every caller.
            Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock --grace 5"]);
            break;
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "logout":
            // Go through loginctl rather than `hyprctl dispatch exit`: it ends
            // the SESSION, so anything outside the compositor is torn down too.
            Quickshell.execDetached(["loginctl", "terminate-session", ""]);
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "shutdown":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
        root.hide();
    }

    function activate(id) {
        const action = root.actions.find(a => a.id === id);
        if (!action) return;

        if (!action.confirm) {
            // Flush any pending settings write before the machine goes away.
            Settings.flush();
            root.run(id);
            return;
        }

        if (root.arming === id) {
            Settings.flush();
            root.run(id);
        } else {
            root.arming = id;
            disarm.restart();
        }
    }

    // An armed action that is ignored disarms itself, so a red "click again to
    // shut down" button is never left sitting there waiting to be brushed.
    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.arming = ""
    }

    content: Column {
        spacing: Appearance.lg

        Column {
            width: parent.width
            spacing: 2

            Text {
                text: root.arming === "" ? "Power" : "Press again to confirm"
                color: root.arming === "" ? Theme.text : Theme.error
                font.family: Appearance.font
                font.pixelSize: Appearance.fontHeading
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationNormal }
                }
            }

            Text {
                text: {
                    if (root.arming !== "") {
                        const a = root.actions.find(x => x.id === root.arming);
                        return (a ? a.label : "") + " — this will close everything you have open";
                    }
                    if (Performance.hasBattery) {
                        return Math.round(Performance.batteryPercent * 100) + "% battery"
                             + (Performance.batteryCharging ? ", charging" : " remaining");
                    }
                    return Time.longDate;
                }
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
            }
        }

        Row {
            width: parent.width
            spacing: Appearance.sm

            readonly property real cell: (width - spacing * (root.actions.length - 1)) / root.actions.length

            Repeater {
                model: root.actions

                PowerTile {
                    required property var modelData
                    required property int index

                    width: parent.cell
                    action: modelData
                    armed: root.arming === modelData.id
                    focused: powerKeys.selected === index
                    onTriggered: root.activate(modelData.id)
                    onHovered: powerKeys.selected = index
                }
            }
        }

        // Keyboard driving. Lives here rather than on the Panel because the
        // selection index belongs to this content, and the content is rebuilt
        // every time the panel opens -- so the selection always starts at Lock.
        Item {
            id: powerKeys

            property int selected: 0

            focus: true
            width: 0
            height: 0

            Keys.onPressed: (event) => {
                switch (event.key) {
                case Qt.Key_Right:
                case Qt.Key_L:
                    powerKeys.selected = (powerKeys.selected + 1) % root.actions.length;
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                case Qt.Key_H:
                    powerKeys.selected = (powerKeys.selected - 1 + root.actions.length) % root.actions.length;
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root.activate(root.actions[powerKeys.selected].id);
                    event.accepted = true;
                    break;
                default:
                    // Mnemonics: the letter shown on each tile.
                    for (const action of root.actions) {
                        if (event.text.toUpperCase() === action.key) {
                            root.activate(action.id);
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }
        }
    }
}
