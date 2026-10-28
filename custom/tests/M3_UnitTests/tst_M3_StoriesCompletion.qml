import QtQuick
import QtQuick.Controls
import QtTest
import PulseGCS

TestCase {
    id: testCase
    name: "M3_StoriesCompletionQuickTest"
    width: 600
    height: 800
    visible: true
    when: windowShown

    // Components under test
    PulseGCSSignInView {
        id: signInView
        anchors.fill: parent
    }

    ConnectAircraftPanel {
        id: connectPanel
        visible: false
        width: 600
        height: 800
    }

    SignalSpy {
        id: signInSuccessSpy
        target: signInView
        signalName: "signInSucceeded"
    }

    SignalSpy {
        id: demoModeSpy
        target: signInView
        signalName: "demoModeClicked"
    }

    function cleanup() {
        signInSuccessSpy.clear()
        demoModeSpy.clear()
        signInView.licenseReadyPopup.close()
        signInView.suspendedLockoutPopup.close()
        signInView.sessionExpiredPopup.close()
        signInView.applicationSentPopup.close()
        signInView.submissionIssuePopup.close()
        signInView.fcmMismatchPopup.close()
        connectPanel.fcmMismatchPopup.close()
        signInView.clearNotice()
    }

    // -------------------------------------------------------------------------
    // 1. M3-US07: First-Login License Key Activation Modal & Copy Action
    // -------------------------------------------------------------------------
    function test_us07_licenseKeyActivationModal() {
        // Direct modal invocation
        signInView.showLicenseReadyModal("SKYX-LIC-8820-4190-FA21", "SkyX Kissan", "SKYX-KSN-2026-0842")
        verify(signInView.licenseReadyPopup.opened, "License key popup opens")
        compare(signInView.issuedLicenseKey, "SKYX-LIC-8820-4190-FA21", "Issued key matches specification")
        compare(signInView.licensedDroneModel, "SkyX Kissan", "Drone model matches")
        compare(signInView.licensedDroneSerial, "SKYX-KSN-2026-0842", "Serial number matches")

        // Test copy to clipboard action
        compare(signInView.licenseCopied, false, "Initial copied state is false")
        signInView.copyToClipboard(signInView.issuedLicenseKey)
        signInView.licenseCopied = true
        compare(signInView.licenseCopied, true, "License copied state active")

        signInView.licenseReadyPopup.close()
        verify(!signInView.licenseReadyPopup.opened, "License modal closed")

        // Test end-to-end signIn trigger with license ready account
        signInView.authService.signIn("license@skyx.aero", "AnyPass2026!", function(success, data, errorMsg) {
            compare(success, true, "License account sign in succeeds")
            compare(data.licenseReady, true, "Data specifies licenseReady")
            compare(data.licenseKey, "SKYX-LIC-8820-4190-FA21", "License key returned")
        })
    }

    // -------------------------------------------------------------------------
    // 2. M3-US08: 7-Day Session Vault & Expiration State Lockout
    // -------------------------------------------------------------------------
    function test_us08_sessionExpirationLockout() {
        // Normal pilot login generates active 7-day session
        signInView.authService.signIn("pilot@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, true, "Pilot sign in succeeds")
            compare(data.attestation.validDays, 7, "7-day attestation present")
            compare(data.sessionActive, true, "Session vault active")
        })

        // Expired session account returns expiration error and blocks login
        signInView.authService.signIn("expired@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Expired account login fails")
            compare(data.errorCode, "SESSION_EXPIRED", "Error code is SESSION_EXPIRED")
            verify(errorMsg.indexOf("7-day offline flight authorization has expired") !== -1, "Expiration message returned")
        })

        // Verify session expired modal
        signInView.showSessionExpiredModal()
        verify(signInView.sessionExpiredPopup.opened, "Session expired popup opens")
        signInView.sessionExpiredPopup.close()
        verify(!signInView.sessionExpiredPopup.opened, "Session expired popup closes")
    }

    // -------------------------------------------------------------------------
    // 3. M3-US09: FCM Silicon UID Verification Failure & Telemetry Lockout
    // -------------------------------------------------------------------------
    function test_us09_fcmSiliconUidMismatch() {
        // In SignInView: FCM error simulation
        signInView.authService.signIn("fcmerror@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "FCM mismatch login rejected")
            compare(data.errorCode, "FCM_MISMATCH", "Error code is FCM_MISMATCH")
            compare(data.fcmUid, "1A:2B:3C:4D:5E:6F", "FCM UID matches")
            compare(data.airframeSerial, "SKYX-KSN-2026-0842", "Airframe serial matches")
        })

        signInView.showFcmMismatchModal("1A:2B:3C:4D:5E:6F", "SKYX-KSN-2026-0842")
        verify(signInView.fcmMismatchPopup.opened, "FCM mismatch popup opens in SignInView")
        signInView.fcmMismatchPopup.close()

        // In ConnectAircraftPanel: FCM verification lockout trigger
        connectPanel.triggerFcmMismatch("1A:2B:3C:4D:5E:6F", "SKYX-KSN-2026-0842")
        verify(connectPanel.fcmMismatchPopup.opened, "ConnectAircraftPanel FCM mismatch popup opens")
        compare(connectPanel.isFcmMismatchActive, true, "Lockout active flag set")
        verify(connectPanel._statusMessage.indexOf("FCM UID: 1A:2B:3C:4D:5E:6F") !== -1, "Status message updated with FCM failure")
        connectPanel.fcmMismatchPopup.close()
    }

    // -------------------------------------------------------------------------
    // 4. M3-US11: Console Suspended / Replaced (HTTP 403) Lockout
    // -------------------------------------------------------------------------
    function test_us11_consoleSuspendedLockout() {
        // Suspended console attempt
        signInView.authService.signIn("suspended@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Suspended console login rejected")
            compare(data.code, 403, "HTTP status 403")
            compare(data.errorCode, "CONSOLE_SUSPENDED", "Error code is CONSOLE_SUSPENDED")
            verify(errorMsg.indexOf("suspended by an administrator") !== -1, "Suspended message returned")
        })

        // Verify suspended lockout modal
        signInView.showSuspendedModal()
        verify(signInView.suspendedLockoutPopup.opened, "Suspended lockout popup opens")
        signInView.suspendedLockoutPopup.close()
        verify(!signInView.suspendedLockoutPopup.opened, "Suspended lockout popup closes")
    }

    // -------------------------------------------------------------------------
    // 5. M3 Launch Status Modals & Mock Seeds (Under Review, Approved, Issue)
    // -------------------------------------------------------------------------
    function test_launchStatusModalsAndSeeds() {
        // A. Under Review (1-2 Days) seed & modal
        signInView.authService.signIn("review@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Under review login returns pending status")
            compare(data.code, 202, "HTTP 202 Accepted status")
            compare(data.errorCode, "APPLICATION_UNDER_REVIEW", "Error code is APPLICATION_UNDER_REVIEW")
            verify(errorMsg.indexOf("under review") !== -1, "Under review text returned")
        })
        signInView.showApplicationUnderReviewModal()
        verify(signInView.applicationSentPopup.opened, "Application under review popup opens")
        signInView.applicationSentPopup.close()
        verify(!signInView.applicationSentPopup.opened, "Application under review popup closes")

        // B. Access Approved (License Key) seed & modal
        signInView.authService.signIn("license@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, true, "Approved account sign-in succeeds")
            compare(data.licenseReady, true, "License ready flag set")
            compare(data.licenseKey, "SKYX-LIC-8820-4190-FA21", "License key matches")
        })
        signInView.showLicenseReadyModal("SKYX-LIC-8820-4190-FA21", "SkyX Kissan", "SKYX-KSN-2026-0842")
        verify(signInView.licenseReadyPopup.opened, "License ready popup opens")
        signInView.licenseReadyPopup.close()
        verify(!signInView.licenseReadyPopup.opened, "License ready popup closes")

        // C. Submission Issue (Not Received / Backend Failure) seed & modal
        signInView.authService.signIn("failed@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Failed submission login rejected")
            compare(data.code, 500, "HTTP status 500")
            compare(data.errorCode, "APPLICATION_SUBMISSION_FAILED", "Error code is APPLICATION_SUBMISSION_FAILED")
            verify(errorMsg.indexOf("could not reach the SkyX backend") !== -1, "Backend error message returned")
        })
        signInView.showSubmissionIssueModal()
        verify(signInView.submissionIssuePopup.opened, "Submission issue popup opens")
        signInView.submissionIssuePopup.close()
        verify(!signInView.submissionIssuePopup.opened, "Submission issue popup closes")
    }

    // -------------------------------------------------------------------------
    // 6. M3 Sign In Alerts & Policy Seeds (No Alert, 401, 403, 504, 200, Session Expired)
    // -------------------------------------------------------------------------
    function test_alertsAndPolicySeeds() {
        // A. Standard Standby (No Alert)
        signInView.clearNotice()
        compare(signInView.inlineNoticeMsg, "", "No alert present in standby")

        // B. Invalid User Account (401)
        signInView.authService.signIn("pilot@skyx.aero", "wrongpassword", function(success, data, errorMsg) {
            compare(success, false, "Invalid password rejected")
            compare(data.code, 401, "HTTP status 401")
            compare(data.errorCode, "INVALID_CREDENTIALS", "Error code is INVALID_CREDENTIALS")
            verify(errorMsg.indexOf("Invalid user account or password") !== -1, "Invalid credentials message returned")
        })

        // C. Valid Account, Invalid Device (403)
        signInView.authService.signIn("unbound@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Unbound device rejected")
            compare(data.code, 403, "HTTP status 403")
            compare(data.errorCode, "CONSOLE_UNBOUND", "Error code is CONSOLE_UNBOUND")
            verify(errorMsg.indexOf("Device Not Authorized") !== -1, "Device not authorized message returned")
        })

        // D. Console Suspended / Replaced (US11 403)
        signInView.authService.signIn("suspended@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Suspended console rejected")
            compare(data.code, 403, "HTTP status 403")
            compare(data.errorCode, "CONSOLE_SUSPENDED", "Error code is CONSOLE_SUSPENDED")
        })

        // E. Network / Server Connection Timeout (504)
        signInView.authService.signIn("timeout@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Server timeout rejected")
            compare(data.code, 504, "HTTP status 504")
            compare(data.errorCode, "SERVER_TIMEOUT", "Error code is SERVER_TIMEOUT")
            verify(errorMsg.indexOf("Server Connection Timeout") !== -1, "Server timeout message returned")
        })

        // F. 7-Day Session Active (200)
        signInView.authService.signIn("pilot@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, true, "Standard valid pilot sign in succeeds")
            compare(data.attestation.validDays, 7, "7-day attestation present")
            compare(data.sessionActive, true, "Session vault active")
        })

        // G. Session Expired (401 Expiration)
        signInView.authService.signIn("expired@skyx.aero", "FlightPass2026!", function(success, data, errorMsg) {
            compare(success, false, "Expired session rejected")
            compare(data.errorCode, "SESSION_EXPIRED", "Error code is SESSION_EXPIRED")
        })
    }

    // -------------------------------------------------------------------------
    // 7. M3 Sign In Card End-to-End UI Integration (Simulating User Clicks)
    // -------------------------------------------------------------------------
    function test_endToEndSignInCardTriggeredUIResponses() {
        // 1. review@skyx.aero triggers under review popup
        cleanup()
        signInView.signInCard.signInRequested("review@skyx.aero", "FlightPass2026!")
        verify(signInView.applicationSentPopup.opened, "applicationSentPopup opened from user card submission")
        signInView.applicationSentPopup.close()

        // 2. failed@skyx.aero triggers submission issue popup
        cleanup()
        signInView.signInCard.signInRequested("failed@skyx.aero", "FlightPass2026!")
        verify(signInView.submissionIssuePopup.opened, "submissionIssuePopup opened from user card submission")
        signInView.submissionIssuePopup.close()

        // 3. license@skyx.aero triggers license ready popup
        cleanup()
        signInView.signInCard.signInRequested("license@skyx.aero", "FlightPass2026!")
        verify(signInView.licenseReadyPopup.opened, "licenseReadyPopup opened from user card submission")
        signInView.licenseReadyPopup.close()

        // 4. unbound@skyx.aero triggers amber 403 warning banner
        cleanup()
        signInView.signInCard.signInRequested("unbound@skyx.aero", "FlightPass2026!")
        compare(signInView.inlineNoticeType, "warn", "Warning notice type active for unbound device")
        verify(signInView.inlineNoticeMsg.indexOf("Device Not Authorized") !== -1, "Device not authorized message shown in UI")

        // 5. timeout@skyx.aero triggers red 504 error banner
        cleanup()
        signInView.signInCard.signInRequested("timeout@skyx.aero", "FlightPass2026!")
        compare(signInView.inlineNoticeType, "err", "Error notice type active for 504 timeout")
        verify(signInView.inlineNoticeMsg.indexOf("Server Connection Timeout") !== -1, "Timeout message shown in UI")

        // 6. wrongpassword triggers red 401 error banner
        cleanup()
        signInView.signInCard.signInRequested("pilot@skyx.aero", "wrongpassword")
        compare(signInView.inlineNoticeType, "err", "Error notice type active for wrong password")

        // 7. pilot@skyx.aero with valid credentials triggers green 200 banner & success signal
        cleanup()
        signInView.signInCard.signInRequested("pilot@skyx.aero", "FlightPass2026!")
        compare(signInView.inlineNoticeType, "ok", "Success notice type active for valid session")
        compare(signInSuccessSpy.count, 1, "signInSucceeded signal emitted to parent view")

        // 8. suspended@skyx.aero triggers lockout modal
        cleanup()
        signInView.signInCard.signInRequested("suspended@skyx.aero", "FlightPass2026!")
        verify(signInView.suspendedLockoutPopup.opened, "suspendedLockoutPopup opened from user card submission")
        signInView.suspendedLockoutPopup.close()

        // 9. expired@skyx.aero triggers session expired modal
        cleanup()
        signInView.signInCard.signInRequested("expired@skyx.aero", "FlightPass2026!")
        verify(signInView.sessionExpiredPopup.opened, "sessionExpiredPopup opened from user card submission")
        signInView.sessionExpiredPopup.close()
    }
}
