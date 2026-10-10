pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Wi-Fi state of the centre island, opened from the Settings tile: the
// control row, then the networks. A click connects to a saved or open network;
// an unknown secured one expands into a password field, the connected one into
// Disconnect and Forget, and a right click on a saved one into Connect and
// Forget. One row is expanded at a time. The scanner, the errors and the
// attempts live in `Network`; this panel only holds which row is expanded.
Appear {
    id: panel

    property string expandedKey: ""
    // What the expanded row shows: "password", "connected" (Disconnect, Forget),
    // "saved" (Connect, Forget) or "suspect" (Forget, after a client failure
    // that may be a stale password).
    property string expandedKind: ""

    readonly property var networks: Network.networks
    readonly property var keys: networks.map(network => network.name)

    implicitWidth: Theme.panelWidths.wifi
    implicitHeight: 2 * Theme.panelPadding + Theme.controlRowHeight + (Network.wifiEnabled ? Theme.gap + list.implicitHeight : 0)

    // Errors stay until the next attempt; only the expansion resets.
    onShownChanged: {
        collapse();
        if (shown)
            list.positionAtBeginning();
    }

    Connections {
        target: Network

        function onFailed(ssid: string, kind: string) {
            panel.expand(ssid, kind);
        }
    }

    function networkFor(key: string): var {
        return networks.find(network => network.name === key) ?? null;
    }

    function expand(key: string, kind: string) {
        expandedKind = kind;
        expandedKey = key;
    }

    function collapse() {
        expandedKey = "";
        expandedKind = "";
    }

    function toggle(key: string, kind: string) {
        if (expandedKey === key && expandedKind === kind)
            collapse();
        else
            expand(key, kind);
    }

    function activate(network: var) {
        const key = network.name;
        if (network.connected) {
            toggle(key, "connected");
            return;
        }
        // A saved profile whose password was just refused asks for a new one.
        const refused = Network.wrongPassword.includes(key);
        if (!Network.secured(network) || (network.known && !refused)) {
            collapse();
            Network.attemptConnect(network);
        } else if (Network.needsPassword(network)) {
            toggle(key, "password");
        } else {
            Network.setError(key, "Needs a login: open settings");
        }
    }

    function activateSecondary(network: var) {
        if (network.known && !network.connected)
            toggle(network.name, "saved");
        else
            activate(network);
    }

    function actionsFor(kind: string): var {
        const forget = {
            key: "forget",
            label: "Forget",
            danger: true
        };
        if (kind === "connected")
            return [
                {
                    key: "disconnect",
                    label: "Disconnect"
                },
                forget
            ];
        if (kind === "saved")
            return [
                {
                    key: "connect",
                    label: "Connect",
                    accent: true
                },
                forget
            ];
        return [forget];
    }

    function submitPassword(network: var, password: string) {
        collapse();
        Network.attemptPassword(network, password);
    }

    function act(network: var, action: string) {
        collapse();
        if (action === "connect")
            Network.attemptConnect(network);
        else if (action === "disconnect")
            Network.disconnectFrom(network);
        else if (action === "forget")
            Network.attemptForget(network);
    }

    PanelControlRow {
        id: controls

        x: Theme.panelPadding
        y: Theme.panelPadding
        width: panel.width - 2 * Theme.panelPadding
        switchName: "Wi-Fi"
        checked: Network.wifiEnabled
        stateText: {
            if (!Network.wifiEnabled)
                return "Off";
            if (Network.scanning)
                return "Scanning…";
            return Network.wifiConnected ? "On · " + Network.ssid : "On · not connected";
        }
        actionLabel: "Open Wi-Fi settings"
        onToggled: Network.toggleWifi()
        // The settings window needs the keyboard, which the open panel holds.
        onActionTriggered: {
            Dms.openSettingsTab("network_wifi");
            Shell.close();
        }
    }

    RowList {
        id: list

        objectName: "networkList"
        x: Theme.panelPadding
        y: controls.y + controls.height + Theme.gap
        width: panel.width - 2 * Theme.panelPadding
        height: implicitHeight
        visible: Network.wifiEnabled
        keys: panel.keys
        expandedKey: panel.expandedKey
        errors: Network.errors
        emptyText: Network.scanning ? "Looking for networks" : "No networks in range"

        delegate: NetworkRow {
            required property string rowKey
            readonly property var network: panel.networkFor(rowKey)

            width: ListView.view.width
            iconName: network ? Network.signalIcon(network) : "signal_wifi_0_bar"
            title: rowKey
            detail: network ? Network.detailText(network) : ""
            secured: network ? Network.secured(network) : false
            highlighted: network ? network.connected : false
            expanded: panel.expandedKey === rowKey
            mode: expanded && panel.expandedKind === "password" ? "password" : "actions"
            actions: expanded ? panel.actionsFor(panel.expandedKind) : []
            errorText: Network.errors[rowKey] ?? ""
            onClicked: {
                if (network)
                    panel.activate(network);
            }
            onSecondaryClicked: {
                if (network)
                    panel.activateSecondary(network);
            }
            onActionTriggered: action => {
                if (network)
                    panel.act(network, action);
            }
            onPasswordSubmitted: password => {
                if (network)
                    panel.submitPassword(network, password);
            }
        }
    }
}
