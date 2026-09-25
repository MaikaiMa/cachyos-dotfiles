import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PopoutComponent {
    id: dashboardPopout

    property var dashboard: null

    // DMS keeps this content loaded after the popout closes, so the cards that poll
    // need to know whether the popout is on screen.
    readonly property bool popoutVisible: parentPopout?.shouldBeVisible ?? false

    // DMS anchors plugin popouts under the clicked pill with its own gap; Niri starts
    // tiled windows 2 logical pixels below the bar, so the placement is corrected here.
    readonly property real niriWindowGap: 2

    property string expandedDetails: ""
    // Set by enableAndExpand() while waiting for a radio that was off to come on, so
    // the section can be expanded once it does instead of immediately, which would
    // briefly show the DMS panel's own "off" state.
    property string pendingDetails: ""

    readonly property real belowBarY: parentPopout ? parentPopout.barY + parentPopout.barHeight + niriWindowGap : 0

    // Sums the column's children by hand, counting the details section at its end
    // height: a Column only updates its implicitHeight in the next polish pass, so a
    // formula built on it wobbles on every frame of the section animation.
    readonly property real heightWithoutDetails: {
        let total = 0;
        let count = 0;
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            const childHeight = child === togglesSection ? togglesCard.height : child.height;
            if (!child.visible || childHeight <= 0)
                continue;
            total += childHeight;
            count++;
        }
        return total + spacing * Math.max(0, count - 1);
    }
    readonly property real settledHeight: heightWithoutDetails + connectionDetails.targetHeight

    readonly property real detailsPanelHeight: {
        const screenHeight = parentPopout?.screen?.height ?? 0;
        if (screenHeight <= 0)
            return 350;
        const available = screenHeight - belowBarY - heightWithoutDetails - Theme.spacingS * 2 - Theme.spacingM - Theme.spacingL;
        return Math.max(200, Math.min(350, available));
    }

    // The Wi-Fi password and polkit prompts need the keyboard, which this popout holds
    // exclusively while open, so the dashboard closes for them like the Control Center.
    readonly property bool systemPromptOpen: NetworkService.credentialsRequested || (PopoutService.polkitAuthModal?.visible ?? false)

    // Writing the trigger values back into DMS's own popout is deliberate: the popout
    // derives its position from them, and DMS resets them on every open.
    function placePopout() {
        const popout = parentPopout;
        if (!popout || !popout.screen)
            return;

        const centeredX = popout.screen.width / 2;

        if (popout.triggerWidth !== 0)
            popout.triggerWidth = 0;
        if (popout.triggerX !== centeredX)
            popout.triggerX = centeredX;
        if (popout.triggerY !== belowBarY)
            popout.triggerY = belowBarY;
    }

    function toggleDetails(section) {
        pendingDetails = "";
        expandedDetails = expandedDetails === section ? "" : section;
    }

    function enableAndExpand(section) {
        pendingDetails = section;
        if (section === "wifi")
            NetworkService.toggleWifiRadio();
        else if (section === "bluetooth")
            BluetoothService.setBluetoothEnabled(true);
    }

    function focusDashboard() {
        if (popoutVisible)
            dashboardPopout.forceActiveFocus();
    }

    function collapseDetailsInstantly() {
        connectionDetails.animated = false;
        expandedDetails = "";
        pendingDetails = "";
        connectionDetails.animated = true;
    }

    // PluginPopout binds its height to the animated implicitHeight, which makes the
    // popout's own resize animation chase the section frame by frame. Binding it to
    // the settled height lets both animations run side by side, as in the Control
    // Center. PluginPopout sets its binding right after parentPopout, hence callLater.
    function bindPopoutHeight() {
        if (parentPopout)
            parentPopout.contentHeight = Qt.binding(() => dashboardPopout.settledHeight + Theme.spacingS * 2);
    }

    onParentPopoutChanged: {
        placePopout();
        Qt.callLater(bindPopoutHeight);
    }

    // PluginPopout's container closes the whole popout on Escape, so the dashboard
    // takes the keyboard while a section is open to collapse that first; keys it
    // leaves unaccepted still reach the container.
    onExpandedDetailsChanged: focusDashboard()

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Escape || expandedDetails === "")
            return;
        expandedDetails = "";
        event.accepted = true;
    }

    onSystemPromptOpenChanged: {
        if (systemPromptOpen && popoutVisible && closePopout)
            closePopout();
    }

    headerText: I18n.trFor("dotfilesDashboard", "Dashboard")
    showCloseButton: true
    spacing: Theme.spacingM

    headerActions: Component {
        Row {
            spacing: Theme.spacingXS

            DankActionButton {
                iconName: "home"
                tooltipText: I18n.trFor("dotfilesDashboard", "Open the dash")
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: dashboardPopout.dashboard?.openDashTab("overview")
            }

            DankActionButton {
                iconName: "notifications"
                tooltipText: I18n.trFor("dotfilesDashboard", "Open notifications")
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: dashboardPopout.dashboard?.openNotificationCenter(dashboardPopout.parentPopout)
            }

            DankActionButton {
                iconName: "settings"
                tooltipText: I18n.trFor("dotfilesDashboard", "Open settings")
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: dashboardPopout.dashboard?.openShellSettings()
            }
        }
    }

    Item {
        id: togglesSection

        width: parent.width
        height: togglesCard.height + connectionDetails.height

        TogglesCard {
            id: togglesCard

            width: parent.width
            dashboard: dashboardPopout.dashboard
            popoutVisible: dashboardPopout.popoutVisible
            expandedDetails: dashboardPopout.expandedDetails
            onDetailsRequested: section => dashboardPopout.toggleDetails(section)
            onEnableAndExpandRequested: section => dashboardPopout.enableAndExpand(section)
        }

        ConnectionDetails {
            id: connectionDetails

            y: togglesCard.height
            width: parent.width
            section: dashboardPopout.expandedDetails
            panelHeight: dashboardPopout.detailsPanelHeight
            overlayParent: dashboardPopout.parent
        }
    }

    MediaCard {
        width: parent.width
        popout: dashboardPopout
        popoutVisible: dashboardPopout.popoutVisible
    }

    DisplayAudioCard {
        width: parent.width
    }

    PowerCard {
        width: parent.width
    }

    StatsCard {
        width: parent.width
        popout: dashboardPopout
        popoutVisible: dashboardPopout.popoutVisible
    }

    Connections {
        target: NetworkService

        function onWifiEnabledChanged() {
            if (NetworkService.wifiEnabled) {
                if (dashboardPopout.pendingDetails === "wifi") {
                    dashboardPopout.expandedDetails = "wifi";
                    dashboardPopout.pendingDetails = "";
                }
            } else if (dashboardPopout.expandedDetails === "wifi") {
                dashboardPopout.expandedDetails = "";
            }
        }
    }

    Connections {
        target: BluetoothService

        function onEnabledChanged() {
            if (BluetoothService.enabled) {
                if (dashboardPopout.pendingDetails === "bluetooth") {
                    dashboardPopout.expandedDetails = "bluetooth";
                    dashboardPopout.pendingDetails = "";
                }
            } else if (dashboardPopout.expandedDetails === "bluetooth") {
                dashboardPopout.expandedDetails = "";
            }
        }
    }

    Connections {
        target: dashboardPopout.parentPopout

        function onTriggerXChanged() {
            dashboardPopout.placePopout();
        }

        function onTriggerYChanged() {
            dashboardPopout.placePopout();
        }

        function onTriggerWidthChanged() {
            dashboardPopout.placePopout();
        }

        function onShouldBeVisibleChanged() {
            dashboardPopout.placePopout();
        }

        function onPopoutClosed() {
            dashboardPopout.collapseDetailsInstantly();
        }
    }
}
