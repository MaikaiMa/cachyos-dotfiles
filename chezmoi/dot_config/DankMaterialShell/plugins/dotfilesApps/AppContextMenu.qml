import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: menuWindow

    property var entry: null
    property string barEdge: "top"
    property real barThickness: 48
    property real barSpacing: 4
    property point anchorPos: Qt.point(0, 0)

    readonly property bool isVerticalBar: barEdge === "left" || barEdge === "right"
    readonly property var primaryWindow: {
        const windows = entry?.windows ?? [];
        if (windows.length === 0)
            return null;
        for (const toplevel of windows) {
            if (toplevel?.activated)
                return toplevel;
        }
        return windows[0];
    }
    readonly property bool isPinned: (SessionData.pinnedApps || []).some(appId => Paths.moddedAppId(appId) === entry?.appId)

    readonly property var menuItems: {
        const items = [];
        if (CompositorService.canMinimize(primaryWindow)) {
            items.push({
                "label": primaryWindow?.minimized ? I18n.tr("Restore") : I18n.tr("Minimize"),
                "action": "minimize"
            });
        }
        if (primaryWindow) {
            items.push({
                "label": I18n.tr("Close"),
                "action": "close"
            });
        }
        items.push({
            "label": isPinned ? I18n.tr("Unpin") : I18n.tr("Pin"),
            "action": "pin"
        });
        return items;
    }

    signal menuClosed

    function showAt(targetScreen, x, y) {
        screen = targetScreen;
        anchorPos = Qt.point(x, y);
        visible = true;
    }

    function closeMenu() {
        visible = false;
        menuWindow.menuClosed();
    }

    function runAction(action) {
        switch (action) {
        case "minimize":
            if (primaryWindow?.minimized)
                CompositorService.activateToplevel(primaryWindow);
            else if (primaryWindow)
                primaryWindow.minimized = true;
            break;
        case "close":
            if (primaryWindow)
                primaryWindow.close();
            break;
        case "pin":
            togglePinned();
            break;
        }
        closeMenu();
    }

    function togglePinned() {
        const appId = entry?.appId;
        if (!appId)
            return;

        const pinned = [...(SessionData.pinnedApps || [])];
        const index = pinned.findIndex(candidate => Paths.moddedAppId(candidate) === appId);
        if (index >= 0)
            pinned.splice(index, 1);
        else
            pinned.push(appId);
        SessionData.setPinnedApps(pinned);
    }

    visible: false
    color: "transparent"
    implicitWidth: 100
    implicitHeight: 40

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: menuWindow.closeMenu()
    }

    Rectangle {
        id: menuSurface

        x: {
            if (menuWindow.isVerticalBar) {
                const offset = menuWindow.barThickness + menuWindow.barSpacing + Theme.spacingXS;
                if (menuWindow.barEdge === "left")
                    return offset;
                return Math.max(10, menuWindow.width - offset - width);
            }
            return Math.max(10, Math.min(menuWindow.width - width - 10, menuWindow.anchorPos.x - width / 2));
        }
        y: {
            if (menuWindow.isVerticalBar)
                return Math.max(10, Math.min(menuWindow.height - height - 10, menuWindow.anchorPos.y - height / 2));
            const offset = menuWindow.barThickness + menuWindow.barSpacing + Theme.spacingXS;
            if (menuWindow.barEdge === "bottom")
                return menuWindow.height - offset - height;
            return offset;
        }
        width: 130
        height: menuColumn.height + Theme.spacingXS * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        border.width: BlurService.borderWidth
        border.color: BlurService.borderColor

        Column {
            id: menuColumn

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingXS
            width: parent.width - Theme.spacingXS * 2
            spacing: 1

            Repeater {
                model: menuWindow.menuItems

                delegate: Rectangle {
                    id: menuItem

                    required property var modelData

                    width: menuColumn.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: itemMouseArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: menuItem.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.widgetTextColor
                    }

                    MouseArea {
                        id: itemMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuWindow.runAction(menuItem.modelData.action)
                    }
                }
            }
        }
    }
}
