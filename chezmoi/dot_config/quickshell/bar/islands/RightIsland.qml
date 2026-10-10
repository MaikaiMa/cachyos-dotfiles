pragma ComponentBehavior: Bound

import QtQuick
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
    // Which change the next resize belongs to; morphTokens gives its timing.
    property string morphKind: "indicator"
    // A menu or the stack grows and shrinks with the island's own timing (-1, []).
    readonly property var morphTokens: ({
            indicator: {
                duration: Motion.indicatorDuration,
                curve: Motion.indicatorCurve
            },
            tray: {
                duration: Motion.trayDuration,
                curve: Motion.growCurve
            },
            actions: {
                duration: Motion.trayDuration,
                curve: Motion.growCurve
            },
            menu: {
                duration: -1,
                curve: []
            },
            peek: {
                duration: -1,
                curve: []
            }
        })

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
    readonly property var servicePeekIds: Notifications.peekIdsOn(screenName)
    readonly property bool peekWanted: servicePeekIds.length > 0
    property bool peekOpen: false
    readonly property var shownPeekIds: peekOpen ? servicePeekIds : []
    property bool bellHeld: false
    readonly property real peekWidth: Math.min(Theme.notificationPeekWidth, peekMaxWidth)
    // From the island's right edge: the bell, where the blobs go on the morph
    // back, and the top row's disc, where a re-peeked blob rises to.
    readonly property real bellCentreOffset: Theme.rightEndInset + notificationsIndicator.pillWidth / 2
    readonly property real riseOffset: peekWidth - Theme.notificationPeekPaddingHorizontal - Theme.notificationPeekDisc / 2

    // Left to right, the reverse of the design's reading order from the right edge.
    readonly property list<StatusIndicator> indicators: [caffeineIndicator, mutedIndicator, wifiIndicator, keyboardIndicator, updatesIndicator, notificationsIndicator]
    readonly property bool anyIndicator: indicators.some(indicator => indicator.shown)
    readonly property bool separatorShown: trayCount > 0 && anyIndicator
    readonly property int separatorWidth: 2 * Theme.gap + Theme.hairlineWidth
    readonly property real indicatorsWidth: indicators.reduce((total, indicator) => total + indicator.targetWidth, 0)
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

    // An indicator keeps a gap to a shown one before it.
    function gapBefore(indicator: StatusIndicator): bool {
        return indicator.shown && indicators.slice(0, indicators.indexOf(indicator)).some(before => before.shown);
    }

    // Where a stack row's icon disc is, for the blob that starts from it.
    function discFor(id: string): Item {
        return stack.discFor(id);
    }

    function openMenu(item: var) {
        if (!Tray.menuFor(item))
            return;
        menuClear.stop();
        menuItem = item;
        menuOpen = true;
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

    function noteIndicatorResize() {
        morphKind = peekOpen || bellHeld ? "peek" : "indicator";
    }

    onFannedChanged: morphKind = "tray"
    onTrayCountChanged: morphKind = "tray"
    onMenuOpenChanged: morphKind = "menu"
    onShownPeekIdsChanged: {
        morphKind = "peek";
        stack.sync(shownPeekIds);
    }
    onPeekWantedChanged: {
        if (!peekWanted)
            peekPrepareTimer.stop();
        else if (!peekOpen)
            preparePeek();
    }
    onPeekOpenChanged: {
        morphKind = "peek";
        if (peekOpen) {
            bellRelease.stop();
            bellHeld = true;
            fanned = false;
        } else {
            bellRelease.restart();
        }
    }

    targetWidth: peekOpen ? peekWidth : menuOpen ? Math.max(collapsedWidth, trayMenu.menuWidth + 2 * Theme.paddingHorizontal) : collapsedWidth
    targetHeight: peekOpen ? stack.rowsHeight + 2 * Theme.notificationPeekPaddingVertical : menuOpen ? Theme.islandHeight + trayMenu.contentHeight + Theme.trayMenuInset : Theme.islandHeight
    expanded: menuOpen || peekOpen
    morphDuration: morphTokens[morphKind].duration
    morphCurve: morphTokens[morphKind].curve
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

    // At the island's right edge; the island clips the rest.
    NotificationStack {
        id: stack

        anchors.right: parent.right
        anchors.rightMargin: Theme.notificationPeekPaddingHorizontal
        y: Theme.notificationPeekPaddingVertical
        width: island.peekWidth - 2 * Theme.notificationPeekPaddingHorizontal
        backlogCount: Notifications.backlogCount
        onEmptied: island.peekOpen = false
        onActionsToggled: island.morphKind = "actions"
        onSettingsRequested: Shell.open("settings", island.screenName)
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

                        // The ring sits just outside the disc, in the island colour.
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
            shown: Dms.caffeine
            gap: island.gapBefore(caffeineIndicator)
            iconName: "coffee"
            label: "Caffeine on, turn it off"
            onActivated: Dms.toggleCaffeine()
        }

        Indicator {
            id: mutedIndicator

            objectName: "muted"
            shown: Audio.muted
            gap: island.gapBefore(mutedIndicator)
            iconName: "volume_off"
            label: "Muted, unmute"
            takesWheel: true
            onActivated: Audio.toggleMute()
            onScrolled: delta => Audio.setVolume(Audio.volume + (delta > 0 ? 1 : -1) * Theme.sliderStep / 100)
        }

        Indicator {
            id: wifiIndicator

            objectName: "wifi"
            shown: !Network.wifiEnabled || Network.weak
            gap: island.gapBefore(wifiIndicator)
            iconName: Network.statusIcon
            label: Network.wifiEnabled ? "Wi-Fi weak, open Settings" : "Wi-Fi off, open Settings"
            onActivated: Shell.open("settings", island.screenName)
        }

        // Only while the cover is detached (docs/tablet.md).
        Indicator {
            id: keyboardIndicator

            objectName: "keyboard"
            shown: Tablet.detached
            gap: island.gapBefore(keyboardIndicator)
            iconName: Tablet.keyboardVisible ? "keyboard_hide" : "keyboard"
            tint: Tablet.keyboardVisible ? Colors.primary : Colors.foreground
            label: Tablet.keyboardVisible ? "Hide the on-screen keyboard" : "Show the on-screen keyboard"
            onActivated: Tablet.toggleKeyboard()
        }

        Indicator {
            id: updatesIndicator

            objectName: "updates"
            shown: Updates.count > 0
            gap: island.gapBefore(updatesIndicator)
            iconName: "download"
            count: Updates.count
            tint: Updates.fragileCount > 0 ? Colors.error : Colors.foreground
            label: Updates.count + " updates, open Updates"
            onActivated: Shell.toggle("updates", island.screenName)
        }

        // Do not disturb has no indicator of its own: the bell crosses out and stays.
        Indicator {
            id: notificationsIndicator

            objectName: "notifications"
            shown: Notifications.bellCount > 0 || Notifications.doNotDisturb
            held: island.bellHeld
            gap: island.gapBefore(notificationsIndicator)
            iconName: Notifications.doNotDisturb ? "notifications_off" : "notifications"
            count: Notifications.bellCount
            label: Notifications.bellCount + " notifications" + (Notifications.doNotDisturb ? ", do not disturb on" : "") + ", open Settings"
            onActivated: Shell.open("settings", island.screenName)
            onMiddleClicked: Notifications.clearAll()
            onRightClicked: Notifications.toggleDoNotDisturb()
        }
    }

    // Hangs from the island's left padding whichever disc was clicked.
    TrayMenu {
        id: trayMenu

        x: Theme.paddingHorizontal
        y: Theme.islandHeight
        menu: island.menuItem ? Tray.menuFor(island.menuItem) : null
        open: island.menuOpen
        onEntryTriggered: island.closeMenu()
    }

    // A click on an indicator folds a fanned tray; its width change uses the indicator timing.
    component Indicator: StatusIndicator {
        onPressed: island.fanned = false
        onTargetWidthChanged: island.noteIndicatorResize()
    }

    component TrayAnimation: MorphAnimation {
        durationOverride: Motion.trayDuration
    }

    component IndicatorAnimation: MorphAnimation {
        durationOverride: Motion.indicatorDuration
        curveOverride: Motion.indicatorCurve
    }
}
