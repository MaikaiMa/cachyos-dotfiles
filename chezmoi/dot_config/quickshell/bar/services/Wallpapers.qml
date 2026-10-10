pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The DMS wallpaper folder and the current wallpaper. DMS has no setting for the
// folder: its picker remembers the last one it browsed as wallpaperLastPath in
// its cache.json, which docs/pictures.md points at ~/Pictures/Wallpapers. The
// list is read only on refresh(), when the Wallpaper panel opens. Every IPC
// call tries DMS's global mode first; in its per-monitor mode `get` and `set`
// answer ERROR and `getFor` and `setFor` apply.
Singleton {
    id: root

    readonly property string fallbackFolder: Paths.home + "/Pictures/Wallpapers"
    readonly property int limit: 200

    property string folder: fallbackFolder
    // Absolute paths, sorted by name, at most `limit`.
    property var files: []
    property string current: ""
    property bool loading: false

    // After rerender(): the wallpaper was set again, or could not be.
    signal rerendered

    // The folder is known only once the cache has answered; that answer starts
    // the lister.
    function refresh(screen: string) {
        loading = true;
        cache.reload();
        readCurrent(screen);
    }

    // Only for a refresh; the cache's own first load at start lists nothing.
    function list() {
        if (loading)
            lister.refresh();
    }

    function readCurrent(screen: string) {
        if (getter.running)
            return;
        getter.screen = screen;
        getter.perMonitor = false;
        getter.run();
    }

    function fileName(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    // The file name without its extension.
    function displayName(path: string): string {
        const name = fileName(path);
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(0, dot) : name;
    }

    function urlFor(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // While a set runs only the newest choice waits, so the last click wins.
    function set(path: string, screen: string) {
        current = path;
        internal.pending = {
            path: path,
            screen: screen
        };
        if (!setter.running)
            internal.setNext();
    }

    // Sets the current wallpaper again, which makes DMS render the theme anew
    // (docs/dms.md, "Triggering a re-render"); asks DMS for it first.
    function rerender(screen: string) {
        internal.rerendering = true;
        readCurrent(screen);
    }

    QtObject {
        id: internal

        property var pending: null
        property bool rerendering: false

        function setNext() {
            setter.path = pending.path;
            setter.screen = pending.screen;
            setter.perMonitor = false;
            pending = null;
            setter.run();
        }

        function endRerender() {
            if (!rerendering)
                return;
            rerendering = false;
            root.rerendered();
        }
    }

    FileView {
        id: cache

        path: Paths.dmsCache + "/cache.json"
        printErrors: false
        onLoaded: {
            try {
                const last = JSON.parse(text()).wallpaperLastPath;
                root.folder = typeof last === "string" && last !== "" ? last : root.fallbackFolder;
            } catch (error) {
                root.folder = root.fallbackFolder;
            }
            root.list();
        }
        onLoadFailed: {
            root.folder = root.fallbackFolder;
            root.list();
        }
    }

    // The same filter as DMS's picker: one level, symlinks followed, image types only.
    CommandReader {
        id: lister

        name: "Wallpapers"
        command: ["sh", "-c", "find -L \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.jxl' -o -iname '*.avif' -o -iname '*.heif' -o -iname '*.exr' \\) 2>/dev/null | sort | head -n \"$2\"", "sh", root.folder, String(root.limit)]
        active: false
        onRead: text => {
            root.files = text.split("\n").filter(line => line !== "");
            root.loading = false;
        }
        onFailed: root.loading = false
    }

    Command {
        id: getter

        property string screen: ""
        property bool perMonitor: false

        command: perMonitor ? ["dms", "ipc", "call", "wallpaper", "getFor", screen] : ["dms", "ipc", "call", "wallpaper", "get"]
        onFinished: (code, output) => {
            const answer = output.trim();
            if (code !== 0 || answer.startsWith("ERROR")) {
                if (!getter.perMonitor && getter.screen !== "") {
                    getter.perMonitor = true;
                    getter.run();
                    return;
                }
                if (internal.rerendering)
                    console.warn("Wallpapers: no current wallpaper to set again: " + answer);
                internal.endRerender();
                return;
            }
            if (answer !== "")
                root.current = answer;
            if (internal.rerendering && root.current !== "")
                root.set(root.current, getter.screen);
            else
                internal.endRerender();
        }
    }

    Command {
        id: setter

        property string path: ""
        property string screen: ""
        property bool perMonitor: false

        command: perMonitor ? ["dms", "ipc", "call", "wallpaper", "setFor", screen, path] : ["dms", "ipc", "call", "wallpaper", "set", path]
        onFinished: (code, output) => {
            const refused = code !== 0 || output.startsWith("ERROR");
            if (refused && !setter.perMonitor && setter.screen !== "") {
                setter.perMonitor = true;
                setter.run();
                return;
            }
            if (refused)
                console.warn("Wallpapers: " + setter.command.join(" ") + ": " + output.trim());
            if (internal.pending !== null) {
                internal.setNext();
                return;
            }
            internal.endRerender();
            root.readCurrent(setter.screen);
        }
    }
}
