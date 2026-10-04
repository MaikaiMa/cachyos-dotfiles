pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."
import "../components"
import "../services"

// Tray group, hairline and attention indicators. The owner fixes the right
// edge; the content is laid out from it, so the island grows leftward, and a
// tray menu grows it downward. A click on the background opens Settings.
Island {
    id: island

    required property string screenName

    property bool fanned: false
    property bool menuOpen: false
    // Kept until the island has shrunk back, so the entries do not vanish first.
    property var menuItem: null
    // Which Motion token the next size change uses: indicator, tray or menu.
    property string motion: "indicator"
    // The open menu's top-level entries; a plain property so it can be fed directly.
    property var menuEntries: menuOpener.children
    // Measured when the menu opens and when its entries arrive, not on every
    // text change, so a status line updating inside the menu does not resize it.
    property real menuWidth: Theme.trayMenuWidth

    readonly property int trayCount: Tray.count
    readonly property int stackCount: Math.min(trayCount, Theme.trayStack)
    readonly property int stackStep: Theme.trayDisc - Theme.trayOverlap
    readonly property int fanStep: Theme.trayDisc + Theme.trayGap
    readonly property int stackLeft: Math.max(0, stackCount - 1) * stackStep
    readonly property bool chevronShown: trayCount > 1
    readonly property int chevronWidth: Theme.trayChevronSize + 2 * Theme.gap
    readonly property real rowWidth: (fanned ? (trayCount - 1) * fanStep : stackLeft) + Theme.trayDisc
    readonly property real chevronOffset: rowWidth + Theme.trayGap
    readonly property real trayWidth: trayCount === 0 ? 0 : chevronShown ? chevronOffset + chevronWidth : rowWidth

    readonly property bool wifiShown: !Network.wifiEnabled || Network.weak
    // Left to right, the reverse of the design's reading order from the right edge.
    // Do not disturb has no indicator of its own: the bell crosses out and stays.
    readonly property bool notificationsShown: Notifications.count > 0 || Dms.doNotDisturb
    readonly property var shownFlags: [Dms.caffeine, Audio.muted, wifiShown, Updates.count > 0, notificationsShown]
    readonly property bool anyIndicator: shownFlags.includes(true)
    readonly property bool separatorShown: trayCount > 0 && anyIndicator
    readonly property int separatorWidth: 2 * Theme.gap + Theme.hairlineWidth
    readonly property real indicatorsWidth: caffeineIndicator.targetWidth + mutedIndicator.targetWidth + wifiIndicator.targetWidth + updatesIndicator.targetWidth + notificationsIndicator.targetWidth
    readonly property real contentWidth: trayWidth + (separatorShown ? separatorWidth : 0) + indicatorsWidth
    readonly property real collapsedWidth: contentWidth > 0 ? contentWidth + 2 * Theme.rightEndInset : 0

    // Offset of a disc's right edge from the tray group's right edge. The
    // rightmost stack disc never moves; extras wait under the stack while folded.
    function discOffset(index: int, open: bool): real {
        const slot = index < stackCount ? stackCount - 1 - index : index;
        if (open)
            return slot * fanStep;
        return index < stackCount ? slot * stackStep : stackLeft;
    }

    function gapBefore(index: int): bool {
        return shownFlags[index] && shownFlags.slice(0, index).includes(true);
    }

    function openMenu(item: var) {
        if (!Tray.menuFor(item))
            return;
        menuClear.stop();
        menuItem = item;
        menuOpen = true;
    }

    // DBusMenu marks mnemonics with one underscore and escapes a literal one as two.
    function menuLabel(text: string): string {
        return text.replace(/__|_/g, match => match === "__" ? "_" : "");
    }

    function measureMenu() {
        let widest = 0;
        for (const group of menuColumn.children) {
            for (const row of group.children) {
                // Not row.visible: the menu is still transparent, so invisible, on open.
                if (row.objectName === "menuRow" && row.listed)
                    widest = Math.max(widest, row.naturalWidth);
            }
        }
        menuWidth = Math.max(Theme.trayMenuWidth, Math.min(Theme.trayMenuMaxWidth, Math.ceil(widest)));
    }

    function closeMenu() {
        if (!menuOpen)
            return;
        menuOpen = false;
        menuClear.restart();
        if (!trayHover.hovered)
            fanned = false;
    }

    onFannedChanged: motion = "tray"
    onTrayCountChanged: motion = "tray"
    onMenuOpenChanged: {
        motion = "menu";
        if (menuOpen)
            Qt.callLater(measureMenu);
    }
    onShownFlagsChanged: motion = "indicator"

    targetWidth: menuOpen ? Math.max(collapsedWidth, menuWidth + 2 * Theme.paddingHorizontal) : collapsedWidth
    targetHeight: menuOpen ? Theme.islandHeight + menuColumn.implicitHeight + Theme.trayMenuInset : Theme.islandHeight
    expanded: menuOpen
    morphDuration: motion === "menu" ? -1 : motion === "tray" ? Motion.trayDuration : Motion.indicatorDuration
    morphCurve: motion === "menu" ? [] : motion === "tray" ? Motion.growCurve : Motion.indicatorCurve
    visible: width > 0

    Timer {
        id: menuClear

        interval: Motion.shrinkDuration
        onTriggered: island.menuItem = null
    }

    Connections {
        target: Shell

        function onPanelOpenChanged() {
            if (Shell.panelOpen)
                island.closeMenu();
        }
    }

    MouseArea {
        objectName: "background"
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            island.fanned = false;
            if (island.menuOpen)
                island.closeMenu();
            else
                Shell.toggle("settings", island.screenName);
        }
    }

    Row {
        objectName: "content"
        anchors.right: parent.right
        anchors.rightMargin: Theme.rightEndInset
        height: Theme.islandHeight

        Item {
            id: trayGroup

            objectName: "trayGroup"
            width: island.trayWidth
            height: Theme.islandHeight

            HoverHandler {
                id: trayHover

                onHoveredChanged: {
                    if (hovered)
                        island.fanned = true;
                    else if (!island.menuOpen)
                        island.fanned = false;
                }
            }

            // Everything in the group is placed from this point, the group's right edge.
            Item {
                anchors.right: parent.right
                height: parent.height

                Repeater {
                    model: Tray.items

                    Item {
                        id: disc

                        required property var modelData
                        required property int index

                        readonly property bool extra: index >= island.stackCount
                        property real offset: island.discOffset(index, island.fanned)

                        objectName: "trayDisc"
                        x: -offset - width
                        y: (Theme.islandHeight - height) / 2
                        z: extra ? 1 : index + 2
                        width: Theme.trayDisc
                        height: Theme.trayDisc
                        opacity: extra && !island.fanned ? 0 : 1
                        enabled: !extra || island.fanned

                        Behavior on offset {
                            TrayAnimation {}
                        }
                        Behavior on opacity {
                            TrayAnimation {}
                        }

                        // The ring sits outside the 24 px disc, in the island colour.
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 2
                            height: width
                            radius: width / 2
                            color: discPointer.containsMouse ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.16)) : Colors.surfaceContainerHigh
                            border.width: 1
                            border.color: Colors.surfaceContainer
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: Theme.iconSize
                            source: disc.modelData.icon
                        }

                        MouseArea {
                            id: discPointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            // A tap on the folded stack (touch has no hover) fans it first.
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    island.openMenu(disc.modelData);
                                else if (!island.fanned)
                                    island.fanned = true;
                                else
                                    Tray.activate(disc.modelData);
                            }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.tooltipTitle || modelData.title || modelData.id
                    }
                }

                Item {
                    id: chevron

                    property real offset: island.chevronOffset

                    objectName: "trayChevron"
                    visible: island.chevronShown
                    x: -offset - width
                    y: (Theme.islandHeight - height) / 2
                    width: island.chevronWidth
                    height: Theme.indicatorPill

                    Behavior on offset {
                        TrayAnimation {}
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: chevronPointer.containsMouse ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.16)) : "transparent"
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "chevron_left"
                        size: Theme.trayChevronSize
                        color: Colors.foregroundVariant
                        rotation: island.fanned ? 180 : 0

                        Behavior on rotation {
                            TrayAnimation {}
                        }
                    }

                    MouseArea {
                        id: chevronPointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: island.fanned = !island.fanned
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: island.fanned ? "Fold tray icons" : "Show all tray icons"
                }
            }
        }

        Item {
            objectName: "separator"
            width: island.separatorShown ? island.separatorWidth : 0
            height: Theme.islandHeight
            opacity: island.separatorShown ? 1 : 0
            clip: true

            Behavior on width {
                IndicatorAnimation {}
            }
            Behavior on opacity {
                IndicatorAnimation {}
            }

            Hairline {
                anchors.centerIn: parent
            }
        }

        Indicator {
            id: caffeineIndicator

            objectName: "caffeine"
            shown: island.shownFlags[0]
            gap: island.gapBefore(0)
            iconName: "coffee"
            label: "Caffeine on, turn it off"
            onActivated: Dms.toggleCaffeine()
        }

        Indicator {
            id: mutedIndicator

            objectName: "muted"
            shown: island.shownFlags[1]
            gap: island.gapBefore(1)
            iconName: "volume_off"
            label: "Muted, unmute"
            takesWheel: true
            onActivated: Audio.toggleMute()
            onScrolled: delta => Audio.setVolume(Audio.volume + (delta > 0 ? 1 : -1) * Theme.sliderStep / 100)
        }

        Indicator {
            id: wifiIndicator

            objectName: "wifi"
            shown: island.shownFlags[2]
            gap: island.gapBefore(2)
            iconName: !Network.wifiEnabled ? "wifi_off" : Network.strength >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
            label: Network.wifiEnabled ? "Wi-Fi weak, open Settings" : "Wi-Fi off, open Settings"
            onActivated: Shell.open("settings", island.screenName)
        }

        Indicator {
            id: updatesIndicator

            objectName: "updates"
            shown: island.shownFlags[3]
            gap: island.gapBefore(3)
            iconName: "download"
            count: Updates.count
            tint: Updates.fragileCount > 0 ? Colors.error : Colors.foreground
            label: Updates.count + " updates, open Updates"
            onActivated: Shell.toggle("updates", island.screenName)
        }

        Indicator {
            id: notificationsIndicator

            objectName: "notifications"
            shown: island.shownFlags[4]
            gap: island.gapBefore(4)
            iconName: Dms.doNotDisturb ? "notifications_off" : "notifications"
            count: Notifications.count
            label: Notifications.count + " notifications" + (Dms.doNotDisturb ? ", do not disturb on" : "") + ", open Settings"
            onActivated: Shell.open("settings", island.screenName)
            onMiddleClicked: Notifications.clearAll()
            onRightClicked: Dms.toggleDoNotDisturb()
        }
    }

    // Hangs from the island's left padding whichever disc was clicked.
    Item {
        objectName: "trayMenu"
        x: Theme.paddingHorizontal
        y: Theme.islandHeight
        width: island.menuWidth
        height: menuColumn.implicitHeight
        opacity: island.menuOpen ? 1 : 0
        visible: opacity > 0
        enabled: island.menuOpen

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        QsMenuOpener {
            id: menuOpener

            menu: island.menuItem ? Tray.menuFor(island.menuItem) : null
        }

        Column {
            id: menuColumn

            width: parent.width

            Repeater {
                model: island.menuEntries
                onCountChanged: Qt.callLater(island.measureMenu)

                // Submenus are flattened one level: the parent becomes a header
                // over its indented entries; deeper levels are only marked.
                Column {
                    id: topEntry

                    required property var modelData

                    width: island.menuWidth

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
                        onCountChanged: Qt.callLater(island.measureMenu)

                        MenuRow {
                            required property var modelData

                            entry: modelData
                            depth: 1
                        }
                    }
                }
            }
        }
    }

    component TrayAnimation: NumberAnimation {
        duration: Motion.trayDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.growCurve
    }

    component IndicatorAnimation: NumberAnimation {
        duration: Motion.indicatorDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.indicatorCurve
    }

    // Some apps put multi-line status text in an entry: the row wraps it to
    // at most three lines and grows with it, never under 32 px.
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
        readonly property string label: present && !separator ? island.menuLabel(entry.text ?? "") : ""
        readonly property real textX: Theme.paddingHorizontal + depth * Theme.trayMenuSubmenuIndent
        readonly property real trailing: Theme.paddingHorizontal + (nested ? Theme.trayChevronSize + Theme.indicatorCountGap : 0)
        // The unwrapped width of the widest line, for the menu width.
        readonly property real naturalWidth: textX + singleLine.implicitWidth + trailing
        readonly property bool listed: present && (separator || label !== "")

        objectName: "menuRow"
        width: island.menuWidth
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
            color: rowPointer.containsMouse && row.clickable ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.16)) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }
        }

        MenuText {
            id: labelText

            objectName: "menuLabel"
            visible: !row.separator
            x: row.textX
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - row.trailing
            text: row.label
            wrapMode: Text.Wrap
            maximumLineCount: Theme.trayMenuMaxLines
            elide: Text.ElideRight
            color: row.header ? Colors.foregroundVariant : Colors.foreground
            opacity: row.present && !row.entry.enabled ? 0.5 : 1
        }

        MenuText {
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
                island.closeMenu();
            }
        }

        Accessible.role: row.separator ? Accessible.Separator : Accessible.MenuItem
        Accessible.name: row.label
    }

    component MenuText: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
    }

    // A permanent 24 px pill hit area; hover only tints it. The width and
    // opacity carry the appear and disappear, the gap rides inside the width.
    component Indicator: Item {
        id: indicator

        property bool shown: false
        property bool gap: false
        property string iconName: ""
        property int count: 0
        property color tint: Colors.foreground
        property string label: ""
        property bool takesWheel: false

        signal activated
        signal middleClicked
        signal rightClicked
        signal scrolled(real delta)

        readonly property real pillWidth: 2 * Theme.gap + Theme.iconSize + (count > 0 ? Theme.indicatorCountGap + Math.ceil(countText.implicitWidth) : 0)
        readonly property real targetWidth: shown ? (gap ? Theme.indicatorGap : 0) + pillWidth : 0

        width: targetWidth
        height: Theme.islandHeight
        opacity: shown ? 1 : 0
        enabled: shown
        clip: true

        Behavior on width {
            IndicatorAnimation {}
        }
        Behavior on opacity {
            IndicatorAnimation {}
        }

        Rectangle {
            id: pill

            x: indicator.gap ? Theme.indicatorGap : 0
            y: (Theme.islandHeight - height) / 2
            width: indicator.pillWidth
            height: Theme.indicatorPill
            radius: height / 2
            color: pointer.containsMouse ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.16)) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            Icon {
                x: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                name: indicator.iconName
                color: indicator.tint
            }

            Text {
                id: countText

                visible: indicator.count > 0
                x: Theme.gap + Theme.iconSize + Theme.indicatorCountGap
                anchors.verticalCenter: parent.verticalCenter
                text: indicator.count
                color: indicator.tint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.indicatorCountFontSize
                font.weight: Theme.fontWeight
                font.features: ({
                        tnum: 1
                    })
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    island.fanned = false;
                    if (mouse.button === Qt.MiddleButton)
                        indicator.middleClicked();
                    else if (mouse.button === Qt.RightButton)
                        indicator.rightClicked();
                    else
                        indicator.activated();
                }
                onWheel: wheel => {
                    if (!indicator.takesWheel) {
                        wheel.accepted = false;
                        return;
                    }
                    indicator.scrolled(wheel.angleDelta.y);
                }
            }

            Accessible.role: Accessible.Button
            Accessible.name: indicator.label
        }
    }
}
