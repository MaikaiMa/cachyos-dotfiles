import QtQuick
import ".."
import "../services"

// Home: hours over minutes, the Dutch date under them, centred in the tile.
Rectangle {
    id: tile

    radius: Theme.tileRadius
    color: Colors.surfaceContainerHigh

    Column {
        anchors.centerIn: parent
        spacing: Theme.homeSectionGap

        Clock {
            objectName: "homeTime"
            anchors.horizontalCenter: parent.horizontalCenter
            formatter: date => Qt.formatTime(date, "HH") + "\n" + Qt.formatTime(date, "mm")
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.homeTimeFontSize
            // About line-height 1, as in the prototype; Inter's own line spacing is 1.21.
            lineHeight: 0.84
        }

        Clock {
            objectName: "homeDate"
            anchors.horizontalCenter: parent.horizontalCenter
            // "zo 04 okt"
            formatter: date => Time.shortDay(date, false) + " " + Qt.formatDate(date, "dd") + " " + Time.shortMonth(date)
            color: Colors.foregroundVariant
            font.pixelSize: Theme.homeDetailFontSize
        }
    }
}
