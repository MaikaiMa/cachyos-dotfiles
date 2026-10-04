import QtQuick
import ".."
import "../components"
import "../services"

// Placeholder for the status island; a click on its background opens Settings.
Island {
    id: island

    required property string screenName

    implicitWidth: Theme.iconSize + 2 * Theme.paddingHorizontal
    implicitHeight: Theme.islandHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.centerIn: parent
        width: Theme.iconSize
        height: Theme.iconSize
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Colors.onSurface
    }

    TapHandler {
        onTapped: Shell.toggle("settings", island.screenName)
    }
}
