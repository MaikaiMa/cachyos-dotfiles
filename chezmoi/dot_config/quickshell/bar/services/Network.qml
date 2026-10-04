pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Wi-Fi state from Quickshell's NetworkManager backend.
Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property var activeNetwork: wifiDevice ? wifiDevice.networks.values.find(network => network.connected) ?? null : null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    // Any device, wired or wireless, has a connection.
    readonly property bool connected: Networking.devices.values.some(device => device.connected)
    readonly property bool wifiConnected: activeNetwork !== null
    readonly property string ssid: activeNetwork ? activeNetwork.name : ""
    // 0..100; Quickshell reports 0..1.
    readonly property int strength: activeNetwork ? Math.round(activeNetwork.signalStrength * 100) : 0
    readonly property bool weak: wifiConnected && strength < 40

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
