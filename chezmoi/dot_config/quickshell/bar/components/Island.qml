pragma ComponentBehavior: Bound

import QtQuick
import ".."

// The surface every island is drawn on. The owner sets targetWidth, targetHeight,
// expanded, targetOpacity and optionally targetBlend; one animation carries size,
// radius, shadow, background and blend together, so they share one progress.
Rectangle {
    id: island

    property real targetWidth: implicitWidth
    property real targetHeight: implicitHeight
    property bool expanded: false
    property real targetOpacity: Theme.islandOpacity
    // Free for the owner: content that moves with the island reads blend.
    property real targetBlend: 0
    // An owner whose change has its own Motion token (a workspace slide, a tray
    // fan) sets these before changing a target; -1 and [] keep grow and shrink.
    property int morphDuration: -1
    property var morphCurve: []

    readonly property real targetRadius: expanded ? Theme.islandRadiusExpanded : Theme.islandRadius
    readonly property real targetShadow: expanded ? 1 : 0
    // True while the running animation shrinks the island; the prototype calls it a
    // shrink when the area gets smaller.
    readonly property alias shrinking: morph.shrinking

    // Before completion the targets settle without animation.
    property bool ready: false
    // The animation runs from span.start to span.end; progress is its only animated value.
    property var span: ({
            start: targets(),
            end: targets()
        })
    property real progress: 1

    function targets(): var {
        return {
            width: targetWidth,
            height: targetHeight,
            radius: targetRadius,
            shadow: targetShadow,
            opacity: targetOpacity,
            blend: targetBlend
        };
    }

    function between(key: string): real {
        return span.start[key] + (span.end[key] - span.start[key]) * progress;
    }

    // Owners change several targets in one state change; Qt.callLater folds them
    // into one retarget, so width and height never start at different moments.
    function retarget() {
        if (!ready)
            return;
        const next = targets();
        if (Object.keys(next).every(key => next[key] === span.end[key]))
            return;
        const current = {
            width: width,
            height: height,
            radius: radius,
            shadow: shadowStrength,
            opacity: backgroundOpacity,
            blend: blend
        };
        morph.stop();
        morph.shrinking = next.width * next.height < current.width * current.height;
        progress = 0;
        span = {
            start: current,
            end: next
        };
        morph.start();
    }

    Component.onCompleted: {
        span = {
            start: targets(),
            end: targets()
        };
        ready = true;
    }

    onTargetWidthChanged: Qt.callLater(retarget)
    onTargetHeightChanged: Qt.callLater(retarget)
    onTargetRadiusChanged: Qt.callLater(retarget)
    onTargetOpacityChanged: Qt.callLater(retarget)
    onTargetBlendChanged: Qt.callLater(retarget)

    width: between("width")
    height: between("height")
    radius: between("radius")
    readonly property real shadowStrength: between("shadow")
    readonly property real backgroundOpacity: between("opacity")
    readonly property real blend: between("blend")

    color: Qt.alpha(Colors.surfaceContainer, backgroundOpacity)
    clip: true

    MorphAnimation {
        id: morph

        durationOverride: island.morphDuration
        curveOverride: island.morphCurve
        target: island
        property: "progress"
        from: 0
        to: 1
    }

    layer.enabled: true
    layer.effect: IslandShadow {
        shadowOpacity: island.shadowStrength
    }
}
