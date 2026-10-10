import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The top-edge wave in a strip of its own on the Bottom layer: it animates
// continuously, so it must not make the bar window present frames. Mapped
// only while the wave shows; it takes no input.
PanelWindow {
    id: surface

    required property ShellScreen shellScreen

    screen: shellScreen
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.waveHeight
    visible: Settings.waveEnabled && Cava.waveOpacity > 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "dotfiles-bar-wave"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    TopWave {
        id: wave

        width: parent.width
    }

    FrameCounter {
        item: wave
        screen: surface.shellScreen.name
        window: "wave"
    }
}
