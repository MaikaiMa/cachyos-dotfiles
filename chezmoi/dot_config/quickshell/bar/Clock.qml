import QtQuick
import Quickshell

Text {
    color: Colors.onSurface
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: Qt.formatDateTime(clock.date, "HH:mm")

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
