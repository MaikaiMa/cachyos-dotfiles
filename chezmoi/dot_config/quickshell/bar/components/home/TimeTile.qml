import QtQuick
import qs
import qs.services
import qs.components

// Home: hours over minutes, the Dutch date under them, centred in the tile.
Surface {
    id: tile

    Column {
        anchors.centerIn: parent
        spacing: Theme.homeSectionGap

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            formatter: date => Qt.formatTime(date, "HH") + "\n" + Qt.formatTime(date, "mm")
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.homeTimeFontSize
            // About line-height 1, as in the prototype; Inter's own line spacing is 1.21.
            lineHeight: 0.84
        }

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            // "zo 04 okt"
            formatter: date => Time.shortDay(date, false) + " " + Qt.formatDate(date, "dd") + " " + Time.shortMonth(date)
            color: Colors.foregroundVariant
            font.pixelSize: Theme.homeDetailFontSize
        }
    }
}
