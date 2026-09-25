import QtQuick
import QtQuick.Controls
import QGroundControl
import PulseGCS

Item {
    id: root

    property bool scanning: true
    property bool isOutdoor: PulseGCSTokens.isOutdoor
    property real size: 56

    implicitWidth: size
    implicitHeight: size

    readonly property color accentColor: PulseGCSTokens.accentColor(isOutdoor)
    readonly property color ringColor: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, isOutdoor ? 0.25 : 0.20)

    // Base background and outer border
    Rectangle {
        id: outerRing
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.isOutdoor ? 0.04 : 0.06)
        border.color: root.ringColor
        border.width: 1.5
    }

    // Inner concentric ring
    Rectangle {
        id: innerRing
        width: parent.width * 0.55
        height: parent.height * 0.55
        anchors.centerIn: parent
        radius: width / 2
        color: "transparent"
        border.color: root.ringColor
        border.width: 1
    }

    // Rotating scanner sweep arc
    Canvas {
        id: sweepCanvas
        anchors.fill: parent
        visible: root.scanning

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var r = (width / 2) - 1

            ctx.beginPath()
            // Draw a quarter-circle arc for the sweep head
            ctx.arc(cx, cy, r, -Math.PI / 2, 0, false)
            ctx.strokeStyle = root.accentColor
            ctx.lineWidth = 2.0
            ctx.stroke()
        }

        RotationAnimation on rotation {
            running: root.visible && root.scanning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1100
        }
    }

    // Radar core center dot with pulse animation
    Rectangle {
        id: coreDot
        width: 8
        height: 8
        radius: 4
        anchors.centerIn: parent
        color: root.accentColor

        SequentialAnimation on scale {
            running: root.visible && root.scanning
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.4; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.4; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
        }

        SequentialAnimation on opacity {
            running: root.visible && root.scanning
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.45; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
        }
    }
}
