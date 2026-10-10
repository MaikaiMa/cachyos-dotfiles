import QtQuick
import Quickshell
import qs.services
import qs.windows

ShellRoot {
    // The IPC targets; singletons load lazily, so this one is made here.
    BarIpc {}

    Variants {
        model: Quickshell.screens

        // Three surfaces per screen. Qt Quick presents a whole surface on every
        // frame, so whatever animates continuously lives in a small surface of
        // its own: the wave in a strip on the Bottom layer, the orb in a box
        // left of the centre island. The tall bar window then presents frames
        // only when something in it changes.
        Scope {
            id: screenScope

            required property ShellScreen modelData

            WaveSurface {
                shellScreen: screenScope.modelData
            }

            // Maps only after the bar window has: Niri stacks the surfaces of a
            // layer in mapping order, and the orb must lie over the music bar.
            OrbSurface {
                id: orbSurface

                shellScreen: screenScope.modelData
                centre: bar.centre
                barPresented: bar.presented
            }

            BarWindow {
                id: bar

                shellScreen: screenScope.modelData
                orbHovered: orbSurface.orbHovered
            }
        }
    }
}
