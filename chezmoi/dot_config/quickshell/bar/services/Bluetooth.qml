pragma Singleton

import QtQuick
import Quickshell
import ".."
// Namespaced: this singleton has the same name as the module's.
import Quickshell.Bluetooth as Bluez

// Bluetooth power, devices and discovery from Quickshell's BlueZ backend.
// The module's qmldir lacks `depends Quickshell`, so qmllint cannot resolve its
// property types; the lines that read them carry a disable comment.
Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property bool available: adapter !== null
    readonly property bool btEnabled: adapter ? adapter.enabled : false
    // Powered and ready: `enabled` turns true on the write, before BlueZ can
    // start a discovery.
    readonly property bool powered: adapter ? adapter.state === Bluez.BluetoothAdapterState.Enabled : false // qmllint disable unresolved-type
    readonly property int connectedDevices: Bluez.Bluetooth.devices.values.filter(device => device.connected).length // qmllint disable unresolved-type
    readonly property bool discovering: adapter ? adapter.discovering : false

    // Discovery runs while the Bluetooth panel is open on any screen and the
    // adapter is powered, for at most Theme.bluetoothDiscoveryTime; this service
    // owns it, so a panel moving between screens or an island going away cannot
    // leave it running.
    readonly property bool discoveryWanted: Shell.centreState === "bluetooth" && powered
    // The first seconds of a discovery, shown as "Scanning…".
    readonly property bool scanning: scanNote.running

    // Per address, until the next attempt on that device: the row's error line.
    property var errors: ({})
    // Attempts in flight, address -> start time in ms; polled while any are.
    property var pendingPairs: ({})
    property var pendingConnects: ({})

    onDiscoveryWantedChanged: {
        setDiscovering(discoveryWanted);
        if (discoveryWanted) {
            discoveryCap.restart();
            scanNote.restart();
        } else {
            discoveryCap.stop();
            scanNote.stop();
        }
    }

    // Another adapter while the panel is open discovers too.
    onAdapterChanged: {
        if (discoveryWanted)
            setDiscovering(true);
    }

    // The Bluetooth panel's list: connected, then paired, then discovered devices,
    // each by name. Discovered devices without a name (beacons, most LE noise) are
    // left out.
    readonly property var devices: {
        if (!adapter || !powered)
            return [];
        return adapter.devices.values.filter(device => device.paired || device.deviceName !== "").sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
    }

    function rank(device: var): int {
        return device.connected ? 0 : device.paired ? 1 : 2;
    }

    // From BlueZ's icon name (freedesktop names such as audio-headset, input-mouse).
    function deviceIcon(device: var): string {
        const icon = device.icon;
        if (icon.startsWith("audio-head") || icon === "audio-card")
            return "headphones";
        if (icon === "input-mouse" || icon === "input-tablet")
            return "mouse";
        if (icon === "input-keyboard")
            return "keyboard";
        if (icon === "input-gaming")
            return "sports_esports";
        if (icon === "phone")
            return "smartphone";
        return "bluetooth";
    }

    // "82%", or empty when the device reports no level; Quickshell reports 0..1.
    function batteryText(device: var): string {
        return device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "";
    }

    // The row's second line: the battery level, then the connection.
    function detailText(device: var): string {
        let state = "";
        if (device.pairing)
            state = "Pairing…";
        else if (device.state === Bluez.BluetoothDeviceState.Connecting) // qmllint disable unresolved-type
            state = "Connecting…";
        else if (device.state === Bluez.BluetoothDeviceState.Disconnecting) // qmllint disable unresolved-type
            state = "Disconnecting…";
        else if (device.connected)
            state = "Connected";
        return [batteryText(device), state].filter(part => part !== "").join(" · ");
    }

    // A connect that ended without a connection; pending connects are polled.
    function connectSettled(device: var): bool {
        return device.state === Bluez.BluetoothDeviceState.Disconnected || device.state === Bluez.BluetoothDeviceState.Connected; // qmllint disable unresolved-type
    }

    function deviceFor(address: string): var {
        return devices.find(device => device.address === address) ?? null;
    }

    function setError(address: string, text: string) {
        const next = Object.assign({}, errors);
        if (text === "")
            delete next[address];
        else
            next[address] = text;
        errors = next;
    }

    function withPending(map: var, address: string, add: bool): var {
        const next = Object.assign({}, map);
        if (add)
            next[address] = Date.now();
        else
            delete next[address];
        return next;
    }

    function startConnect(device: var) {
        setError(device.address, "");
        pendingConnects = withPending(pendingConnects, device.address, true);
        connectDevice(device);
    }

    function startPair(device: var) {
        setError(device.address, "");
        pendingPairs = withPending(pendingPairs, device.address, true);
        pair(device);
    }

    // Pairing and connecting report no failure of their own: a pair that stops
    // without a bond, or a connect that settles disconnected, is one. The module
    // does not say why a pair failed, so a device that wanted a PIN or passkey
    // shows the same text; the terminal button has bluetoothctl with its agent.
    function checkPending() {
        const now = Date.now();
        for (const address of Object.keys(pendingPairs)) {
            const device = deviceFor(address);
            const elapsed = now - pendingPairs[address];
            if (!device) {
                pendingPairs = withPending(pendingPairs, address, false);
            } else if (device.paired) {
                pendingPairs = withPending(pendingPairs, address, false);
                pendingConnects = withPending(pendingConnects, address, true);
                trustAndConnect(device);
            } else if ((!device.pairing && elapsed > Motion.pendingSettle) || elapsed > Motion.pendingTimeout) {
                pendingPairs = withPending(pendingPairs, address, false);
                setError(address, "Pairing failed");
            }
        }
        for (const address of Object.keys(pendingConnects)) {
            const device = deviceFor(address);
            const elapsed = now - pendingConnects[address];
            if (!device || device.connected) {
                pendingConnects = withPending(pendingConnects, address, false);
            } else if ((connectSettled(device) && elapsed > Motion.pendingSettle) || elapsed > Motion.pendingTimeout) {
                pendingConnects = withPending(pendingConnects, address, false);
                setError(address, "Could not connect");
            }
        }
    }

    // bluetoothctl in a terminal, for PINs, passkeys and everything else the
    // panel leaves out: DMS's terminalOverride, else xdg-terminal-exec, else
    // Ghostty, as the Updates panel's Update all.
    function openTerminal() {
        Quickshell.execDetached(["sh", "-c", "if [ -n \"$1\" ]; then exec \"$1\" -e bluetoothctl; elif command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec bluetoothctl; else exec ghostty -e bluetoothctl; fi", "sh", Dms.terminal]);
    }

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function setDiscovering(value: bool) {
        if (adapter && adapter.enabled && adapter.discovering !== value)
            adapter.discovering = value;
    }

    function connectDevice(device: var) {
        device.connect();
    }

    function disconnectDevice(device: var) {
        device.disconnect();
    }

    function pair(device: var) {
        device.pair();
    }

    // After a successful pair: trusted, so it reconnects by itself later.
    function trustAndConnect(device: var) {
        device.trusted = true;
        device.connect();
    }

    function forget(device: var) {
        device.forget();
    }

    Timer {
        id: discoveryCap

        interval: Theme.bluetoothDiscoveryTime
        onTriggered: root.setDiscovering(false)
    }

    Timer {
        id: scanNote

        interval: Motion.firstScanTime
    }

    Timer {
        interval: 500
        repeat: true
        running: Object.keys(root.pendingPairs).length > 0 || Object.keys(root.pendingConnects).length > 0
        onTriggered: root.checkPending()
    }
}
