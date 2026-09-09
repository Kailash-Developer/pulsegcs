import QtQuick

// Background watermark — native SVG raster at device-pixel resolution.
Image {
    id: root

    property real screenW: 0
    property real screenH: 0
    property bool isPhoneAspect: false

    readonly property int pixelSize: Math.max(1, Math.round(isPhoneAspect ? (screenH * 1.50) : (screenH * 1.32)))
    readonly property real dpr: Screen.devicePixelRatio
    readonly property int rasterSize: Math.ceil(pixelSize * dpr)

    width: pixelSize
    height: pixelSize
    x: Math.round(isPhoneAspect ? (screenW - pixelSize * (1.0 - 0.09)) : (screenW - pixelSize * (1.0 - 0.06)))
    y: Math.round(isPhoneAspect ? (-screenH * 0.30) : (-screenH * 0.22))

    source: Qt.resolvedUrl("../../res/PulseGCS/pulsegcs-mark-watermark.svg")
    fillMode: Image.Stretch
    sourceSize: Qt.size(rasterSize, rasterSize)
    smooth: false
    mipmap: false
    cache: true

    layer.enabled: true
    layer.smooth: false
    layer.textureSize: Qt.size(rasterSize, rasterSize)
}
