import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// SystemPage — what the machine is doing, right now and over the last minute.
// =============================================================================
//   rings       CPU, memory, disk, temperature
//   activity    CPU and memory over the last ~60 samples, as sparklines
//   network     download / upload rate, with its own sparkline
//   processes   the five busiest, by CPU
//   machine     host, kernel, uptime, battery
//
// EVERYTHING HERE EXISTS ONLY WHILE THIS PAGE IS SHOWING.
//   * /proc polling through SysInfo is demanded on creation, dropped on
//     destruction, like every other SysInfo consumer.
//   * The history starts empty each time the page opens: it is sampled here,
//     not kept by a service in the background, because a graph nobody is
//     looking at is pure cost. It fills in about a minute.
//   * Network rates and the process list come from ONE short-lived process
//     every two seconds (`cat /proc/net/dev` + `ps`), on a Timer that only
//     exists with the page.
//   * host/kernel are read once, on open.
// =============================================================================

Column {
    id: root

    required property var drawer

    spacing: Appearance.lg

    Component.onCompleted: {
        SysInfo.want("drawer-system");
        unameProc.running = true;
        statProc.running = true;
    }
    Component.onDestruction: SysInfo.drop("drawer-system")

    // --- history -------------------------------------------------------------
    readonly property int capacity: 60
    property var cpuHistory: []
    property var memHistory: []
    property var rxHistory: []
    property var txHistory: []

    function pushed(list, value) {
        const next = list.length >= root.capacity ? list.slice(1) : list.slice();
        next.push(value);
        return next;
    }

    // One sample per SysInfo poll: cpuUsage changes every poll, so it is the
    // tick. (Memory is sampled alongside it rather than on its own change, so
    // the two graphs stay in step.)
    Connections {
        target: SysInfo
        function onCpuUsageChanged() {
            root.cpuHistory = root.pushed(root.cpuHistory, SysInfo.cpuUsage);
            root.memHistory = root.pushed(root.memHistory, SysInfo.memoryUsage);
        }
    }

    // --- network rates + top processes ------------------------------------------
    property real lastRx: -1
    property real lastTx: -1
    property double lastStamp: 0
    property real rxRate: 0      // bytes per second
    property real txRate: 0
    property var processes: []   // [{ name, cpu, mem }]

    function formatRate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s";
        if (bps >= 1024) return (bps / 1024).toFixed(0) + " KB/s";
        return Math.round(bps) + " B/s";
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: statProc.running = true
    }

    Process {
        id: statProc

        command: ["sh", "-c", "cat /proc/net/dev; echo ---; ps -eo comm,%cpu,%mem --sort=-%cpu --no-headers | head -n 5"]

        stdout: StdioCollector {
            onStreamFinished: {
                const [net, ps] = statProc.stdout.text.split("---\n");

                // /proc/net/dev: "iface: rxBytes ... (8 fields) txBytes ...".
                // Loopback excluded; everything else summed, so wired and
                // Wi-Fi both count.
                let rx = 0, tx = 0;
                for (const line of net.split("\n").slice(2)) {
                    const m = line.trim().split(/[:\s]+/);
                    if (m.length < 10 || m[0] === "lo") continue;
                    rx += Number(m[1]);
                    tx += Number(m[9]);
                }
                const now = Date.now();
                if (root.lastRx >= 0 && now > root.lastStamp) {
                    const dt = (now - root.lastStamp) / 1000;
                    root.rxRate = Math.max(0, (rx - root.lastRx) / dt);
                    root.txRate = Math.max(0, (tx - root.lastTx) / dt);
                    root.rxHistory = root.pushed(root.rxHistory, root.rxRate);
                    root.txHistory = root.pushed(root.txHistory, root.txRate);
                }
                root.lastRx = rx;
                root.lastTx = tx;
                root.lastStamp = now;

                const procs = [];
                for (const line of (ps || "").split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 3) continue;
                    procs.push({ name: f.slice(0, f.length - 2).join(" "), cpu: Number(f[f.length - 2]), mem: Number(f[f.length - 1]) });
                }
                root.processes = procs;
            }
        }
    }

    // --- host / kernel, once --------------------------------------------------------
    property string host: ""
    property string kernel: ""

    Process {
        id: unameProc

        command: ["uname", "-nr"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = unameProc.stdout.text.trim().split(/\s+/);
                root.host = f[0] || "";
                root.kernel = f[1] || "";
            }
        }
    }

    // --- layout -----------------------------------------------------------------------
    PageHeader {
        title: "System"
        subtitle: root.host !== "" ? root.host + " · Linux " + root.kernel : ""
    }

    Card {
        width: parent.width
        elevation: 0
        implicitHeight: ringRow.implicitHeight + Appearance.md * 2

        Row {
            id: ringRow

            anchors.top: parent.top
            anchors.topMargin: Appearance.md
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.sm

            readonly property real cell: (parent.width - Appearance.md * 2 - spacing * 3) / 4

            MiniRing {
                width: parent.cell
                value: SysInfo.cpuUsage
                detail: Math.round(SysInfo.cpuUsage * 100) + "%"
                label: "CPU"
                icon: "cpu"
                tint: SysInfo.cpuUsage > 0.85 ? Theme.error : SysInfo.cpuUsage > 0.6 ? Theme.warning : Theme.accent
            }

            MiniRing {
                width: parent.cell
                value: SysInfo.memoryUsage
                detail: SysInfo.memoryUsedGb.toFixed(1) + "G"
                label: "MEMORY"
                icon: "ram"
                tint: SysInfo.memoryUsage > 0.9 ? Theme.error : SysInfo.memoryUsage > 0.75 ? Theme.warning : Theme.accent
            }

            MiniRing {
                width: parent.cell
                value: SysInfo.diskUsage
                detail: Math.round(SysInfo.diskUsage * 100) + "%"
                label: "DISK"
                icon: "folder"
                tint: SysInfo.diskUsage > 0.9 ? Theme.error : SysInfo.diskUsage > 0.75 ? Theme.warning : Theme.accent
            }

            MiniRing {
                width: parent.cell
                value: SysInfo.cpuTempC > 0 ? Math.min(1, SysInfo.cpuTempC / 100) : 0
                detail: SysInfo.cpuTempC > 0 ? Math.round(SysInfo.cpuTempC) + "°" : "–"
                label: "TEMP"
                icon: "temperature"
                tint: SysInfo.cpuTempC > 85 ? Theme.error : SysInfo.cpuTempC > 70 ? Theme.warning : Theme.accent
            }
        }
    }

    // Activity: CPU and memory sparklines.
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: activity.implicitHeight + Appearance.md * 2

        Column {
            id: activity

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: Appearance.sm

            Repeater {
                model: [
                    { label: "PROCESSOR", key: "cpu" },
                    { label: "MEMORY", key: "mem" }
                ]

                Column {
                    id: graph

                    required property var modelData
                    readonly property bool isCpu: graph.modelData.key === "cpu"

                    width: activity.width
                    spacing: 2

                    Item {
                        width: parent.width
                        height: graphLabel.implicitHeight

                        Text {
                            id: graphLabel

                            text: graph.modelData.label
                            color: Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                            font.letterSpacing: Appearance.trackingLabel
                        }

                        Text {
                            anchors.right: parent.right
                            text: graph.isCpu ? Math.round(SysInfo.cpuUsage * 100) + "%"
                                : SysInfo.memoryUsedGb.toFixed(1) + " / " + SysInfo.memoryTotalGb.toFixed(1) + " GB"
                            color: Theme.text
                            font.family: Appearance.fontMono
                            font.pixelSize: Appearance.fontCaption
                        }
                    }

                    Sparkline {
                        width: parent.width
                        height: 46
                        capacity: root.capacity
                        values: graph.isCpu ? root.cpuHistory : root.memHistory
                        tint: graph.isCpu ? Theme.accent : Theme.accent2
                    }
                }
            }
        }
    }

    // Network throughput.
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: netColumn.implicitHeight + Appearance.md * 2

        Column {
            id: netColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: Appearance.sm

            Row {
                width: parent.width
                spacing: Appearance.lg

                Repeater {
                    model: [
                        { label: "DOWN", icon: "arrow-down", rx: true },
                        { label: "UP",   icon: "arrow-up",   rx: false }
                    ]

                    Row {
                        id: rate

                        required property var modelData

                        spacing: Appearance.sm

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: rate.modelData.icon
                            size: Appearance.iconSize
                            color: rate.modelData.rx ? Theme.accent : Theme.accent2
                        }

                        Column {
                            spacing: 0

                            Text {
                                text: rate.modelData.label
                                color: Theme.muted
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontCaption
                                font.letterSpacing: Appearance.trackingLabel
                            }

                            Text {
                                text: root.formatRate(rate.modelData.rx ? root.rxRate : root.txRate)
                                color: Theme.text
                                font.family: Appearance.fontMono
                                font.pixelSize: Appearance.fontBody
                                font.weight: Appearance.weightMedium
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 40

                Sparkline {
                    anchors.fill: parent
                    capacity: root.capacity
                    values: root.rxHistory
                    autoScale: true
                    tint: Theme.accent
                }

                Sparkline {
                    anchors.fill: parent
                    capacity: root.capacity
                    values: root.txHistory
                    autoScale: true
                    tint: Theme.accent2
                    opacity: 0.8
                }
            }
        }
    }

    // Busiest processes.
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: procColumn.implicitHeight + Appearance.md * 2

        Column {
            id: procColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: Appearance.xs

            Text {
                text: "BUSIEST"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                font.letterSpacing: Appearance.trackingLabel
            }

            Repeater {
                model: root.processes

                Item {
                    id: proc

                    required property var modelData

                    width: procColumn.width
                    height: 24

                    // A bar behind the row, proportional to CPU.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: parent.width * Math.min(1, proc.modelData.cpu / 100)
                        radius: Appearance.radiusSmall
                        color: Theme.wash(Theme.accent, 0.14)

                        Behavior on width {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationSlow; easing.type: Appearance.easeStandard }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.sm
                        anchors.right: procStats.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: proc.modelData.name
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                        elide: Text.ElideRight
                    }

                    Text {
                        id: procStats

                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: proc.modelData.cpu.toFixed(1) + "%  ·  " + proc.modelData.mem.toFixed(1) + "% mem"
                        color: Theme.muted
                        font.family: Appearance.fontMono
                        font.pixelSize: Appearance.fontCaption
                    }
                }
            }
        }
    }

    // Battery and uptime.
    Card {
        width: parent.width
        elevation: 0
        visible: Performance.hasBattery
        implicitHeight: batteryBar.implicitHeight + Appearance.md * 2

        StatBar {
            id: batteryBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            icon: Performance.batteryCharging ? "battery-charging" : "battery-full"
            label: "Battery" + (Performance.batteryHealth > 0 ? " · " + Math.round(Performance.batteryHealth) + "% health" : "")
            value: Performance.batteryPercent
            detail: {
                const pct = Math.round(Performance.batteryPercent * 100) + "%";
                const secs = Performance.batteryTimeRemaining;
                if (!(secs > 0)) return pct;
                const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60);
                return pct + " · " + (h > 0 ? h + "h " + m + "m" : m + "m")
                    + (Performance.batteryCharging ? " to full" : " left");
            }
            tint: Performance.batteryCharging ? Theme.success
                : Performance.batteryPercent <= 0.15 ? Theme.error
                : Performance.batteryPercent <= 0.3 ? Theme.warning : Theme.accent
        }
    }
}
