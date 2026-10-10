import QtQuick
import ".."

// Crossfade for a colour: hover tints, selection and state colours.
ColorAnimation {
    duration: Motion.crossfadeDuration
    easing.type: Motion.crossfadeEasing
}
