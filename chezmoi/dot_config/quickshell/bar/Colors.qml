pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Fallbacks are Material dark defaults, so the bar renders before DMS has themed anything.
    property var scheme: ({})
    readonly property bool dark: scheme.dark ?? true

    readonly property color primary: pick("primary", "#d0bcff")
    readonly property color onPrimary: pick("on_primary", "#381e72")
    readonly property color primaryContainer: pick("primary_container", "#4f378b")
    readonly property color surface: pick("surface", "#141218")
    readonly property color surfaceContainer: pick("surface_container", "#211f26")
    readonly property color surfaceContainerHigh: pick("surface_container_high", "#2b2930")
    readonly property color onSurface: pick("on_surface", "#e6e0e9")
    readonly property color onSurfaceVariant: pick("on_surface_variant", "#cac4d0")
    readonly property color outline: pick("outline", "#938f99")
    readonly property color error: pick("error", "#f2b8b5")
    readonly property color shadow: pick("shadow", "#000000")

    function pick(key: string, fallback: string): string {
        const value = scheme.colors ? scheme.colors[key] : undefined;
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback;
    }

    function parse(text: string) {
        try {
            const file = JSON.parse(text);
            const mode = file.mode === "light" ? "light" : "dark";
            const colors = file.colors ? file.colors[mode] : undefined;
            scheme = colors ? { dark: mode === "dark", colors: colors } : ({});
        } catch (error) {
            console.warn("Colors: cannot parse " + colorsFile.path + ": " + error);
            scheme = ({});
        }
    }

    FileView {
        id: colorsFile

        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/DankMaterialShell/dms-colors.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
        // The watch needs an existing file; DMS writes it only after its first matugen run.
        onLoadFailed: retry.restart()
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: colorsFile.reload()
    }
}
