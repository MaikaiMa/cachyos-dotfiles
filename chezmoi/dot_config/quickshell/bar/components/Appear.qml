import QtQuick

// A container that cross-fades in and out with shown; while hidden it is not
// drawn and takes no input.
Item {
    property bool shown: false

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        Crossfade {}
    }
}
