import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    pluginId: "dotfilesWorkspaces"

    ToggleSetting {
        settingKey: "notificationHighlightEnabled"
        label: I18n.trFor("dotfilesWorkspaces", "Notification highlight")
        description: I18n.trFor("dotfilesWorkspaces", "Colour a workspace red when the notification centre holds a notification from an app on it")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "overviewOnRightClick"
        label: I18n.trFor("dotfilesWorkspaces", "Overview on right click")
        description: I18n.trFor("dotfilesWorkspaces", "Toggle the niri overview when the widget is right clicked")
        defaultValue: true
    }
}
