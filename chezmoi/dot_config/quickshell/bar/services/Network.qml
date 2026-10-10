pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking
import ".."

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
    // The one glyph for the Wi-Fi state, so the tile, the island and the panel
    // row show the same bars.
    readonly property string statusIcon: !wifiEnabled ? "wifi_off" : activeNetwork ? signalIcon(activeNetwork) : "signal_wifi_0_bar"

    // The Wi-Fi panel's list: one network per SSID (the connected one, else a known
    // one, else the strongest), hidden networks left out; connected first, then
    // known, then the rest by signal bars and name. Bars rather than raw strength,
    // so rows do not swap places on every small change.
    readonly property var networks: {
        if (!wifiDevice || !wifiEnabled)
            return [];
        const bySsid = {};
        for (const network of wifiDevice.networks.values) {
            if (network.name === "")
                continue;
            const kept = bySsid[network.name];
            if (!kept || rank(network) < rank(kept) || (rank(network) === rank(kept) && network.signalStrength > kept.signalStrength))
                bySsid[network.name] = network;
        }
        return Object.values(bySsid).sort((a, b) => rank(a) - rank(b) || bars(b) - bars(a) || a.name.localeCompare(b.name));
    }

    // Quickshell lists networks that are neither connected nor saved only while
    // its scanner is on, and the scanner asks NetworkManager for a scan at once
    // and then at most every 10 s. It runs while the Wi-Fi panel is open on any
    // screen and Wi-Fi is on; this service owns it, so a panel moving between
    // screens or an island going away cannot leave it running.
    readonly property bool scannerWanted: Shell.centreState === "wifi" && wifiEnabled && wifiDevice !== null
    // The first scan after the scanner started is still running.
    readonly property bool scanning: firstScan.running

    // Per SSID, until the next attempt on that network: the row's error line.
    property var errors: ({})
    // SSIDs whose last attempt was refused on the password: a click asks again.
    property var wrongPassword: []
    // SSID -> time of the last connect the panel started, in ms.
    property var lastAttempt: ({})

    // A failure the panel shows by expanding the row: "password" opens the
    // field, "suspect" offers Forget for a saved network that may hold a stale
    // password.
    signal failed(string ssid, string kind)

    onScannerWantedChanged: {
        setScanning(scannerWanted);
        if (scannerWanted)
            firstScan.restart();
        else
            firstScan.stop();
    }

    // A new Wi-Fi device while the panel is open gets the scanner too.
    onWifiDeviceChanged: {
        if (scannerWanted)
            setScanning(true);
    }

    function rank(network: var): int {
        return network.connected ? 0 : network.known ? 1 : 2;
    }

    // 0..4, the signal glyph's bars.
    function bars(network: var): int {
        return Math.min(4, Math.floor(network.signalStrength * 5));
    }

    function signalIcon(network: var): string {
        return ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"][bars(network)];
    }

    function secured(network: var): bool {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    // A pre-shared key the panel can ask for; enterprise networks need the settings window.
    function needsPassword(network: var): bool {
        return [WifiSecurityType.Sae, WifiSecurityType.Wpa2Psk, WifiSecurityType.WpaPsk, WifiSecurityType.StaticWep].includes(network.security);
    }

    // The row's second line.
    function detailText(network: var): string {
        if (network.state === ConnectionState.Connecting)
            return "Connecting…";
        if (network.state === ConnectionState.Disconnecting)
            return "Disconnecting…";
        return network.connected ? "Connected" : "";
    }

    function failureText(reason: int): string {
        if (reason === ConnectionFailReason.NoSecrets)
            return "Wrong password";
        if (reason === ConnectionFailReason.WifiAuthTimeout)
            return "No answer from the network";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "Network out of range";
        return "Could not connect";
    }

    function setError(ssid: string, text: string) {
        const next = Object.assign({}, errors);
        if (text === "")
            delete next[ssid];
        else
            next[ssid] = text;
        errors = next;
    }

    function noteAttempt(ssid: string) {
        setError(ssid, "");
        const next = Object.assign({}, lastAttempt);
        next[ssid] = Date.now();
        lastAttempt = next;
    }

    // A click on a saved or open network.
    function attemptConnect(network: var) {
        noteAttempt(network.name);
        connectTo(network);
    }

    function attemptPassword(network: var, password: string) {
        noteAttempt(network.name);
        wrongPassword = wrongPassword.filter(ssid => ssid !== network.name);
        connectWithPassword(network, password);
    }

    function attemptForget(network: var) {
        setError(network.name, "");
        wrongPassword = wrongPassword.filter(ssid => ssid !== network.name);
        forget(network);
    }

    // NetworkManager reports a stale saved password on a WPA network often as a
    // plain client failure, not as missing secrets.
    function reportFailure(network: var, reason: int) {
        const ssid = network.name;
        const recent = Date.now() - (lastAttempt[ssid] ?? 0) < Motion.pendingTimeout;
        if (reason === ConnectionFailReason.NoSecrets && needsPassword(network)) {
            setError(ssid, "Wrong password");
            if (!wrongPassword.includes(ssid))
                wrongPassword = wrongPassword.concat([ssid]);
            failed(ssid, "password");
        } else if ((reason === ConnectionFailReason.WifiClientFailed || reason === ConnectionFailReason.WifiClientDisconnected) && network.known && recent) {
            setError(ssid, "Could not connect: wrong password?");
            failed(ssid, "suspect");
        } else {
            setError(ssid, failureText(reason));
        }
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function connectTo(network: var) {
        network.connect();
    }

    function connectWithPassword(network: var, password: string) {
        network.connectWithPsk(password);
    }

    function disconnectFrom(network: var) {
        network.disconnect();
    }

    function forget(network: var) {
        network.forget();
    }

    // The module's scanner switch; scannerWanted drives it.
    function setScanning(value: bool) {
        if (wifiDevice && wifiDevice.scannerEnabled !== value)
            wifiDevice.scannerEnabled = value;
    }

    // One watcher per network the device knows, hidden and duplicate SSIDs
    // included, on its stable model: the derived list rebuilds on every
    // strength change and would drop a failure emitted meanwhile.
    Instantiator {
        model: root.wifiDevice ? root.wifiDevice.networks : null

        delegate: Connections {
            id: watcher

            required property var modelData

            target: modelData

            function onConnectionFailed(reason: int) {
                root.reportFailure(watcher.modelData, reason);
            }

            function onConnectedChanged() {
                if (watcher.modelData.connected)
                    root.setError(watcher.modelData.name, "");
            }
        }
    }

    // The module does not say when a scan ends; NetworkManager's take a few seconds.
    Timer {
        id: firstScan

        interval: Motion.firstScanTime
    }
}
