import QtQuick
import qs

// A Material Symbols glyph by ligature name. Without the font, or without a
// name, it draws a dim rounded square of the same size so the layout holds.
Item {
    id: icon

    property string name: ""
    property int size: Theme.iconSize
    property color color: Colors.foreground
    property real fill: 0
    property int weight: 400

    readonly property bool glyphShown: Theme.iconFontAvailable && name !== ""

    implicitWidth: size
    implicitHeight: size

    Text {
        anchors.fill: parent
        visible: icon.glyphShown
        text: icon.name
        color: icon.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.iconFontFamily
        font.pixelSize: icon.size
        font.weight: icon.weight
        font.hintingPreference: Font.PreferNoHinting
        // The variable outlines overlap where FILL and wght blend them; Qt's
        // distance-field and curve renderers break up on overlapping contours
        // (holes and fringes in filled glyphs), FreeType rasterises them cleanly.
        renderType: Text.NativeRendering
        // opsz only spans 20..48; smaller icons use the 20 cut.
        font.variableAxes: ({
                FILL: icon.fill,
                wght: icon.weight,
                opsz: Math.min(48, Math.max(20, icon.size))
            })
    }

    Rectangle {
        anchors.fill: parent
        visible: !icon.glyphShown
        radius: icon.size / 4
        color: Qt.alpha(Colors.foregroundVariant, Theme.mutedOpacity)
    }
}
