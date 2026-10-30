import QtQuick
import PulseGCS

Item {
    id: root

    property real size: 16
    property real lineWidth: 2.0
    property color color: PulseGCSTokens.ink
    property bool running: true

    implicitWidth: visible ? size : 0
    implicitHeight: visible ? size : 0
    width: visible ? size : 0
    height: visible ? size : 0

    visible: running

    // Background static track ring (20% opacity)
    Rectangle {
        id: trackRing
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.20)
        border.width: root.lineWidth
    }

    // Rotating active arc
    Canvas {
        id: arcCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var r = (width - root.lineWidth) / 2

            if (r > 0) {
                ctx.beginPath()
                // 270 degree arc (1.5 * PI)
                ctx.arc(cx, cy, r, 0, 1.5 * Math.PI, false)
                ctx.strokeStyle = root.color
                ctx.lineWidth = root.lineWidth
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        RotationAnimation on rotation {
            running: root.visible && root.running
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 850
        }
    }

    onColorChanged: arcCanvas.requestPaint()
    onLineWidthChanged: arcCanvas.requestPaint()
}
