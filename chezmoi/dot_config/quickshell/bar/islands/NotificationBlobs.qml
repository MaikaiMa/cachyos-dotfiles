pragma ComponentBehavior: Bound

import QtQuick
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
// and top on the island's, gives the places below in this item's coordinates
// and adds area(slot) to the window's input and blur regions.
Item {
    id: strip

    required property string screenName
    property real islandWidth: 0
    property real islandBottom: 0
    // The bell, where blobs sink to, and the top row's disc, where a re-peeked
    // blob rises to.
    property real bellX: 0
    property real riseX: 0
    // Always there while the stack shows: a hover-only reveal was too easy to
    // lose on the trackpad.
    property bool clearShown: false
    // The centre of a stack row's icon disc in this item, or null once the row is gone.
    property var discOrigin: id => null

    readonly property var serviceIds: NotificationStack.blobIdsOn(screenName)
    readonly property int step: Theme.notificationBlobSize + Theme.notificationBlobGap
    // Blobs that are not sliding into the bell or rising into the island; past
    // the maximum they make "+N".
    readonly property int settledCount: blobModel.settledCount
    // Slots up to the leftmost settled blob: a blob that rises keeps its slot
    // until it has gone, so the clear-all blob does not land on it.
    readonly property int occupiedSlots: Math.min(blobModel.settledEnd, Theme.notificationBlobMax)
    readonly property int extra: Math.max(0, settledCount - Theme.notificationBlobMax)
    // Kept while "+N" fades out.
    property int moreCount: 0
    readonly property real bellY: Theme.islandHeight / 2
    readonly property real restY: islandBottom + Theme.notificationBlobGap + Theme.notificationBlobSize / 2
    readonly property real riseY: Theme.notificationPeekPaddingVertical + Theme.notificationPeekRowHeight / 2

    // Every slot area() answers for, for the owner's regions.
    readonly property var slots: Array.from({
        length: Theme.notificationBlobMax + 2
    }, (_, slot) => slot)

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
        const rows = NotificationStack.peekIdsOn(screenName);
        blobModel.sync(serviceIds, id => {
            const origin = discOrigin(id);
            return {
                fromDisc: !!origin,
                originX: origin ? origin.x : 0,
                originY: origin ? origin.y : 0
            };
        }, id => rows.includes(id) ? "rising" : "sinking");
    }

    function openList() {
        Shell.open("settings", screenName);
    }

    width: Math.max(islandWidth, (Theme.notificationBlobMax + 2) * step)
    height: islandBottom + Theme.notificationBlobGap + Theme.notificationBlobSize
    visible: blobModel.count > 0 || more.opacity > 0 || clear.opacity > 0

    onServiceIdsChanged: sync()
    onExtraChanged: {
        if (extra > 0)
            moreCount = extra;
    }

    KeyedListModel {
        id: blobModel

        keyRole: "blobId"
        leavingRoles: ["sinking", "rising"]
        newAtTop: true
    }

    Repeater {
        id: repeater

        model: blobModel

        Blob {}
    }

    RestingBlob {
        id: more

        slot: Theme.notificationBlobMax
        interactive: strip.extra > 0

        Label {
            anchors.centerIn: parent
            text: "+" + strip.moreCount
            secondary: true
            numeric: true
            font.weight: Theme.notificationBlobCountWeight
        }

        Accessible.name: strip.moreCount + " more notifications, open the list"

        onActivated: strip.openList()
    }

    // Left of "+N" when it is there, else left of the last blob, or alone.
    RestingBlob {
        id: clear

        slot: strip.extra > 0 ? Theme.notificationBlobMax + 1 : strip.occupiedSlots
        interactive: strip.clearShown

        Icon {
            anchors.centerIn: parent
            name: "close"
            color: clear.hovered ? Colors.foreground : Colors.foregroundVariant

            Behavior on color {
                ColorCrossfade {}
            }
        }

        Accessible.name: "Clear the notification stack"

        onActivated: NotificationStack.clearStack()
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
        color: pointer.containsMouse ? Colors.hovered(Colors.islandSurface, false) : Colors.islandSurface
        visible: opacity > 0

        Behavior on color {
            ColorCrossfade {}
        }

        layer.enabled: true
        layer.effect: IslandShadow {}

        MouseArea {
            id: pointer

            anchors.fill: parent
            enabled: surface.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    NotificationStack.clearStack();
                else
                    surface.activated();
            }
        }

        Accessible.role: Accessible.Button
    }

    // A blob at rest in a slot from the right, shown while it takes clicks.
    component RestingBlob: BlobSurface {
        property real slot: 0

        x: strip.width - Theme.notificationBlobSize - slot * strip.step
        y: strip.restY - height / 2
        width: Theme.notificationBlobSize
        height: Theme.notificationBlobSize
        opacity: interactive ? 1 : 0

        Behavior on slot {
            MorphAnimation {
                shrinking: true
            }
        }
        Behavior on opacity {
            Crossfade {}
        }
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
            MorphAnimation {
                shrinking: true
            }
        }
        Behavior on shownProgress {
            Crossfade {}
        }

        Component.onCompleted: {
            const entry = Notifications.entryFor(blobId);
            if (entry) {
                iconUrl = Notifications.iconFor(blobId);
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
        onActivated: NotificationStack.repeek(blobId)

        MorphAnimation {
            id: travelIn

            target: blob
            property: "travel"
            to: 1
            shrinking: true
        }

        Crossfade {
            id: fadeIn

            target: blob
            property: "presence"
            to: 1
        }

        MorphAnimation {
            id: sinkUp

            target: blob
            property: "sink"
            to: 1
            shrinking: true
            onFinished: blobModel.finish(blob.blobId)
        }

        // The row grows in place with the grow timing, so the rise uses it too.
        MorphAnimation {
            id: riseIn

            target: blob
            property: "rise"
            to: 1
            onFinished: blobModel.finish(blob.blobId)
        }

        // The blob is the disc: it brings the shape and the shadow.
        AppIconDisc {
            size: blob.width
            color: "transparent"
            source: blob.iconUrl
        }

        Accessible.name: blob.summary + ", show again"
    }
}
