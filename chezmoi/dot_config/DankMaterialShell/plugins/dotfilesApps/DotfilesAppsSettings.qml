import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    pluginId: "dotfilesApps"

    ToggleSetting {
        settingKey: "showPinnedApps"
        label: I18n.trFor("dotfilesApps", "Show pinned apps")
        description: I18n.trFor("dotfilesApps", "Also show the apps pinned to the dock, even when they are not running")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "notificationBadgeEnabled"
        label: I18n.trFor("dotfilesApps", "Notification badge")
        description: I18n.trFor("dotfilesApps", "Show a red dot when the notification centre holds a notification from the app")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "dismissOnFocus"
        label: I18n.trFor("dotfilesApps", "Clear notifications on focus")
        description: I18n.trFor("dotfilesApps", "Dismiss an app's notifications to the history after it stays focused for 1.5 seconds")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "currentWorkspaceOnly"
        label: I18n.trFor("dotfilesApps", "Current workspace only")
        description: I18n.trFor("dotfilesApps", "Only show windows on the active workspace")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "currentMonitorOnly"
        label: I18n.trFor("dotfilesApps", "Current monitor only")
        description: I18n.trFor("dotfilesApps", "Only show windows on the monitor this bar belongs to")
        defaultValue: false
    }
}
