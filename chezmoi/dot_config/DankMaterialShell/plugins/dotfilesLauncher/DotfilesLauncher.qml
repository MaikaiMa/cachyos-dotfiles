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
        PopoutService.toggleAppDrawer(x, y, width, section, screen);
    }

    pillRightClickAction: () => {
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
                color: hoverArea.containsMouse ? Theme.hoverTint(Theme.primary) : Theme.primary

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
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
