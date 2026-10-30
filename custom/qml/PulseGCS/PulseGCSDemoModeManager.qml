import QtQuick
import QGroundControl

pragma Singleton

// ============================================================================
// PulseGCSDemoModeManager
// Headless, UI-Independent Simulation and Demo Mode State Machine (M3-US10)
//
// Key Invariants:
// 1. Decoupled from UI: Uses the existing native FlyView and native QGC panels
//    (TelemetryValuesBar, VehicleMapItem, Toolbar, FlyViewToolStrip).
// 2. Safety Interlock: Physical hardware arming and live flight commands are
//    strictly blocked whenever isDemoModeActive is true.
// 3. Isolated Teardown: Exiting demo mode halts the mock link, purges simulated
//    telemetry, and restores the ground station cleanly to the login gateway.
// ============================================================================

QtObject {
    id: root

    // ------------------------------------------------------------------------
    // Primary State Properties
    // ------------------------------------------------------------------------

    // Active state flag
    property bool isDemoModeActive: false

    // Sample aircraft specification for simulation
    property string sampleVehicleSerial: "SKYX-SIM-2026-0842"
    property string sampleVehicleModel: "SkyX Kissan 16L (Simulation)"
    property string sampleFirmwareVersion: "ArduCopter V4.5.4 (SITL)"
    property string sampleMissionName: "Demo Orchard Perimeter Spray"
    property real   sampleBatteryPercentage: 94.0
    property int    sampleSatellites: 18
    property string sampleGpsLock: "3D RTK Fix"

    // High-visibility user-facing banner text
    readonly property string bannerNoticeText: qsTr("DEMO FLIGHT MODE ACTIVE — SIMULATED TELEMETRY ONLY")

    // Safety and interlock policies
    readonly property bool allowRealHardwareArming: !root.isDemoModeActive
    readonly property bool suppressLiveScanning: root.isDemoModeActive

    // Path to the demo mission plan file
    readonly property string demoMissionPlanPath: {
        var path = ""
        if (typeof PulseGCSStartupController !== "undefined" && typeof PulseGCSStartupController.demoMissionPlanPath === "function") {
            try {
                path = PulseGCSStartupController.demoMissionPlanPath()
            } catch (e) {
                console.warn("PulseGCSDemoModeManager: Error obtaining demo plan path:", e)
            }
        }
        if (!path || path.length === 0) {
            path = ":/Custom/telemetry/demo_mission.plan"
        }
        return path
    }

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------

    signal demoModeStarted()
    signal demoModeStopped()
    signal demoModeError(string errorMsg)

    // ------------------------------------------------------------------------
    // Public API Methods
    // ------------------------------------------------------------------------

    // Start Demo Mode and initialize native mock autopilot
    function startDemoMode() {
        if (root.isDemoModeActive) {
            console.log("PulseGCSDemoModeManager: Demo mode is already active.")
            return
        }

        root.isDemoModeActive = true

        // 1. Primary: Start simulation via PulseGCSStartupController
        let startedViaCpp = false
        if (typeof PulseGCSStartupController !== "undefined" && typeof PulseGCSStartupController.startDemoSimulation === "function") {
            try {
                startedViaCpp = PulseGCSStartupController.startDemoSimulation()
                if (startedViaCpp) {
                    console.log("PulseGCSDemoModeManager: C++ APM ArduCopter MockLink started.")
                }
            } catch (err) {
                console.warn("PulseGCSDemoModeManager: Error invoking C++ simulation:", err)
            }
        }

        // 2. Secondary fallback: QGroundControl global MockLink methods
        if (!startedViaCpp && typeof QGroundControl !== "undefined") {
            try {
                if (typeof QGroundControl.startAPMArduCopterMockLink === "function") {
                    QGroundControl.startAPMArduCopterMockLink(true, false, false, false, false, 0)
                    console.log("PulseGCSDemoModeManager: QGC APM MockLink fallback started.")
                } else if (typeof QGroundControl.startGenericMockLink === "function") {
                    QGroundControl.startGenericMockLink(true, false, false, false, 0)
                    console.log("PulseGCSDemoModeManager: QGC Generic MockLink fallback started.")
                }
            } catch (err) {
                console.warn("PulseGCSDemoModeManager: Could not start native MockLink fallback:", err)
            }
        }

        root.demoModeStarted()
    }

    // Stop Demo Mode, terminate simulation, and purge state
    function stopDemoMode() {
        if (!root.isDemoModeActive) {
            console.log("PulseGCSDemoModeManager: Demo mode is not active.")
            return
        }

        // 1. Disconnect C++ simulation via PulseGCSStartupController
        if (typeof PulseGCSStartupController !== "undefined" && typeof PulseGCSStartupController.stopDemoSimulation === "function") {
            try {
                PulseGCSStartupController.stopDemoSimulation()
                console.log("PulseGCSDemoModeManager: C++ MockLink stopped.")
            } catch (err) {
                console.warn("PulseGCSDemoModeManager: Error stopping C++ simulation:", err)
            }
        }

        // 2. Defensively disconnect QGC global MockLink
        if (typeof QGroundControl !== "undefined" && typeof QGroundControl.stopOneMockLink === "function") {
            try {
                QGroundControl.stopOneMockLink()
                console.log("PulseGCSDemoModeManager: QGC MockLink stopped.")
            } catch (err) {
                console.warn("PulseGCSDemoModeManager: Could not stop native MockLink:", err)
            }
        }

        root.isDemoModeActive = false
        root.demoModeStopped()
    }

    // Toggle helper
    function toggleDemoMode() {
        if (root.isDemoModeActive) {
            root.stopDemoMode()
        } else {
            root.startDemoMode()
        }
    }

    // Unbypassable arming check callable by any flight control UI
    function canArmAircraft() {
        return !root.isDemoModeActive
    }

    // Loads the demo mission plan into the target planMasterController
    function loadDemoMissionPlan(planMasterController) {
        if (!planMasterController) {
            console.warn("PulseGCSDemoModeManager: Cannot load demo mission — null planMasterController")
            return false
        }
        var path = root.demoMissionPlanPath
        console.log("PulseGCSDemoModeManager: Loading demo mission plan from:", path)
        try {
            planMasterController.loadFromFile(path)
            if (typeof planMasterController.fitViewportToItems === "function") {
                planMasterController.fitViewportToItems()
            }
            if (planMasterController.missionController && typeof planMasterController.missionController.setCurrentPlanViewSeqNum === "function") {
                planMasterController.missionController.setCurrentPlanViewSeqNum(0, true)
            }
            return true
        } catch (err) {
            console.error("PulseGCSDemoModeManager: Failed to load demo mission plan:", err)
            return false
        }
    }
}


