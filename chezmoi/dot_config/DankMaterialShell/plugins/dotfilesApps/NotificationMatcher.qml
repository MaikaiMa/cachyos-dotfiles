import QtQuick
import qs.Services

QtObject {
    id: matcher

    readonly property var notifiedKeys: {
        const keys = new Set();
        const groups = NotificationService.groupedNotifications || [];
        for (const group of groups) {
            if (!group)
                continue;
            collectKeys(keys, group.key);
            collectKeys(keys, group.appName);
            collectKeys(keys, group.latestNotification?.desktopEntry);
        }
        return keys;
    }

    function collectKeys(target, value) {
        for (const key of keysFor(value))
            target.add(key);
    }

    function keysFor(value) {
        if (!value)
            return [];

        let name = value.toString().toLowerCase().trim();
        if (name.endsWith(".desktop"))
            name = name.slice(0, -8);

        const full = name.replace(/[^a-z0-9]/g, "");
        const tail = name.slice(name.lastIndexOf(".") + 1).replace(/[^a-z0-9]/g, "");

        const keys = [];
        if (full)
            keys.push(full);
        if (tail && tail !== full)
            keys.push(tail);
        return keys;
    }

    function matchesApp(appId, appName) {
        const keys = notifiedKeys;
        if (keys.size === 0)
            return false;

        for (const key of keysFor(appId)) {
            if (keys.has(key))
                return true;
        }
        for (const key of keysFor(appName)) {
            if (keys.has(key))
                return true;
        }
        return false;
    }
}
