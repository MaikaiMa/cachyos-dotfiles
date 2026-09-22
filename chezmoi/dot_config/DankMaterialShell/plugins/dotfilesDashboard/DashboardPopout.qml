import QtQuick
import qs.Common
import qs.Modules.Plugins
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

    // Writing the trigger values back into DMS's own popout is deliberate: the popout
    // derives its position from them, and DMS resets them on every open.
    function placePopout() {
        const popout = parentPopout;
        if (!popout || !popout.screen)
            return;

        const centeredX = popout.screen.width / 2;
        const belowBarY = popout.barY + popout.barHeight + niriWindowGap;

        if (popout.triggerWidth !== 0)
            popout.triggerWidth = 0;
        if (popout.triggerX !== centeredX)
            popout.triggerX = centeredX;
        if (popout.triggerY !== belowBarY)
            popout.triggerY = belowBarY;
    }

    onParentPopoutChanged: placePopout()

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

    TogglesCard {
        width: parent.width
        dashboard: dashboardPopout.dashboard
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
    }
}
