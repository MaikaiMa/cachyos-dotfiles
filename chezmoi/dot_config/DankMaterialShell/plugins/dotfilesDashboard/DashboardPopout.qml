import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PopoutComponent {
    id: dashboardPopout

    property var dashboard: null

    headerText: I18n.trFor("dotfilesDashboard", "Dashboard")
    showCloseButton: true
    spacing: Theme.spacingM

    headerActions: Component {
        Row {
            spacing: Theme.spacingXS

            DankActionButton {
                circular: false
                iconName: "home"
                tooltipText: I18n.trFor("dotfilesDashboard", "Open the dash")
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: dashboardPopout.dashboard?.openDashTab("overview")
            }

            DankActionButton {
                circular: false
                iconName: "notifications"
                tooltipText: I18n.trFor("dotfilesDashboard", "Open notifications")
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: dashboardPopout.dashboard?.openNotificationCenter()
            }

            DankActionButton {
                circular: false
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
    }

    DisplayAudioCard {
        width: parent.width
    }

    PowerCard {
        width: parent.width
    }

    StatsCard {
        width: parent.width
    }
}
