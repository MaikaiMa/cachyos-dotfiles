pragma ComponentBehavior: Bound

import QtQuick
import ".."

// A row of the Wi-Fi and Bluetooth lists: an icon, the name with a detail line,
// a lock when secured. Expanded, it shows a password field with Connect, or a
// line of buttons; an error adds a line in `error`. The panel owns which row is
// expanded and the errors, so it knows the settled height before the row grows.
Item {
    id: row

    property string iconName: ""
    property string title: ""
    property string detail: ""
    property bool secured: false
    // The connected network or device, tinted with the accent.
    property bool highlighted: false
    property bool expanded: false
    // "password" or "actions".
    property string mode: "actions"
    // [{ key, label, accent, danger }]
    property var actions: []
    property string errorText: ""

    signal clicked
    signal secondaryClicked
    signal actionTriggered(string key)
    signal passwordSubmitted(string password)

    readonly property real targetHeight: Theme.listRowHeight + (expanded ? Theme.listRowExpansion : 0) + (errorText !== "" ? Theme.listRowErrorHeight : 0)
    readonly property real textX: Theme.listRowPadding + Theme.toggleIconSize + Theme.listRowPadding
    readonly property color baseColor: highlighted ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.16)) : Colors.surfaceContainerHigh

    implicitHeight: targetHeight
    height: implicitHeight
    clip: true
    activeFocusOnTab: true

    Behavior on implicitHeight {
        id: heightBehavior

        IslandAnimation {
            shrinking: heightBehavior.targetValue < row.implicitHeight
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: detail
    Accessible.onPressAction: row.clicked()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            row.clicked();
        } else if (event.key === Qt.Key_Menu) {
            event.accepted = true;
            row.secondaryClicked();
        }
    }

    // The password field takes the keyboard as soon as it shows; collapsing with
    // the keyboard inside hands it back to the row, so Escape still reaches the
    // window.
    onExpandedChanged: {
        if (expanded)
            Qt.callLater(row.focusField);
        if (!expanded) {
            if (focusInside())
                row.forceActiveFocus();
            passwordField.text = "";
        }
    }

    // Later than the expansion itself: the mode may change in the same step.
    function focusField() {
        if (expanded && mode === "password")
            passwordField.forceActiveFocus();
    }

    function focusInside(): bool {
        for (let item = row.Window.activeFocusItem; item; item = item.parent) {
            if (item === expansion)
                return true;
        }
        return false;
    }

    function submit() {
        if (passwordField.text === "")
            return;
        const password = passwordField.text;
        passwordField.text = "";
        row.passwordSubmitted(password);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.listRowRadius
        color: headerPointer.containsMouse ? Qt.tint(row.baseColor, Qt.alpha(Colors.foreground, 0.05)) : row.baseColor

        Behavior on color {
            ColorAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.listRowRadius - 1
        color: "transparent"
        border.width: 2
        border.color: Colors.primary
        visible: row.activeFocus
    }

    MouseArea {
        id: headerPointer

        width: parent.width
        height: Theme.listRowHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                row.secondaryClicked();
            else
                row.clicked();
        }
    }

    Icon {
        x: Theme.listRowPadding
        y: (Theme.listRowHeight - height) / 2
        name: row.iconName
        size: Theme.toggleIconSize
        color: row.highlighted ? Colors.primary : Colors.foreground
        fill: row.highlighted ? 1 : 0
    }

    Column {
        x: row.textX
        y: (Theme.listRowHeight - height) / 2
        width: (lock.visible ? lock.x - Theme.gap : row.width - Theme.listRowPadding) - x

        Text {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            color: Colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Theme.fontWeight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: row.detail
            elide: Text.ElideRight
            color: Colors.foregroundVariant
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
            font.weight: Theme.fontWeight
            font.features: ({
                    tnum: 1
                })
        }
    }

    Icon {
        id: lock

        visible: row.secured
        x: row.width - Theme.listRowPadding - width
        y: (Theme.listRowHeight - height) / 2
        name: "lock"
        size: 14
        color: Colors.foregroundVariant
    }

    Item {
        id: expansion

        objectName: "expansion"
        x: row.textX
        y: Theme.listRowHeight - 2
        width: row.width - x - Theme.listRowPadding
        height: Theme.listRowFieldHeight
        // Visible at once on expanding, so the field can take the keyboard.
        visible: row.expanded || opacity > 0
        opacity: row.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Rectangle {
            id: field

            visible: row.mode === "password"
            width: parent.width - connectButton.width - Theme.gap
            height: parent.height
            radius: height / 2
            color: Colors.surfaceContainer
            border.width: passwordField.activeFocus ? 2 : 0
            border.color: Colors.primary

            TextInput {
                id: passwordField

                objectName: "passwordField"
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                clip: true
                activeFocusOnTab: row.expanded && row.mode === "password"
                color: Colors.foreground
                selectionColor: Colors.primary
                selectedTextColor: Colors.primaryForeground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                // Handled here: TextInput passes Return on, and the row would
                // take it as a click.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        event.accepted = true;
                        row.submit();
                    }
                }

                Accessible.name: "Password for " + row.title

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passwordField.text === ""
                    text: "Password"
                    color: Colors.foregroundVariant
                    font: passwordField.font
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: mouse => {
                    passwordField.forceActiveFocus();
                    mouse.accepted = false;
                }
            }
        }

        RowButton {
            id: connectButton

            visible: row.mode === "password"
            anchors.right: parent.right
            width: 88
            label: "Connect"
            accent: true
            focusable: row.expanded
            onActivated: row.submit()
        }

        Row {
            visible: row.mode === "actions"
            width: parent.width
            height: parent.height
            spacing: Theme.gap

            Repeater {
                model: row.actions

                RowButton {
                    required property var modelData

                    width: (expansion.width - (row.actions.length - 1) * Theme.gap) / row.actions.length
                    label: modelData.label
                    accent: modelData.accent ?? false
                    danger: modelData.danger ?? false
                    focusable: row.expanded
                    onActivated: row.actionTriggered(modelData.key)
                }
            }
        }
    }

    Text {
        objectName: "errorLine"
        x: row.textX
        y: Theme.listRowHeight + (row.expanded ? Theme.listRowExpansion : 0) - 4
        width: row.width - x - Theme.listRowPadding
        height: Theme.listRowErrorHeight
        verticalAlignment: Text.AlignTop
        visible: row.errorText !== ""
        text: row.errorText
        elide: Text.ElideRight
        color: Colors.error
        font.family: Theme.fontFamily
        font.pixelSize: Theme.secondaryFontSize
        font.weight: Theme.fontWeight
    }

    component RowButton: Item {
        id: button

        property string label: ""
        property bool accent: false
        property bool danger: false
        property bool focusable: false

        signal activated

        height: Theme.listRowFieldHeight
        activeFocusOnTab: focusable

        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: button.activated()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                button.activated();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: {
                const base = button.accent ? Colors.primary : Colors.surfaceContainer;
                return buttonPointer.containsMouse ? Qt.tint(base, Qt.alpha(button.accent ? Colors.primaryForeground : Colors.primary, button.accent ? 0.10 : 0.16)) : base;
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: height / 2
                color: "transparent"
                border.width: 2
                border.color: Colors.primary
                visible: button.activeFocus
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.accent ? Colors.primaryForeground : button.danger ? Colors.error : Colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
