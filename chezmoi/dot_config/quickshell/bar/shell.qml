import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Theme.barHeight
            exclusiveZone: Theme.barHeight
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "dotfiles-bar"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing
                anchors.rightMargin: Theme.spacing
                spacing: Theme.spacing

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: placeholder.implicitWidth + 4 * Theme.spacing
                    implicitHeight: Theme.barHeight - Theme.spacing
                    radius: Theme.radius
                    color: Colors.surfaceContainer

                    Text {
                        id: placeholder

                        anchors.centerIn: parent
                        text: "bar"
                        color: Colors.onSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.centerIn: parent
                        implicitWidth: clock.implicitWidth + 4 * Theme.spacing
                        implicitHeight: Theme.barHeight - Theme.spacing
                        radius: Theme.radius
                        color: Colors.surfaceContainer

                        Clock {
                            id: clock

                            anchors.centerIn: parent
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: implicitHeight + 2 * Theme.spacing
                    implicitHeight: Theme.barHeight - Theme.spacing
                    radius: Theme.radius
                    color: Colors.surfaceContainer

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.fontSize
                        height: Theme.fontSize
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Colors.onSurface
                    }
                }
            }
        }
    }
}
