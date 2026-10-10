import QtQuick
import QtQuick.Effects

// An image cropped to fill and rounded through a mask. Many images of one
// shape share one mask item (maskSource), so each does not render its own;
// without one the image uses its own at radius. fadeIn cross-fades it in
// once loaded.
Item {
    id: rounded

    property alias source: picture.source
    readonly property alias status: picture.status
    property real radius: 0
    property Item maskSource: ownMask
    property bool fadeIn: false

    Image {
        id: picture

        anchors.fill: parent
        sourceSize.width: 2 * rounded.width
        sourceSize.height: 2 * rounded.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Rectangle {
        id: ownMask

        anchors.fill: parent
        radius: rounded.radius
        visible: false
        layer.enabled: rounded.maskSource === ownMask
    }

    MultiEffect {
        anchors.fill: parent
        source: picture
        maskEnabled: true
        maskSource: rounded.maskSource
        // A soft ramp over the mask's alpha keeps the antialiased corner; the
        // default thresholds cut it at a single alpha.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        opacity: picture.status === Image.Ready ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: rounded.fadeIn

            Crossfade {}
        }
    }
}
