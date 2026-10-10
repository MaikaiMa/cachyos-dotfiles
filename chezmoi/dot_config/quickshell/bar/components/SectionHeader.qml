import QtQuick
import qs

// A small glyph and a name over a group of rows. Children, such as a text
// button, sit on the header and anchor to its right edge themselves.
Item {
    id: header

    property string iconName: ""
    property string text: ""
    property bool numeric: false

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sectionHeaderSpacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: header.iconName
            size: Theme.smallIconSize
            color: Colors.foregroundVariant
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            secondary: true
            numeric: header.numeric
            text: header.text
        }
    }
}
