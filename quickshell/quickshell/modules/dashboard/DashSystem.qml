import QtQuick
import qs

// =============================================================================
// DashSystem — the SYSTEM card: CPU, memory, disk, battery, uptime
// =============================================================================
// One section of the dashboard, split out so the left drawer's pages
// (modules/drawer) can show the very same thing instead of a copy that drifts.
// It reads services only; whatever it needs polled (seconds, /proc, the MPRIS
// position) is demanded by its HOST while the host is on screen -- see
// Dashboard.qml and modules/drawer/Drawer.qml.
// =============================================================================

Card {
    width: parent.width
    elevation: 0
    implicitHeight: sys.implicitHeight + Appearance.md * 2

    Column {
        id: sys

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.md
        spacing: Appearance.sm

        Item {
            width: parent.width
            implicitHeight: 16

            Text {
                anchors.left: parent.left
                text: "SYSTEM"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                font.weight: Appearance.weightMedium
                font.letterSpacing: Appearance.trackingLabel
            }

            Text {
                anchors.right: parent.right
                text: SysInfo.uptimeText === "" ? "" : "up " + SysInfo.uptimeText
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
            }
        }

        StatBar {
            width: parent.width
            icon: "cpu"
            label: "Processor"
            value: SysInfo.cpuUsage
            detail: Math.round(SysInfo.cpuUsage * 100) + "%"
        }

        StatBar {
            width: parent.width
            icon: "ram"
            label: "Memory"
            value: SysInfo.memoryUsage
            detail: SysInfo.memoryUsedGb.toFixed(1) + " / "
                  + SysInfo.memoryTotalGb.toFixed(1) + " GB"
        }

        StatBar {
            width: parent.width
            visible: SysInfo.diskTotalGb > 0
            icon: "folder"
            label: "Disk"
            value: SysInfo.diskUsage
            detail: SysInfo.diskUsedGb.toFixed(0) + " / "
                  + SysInfo.diskTotalGb.toFixed(0) + " GB"
            tint: SysInfo.diskUsage > 0.9 ? Theme.error
                : SysInfo.diskUsage > 0.75 ? Theme.warning : Theme.accent
        }

        StatBar {
            width: parent.width
            visible: Performance.hasBattery
            icon: Performance.batteryCharging ? "battery-charging" : "battery-full"
            label: "Battery"
            value: Performance.batteryPercent
            // UPower needs a few minutes of history after a resume
            // before the estimate means anything, so it is omitted
            // rather than shown as "0 minutes remaining".
            detail: {
                const pct = Math.round(Performance.batteryPercent * 100) + "%";
                const secs = Performance.batteryTimeRemaining;
                if (!(secs > 0)) return pct;
                const h = Math.floor(secs / 3600);
                const m = Math.floor((secs % 3600) / 60);
                return pct + " · " + (h > 0 ? h + "h " + m + "m" : m + "m")
                     + (Performance.batteryCharging ? " to full" : " left");
            }
            // Amber then red, on the same thresholds waybar uses.
            tint: {
                const p = Performance.batteryPercent * 100;
                if (Performance.batteryCharging) return Theme.success;
                if (p <= 15) return Theme.error;
                if (p <= 30) return Theme.warning;
                return Theme.accent;
            }
        }
    }
}
