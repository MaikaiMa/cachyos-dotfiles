pragma ComponentBehavior: Bound

import QtQuick
import ".."

// A row of the Wi-Fi, Bluetooth and Sound lists: an icon, the name with a
// detail line or a live level bar, a lock when secured. Expanded, it shows a
// password field with Connect, or a line of buttons; an error adds a line in
// `error`. The panel owns which row is expanded and the errors, so it knows
// the settled height before the row grows.
Pressable {
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
    // 0..1 drawn as a thin bar under the name (the Sound panel's default input); -1 for none.
    property real level: -1

    signal clicked
    signal secondaryClicked
    signal actionTriggered(string key)
    signal passwordSubmitted(string password)

    readonly property real targetHeight: Theme.listRowHeight + (expanded ? Theme.listRowExpansion : 0) + (errorText !== "" ? Theme.listRowErrorHeight : 0)
    readonly property real textX: Theme.listRowPadding + Theme.toggleIconSize + Theme.listRowPadding
    readonly property color baseColor: highlighted ? Colors.hoverSurface : Colors.surfaceContainerHigh

    implicitHeight: targetHeight
    height: implicitHeight
    clip: true
    pointerHeight: Theme.listRowHeight
    secondaryEnabled: true
    accessibleName: title

    Behavior on implicitHeight {
        id: heightBehavior

        MorphAnimation {
            shrinking: heightBehavior.targetValue < row.implicitHeight
        }
    }

    Accessible.description: detail

    onActivated: row.clicked()
    onSecondaryActivated: row.secondaryClicked()

    // The password field takes the keyboard as soon as it shows; collapsing with
    // the keyboard inside hands it back to the row, so Escape still reaches the
    // window.
    onExpandedChanged: {
        if (expanded)
            Qt.callLater(row.focusField);
        if (!expanded) {
            if (focusInside())
                row.forceActiveFocus();
            passwordField.clear();
        }
    }

    // Later than the expansion itself: the mode may change in the same step.
    function focusField() {
        if (expanded && mode === "password")
            passwordField.takeFocus();
    }

    function focusInside(): bool {
        for (let item = row.Window.activeFocusItem; item; item = item.parent) {
            if (item === expansion)
                return true;
        }
        return false;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.listRowRadius
        // A whole row under the pointer takes a quieter, neutral tint than a button.
        color: row.hovered ? Qt.tint(row.baseColor, Qt.alpha(Colors.foreground, 0.05)) : row.baseColor

        Behavior on color {
            ColorCrossfade {}
        }
    }

    FocusRing {
        inset: -1
        radius: Theme.listRowRadius - 1
        visible: row.activeFocus
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

        Label {
            width: parent.width
            text: row.title
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: row.detail
            secondary: true
            numeric: true
        }

        Item {
            objectName: "levelBar"
            visible: row.level >= 0
            width: parent.width
            height: Theme.levelBarGap + Theme.levelBarHeight

            FillTrack {
                y: Theme.levelBarGap
                width: parent.width
                height: Theme.levelBarHeight
                value: row.level
                trackColor: Qt.alpha(Colors.foreground, 0.1)
                duration: Motion.audioAttack
                easingType: Easing.Linear
            }
        }
    }

    Icon {
        id: lock

        visible: row.secured
        x: row.width - Theme.listRowPadding - width
        y: (Theme.listRowHeight - height) / 2
        name: "lock"
        size: Theme.smallIconSize
        color: Colors.foregroundVariant
    }

    Item {
        id: expansion

        objectName: "expansion"
        x: row.textX
        y: Theme.listRowHeight - Theme.listRowExpansionLift
        width: row.width - x - Theme.listRowPadding
        height: Theme.fieldHeight
        // Visible at once on expanding, so the field can take the keyboard.
        visible: row.expanded || opacity > 0
        opacity: row.expanded ? 1 : 0

        Behavior on opacity {
            Crossfade {}
        }

        InlineField {
            id: passwordField

            objectName: "passwordField"
            visible: row.mode === "password"
            width: parent.width
            height: parent.height
            password: true
            placeholder: "Password"
            accessibleName: "Password for " + row.title
            buttonText: "Connect"
            buttonWidth: Theme.listRowButtonWidth
            focusable: row.expanded
            button.filled: true
            button.strong: true
            onSubmitted: text => row.passwordSubmitted(text)
        }

        Row {
            visible: row.mode === "actions"
            width: parent.width
            height: parent.height
            spacing: Theme.gap

            Repeater {
                model: row.actions

                PillButton {
                    required property var modelData

                    width: (expansion.width - (row.actions.length - 1) * Theme.gap) / row.actions.length
                    height: Theme.fieldHeight
                    text: modelData.label
                    filled: modelData.accent ?? false
                    tone: modelData.danger ? "danger" : "neutral"
                    strong: true
                    baseColor: Colors.surfaceContainer
                    focusable: row.expanded
                    onActivated: row.actionTriggered(modelData.key)
                }
            }
        }
    }

    Label {
        objectName: "errorLine"
        x: row.textX
        y: Theme.listRowHeight + (row.expanded ? Theme.listRowExpansion : 0) - Theme.listRowErrorLift
        width: row.width - x - Theme.listRowPadding
        height: Theme.listRowErrorHeight
        verticalAlignment: Text.AlignTop
        visible: row.errorText !== ""
        text: row.errorText
        secondary: true
        color: Colors.error
    }
}
