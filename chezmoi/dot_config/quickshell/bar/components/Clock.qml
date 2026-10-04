import QtQuick
import Quickshell
import ".."

Text {
    property string format: "HH:mm"
    // Optional date => string, for text a Qt format string cannot express.
    property var formatter: null

    color: Colors.foreground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Theme.fontWeight
    font.features: ({
            tnum: 1
        })
    text: formatter ? formatter(clock.date) : Qt.formatDateTime(clock.date, format)

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
