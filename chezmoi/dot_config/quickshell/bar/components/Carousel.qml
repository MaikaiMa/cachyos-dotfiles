import QtQuick
import ".."

// A sideways strip of cards for the Theme and Wallpaper panels. The wheel (either
// axis, notches and touchpad pixels), a drag and a flick move only the strip;
// Left and Right move the selection and the strip glides to centre it, Enter
// and a click activate. With adoptOnSettle the card nearest the centre becomes
// the selection once a scroll of the user's comes to rest.
Item {
    id: carousel

    property alias model: strip.model
    property alias delegate: strip.delegate
    property alias count: strip.count
    property int selectedIndex: -1
    property bool adoptOnSettle: false
    property real edgeMargin: Theme.panelPadding
    property string label: ""

    signal activated(int index)

    readonly property alias strip: strip

    activeFocusOnTab: true

    Accessible.role: Accessible.List
    Accessible.name: label

    // The panel opens on the given card, already centred.
    function open(index: int) {
        glide.stop();
        selectedIndex = Math.max(-1, Math.min(count - 1, index));
        reveal(selectedIndex, false);
    }

    function select(index: int) {
        if (count === 0)
            return;
        selectedIndex = Math.max(0, Math.min(count - 1, index));
        reveal(selectedIndex, true);
    }

    function minX(): real {
        return strip.originX - strip.leftMargin;
    }

    function maxX(): real {
        return Math.max(minX(), strip.originX + strip.contentWidth + strip.rightMargin - strip.width);
    }

    // positionViewAtIndex knows the delegate sizes and the bounds; it is used to
    // find the target, and the glide runs from where the strip was.
    function reveal(index: int, animate: bool) {
        if (index < 0 || index >= count)
            return;
        const from = strip.contentX;
        glide.stop();
        strip.positionViewAtIndex(index, ListView.Center);
        const to = strip.contentX;
        if (!animate || to === from)
            return;
        strip.contentX = from;
        glideTo(to);
    }

    function glideTo(x: real) {
        glide.stop();
        glide.to = Math.max(minX(), Math.min(maxX(), x));
        glide.start();
    }

    function nearestToCentre(): int {
        const y = strip.height / 2;
        const centre = strip.contentX + strip.width / 2;
        for (const offset of [0, -strip.spacing, strip.spacing]) {
            const index = strip.indexAt(centre + offset, y);
            if (index >= 0)
                return index;
        }
        return selectedIndex;
    }

    function settle() {
        if (adoptOnSettle && count > 0)
            selectedIndex = nearestToCentre();
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))
            return;
        if (event.key === Qt.Key_Left)
            select(selectedIndex - 1);
        else if (event.key === Qt.Key_Right)
            select(selectedIndex + 1);
        else if (event.key === Qt.Key_Home)
            select(0);
        else if (event.key === Qt.Key_End)
            select(count - 1);
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && selectedIndex >= 0)
            activated(selectedIndex);
        else
            return;
        event.accepted = true;
    }

    ListView {
        id: strip

        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Theme.carouselGap
        leftMargin: carousel.edgeMargin
        rightMargin: carousel.edgeMargin
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Theme.carouselCacheBuffer
        onMovementEnded: carousel.settle()
        onCountChanged: {
            if (carousel.selectedIndex >= 0)
                carousel.reveal(carousel.selectedIndex, false);
        }
    }

    MorphAnimation {
        id: glide

        target: strip
        property: "contentX"
    }

    // Wheel only: presses go through to the strip and its cards.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const pixels = Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y) ? wheel.pixelDelta.x : wheel.pixelDelta.y;
            const angle = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
            if (pixels !== 0) {
                glide.stop();
                strip.contentX = Math.max(carousel.minX(), Math.min(carousel.maxX(), strip.contentX - pixels));
            } else if (angle !== 0) {
                const base = glide.running ? glide.to : strip.contentX;
                carousel.glideTo(base - angle / 120 * Theme.carouselWheelStep);
            } else {
                return;
            }
            settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer

        interval: Motion.scrollSettleDelay + (glide.running ? Motion.growDuration : 0)
        onTriggered: carousel.settle()
    }
}
