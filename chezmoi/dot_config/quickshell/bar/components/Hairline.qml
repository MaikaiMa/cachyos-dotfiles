import QtQuick
import ".."

Rectangle {
    implicitWidth: Theme.hairlineWidth
    implicitHeight: Theme.hairlineHeight
    color: Qt.alpha(Colors.outline, Theme.hairlineOpacity)
}
