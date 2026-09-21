import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    pluginId: "dotfilesApps"

    ToggleSetting {
        settingKey: "showPinnedApps"
        label: "Show pinned apps"
        description: "Also show the apps pinned to the dock, even when they are not running"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "notificationBadgeEnabled"
        label: "Notification badge"
        description: "Show a red dot when the notification centre holds a notification from the app"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "dismissOnFocus"
        label: "Clear notifications on focus"
        description: "Dismiss an app's notifications to the history after it stays focused for 1.5 seconds"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "currentWorkspaceOnly"
        label: "Current workspace only"
        description: "Only show windows on the active workspace"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "currentMonitorOnly"
        label: "Current monitor only"
        description: "Only show windows on the monitor this bar belongs to"
        defaultValue: false
    }
}
