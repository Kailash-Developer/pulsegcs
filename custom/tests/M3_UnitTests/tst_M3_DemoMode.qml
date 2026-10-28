import QtQuick
import QtTest

import QGroundControl
import PulseGCS 1.0

TestCase {
    id: testCase
    name: "M3_DemoModeQuickTest"
    visible: true
    when: windowShown

    SignalSpy {
        id: startSpy
        target: PulseGCSDemoModeManager
        signalName: "demoModeStarted"
    }

    SignalSpy {
        id: stopSpy
        target: PulseGCSDemoModeManager
        signalName: "demoModeStopped"
    }

    PulseGCSDemoBanner {
        id: banner
        width: 800
    }

    function init() {
        startSpy.clear()
        stopSpy.clear()
        if (PulseGCSDemoModeManager.isDemoModeActive) {
            PulseGCSDemoModeManager.stopDemoMode()
            startSpy.clear()
            stopSpy.clear()
        }
    }

    function cleanup() {
        if (PulseGCSDemoModeManager.isDemoModeActive) {
            PulseGCSDemoModeManager.stopDemoMode()
        }
    }

    function test_1_initialDemoState() {
        compare(PulseGCSDemoModeManager.isDemoModeActive, false, "Initial demo mode must be inactive")
        compare(PulseGCSDemoModeManager.allowRealHardwareArming, true, "Arming must be permitted when not in demo")
        compare(PulseGCSDemoModeManager.suppressLiveScanning, false, "Scanning must not be suppressed initially")
        compare(PulseGCSDemoModeManager.canArmAircraft(), true, "canArmAircraft() must return true when inactive")
        compare(banner.visible, false, "Demo banner must be hidden initially")
        compare(banner.height, 0, "Demo banner height must be 0 when hidden")
    }

    function test_2_startDemoModeLifecycle() {
        compare(startSpy.count, 0)
        PulseGCSDemoModeManager.startDemoMode()

        compare(PulseGCSDemoModeManager.isDemoModeActive, true, "isDemoModeActive must be true after start")
        compare(PulseGCSDemoModeManager.allowRealHardwareArming, false, "Real aircraft arming must be strictly blocked")
        compare(PulseGCSDemoModeManager.suppressLiveScanning, true, "Live radio scanning must be suppressed in demo")
        compare(PulseGCSDemoModeManager.canArmAircraft(), false, "canArmAircraft() must return false in demo")
        compare(startSpy.count, 1, "demoModeStarted signal must be emitted exactly once")

        // Verify banner visibility and height (wait for 150ms animation to complete)
        compare(banner.visible, true, "Demo banner must become visible in demo mode")
        tryCompare(banner, "height", 38, 500)

        // Idempotency: starting again must not re-emit signal
        PulseGCSDemoModeManager.startDemoMode()
        compare(startSpy.count, 1, "Redundant start must be idempotent and not re-emit")
    }

    function test_3_stopDemoModeLifecycle() {
        PulseGCSDemoModeManager.startDemoMode()
        compare(PulseGCSDemoModeManager.isDemoModeActive, true)

        compare(stopSpy.count, 0)
        PulseGCSDemoModeManager.stopDemoMode()

        compare(PulseGCSDemoModeManager.isDemoModeActive, false, "isDemoModeActive must be false after stop")
        compare(PulseGCSDemoModeManager.allowRealHardwareArming, true, "Arming permission restored")
        compare(PulseGCSDemoModeManager.suppressLiveScanning, false, "Scanning restriction removed")
        compare(PulseGCSDemoModeManager.canArmAircraft(), true, "canArmAircraft() restored to true")
        compare(stopSpy.count, 1, "demoModeStopped signal must be emitted exactly once")

        // Verify banner hides (wait for collapse animation)
        compare(banner.visible, false, "Demo banner must hide after stopping demo mode")
        tryCompare(banner, "height", 0, 500)

        // Idempotency: stopping again when stopped must not re-emit
        PulseGCSDemoModeManager.stopDemoMode()
        compare(stopSpy.count, 1, "Redundant stop must be idempotent")
    }

    function test_4_toggleDemoMode() {
        compare(PulseGCSDemoModeManager.isDemoModeActive, false)
        PulseGCSDemoModeManager.toggleDemoMode()
        compare(PulseGCSDemoModeManager.isDemoModeActive, true, "Toggle from false should be true")

        PulseGCSDemoModeManager.toggleDemoMode()
        compare(PulseGCSDemoModeManager.isDemoModeActive, false, "Toggle from true should be false")
    }

    // Item representing mock MainWindow view state to test view stack transitions & fallbacks
    Item {
        id: mockMainWindow
        property bool userAuthenticated: false
        property bool flyViewVisible: false
        property bool planViewVisible: false
        property bool connectAircraftVisible: false
        property bool signInVisible: true
        property string requestedOrientation: "portrait"

        property var mockPlanMasterController: QtObject {
            property bool containsItems: false
            property string loadedPath: ""
            property int loadCount: 0
            property int removeAllCount: 0
            property var missionController: QtObject {
                property int currentSeqNum: -1
                function setCurrentPlanViewSeqNum(seq, fit) {
                    currentSeqNum = seq
                }
            }
            function loadFromFile(path) {
                loadedPath = path
                containsItems = true
                loadCount++
            }
            function fitViewportToItems() {}
            function removeAll() {
                containsItems = false
                loadedPath = ""
                removeAllCount++
            }
        }

        function showPlanView() {
            requestedOrientation = "landscape"
            flyViewVisible = false
            planViewVisible = true
            connectAircraftVisible = false
            signInVisible = false
            if (PulseGCSDemoModeManager.isDemoModeActive) {
                _ensureDemoPlanLoaded()
            }
        }

        function _ensureDemoPlanLoaded() {
            if (!PulseGCSDemoModeManager.isDemoModeActive) {
                return
            }
            if (!mockPlanMasterController.containsItems) {
                PulseGCSDemoModeManager.loadDemoMissionPlan(mockPlanMasterController)
            }
        }

        function showSignIn() {
            requestedOrientation = "portrait"
            flyViewVisible = false
            planViewVisible = false
            connectAircraftVisible = false
            signInVisible = true
        }

        function showFlyView() {
            requestedOrientation = "landscape"
            flyViewVisible = true
            planViewVisible = false
            connectAircraftVisible = false
            signInVisible = false
        }

        function showConnectAircraft() {
            if (PulseGCSDemoModeManager.isDemoModeActive) {
                return
            }
            flyViewVisible = false
            planViewVisible = false
            connectAircraftVisible = true
            signInVisible = false
        }

        function hideConnectAircraft() {
            connectAircraftVisible = false
            showFlyView()
        }

        Connections {
            target: PulseGCSDemoModeManager
            function onDemoModeStopped() {
                if (mockMainWindow.mockPlanMasterController) {
                    mockMainWindow.mockPlanMasterController.removeAll()
                }
                mockMainWindow.userAuthenticated = false
                mockMainWindow.showSignIn()
            }
        }
    }

    function test_5_demoExitRestoresSignInViewAndPortraitOrientation() {
        // Reset to initial state
        mockMainWindow.showSignIn()
        compare(mockMainWindow.signInVisible, true)
        compare(mockMainWindow.flyViewVisible, false)
        compare(mockMainWindow.userAuthenticated, false)

        // 1. Enter Demo Mode from SignIn
        mockMainWindow.userAuthenticated = true
        mockMainWindow.signInVisible = false
        PulseGCSDemoModeManager.startDemoMode()
        mockMainWindow.showFlyView()

        // Verify Demo Mode active view state
        compare(PulseGCSDemoModeManager.isDemoModeActive, true, "Demo mode must be active")
        compare(mockMainWindow.userAuthenticated, true, "User marked authenticated in demo")
        compare(mockMainWindow.flyViewVisible, true, "FlyView must be active in demo mode")
        compare(mockMainWindow.signInVisible, false, "SignIn must be hidden in demo mode")
        compare(mockMainWindow.connectAircraftVisible, false, "ConnectAircraft must be hidden")
        compare(mockMainWindow.requestedOrientation, "landscape", "Orientation should be landscape in fly view")
        compare(banner.visible, true, "Hazard banner must be visible in demo mode")

        // 2. Click Exit on Demo Banner
        PulseGCSDemoModeManager.stopDemoMode()

        // 3. Verify regression check: Must fallback cleanly to Sign In view with portrait orientation
        compare(PulseGCSDemoModeManager.isDemoModeActive, false, "Demo mode must be deactivated")
        compare(mockMainWindow.userAuthenticated, false, "User must be logged out upon exiting demo")
        compare(mockMainWindow.signInVisible, true, "CRITICAL: SignInView must be visible after exiting demo mode")
        compare(mockMainWindow.flyViewVisible, false, "CRITICAL: FlyView must be hidden after exiting demo mode")
        compare(mockMainWindow.connectAircraftVisible, false, "ConnectAircraft must remain hidden")
        compare(mockMainWindow.planViewVisible, false, "PlanView must remain hidden")
        compare(mockMainWindow.requestedOrientation, "portrait", "CRITICAL: Orientation must revert to portrait for sign-in")
        compare(banner.visible, false, "Hazard banner must be hidden when exiting demo")
    }

    function test_6_planAndFlyViewStateAlignmentAndPreservation() {
        // Reset to clean sign-in
        mockMainWindow.showSignIn()
        mockMainWindow.mockPlanMasterController.removeAll()
        compare(mockMainWindow.mockPlanMasterController.containsItems, false, "Mock plan should be empty initially")

        // 1. Launch Demo Mode and land in Fly View
        mockMainWindow.userAuthenticated = true
        PulseGCSDemoModeManager.startDemoMode()
        mockMainWindow.showFlyView()
        compare(PulseGCSDemoModeManager.isDemoModeActive, true, "Demo mode active")
        compare(mockMainWindow.flyViewVisible, true, "Fly View visible")
        compare(mockMainWindow.planViewVisible, false, "Plan View hidden")

        // 2. User switches to Plan View via Toolbar / dropdown
        mockMainWindow.showPlanView()
        compare(mockMainWindow.planViewVisible, true, "Plan View now visible")
        compare(mockMainWindow.flyViewVisible, false, "Fly View hidden")
        compare(mockMainWindow.mockPlanMasterController.containsItems, true, "Demo mission plan must be loaded in Plan View")
        compare(mockMainWindow.mockPlanMasterController.loadCount, 1, "Load was invoked once")
        verify(mockMainWindow.mockPlanMasterController.loadedPath.indexOf("demo_mission.plan") !== -1, "Loaded path must reference demo_mission.plan")
        compare(mockMainWindow.mockPlanMasterController.missionController.currentSeqNum, 0, "First sequence item selected for viewport focus")

        // 3. User switches back to Fly View to monitor aircraft
        mockMainWindow.showFlyView()
        compare(mockMainWindow.flyViewVisible, true, "Fly View visible")
        compare(mockMainWindow.planViewVisible, false, "Plan View hidden")
        compare(PulseGCSDemoModeManager.isDemoModeActive, true, "Demo mode remains active")
        compare(mockMainWindow.mockPlanMasterController.containsItems, true, "Plan waypoints must NOT be wiped when switching to Fly View")

        // 4. User switches back to Plan View to review route
        mockMainWindow.showPlanView()
        compare(mockMainWindow.planViewVisible, true, "Plan View visible again")
        compare(mockMainWindow.mockPlanMasterController.containsItems, true, "Plan waypoints remain intact")
        compare(mockMainWindow.mockPlanMasterController.loadCount, 1, "Plan was not reloaded or overwritten unnecessarily")

        // 5. Exit Demo Mode
        PulseGCSDemoModeManager.stopDemoMode()
        compare(mockMainWindow.signInVisible, true, "Restores sign-in view")
        compare(mockMainWindow.mockPlanMasterController.containsItems, false, "Demo plan cleared on exit")
        verify(mockMainWindow.mockPlanMasterController.removeAllCount >= 1, "removeAll was called upon exiting demo")
    }
}

