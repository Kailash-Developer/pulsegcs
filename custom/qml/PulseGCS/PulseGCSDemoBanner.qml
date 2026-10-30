import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import PulseGCS 1.0

// ============================================================================
// PulseGCSDemoBanner
// High-Visibility Simulation & Demo Flight Hazard Banner (M3-US10)
//
// Adheres strictly to PulseGCS design language:
// 1. Uses canonical PulseGCSTokens for both Indoor (Dark) and Outdoor (Light).
// 2. Uses ScreenTools.normalFontFamily, proper font scales, and Text.QtRendering.
// 3. UI-Independent: Decoupled from internal FlyView/PlanView layouts.
// ============================================================================

Rectangle {
    id: root

    readonly property bool isOutdoor: PulseGCSTokens.isOutdoor

    // Controlled strictly by the headless simulation manager
    visible: PulseGCSDemoModeManager.isDemoModeActive
    // Signal emitted when exit button is triggered
    signal exitClicked()

    height: visible ? 38 : 0
    clip: true

    // Theme-aware warning surface
    color: isOutdoor ? "#FFFBEB" : "#1A1508" // Subtle warm amber tint surface
    border.color: PulseGCSTokens.statusColor("warn", isOutdoor)
    border.width: 1

    Behavior on height {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // Pulsing warning indicator dot
        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: PulseGCSTokens.statusColor("warn", root.isOutdoor)
            Layout.alignment: Qt.AlignVCenter

            SequentialAnimation on opacity {
                running: root.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
            }
        }

        // Title and Descriptive Subtext
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: qsTr("DEMO FLIGHT MODE ACTIVE")
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.6
                renderType: Text.QtRendering
            }

            Rectangle {
                width: 1
                height: 12
                color: PulseGCSTokens.divider
            }

            Text {
                text: qsTr("Simulated Telemetry • Live Aircraft Commands Disabled")
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                renderType: Text.QtRendering
            }
        }

        // Status Pill for Simulator Identity
        PulseGCSStatusPill {
            status: "warn"
            text: qsTr("SIMULATOR")
            isOutdoor: root.isOutdoor
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true // Spacer
        }

        // Clean Action Button
        Button {
            id: exitBtn
            text: qsTr("Exit Demo")
            implicitHeight: 24
            implicitWidth: Math.max(76, exitText.implicitWidth + 20)
            Layout.alignment: Qt.AlignVCenter

            contentItem: Text {
                id: exitText
                text: exitBtn.text
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.statusColor("warn", root.isOutdoor)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }

            background: Rectangle {
                radius: 4
                color: exitBtn.pressed
                       ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                       : (exitBtn.hovered
                          ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfacePanel)
                          : "transparent")
                border.color: PulseGCSTokens.statusColor("warn", root.isOutdoor)
                border.width: 1
            }

            onClicked: {
                root.exitClicked()
                PulseGCSDemoModeManager.stopDemoMode()
            }
        }
    }
}
