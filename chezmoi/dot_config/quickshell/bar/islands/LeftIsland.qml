import QtQuick
import ".."
import "../components"

// Placeholder for the workspaces and apps island.
Island {
    implicitWidth: label.implicitWidth + 2 * Theme.paddingHorizontal
    implicitHeight: Theme.islandHeight
    width: implicitWidth
    height: implicitHeight

    Text {
        id: label

        anchors.centerIn: parent
        text: "bar"
        color: Colors.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
    }
}
