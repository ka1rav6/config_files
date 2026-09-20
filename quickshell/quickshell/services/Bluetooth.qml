pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
// Process, for the audio-profile selection below -- see ensureAudioProfile().
import Quickshell.Io
import qs

// =============================================================================
// Bluetooth — BlueZ, event-driven.
// =============================================================================
// Replaces blueman-applet + blueman-tray, which between them hold ~43 MiB of
// PSS and two GTK processes to provide a tray icon and a menu.
//
// DISCOVERY IS GATED, FOR THE SAME REASON SCANNING IS IN Network.qml
//   Bluetooth discovery keeps the radio transmitting and is a genuine battery
//   drain. `discovering` is driven from whether a Bluetooth panel is on screen,
//   so the adapter is only ever scanning while somebody is actually looking for
//   a device to pair. Connection state, battery levels and the paired-device
//   list all arrive as D-Bus signals and cost nothing, so those stay live.
//
//   This is the "don't continuously query Bluetooth when the panel is closed"
//   requirement.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!root.adapter

    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property bool discovering: root.available && root.adapter.discovering

    // --- Devices ------------------------------------------------------

    readonly property var allDevices: Bluetooth.devices ? Bluetooth.devices.values : []

    // Paired devices, connected first. This is the list worth showing when the
    // panel opens -- the things you actually own.
    readonly property var pairedDevices: {
        const list = root.allDevices.filter(d => d.paired || d.bonded);
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return (a.deviceName || a.name || "").localeCompare(b.deviceName || b.name || "");
        });
        return list;
    }

    // Everything else in range, only meaningful while discovering.
    readonly property var availableDevices: {
        return root.allDevices
            .filter(d => !d.paired && !d.bonded && (d.deviceName || d.name))
            .sort((a, b) => (a.deviceName || a.name).localeCompare(b.deviceName || b.name));
    }

    readonly property var connectedDevices: root.allDevices.filter(d => d.connected)
    readonly property bool anyConnected: root.connectedDevices.length > 0

    readonly property string summary: {
        if (!root.available) return "No adapter";
        if (!root.enabled) return "Off";
        const c = root.connectedDevices;
        if (c.length === 0) return "On";
        if (c.length === 1) return c[0].deviceName || c[0].name || "Connected";
        return c.length + " connected";
    }

    // --- Actions ------------------------------------------------------

    function setEnabled(value) {
        if (root.available) root.adapter.enabled = value;
    }

    function toggle() {
        root.setEnabled(!root.enabled);
    }

    // Set by whatever panel is showing devices. See the header.
    property bool scanning: false

    // Only bind while something actually wants to scan.
    //
    // A permanent Binding writes `false` on construction, and BlueZ answers a
    // stop-discovery on an adapter that was never discovering with
    // "No discovery started" -- a warning on every shell start, for a request
    // that was a no-op. `when` keeps the binding out of the way until the
    // first real scan.
    Binding {
        target: root.adapter
        property: "discovering"
        // Never leave discovery on when the adapter is off -- BlueZ errors
        // rather than quietly ignoring it.
        value: root.scanning && root.enabled
        when: root.available && root.enabled && root.scanning
    }

    // Stopping needs its own path, since the binding above is not active while
    // `scanning` is false. Guarded on actually discovering, so it is never the
    // no-op that produced the warning.
    onScanningChanged: {
        if (!root.scanning && root.available && root.adapter.discovering)
            root.adapter.discovering = false;
    }

    function connectDevice(device) {
        if (!device) return;
        // An unpaired device has to be paired first; BlueZ will not connect to
        // a stranger. Pairing normally auto-connects afterwards.
        if (!device.paired && !device.bonded) device.pair();
        else device.connect();
    }

    function disconnectDevice(device) {
        if (device) device.disconnect();
    }

    function forgetDevice(device) {
        if (device) device.forget();
    }

    // -----------------------------------------------------------------
    // Audio profile auto-selection
    //
    // THIS IS NOT OPTIONAL POLISH -- WITHOUT IT, BLUETOOTH HEADPHONES CONNECT
    // AND PLAY NOTHING.
    //
    // BlueZ connecting a headset and PipeWire having a usable SINK for it are
    // two different things. BlueZ brings up the device and its control
    // profiles (AVRCP and so on); the audio transport is a separate card
    // profile that something has to select. Left alone, PipeWire routinely
    // parks the card at:
    //
    //     Active Profile: off          (sinks: 0)
    //
    // which is exactly what it looks like when headphones are "connected" per
    // bluetoothctl, show up in the Bluetooth panel as connected, and simply do
    // not appear in the output list at all.
    //
    // blueman-applet did this selection. Replacing blueman without replacing
    // this is what broke audio on the JBL headset -- it connected, reported
    // connected, and had no sink.
    //
    // WHY pactl AND NOT THE Pipewire MODULE
    //   Card profiles are a PulseAudio-compat concept exposed through
    //   pactl/wpctl; Quickshell's Pipewire module models nodes and links, not
    //   cards, so there is no in-process way to set one. This is a short-lived
    //   subprocess that runs once per device connection, not a poll.
    //
    // WHICH PROFILE
    //   The best available A2DP variant, by PipeWire's own priority ordering:
    //   SBC-XQ over plain SBC where the device offers it. HSP/HFP is
    //   deliberately never auto-selected -- it is the 8 kHz telephone profile,
    //   and silently putting music through it sounds broken.
    // -----------------------------------------------------------------

    // Addresses already handled this session, so reconnect storms and BlueZ
    // property churn do not respawn pactl repeatedly for the same device.
    property var profileHandled: ({})

    function ensureAudioProfile(device) {
        if (!device || !device.connected) return;
        if (root.kind(device) !== "audio") return;

        const address = device.address;
        if (!address || root.profileHandled[address]) return;

        const marked = {};
        for (const k in root.profileHandled) marked[k] = true;
        marked[address] = true;
        root.profileHandled = marked;

        // BlueZ underscores the address in the card name.
        const card = "bluez_card." + address.replace(/:/g, "_");

        // Pick the highest-priority a2dp profile the card actually lists, and
        // only act when the card is currently off -- never override a profile
        // the user chose deliberately.
        profileProc.command = ["bash", "-c",
            'card="$1"\n' +
            'info=$(pactl list cards 2>/dev/null | awk -v c="Name: $card" \'$0 ~ c, /^$/\')\n' +
            '[ -z "$info" ] && exit 0\n' +
            'active=$(printf "%s" "$info" | grep -oP "Active Profile: \\K.*")\n' +
            '[ "$active" != "off" ] && exit 0\n' +
            'for p in a2dp-sink-sbc_xq a2dp-sink; do\n' +
            '  if printf "%s" "$info" | grep -q "^\\s*$p:"; then\n' +
            '    pactl set-card-profile "$card" "$p" && echo "$p" && exit 0\n' +
            '  fi\n' +
            'done\n',
            "qs-btprofile", card];
        profileProc.deviceName = device.deviceName || device.name || address;
        profileProc.running = true;
    }

    Process {
        id: profileProc

        property string deviceName: ""

        running: false

        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() !== "")
                    console.log("[bluetooth]", profileProc.deviceName,
                                "-> audio profile", line.trim());
            }
        }
    }

    // Re-arm a device when it disconnects, so unplugging and reconnecting gets
    // the profile selected again rather than being remembered as handled.
    function releaseProfile(address) {
        if (!address || !root.profileHandled[address]) return;
        const next = {};
        for (const k in root.profileHandled) { if (k !== address) next[k] = true; }
        root.profileHandled = next;
    }

    // Watch every device's connected state. The model is event-driven off
    // BlueZ, so this costs nothing until something actually connects.
    Instantiator {
        model: root.allDevices

        delegate: QtObject {
            required property var modelData

            readonly property bool connected: !!(modelData && modelData.connected)

            onConnectedChanged: {
                if (connected) root.ensureAudioProfile(modelData);
                else root.releaseProfile(modelData ? modelData.address : "");
            }

            // Devices already connected when the shell starts need the same
            // treatment -- this is the common case after a Quickshell restart.
            Component.onCompleted: if (connected) root.ensureAudioProfile(modelData)
        }
    }

    // A rough category for icon selection, from BlueZ's own icon hint.
    function kind(device) {
        const icon = device && device.icon ? device.icon : "";
        if (icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1
            || icon.indexOf("headphone") !== -1) return "audio";
        if (icon.indexOf("input-keyboard") !== -1) return "keyboard";
        if (icon.indexOf("input-mouse") !== -1) return "mouse";
        if (icon.indexOf("phone") !== -1) return "phone";
        return "device";
    }
}
