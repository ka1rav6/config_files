import QtQuick
import Quickshell
import qs

// =============================================================================
// Dashboard.  SUPER + SHIFT + D
// =============================================================================
// The at-a-glance panel: clock, calendar, media, and system usage. Distinct
// from the Control Center, which is for CHANGING things -- this one is for
// LOOKING at them, and nothing here alters system state.
//
// System polling is reference-counted (see services/SysInfo.qml) and asked for
// only while this panel is open, so an unopened dashboard reads no /proc at
// all. Same for the MPRIS position tick.
// =============================================================================

Panel {
    id: root

    name: "dashboard"
    panelWidth: 420

    // Opened from the waybar clock it drops straight down out of the clock
    // (which is waybar's centre module, so horizontally centred); opened from
    // SUPER + SHIFT + D it comes in at the top right as before. Same panel,
    // same content -- only where it lands differs, so the gesture that opened
    // it is the one it appears to come from.
    property bool dropdown: false
    placement: root.dropdown ? "top-center" : "top-right"

    readonly property string consumerId: "dashboard"

    onOpened: {
        SysInfo.want(root.consumerId);
        Media.wantPosition(root.consumerId);
        Time.wantSeconds(root.consumerId);
    }

    onClosed: {
        // Back to the keybind position, so the next SUPER + SHIFT + D does not
        // inherit the waybar placement.
        root.dropdown = false;
        SysInfo.drop(root.consumerId);
        Media.dropPosition(root.consumerId);
        Time.dropSeconds(root.consumerId);
    }

    // A panel torn down without its onClosed running would leak the demand and
    // leave /proc being read forever.
    Component.onDestruction: {
        SysInfo.drop(root.consumerId);
        Media.dropPosition(root.consumerId);
        Time.dropSeconds(root.consumerId);
    }

    content: Column {
        spacing: Appearance.lg

        // --- clock ---------------------------------------------------------
        // The sections are their own files so the left drawer can reuse them:
        // DashClock, DashActions, DashSystem.
        DashClock {
            width: parent.width
        }

        // --- calendar ------------------------------------------------------
        Card {
            width: parent.width
            elevation: 0
            implicitHeight: calendar.implicitHeight + Appearance.md * 2

            Calendar {
                id: calendar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.md

                // The calendar owns the arrow keys while the dashboard is
                // open: left/right steps months, up/down steps years. It has
                // to actually hold focus for that to work -- the Panel routes
                // the keyboard to its content, and this is the only thing in
                // the content that wants it.
                focus: true

                // Always open on the current month rather than wherever it was
                // left days ago, and take focus each time.
                Connections {
                    target: root
                    function onOpened() {
                        calendar.reset();
                        calendar.forceActiveFocus();
                    }
                }
            }
        }

        // --- quick actions --------------------------------------------------
        // The four things most often wanted straight from a glance at the
        // clock. Deliberately few: this is a dashboard, and a wall of buttons
        // would make it a control panel.
        DashActions {
            width: parent.width
        }

        // --- media ---------------------------------------------------------
        CcMedia {
            width: parent.width
            visible: Media.available && Settings.features.music
        }

        // --- system ---------------------------------------------------------
        DashSystem {
            width: parent.width
        }
    }
}
