pragma Singleton

import QtQuick
import Quickshell
// Namespaced: this singleton has the same name as the module's.
import Quickshell.Bluetooth as Bluez

// Bluetooth power, devices and discovery from Quickshell's BlueZ backend.
// The module's qmldir lacks `depends Quickshell`, so qmllint cannot resolve its
// property types; the lines that read them carry a disable comment.
Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property bool available: adapter !== null
    readonly property bool bluetoothEnabled: adapter ? adapter.enabled : false
    // Powered and ready: `enabled` turns true on the write, before BlueZ can
    // start a discovery.
    readonly property bool powered: adapter ? adapter.state === Bluez.BluetoothAdapterState.Enabled : false // qmllint disable unresolved-type
    readonly property int connectedDevices: Bluez.Bluetooth.devices.values.filter(device => device.connected).length // qmllint disable unresolved-type
    readonly property bool discovering: adapter ? adapter.discovering : false

    // Set by Shell while the Bluetooth panel is open on any screen.
    property bool active: false
    // Discovery stops after this at the latest.
    readonly property int discoveryTime: 30000
    // How long the panel says "Scanning…" after discovery started.
    readonly property int firstScanTime: 4000
    // A pair or connect that is idle this long after the request has failed.
    readonly property int pendingSettle: 2000
    // A pair or connect still pending after this has failed.
    readonly property int pendingTimeout: 20000

    // Discovery runs while active and the adapter is powered, for at most
    // discoveryTime; this service owns it, so a panel moving between screens
    // or an island going away cannot leave it running.
    readonly property bool discoveryWanted: active && powered
    // The first seconds of a discovery, shown as "Scanning…".
    readonly property bool scanning: scanNote.running

    // Per address, until the next attempt on that device: the row's error line.
    property var errors: ({})
    // Attempts in flight, address -> start time in ms.
    property var pendingPairs: ({})
    property var pendingConnects: ({})
    // The pairing and connection state of every device in flight: BlueZ's
    // property signals re-check them, the deadline timer covers the time-outs.
    readonly property string pendingStates: Object.keys(pendingPairs).concat(Object.keys(pendingConnects)).map(address => {
        const device = deviceFor(address);
        return device ? [address, device.paired, device.pairing, device.state, device.connected].join(":") : address;
    }).join(" ")

    onPendingStatesChanged: Qt.callLater(checkPending)

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

    // A connect that ended without a connection.
    function connectSettled(device: var): bool {
        return device.state === Bluez.BluetoothDeviceState.Disconnected || device.state === Bluez.BluetoothDeviceState.Connected; // qmllint disable unresolved-type
    }

    function deviceFor(address: string): var {
        return devices.find(device => device.address === address) ?? null;
    }

    function setError(address: string, text: string) {
        errors = text === "" ? Maps.withoutKey(errors, address) : Maps.withKey(errors, address, text);
    }

    function startConnect(device: var) {
        setError(device.address, "");
        pendingConnects = Maps.withKey(pendingConnects, device.address, Date.now());
        connectDevice(device);
    }

    function startPair(device: var) {
        setError(device.address, "");
        pendingPairs = Maps.withKey(pendingPairs, device.address, Date.now());
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
                pendingPairs = Maps.withoutKey(pendingPairs, address);
            } else if (device.paired) {
                pendingPairs = Maps.withoutKey(pendingPairs, address);
                pendingConnects = Maps.withKey(pendingConnects, address, now);
                trustAndConnect(device);
            } else if ((!device.pairing && elapsed > pendingSettle) || elapsed > pendingTimeout) {
                pendingPairs = Maps.withoutKey(pendingPairs, address);
                setError(address, "Pairing failed");
            }
        }
        for (const address of Object.keys(pendingConnects)) {
            const device = deviceFor(address);
            const elapsed = now - pendingConnects[address];
            if (!device || device.connected) {
                pendingConnects = Maps.withoutKey(pendingConnects, address);
            } else if ((connectSettled(device) && elapsed > pendingSettle) || elapsed > pendingTimeout) {
                pendingConnects = Maps.withoutKey(pendingConnects, address);
                setError(address, "Could not connect");
            }
        }
        scheduleDeadline(now);
    }

    // The next settle or time-out of any attempt in flight.
    function scheduleDeadline(now: real) {
        const starts = Object.values(pendingPairs).concat(Object.values(pendingConnects));
        const times = starts.reduce((all, start) => all.concat([start + pendingSettle, start + pendingTimeout]), []).filter(time => time > now);
        const next = Math.min.apply(null, times);
        if (isFinite(next)) {
            deadline.interval = Math.max(1, next - now + 1);
            deadline.restart();
        } else {
            deadline.stop();
        }
    }

    // bluetoothctl in a terminal, for PINs, passkeys and everything else the
    // panel leaves out.
    function openTerminal() {
        Session.openInTerminal(["bluetoothctl"]);
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

    // Errors stay until the next attempt, and this is one.
    function disconnectDevice(device: var) {
        setError(device.address, "");
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
        setError(device.address, "");
        device.forget();
    }

    Timer {
        id: discoveryCap

        interval: root.discoveryTime
        onTriggered: root.setDiscovering(false)
    }

    Timer {
        id: scanNote

        interval: root.firstScanTime
    }

    Timer {
        id: deadline

        onTriggered: root.checkPending()
    }
}
