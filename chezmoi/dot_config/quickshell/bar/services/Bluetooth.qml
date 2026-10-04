pragma Singleton

import QtQuick
import Quickshell
// Namespaced: this singleton has the same name as the module's.
import Quickshell.Bluetooth as Bluez

// Bluetooth power and connected devices from Quickshell's BlueZ backend.
// The module's qmldir lacks `depends Quickshell`, so qmllint cannot resolve its
// property types; the two lines that read them carry a disable comment.
Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property bool available: adapter !== null
    readonly property bool btEnabled: adapter ? adapter.enabled : false
    readonly property int connectedDevices: Bluez.Bluetooth.devices.values.filter(device => device.connected).length // qmllint disable unresolved-type

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
