pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Settings state of the centre island: toggle grid, three capsule sliders and,
// when there are any, the notifications. implicitHeight is the settled height the
// island grows to; it drops as soon as a row starts leaving, so the island shrinks
// in one animation while the row collapses inside it.
Appear {
    id: panel

    readonly property real cellWidth: (width - 2 * Theme.panelPadding - (Theme.settingsColumns - 1) * Theme.tileGap) / Theme.settingsColumns

    // Rows that are animating out; the service drops them once they are gone.
    property var leavingIds: []
    property bool clearing: false
    // One row at a time is expanded; expandedExtra is what it adds once settled.
    property string expandedId: ""
    property real expandedExtra: 0
    readonly property int settledCount: clearing ? 0 : Notifications.items.filter(item => !leavingIds.includes(item.id)).length
    readonly property real settledListHeight: Math.min(Theme.notificationListMaxHeight, settledCount * Theme.notificationRowHeight + Math.max(0, settledCount - 1) * Theme.notificationRowGap + (clearing ? 0 : expandedExtra))
    readonly property real notificationsHeight: settledCount > 0 ? Theme.notificationHeaderGap + Theme.notificationHeaderHeight + settledListHeight : 0

    implicitWidth: Theme.panelWidths.settings
    implicitHeight: 2 * Theme.panelPadding + Theme.settingsGridHeight + Theme.tileGap + Theme.settingsSlidersHeight + notificationsHeight

    // The notifications indicator opens Settings for the list: newest first, on top.
    // The rotation lock can change from a terminal, so it is read again too.
    onShownChanged: {
        if (shown) {
            list.positionViewAtBeginning();
            Tablet.refresh();
        } else {
            expandedId = "";
        }
    }
    onExpandedIdChanged: {
        if (expandedId === "")
            expandedExtra = 0;
    }

    function spanWidth(cells: int): real {
        return cells * cellWidth + (cells - 1) * Theme.tileGap;
    }

    function cellX(column: int): real {
        return Theme.panelPadding + column * (cellWidth + Theme.tileGap);
    }

    function nextProfile(): string {
        const profiles = Battery.profiles;
        return profiles[(profiles.indexOf(Battery.profile) + 1) % profiles.length];
    }

    function dismiss(id: string) {
        if (expandedId === id)
            expandedId = "";
        if (!leavingIds.includes(id))
            leavingIds = leavingIds.concat([id]);
    }

    function toggleExpanded(id: string) {
        expandedId = expandedId === id ? "" : id;
    }

    function noteExtra(id: string, extra: real) {
        if (id === expandedId)
            expandedExtra = extra;
    }

    // A resident notification stays in the list after an action or a reply.
    function invokeAction(id: string, identifier: string) {
        const resident = Notifications.isResident(id);
        if (Notifications.invoke(id, identifier) && !resident)
            dismiss(id);
    }

    function sendReply(id: string, text: string) {
        const resident = Notifications.isResident(id);
        if (Notifications.reply(id, text) && !resident)
            dismiss(id);
    }

    function clearAll() {
        expandedId = "";
        clearing = true;
        clearTimer.restart();
    }

    // The ListView keeps its delegates while items come and go, so a leaving
    // row can finish its animation.
    function syncModel() {
        const items = Notifications.items;
        const ids = items.map(item => item.id);
        notificationModel.sync(ids, id => {
            const item = items.find(candidate => candidate.id === id);
            return {
                appName: item.appName,
                summary: item.summary,
                body: item.body,
                appIcon: item.appIcon,
                image: item.image,
                desktopEntry: item.desktopEntry
            };
        });
        const kept = leavingIds.filter(id => ids.includes(id));
        if (kept.length !== leavingIds.length)
            leavingIds = kept;
        if (expandedId !== "" && !ids.includes(expandedId))
            expandedId = "";
    }

    Connections {
        target: Notifications

        function onItemsChanged() {
            panel.syncModel();
        }
    }

    Component.onCompleted: syncModel()

    KeyedListModel {
        id: notificationModel

        keyRole: "notificationId"
        refresh: true
    }

    Timer {
        id: clearTimer

        interval: Motion.crossfadeDuration + Motion.settleMargin
        onTriggered: {
            Notifications.clearAll();
            panel.clearing = false;
            panel.leavingIds = [];
        }
    }

    // Two rows, no holes. Docked: Wi-Fi | DND | Caffeine, then Bluetooth | Power
    // profile. Detached, Bluetooth shrinks to one cell and the rotation lock takes
    // the other. Declared in reading order, which is also the Tab order.
    Item {
        id: grid

        readonly property real secondRow: Theme.settingsTileHeight + Theme.tileGap

        y: Theme.panelPadding
        width: panel.width
        height: Theme.settingsGridHeight

        GridTile {
            objectName: "wifiTile"
            x: panel.cellX(0)
            y: 0
            width: panel.spanWidth(2)
            wide: true
            title: "Wi-Fi"
            active: Network.wifiEnabled
            iconName: Network.statusIcon
            stateText: !Network.wifiEnabled ? "Off" : !Network.wifiConnected ? "Disconnected" : Network.weak ? "Weak · " + Network.ssid : Network.ssid
            hasPanel: true
            onActivated: Network.toggleWifi()
            onSecondaryAction: Shell.open("wifi", Shell.screenName)
        }

        GridTile {
            objectName: "dndTile"
            x: panel.cellX(2)
            y: 0
            width: panel.spanWidth(1)
            title: "Do not disturb"
            active: Notifications.doNotDisturb
            iconName: "do_not_disturb_on"
            onActivated: Notifications.toggleDoNotDisturb()
        }

        GridTile {
            objectName: "caffeineTile"
            x: panel.cellX(3)
            y: 0
            width: panel.spanWidth(1)
            title: "Caffeine"
            active: Dms.caffeine
            iconName: "coffee"
            onActivated: Dms.toggleCaffeine()
        }

        GridTile {
            objectName: "bluetoothTile"
            x: panel.cellX(0)
            y: grid.secondRow
            width: panel.spanWidth(Tablet.detached ? 1 : 2)
            wide: !Tablet.detached
            title: "Bluetooth"
            active: Bluetooth.btEnabled
            iconName: !Bluetooth.btEnabled ? "bluetooth_disabled" : Bluetooth.connectedDevices > 0 ? "bluetooth_connected" : "bluetooth"
            stateText: {
                if (!Bluetooth.available)
                    return "Unavailable";
                if (!Bluetooth.btEnabled)
                    return "Off";
                const devices = Bluetooth.connectedDevices;
                return devices === 0 ? "On" : devices === 1 ? "1 device" : devices + " devices";
            }
            hasPanel: true
            onActivated: Bluetooth.toggleBluetooth()
            onSecondaryAction: Shell.open("bluetooth", Shell.screenName)
        }

        // Grows out of the cell Bluetooth frees; Tab skips it while docked.
        GridTile {
            objectName: "rotationTile"
            x: panel.cellX(1)
            y: grid.secondRow
            width: panel.spanWidth(1)
            title: "Rotation lock"
            active: Tablet.rotationLocked
            iconName: Tablet.rotationLocked ? "screen_lock_rotation" : "screen_rotation"
            enabled: Tablet.detached
            opacity: Tablet.detached ? 1 : 0
            scale: Tablet.detached ? 1 : 0.85
            visible: opacity > 0
            onActivated: Tablet.toggleRotationLock()

            Behavior on opacity {
                MorphAnimation {}
            }
            Behavior on scale {
                MorphAnimation {}
            }
        }

        GridTile {
            objectName: "profileTile"
            x: panel.cellX(2)
            y: grid.secondRow
            width: panel.spanWidth(2)
            wide: true
            title: "Power profile"
            active: Battery.profile !== "balanced"
            iconName: Battery.profile === "power-saver" ? "battery_saver" : Battery.profile === "performance" ? "bolt" : "balance"
            stateText: Battery.profile === "power-saver" ? "Power saver" : Battery.profile === "performance" ? "Performance" : "Balanced"
            onActivated: Battery.setProfile(panel.nextProfile())
        }
    }

    // The tiles move with the island's grow curve when the grid changes layout.
    component GridTile: Tile {
        Behavior on x {
            MorphAnimation {}
        }
        Behavior on width {
            MorphAnimation {}
        }
    }

    Column {
        id: sliders

        x: Theme.panelPadding
        y: grid.y + grid.height + Theme.tileGap
        width: panel.width - 2 * Theme.panelPadding
        spacing: Theme.sliderGap

        CapsuleSlider {
            objectName: "volumeSlider"
            width: parent.width
            label: "Volume"
            available: Audio.ready
            value: Audio.volume * 100
            muted: Audio.muted
            iconName: Audio.muted ? "volume_off" : "volume_up"
            onMoved: target => Audio.setVolume(target / 100)
            onIconClicked: Audio.toggleMute()
            hasPanel: true
            onPanelRequested: Shell.open("sound", Shell.screenName)
        }

        CapsuleSlider {
            objectName: "micSlider"
            width: parent.width
            label: "Microphone"
            available: Audio.source !== null
            value: Audio.micVolume * 100
            muted: Audio.micMuted
            iconName: Audio.micMuted ? "mic_off" : "mic"
            onMoved: target => Audio.setMicVolume(target / 100)
            onIconClicked: Audio.toggleMicMute()
            hasPanel: true
            onPanelRequested: Shell.open("sound", Shell.screenName)
        }

        CapsuleSlider {
            objectName: "brightnessSlider"
            width: parent.width
            label: "Brightness"
            available: Brightness.available
            minimum: 1
            value: Math.max(0, Brightness.percentage)
            iconName: "light_mode"
            onMoved: target => Brightness.set(target)
            onIconClicked: Brightness.cycle()
            hasPanel: true
            onPanelRequested: Shell.open("display", Shell.screenName)
        }
    }

    Item {
        id: notifications

        objectName: "notifications"
        y: sliders.y + sliders.height
        width: panel.width
        height: Theme.notificationHeaderGap + Theme.notificationHeaderHeight + list.height
        visible: notificationModel.count > 0

        SectionHeader {
            id: header

            x: Theme.panelPadding
            y: Theme.notificationHeaderGap
            width: parent.width - 2 * Theme.panelPadding
            height: Theme.notificationHeaderHeight
            iconName: "notifications"
            text: "Notifications · " + panel.settledCount
            numeric: true
            opacity: panel.settledCount > 0 ? 1 : 0

            Behavior on opacity {
                Crossfade {}
            }

            PillButton {
                id: clearButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: clearButton.label.implicitHeight + 2 * Theme.textButtonPaddingVertical
                text: "Clear all"
                accessibleName: "Clear all notifications"
                tone: "accent"
                fontSize: Theme.secondaryFontSize
                horizontalPadding: Theme.textButtonPadding
                baseColor: "transparent"
                hoverColor: Colors.subtleFill
                enabled: !panel.clearing
                onActivated: panel.clearAll()
            }
        }

        ListView {
            id: list

            x: Theme.panelPadding
            y: header.y + header.height
            width: parent.width - 2 * Theme.panelPadding
            height: Math.min(Theme.notificationListMaxHeight, contentHeight)
            clip: true
            spacing: Theme.notificationRowGap
            boundsBehavior: Flickable.StopAtBounds
            model: notificationModel

            delegate: NotificationRow {
                width: ListView.view.width
                leaving: panel.clearing || panel.leavingIds.includes(notificationId)
                expanded: panel.expandedId === notificationId
                onToggled: panel.toggleExpanded(notificationId)
                onExpansionExtraChanged: panel.noteExtra(notificationId, expansionExtra)
                onActionInvoked: identifier => panel.invokeAction(notificationId, identifier)
                onReplySent: text => panel.sendReply(notificationId, text)
                onDismissClicked: panel.dismiss(notificationId)
                // Clear all hands the whole list to the service at once.
                onGone: {
                    if (!panel.clearing)
                        Notifications.dismiss(notificationId);
                }
            }
        }

        ScrollHint {
            view: list
        }
    }
}
