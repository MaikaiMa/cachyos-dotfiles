import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: card

    property string title: ""
    property alias spacing: body.spacing
    default property alias content: body.data

    implicitHeight: body.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: 1

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        StyledText {
            width: parent.width
            text: card.title
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.surfaceText
            visible: card.title.length > 0
        }
    }
}
