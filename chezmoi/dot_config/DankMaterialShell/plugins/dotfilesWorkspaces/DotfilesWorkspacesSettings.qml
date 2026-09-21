import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    pluginId: "dotfilesWorkspaces"

    ToggleSetting {
        settingKey: "notificationHighlightEnabled"
        label: "Notification highlight"
        description: "Colour a workspace red when the notification centre holds a notification from an app on it"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "overviewOnRightClick"
        label: "Overview on right click"
        description: "Toggle the niri overview when the widget is right clicked"
        defaultValue: true
    }
}
