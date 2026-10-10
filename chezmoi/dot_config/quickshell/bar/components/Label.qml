import QtQuick
import qs

// Text in the bar's font. secondary is the small line in the variant colour,
// strong is demi-bold, numeric uses tabular figures so changing digits do not
// shift, lineHeightPx > 0 fixes the line height so rows keep one height.
// Plain text: notification and menu text must never be read as markup.
Text {
    property bool secondary: false
    property bool strong: false
    property bool numeric: false
    property real lineHeightPx: 0

    color: secondary ? Colors.foregroundVariant : Colors.foreground
    elide: Text.ElideRight
    textFormat: Text.PlainText
    lineHeightMode: lineHeightPx > 0 ? Text.FixedHeight : Text.ProportionalHeight
    lineHeight: lineHeightPx > 0 ? lineHeightPx : 1
    font.family: Theme.fontFamily
    font.pixelSize: secondary ? Theme.secondaryFontSize : Theme.fontSize
    font.weight: strong ? Font.DemiBold : Theme.fontWeight
    font.features: numeric ? ({
            tnum: 1
        }) : ({})
}
