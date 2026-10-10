import QtQuick
import qs.services

// Counts the frames the window of `item` presents into Frames.
Connections {
    required property Item item
    required property string screen
    required property string window

    target: item.Window.window

    function onFrameSwapped() {
        Frames.count(screen, window);
    }
}
