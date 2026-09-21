pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs

// =============================================================================
// Network — NetworkManager, event-driven.
// =============================================================================
// Replaces the INTERACTIVE half of what used to be two things:
//   * ~/.config/waybar/scripts/wifi-menu.sh -- 167 lines of shell driving wofi,
//     which could only show what a scan happened to find at the moment it ran.
//     Deleted; it is in the dotfiles git history.
//   * waybar's `network` module as a click target -- clicking the bar now opens
//     the Control Center.
//
// IT DOES NOT REPLACE THE BAR'S READOUT, and this header used to claim it did.
// `network` is still a live module in ~/.config/waybar/config.jsonc, still
// refreshing on its own interval, because a persistent at-a-glance status line
// is a different job from a panel you open. So there ARE two NetworkManager
// consumers on this machine, deliberately: a cheap read-only one on the bar,
// and this one, which is the only thing that connects, disconnects or scans.
// If the bar's readout is ever retired, this is what it moves to.
//
// Quickshell.Networking talks to NetworkManager over D-Bus and is TOLD when
// something changes. There is no timer anywhere in this file.
//
// SCANNING IS EXPENSIVE, SO IT IS GATED
//   A Wi-Fi scan wakes the radio, takes a second or two and costs real battery.
//   NetworkManager will happily scan continuously if asked. `scanning` here is
//   set true only while a Wi-Fi panel is actually on screen, and false the
//   moment it closes -- so the radio is left alone the other 99% of the time.
//
//   This is the "don't continuously query NetworkManager when nothing changed"
//   requirement, made concrete: the network LIST is only refreshed while
//   someone is looking at it. Connection STATE is always live, because that
//   arrives as a signal and costs nothing.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // --- Devices ------------------------------------------------------

    readonly property var devices: Networking.devices ? Networking.devices.values : []

    readonly property var wifiDevice: {
        for (const d of root.devices) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    readonly property var wiredDevice: {
        for (const d of root.devices) {
            if (d.type === DeviceType.Ethernet) return d;
        }
        return null;
    }

    // --- State --------------------------------------------------------

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wifiAvailable: !!root.wifiDevice

    readonly property bool wiredConnected: !!(root.wiredDevice && root.wiredDevice.connected)
    readonly property bool wifiConnected: !!(root.wifiDevice && root.wifiDevice.connected)
    readonly property bool connected: root.wiredConnected || root.wifiConnected

    // The network currently joined, or null.
    readonly property var activeNetwork: {
        const d = root.wifiDevice;
        if (!d || !d.networks) return null;
        for (const n of d.networks.values) {
            if (n.connected) return n;
        }
        return null;
    }

    readonly property string ssid: root.activeNetwork ? root.activeNetwork.name : ""
    readonly property int signalStrength: root.activeNetwork ? root.activeNetwork.signalStrength : 0
    readonly property string address: root.wifiDevice ? root.wifiDevice.address : ""

    // Ethernet wins when both are up, because that is what the routing table
    // will do too -- reporting Wi-Fi while traffic goes over the cable is a
    // small lie that makes diagnosing a problem harder.
    readonly property string summary: {
        if (root.wiredConnected) return "Wired";
        if (root.wifiConnected) return root.ssid || "Wi-Fi";
        if (!root.wifiHardwareEnabled) return "Wi-Fi off (hardware)";
        if (!root.wifiEnabled) return "Wi-Fi off";
        return "Offline";
    }

    // 0-4, for icon selection. Matching waybar's buckets so the bar and the
    // shell never disagree about how many bars to draw.
    readonly property int signalBars: {
        const s = root.signalStrength;
        if (s >= 75) return 4;
        if (s >= 50) return 3;
        if (s >= 25) return 2;
        if (s > 0) return 1;
        return 0;
    }

    // --- Network list -------------------------------------------------

    // Set true by whatever panel is showing networks, false when it closes.
    // See the header: this is the battery gate.
    property bool scanning: false

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanning
        when: !!root.wifiDevice
    }

    // Visible networks, strongest first, with the connected one pinned to the
    // top. Duplicates (the same SSID on several APs) are collapsed to the
    // strongest, because joining is by SSID and showing five identical rows is
    // noise.
    readonly property var networks: {
        const d = root.wifiDevice;
        if (!d || !d.networks) return [];

        const best = {};
        for (const n of d.networks.values) {
            if (!n.name) continue;              // hidden SSIDs cannot be listed
            const existing = best[n.name];
            if (!existing || n.connected || n.signalStrength > existing.signalStrength)
                best[n.name] = n;
        }

        const list = Object.keys(best).map(k => best[k]);
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return list;
    }

    // --- Actions ------------------------------------------------------

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled;
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // Join a network. A `known` network already has its passphrase stored, so
    // it connects with no prompt -- which is the case wifi-menu.sh got right
    // and nm-connection-editor never handled at all.
    function connect(network, passphrase) {
        if (!network) return;
        if (passphrase !== undefined && passphrase !== "")
            network.connectWithPsk(passphrase);
        else
            network.connect();
    }

    function disconnect() {
        const n = root.activeNetwork;
        if (n) n.disconnect();
    }

    // Whether joining this network will need a passphrase typed.
    function needsPassphrase(network) {
        if (!network) return false;
        if (network.known) return false;                  // saved already
        return network.security !== WifiSecurityType.None;
    }
}
