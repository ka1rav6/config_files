import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// =============================================================================
// Lock — the session lock. Runs in its own process; see lock.qml.
// =============================================================================
// Uses ext-session-lock-v1, the same protocol hyprlock uses: the compositor
// itself stops showing your windows and hands this client exclusive keyboard
// focus. It is not a fullscreen window that can be alt-tabbed away from.
//
// -----------------------------------------------------------------------------
// WHAT WENT WRONG THE FIRST TIME, AND WHAT CHANGED
//
// This shipped as a Loader inside shell.qml with the setting ON. The session
// fell over while locked -- xdg-desktop-portal and hyprpolkitagent both
// segfaulted in the same second -- and took the locker with it. The compositor
// did the right thing and kept the screen locked. Getting back in meant a TTY.
//
// Two distinct causes, both now addressed:
//
//   1. BLAST RADIUS. Everything in the shell shared one process with the lock.
//      Fixed by moving the lock into its own quickshell instance (lock.qml),
//      so a fault in the dock or the visualiser can no longer strand you.
//
//   2. A SECOND LOCKER ARRIVING ON TOP OF THIS ONE. hypridle's 300 s listener
//      runs `loginctl lock-session`, and its lock_cmd is
//      `pidof hyprlock || hyprlock --grace 5`. With this locker holding the
//      session, `pidof hyprlock` is false, so hyprlock launched INTO an
//      already-locked session roughly five minutes after the screen locked --
//      which is exactly when the failure happened.
//
//      This cannot be fixed from here. ~/.config/hypr/hypridle.conf has to
//      call ~/.local/bin/lock-session instead of hyprlock directly, and that
//      file is on the do-not-touch list. Until it is changed, leaving
//      Settings.features.lockScreen OFF is the correct setting, and it is the
//      default.
//
// RECOVERY, REGARDLESS
//   misc:allow_session_lock_restore is set at login (autostart.lua), and
//   lock-session relaunches hyprlock if this process exits without writing its
//   clean-unlock marker. A crash now surfaces hyprlock rather than a TTY.
//
// AUTHENTICATION
//   PamContext against /etc/pam.d/hyprlock, a one-line `auth include login`.
//   Reusing it means one policy to audit rather than two, and this accepts
//   exactly what hyprlock accepts.
// =============================================================================

Scope {
    id: root

    // Emitted once the session is genuinely unlocked and the marker is
    // written. lock.qml quits on this.
    signal released()

    // Written on a clean unlock, removed when the lock starts. Its absence
    // after the process exits is how lock-session detects a crash.
    readonly property string markerPath:
        Quickshell.env("XDG_RUNTIME_DIR") + "/qs-lock-clean"

    // -----------------------------------------------------------------
    // WHY EVERY READ OF session.locked IS A FUNCTION CALL AND NEVER A BINDING
    //
    // WlSessionLock.locked is asymmetric: READ returns the compositor's real
    // state, WRITE sets a target that is then realized. Its lockStateChanged
    // signal fires when a lock is acquired, but on a successful unlock the
    // emit is guarded by `if (isLocked())` -- false by then. A successful
    // unlock therefore produces no change notification at all.
    //
    // A QML binding caches and only re-evaluates on the notify signal, so
    // `readonly property bool locked: session.locked` latches true forever
    // after the first lock. An imperative read inside a function bypasses the
    // cache and asks the object, so these are always the truth.
    // -----------------------------------------------------------------

    function queryLocked() { return !!session.locked; }

    function engage() {
        markerClear.running = true;
        if (root.queryLocked()) return true;
        session.locked = true;
        return root.queryLocked();
    }

    function unlock() {
        // Marker first, then unlock: if the process is killed between the two
        // the marker still says the unlock was intended, and lock-session will
        // not spawn hyprlock over a session the user already opened.
        markerWrite.running = true;
        session.locked = false;
        root.released();
    }

    Process {
        id: markerClear
        running: false
        command: ["rm", "-f", root.markerPath]
    }

    Process {
        id: markerWrite
        running: false
        command: ["touch", root.markerPath]
    }

    // The surfaces are built from a Component and have no lexical access to
    // this scope, so they reach the lock through the registry.
    Component.onCompleted: Shell.lock = root
    Component.onDestruction: if (Shell.lock === root) Shell.lock = null

    WlSessionLock {
        id: session

        locked: false

        LockSurface {}
    }
}
