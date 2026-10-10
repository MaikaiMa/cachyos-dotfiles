pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The DMS wallpaper folder and the current wallpaper. DMS has no setting for the
// folder: its picker remembers the last one it browsed as wallpaperLastPath in
// its cache.json, which docs/pictures.md points at ~/Pictures/Wallpapers. The
// list is read only on refresh(), when the Wallpaper panel opens.
Singleton {
    id: root

    readonly property string fallbackFolder: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property int limit: 200

    property string folder: fallbackFolder
    // Absolute paths, sorted by name, at most `limit`.
    property var files: []
    property string current: ""
    property bool loading: false

    // The folder is known only once the cache has answered; that answer starts
    // the lister.
    function refresh(screen: string) {
        loading = true;
        cache.reload();
        readCurrent(screen);
    }

    // Only for a refresh; the cache's own first load at start lists nothing.
    function list() {
        if (!loading)
            return;
        lister.running = false;
        lister.running = true;
    }

    function readCurrent(screen: string) {
        getter.screen = screen;
        getter.command = ["dms", "ipc", "call", "wallpaper", "get"];
        getter.running = true;
    }

    function fileName(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    // Global mode first; in DMS's per-monitor mode `set` refuses and `setFor` applies.
    function apply(path: string, screen: string) {
        current = path;
        const process = setterComponent.createObject(root, {
            path: path,
            screen: screen
        });
        process.running = true;
    }

    FileView {
        id: cache

        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/DankMaterialShell/cache.json"
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
    Process {
        id: lister

        command: ["sh", "-c", "find -L \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.jxl' -o -iname '*.avif' -o -iname '*.heif' -o -iname '*.exr' \\) 2>/dev/null | sort | head -n \"$2\"", "sh", root.folder, String(root.limit)]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(line => line !== "");
                root.loading = false;
            }
        }
    }

    Process {
        id: getter

        property string screen: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const answer = text.trim();
                if (answer.startsWith("ERROR")) {
                    if (getter.screen !== "" && getter.command[4] === "get") {
                        getter.command = ["dms", "ipc", "call", "wallpaper", "getFor", getter.screen];
                        Qt.callLater(() => getter.running = true);
                    }
                    return;
                }
                if (answer !== "")
                    root.current = answer;
            }
        }
    }

    Component {
        id: setterComponent

        Process {
            id: setter

            required property string path
            required property string screen
            property bool perMonitor: false

            command: perMonitor ? ["dms", "ipc", "call", "wallpaper", "setFor", screen, path] : ["dms", "ipc", "call", "wallpaper", "set", path]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (!setter.perMonitor && text.startsWith("ERROR") && setter.screen !== "") {
                        setter.perMonitor = true;
                        Qt.callLater(() => setter.running = true);
                        return;
                    }
                    if (text.startsWith("ERROR"))
                        console.warn("Wallpapers: " + text.trim());
                    root.readCurrent(setter.screen);
                    setter.destroy();
                }
            }
        }
    }
}
