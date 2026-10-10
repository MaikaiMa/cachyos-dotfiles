import QtQuick
import ".."

// A thin bar at the right edge of a list that is longer than its window.
// A sibling of the view, not its child: a Flickable's children scroll with
// the content.
Rectangle {
    required property Flickable view

    visible: view.visible && view.contentHeight > view.height
    x: view.x + view.width - width
    y: view.y + view.visibleArea.yPosition * view.height
    width: Theme.scrollHintWidth
    height: view.visibleArea.heightRatio * view.height
    radius: width / 2
    color: Colors.scrollHint
}
