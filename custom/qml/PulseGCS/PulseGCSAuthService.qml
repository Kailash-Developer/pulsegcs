import QtQuick
import QGroundControl
import PulseGCS

Item {
    id: root

    // Configuration
    property string baseUrl: "https://api.pulsegcs.skyx.aero"
    property bool mockMode: true
    property int requestTimeoutMs: 10000
    property bool isBusy: false

    // Endpoints schema registry
    readonly property var endpoints: ({
        "signIn": "/api/v1/auth/signin",
        "register": "/api/v1/auth/register",
        "recoveryRequest": "/api/v1/auth/recovery/request",
        "recoveryVerify": "/api/v1/auth/recovery/verify-code",
        "recoveryReset": "/api/v1/auth/recovery/reset-password",
        "health": "/api/v1/health"
    })

    // Signals for UI bindings
    signal signInCompleted(bool success, var data, string errorMessage)
    signal registrationCompleted(bool success, var data, string errorMessage)
    signal recoveryRequestCompleted(bool success, var data, string errorMessage)
    signal recoveryVerifyCompleted(bool success, var data, string errorMessage)
    signal recoveryResetCompleted(bool success, var data, string errorMessage)

    // =========================================================================
    // 1. Sign In Endpoint
    // Request: { "email": "...", "password": "...", "deviceId": "...", "appVersion": "..." }
    // Response (200): { "status": "success", "token": "jwt...", "operator": { ... }, "attestationDays": 7 }
    // =========================================================================
    function signIn(email, password, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "password": password || "",
            "deviceId": "console-skyx-dev-01",
            "appVersion": (typeof PulseGCSStartupController !== "undefined") ? PulseGCSStartupController.appVersion : "1.0.0",
            "clientTimestamp": new Date().toISOString()
        }

        if (root.mockMode) {
            mockSignIn(payload, function(success, data, errorMsg) {
                root.isBusy = false
                root.signInCompleted(success, data, errorMsg)
                if (typeof callback === "function") callback(success, data, errorMsg)
            })
            return
        }

        sendHttpRequest("POST", root.endpoints.signIn, payload, function(success, data, errorMsg) {
            root.isBusy = false
            root.signInCompleted(success, data, errorMsg)
            if (typeof callback === "function") callback(success, data, errorMsg)
        })
    }

    // =========================================================================
    // 2. Registration Endpoint
    // Request: { "fullName": "...", "phone": "...", "email": "...", "password": "...", "dob": "...", "aircraftSerial": "...", "bindConsole": true }
    // Response (201): { "status": "success", "applicationId": "...", "state": "pending_approval" }
    // =========================================================================
    function register(regData, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "fullName": (regData.fullName || "").trim(),
            "phone": (regData.phone || "").trim(),
            "email": (regData.email || "").trim(),
            "password": regData.password || "",
            "dob": (regData.dob || "").trim(),
            "aircraftSerial": (regData.aircraftSerial || "").trim(),
            "bindConsole": !!regData.bindConsole,
            "submittedAt": new Date().toISOString()
        }

        if (root.mockMode) {
            mockRegister(payload, function(success, data, errorMsg) {
                root.isBusy = false
                root.registrationCompleted(success, data, errorMsg)
                if (typeof callback === "function") callback(success, data, errorMsg)
            })
            return
        }

        sendHttpRequest("POST", root.endpoints.register, payload, function(success, data, errorMsg) {
            root.isBusy = false
            root.registrationCompleted(success, data, errorMsg)
            if (typeof callback === "function") callback(success, data, errorMsg)
        })
    }

    // =========================================================================
    // 3. Password Recovery - Stage 1: Request Code
    // Request: { "email": "..." }
    // Response (200): { "status": "success", "expiresIn": 300, "codeLength": 6 }
    // =========================================================================
    function requestRecoveryCode(email, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "clientTimestamp": new Date().toISOString()
        }

        if (root.mockMode) {
            mockRecoveryRequest(payload, function(success, data, errorMsg) {
                root.isBusy = false
                root.recoveryRequestCompleted(success, data, errorMsg)
                if (typeof callback === "function") callback(success, data, errorMsg)
            })
            return
        }

        sendHttpRequest("POST", root.endpoints.recoveryRequest, payload, function(success, data, errorMsg) {
            root.isBusy = false
            root.recoveryRequestCompleted(success, data, errorMsg)
            if (typeof callback === "function") callback(success, data, errorMsg)
        })
    }

    // =========================================================================
    // 4. Password Recovery - Stage 2: Verify Code
    // Request: { "email": "...", "code": "..." }
    // Response (200): { "status": "success", "resetToken": "tok_..." }
    // =========================================================================
    function verifyRecoveryCode(email, code, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "code": (code || "").trim(),
            "clientTimestamp": new Date().toISOString()
        }

        if (root.mockMode) {
            mockRecoveryVerify(payload, function(success, data, errorMsg) {
                root.isBusy = false
                root.recoveryVerifyCompleted(success, data, errorMsg)
                if (typeof callback === "function") callback(success, data, errorMsg)
            })
            return
        }

        sendHttpRequest("POST", root.endpoints.recoveryVerify, payload, function(success, data, errorMsg) {
            root.isBusy = false
            root.recoveryVerifyCompleted(success, data, errorMsg)
            if (typeof callback === "function") callback(success, data, errorMsg)
        })
    }

    // =========================================================================
    // 5. Password Recovery - Stage 3: Reset Password
    // Request: { "email": "...", "resetToken": "...", "newPassword": "..." }
    // Response (200): { "status": "success", "message": "Password successfully updated" }
    // =========================================================================
    function resetPassword(email, resetToken, newPassword, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "resetToken": resetToken || "",
            "newPassword": newPassword || "",
            "clientTimestamp": new Date().toISOString()
        }

        if (root.mockMode) {
            mockRecoveryReset(payload, function(success, data, errorMsg) {
                root.isBusy = false
                root.recoveryResetCompleted(success, data, errorMsg)
                if (typeof callback === "function") callback(success, data, errorMsg)
            })
            return
        }

        sendHttpRequest("POST", root.endpoints.recoveryReset, payload, function(success, data, errorMsg) {
            root.isBusy = false
            root.recoveryResetCompleted(success, data, errorMsg)
            if (typeof callback === "function") callback(success, data, errorMsg)
        })
    }

    // =========================================================================
    // HTTP Network Layer (XMLHttpRequest REST Client)
    // =========================================================================
    function sendHttpRequest(method, path, payload, callback) {
        var xhr = new XMLHttpRequest()
        var url = root.baseUrl + path

        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.timeout = root.requestTimeoutMs

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        var parsed = JSON.parse(xhr.responseText)
                        callback(true, parsed, "")
                    } catch (e) {
                        callback(false, null, qsTr("Malformed server response"))
                    }
                } else if (xhr.status === 401) {
                    callback(false, null, qsTr("Invalid credentials. Please re-enter your password."))
                } else if (xhr.status === 403) {
                    callback(false, {
                        "status": "error",
                        "code": 403,
                        "errorCode": "CONSOLE_SUSPENDED",
                        "title": qsTr("Device Suspended"),
                        "message": qsTr("This device has been marked replaced or suspended by an administrator. Please sign in using an authorized device or contact SkyX support.")
                    }, qsTr("This device has been marked replaced or suspended by an administrator. Please sign in using an authorized device or contact SkyX support."))
                } else if (xhr.status === 404) {
                    callback(false, null, qsTr("No operator account found matching this email."))
                } else if (xhr.status === 409) {
                    callback(false, null, qsTr("An account with this email address already exists."))
                } else if (xhr.status === 0) {
                    callback(false, null, qsTr("Network connection failed. Verify internet link."))
                } else {
                    try {
                        var errJson = JSON.parse(xhr.responseText)
                        callback(false, null, errJson.message || qsTr("Server returned error %1").arg(xhr.status))
                    } catch (e) {
                        callback(false, null, qsTr("Server returned HTTP error %1").arg(xhr.status))
                    }
                }
            }
        }

        xhr.ontimeout = function() {
            callback(false, null, qsTr("Request timed out after %1 seconds").arg(root.requestTimeoutMs / 1000))
        }

        xhr.onerror = function() {
            callback(false, null, qsTr("Unable to reach authentication server"))
        }

        try {
            xhr.send(payload ? JSON.stringify(payload) : null)
        } catch (err) {
            callback(false, null, qsTr("Failed to dispatch request: %1").arg(err.message))
        }
    }

    // =========================================================================
    // Mock Backend Simulation Engine (Pre-configured for contract verification)
    // =========================================================================
    function mockSignIn(payload, callback) {
        var email = payload.email.toLowerCase()
        var password = payload.password

        // M3-US11: Console Suspended / Replaced (HTTP 403) Lockout
        if (email === "suspended@skyx.aero" || password === "suspended" || email.indexOf("suspended") !== -1) {
            callback(false, {
                "status": "error",
                "code": 403,
                "errorCode": "CONSOLE_SUSPENDED",
                "title": qsTr("Device Suspended"),
                "message": qsTr("This device has been marked replaced or suspended by an administrator. Please sign in using an authorized device or contact SkyX support.")
            }, qsTr("This device has been marked replaced or suspended by an administrator. Please sign in using an authorized device or contact SkyX support."))
            return
        }

        // M3-US08: 7-Day Session Vault Expired State
        if (email === "expired@skyx.aero" || email.indexOf("expired") !== -1) {
            callback(false, {
                "status": "error",
                "code": 401,
                "errorCode": "SESSION_EXPIRED",
                "title": qsTr("Session Expired"),
                "message": qsTr("7-day offline flight authorization has expired. Re-authentication with SkyX backend required.")
            }, qsTr("7-day offline flight authorization has expired. Re-authentication with SkyX backend required."))
            return
        }

        // M3-Launch Status: Application Under Review (1-2 Days)
        if (email === "review@skyx.aero" || email === "pending@skyx.aero" || email.indexOf("review") !== -1 || email.indexOf("pending") !== -1) {
            callback(false, {
                "status": "pending",
                "code": 202,
                "errorCode": "APPLICATION_UNDER_REVIEW",
                "title": qsTr("Application Under Review"),
                "message": qsTr("Your application has been received and is under review (1–2 business days).")
            }, qsTr("Your application has been received and is under review (1–2 business days)."))
            return
        }

        // M3-Launch Status: Submission Issue (Not Received / Failure)
        if (email === "failed@skyx.aero" || email === "submissionerror@skyx.aero" || email.indexOf("failed") !== -1) {
            callback(false, {
                "status": "error",
                "code": 500,
                "errorCode": "APPLICATION_SUBMISSION_FAILED",
                "title": qsTr("Application Sent Failure"),
                "message": qsTr("Application was submitted, but could not reach the SkyX backend.")
            }, qsTr("Application was submitted, but could not reach the SkyX backend."))
            return
        }

        // M3-Alerts & Policy: Valid Account, Invalid Console (HTTP 403)
        if (email === "unbound@skyx.aero" || email === "unauthorized@skyx.aero" || email.indexOf("unbound") !== -1) {
            callback(false, {
                "status": "error",
                "code": 403,
                "errorCode": "CONSOLE_UNBOUND",
                "title": qsTr("Device Not Authorized"),
                "message": qsTr("Your user account is valid, but this device is not authorized for flight operations. Contact your administrator to enroll or reassign this device.")
            }, qsTr("Device Not Authorized: Your user account is valid, but this device is not authorized for flight operations. Contact your administrator to enroll or reassign this device."))
            return
        }

        // M3-Alerts & Policy: Network / Server Timeout (HTTP 504)
        if (email === "timeout@skyx.aero" || email.indexOf("timeout") !== -1) {
            callback(false, {
                "status": "error",
                "code": 504,
                "errorCode": "SERVER_TIMEOUT",
                "title": qsTr("Server Connection Timeout"),
                "message": qsTr("Unable to reach SkyX authentication servers. Please verify your internet connection and try again.")
            }, qsTr("Server Connection Timeout: Unable to reach SkyX authentication servers. Please verify your internet connection and try again."))
            return
        }

        // M3-US09: FCM Silicon UID Verification Failure Simulation
        if (email === "fcmerror@skyx.aero" || email.indexOf("fcmerror") !== -1 || password === "fcmerror") {
            callback(false, {
                "status": "error",
                "code": 422,
                "errorCode": "FCM_MISMATCH",
                "title": qsTr("FCM UID Mismatch"),
                "fcmUid": "1A:2B:3C:4D:5E:6F",
                "airframeSerial": "SKYX-KSN-2026-0842",
                "message": qsTr("Aircraft Flight Control Module (FCM UID: 1A:2B:3C:4D:5E:6F) does not match registered airframe serial (SKYX-KSN-2026-0842). Telemetry connection aborted.")
            }, qsTr("Aircraft Flight Control Module (FCM UID: 1A:2B:3C:4D:5E:6F) does not match registered airframe serial (SKYX-KSN-2026-0842). Telemetry connection aborted."))
            return
        }

        // M3-US07: First-Login License Key Activation Ready
        if (email === "license@skyx.aero" || email.indexOf("license") !== -1) {
            var licenseData = {
                "status": "success",
                "licenseReady": true,
                "token": "mock_jwt_token_lic_" + Math.random().toString(36).substring(2),
                "licenseKey": "SKYX-LIC-8820-4190-FA21",
                "droneModel": "SkyX Kissan",
                "serialNumber": "SKYX-KSN-2026-0842",
                "operator": {
                    "id": "op_skyx_license_01",
                    "email": payload.email,
                    "name": "Certified Flight Operator",
                    "role": "pilot"
                },
                "attestation": {
                    "validDays": 7,
                    "expiresAt": new Date(Date.now() + 7 * 86400 * 1000).toISOString()
                },
                "sessionActive": true
            }
            callback(true, licenseData, "")
            return
        }

        if (email.indexOf("unregistered") !== -1 || email === "notfound@skyx.aero") {
            callback(false, {
                "status": "error",
                "code": 404,
                "errorCode": "ACCOUNT_NOT_FOUND",
                "title": qsTr("Account Not Found"),
                "message": qsTr("No operator account found matching this email.")
            }, qsTr("No operator account found matching this email."))
            return
        }
        if (password === "wrongpassword" || password === "invalid123" || email === "invalid@skyx.aero" || email.indexOf("invalid") !== -1) {
            callback(false, {
                "status": "error",
                "code": 401,
                "errorCode": "INVALID_CREDENTIALS",
                "title": qsTr("Sign In Failed"),
                "message": qsTr("Invalid credentials. Invalid user account or password. Please verify your credentials or use password recovery.")
            }, qsTr("Invalid credentials. Invalid user account or password. Please verify your credentials or use password recovery."))
            return
        }

        // Standard success payload (M3-US08: Active 7-day session vault)
        var responseData = {
            "status": "success",
            "token": "mock_jwt_token_" + Math.random().toString(36).substring(2),
            "operator": {
                "id": "op_skyx_9021",
                "email": payload.email,
                "name": "Certified Flight Operator",
                "role": "pilot"
            },
            "attestation": {
                "validDays": 7,
                "expiresAt": new Date(Date.now() + 7 * 86400 * 1000).toISOString()
            },
            "sessionActive": true
        }
        callback(true, responseData, "")
    }

    function mockRegister(payload, callback) {
        var email = payload.email.toLowerCase()
        if (email === "duplicate@skyx.aero" || email.indexOf("exists") !== -1) {
            callback(false, {
                "status": "error",
                "code": 409,
                "errorCode": "ACCOUNT_EXISTS",
                "message": qsTr("An account with this email address already exists.")
            }, qsTr("An account with this email address already exists."))
            return
        }

        // M3-US02: Application submission failure simulation
        if (email === "failed@skyx.aero" || email === "submissionerror@skyx.aero" || email.indexOf("fail") !== -1) {
            callback(false, {
                "status": "error",
                "code": 500,
                "errorCode": "APPLICATION_SUBMISSION_FAILED",
                "title": qsTr("Application Sent Failure"),
                "message": qsTr("Application was submitted, but could not reach the SkyX backend.")
            }, qsTr("Application was submitted, but could not reach the SkyX backend."))
            return
        }

        var responseData = {
            "status": "success",
            "applicationId": "APP-" + Math.floor(100000 + Math.random() * 900000),
            "message": "Operator application submitted successfully for review.",
            "state": "pending_verification"
        }
        callback(true, responseData, "")
    }

    function mockRecoveryRequest(payload, callback) {
        var email = payload.email.toLowerCase()
        if (email.indexOf("unregistered") !== -1 || email === "notfound@skyx.aero") {
            callback(false, null, qsTr("No operator account found matching this email."))
            return
        }

        var responseData = {
            "status": "success",
            "message": "Verification code dispatched to operator email.",
            "expiresIn": 300,
            "testCode": "849201" // Simulated test code
        }
        callback(true, responseData, "")
    }

    function mockRecoveryVerify(payload, callback) {
        var code = payload.code.trim()
        if (code !== "849201") {
            callback(false, null, qsTr("Incorrect verification code. Please check your email or request a new code."))
            return
        }

        var responseData = {
            "status": "success",
            "resetToken": "rst_tok_" + Math.random().toString(36).substring(2)
        }
        callback(true, responseData, "")
    }

    function mockRecoveryReset(payload, callback) {
        if (!payload.resetToken || payload.resetToken.length === 0) {
            callback(false, null, qsTr("Invalid or expired session. Please restart recovery."))
            return
        }

        var responseData = {
            "status": "success",
            "message": "Password successfully reset. Operator may now sign in."
        }
        callback(true, responseData, "")
    }
}

