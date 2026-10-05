pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Fallbacks are Material dark defaults, so the bar renders before DMS has themed anything.
    // Property names must not start with "on" + a capital: QML reads them as signal
    // handlers and refuses the declaration, which also aborts the file loader below.
    property var scheme: ({})
    readonly property bool dark: scheme.dark ?? true

    // Assigned by apply(), not bound, so each colour can glide to a new palette.
    // Keys are the Material names in dms-colors.json; values are the fallbacks.
    readonly property var keys: ({
            primary: ["primary", "#d0bcff"],
            primaryForeground: ["on_primary", "#381e72"],
            primaryContainer: ["primary_container", "#4f378b"],
            secondary: ["secondary", "#ccc2dc"],
            tertiary: ["tertiary", "#efb8c8"],
            surface: ["surface", "#141218"],
            surfaceContainer: ["surface_container", "#211f26"],
            surfaceContainerHigh: ["surface_container_high", "#2b2930"],
            foreground: ["on_surface", "#e6e0e9"],
            foregroundVariant: ["on_surface_variant", "#cac4d0"],
            outline: ["outline", "#938f99"],
            error: ["error", "#f2b8b5"],
            shadow: ["shadow", "#000000"]
        })

    property color primary: "#d0bcff"
    property color primaryForeground: "#381e72"
    property color primaryContainer: "#4f378b"
    property color secondary: "#ccc2dc"
    property color tertiary: "#efb8c8"
    property color surface: "#141218"
    property color surfaceContainer: "#211f26"
    property color surfaceContainerHigh: "#2b2930"
    property color foreground: "#e6e0e9"
    property color foregroundVariant: "#cac4d0"
    property color outline: "#938f99"
    property color error: "#f2b8b5"
    property color shadow: "#000000"

    Behavior on primary {
        PaletteAnimation {}
    }
    Behavior on primaryForeground {
        PaletteAnimation {}
    }
    Behavior on primaryContainer {
        PaletteAnimation {}
    }
    Behavior on secondary {
        PaletteAnimation {}
    }
    Behavior on tertiary {
        PaletteAnimation {}
    }
    Behavior on surface {
        PaletteAnimation {}
    }
    Behavior on surfaceContainer {
        PaletteAnimation {}
    }
    Behavior on surfaceContainerHigh {
        PaletteAnimation {}
    }
    Behavior on foreground {
        PaletteAnimation {}
    }
    Behavior on foregroundVariant {
        PaletteAnimation {}
    }
    Behavior on outline {
        PaletteAnimation {}
    }
    Behavior on error {
        PaletteAnimation {}
    }
    Behavior on shadow {
        PaletteAnimation {}
    }

    component PaletteAnimation: ColorAnimation {
        duration: Motion.paletteDuration
        easing.type: Easing.InOutQuad
    }

    function apply() {
        for (const name in keys)
            root[name] = pick(keys[name][0], keys[name][1]);
    }

    onSchemeChanged: apply()

    function pick(key: string, fallback: string): string {
        const value = scheme.colors ? scheme.colors[key] : undefined;
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback;
    }

    // The last parsed file; it holds a colour set for both modes.
    property var file: ({})

    function parse(text: string) {
        try {
            file = JSON.parse(text);
            select(file.mode === "light" ? "light" : "dark");
        } catch (error) {
            console.warn("Colors: cannot parse " + colorsFile.path + ": " + error);
            file = ({});
            scheme = ({});
        }
    }

    function select(mode: string) {
        const colors = file.colors ? file.colors[mode] : undefined;
        scheme = colors ? { dark: mode === "dark", colors: colors } : ({});
    }

    // Shows the other mode's colours from the loaded file at once, so the glide
    // starts on the click while DMS renders; the next reload of the file wins.
    function preview(mode: string) {
        if (file.colors && file.colors[mode])
            select(mode);
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
