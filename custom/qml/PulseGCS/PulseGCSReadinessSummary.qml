import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var activeAircraftInfo: PulseGCSAircraftManager.activeAircraftInfo
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    implicitWidth: 380
    implicitHeight: mainLayout.implicitHeight + 24
    radius: PulseGCSTokens.radiusCard
    color: isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
    border.color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
    border.width: 1

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Section 1: Hero Readiness Card
        PulseGCSReadinessHero {
            Layout.fillWidth: true
            isOutdoor: root.isOutdoor
            status: {
                if (!root.activeVehicle) return "unknown"
                if (root.activeAircraftInfo && root.activeAircraftInfo.connectionState === PulseGCSAircraft.ParameterSync) return "checking"
                if (root.activeVehicle.healthAndArmingCheckReport && root.activeVehicle.healthAndArmingCheckReport.supported) {
                    if (root.activeVehicle.healthAndArmingCheckReport.canArm) return "ready"
                    if (root.activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count > 0) return "not_ready"
                }
                if (root.activeVehicle.armed) return "ready"
                return "ready"
            }
            batteryText: {
                if (!root.activeVehicle || !root.activeVehicle.battery) return ""
                var percent = root.activeVehicle.battery.percentRemaining.value
                var volts = root.activeVehicle.battery.voltage.value
                if (percent >= 0) {
                    return Math.round(percent) + "%" + (volts > 0 ? " (" + volts.toFixed(1) + "V)" : "")
                }
                return ""
            }
            gpsText: {
                if (!root.activeVehicle || !root.activeVehicle.gps) return ""
                var sats = root.activeVehicle.gps.count.value
                var lock = root.activeVehicle.gps.lock.value
                if (sats > 0) {
                    return sats + " Sats" + (lock >= 3 ? " (3D)" : "")
                }
                return ""
            }
            linkText: {
                if (!root.activeAircraftInfo) return ""
                if (root.activeAircraftInfo.rssi !== 0) return root.activeAircraftInfo.rssi + " dBm"
                return qsTr("Active")
            }
        }

        // Section 2: Health Checks Header
        Text {
            text: qsTr("PRE-FLIGHT READINESS CHECKS")
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 0.5
            color: PulseGCSTokens.metaText(root.isOutdoor)
            renderType: Text.QtRendering
        }

        // Checks Grid / Column
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Check 1: Battery
            PulseGCSReadinessCheck {
                Layout.fillWidth: true
                name: qsTr("Battery System")
                isOutdoor: root.isOutdoor
                status: {
                    if (!root.activeVehicle || !root.activeVehicle.battery) return "neutral"
                    var percent = root.activeVehicle.battery.percentRemaining.value
                    if (percent < 0) return "neutral"
                    if (percent < 20) return "err"
                    if (percent < 30) return "warn"
                    return "ok"
                }
                valueText: {
                    if (!root.activeVehicle || !root.activeVehicle.battery) return qsTr("Unknown")
                    var percent = root.activeVehicle.battery.percentRemaining.value
                    var volts = root.activeVehicle.battery.voltage.value
                    if (percent >= 0) return Math.round(percent) + "%" + (volts > 0 ? " • " + volts.toFixed(1) + "V" : "")
                    return qsTr("N/A")
                }
                detailText: {
                    if (!root.activeVehicle || !root.activeVehicle.battery) return ""
                    var percent = root.activeVehicle.battery.percentRemaining.value
                    if (percent >= 0 && percent < 20) return qsTr("Critically low battery (< 20%)")
                    if (percent >= 0 && percent < 30) return qsTr("Low battery warning (< 30%)")
                    return ""
                }
            }

            // Check 2: GPS Position & Fix
            PulseGCSReadinessCheck {
                Layout.fillWidth: true
                name: qsTr("GPS & Navigation")
                isOutdoor: root.isOutdoor
                status: {
                    if (!root.activeVehicle || !root.activeVehicle.gps) return "neutral"
                    var sats = root.activeVehicle.gps.count.value
                    var lock = root.activeVehicle.gps.lock.value
                    if (sats >= 8 && lock >= 3) return "ok"
                    if (sats >= 4) return "warn"
                    if (sats >= 0) return "err"
                    return "neutral"
                }
                valueText: {
                    if (!root.activeVehicle || !root.activeVehicle.gps) return qsTr("No GPS Data")
                    var sats = root.activeVehicle.gps.count.value
                    var lock = root.activeVehicle.gps.lock.value
                    if (sats >= 0) return sats + " Sats • " + (lock >= 3 ? "3D Lock" : "Acquiring")
                    return qsTr("No Lock")
                }
                detailText: {
                    if (!root.activeVehicle || !root.activeVehicle.gps) return ""
                    var sats = root.activeVehicle.gps.count.value
                    if (sats < 6) return qsTr("Insufficient satellites for precision navigation")
                    return ""
                }
            }

            // Check 3: Telemetry & Parameter Sync
            PulseGCSReadinessCheck {
                Layout.fillWidth: true
                name: qsTr("Telemetry & Parameters")
                isOutdoor: root.isOutdoor
                status: {
                    if (!root.activeVehicle) return "neutral"
                    if (root.activeAircraftInfo && root.activeAircraftInfo.connectionState === PulseGCSAircraft.ParameterSync) return "checking"
                    if (root.activeVehicle.parameterManager.parametersReady) return "ok"
                    return "warn"
                }
                valueText: {
                    if (!root.activeVehicle) return qsTr("Disconnected")
                    if (root.activeAircraftInfo && root.activeAircraftInfo.connectionState === PulseGCSAircraft.ParameterSync) {
                        return Math.round(root.activeAircraftInfo.parameterLoadProgress * 100) + "%"
                    }
                    if (root.activeVehicle.parameterManager.parametersReady) return qsTr("Synchronized")
                    return qsTr("Syncing...")
                }
                detailText: {
                    if (root.activeAircraftInfo && root.activeAircraftInfo.connectionState === PulseGCSAircraft.ParameterSync) {
                        return qsTr("Loading autopilot parameter tables")
                    }
                    return ""
                }
            }

            // Check 4: Sensors Calibration (Compass / Gyro / Accel)
            PulseGCSReadinessCheck {
                Layout.fillWidth: true
                name: qsTr("Sensors & IMU")
                isOutdoor: root.isOutdoor
                status: {
                    if (!root.activeVehicle) return "neutral"
                    if (root.activeVehicle.sensorsUnhealthy) return "err"
                    if (root.activeVehicle.sensorsCalibrated) return "ok"
                    return "ok"
                }
                valueText: {
                    if (!root.activeVehicle) return qsTr("Unknown")
                    if (root.activeVehicle.sensorsUnhealthy) return qsTr("Unhealthy")
                    return qsTr("Calibrated")
                }
                detailText: {
                    if (root.activeVehicle && root.activeVehicle.sensorsUnhealthy) {
                        return qsTr("IMU / Compass requires sensor calibration")
                    }
                    return ""
                }
            }

            // Check 5: RC Signal (M2 Readiness)
            PulseGCSReadinessCheck {
                Layout.fillWidth: true
                name: qsTr("RC Signal")
                isOutdoor: root.isOutdoor
                status: {
                    if (!root.activeVehicle) return "neutral"
                    let isRCLost = (root.activeVehicle.rcRSSI && root.activeVehicle.rcRSSI.value === 255)
                        || ((root.activeVehicle.sensorsUnhealthyBits & 0x10000) !== 0)
                    if (isRCLost) return "warn"
                    return "ok"
                }
                valueText: {
                    if (!root.activeVehicle) return qsTr("Unknown")
                    let isRCLost = (root.activeVehicle.rcRSSI && root.activeVehicle.rcRSSI.value === 255)
                        || ((root.activeVehicle.sensorsUnhealthyBits & 0x10000) !== 0)
                    if (isRCLost) return qsTr("Not Detected")
                    if (root.activeVehicle.rcRSSI && root.activeVehicle.rcRSSI.value >= 0 && root.activeVehicle.rcRSSI.value <= 100) {
                        return qsTr("%1% Signal").arg(Math.round(root.activeVehicle.rcRSSI.value))
                    }
                    return qsTr("Active")
                }
                detailText: {
                    if (!root.activeVehicle) return ""
                    let isRCLost = (root.activeVehicle.rcRSSI && root.activeVehicle.rcRSSI.value === 255)
                        || ((root.activeVehicle.sensorsUnhealthyBits & 0x10000) !== 0)
                    if (isRCLost) {
                        return qsTr("RC transmitter/receiver signal is not detected. GCS telemetry remains healthy.")
                    }
                    return ""
                }
            }
        }

        // Section 3: Actionable Issues List (M2-US07)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.activeVehicle && root.activeVehicle.healthAndArmingCheckReport && root.activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count > 0

            Text {
                text: qsTr("ACTIONABLE ISSUES")
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.5
                color: PulseGCSTokens.metaText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            Repeater {
                model: root.activeVehicle ? root.activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode : null
                delegate: PulseGCSActionableIssue {
                    Layout.fillWidth: true
                    isOutdoor: root.isOutdoor
                    severity: modelData.severity === "error" ? "blocking" : (modelData.severity === "warning" ? "warning" : "info")
                    title: modelData.message
                    description: modelData.description
                    actionText: modelData.severity === "error" ? qsTr("RESOLVE") : qsTr("DETAILS")
                    onActionClicked: {
                        mainWindow.showVehicleConfig()
                    }
                }
            }
        }
    }
}
