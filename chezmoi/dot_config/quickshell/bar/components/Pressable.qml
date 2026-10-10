import QtQuick

// Anything that acts on a click, Space, Return or Enter: a hit area with the
// pointing hand, Tab focus and the accessible press action. With
// secondaryEnabled a right click or the Menu key emits secondaryActivated.
// Keys with Alt, Ctrl or Meta pass on to the window's shortcuts; an owner
// adds keys with the specific handlers (Keys.onLeftPressed), which run first.
// The content and the FocusRing are the owner's children.
Item {
    id: pressable

    property bool focusable: true
    property string accessibleName: ""
    property bool secondaryEnabled: false
    // The hit area from the top; a row that expands keeps it on its header.
    property real pointerHeight: height

    readonly property bool hovered: pointer.containsMouse
    readonly property bool pressed: pointer.pressed

    signal activated
    signal secondaryActivated

    activeFocusOnTab: focusable

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: pressable.activated()

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))
            return;
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            pressable.activated();
        } else if (pressable.secondaryEnabled && event.key === Qt.Key_Menu) {
            event.accepted = true;
            pressable.secondaryActivated();
        }
    }

    MouseArea {
        id: pointer

        width: parent.width
        height: pressable.pointerHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: pressable.secondaryEnabled ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                pressable.secondaryActivated();
            else
                pressable.activated();
        }
    }
}
