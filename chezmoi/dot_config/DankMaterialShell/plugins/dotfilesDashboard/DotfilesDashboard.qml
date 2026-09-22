import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    // A PluginComponent subclass cannot reach the pill's visual content, which is what
    // DMS itself measures, so the notification centre reuses the placement
    // DashboardPopout already forced onto the dashboard popout.
    function openNotificationCenter(popout) {
        if (!popout?.screen)
            return;

        const screen = popout.screen;
        const x = popout.triggerX;
        const y = popout.triggerY;
        const width = popout.triggerWidth;
        closePopout();
        PopoutService.toggleNotificationCenter(x, y, width, section, screen);
    }

    function openDashTab(tab) {
        closePopout();
        PopoutService.toggleDankDash(tab);
    }

    function openShellSettings() {
        closePopout();
        PopoutService.focusOrToggleSettings();
    }

    popoutWidth: 700

    horizontalBarPill: Component {
        DashboardBarButton {
            iconSize: root.iconSize
            textSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
        }
    }

    verticalBarPill: Component {
        DashboardBarButton {
            iconSize: root.iconSize
            vertical: true
        }
    }

    popoutContent: Component {
        DashboardPopout {
            dashboard: root
        }
    }
}
