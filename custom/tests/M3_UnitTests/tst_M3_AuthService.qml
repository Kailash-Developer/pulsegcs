import QtQuick
import QtTest
import PulseGCS

TestCase {
    id: testCase
    name: "M3_AuthServiceQuickTest"

    PulseGCSAuthService {
        id: authService
        mockMode: true
    }

    // -------------------------------------------------------------------------
    // 1. Endpoints Registry Schema Check
    // -------------------------------------------------------------------------
    function test_endpointsRegistry() {
        compare(authService.endpoints.signIn, "/api/v1/auth/signin", "SignIn endpoint")
        compare(authService.endpoints.register, "/api/v1/auth/register", "Register endpoint")
        compare(authService.endpoints.recoveryRequest, "/api/v1/auth/recovery/request", "Recovery request endpoint")
        compare(authService.endpoints.recoveryVerify, "/api/v1/auth/recovery/verify-code", "Recovery verify endpoint")
        compare(authService.endpoints.recoveryReset, "/api/v1/auth/recovery/reset-password", "Recovery reset endpoint")
        compare(authService.endpoints.health, "/api/v1/health", "Health endpoint")
    }

    // -------------------------------------------------------------------------
    // 2. Sign In Mock Contract
    // -------------------------------------------------------------------------
    function test_signInContract() {
        var completed = false
        var isSuccess = false
        var jwt = ""
        var days = 0

        authService.signIn("pilot@example.com", "FlightPass2026!", function(success, data, errorMsg) {
            completed = true
            isSuccess = success
            if (data) {
                jwt = data.token
                days = data.attestation ? data.attestation.validDays : 0
            }
        })

        verify(completed, "Sign in responded")
        compare(isSuccess, true, "Sign in success")
        verify(jwt.startsWith("mock_jwt_token_"), "JWT issued")
        compare(days, 7, "7-day attestation")
    }

    function test_signInWrongPassword() {
        var completed = false
        var isSuccess = true
        var err = ""

        authService.signIn("pilot@example.com", "wrongpassword", function(success, data, errorMsg) {
            completed = true
            isSuccess = success
            err = errorMsg
        })

        verify(completed, "Sign in responded")
        compare(isSuccess, false, "Wrong password fails")
        verify(err.indexOf("Invalid credentials") !== -1, "Proper error returned")
    }

    // -------------------------------------------------------------------------
    // 3. M3-US11: Console Suspended (HTTP 403) Mock Contract
    // -------------------------------------------------------------------------
    function test_signInSuspendedConsole_US11() {
        var completed = false
        var isSuccess = true
        var errCode = ""
        var errMsg = ""

        authService.signIn("suspended@skyx.aero", "anypass123", function(success, data, errorMsg) {
            completed = true
            isSuccess = success
            if (data) errCode = data.errorCode
            errMsg = errorMsg
        })

        verify(completed, "Sign in responded")
        compare(isSuccess, false, "Suspended console fails login")
        compare(errCode, "CONSOLE_SUSPENDED", "Error code is CONSOLE_SUSPENDED")
        verify(errMsg.indexOf("suspended by an administrator") !== -1, "Suspended message returned")
    }

    // -------------------------------------------------------------------------
    // 4. M3-US08: 7-Day Session Vault Expired Contract
    // -------------------------------------------------------------------------
    function test_signInSessionExpired_US08() {
        var completed = false
        var isSuccess = true
        var errCode = ""
        var errMsg = ""

        authService.signIn("expired@skyx.aero", "anypass123", function(success, data, errorMsg) {
            completed = true
            isSuccess = success
            if (data) errCode = data.errorCode
            errMsg = errorMsg
        })

        verify(completed, "Sign in responded")
        compare(isSuccess, false, "Expired session fails login")
        compare(errCode, "SESSION_EXPIRED", "Error code is SESSION_EXPIRED")
        verify(errMsg.indexOf("7-day offline flight authorization has expired") !== -1, "Expired message returned")
    }

    // -------------------------------------------------------------------------
    // 5. M3-US07: First-Login License Ready Contract
    // -------------------------------------------------------------------------
    function test_signInLicenseReady_US07() {
        var completed = false
        var isSuccess = false
        var licenseReady = false
        var key = ""

        authService.signIn("license@skyx.aero", "anypass123", function(success, data, errorMsg) {
            completed = true
            isSuccess = success
            if (data) {
                licenseReady = !!data.licenseReady
                key = data.licenseKey
            }
        })

        verify(completed, "Sign in responded")
        compare(isSuccess, true, "Sign in with license ready account succeeds")
        compare(licenseReady, true, "License ready flag is true")
        compare(key, "SKYX-LIC-8820-4190-FA21", "Issued license key matches")
    }

    // -------------------------------------------------------------------------
    // 6. M3-US09: FCM UID Mismatch Simulation Contract
    // -------------------------------------------------------------------------
    function test_signInFcmMismatch_US09() {
        var completed = false
        var isSuccess = true
        var errCode = ""
        var fcmUid = ""

        authService.signIn("fcmerror@skyx.aero", "anypass123", function(success, data, errorMsg) {
            completed = true
            isSuccess = success
            if (data) {
                errCode = data.errorCode
                fcmUid = data.fcmUid
            }
        })

        verify(completed, "Sign in responded")
        compare(isSuccess, false, "FCM error simulation fails login")
        compare(errCode, "FCM_MISMATCH", "Error code is FCM_MISMATCH")
        compare(fcmUid, "1A:2B:3C:4D:5E:6F", "Mismatched FCM UID matches")
    }

    // -------------------------------------------------------------------------
    // 7. Registration Mock Contract
    // -------------------------------------------------------------------------
    function test_registrationContract() {
        var completed = false
        var isSuccess = false
        var appId = ""

        authService.register({
            fullName: "Alex Rivera",
            phone: "+1-555-0199",
            email: "alex@example.com",
            password: "SecureFlightPass2026!",
            dob: "15 / 06 / 1995",
            aircraftSerial: "SKYX-VTOL-9921",
            bindConsole: true
        }, function(success, data, errorMsg) {
            completed = true
            isSuccess = success
            if (data) appId = data.applicationId
        })

        verify(completed, "Register responded")
        compare(isSuccess, true, "Register success")
        verify(appId.startsWith("APP-"), "Application ID assigned")
    }

    // -------------------------------------------------------------------------
    // 4. Password Recovery Mock Contract
    // -------------------------------------------------------------------------
    function test_recoveryContract() {
        var reqSuccess = false
        authService.requestRecoveryCode("pilot@example.com", function(success, data, errorMsg) {
            reqSuccess = success
            compare(data.testCode, "849201", "Simulated code is 849201")
        })
        compare(reqSuccess, true, "Recovery request success")

        var verifySuccess = false
        var resetToken = ""
        authService.verifyRecoveryCode("pilot@example.com", "849201", function(success, data, errorMsg) {
            verifySuccess = success
            if (data) resetToken = data.resetToken
        })
        compare(verifySuccess, true, "Code verification success")
        verify(resetToken.startsWith("rst_tok_"), "Reset token generated")

        var resetSuccess = false
        authService.resetPassword("pilot@example.com", resetToken, "NewPass2026!", function(success, data, errorMsg) {
            resetSuccess = success
        })
        compare(resetSuccess, true, "Password reset success")
    }
}

