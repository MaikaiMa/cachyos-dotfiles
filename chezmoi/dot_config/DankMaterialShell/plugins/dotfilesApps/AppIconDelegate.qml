import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: delegate

    property var entry: null
    property var notificationMatcher: null
    property bool notificationBadgeEnabled: true
    property bool focused: false
    property real iconPixelSize: 20
    property real cellWidth: 28
    property real cellHeight: 28
    property int desktopEntriesRevision: 0

    signal activated
    signal closeRequested
    signal contextMenuRequested(real anchorX, real anchorY)
    signal hoverStarted
    signal hoverEnded

    readonly property string appId: entry?.appId ?? ""
    readonly property var windows: entry?.windows ?? []
    readonly property int windowCount: windows.length
    readonly property bool hasWindows: windowCount > 0
    readonly property bool minimized: {
        if (!CompositorService.supportsMinimize || !hasWindows)
            return false;
        return windows.every(toplevel => toplevel?.minimized === true);
    }

    readonly property var desktopEntry: {
        delegate.desktopEntriesRevision;
        return appId ? DesktopEntries.heuristicLookup(appId) : null;
    }
    readonly property string appName: appId ? Paths.getAppName(appId, desktopEntry) : "Unknown"
    readonly property string windowTitle: hasWindows ? (windows[0]?.title || "") : ""

    readonly property bool hasNotification: {
        if (!notificationBadgeEnabled || !notificationMatcher)
            return false;
        return notificationMatcher.matchesApp(appId, appName);
    }

    readonly property string tooltipText: {
        if (!hasWindows)
            return appName;
        if (windowCount > 1)
            return appName + " (" + windowCount + " " + I18n.trFor("dotfilesApps", "windows") + ")";
        return windowTitle ? appName + " • " + windowTitle : appName;
    }

    width: cellWidth
    height: cellHeight

    Rectangle {
        id: background

        anchors.fill: parent
        radius: Theme.cornerRadius
        color: {
            if (delegate.focused)
                return mouseArea.containsMouse ? Theme.primarySelected : Theme.withAlpha(Theme.primary, 0.45);
            if (mouseArea.containsMouse)
                return BlurService.hoverColor(Theme.widgetBaseHoverColor);
            return "transparent";
        }

        IconImage {
            id: appIcon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: delegate.iconPixelSize
            height: delegate.iconPixelSize
            source: {
                delegate.desktopEntriesRevision;
                return delegate.appId ? Paths.getAppIcon(delegate.appId, delegate.desktopEntry) : "";
            }
            smooth: true
            mipmap: true
            asynchronous: true
            visible: status === Image.Ready
            opacity: delegate.minimized ? 0.4 : (delegate.focused ? 1 : 0.6)
            layer.enabled: delegate.appId === "org.quickshell" || delegate.appId === "com.danklinux.dms"
            layer.smooth: true
            layer.mipmap: true
            layer.effect: MultiEffect {
                saturation: 0
                colorization: 1
                colorizationColor: Theme.primary
            }
        }

        DankIcon {
            anchors.horizontalCenter: appIcon.horizontalCenter
            anchors.verticalCenter: appIcon.verticalCenter
            size: delegate.iconPixelSize
            name: "sports_esports"
            color: Theme.widgetTextColor
            visible: !appIcon.visible && Paths.isSteamApp(delegate.appId)
            opacity: appIcon.opacity
        }

        StyledText {
            anchors.horizontalCenter: appIcon.horizontalCenter
            anchors.verticalCenter: appIcon.verticalCenter
            visible: !appIcon.visible && !Paths.isSteamApp(delegate.appId)
            text: delegate.appName ? delegate.appName.charAt(0).toUpperCase() : "?"
            font.pixelSize: 10
            color: Theme.widgetTextColor
            opacity: appIcon.opacity
        }


        StatusDot {
            id: notificationDot

            anchors.horizontalCenter: appIcon.right
            anchors.verticalCenter: appIcon.top
            diameter: 6
            color: Theme.error
            visible: delegate.hasNotification
            z: 10
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                delegate.activated();
            } else if (mouse.button === Qt.RightButton) {
                const anchor = delegate.mapToItem(null, delegate.width / 2, delegate.height / 2);
                delegate.contextMenuRequested(anchor.x, anchor.y);
            } else if (mouse.button === Qt.MiddleButton) {
                delegate.closeRequested();
            }
        }
        onEntered: delegate.hoverStarted()
        onExited: delegate.hoverEnded()
    }

    Component.onDestruction: delegate.hoverEnded()
}
