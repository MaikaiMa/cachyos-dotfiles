import QtQuick
import "../services"

Label {
    property string format: "HH:mm"
    // Optional date => string, for text a Qt format string cannot express.
    property var formatter: null

    numeric: true
    text: formatter ? formatter(Time.date) : Qt.formatDateTime(Time.date, format)
}
