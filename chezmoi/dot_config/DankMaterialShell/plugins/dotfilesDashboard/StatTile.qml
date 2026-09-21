import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: tile

    property string title: ""
    property string valueText: ""
    property var samples: []
    property real sampleCeiling: 100
    property color lineColor: Theme.primary
    property real repaintTrigger: 0

    signal clicked

    onRepaintTriggerChanged: sparkline.requestPaint()
    onSamplesChanged: sparkline.requestPaint()
    onLineColorChanged: sparkline.requestPaint()

    implicitHeight: body.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius
    color: hoverArea.containsMouse ? Theme.ccPillInactiveHoverBg : Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: 1

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingXS

        Item {
            width: parent.width
            height: 18

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: tile.title
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: tile.valueText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Canvas {
            id: sparkline

            width: parent.width
            height: 44
            antialiasing: true

            onPaint: {
                const context = getContext("2d");
                context.reset();

                const values = tile.samples || [];
                if (values.length < 2)
                    return;

                const ceiling = Math.max(tile.sampleCeiling, 0.001);
                const stepX = width / (values.length - 1);
                const pointY = index => {
                    const ratio = Math.max(0, Math.min(1, values[index] / ceiling));
                    return height - 1 - ratio * (height - 2);
                };

                context.beginPath();
                context.moveTo(0, pointY(0));
                for (let index = 1; index < values.length; index++)
                    context.lineTo(index * stepX, pointY(index));

                context.strokeStyle = tile.lineColor;
                context.lineWidth = 2;
                context.lineJoin = "round";
                context.stroke();

                context.lineTo(width, height);
                context.lineTo(0, height);
                context.closePath();
                context.fillStyle = Theme.withAlpha(tile.lineColor, 0.12);
                context.fill();
            }
        }
    }

    DankRipple {
        id: ripple

        cornerRadius: tile.radius
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: tile.clicked()
    }
}
