import QtQuick
import ".."

// The keyboard focus ring around its parent; the owner binds visible to its
// activeFocus. Focus only arrives through Tab, so the ring never shows on a
// click. A parent that clips takes a negative inset, inside its edge.
Rectangle {
    property real inset: Theme.focusRingInset

    anchors.fill: parent
    anchors.margins: -inset
    radius: height / 2
    color: "transparent"
    border.width: Theme.focusRingWidth
    border.color: Colors.primary
}
