import QtQuick
import qs
import qs.components

// The music bar's cross-fade: on opening, the content comes in after the
// island has grown into the bar; on closing it fades at once.
SequentialAnimation {
    id: fade

    property bool opening: false

    PauseAnimation {
        duration: fade.opening ? Motion.musicContentDelay : 0
    }
    Crossfade {}
}
