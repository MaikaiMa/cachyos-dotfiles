import QtQuick
import qs

// The fade of everything that appears, disappears or changes in place.
NumberAnimation {
    duration: Motion.crossfadeDuration
    easing.type: Motion.crossfadeEasing
}
