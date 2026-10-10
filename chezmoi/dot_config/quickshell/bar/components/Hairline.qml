import QtQuick
import qs

Rectangle {
    implicitWidth: Theme.hairlineWidth
    implicitHeight: Theme.hairlineHeight
    color: Qt.alpha(Colors.outline, Theme.hairlineOpacity)
}
