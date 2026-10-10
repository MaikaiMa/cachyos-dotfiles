pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    // Fallbacks are Material dark defaults, so the bar renders before DMS has themed anything.
    // Property names must not start with "on" + a capital: QML reads them as signal
    // handlers and refuses the declaration, which also aborts the file loader below.
    readonly property bool dark: internal.scheme.dark ?? true
    // The mode DMS last applied, from the file; unlike `dark` no preview moves it.
    readonly property string mode: internal.file.mode === "light" ? "light" : "dark"

    // Each starts at its fallback and is then assigned by internal.apply(), not
    // bound, so it can glide to a new palette.
    property color primary: internal.keys.primary[1]
    property color primaryForeground: internal.keys.primaryForeground[1]
    property color primaryContainer: internal.keys.primaryContainer[1]
    property color secondary: internal.keys.secondary[1]
    property color tertiary: internal.keys.tertiary[1]
    property color surface: internal.keys.surface[1]
    property color surfaceContainer: internal.keys.surfaceContainer[1]
    property color surfaceContainerHigh: internal.keys.surfaceContainerHigh[1]
    property color foreground: internal.keys.foreground[1]
    property color foregroundVariant: internal.keys.foregroundVariant[1]
    property color outline: internal.keys.outline[1]
    property color error: internal.keys.error[1]
    property color shadow: internal.keys.shadow[1]

    // Interaction and state colours, derived from the palette with Theme's alphas.
    readonly property color hoverSurface: hovered(surfaceContainerHigh, false)
    // Hover on an item without a surface of its own.
    readonly property color hoverFill: Qt.alpha(primary, Theme.hoverTint)
    readonly property color selectedSurface: Qt.tint(surfaceContainerHigh, Qt.alpha(primary, Theme.selectedTint))
    readonly property color subtleFill: Qt.alpha(foreground, Theme.subtleFillOpacity)
    readonly property color errorSurface: Qt.tint(surfaceContainerHigh, Qt.alpha(error, Theme.errorSurfaceTint))
    readonly property color errorChip: Qt.alpha(error, Theme.errorChipTint)
    readonly property color dotOutline: Qt.alpha(foreground, Theme.dotOutlineOpacity)
    readonly property color scrollHint: Qt.alpha(foreground, Theme.scrollHintOpacity)
    readonly property color islandSurface: Qt.alpha(surfaceContainer, Theme.islandOpacity)

    // The privacy dots: fixed, not the palette, so they read the same on every scheme.
    readonly property color privacyMic: "#FF9F0A"
    readonly property color privacyCamera: "#30D158"
    readonly property color privacyShare: "#0A84FF"

    // A surface under the pointer: tinted with the accent, or on the accent
    // itself with the accent's foreground.
    function hovered(base: color, onAccent: bool): color {
        return onAccent ? Qt.tint(base, Qt.alpha(primaryForeground, Theme.hoverTintOnAccent)) : Qt.tint(base, Qt.alpha(primary, Theme.hoverTint));
    }

    // Shows the other mode's colours from the loaded file at once, so the glide
    // starts on the click while DMS renders; the next reload of the file wins.
    function preview(mode: string) {
        if (internal.file.colors && internal.file.colors[mode])
            internal.select(mode);
    }

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

    QtObject {
        id: internal

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
        // The shown mode's colours from the file, or nothing for the fallbacks.
        property var scheme: ({})
        // The last parsed file; it holds a colour set for both modes.
        property var file: ({})

        function apply() {
            for (const name in keys)
                root[name] = pick(keys[name][0], keys[name][1]);
        }

        onSchemeChanged: apply()

        function pick(key: string, fallback: string): string {
            const value = scheme.colors ? scheme.colors[key] : undefined;
            return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback;
        }

        // A read can catch DMS mid-write; a palette once loaded stays until the
        // next good read, the fallbacks are only for a file that never parsed.
        function parse(text: string) {
            let parsed;
            try {
                parsed = JSON.parse(text);
                if (!parsed || typeof parsed !== "object")
                    throw new Error("not an object");
            } catch (error) {
                console.warn("Colors: cannot parse " + colorsFile.path + ": " + error);
                if (!file.colors)
                    scheme = ({});
                return;
            }
            file = parsed;
            select(file.mode === "light" ? "light" : "dark");
        }

        function select(mode: string) {
            const colors = file.colors ? file.colors[mode] : undefined;
            scheme = colors ? {
                dark: mode === "dark",
                colors: colors
            } : ({});
        }
    }

    FileView {
        id: colorsFile

        path: Paths.dmsCache + "/dms-colors.json"
        watchChanges: true
        printErrors: false
        onLoaded: internal.parse(text())
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
