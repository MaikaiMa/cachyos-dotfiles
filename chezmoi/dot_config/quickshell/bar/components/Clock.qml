import QtQuick
import Quickshell

Label {
    property string format: "HH:mm"
    // Optional date => string, for text a Qt format string cannot express.
    property var formatter: null

    numeric: true
    text: formatter ? formatter(clock.date) : Qt.formatDateTime(clock.date, format)

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
