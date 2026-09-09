import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PulseGCS 1.0

Rectangle {
    id: root
    width: 1024
    height: 640
    color: "#030B14" // Ambient dark stage surrounding the active device canvas
    focus: true

    // =========================================================================
    // SIGNALS & PUBLIC PROPERTIES
    // =========================================================================
    signal splashCompleted()

    // Configuration & State
    property bool isProductionMode: true    // true: 1.4s Production Single-Shot (1400ms ceiling), false: 5.2s Review Loop
    property bool loopAnimation: false
    property bool isPlaying: true
    property real animationSpeed: 1.0
    property bool reducedMotion: false
    property bool showHud: true
    property int devicePreset: 1            // 0: Responsive/Fill, 1: Tablet 16:10 (760x475), 2: Phone 19.5:9 (624x288), 3: Desktop 16:9 (960x540), 4: Field 4:3 (800x600)
    property int editionIndex: 0            // 0: Aperture Cyan (#00C4DE), 1: Sentinel Gold (#E5A93C), 2: Tactical Orange (#FF6B35)
    property int durationPreset: 0            // 0: 1.4s, 1: 2.5s, 2: 5.0s (production only)

    // Configurable Build Metadata (Reads from build config in production)
    property string appVersion: "v2.4.1"
    property string buildNumber: "3120"
    property string poweredByLabel: "POWERED BY"
    property string vendorLabel: "SKYX AEROSPACE"
    property string statusTime: "10:24"

    // =========================================================================
    // COLOR TOKENS & EDITIONS (Section 02 Source of Truth)
    // =========================================================================
    readonly property var editions: [
        { name: "Aperture Cyan (Standard)", accent: "#00C4DE", accentR: 0,   accentG: 196, accentB: 222 },
        { name: "Sentinel Gold (Enterprise)", accent: "#E5A93C", accentR: 229, accentG: 169, accentB: 60  },
        { name: "Tactical Orange (Mil/Gov)",  accent: "#FF6B35", accentR: 255, accentG: 107, accentB: 53  }
    ]
    readonly property var currentEdition: root.editions[root.editionIndex]

    readonly property color groundColor: "#071A2B"        // Flat deep navy ground (#071A2B)
    readonly property color watermarkColor: "#0D2A40"     // Background watermark symbol (#0D2A40)
    readonly property color arcColor: "#EAF2F7"           // Arcs stroke signal white (#EAF2F7)
    readonly property color wordmarkPulseColor: "#EAF2F7" // "Pulse" typography (#EAF2F7)
    readonly property color statusColor: "#7E96AB"        // Status bar text (#7E96AB)
    readonly property color ruleColor: "#1E3B52"          // 1px dividing rule (#1E3B52)
    readonly property color endorsementDimColor: "#7E96AB"// "POWERED BY" (#7E96AB)
    readonly property color endorsementLitColor: "#EAF2F7"// "SKYX AEROSPACE" (#EAF2F7)
    readonly property color metaDimColor: "#5E778C"       // "VERSION" / "BUILD" labels (#5E778C)
    readonly property color metaLitColor: "#EAF2F7"       // "v2.4.1" / "3120" values (#EAF2F7)

    // =========================================================================
    // TIMING ENGINE & NORMALIZED CHOREOGRAPHY
    // =========================================================================
    // Full Loop Duration: 5200 ms (Review Mode) / 1400 ms (Production Mode)
    readonly property real totalDuration: {
        if (!root.isProductionMode) return 5200.0
        if (root.durationPreset === 1) return 2500.0
        if (root.durationPreset === 2) return 5000.0
        return 1400.0
    }
    property real currentTimestampMs: 0.0
    readonly property real normalizedProgress: Math.min(1.0, Math.max(0.0, root.currentTimestampMs / root.totalDuration))

    // Universal Easing: cubic-bezier(0.3, 0.02, 0.16, 1.0)
    function solveCubicBezier(p1x, p1y, p2x, p2y, t) {
        if (t <= 0.0) return 0.0;
        if (t >= 1.0) return 1.0;
        var u = t;
        for (var i = 0; i < 8; i++) {
            var currentX = 3.0 * (1.0 - u) * (1.0 - u) * u * p1x + 3.0 * (1.0 - u) * u * u * p2x + u * u * u - t;
            if (Math.abs(currentX) < 1e-5) break;
            var currentSlope = 3.0 * (1.0 - u) * (1.0 - u) * p1x + 6.0 * (1.0 - u) * u * (p2x - p1x) + 3.0 * u * u * (1.0 - p2x);
            if (Math.abs(currentSlope) < 1e-5) break;
            u -= currentX / currentSlope;
        }
        u = Math.max(0.0, Math.min(1.0, u));
        return 3.0 * (1.0 - u) * (1.0 - u) * u * p1y + 3.0 * (1.0 - u) * u * u * p2y + u * u * u;
    }

    // Standard motion curves
    function easeUniversal(t) { return root.solveCubicBezier(0.30, 0.02, 0.16, 1.00, t); }
    function easeArcs(t)      { return root.solveCubicBezier(0.22, 0.70, 0.20, 1.00, t); }
    function easeSmooth(t)    { return root.solveCubicBezier(0.25, 0.10, 0.25, 1.00, t); }

    // Keyframe Evaluators mapped directly from CSS @keyframes
    // 1. Status Bar: 000-200ms (0%-11% of loop)
    readonly property real statusOpacity: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            var t = root.currentTimestampMs / 200.0;
            return Math.min(1.0, Math.max(0.0, t));
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 4.0) return 0.0;
            if (p < 11.0) return (p - 4.0) / 7.0;
            if (p <= 92.0) return 1.0;
            if (p < 99.0) return 1.0 - (p - 92.0) / 7.0;
            return 0.0;
        }
    }

    // 2. Arcs Draw: 060-320ms (3%-15% of loop) -> stroke-dashoffset: 72 -> 0
    readonly property real arcDrawProgress: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 60.0) return 0.0;
            if (root.currentTimestampMs >= 320.0) return 1.0;
            return root.easeArcs((root.currentTimestampMs - 60.0) / 260.0);
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 3.0) return 0.0;
            if (p < 15.0) return root.easeArcs((p - 3.0) / 12.0);
            return 1.0;
        }
    }

    readonly property real arcOpacity: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 60.0) return 0.0;
            return 1.0;
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 3.0) return 0.0;
            if (p <= 92.0) return 1.0;
            if (p < 99.0) return 1.0 - (p - 92.0) / 7.0;
            return 0.0;
        }
    }

    // 3. Core Scale & Opacity: 280-420ms (10%-19% of loop) -> scale 0.3 -> 1.0, opacity 0 -> 1
    readonly property real coreScale: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 280.0) return 0.3;
            if (root.currentTimestampMs >= 420.0) return 1.0;
            var t = root.easeArcs((root.currentTimestampMs - 280.0) / 140.0);
            return 0.3 + 0.7 * t;
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 10.0) return 0.3;
            if (p < 19.0) {
                var t = root.easeArcs((p - 10.0) / 9.0);
                return 0.3 + 0.7 * t;
            }
            return 1.0;
        }
    }

    readonly property real coreOpacity: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 280.0) return 0.0;
            if (root.currentTimestampMs >= 420.0) return 1.0;
            return (root.currentTimestampMs - 280.0) / 140.0;
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 10.0) return 0.0;
            if (p < 19.0) return (p - 10.0) / 9.0;
            if (p <= 92.0) return 1.0;
            if (p < 99.0) return 1.0 - (p - 92.0) / 7.0;
            return 0.0;
        }
    }

    // 4. Wordmark Unclip / Open: 420-620ms (13%-27% of loop) -> width 0 -> full
    readonly property real wordmarkOpenProgress: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 420.0) return 0.0;
            if (root.currentTimestampMs >= 620.0) return 1.0;
            return root.easeUniversal((root.currentTimestampMs - 420.0) / 200.0);
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 13.0) return 0.0;
            if (p < 27.0) return root.easeUniversal((p - 13.0) / 14.0);
            return 1.0;
        }
    }

    readonly property real wordmarkOpacity: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 420.0) return 0.0;
            if (root.currentTimestampMs < 500.0) return (root.currentTimestampMs - 420.0) / 80.0;
            return 1.0;
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 13.0) return 0.0;
            if (p < 18.0) return (p - 13.0) / 5.0;
            if (p <= 92.0) return 1.0;
            if (p < 99.0) return 1.0 - (p - 92.0) / 7.0;
            return 0.0;
        }
    }

    // 5. Lockup Travel: 660-860ms (27%-41% of loop) -> Center (50%, 50%) to Reading Corner (4.5%, 63.9% / 62.1%)
    readonly property real travelProgress: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 660.0) return 0.0;
            if (root.currentTimestampMs >= 860.0) return 1.0;
            return root.easeUniversal((root.currentTimestampMs - 660.0) / 200.0);
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 27.0) return 0.0;
            if (p < 41.0) return root.easeUniversal((p - 27.0) / 14.0);
            return 1.0;
        }
    }

    // 6. Dividing Rule: 860-1000ms (43%-55% of loop) -> scaleX: 0 -> 1
    readonly property real ruleDrawProgress: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 860.0) return 0.0;
            if (root.currentTimestampMs >= 1000.0) return 1.0;
            return root.easeUniversal((root.currentTimestampMs - 860.0) / 140.0);
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 43.0) return 0.0;
            if (p < 55.0) return root.easeUniversal((p - 43.0) / 12.0);
            return 1.0;
        }
    }

    readonly property real ruleOpacity: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 860.0) return 0.0;
            return 1.0;
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 43.0) return 0.0;
            if (p <= 92.0) return 1.0;
            if (p < 99.0) return 1.0 - (p - 92.0) / 7.0;
            return 0.0;
        }
    }

    // 7. Endorsement ("POWERED BY SKYX AEROSPACE"): 960-1120ms (49%-59% of loop) -> translateY 4px -> 0, opacity 0 -> 1
    readonly property real endorsementOpacity: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 960.0) return 0.0;
            if (root.currentTimestampMs >= 1120.0) return 1.0;
            return root.easeSmooth((root.currentTimestampMs - 960.0) / 160.0);
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 49.0) return 0.0;
            if (p < 59.0) return root.easeSmooth((p - 49.0) / 10.0);
            if (p <= 92.0) return 1.0;
            if (p < 99.0) return 1.0 - (p - 92.0) / 7.0;
            return 0.0;
        }
    }

    readonly property real endorsementTranslateY: {
        if (root.reducedMotion) return 0.0;
        return (1.0 - root.endorsementOpacity) * 4.0;
    }

    // 8. Build Plate ("VERSION v2.4.1" / "BUILD 3120"): 960-1120ms (53%-63% of loop)
    readonly property real plateOpacity: {
        if (root.reducedMotion) return 1.0;
        if (root.isProductionMode) {
            if (root.currentTimestampMs < 960.0) return 0.0;
            if (root.currentTimestampMs >= 1120.0) return 1.0;
            return root.easeSmooth((root.currentTimestampMs - 960.0) / 160.0);
        } else {
            var p = root.normalizedProgress * 100.0;
            if (p < 53.0) return 0.0;
            if (p < 63.0) return root.easeSmooth((p - 53.0) / 10.0);
            if (p <= 92.0) return 1.0;
            if (p < 99.0) return 1.0 - (p - 92.0) / 7.0;
            return 0.0;
        }
    }

    // Animation Driver Timer (60/120 Hz update)
    Timer {
        id: frameTimer
        interval: 16
        repeat: true
        running: root.isPlaying
        onTriggered: {
            var step = 16.0 * root.animationSpeed;
            var next = root.currentTimestampMs + step;
            if (next >= root.totalDuration) {
                if (root.isProductionMode) {
                    root.currentTimestampMs = root.totalDuration;
                    root.isPlaying = false;
                    root.splashCompleted();
                } else if (root.loopAnimation) {
                    root.currentTimestampMs = next % root.totalDuration;
                } else {
                    root.currentTimestampMs = root.totalDuration;
                    root.isPlaying = false;
                }
            } else {
                root.currentTimestampMs = next;
            }
        }
    }

    // =========================================================================
    // KEYBOARD SHORTCUTS & INTERACTIVE CONTROLS
    // =========================================================================
    function togglePlay() { root.isPlaying = !root.isPlaying; }
    function restartAnimation() {
        root.currentTimestampMs = 0.0;
        root.isPlaying = true;
    }

    Keys.onSpacePressed: root.togglePlay()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_R) {
            root.restartAnimation();
        } else if (event.key === Qt.Key_M) {
            root.reducedMotion = !root.reducedMotion;
        } else if (event.key === Qt.Key_E) {
            root.editionIndex = (root.editionIndex + 1) % root.editions.length;
        } else if (event.key === Qt.Key_P) {
            root.isProductionMode = !root.isProductionMode;
            root.restartAnimation();
        } else if (event.key === Qt.Key_H) {
            root.showHud = !root.showHud;
        } else if (event.key === Qt.Key_1) {
            root.devicePreset = 1; // Tablet
        } else if (event.key === Qt.Key_2) {
            root.devicePreset = 2; // Phone
        } else if (event.key === Qt.Key_3) {
            root.devicePreset = 3; // Desktop
        } else if (event.key === Qt.Key_4) {
            root.devicePreset = 4; // Field
        } else if (event.key === Qt.Key_0) {
            root.devicePreset = 0; // Responsive
        } else if (event.key === Qt.Key_4 && root.isProductionMode) {
            root.durationPreset = 0
            root.restartAnimation()
        } else if (event.key === Qt.Key_5 && root.isProductionMode) {
            root.durationPreset = 1
            root.restartAnimation()
        } else if (event.key === Qt.Key_6 && root.isProductionMode) {
            root.durationPreset = 2
            root.restartAnimation()
        }
    }

    // =========================================================================
    // VIEWPORT CONTAINER & ASPECT RATIO MANAGEMENT
    // =========================================================================
    Item {
        id: viewportContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.showHud ? -36 : 0

        // Device Presets:
        // 0: Fill available stage space
        // 1: Tablet 10.1" (16:10, 760 x 475)
        // 2: Phone (19.5:9, 624 x 288)
        // 3: Desktop (16:9, 960 x 540)
        // 4: Field Controller (4:3, 800 x 600)
        width: {
            var availW = root.width - (root.showHud ? 32 : 0);
            var availH = root.height - (root.showHud ? 110 : 0);
            if (root.devicePreset === 1) return Math.min(availW, availH * (760.0 / 475.0));
            if (root.devicePreset === 2) return Math.min(availW, availH * (624.0 / 288.0));
            if (root.devicePreset === 3) return Math.min(availW, availH * (16.0 / 9.0));
            if (root.devicePreset === 4) return Math.min(availW, availH * (4.0 / 3.0));
            return availW;
        }
        height: {
            if (root.devicePreset === 1) return width * (475.0 / 760.0);
            if (root.devicePreset === 2) return width * (288.0 / 624.0);
            if (root.devicePreset === 3) return width * (9.0 / 16.0);
            if (root.devicePreset === 4) return width * (3.0 / 4.0);
            var availH = root.height - (root.showHud ? 110 : 0);
            return availH;
        }

        // =====================================================================
        // SECTION 02 CANVAS GROUND
        // =====================================================================
        Rectangle {
            id: deviceCanvas
            anchors.fill: parent
            color: root.groundColor
            clip: true

            // Device bezel outline for clear inspection
            border.color: "#1E3B52"
            border.width: root.devicePreset !== 0 ? 1 : 0

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

    // =========================================================================
    // PROTOTYPE REVIEW HUD & INTERACTIVE EVALUATION TOOLBAR
    // (Non-intrusive bottom toolbar with keyboard shortcuts and scrubber)
    // =========================================================================
    Rectangle {
        id: reviewHud
        visible: root.showHud
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 78
        color: "#0B1522"
        border.color: "#182F45"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // Row 1: Interactive Timeline Scrubber & Timing Readouts
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.isProductionMode ? ("PROD (" + (root.durationPreset === 1 ? "2.5s" : root.durationPreset === 2 ? "5.0s" : "1.4s") + ")") : "REVIEW (5.2s)"
                    color: root.currentEdition.accent
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    text: (root.currentTimestampMs / 1000.0).toFixed(2) + "s / " + (root.totalDuration / 1000.0).toFixed(2) + "s"
                    color: "#A0B8CC"
                    font.family: "monospace"
                    font.pixelSize: 11
                }

                Slider {
                    id: timeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: root.totalDuration
                    value: root.currentTimestampMs
                    onMoved: root.currentTimestampMs = value
                }

                Text {
                    text: Math.round(root.normalizedProgress * 100) + "%"
                    color: "#A0B8CC"
                    font.family: "monospace"
                    font.pixelSize: 11
                    Layout.preferredWidth: 36
                }
            }

            // Row 2: Control Action Buttons & Preset Selectors
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Button {
                    text: root.isPlaying ? "Pause [Space]" : "Play [Space]"
                    onClicked: root.togglePlay()
                    Layout.preferredHeight: 28
                }

                Button {
                    text: "Restart [R]"
                    onClicked: root.restartAnimation()
                    Layout.preferredHeight: 28
                }

                Button {
                    text: "Mode: " + (root.isProductionMode ? "1.4s Prod" : "5.2s Loop") + " [P]"
                    onClicked: {
                        root.isProductionMode = !root.isProductionMode;
                        root.restartAnimation();
                    }
                    Layout.preferredHeight: 28
                }

                Button {
                    text: "Speed: " + root.animationSpeed + "x"
                    onClicked: {
                        if (root.animationSpeed === 1.0) root.animationSpeed = 0.5;
                        else if (root.animationSpeed === 0.5) root.animationSpeed = 0.25;
                        else if (root.animationSpeed === 0.25) root.animationSpeed = 2.0;
                        else root.animationSpeed = 1.0;
                    }
                    Layout.preferredHeight: 28
                }

                Button {
                    text: "Reduced Motion: " + (root.reducedMotion ? "ON" : "OFF") + " [M]"
                    onClicked: root.reducedMotion = !root.reducedMotion
                    Layout.preferredHeight: 28
                }

                Button {
                    text: "Edition: " + root.currentEdition.name.split(" ")[0] + " [E]"
                    onClicked: root.editionIndex = (root.editionIndex + 1) % root.editions.length
                    Layout.preferredHeight: 28
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Presets: [1] Tablet [2] Phone [3] 16:9 [4] 4:3 [0] Fill | Durations: [4] 1.4s [5] 2.5s [6] 5s | [H] HUD"
                    color: "#6C879B"
                    font.family: "monospace"
                    font.pixelSize: 10
                }
            }
        }
    }
}
