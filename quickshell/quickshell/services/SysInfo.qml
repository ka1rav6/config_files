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
