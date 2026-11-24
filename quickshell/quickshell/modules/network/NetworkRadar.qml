import QtQuick
import qs

// =============================================================================
// NetworkRadar — the Wi-Fi radar as a panel of its own.
// =============================================================================
// The big sibling of the Control Center's Wi-Fi list. The list stays for a
// quick join; this is the one you open to look around: every network in
// range at once, placed by strength, with what you are on and whether it
// actually reaches the internet.
//
//   quickshell ipc call network toggle | open | close
//   or the radar button on the Control Center's Wi-Fi page.
//   The same body is also the Network page of the left drawer.
//
// No keybind of its own -- nothing in bindings.lua moved for it. If one is
// ever wanted, route it like the others: key -> bindings.lua -> `ipc call`.
//
// Everything inside lives in NetworkRadarBody.qml, which also owns the scan
// and address demands; this file is only the window.
// =============================================================================

Panel {
    id: root

    name: "network"
    placement: "center"
    panelWidth: 600

    content: NetworkRadarBody {
        consumerId: "network-radar"
        onCloseRequested: root.hide()
    }
}
