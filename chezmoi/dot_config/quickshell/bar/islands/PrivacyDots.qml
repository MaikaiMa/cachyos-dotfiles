import QtQuick
import qs
import qs.services
import qs.components

// One steady dot per capture in use, from the left edge outward: microphone,
// camera, screen share. A dot that goes fades where it was while the dots
// beyond it close up. No input: the owner leaves it out of the mask.
Item {
    id: dots

    readonly property int count: [Privacy.micActive, Privacy.cameraActive, Privacy.shareActive].filter(Boolean).length

    implicitWidth: count > 0 ? count * Theme.privacyDotSize + (count - 1) * Theme.privacyDotGap : 0
    implicitHeight: Theme.privacyDotSize

    Accessible.role: Accessible.StaticText
    Accessible.name: [Privacy.micActive ? "Microphone in use: " + Privacy.micApps.join(", ") : "", Privacy.cameraActive ? "Camera in use: " + Privacy.cameraApps.join(", ") : "", Privacy.shareActive ? "Screen shared: " + Privacy.shareApps.join(", ") : ""].filter(text => text !== "").join("; ")

    Dot {
        shown: Privacy.micActive
        slot: 0
        color: Colors.privacyMic
    }

    Dot {
        shown: Privacy.cameraActive
        slot: Privacy.micActive ? 1 : 0
        color: Colors.privacyCamera
    }

    Dot {
        shown: Privacy.shareActive
        slot: (Privacy.micActive ? 1 : 0) + (Privacy.cameraActive ? 1 : 0)
        color: Colors.privacyShare
    }

    component Dot: Rectangle {
        id: dot

        property bool shown: false
        property int slot: 0

        width: Theme.privacyDotSize
        height: Theme.privacyDotSize
        radius: width / 2
        opacity: shown ? 1 : 0
        visible: opacity > 0

        // Only a shown dot follows its slot; a fading one stays where it was.
        Binding on x {
            when: dot.shown
            value: dot.slot * (Theme.privacyDotSize + Theme.privacyDotGap)
            restoreMode: Binding.RestoreNone
        }

        // A dot appearing from nothing takes its place at once.
        Behavior on x {
            enabled: dot.visible

            Crossfade {}
        }

        Behavior on opacity {
            Crossfade {}
        }
    }
}
