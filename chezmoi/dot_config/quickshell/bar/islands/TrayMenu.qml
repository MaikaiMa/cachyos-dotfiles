pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import ".."
import "../components"

// A tray item's menu, hanging from the right island's left padding. Submenus
// are flattened one level: the parent becomes a header over its indented
// entries; deeper levels are only marked. menuWidth is measured when the menu
// opens and when its entries arrive, not on every text change, so a status
// line updating inside the menu does not resize it.
Appear {
    id: trayMenu

    property QsMenuHandle menu: null
    property bool open: false
    property real menuWidth: Theme.trayMenuWidth
    readonly property real contentHeight: entries.implicitHeight

    // An entry was clicked and has run; the owner closes the menu.
    signal entryTriggered

    // DBusMenu marks mnemonics with one underscore and escapes a literal one as two.
    function menuLabel(text: string): string {
        return text.replace(/__|_/g, match => match === "__" ? "_" : "");
    }

    function measure() {
        let widest = 0;
        for (const group of entries.children) {
            for (const child of group.children) {
                const row = child as MenuRow;
                // Not row.visible: the menu is still transparent, so invisible, on open.
                if (row && row.listed)
                    widest = Math.max(widest, row.naturalWidth);
            }
        }
        menuWidth = Math.max(Theme.trayMenuWidth, Math.min(Theme.trayMenuMaxWidth, Math.ceil(widest)));
    }

    objectName: "trayMenu"
    width: menuWidth
    height: entries.implicitHeight
    shown: open

    onOpenChanged: {
        if (open)
            Qt.callLater(measure);
    }

    QsMenuOpener {
        id: opener

        menu: trayMenu.menu
    }

    Column {
        id: entries

        width: parent.width

        Repeater {
            model: opener.children
            onCountChanged: Qt.callLater(trayMenu.measure)

            Column {
                id: topEntry

                required property var modelData

                width: trayMenu.menuWidth

                MenuRow {
                    entry: topEntry.modelData
                    depth: 0
                }

                QsMenuOpener {
                    id: submenuOpener

                    menu: topEntry.modelData.hasChildren ? topEntry.modelData : null
                }

                Repeater {
                    model: submenuOpener.children
                    onCountChanged: Qt.callLater(trayMenu.measure)

                    MenuRow {
                        required property var modelData

                        entry: modelData
                        depth: 1
                    }
                }
            }
        }
    }

    // Some apps put multi-line status text in an entry: the row wraps it to
    // at most trayMenuMaxLines lines and grows with it, never under the row height.
    component MenuRow: Item {
        id: row

        // A QsMenuEntry, or any object with its text, enabled, isSeparator,
        // hasChildren and triggered().
        property var entry: null
        property int depth: 0

        readonly property bool present: !!entry
        readonly property bool separator: present && entry.isSeparator
        readonly property bool header: present && entry.hasChildren && depth === 0
        readonly property bool nested: present && entry.hasChildren && depth > 0
        readonly property bool clickable: present && entry.enabled && !separator && !entry.hasChildren
        readonly property string label: present && !separator ? trayMenu.menuLabel(entry.text ?? "") : ""
        readonly property real textX: Theme.paddingHorizontal + depth * Theme.trayMenuSubmenuIndent
        readonly property real trailing: Theme.paddingHorizontal + (nested ? Theme.trayChevronSize + Theme.indicatorCountGap : 0)
        // The unwrapped width of the widest line, for the menu width.
        readonly property real naturalWidth: textX + singleLine.implicitWidth + trailing
        readonly property bool listed: present && (separator || label !== "")

        objectName: "menuRow"
        width: trayMenu.menuWidth
        height: separator ? Theme.trayMenuSeparatorHeight : Math.max(Theme.trayMenuRowHeight, Math.ceil(labelText.implicitHeight) + Theme.trayMenuRowPadding)
        visible: listed

        Rectangle {
            visible: row.separator
            x: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * Theme.paddingHorizontal
            height: Theme.hairlineWidth
            color: Qt.alpha(Colors.outline, Theme.hairlineOpacity)
        }

        Rectangle {
            visible: !row.separator
            anchors.fill: parent
            radius: Theme.paddingHorizontal
            color: rowPointer.containsMouse && row.clickable ? Colors.hoverSurface : "transparent"

            Behavior on color {
                ColorCrossfade {}
            }
        }

        Label {
            id: labelText

            objectName: "menuLabel"
            visible: !row.separator
            x: row.textX
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - row.trailing
            text: row.label
            wrapMode: Text.Wrap
            maximumLineCount: Theme.trayMenuMaxLines
            color: row.header ? Colors.foregroundVariant : Colors.foreground
            opacity: row.present && !row.entry.enabled ? Theme.disabledOpacity : 1
        }

        Label {
            id: singleLine

            visible: false
            text: row.label
        }

        Icon {
            visible: row.nested
            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Theme.trayChevronSize
            color: Colors.foregroundVariant
        }

        MouseArea {
            id: rowPointer

            anchors.fill: parent
            hoverEnabled: true
            enabled: row.clickable
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                row.entry.triggered();
                trayMenu.entryTriggered();
            }
        }

        Accessible.role: row.separator ? Accessible.Separator : Accessible.MenuItem
        Accessible.name: row.label
    }
}
