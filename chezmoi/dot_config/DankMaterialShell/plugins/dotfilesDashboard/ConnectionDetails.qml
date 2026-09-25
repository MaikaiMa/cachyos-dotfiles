import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Details

Item {
    id: details

    property string section: ""
    property real panelHeight: 350
    property bool animated: true
    property Item overlayParent: null

    property string shownSection: ""

    readonly property real targetHeight: section !== "" ? panelHeight + Theme.spacingM : 0

    onSectionChanged: {
        if (section !== "")
            shownSection = section;
    }

    // The panel stays loaded while the section folds shut; unloading it releases the
    // NetworkService ref that keeps DMS scanning for Wi-Fi networks.
    onHeightChanged: {
        if (section === "" && height <= 0.5)
            shownSection = "";
    }

    height: targetHeight
    clip: true

    Loader {
        y: Theme.spacingM
        width: parent.width
        height: details.panelHeight
        active: details.shownSection !== ""
        sourceComponent: details.shownSection === "bluetooth" ? bluetoothPanel : networkPanel
    }

    Component {
        id: networkPanel

        NetworkDetail {}
    }

    Component {
        id: bluetoothPanel

        BluetoothDetail {
            bluetoothCodecModalRef: codecSelector
            onShowCodecSelector: device => codecSelector.show(device)

            // The panel takes the keyboard back when its device menu closes, and its
            // own Escape handler closes the Control Center, not this section.
            onActiveFocusChanged: {
                if (activeFocus)
                    Qt.callLater(() => details.forceActiveFocus());
            }

            // The Control Center stops discovery when it closes; outside it nothing
            // else would, so it stops with the panel.
            Component.onDestruction: {
                if (BluetoothService.adapter?.discovering)
                    BluetoothService.adapter.discovering = false;
            }
        }
    }

    // The dashboard body is a Column, so the codec overlay is hosted by its parent
    // to cover the whole dashboard instead of taking a slot in the column.
    BluetoothCodecSelector {
        id: codecSelector

        parent: details.overlayParent
    }

    // Hiding disables the selector's focus scope, which leaves the keyboard outside
    // the dashboard, where Escape reaches the container that closes the popout.
    Connections {
        target: codecSelector

        function onModalVisibleChanged() {
            if (!codecSelector.modalVisible)
                Qt.callLater(() => details.forceActiveFocus());
        }
    }

    Behavior on height {
        id: heightBehavior

        enabled: details.animated

        NumberAnimation {
            readonly property bool growing: (heightBehavior.targetValue ?? 0) >= details.height

            duration: Theme.variantDuration(Theme.popoutAnimationDuration, growing)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: growing ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve
        }
    }
}
