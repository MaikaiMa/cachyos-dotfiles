import QtQuick
import ".."

// Home: hours over minutes, the Dutch date under them, centred in the tile.
Rectangle {
    id: tile

    radius: Theme.tileRadius
    color: Colors.surfaceContainerHigh

    // "zo 04 okt": Qt's Dutch short month carries a full stop ("okt."), the design does not.
    function dutchDate(date: date): string {
        const locale = Qt.locale("nl_NL");
        const day = locale.dayName(date.getDay(), Locale.ShortFormat).replace(/\.$/, "");
        const month = locale.monthName(date.getMonth(), Locale.ShortFormat).replace(/\.$/, "");
        return day + " " + Qt.formatDate(date, "dd") + " " + month;
    }

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
            formatter: date => tile.dutchDate(date)
            color: Colors.foregroundVariant
            font.pixelSize: Theme.homeDetailFontSize
        }
    }
}
