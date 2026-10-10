pragma ComponentBehavior: Bound

import QtQuick
import qs

// A row of the Wi-Fi, Bluetooth and Sound lists: an icon, the title with a
// subtitle or a live level bar, a lock when secured. Expanded, it shows a
// password field with Connect, or a line of buttons; an error adds a line in
// `errorText`. The panel owns which row is expanded and the errors, so it
// knows the settled height before the row grows. A right click or the Menu
// key is the row's context action, secondaryActivated.
Pressable {
    id: row

    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property bool secured: false
    // The connected network or device, tinted with the accent.
    property bool highlighted: false
    property bool expanded: false
    // "password" or "actions".
    property string mode: "actions"
    // [{ id, text, tone }]; the "accent" one is the filled main action.
    property var actions: []
    property string errorText: ""
    // 0..1 drawn as a thin bar under the name (the Sound panel's default input); -1 for none.
    property real level: -1

    signal clicked
    signal actionActivated(string id)
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

    Accessible.description: subtitle

    onActivated: row.clicked()

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
        color: row.hovered ? Qt.tint(row.baseColor, Qt.alpha(Colors.foreground, Theme.listRowHoverTint)) : row.baseColor

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
            text: row.subtitle
            secondary: true
            numeric: true
        }

        Item {
            visible: row.level >= 0
            width: parent.width
            height: Theme.levelBarGap + Theme.levelBarHeight

            FillTrack {
                y: Theme.levelBarGap
                width: parent.width
                height: Theme.levelBarHeight
                value: row.level
                trackColor: Qt.alpha(Colors.foreground, Theme.levelTrackOpacity)
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
                    text: modelData.text
                    tone: modelData.tone ?? "neutral"
                    filled: tone === "accent"
                    strong: true
                    baseColor: Colors.surfaceContainer
                    focusable: row.expanded
                    onActivated: row.actionActivated(modelData.id)
                }
            }
        }
    }

    Label {
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
