import QtQuick
import qs
import qs.components

// The body of one centre panel: as wide as Theme.panelWidths[name] and as
// tall as its settled implicitHeight, centred on its host, which the island
// clips while it grows. The host shows it while name is the island's state;
// it cross-fades, and hidden it is not drawn and takes no input.
Appear {
    id: panel

    // The Shell state that shows it and its Theme.panelWidths key.
    required property string name
    readonly property real contentX: Theme.panelPadding
    readonly property real contentWidth: width - 2 * Theme.panelPadding

    signal opened
    signal closed

    // The window takes the keys back on the state change; this runs after it.
    function focusWhenShown(item: Item) {
        Qt.callLater(() => {
            if (panel.shown)
                item.forceActiveFocus();
        });
    }

    anchors.horizontalCenter: parent.horizontalCenter
    implicitWidth: Theme.panelWidths[name]
    width: implicitWidth
    height: implicitHeight

    onShownChanged: {
        if (shown)
            opened();
        else
            closed();
    }
}
