import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    readonly property real dpr: parentScreen ? CompositorService.getScreenScale(parentScreen) : 1
    // BasePill's padding is not exposed to plugins; recomputed so the fill covers the whole pill.
    readonly property real horizontalPadding: (barConfig?.removeWidgetPadding ?? false) ? 0 : Theme.snap((barConfig?.widgetPadding ?? 12) * (widgetThickness / 30), dpr)

    pillClickAction: (x, y, width, section, screen) => {
        // DMS 1.6 loads the app drawer lazily and toggleAppDrawer is a no-op until
        // the loader is active; the built-in launcher activates it before toggling.
        const loader = PopoutService.appDrawerLoader;
        if (loader)
            loader.active = true;
        PopoutService.toggleAppDrawer(x, y, width, section, screen);
    }

    pillRightClickAction: () => root.toggleOverview()

    function toggleOverview() {
        if (CompositorService.isNiri)
            NiriService.toggleOverview();
    }

    horizontalBarPill: pillComponent
    verticalBarPill: pillComponent

    Component {
        id: pillComponent

        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            Rectangle {
                id: fill
                anchors.fill: parent
                anchors.margins: -root.horizontalPadding
                radius: Theme.cornerRadius
                color: pressArea.containsMouse ? Theme.hoverTint(Theme.primary) : Theme.primary

                DankRipple {
                    id: ripple
                    rippleColor: Theme.primaryText
                    cornerRadius: fill.radius
                }

                // BasePill fires its click on press, which leaves no room for a long
                // press; the left button is taken here and right clicks still reach BasePill.
                MouseArea {
                    id: pressArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
                    onClicked: root.triggerPopout()
                    onPressAndHold: root.toggleOverview()
                }
            }

            DankIcon {
                anchors.centerIn: parent
                name: "apps"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.primaryText
            }
        }
    }
}
