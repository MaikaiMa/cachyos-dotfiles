import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    function triggerPosition() {
        const screen = parentScreen || Screen;
        const globalPos = mapToItem(null, 0, 0);
        const barPosition = axis?.edge === "left" ? 2 : (axis?.edge === "right" ? 3 : (axis?.edge === "top" ? 0 : 1));
        return SettingsData.getPopupTriggerPosition(globalPos, screen, barThickness, width, barSpacing, barPosition, barConfig);
    }

    function openNotificationCenter() {
        const screen = parentScreen || Screen;
        const pos = triggerPosition();
        closePopout();
        PopoutService.toggleNotificationCenter(pos.x, pos.y, pos.width, section, screen);
    }

    function openDashTab(tab) {
        closePopout();
        PopoutService.toggleDankDash(tab);
    }

    function openShellSettings() {
        closePopout();
        PopoutService.openSettings();
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
