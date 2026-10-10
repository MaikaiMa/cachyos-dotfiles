pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"
import "../components/RowActions.js" as RowActions

// The Wi-Fi state of the centre island, opened from the Settings tile; what
// a click does is in docs/shell.md, "Wi-Fi and Bluetooth panels". The
// scanner, the errors and the attempts live in `Network`; the list holds
// which row is expanded.
Panel {
    id: panel

    name: "wifi"

    readonly property var networks: Network.networks
    readonly property var keys: networks.map(network => network.name)

    implicitHeight: 2 * Theme.panelPadding + Theme.controlRowHeight + (Network.wifiEnabled ? Theme.gap + list.implicitHeight : 0)

    // Errors stay until the next attempt; only the expansion resets.
    onOpened: {
        list.collapse();
        list.positionAtBeginning();
    }
    onClosed: list.collapse()

    // The expansion kind is the failure kind: password or suspect.
    Connections {
        target: Network

        function onFailed(ssid: string, kind: string) {
            list.expand(ssid, kind);
        }
    }

    function networkFor(key: string): var {
        return networks.find(network => network.name === key) ?? null;
    }

    function activate(network: var) {
        const action = Network.primaryAction(network);
        if (action === "manage") {
            list.toggle(network.name, "connected");
        } else if (action === "connect") {
            list.collapse();
            Network.attemptConnect(network);
        } else if (action === "password") {
            list.toggle(network.name, "password");
        } else {
            Network.requestLogin(network);
        }
    }

    // A saved network gets Connect and Forget; the rest behave like a click.
    function activateSecondary(network: var) {
        if (network.known && !network.connected)
            list.toggle(network.name, "saved");
        else
            activate(network);
    }

    function actionsFor(kind: string): var {
        if (kind === "connected")
            return RowActions.connected();
        if (kind === "saved")
            return RowActions.saved();
        return RowActions.suspect();
    }

    function submitPassword(network: var, password: string) {
        list.collapse();
        Network.attemptPassword(network, password);
    }

    function act(network: var, action: string) {
        list.collapse();
        if (action === "connect")
            Network.attemptConnect(network);
        else if (action === "disconnect")
            Network.disconnectFrom(network);
        else if (action === "forget")
            Network.attemptForget(network);
    }

    PanelControlRow {
        id: controls

        x: panel.contentX
        y: Theme.panelPadding
        width: panel.contentWidth
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
        settingsTab: "network_wifi"
        onToggled: Network.toggleWifi()
    }

    RowList {
        id: list

        objectName: "networkList"
        x: panel.contentX
        y: controls.y + controls.height + Theme.gap
        width: panel.contentWidth
        height: implicitHeight
        visible: Network.wifiEnabled
        keys: panel.keys
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
            expanded: list.expandedKey === rowKey
            mode: expanded && list.expandedKind === "password" ? "password" : "actions"
            actions: expanded ? panel.actionsFor(list.expandedKind) : []
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
