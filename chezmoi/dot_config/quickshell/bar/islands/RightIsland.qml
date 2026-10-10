pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."
import "../components"
import "../services"

// Tray group, hairline and attention indicators, or the notification stack in
// their place. The owner fixes the right edge; the content is laid out from it,
// so the island grows leftward, and a tray menu or the stack grows it
// downward. A click on the background opens Settings.
Island {
    id: island

    required property string screenName
    // The widest the island may be on this screen: clear of the centre island.
    property real peekMaxWidth: Theme.notificationPeekWidth

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

    // The notification stack: the service's rows when its stack is on this
    // screen. Before it opens, a tray menu closes and a fanned tray folds; while
    // it is open nothing else is drawn. It closes as the last row starts to
    // leave, and the island morphs back with the bell held until it has settled.
    readonly property var servicePeekIds: Notifications.peekScreen === screenName ? Notifications.peekIds : []
    readonly property bool peekWanted: servicePeekIds.length > 0
    property bool peekOpen: false
    readonly property var shownPeekIds: peekOpen ? servicePeekIds : []
    property bool bellHeld: false
    // The rows that stay, without the gap under the last; set by measurePeek.
    property real peekRowsHeight: 0
    property string lastPeekId: ""
    readonly property real peekWidth: Math.min(Theme.notificationPeekWidth, peekMaxWidth)
    // For the blobs' clear-all: the pointer on the stack, or a row's controls
    // revealed by a long press.
    // From the island's right edge, where the blobs go on the morph back.
    readonly property real bellCentreOffset: Theme.rightEndInset + notificationsIndicator.pillWidth / 2

    readonly property bool wifiShown: !Network.wifiEnabled || Network.weak
    // Left to right, the reverse of the design's reading order from the right edge.
    // Do not disturb has no indicator of its own: the bell crosses out and stays.
    readonly property bool notificationsShown: Notifications.bellCount > 0 || Notifications.doNotDisturb
    // The keyboard button only while the cover is detached (docs/tablet.md).
    readonly property var shownFlags: [Dms.caffeine, Audio.muted, wifiShown, Tablet.detached, Updates.count > 0, notificationsShown]
    readonly property bool anyIndicator: shownFlags.includes(true)
    readonly property bool separatorShown: trayCount > 0 && anyIndicator
    readonly property int separatorWidth: 2 * Theme.gap + Theme.hairlineWidth
    readonly property real indicatorsWidth: caffeineIndicator.targetWidth + mutedIndicator.targetWidth + wifiIndicator.targetWidth + keyboardIndicator.targetWidth + updatesIndicator.targetWidth + notificationsIndicator.targetWidth
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

    // Rows that leave stay until their collapse is done (peekModel.finish).
    function syncPeek() {
        peekModel.sync(shownPeekIds);
        motion = "peek";
        measurePeek();
        // The last row starts leaving: the island morphs back with it.
        if (peekModel.settledCount === 0)
            peekOpen = false;
    }

    // The island is as tall as the rows that stay; the last one has no hairline.
    function measurePeek() {
        let height = 0;
        let settled = 0;
        let last = "";
        for (let index = 0; index < peekRepeater.count; index++) {
            const row = peekRepeater.itemAt(index) as NotificationPeekRow;
            if (!row || row.leaving)
                continue;
            height += row.settledHeight;
            settled++;
            last = row.rowId;
        }
        if (settled === 0)
            return;
        peekRowsHeight = height + (settled - 1) * Theme.notificationPeekRowGap;
        lastPeekId = last;
    }

    // Where a row's icon disc is, for the blob that starts from it.
    function peekDisc(id: string): Item {
        for (let index = 0; index < peekRepeater.count; index++) {
            const row = peekRepeater.itemAt(index) as NotificationPeekRow;
            if (row && row.rowId === id)
                return row.disc;
        }
        return null;
    }

    // A tray menu closes and a fanned tray folds before the stack opens.
    function preparePeek() {
        const wait = Math.max(menuOpen ? Motion.shrinkDuration : 0, fanned ? Motion.trayDuration : 0);
        closeMenu();
        fanned = false;
        if (wait === 0) {
            peekOpen = true;
            return;
        }
        peekPrepareTimer.interval = wait;
        peekPrepareTimer.restart();
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
    onShownFlagsChanged: motion = peekOpen || bellHeld ? "peek" : "indicator"
    onShownPeekIdsChanged: syncPeek()
    onPeekWantedChanged: {
        if (!peekWanted)
            peekPrepareTimer.stop();
        else if (!peekOpen)
            preparePeek();
    }
    onPeekOpenChanged: {
        motion = "peek";
        if (peekOpen) {
            bellRelease.stop();
            bellHeld = true;
            fanned = false;
        } else {
            bellRelease.restart();
        }
    }

    targetWidth: peekOpen ? peekWidth : menuOpen ? Math.max(collapsedWidth, menuWidth + 2 * Theme.paddingHorizontal) : collapsedWidth
    targetHeight: peekOpen ? peekRowsHeight + 2 * Theme.notificationPeekPaddingVertical : menuOpen ? Theme.islandHeight + menuColumn.implicitHeight + Theme.trayMenuInset : Theme.islandHeight
    expanded: menuOpen || peekOpen
    morphDuration: motion === "menu" || motion === "peek" ? -1 : motion === "tray" || motion === "actions" ? Motion.trayDuration : Motion.indicatorDuration
    morphCurve: motion === "menu" || motion === "peek" ? [] : motion === "tray" || motion === "actions" ? Motion.growCurve : Motion.indicatorCurve
    visible: width > 0

    Timer {
        id: peekPrepareTimer

        onTriggered: {
            if (island.peekWanted)
                island.peekOpen = true;
        }
    }

    // The bell appears once the morph back has settled.
    Timer {
        id: bellRelease

        interval: Motion.shrinkDuration
        onTriggered: island.bellHeld = false
    }

    KeyedListModel {
        id: peekModel

        keyRole: "rowId"
        leavingRoles: ["leaving"]
    }

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

    // Middle click on the stack outside its rows clears the stack; a row's own
    // middle click dismisses only that row.
    MouseArea {
        objectName: "background"
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (island.peekOpen)
                    Notifications.clearStack();
                return;
            }
            island.fanned = false;
            if (island.menuOpen)
                island.closeMenu();
            else
                Shell.toggle("settings", island.screenName);
        }
    }

    // Newest on top, at the island's right edge with a fixed width, so the text
    // does not reflow while the island morphs; the island clips the rest.
    Column {
        objectName: "peek"
        anchors.right: parent.right
        anchors.rightMargin: Theme.notificationPeekPaddingHorizontal
        y: Theme.notificationPeekPaddingVertical
        width: island.peekWidth - 2 * Theme.notificationPeekPaddingHorizontal
        visible: peekModel.count > 0

        Repeater {
            id: peekRepeater

            model: peekModel

            NotificationPeekRow {
                width: parent.width
                backlogCount: Notifications.backlogCount
                holding: island.peekOpen && island.servicePeekIds.includes(rowId)
                lastRow: rowId === island.lastPeekId
                onHoldEnded: Notifications.expirePeek(rowId)
                onSettingsRequested: Shell.open("settings", island.screenName)
                onGone: peekModel.finish(rowId)
                onRevealedChanged: {
                    if (!leaving)
                        island.motion = "actions";
                }
                onSettledHeightChanged: Qt.callLater(island.measurePeek)
            }
        }
    }

    // The status content; while the stack shows it is faded out and not drawn.
    Row {
        objectName: "content"
        anchors.right: parent.right
        anchors.rightMargin: Theme.rightEndInset
        height: Theme.islandHeight
        opacity: island.peekOpen ? 0 : 1
        visible: opacity > 0
        enabled: !island.peekOpen

        Behavior on opacity {
            Crossfade {}
        }

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
                            color: discPointer.containsMouse ? Colors.hoverSurface : Colors.surfaceContainerHigh
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
                        color: chevronPointer.containsMouse ? Colors.hoverSurface : "transparent"
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
            iconName: Network.statusIcon
            label: Network.wifiEnabled ? "Wi-Fi weak, open Settings" : "Wi-Fi off, open Settings"
            onActivated: Shell.open("settings", island.screenName)
        }

        Indicator {
            id: keyboardIndicator

            objectName: "keyboard"
            shown: island.shownFlags[3]
            gap: island.gapBefore(3)
            iconName: Tablet.keyboardVisible ? "keyboard_hide" : "keyboard"
            tint: Tablet.keyboardVisible ? Colors.primary : Colors.foreground
            label: Tablet.keyboardVisible ? "Hide the on-screen keyboard" : "Show the on-screen keyboard"
            onActivated: Tablet.toggleKeyboard()
        }

        Indicator {
            id: updatesIndicator

            objectName: "updates"
            shown: island.shownFlags[4]
            gap: island.gapBefore(4)
            iconName: "download"
            count: Updates.count
            tint: Updates.fragileCount > 0 ? Colors.error : Colors.foreground
            label: Updates.count + " updates, open Updates"
            onActivated: Shell.toggle("updates", island.screenName)
        }

        Indicator {
            id: notificationsIndicator

            objectName: "notifications"
            shown: island.shownFlags[5]
            held: island.bellHeld
            gap: island.gapBefore(5)
            iconName: Notifications.doNotDisturb ? "notifications_off" : "notifications"
            count: Notifications.bellCount
            label: Notifications.bellCount + " notifications" + (Notifications.doNotDisturb ? ", do not disturb on" : "") + ", open Settings"
            onActivated: Shell.open("settings", island.screenName)
            onMiddleClicked: Notifications.clearAll()
            onRightClicked: Notifications.toggleDoNotDisturb()
        }
    }

    // Hangs from the island's left padding whichever disc was clicked.
    Appear {
        objectName: "trayMenu"
        x: Theme.paddingHorizontal
        y: Theme.islandHeight
        width: island.menuWidth
        height: menuColumn.implicitHeight
        shown: island.menuOpen

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

    component TrayAnimation: MorphAnimation {
        durationOverride: Motion.trayDuration
    }

    component IndicatorAnimation: MorphAnimation {
        durationOverride: Motion.indicatorDuration
        curveOverride: Motion.indicatorCurve
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
                island.closeMenu();
            }
        }

        Accessible.role: row.separator ? Accessible.Separator : Accessible.MenuItem
        Accessible.name: row.label
    }

    // A permanent 24 px pill hit area; hover only tints it. The width and
    // opacity carry the appear and disappear, the gap rides inside the width.
    component Indicator: Item {
        id: indicator

        property bool shown: false
        // Keeps its place but is not drawn: the bell while the stack shows and
        // the island morphs back; then it fades in.
        property bool held: false
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
        opacity: shown && !held ? 1 : 0
        enabled: shown && !held
        clip: true

        Behavior on width {
            enabled: !indicator.held

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
            color: pointer.containsMouse ? Colors.hoverSurface : "transparent"

            Behavior on color {
                ColorCrossfade {}
            }

            Icon {
                x: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                name: indicator.iconName
                color: indicator.tint
            }

            Label {
                id: countText

                visible: indicator.count > 0
                x: Theme.gap + Theme.iconSize + Theme.indicatorCountGap
                anchors.verticalCenter: parent.verticalCenter
                text: indicator.count
                color: indicator.tint
                numeric: true
                font.pixelSize: Theme.indicatorCountFontSize
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
