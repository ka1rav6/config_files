import QtQuick
import Quickshell
import qs

// =============================================================================
// lock.qml — the lock screen, as its OWN quickshell process.
// =============================================================================
// Run with:  quickshell -p ~/.config/quickshell/lock.qml
// Never by the main shell. ~/.local/bin/lock-session is what launches it.
//
// WHY THIS IS A SEPARATE PROCESS
//   It used to be one more Loader inside shell.qml. Under ext-session-lock the
//   compositor keeps the screen locked if the lock client dies -- correctly,
//   because a lock that fails open is not a lock -- so ANY fault anywhere in
//   the shell became "reboot from a TTY". That happened in real use.
//
//   Here the process contains the lock and nothing else: no dock, no widgets,
//   no visualiser, no cava subprocess, no IPC handlers, no wallpaper manager.
//   The singletons it touches are pulled in lazily by the surface itself, and
//   the ones that do the most work in the main shell are never referenced.
//
// AND IF IT STILL DIES
//   lock-session watches it. The lock writes a marker on a clean unlock; if
//   the process exits without one, lock-session treats that as a crash and
//   starts hyprlock, which can take over the existing lock because
//   misc:allow_session_lock_restore is set at login (see autostart.lua).
//   So the worst case is "hyprlock appeared", not a TTY.
// =============================================================================

ShellRoot {
    Lock {
        id: lock

        // This process exists only to lock. It does not consult
        // Settings.features.lockScreen -- being launched IS the decision, and
        // lock-session is what reads the setting.
        Component.onCompleted: lock.engage()

        // Quit once the session is unlocked, so nothing lingers. The marker
        // file is written first: its presence is how lock-session tells a
        // clean unlock from a crash.
        onReleased: Qt.quit()
    }
}
