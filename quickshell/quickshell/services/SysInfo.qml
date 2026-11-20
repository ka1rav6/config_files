pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// SysInfo — CPU, memory and uptime.
// =============================================================================
// The one genuinely poll-based service in the shell, because /proc has no
// change notification: there is no event for "CPU usage moved".
//
// SO IT IS GATED THREE WAYS
//   1. Reference-counted demand. Nothing reads /proc unless a visible widget
//      has asked for it, and the timer stops the moment the last one goes.
//      An unopened dashboard costs nothing.
//   2. Performance.pollInterval, so the profile decides the rate: 2 s in
//      Visual, 5 s Balanced, 10 s in Battery Saver, 30 s in game mode.
//   3. Reads, not subprocesses. /proc/stat and /proc/meminfo are read through
//      FileView rather than by shelling out to `top` or `free` -- a subprocess
//      every few seconds is far more expensive than the numbers are worth.
//
// CPU PERCENTAGE
//   /proc/stat gives cumulative jiffies since boot, so a single read says
//   nothing about current load. The usage below is the delta between two
//   reads -- which is why the first sample after enabling reads zero.
// =============================================================================

Singleton {
    id: root

    // --- demand -----------------------------------------------------------
    property var consumers: ({})

    function want(id) {
        if (root.consumers[id]) return;
        const next = {};
        for (const k in root.consumers) next[k] = true;
        next[id] = true;
        root.consumers = next;
    }

    function drop(id) {
        if (!root.consumers[id]) return;
        const next = {};
        for (const k in root.consumers) { if (k !== id) next[k] = true; }
        root.consumers = next;
    }

    readonly property bool wanted: Object.keys(root.consumers).length > 0

    // --- readings ----------------------------------------------------------

    property real cpuUsage: 0          // 0..1
    property real memoryUsage: 0       // 0..1
    property real memoryUsedGb: 0
    property real memoryTotalGb: 0
    property int uptimeSeconds: 0

    property real diskUsage: 0         // 0..1
    property real diskUsedGb: 0
    property real diskTotalGb: 0

    // Degrees C, or -1 when no sensor was found -- callers hide the row on -1.
    property real cpuTempC: -1

    // The sysfs file to read it from. Thermal zone NUMBERS are assigned at
    // probe time and are not stable across boots or kernels, so the zone is
    // found by its TYPE once at startup: x86_pkg_temp is the package sensor the
    // CPU itself reports, TCPU is the ACPI view of it, acpitz a last resort.
    property string tempPath: ""

    // Previous /proc/stat totals, for the delta.
    property real lastIdle: 0
    property real lastTotal: 0

    Timer {
        // Rate comes from the performance profile, not from here.
        interval: Performance.pollInterval
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            uptimeFile.reload();
            if (root.tempPath !== "") tempFile.reload();
            // Disk has no /proc equivalent -- statvfs is a syscall, not a file
            // -- so this is the one subprocess here. It runs at the same
            // gated interval as everything else, and free space does not move
            // fast enough to want more.
            if (!diskProc.running) diskProc.running = true;
        }
    }

    // Reset the delta baseline when polling stops, so the first reading after
    // it resumes is not an average over the whole idle period.
    onWantedChanged: if (!root.wanted) { root.lastTotal = 0; root.lastIdle = 0; }

    FileView {
        id: statFile

        path: "/proc/stat"
        printErrors: false

        onLoaded: {
            // First line: cpu  user nice system idle iowait irq softirq steal
            const line = statFile.text().split("\n")[0];
            const parts = line.trim().split(/\s+/);
            if (parts.length < 5) return;

            let total = 0;
            for (let i = 1; i < parts.length; i++) total += parseInt(parts[i]) || 0;
            const idle = (parseInt(parts[4]) || 0) + (parseInt(parts[5]) || 0);

            if (root.lastTotal > 0) {
                const dTotal = total - root.lastTotal;
                const dIdle = idle - root.lastIdle;
                if (dTotal > 0)
                    root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
            }
            root.lastTotal = total;
            root.lastIdle = idle;
        }
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        printErrors: false

        onLoaded: {
            const text = memFile.text();
            const grab = (key) => {
                const m = new RegExp("^" + key + ":\\s+(\\d+)", "m").exec(text);
                return m ? parseInt(m[1]) : 0;
            };
            const total = grab("MemTotal");
            // MemAvailable, not MemFree: free excludes cache and reclaimable
            // slab, so it reports a machine with a warm page cache as nearly
            // out of memory. Available is the kernel's own estimate of what a
            // new allocation could actually get.
            const available = grab("MemAvailable");
            if (total <= 0) return;

            root.memoryTotalGb = total / 1048576;
            root.memoryUsedGb = (total - available) / 1048576;
            root.memoryUsage = Math.max(0, Math.min(1, (total - available) / total));
        }
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeSeconds = Math.floor(parseFloat(uptimeFile.text().split(" ")[0]) || 0)
    }

    // One-shot sensor discovery. Runs once per process, not per poll.
    Process {
        running: true
        command: ["sh", "-c",
            "for t in x86_pkg_temp TCPU acpitz; do for z in /sys/class/thermal/thermal_zone*; do "
          + "[ \"$(cat $z/type 2>/dev/null)\" = $t ] && echo $z/temp && exit; done; done"]
        stdout: SplitParser { onRead: (line) => root.tempPath = line.trim() }
    }

    FileView {
        id: tempFile

        path: root.tempPath
        printErrors: false
        // Millidegrees. A sensor that reads 0 or garbage is treated as absent.
        onLoaded: {
            const milli = parseInt(tempFile.text());
            root.cpuTempC = milli > 0 ? milli / 1000 : -1;
        }
    }

    Process {
        id: diskProc

        // 1K blocks on /, as two plain numbers. `df -P` is the POSIX output
        // format, which is one line per filesystem and never wraps -- plain
        // `df` wraps long device names onto a second line and breaks parsing.
        command: ["sh", "-c", "df -P -k / | awk 'NR==2 {print $2, $3}'"]
        running: false

        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.trim().split(/\s+/);
                if (parts.length < 2) return;
                const total = parseInt(parts[0]) || 0;
                const used = parseInt(parts[1]) || 0;
                if (total <= 0) return;
                root.diskTotalGb = total / 1048576;
                root.diskUsedGb = used / 1048576;
                root.diskUsage = Math.max(0, Math.min(1, used / total));
            }
        }
    }

    readonly property string uptimeText: {
        const s = root.uptimeSeconds;
        if (s <= 0) return "";
        const days = Math.floor(s / 86400);
        const hours = Math.floor((s % 86400) / 3600);
        const mins = Math.floor((s % 3600) / 60);
        if (days > 0) return days + "d " + hours + "h";
        if (hours > 0) return hours + "h " + mins + "m";
        return mins + "m";
    }
}
