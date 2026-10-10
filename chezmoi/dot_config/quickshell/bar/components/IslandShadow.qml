import QtQuick
import QtQuick.Effects
import ".."

// The islands' drop shadow, as a layer effect: the islands, and the blobs
// that break out of the right one.
MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.alpha(Colors.shadow, Theme.shadowOpacity)
    shadowVerticalOffset: Theme.shadowOffsetY
    blurMax: Theme.shadowBlur
    shadowBlur: 1
}
