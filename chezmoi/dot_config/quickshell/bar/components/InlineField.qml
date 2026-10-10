import QtQuick
import qs

// A one-line text field with a button after it: the Wi-Fi password and the
// notification reply. Return or the button submits non-empty text, and the
// field clears itself. The owner styles the button through `button`.
Item {
    id: inline

    property string placeholder: ""
    property bool password: false
    property string buttonText: ""
    property real buttonWidth: submitButton.implicitWidth
    property bool focusable: true
    property string accessibleName: ""

    readonly property alias button: submitButton
    readonly property alias text: input.text

    signal submitted(string text)

    function clear() {
        input.text = "";
    }

    function takeFocus() {
        input.forceActiveFocus();
    }

    function submit() {
        if (input.text === "")
            return;
        const text = input.text;
        input.text = "";
        submitted(text);
    }

    implicitHeight: Theme.fieldHeight

    Rectangle {
        width: parent.width - submitButton.width - Theme.gap
        height: parent.height
        radius: height / 2
        color: Colors.surfaceContainer
        border.width: input.activeFocus ? Theme.focusRingWidth : 0
        border.color: Colors.primary

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Theme.fieldPadding
            anchors.rightMargin: Theme.fieldPadding
            verticalAlignment: TextInput.AlignVCenter
            echoMode: inline.password ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            clip: true
            activeFocusOnTab: inline.focusable
            color: Colors.foreground
            selectionColor: Colors.primary
            selectedTextColor: Colors.primaryForeground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize

            // Handled here: TextInput passes Return on, and the row around
            // the field would take it as a click.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                    inline.submit();
                }
            }

            Accessible.name: inline.accessibleName

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: inline.placeholder
                color: Colors.foregroundVariant
                font: input.font
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: mouse => {
                input.forceActiveFocus();
                mouse.accepted = false;
            }
        }
    }

    PillButton {
        id: submitButton

        anchors.right: parent.right
        width: inline.buttonWidth
        height: parent.height
        focusable: inline.focusable
        text: inline.buttonText
        baseColor: Colors.surfaceContainer
        onActivated: inline.submit()
    }
}
