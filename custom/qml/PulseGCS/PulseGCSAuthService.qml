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

        if (email.indexOf("unregistered") !== -1 || email === "notfound@skyx.aero") {
            callback(false, null, qsTr("No operator account found matching this email."))
            return
        }
        if (password === "wrongpassword" || password === "invalid123") {
            callback(false, null, qsTr("Invalid credentials. Please re-enter your password."))
            return
        }

        // Standard success payload
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
            }
        }
        callback(true, responseData, "")
    }

    function mockRegister(payload, callback) {
        var email = payload.email.toLowerCase()
        if (email === "duplicate@skyx.aero" || email.indexOf("exists") !== -1) {
            callback(false, null, qsTr("An account with this email address already exists."))
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

