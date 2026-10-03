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
// Replaces blueman-applet + blueman-tray, which between them held 97 MiB
// resident (52 + 44, measured) and two Python/GTK processes, to provide a tray
// icon and a menu.
//
// PAIRING NEEDS AN AGENT, AND THIS SHELL IS NOT ONE
//   BlueZ refuses to pair with anything unless some process has registered an
//   org.bluez.Agent1 to answer "confirm this passkey". Quickshell exposes
//   BluetoothDevice.pair() but registers no such agent, so pair() on its own
//   fails on the bus and looks, on screen, like a dead button.
//
//   ~/.local/bin/bt-connect supplies one by holding a single short-lived
//   bluetoothctl session open for the length of one pairing (bluetoothctl
//   registers an agent of its own the moment it connects to bluetoothd). That
//   covers everything that pairs with a yes: headphones, speakers, mice, TVs,
//   controllers. See pairDevice() below.
//
//   ~/.local/bin/bt-pair -- the blueman detour -- is now only the fallback for
//   devices that need a PIN typed IN, which no unattended agent can answer. It
//   still starts blueman-applet for its AuthAgent and stops it again; note that
//   stopping it means stopping the systemd USER UNIT (it is D-Bus activated)
//   and blueman-tray alongside it, since a plain `pkill -x blueman-applet`
//   leaves both resident and leaked that full 97 MiB after every pair.
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

    // --- Names ---------------------------------------------------------
    //
    // WHY A DEVICE WITH NO NAME IS NOT A DEVICE WITH AN EMPTY NAME
    //   BlueZ exposes two names. `Name` is what the device actually told us,
    //   and is ABSENT as a property entirely until it has told us something.
    //   `Alias` is the writable display name -- and when there is no `Name`,
    //   BlueZ fills `Alias` in with the device's own ADDRESS. Quickshell maps
    //   `Name` to `deviceName` and `Alias` to `name`.
    //
    //   So `deviceName || name || address` -- the obvious-looking fallback
    //   chain, and the one this shell used -- can never reach its `address`
    //   arm, because `name` is already the address wearing a name's clothes.
    //   Confirmed over D-Bus on this machine:
    //
    //       dev_5A_54_5D_F4_72_FA   Name:  <no such property>
    //                               Alias: "5A:54:5D:F4:72:FA"
    //       dev_88_92_CC_2B_3E_B0   Name:  "JBL TUNE770NC"
    //
    //   That is where the panel's rows of bare MAC addresses came from. They
    //   were never a rendering bug: the shell genuinely believed those strings
    //   were the devices' names. Worse, the "has a name" filter below was
    //   written as `d.deviceName || d.name`, which is therefore TRUE for every
    //   anonymous BLE beacon in radio range -- and since the page caps itself
    //   at six rows, a real device could be, and was, pushed off the list by
    //   other people's fitness trackers.
    function hasRealName(device) {
        if (!device) return false;
        if (device.deviceName && device.deviceName.length > 0) return true;

        const alias = device.name || "";
        if (alias.length === 0) return false;

        // BlueZ writes the placeholder colon-separated, but aliases imported
        // from other tools turn up dash- or underscore-separated; normalise
        // before comparing so none of those spellings reads as a real name.
        const address = (device.address || "").toUpperCase();
        return alias.toUpperCase().replace(/[-_]/g, ":") !== address;
    }

    // The string to put in front of a human. Never an address -- the address
    // belongs in the second line, where BtRow puts it, labelled as what it is.
    function label(device) {
        if (!device) return "";
        if (device.deviceName && device.deviceName.length > 0) return device.deviceName;
        if (root.hasRealName(device)) return device.name;
        return "Unknown device";
    }

    // Paired devices, connected first. This is the list worth showing when the
    // panel opens -- the things you actually own.
    readonly property var pairedDevices: {
        const list = root.allDevices.filter(d => d.paired || d.bonded);
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return root.label(a).localeCompare(root.label(b));
        });
        return list;
    }

    // In range, unpaired, and has told us what it is. Only meaningful while
    // discovering.
    readonly property var availableDevices: {
        return root.allDevices
            .filter(d => !d.paired && !d.bonded && root.hasRealName(d))
            .sort((a, b) => root.label(a).localeCompare(root.label(b)));
    }

    // In range, unpaired, and anonymous.
    //
    // Kept as a SEPARATE list rather than filtered away, because "anonymous"
    // and "useless" are not the same thing: a device that has not advertised a
    // name yet often has one a few seconds later, and a few genuinely never
    // advertise one. But they are overwhelmingly BLE beacons -- random-address
    // trackers, phones' privacy addresses, somebody's earbud case -- so they
    // are not allowed to share a list with the thing the user is looking for.
    // The page shows the count and reveals them on request.
    readonly property var unnamedDevices: {
        return root.allDevices
            .filter(d => !d.paired && !d.bonded && !root.hasRealName(d))
            .sort((a, b) => (a.address || "").localeCompare(b.address || ""));
    }

    readonly property var connectedDevices: root.allDevices.filter(d => d.connected)
    readonly property bool anyConnected: root.connectedDevices.length > 0

    readonly property string summary: {
        if (!root.available) return "No adapter";
        if (!root.enabled) return "Off";
        const c = root.connectedDevices;
        if (c.length === 0) return "On";
        if (c.length === 1) return root.label(c[0]);
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

        // RestoreNone is what actually silenced
        //     Failed to stop discovery ...: "Operation already in progress"
        //
        // A Qt Binding with `when: false` does not merely stop driving the
        // property -- by default it RESTORES the value the target had before
        // the binding took effect, i.e. it writes `discovering = false` the
        // instant `scanning` goes false. That write races BlueZ's own
        // StartDiscovery, which is still in flight, and BlueZ rejects it.
        //
        // The debounced stopDiscovery timer below is the only thing that
        // should ever issue the stop, so the binding must not write on the way
        // out. Chasing this in the timer first was wrong: the warning was
        // never coming from the timer.
        restoreMode: Binding.RestoreNone
    }

    // Stopping needs its own path, since the binding above is not active while
    // `scanning` is false.
    //
    // DEBOUNCED, because BlueZ rejects a stop that arrives while its own
    // start is still in flight:
    //
    //     Failed to stop discovery on adapter ...: "Operation already in
    //     progress"
    //
    // `adapter.discovering` reads true as soon as the start is ISSUED, not
    // once it has completed, so the existing guard could not tell the two
    // apart -- opening and immediately closing the Bluetooth page (or the
    // panel auto-closing behind another one) reliably produced that warning.
    // A short settle lets the start finish first, and re-checking inside the
    // timer means a scan that was restarted meanwhile is left alone.
    onScanningChanged: {
        if (root.scanning)
            stopDiscovery.stop();
        else
            stopDiscovery.restart();
    }

    Timer {
        id: stopDiscovery

        interval: 350
        onTriggered: {
            if (!root.scanning && root.available && root.enabled && root.adapter.discovering)
                root.adapter.discovering = false;
        }
    }

    // --- Pairability --------------------------------------------------
    //
    // The adapter on this machine sits at `Pairable: no` with nothing to change
    // it -- blueman-manager used to turn it on while its window was open, and
    // nothing took that job over. Pairable governs pair requests arriving FROM
    // a device, which is how phones and some keyboards insist on doing it, so
    // with it off those devices cannot be added at all.
    //
    // Discoverable is the matching half: it is what makes this machine appear
    // in the other device's own Bluetooth list.
    //
    // BOTH ARE GATED ON `scanning`, i.e. on the Bluetooth page being open, for
    // the same reason discovery is -- an always-discoverable machine is a
    // standing invitation, and there is no reason to advertise except while
    // somebody is actually adding a device. `discoverableTimeout` is a backstop
    // for the case where the shell dies with it still on; BlueZ then clears it
    // itself after three minutes.
    //
    // UNLIKE THE `discovering` BINDING ABOVE, THESE NEED NO `when` GUARD.
    //   That one is guarded because stopping discovery is a METHOD CALL that
    //   BlueZ rejects when there is nothing to stop. Pairable and Discoverable
    //   are plain D-Bus properties -- setting one to the value it already holds
    //   is accepted silently -- so a permanent binding writing `false` at
    //   startup costs nothing and produces no warning.
    // `|| root.pairingBusy`, because the panel closing must not pull pairability
    // out from under a pairing that is still running. Observed live: closing the
    // Control Center during a phone pairing set Pairable back to false while
    // bt-connect was still mid-exchange, which is exactly the state that makes a
    // device-initiated pairing fail.
    Binding {
        target: root.adapter
        property: "pairable"
        value: (root.scanning || root.pairingBusy) && root.enabled
    }

    Binding {
        target: root.adapter
        property: "discoverableTimeout"
        value: 180
    }

    Binding {
        target: root.adapter
        property: "discoverable"
        value: (root.scanning || root.pairingBusy) && root.enabled
    }

    // --- Pairing ------------------------------------------------------
    //
    // WHY THIS IS NOT JUST device.pair()
    //   It was, and that is why clicking a new device did nothing at all.
    //   BlueZ refuses every pairing attempt unless some process has registered
    //   an org.bluez.Agent1 to answer "confirm this passkey" / "enter this
    //   PIN". Quickshell's Bluetooth module drives the adapter and exposes
    //   pair(), but registers no agent (there is no Agent1 or AgentManager1
    //   anywhere in its source) -- so pair() was an error on the bus and a
    //   no-op in the UI, with nothing on screen to say so.
    //
    //   ~/.local/bin/bt-connect supplies the missing agent by holding one short
    //   bluetoothctl session open for the length of a single pairing -- see its
    //   header for why bluetoothctl and not blueman -- and then pairs, TRUSTS
    //   and connects the device. Trusting is the part that makes the headset
    //   reconnect on its own afterwards, when no agent is running at all.
    //
    // ONE AT A TIME
    //   Two concurrent pairings would mean two agents fighting over the same
    //   prompts, and the Process below has one `command` property anyway -- the
    //   exact shape of bug that bit the audio-profile queue further down.
    //   Pairing is a thing a person does once, deliberately, so the second
    //   request is refused rather than queued.

    // Address currently being paired, "" when idle.
    property string pairingAddress: ""

    // Progress for the row to show while it runs.
    property string pairingStatus: ""

    // Last failure, and which device it belonged to -- the row needs both, or a
    // failure on one device renders under all of them.
    property string pairingError: ""
    property string pairingErrorAddress: ""

    // Set when the failure was specifically "this device wants a PIN typed in",
    // which bt-connect cannot answer and blueman can. The page uses it to point
    // at the right button instead of just saying no.
    property bool pairingNeedsManager: false

    readonly property bool pairingBusy: root.pairingAddress !== ""

    function pairDevice(device) {
        if (!device) return;
        if (root.pairingBusy) return;

        const address = device.address || "";
        if (address === "") return;

        root.pairingAddress = address;
        root.pairingStatus = "Starting…";
        root.pairingError = "";
        root.pairingErrorAddress = "";
        root.pairingNeedsManager = false;

        pairProc.command = [Quickshell.env("HOME") + "/.local/bin/bt-connect", address];
        pairProc.running = true;
    }

    function cancelPairing() {
        if (pairProc.running) pairProc.signal(15);
    }

    Process {
        id: pairProc

        running: false

        stdout: SplitParser {
            onRead: (line) => {
                const text = line.trim();
                if (text === "") return;

                console.log("[bluetooth] pair", root.pairingAddress, text);

                if (text.startsWith("status: ")) {
                    const key = text.substring(8);
                    root.pairingStatus = key === "starting agent" ? "Starting…"
                                       : key === "pairing"        ? "Pairing…"
                                       : key === "paired"         ? "Paired, connecting…"
                                       : key === "connecting"     ? "Connecting…"
                                       : key;
                } else if (text.startsWith("passkey: ")) {
                    // Shown so it can be compared against the device's screen.
                    root.pairingStatus = "Passkey " + text.substring(9);
                } else if (text.startsWith("error: ")) {
                    root.pairingErrorAddress = root.pairingAddress;
                    root.pairingError = text.substring(7);
                } else if (text.startsWith("ok: ")) {
                    root.pairingError = "";
                    root.pairingErrorAddress = "";
                }
            }
        }

        // Exit 2 is bt-connect's "needs a PIN typed in"; 3 is "paired but could
        // not connect", which is a half-success -- the device is in My devices
        // now and one click away, so it is not worth a scary message.
        onExited: (code) => {
            root.pairingNeedsManager = (code === 2);
            root.pairingAddress = "";
            root.pairingStatus = "";
            if (root.pairingError !== "") errorExpiry.restart();
        }
    }

    // Don't leave a failure on screen indefinitely -- the device list is live,
    // and a red line under a row the user has since successfully paired is
    // worse than no line at all.
    Timer {
        id: errorExpiry

        interval: 20000
        onTriggered: {
            root.pairingError = "";
            root.pairingErrorAddress = "";
            root.pairingNeedsManager = false;
        }
    }

    function connectDevice(device) {
        if (!device) return;
        // An unpaired device has to be paired first, and pairing needs an agent
        // this shell does not have -- hence the subprocess. See above.
        if (!device.paired && !device.bonded) root.pairDevice(device);
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
        // Serialised through the queue below rather than assigned straight to
        // the Process: `command` and `deviceName` are single properties, so two
        // devices connecting within a moment of each other (a headset and a
        // mouse waking together after a resume) had the second overwrite the
        // first mid-run -- the first device silently never got its profile
        // selected, which is indistinguishable from the bug this whole section
        // exists to fix.
        root.enqueueProfile(device.deviceName || device.name || address, ["bash", "-c",
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
            "qs-btprofile", card]);
    }

    // Pending { name, command } entries. One pactl call runs at a time.
    property var profileQueue: []

    function enqueueProfile(name, command) {
        const next = root.profileQueue.slice();
        next.push({ name: name, command: command });
        root.profileQueue = next;
        if (!profileProc.running)
            root.dequeueProfile();
    }

    function dequeueProfile() {
        if (root.profileQueue.length === 0)
            return;
        const next = root.profileQueue.slice();
        const job = next.shift();
        root.profileQueue = next;
        profileProc.deviceName = job.name;
        profileProc.command = job.command;
        profileProc.running = true;
    }

    Process {
        id: profileProc

        property string deviceName: ""

        running: false

        onExited: root.dequeueProfile()

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
