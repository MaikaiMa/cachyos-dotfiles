pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import ".."
import "../components"
import "../services"

// Rows that broke out of the notification stack, as discs below the right
// island: each starts as the row's icon disc, crosses the island's bottom edge
// growing to the blob size and settles under the island, newest on the right.
// They follow the island's bottom edge, and when the stack ends they slide up
// into the bell, shrinking and fading. A click re-peeks one: it rises back into
// the island onto its new top row's disc. A clear-all blob sits on the far
// left as long as the stack shows. The island clips its
// content, so they live here, beside it; the owner puts this item's right edge
// and top on the island's and adds area(slot) to the window's input and blur
// regions.
Item {
    id: strip

    required property string screenName
    required property RightIsland island

    readonly property var serviceIds: Notifications.peekScreen === screenName ? Notifications.blobIds : []
    readonly property int step: Theme.notificationBlobSize + Theme.notificationBlobGap
    // Blobs that are not sliding into the bell or rising into the island; past
    // the maximum they make "+N".
    property int settledCount: 0
    // Slots up to the leftmost settled blob: a blob that rises keeps its slot
    // until it has gone, so the clear-all blob does not land on it.
    property int occupiedSlots: 0
    readonly property int extra: Math.max(0, settledCount - Theme.notificationBlobMax)
    // Kept while "+N" fades out.
    property int moreCount: 0
    readonly property real bellX: width - island.bellCentreOffset
    readonly property real bellY: Theme.islandHeight / 2
    readonly property real restY: island.height + Theme.notificationBlobGap + Theme.notificationBlobSize / 2
    // The top row's disc, where a re-peeked blob rises to.
    readonly property real riseX: width - island.peekWidth + Theme.notificationPeekPaddingHorizontal + Theme.notificationPeekDisc / 2
    readonly property real riseY: Theme.notificationPeekPaddingVertical + Theme.notificationPeekRowHeight / 2

    // Always there while the stack shows: a hover-only reveal was too easy to
    // lose on the trackpad.
    readonly property bool clearShown: island.peekOpen

    // The slots 0 to notificationBlobMax - 1 are blobs from the right, the slot
    // notificationBlobMax is "+N" and the one after it the clear-all blob; in
    // window coordinates, empty when nothing clickable is there.
    function area(slot: int): rect {
        const item = slot === Theme.notificationBlobMax + 1 ? clear : slot === Theme.notificationBlobMax ? more : repeater.count > slot ? repeater.itemAt(slot) as BlobSurface : null;
        if (!item || !item.interactive)
            return Qt.rect(0, 0, 0, 0);
        return Qt.rect(x + item.x, y + item.y, item.width, item.height);
    }

    // New blobs start from their row's disc while that row is still there. One
    // that leaves for a row of its own rises into the island; the others sink
    // into the bell.
    function sync() {
        const ids = serviceIds;
        const rows = Notifications.peekScreen === screenName ? Notifications.peekIds : [];
        for (let index = 0; index < blobModel.count; index++) {
            const entry = blobModel.get(index);
            if (entry.sinking || entry.rising || ids.includes(entry.blobId))
                continue;
            blobModel.setProperty(index, rows.includes(entry.blobId) ? "rising" : "sinking", true);
        }
        for (let position = ids.length - 1; position >= 0; position--) {
            const id = ids[position];
            let found = false;
            for (let index = 0; index < blobModel.count; index++) {
                const entry = blobModel.get(index);
                if (entry.blobId === id && !entry.sinking && !entry.rising)
                    found = true;
            }
            if (found)
                continue;
            const disc = island.peekDisc(id);
            const origin = disc ? disc.mapToItem(strip, disc.width / 2, disc.height / 2) : Qt.point(0, 0);
            blobModel.insert(0, {
                blobId: id,
                sinking: false,
                rising: false,
                fromDisc: !!disc,
                originX: origin.x,
                originY: origin.y
            });
        }
        countSettled();
    }

    function countSettled() {
        let settled = 0;
        let occupied = 0;
        for (let index = 0; index < blobModel.count; index++) {
            const entry = blobModel.get(index);
            if (entry.sinking || entry.rising)
                continue;
            settled++;
            occupied = index + 1;
        }
        settledCount = settled;
        occupiedSlots = Math.min(occupied, Theme.notificationBlobMax);
    }

    function removeBlob(id: string) {
        for (let index = blobModel.count - 1; index >= 0; index--) {
            const entry = blobModel.get(index);
            if (entry.blobId === id && (entry.sinking || entry.rising))
                blobModel.remove(index);
        }
        countSettled();
    }

    function openList() {
        Shell.open("settings", screenName);
    }

    width: Math.max(island.width, (Theme.notificationBlobMax + 2) * step)
    height: island.height + Theme.notificationBlobGap + Theme.notificationBlobSize
    visible: blobModel.count > 0 || more.opacity > 0 || clear.opacity > 0

    onServiceIdsChanged: sync()
    onExtraChanged: {
        if (extra > 0)
            moreCount = extra;
    }

    ListModel {
        id: blobModel
    }

    Repeater {
        id: repeater

        model: blobModel

        Blob {}
    }

    BlobSurface {
        id: more

        interactive: strip.extra > 0
        x: strip.width - Theme.notificationBlobSize - Theme.notificationBlobMax * strip.step
        y: strip.restY - height / 2
        width: Theme.notificationBlobSize
        height: Theme.notificationBlobSize
        opacity: interactive ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Text {
            anchors.centerIn: parent
            text: "+" + strip.moreCount
            color: Colors.foregroundVariant
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
            font.weight: Theme.notificationBlobCountWeight
            font.features: ({
                    tnum: 1
                })
        }

        Accessible.name: strip.moreCount + " more notifications, open the list"

        onActivated: strip.openList()
    }

    // Left of "+N" when it is there, else left of the last blob, or alone.
    BlobSurface {
        id: clear

        property real slot: strip.extra > 0 ? Theme.notificationBlobMax + 1 : strip.occupiedSlots

        interactive: strip.clearShown
        x: strip.width - Theme.notificationBlobSize - slot * strip.step
        y: strip.restY - height / 2
        width: Theme.notificationBlobSize
        height: Theme.notificationBlobSize
        opacity: interactive ? 1 : 0

        Behavior on slot {
            IslandAnimation {
                shrinking: true
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "close"
            color: clear.hovered ? Colors.foreground : Colors.foregroundVariant

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }
        }

        Accessible.name: "Clear the notification stack"

        onActivated: Notifications.clearStack()
    }

    // A disc in the island background and shadow. A middle click on any of
    // them clears the stack.
    component BlobSurface: Rectangle {
        id: surface

        // Takes clicks and has a place in the window's input and blur regions.
        property bool interactive: true
        readonly property bool hovered: pointer.containsMouse

        signal activated

        radius: width / 2
        color: pointer.containsMouse ? Qt.tint(Qt.alpha(Colors.surfaceContainer, Theme.islandOpacity), Qt.alpha(Colors.primary, 0.16)) : Qt.alpha(Colors.surfaceContainer, Theme.islandOpacity)
        visible: opacity > 0

        Behavior on color {
            ColorAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Colors.shadow, Theme.shadowOpacity)
            shadowVerticalOffset: Theme.shadowOffsetY
            blurMax: Theme.shadowBlur
            shadowBlur: 1
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            enabled: surface.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    Notifications.clearStack();
                else
                    surface.activated();
            }
        }

        Accessible.role: Accessible.Button
    }

    // Positions mix centres: from the row's disc to the slot (travel), then
    // from the slot to the bell (sink) or back to the top row's disc (rise);
    // the size follows the same progress.
    component Blob: BlobSurface {
        id: blob

        required property string blobId
        required property bool sinking
        required property bool rising
        required property bool fromDisc
        required property real originX
        required property real originY
        required property int index

        readonly property bool shown: index < Theme.notificationBlobMax
        // Slots from the right; a blob past the maximum waits under "+N".
        property real slot: shown ? index : Theme.notificationBlobMax
        property real travel: fromDisc ? 0 : 1
        property real sink: 0
        property real rise: 0
        property real presence: fromDisc ? 1 : 0
        property real shownProgress: shown ? 1 : 0
        property string iconUrl: ""
        property string summary: ""

        readonly property real slotX: strip.width - Theme.notificationBlobSize / 2 - slot * strip.step
        readonly property real restX: fromDisc ? originX + (slotX - originX) * travel : slotX
        readonly property real restY: fromDisc ? originY + (strip.restY - originY) * travel : strip.restY
        readonly property real restSize: fromDisc ? Theme.notificationPeekDisc + (Theme.notificationBlobSize - Theme.notificationPeekDisc) * travel : Theme.notificationBlobSize
        readonly property real centreX: restX + (strip.bellX - restX) * sink + (strip.riseX - restX) * rise
        readonly property real centreY: restY + (strip.bellY - restY) * sink + (strip.riseY - restY) * rise

        interactive: shown && !sinking && !rising
        x: centreX - width / 2
        y: centreY - height / 2
        width: restSize + (Theme.iconSize - restSize) * sink + (Theme.notificationPeekDisc - restSize) * rise
        height: width
        // Rising, it stays solid until it reaches the row's own disc.
        opacity: presence * shownProgress * (1 - sink) * Math.max(0, 1 - rise * rise)

        Behavior on slot {
            IslandAnimation {
                shrinking: true
            }
        }
        Behavior on shownProgress {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Component.onCompleted: {
            const entry = Notifications.entryFor(blobId);
            if (entry) {
                iconUrl = Notifications.iconSource(entry.appIcon, entry.desktopEntry, entry.image);
                summary = Notifications.oneLine(entry.summary);
            }
            if (fromDisc)
                travelIn.start();
            else
                fadeIn.start();
        }
        onSinkingChanged: {
            if (sinking)
                sinkUp.start();
        }
        onRisingChanged: {
            if (rising) {
                travelIn.complete();
                riseIn.start();
            }
        }
        onActivated: Notifications.repeek(blobId)

        IslandAnimation {
            id: travelIn

            target: blob
            property: "travel"
            to: 1
            shrinking: true
        }

        NumberAnimation {
            id: fadeIn

            target: blob
            property: "presence"
            to: 1
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }

        IslandAnimation {
            id: sinkUp

            target: blob
            property: "sink"
            to: 1
            shrinking: true
            onFinished: strip.removeBlob(blob.blobId)
        }

        // The row grows in place with the grow timing, so the rise uses it too.
        IslandAnimation {
            id: riseIn

            target: blob
            property: "rise"
            to: 1
            onFinished: strip.removeBlob(blob.blobId)
        }

        Image {
            id: appImage

            anchors.centerIn: parent
            width: Math.min(Theme.iconSize, parent.width)
            height: width
            sourceSize.width: Theme.iconSize * 2
            sourceSize.height: Theme.iconSize * 2
            source: blob.iconUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }

        Icon {
            anchors.centerIn: parent
            visible: !appImage.visible
            name: "notifications"
            color: Colors.foregroundVariant
        }

        Accessible.name: blob.summary + ", show again"
    }
}
