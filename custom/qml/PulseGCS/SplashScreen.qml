import QtQuick
import QtQuick.Controls

import QGroundControl
import PulseGCS 1.0

Item {
    id: root
    anchors.fill: parent
    z: 100000
    opacity: exitOpacity

    signal splashCompleted()

    function _finishSplash() {
        root.splashCompleted()
    }

    property bool isPlaying: true
    readonly property bool reducedMotion: typeof Qt.styleHints !== "undefined"
                                        && Qt.styleHints.preferReducedMotion === true
    readonly property int editionIndex: 0

    property string appVersion: PulseGCSStartupController.appVersion
    property string buildNumber: PulseGCSStartupController.buildNumber
    property string poweredByLabel: "POWERED BY"
    property string vendorLabel: "SKYX AEROSPACE"
    property string statusTime: _clock.timeString

    QtObject {
        id: _clock
        property string timeString: Qt.formatTime(new Date(), "HH:mm")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: _clock.timeString = Qt.formatTime(new Date(), "HH:mm")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
    }

    Component.onCompleted: {
        if (root.reducedMotion) {
            durationMs = 120
            root.currentTimestampMs = root.totalDuration
            root.isPlaying = false
            root._finishSplash()
        }
    }

    // =========================================================================
    // COLOR TOKENS & EDITIONS (Section 02 Source of Truth)
    // =========================================================================
    readonly property var editions: [
        { name: "Aperture Cyan (Standard)", accent: "#00C4DE", accentR: 0,   accentG: 196, accentB: 222 },
        { name: "Sentinel Gold (Enterprise)", accent: "#E5A93C", accentR: 229, accentG: 169, accentB: 60  },
        { name: "Tactical Orange (Mil/Gov)",  accent: "#FF6B35", accentR: 255, accentG: 107, accentB: 53  }
    ]
    readonly property var currentEdition: root.editions[root.editionIndex]

    readonly property color groundColor: "#071A2B"
    readonly property color watermarkColor: "#0D2A40"
    readonly property color arcColor: "#EAF2F7"
    readonly property color wordmarkPulseColor: "#EAF2F7"
    readonly property color statusColor: "#7E96AB"
    readonly property color ruleColor: "#1E3B52"
    readonly property color endorsementDimColor: "#7E96AB"
    readonly property color endorsementLitColor: "#EAF2F7"
    readonly property color metaDimColor: "#5E778C"
    readonly property color metaLitColor: "#EAF2F7"

    // TIMING (HTML saved_resource.html — keyframes on 1400ms design timeline, scaled by durationMs)
    property int durationMs: 5200
    readonly property real totalDuration: durationMs
    property real currentTimestampMs: 0.0
    readonly property real normalizedProgress: Math.min(1.0, Math.max(0.0, root.currentTimestampMs / root.totalDuration))

    function frac(ms1400) { return ms1400 / 1400.0 }
    function lerpFrac(t, a, b, ease) {
        if (t <= a) return 0.0
        if (t >= b) return 1.0
        return ease((t - a) / (b - a))
    }

    function solveCubicBezier(p1x, p1y, p2x, p2y, t) {
        if (t <= 0.0) return 0.0
        if (t >= 1.0) return 1.0
        var u = t
        for (var i = 0; i < 8; i++) {
            var currentX = 3.0 * (1.0 - u) * (1.0 - u) * u * p1x + 3.0 * (1.0 - u) * u * u * p2x + u * u * u - t
            if (Math.abs(currentX) < 1e-5) break
            var currentSlope = 3.0 * (1.0 - u) * (1.0 - u) * p1x + 6.0 * (1.0 - u) * u * (p2x - p1x) + 3.0 * u * u * (1.0 - p2x)
            if (Math.abs(currentSlope) < 1e-5) break
            u -= currentX / currentSlope
        }
        u = Math.max(0.0, Math.min(1.0, u))
        return 3.0 * (1.0 - u) * (1.0 - u) * u * p1y + 3.0 * (1.0 - u) * u * u * p2y + u * u * u
    }
    function easeUniversal(t) { return solveCubicBezier(0.30, 0.02, 0.16, 1.00, t) }
    function easeArcs(t)      { return solveCubicBezier(0.22, 0.70, 0.20, 1.00, t) }
    function easeSmooth(t)    { return solveCubicBezier(0.25, 0.10, 0.25, 1.00, t) }

    readonly property real statusOpacity: {
        if (root.reducedMotion) return 1.0
        return Math.min(1.0, root.normalizedProgress / root.frac(200))
    }
    readonly property real arcDrawProgress: {
        if (root.reducedMotion) return 1.0
        return root.lerpFrac(root.normalizedProgress, root.frac(60), root.frac(320), root.easeArcs)
    }
    readonly property real arcOpacity: {
        if (root.reducedMotion) return 1.0
        return root.normalizedProgress >= root.frac(60) ? 1.0 : 0.0
    }
    readonly property real coreScale: {
        if (root.reducedMotion) return 1.0
        var t = root.lerpFrac(root.normalizedProgress, root.frac(280), root.frac(420), root.easeArcs)
        return 0.3 + 0.7 * t
    }
    readonly property real coreOpacity: {
        if (root.reducedMotion) return 1.0
        return root.lerpFrac(root.normalizedProgress, root.frac(280), root.frac(420), function(x){return x})
    }
    readonly property real wordmarkOpenProgress: {
        if (root.reducedMotion) return 1.0
        return root.lerpFrac(root.normalizedProgress, root.frac(420), root.frac(620), root.easeUniversal)
    }
    readonly property real wordmarkOpacity: {
        if (root.reducedMotion) return 1.0
        var p = root.normalizedProgress
        if (p < root.frac(420)) return 0.0
        if (p < root.frac(500)) return (p - root.frac(420)) / (root.frac(500) - root.frac(420))
        return 1.0
    }
    readonly property real travelProgress: {
        if (root.reducedMotion) return 1.0
        return root.lerpFrac(root.normalizedProgress, root.frac(660), root.frac(860), root.easeUniversal)
    }
    readonly property real ruleDrawProgress: {
        if (root.reducedMotion) return 1.0
        return root.lerpFrac(root.normalizedProgress, root.frac(860), root.frac(1000), root.easeUniversal)
    }
    readonly property real ruleOpacity: {
        if (root.reducedMotion) return 1.0
        return root.normalizedProgress >= root.frac(860) ? 1.0 : 0.0
    }
    readonly property real endorsementOpacity: {
        if (root.reducedMotion) return 1.0
        return root.lerpFrac(root.normalizedProgress, root.frac(960), root.frac(1120), root.easeSmooth)
    }
    readonly property real endorsementTranslateY: (1.0 - root.endorsementOpacity) * 4.0
    readonly property real plateOpacity: {
        if (root.reducedMotion) return 1.0
        return root.lerpFrac(root.normalizedProgress, root.frac(960), root.frac(1120), root.easeSmooth)
    }
    readonly property real exitOpacity: {
        if (root.reducedMotion) return 1.0
        var exitStart = root.frac(1250)
        if (root.normalizedProgress <= exitStart) return 1.0
        return 1.0 - root.lerpFrac(root.normalizedProgress, exitStart, 1.0, root.easeSmooth)
    }

    // Animation Driver Timer (60/120 Hz update)
    Timer {
        id: frameTimer
        interval: 16
        repeat: true
        running: root.isPlaying
        onTriggered: {
            var step = 16.0;
            var next = root.currentTimestampMs + step;
            if (next >= root.totalDuration) {
                root.currentTimestampMs = root.totalDuration;
                root.isPlaying = false;
                root._finishSplash();
            } else {
                root.currentTimestampMs = next;
            }
        }
    }

    Rectangle {
        id: deviceCanvas
        anchors.fill: parent
            color: root.groundColor
            clip: true

            // Device bezel outline for clear inspection

            // Responsive Metrics from HTML Specification
            readonly property real screenW: width
            readonly property real screenH: height
            readonly property real marginL: screenW * 0.045
            readonly property real marginR: screenW * 0.045
            readonly property real marginB: screenH * 0.070
            readonly property real symbolH: screenH * 0.190 // 19% of screen height
            readonly property real isPhoneAspect: (screenW / screenH) > 2.0

            // =================================================================
            // 1. BACKGROUND WATERMARK (132% H Tablet, 150% H Phone)
            // =================================================================
            PulseGCSWatermark {
                screenW: deviceCanvas.screenW
                screenH: deviceCanvas.screenH
                isPhoneAspect: deviceCanvas.isPhoneAspect
            }

            // =================================================================
            // 2. STATUS BAR (Top left)
            // =================================================================
            Item {
                id: statusBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: deviceCanvas.marginL
                anchors.rightMargin: deviceCanvas.marginR
                anchors.topMargin: Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (11.0 / 288.0) : (14.0 / 475.0)))
                height: 20
                opacity: root.statusOpacity

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.statusTime
                    color: root.statusColor
                    font.family: "IBM Plex Mono, JetBrains Mono, SF Mono, Consolas, monospace"
                    font.pixelSize: Math.max(9, Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (9.5 / 288.0) : (11.0 / 475.0))))
                    font.letterSpacing: 1.1
                    font.weight: Font.Medium
                }
            }

            // =================================================================
            // 3. MAIN ANIMATING LOCKUP (Mark + Wordmark + Rule + Endorsement)
            // =================================================================
            Item {
                id: lockupContainer

                readonly property real markSize: deviceCanvas.symbolH
                readonly property real markGap: Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (17.0 / 288.0) : (26.0 / 475.0)))
                readonly property real pulseTextPixelSize: Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (32.0 / 288.0) : (52.0 / 475.0)))
                readonly property real gcsTextPixelSize: Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (26.5 / 288.0) : (43.0 / 475.0)))

                // Unclipped width of the wordmark (Pulse + GCS)
                readonly property real wordmarkFullWidth: wordmarkMeasureItem.implicitWidth
                readonly property real lockupFullWidth: markSize + markGap + wordmarkFullWidth

                // Dynamic width during 420-620ms expansion (Wordmark unclips to the right)
                readonly property real currentWordmarkWidth: (markGap + wordmarkFullWidth) * root.wordmarkOpenProgress
                readonly property real currentLockupWidth: markSize + currentWordmarkWidth

                // Position Interpolation:
                // Start (0% - 27%): Centered on screen (50% W, 50% H with translate(-50%, -50%))
                // End   (41% - 100%): Reading Corner (4.5% W, 63.9% H tablet / 62.1% H phone with translate(0, 0))
                readonly property real startX: (deviceCanvas.screenW - currentLockupWidth) * 0.5
                readonly property real startY: (deviceCanvas.screenH - markSize) * 0.5

                readonly property real endX: deviceCanvas.marginL
                readonly property real endY: deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? 0.621 : 0.639)

                x: Math.round(startX + (endX - startX) * root.travelProgress)
                y: Math.round(startY + (endY - startY) * root.travelProgress)
                width: currentLockupWidth
                height: markSize + markSize * 0.70

                // -------------------------------------------------------------
                // A. VECTOR APERTURE MARK (Concentric Arcs + Diamond Core)
                // -------------------------------------------------------------
                PulseGCSMark {
                    x: 0
                    y: 0
                    markSize: lockupContainer.markSize
                    arcColor: root.arcColor
                    coreColor: "#00C4DE"
                    arcDrawProgress: root.arcDrawProgress
                    arcOpacity: root.arcOpacity
                    coreScale: root.coreScale
                    coreOpacity: root.coreOpacity
                }

                // -------------------------------------------------------------
                // B. HIDDEN MEASUREMENT ITEM (For layout calculation)
                // -------------------------------------------------------------
                Item {
                    id: wordmarkMeasureItem
                    visible: false
                    implicitWidth: pulseMeasure.implicitWidth + Math.round(lockupContainer.gcsTextPixelSize * 0.08) + gcsMeasure.implicitWidth
                    implicitHeight: lockupContainer.markSize

                    Text {
                        id: pulseMeasure
                        text: "Pulse"
                        font.family: "IBM Plex Sans, Archivo, -apple-system, sans-serif"
                        font.pixelSize: lockupContainer.pulseTextPixelSize
                        font.weight: Font.Medium
                        font.letterSpacing: -0.028 * lockupContainer.pulseTextPixelSize
                    }
                    Text {
                        id: gcsMeasure
                        text: "GCS"
                        font.family: "IBM Plex Mono, JetBrains Mono, SF Mono, monospace"
                        font.pixelSize: lockupContainer.gcsTextPixelSize
                        font.weight: Font.Medium
                        font.letterSpacing: 0
                    }
                }

                // -------------------------------------------------------------
                // C. EXPANDING / UNCLIPPING WORDMARK ("PulseGCS")
                // -------------------------------------------------------------
                Item {
                    id: wordmarkClipItem
                    x: lockupContainer.markSize
                    y: 0
                    width: lockupContainer.currentWordmarkWidth
                    height: lockupContainer.markSize
                    clip: true
                    opacity: root.wordmarkOpacity

                    Item {
                        id: wordmarkInnerContainer
                        x: lockupContainer.markGap
                        anchors.verticalCenter: parent.verticalCenter
                        width: wordmarkMeasureItem.implicitWidth
                        height: lockupContainer.markSize

                        Text {
                            id: pulseText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Pulse"
                            color: root.wordmarkPulseColor
                            font.family: "IBM Plex Sans, Archivo, -apple-system, sans-serif"
                            font.pixelSize: lockupContainer.pulseTextPixelSize
                            font.weight: Font.Medium
                            font.letterSpacing: -0.028 * lockupContainer.pulseTextPixelSize
                        }

                        Text {
                            id: gcsText
                            anchors.left: pulseText.right
                            anchors.leftMargin: Math.round(lockupContainer.gcsTextPixelSize * 0.08)
                            anchors.baseline: pulseText.baseline
                            text: "GCS"
                            color: root.currentEdition.accent
                            font.family: "IBM Plex Mono, JetBrains Mono, SF Mono, monospace"
                            font.pixelSize: lockupContainer.gcsTextPixelSize
                            font.weight: Font.Medium
                            font.letterSpacing: 0
                        }
                    }
                }

                // -------------------------------------------------------------
                // D. 1PX DIVIDING RULE (Draws left-to-right beneath mark)
                // -------------------------------------------------------------
                Rectangle {
                    id: dividingRule
                    x: 0
                    y: lockupContainer.markSize + Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (10.0 / 288.0) : (15.0 / 475.0)))
                    width: lockupContainer.lockupFullWidth
                    height: 1
                    color: root.ruleColor
                    opacity: root.ruleOpacity
                    transformOrigin: Item.Left
                    scale: root.ruleDrawProgress
                }

                // -------------------------------------------------------------
                // E. ENDORSEMENT ("POWERED BY SKYX AEROSPACE")
                // -------------------------------------------------------------
                Row {
                    id: endorsementRow
                    x: 0
                    y: dividingRule.y + 1 + Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (9.0 / 288.0) : (13.0 / 475.0))) + root.endorsementTranslateY
                    spacing: Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (7.0 / 288.0) : (10.0 / 475.0)))
                    opacity: root.endorsementOpacity

                    Text {
                        text: root.poweredByLabel
                        color: root.endorsementDimColor
                        font.family: "IBM Plex Sans, Archivo, -apple-system, sans-serif"
                        font.pixelSize: Math.max(7, Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (8.5 / 288.0) : (12.0 / 475.0))))
                        font.letterSpacing: 1.6
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.vendorLabel
                        color: root.endorsementLitColor
                        font.family: "IBM Plex Sans, Archivo, -apple-system, sans-serif"
                        font.pixelSize: Math.max(8, Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (9.5 / 288.0) : (13.0 / 475.0))))
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // =================================================================
            // 4. BUILD METADATA PLATE (4-line vertical stack, right-aligned)
            // =================================================================
            Column {
                id: buildPlate
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: deviceCanvas.marginR
                anchors.bottomMargin: deviceCanvas.marginB
                spacing: Math.round(deviceCanvas.screenH * (6.0 / 475.0))
                opacity: root.plateOpacity

                Text {
                    anchors.right: parent.right
                    text: "VERSION"
                    color: root.metaDimColor
                    font.family: "IBM Plex Mono, JetBrains Mono, SF Mono, monospace"
                    font.pixelSize: Math.max(7, Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (8.0 / 288.0) : (10.0 / 475.0))))
                    font.letterSpacing: 1.0
                }

                Text {
                    anchors.right: parent.right
                    text: root.appVersion
                    color: root.metaLitColor
                    font.family: "IBM Plex Mono, JetBrains Mono, SF Mono, monospace"
                    font.pixelSize: Math.max(9, Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (11.0 / 288.0) : (14.0 / 475.0))))
                    font.weight: Font.Medium
                }

                Text {
                    anchors.right: parent.right
                    text: "BUILD"
                    color: root.metaDimColor
                    font.family: "IBM Plex Mono, JetBrains Mono, SF Mono, monospace"
                    font.pixelSize: Math.max(7, Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (8.0 / 288.0) : (10.0 / 475.0))))
                    font.letterSpacing: 1.0
                    topPadding: Math.round(deviceCanvas.screenH * (6.0 / 475.0))
                }

                Text {
                    anchors.right: parent.right
                    text: root.buildNumber
                    color: root.metaLitColor
                    font.family: "IBM Plex Mono, JetBrains Mono, SF Mono, monospace"
                    font.pixelSize: Math.max(9, Math.round(deviceCanvas.screenH * (deviceCanvas.isPhoneAspect ? (11.0 / 288.0) : (14.0 / 475.0))))
                    font.weight: Font.Medium
                }
            }
        }
    }

