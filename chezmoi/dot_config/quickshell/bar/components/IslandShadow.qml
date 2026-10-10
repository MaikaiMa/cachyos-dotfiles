import QtQuick
import QtQuick.Effects
import qs

// The islands' drop shadow as a layer effect, for the blobs that break out of
// the right island; Island itself draws a RectangularShadow sibling.
MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.alpha(Colors.shadow, Theme.shadowOpacity)
    shadowVerticalOffset: Theme.shadowOffsetY
    blurMax: Theme.shadowBlur
    shadowBlur: 1
}
