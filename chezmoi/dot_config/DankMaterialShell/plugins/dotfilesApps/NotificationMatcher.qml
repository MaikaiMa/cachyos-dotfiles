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
            for (const key of keysForGroup(group))
                keys.add(key);
        }
        return keys;
    }

    function keysForGroup(group) {
        const keys = [];
        for (const value of [group.key, group.appName, group.latestNotification?.desktopEntry]) {
            for (const key of keysFor(value))
                keys.push(key);
        }
        return keys;
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

    function keysForApp(appId, appName) {
        return new Set([...keysFor(appId), ...keysFor(appName)]);
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

    function groupKeysForApp(appId, appName) {
        const appKeys = keysForApp(appId, appName);
        if (appKeys.size === 0)
            return [];

        const matched = [];
        const groups = NotificationService.groupedNotifications || [];
        for (const group of groups) {
            if (!group)
                continue;
            if (keysForGroup(group).some(key => appKeys.has(key)))
                matched.push(group.key);
        }
        return matched;
    }
}
