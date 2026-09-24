import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.local/bin"
    property bool keyboardDetached: false
    property bool keyboardShown: false

    function applyMode(mode) {
        const detached = mode === "tablet";
        if (root.keyboardDetached && !detached)
            Quickshell.execDetached([root.binDir + "/osk", "hide"]);
        root.keyboardDetached = detached;
        root.setVisibilityOverride(detached);
    }

    // The override collapses the pill to zero width, which the bar's Row skips, so no
    // gap or double spacing remains; visible alone keeps the pill's width reserved.
    // visible also stops the collapsed pill's edge MouseArea from taking clicks.
    Component.onCompleted: root.setVisibilityOverride(false)
    visible: effectiveVisible

    pillClickAction: () => Quickshell.execDetached([root.binDir + "/osk", "toggle"])

    horizontalBarPill: pillComponent
    verticalBarPill: pillComponent

    Component {
        id: pillComponent

        DankIcon {
            name: root.keyboardShown ? "keyboard_hide" : "keyboard"
            size: root.iconSize
            color: root.keyboardShown ? Theme.primary : Theme.widgetIconColor
        }
    }

    LineWatcher {
        command: [root.binDir + "/tablet-mode", "watch"]
        onLine: text => root.applyMode(text)
    }

    LineWatcher {
        command: [root.binDir + "/osk", "watch"]
        onLine: text => root.keyboardShown = text === "visible"
    }
}
