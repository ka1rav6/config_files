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
            if (d.type === DeviceType.Wired) return d;
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
    readonly property string address: root.wifiDevice ? root.wifiDevice.address : ""

    // WifiNetwork.signalStrength IS A FRACTION, NOT A PERCENT.
    //   NetworkManager's AccessPoint.Strength is a guint8 0-100, but Quickshell
    //   normalises it on the way out -- src/network/nm/network.cpp does
    //   `signalStrength() / 100.0` -- so what QML sees is a qreal 0.0-1.0.
    //
    //   This file used to read it straight into `readonly property int`, which
    //   is why every readout in the shell said 0%: QML truncates a double
    //   assigned to an int property, so a genuine 60% AP arrived as 0.60 and
    //   landed as 0. Not a parse bug, not a stale binding -- a unit mismatch
    //   that only an AP at exactly 100% would have survived.
    //
    //   Everything downstream (this file's 75/50/25 buckets, the "% signal"
    //   labels, the per-row icons) is written against 0-100, so the conversion
    //   happens HERE, once, and nowhere else. Use signalPercent() for any
    //   network that is not the connected one -- reading `.signalStrength` off
    //   a WifiNetwork directly in a widget will reintroduce exactly this bug.
    readonly property int signalStrength: root.signalPercent(root.activeNetwork)

    // 0-100 for any WifiNetwork, or 0 for null. The one place the fraction ->
    // percent conversion lives.
    function signalPercent(network) {
        if (!network) return 0;
        return Math.round(network.signalStrength * 100);
    }

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
    readonly property int signalBars: root.signalBarsFor(root.activeNetwork)

    // Same buckets for a network that is not the connected one -- the Wi-Fi
    // lists need this per row. It lives here rather than being re-typed in each
    // list because the thresholds were previously copy-pasted into three
    // widgets, all of which were silently comparing a 0.0-1.0 fraction against
    // 75/50/25 and therefore always falling through to the weakest icon.
    function signalBarsFor(network) {
        const s = root.signalPercent(network);
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

        // The raw 0.0-1.0 `signalStrength` is read directly below, which is
        // fine and deliberate: this only ever COMPARES two of them against each
        // other, and the ordering of the fraction is the ordering of the
        // percent. Anything that DISPLAYS a number must go through
        // signalPercent() instead -- see the note on signalStrength above.
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
        if (!enabled) root.clearError();
        Networking.wifiEnabled = enabled;
    }

    function toggleWifi() {
        root.setWifiEnabled(!Networking.wifiEnabled);
    }

    // Join a network. A `known` network already has its passphrase stored, so
    // it connects with no prompt -- which is the case wifi-menu.sh got right
    // and nm-connection-editor never handled at all.
    //
    // PASSING A PASSPHRASE FOR A KNOWN NETWORK IS AN EDIT, NOT A DUPLICATE.
    //   quickshell's WifiNetwork::connectWithPsk checks for existing settings
    //   first and, when it finds them, does an Update on that profile and
    //   reactivates it -- it only falls back to AddAndActivate when the SSID
    //   has never been saved. So this one call is also how a rotated router
    //   password is fixed: hand it the new secret and the stored one is
    //   overwritten in place, with the rest of the profile left alone.
    //
    //   Two things it will NOT do, both enforced in C++ with nothing but a
    //   critical log line to show for it -- so callers must not offer them:
    //     * rewrite the secret of a network that is currently CONNECTED, and
    //     * accept a passphrase for anything canUsePassphrase() rejects.
    function connect(network, passphrase) {
        if (!network) return;
        root.clearError();
        root.pendingNetwork = network;
        if (passphrase !== undefined && passphrase !== "")
            network.connectWithPsk(passphrase);
        else
            network.connect();
    }

    function disconnect() {
        const n = root.activeNetwork;
        root.pendingNetwork = null;
        root.clearError();
        if (n) n.disconnect();
    }

    // Delete every saved profile NetworkManager holds for this network.
    //
    // NMNetwork::forget() walks all the NMSettings the SSID owns and Deletes
    // each over D-Bus, so an SSID that got saved twice (easy to do: joining
    // once by hand and once from a QR code leaves two profiles) is genuinely
    // forgotten rather than half forgotten. If the profile being deleted is
    // the active one, NetworkManager tears the link down as it goes.
    //
    // WHY THIS EXISTS
    //   `known` short-circuits needsPassphrase(), so a saved network never
    //   prompts -- it just quietly retries the stored secret. When a router's
    //   password changes, that is unrecoverable from inside the shell: the row
    //   fails forever and there is nowhere to type the new key. connect() with
    //   a passphrase is the gentle fix; this is the one for a profile that is
    //   wrong in some other way (wrong security type, a stale EAP identity, a
    //   duplicate NetworkManager made behind your back).
    function forget(network) {
        if (!network) return;
        if (root.pendingNetwork === network) root.pendingNetwork = null;
        root.clearError();
        network.forget();
    }

    // Whether joining this network will need a passphrase typed.
    //
    // WifiSecurityType HAS NO `None` MEMBER. The enum is Wpa3SuiteB192, Sae,
    // Wpa2Eap, Wpa2Psk, WpaEap, WpaPsk, StaticWep, DynamicWep, Leap, Owe, Open,
    // Unknown -- the open case is spelled `Open`. This used to compare against
    // `WifiSecurityType.None`, which is undefined, so the `!==` was true for
    // every network and a genuinely open AP still got a passphrase dialog it
    // had no use for. Owe is "enhanced open": encrypted, but still no
    // passphrase to type, so it belongs on this side of the test too.
    function needsPassphrase(network) {
        if (!network) return false;
        if (network.known) return false;                  // saved already
        const s = network.security;
        return s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe;
    }

    // Whether a passphrase box can do anything for this network at all.
    //
    // connectWithPsk() hard-refuses any security type that is not WpaPsk,
    // Wpa2Psk or Sae: src/network/wifi.cpp logs "has the wrong security type
    // for a PSK" and returns WITHOUT emitting, so the UI sees no failure, no
    // state change, nothing. An enterprise (EAP) or WEP network offered a
    // password field therefore gets a field that silently cannot work, which
    // is worse than not offering one. Anything this returns false for belongs
    // in nm-connection-editor, and the panels say so.
    function canUsePassphrase(network) {
        if (!network) return false;
        const s = network.security;
        return s === WifiSecurityType.WpaPsk
            || s === WifiSecurityType.Wpa2Psk
            || s === WifiSecurityType.Sae;
    }

    // --- Failure reporting --------------------------------------------
    //
    // A FAILED JOIN USED TO BE COMPLETELY SILENT. NetworkManager reports why
    // over D-Bus and quickshell re-emits it as Network::connectionFailed, but
    // nothing in this shell was listening -- so the single most common failure
    // of all, a stored passphrase that no longer matches the router, looked
    // exactly like clicking the row and having nothing happen. That silence is
    // half of what made a changed password unrecoverable here; forget() and
    // the passphrase re-entry above are the other half.
    //
    // ONLY THE JOIN WE STARTED IS WATCHED.
    //   The obvious alternative -- a Connections per visible network -- would
    //   rebuild one object per AP every time `networks` re-evaluates, and that
    //   binding re-runs on every signal-strength tick while a panel is
    //   scanning. One target, swapped on connect(), costs nothing and is the
    //   only attribution anyone actually wants: "the thing I just clicked".

    // The network a join is outstanding on, or null.
    property var pendingNetwork: null

    // Human-readable reason the last join failed, or "" if nothing has.
    property string lastError: ""
    property string lastErrorSsid: ""

    // True when re-typing the passphrase is a plausible fix, so panels know
    // whether to offer that as the next step rather than just reporting.
    property bool lastErrorWasAuth: false

    function clearError() {
        root.lastError = "";
        root.lastErrorSsid = "";
        root.lastErrorWasAuth = false;
    }

    function failureText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "Wrong password.";
        case ConnectionFailReason.WifiAuthTimeout:
            return "Timed out authenticating — the password may have changed.";
        case ConnectionFailReason.WifiClientFailed:
            return "The Wi-Fi client rejected the connection.";
        case ConnectionFailReason.WifiClientDisconnected:
            return "Disconnected during the handshake.";
        case ConnectionFailReason.WifiNetworkLost:
            return "That network went out of range.";
        default:
            return "Could not connect.";
        }
    }

    // No ignoreUnknownSignals here, deliberately: a null target between
    // attempts is simply inactive and silent, so the only thing that flag
    // could ever hide is a handler named after a signal that does not exist --
    // which is exactly the mistake worth hearing about at load time.
    Connections {
        target: root.pendingNetwork

        function onConnectionFailed(reason) {
            const n = root.pendingNetwork;
            root.lastErrorSsid = n ? n.name : "";
            // NoSecrets is the honest "wrong key" answer, but a router that
            // simply stops replying to a bad key produces a supplicant timeout
            // or failure instead, so those count as auth failures too -- all
            // three have the same fix.
            root.lastErrorWasAuth = reason === ConnectionFailReason.NoSecrets
                || reason === ConnectionFailReason.WifiAuthTimeout
                || reason === ConnectionFailReason.WifiClientFailed;
            root.lastError = root.failureText(reason);
            root.pendingNetwork = null;
        }

        function onConnectedChanged() {
            const n = root.pendingNetwork;
            if (n && n.connected) {
                root.clearError();
                root.pendingNetwork = null;
            }
        }
    }
}
