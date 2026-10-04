pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// StatusNotifier items; DMS owns the watcher, the bar is one more host.
Singleton {
    id: root

    readonly property var items: SystemTray.items.values
    readonly property int count: items.length

    function activate(item: SystemTrayItem) {
        if (item.onlyMenu)
            return;
        item.activate();
    }

    // Feed the handle to a QsMenuOpener to list the entries; null without a menu.
    function menuFor(item: SystemTrayItem): var {
        // The menu handle's C++ type is not in the qmltypes qmllint reads.
        return item.hasMenu ? item.menu : null; // qmllint disable unresolved-type
    }
}
