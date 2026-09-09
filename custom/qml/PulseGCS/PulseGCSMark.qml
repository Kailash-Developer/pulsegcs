import QtQuick
import QtQuick.Effects

// PulseGCS f-mark — uses the supplied reference icon assets (PNG + SVG layers).
Item {
    id: root

    property real markSize: 104
    property color arcColor: "#EAF2F7"
    property color coreColor: "#00C4DE"
    property real arcDrawProgress: 1.0
    property real arcOpacity: 1.0
    property real coreScale: 1.0
    property real coreOpacity: 1.0

    readonly property int pixelSize: Math.max(1, Math.round(markSize))
    readonly property real dpr: Screen.devicePixelRatio
    readonly property int rasterSize: Math.ceil(pixelSize * dpr)
    readonly property bool showReferenceMark: arcDrawProgress >= 1.0
                                                    && coreScale >= 0.999
                                                    && arcOpacity >= 1.0
                                                    && coreOpacity >= 1.0

    width: pixelSize
    height: pixelSize

    // Authoritative reference icon (user-supplied mark) — exact lockup appearance.
    Image {
        id: referenceMark
        anchors.fill: parent
        visible: root.showReferenceMark
        opacity: Math.min(root.arcOpacity, root.coreOpacity)
        source: Qt.resolvedUrl("../../res/PulseGCS/pulsegcs-mark-color.png")
        sourceSize: Qt.size(root.rasterSize, root.rasterSize)
        fillMode: Image.Stretch
        smooth: false
        mipmap: false
        cache: true
    }

    // Animated build-up layers (SVG assets) — hidden once the reference mark is fully formed.
    Item {
        id: buildLayers
        anchors.fill: parent
        visible: !root.showReferenceMark

        Image {
            id: arcsImage
            anchors.fill: parent
            visible: false
            source: Qt.resolvedUrl("../../res/PulseGCS/pulsegcs-mark-arcs.svg")
            sourceSize: Qt.size(root.rasterSize, root.rasterSize)
            fillMode: Image.Stretch
            smooth: false
            mipmap: false
            cache: true
        }

        MultiEffect {
            id: arcsReveal
            anchors.fill: parent
            visible: root.arcOpacity > 0.0 && root.arcDrawProgress > 0.0
            opacity: root.arcOpacity
            source: arcsImage
            maskEnabled: true
            maskSource: arcMask
        }

        Item {
            id: arcMask
            width: arcsImage.width
            height: arcsImage.height
            visible: false
            layer.enabled: true

            Canvas {
                id: arcMaskCanvas
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                renderStrategy: Canvas.Immediate

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = "#000000"
                    ctx.fillRect(0, 0, width, height)

                    if (root.arcDrawProgress <= 0.0) {
                        return
                    }

                    var scale = root.pixelSize / 104.0
                    ctx.scale(scale, scale)

                    var cx = 52.0
                    var cy = 52.0
                    var r = 45.5

                    ctx.strokeStyle = "#ffffff"
                    ctx.lineWidth = 13
                    ctx.lineCap = "butt"
                    ctx.lineJoin = "miter"
                    ctx.setLineDash([72.0])
                    ctx.lineDashOffset = 72.0 * (1.0 - root.arcDrawProgress)

                    ctx.beginPath()
                    ctx.moveTo(84.17, 19.83)
                    ctx.arc(cx, cy, r, -Math.PI / 4.0, Math.PI / 4.0, false)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.moveTo(19.83, 84.17)
                    ctx.arc(cx, cy, r, 3.0 * Math.PI / 4.0, 5.0 * Math.PI / 4.0, false)
                    ctx.stroke()
                }
            }
        }

        Item {
            id: coreWrapper
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            scale: root.coreScale
            opacity: root.coreOpacity
            visible: root.coreOpacity > 0.0 && root.coreScale > 0.0

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../../res/PulseGCS/pulsegcs-mark-core.svg")
                sourceSize: Qt.size(root.rasterSize, root.rasterSize)
                fillMode: Image.Stretch
                smooth: false
                mipmap: false
                cache: true
            }
        }
    }

    onArcDrawProgressChanged: arcMaskCanvas.requestPaint()
    onArcOpacityChanged: arcMaskCanvas.requestPaint()
    onPixelSizeChanged: arcMaskCanvas.requestPaint()
    Component.onCompleted: arcMaskCanvas.requestPaint()
}
