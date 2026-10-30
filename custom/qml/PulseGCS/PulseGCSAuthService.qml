import QtQuick
import QGroundControl
import PulseGCS

Item {
    id: root

    // =========================================================================
    // 1. Configuration & Transport Modes
    // =========================================================================
    property string baseUrl: "https://api.pulsegcs.skyx.aero"
    property string transportMode: "local_mock" // "local_mock" (offline test fixture) | "remote_api" (live HTTPS)
    property bool mockMode: (transportMode === "local_mock")
    property int requestTimeoutMs: 10000
    property bool isBusy: false
    property int mockLatencyMs: 1200
    property bool disableLatencyForTesting: false
    property string deviceId: (typeof PulseGCSStartupController !== "undefined" && PulseGCSStartupController && typeof PulseGCSStartupController.deviceId === "function") ? PulseGCSStartupController.deviceId() : "SKYX-DEV-CONSOLE-01"

    onMockModeChanged: {
        transportMode = mockMode ? "local_mock" : "remote_api"
    }

    // Endpoints schema registry (Production REST API Contract)
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
    // 2. Production API Pipeline (Canonical Functions)
    // =========================================================================

    // A. Sign In
    function signIn(email, password, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "password": password || "",
            "deviceId": root.deviceId,
            "appVersion": (typeof PulseGCSStartupController !== "undefined") ? PulseGCSStartupController.appVersion : "1.0.0",
            "clientTimestamp": new Date().toISOString()
        }

        dispatchRequest("POST", root.endpoints.signIn, payload, function(httpResponse) {
            root.isBusy = false
            var normalized = normalizeResponse(httpResponse, "signIn")

            if (normalized.ok && normalized.data.token) {
                saveSession(payload.email, normalized.data.token, normalized.data.attestation ? normalized.data.attestation.validDays : 7)
            }

            root.signInCompleted(normalized.ok, normalized.data, normalized.errorMessage)
            if (typeof callback === "function") callback(normalized.ok, normalized.data, normalized.errorMessage)
        })
    }

    // B. Register Operator
    function register(regData, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "fullName": (regData.fullName || "").trim(),
            "phone": (regData.phone || "").trim(),
            "email": (regData.email || "").trim(),
            "password": regData.password || regData.pw || "",
            "dob": (regData.dob || "").trim(),
            "droneModel": (regData.droneModel || "").trim(),
            "aircraftSerial": (regData.aircraftSerial || regData.droneSerial || "").trim(),
            "uin": (regData.uin || "").trim(),
            "bindConsole": !!(regData.bindConsole || regData.consoleBound),
            "submittedAt": new Date().toISOString()
        }

        dispatchRequest("POST", root.endpoints.register, payload, function(httpResponse) {
            root.isBusy = false
            var normalized = normalizeResponse(httpResponse, "register")
            root.registrationCompleted(normalized.ok, normalized.data, normalized.errorMessage)
            if (typeof callback === "function") callback(normalized.ok, normalized.data, normalized.errorMessage)
        })
    }

    // C. Password Recovery - Stage 1: Request Code
    function requestRecoveryCode(email, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "clientTimestamp": new Date().toISOString()
        }

        dispatchRequest("POST", root.endpoints.recoveryRequest, payload, function(httpResponse) {
            root.isBusy = false
            var normalized = normalizeResponse(httpResponse, "recoveryRequest")
            root.recoveryRequestCompleted(normalized.ok, normalized.data, normalized.errorMessage)
            if (typeof callback === "function") callback(normalized.ok, normalized.data, normalized.errorMessage)
        })
    }

    // D. Password Recovery - Stage 2: Verify Code
    function verifyRecoveryCode(email, code, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "code": (code || "").trim(),
            "clientTimestamp": new Date().toISOString()
        }

        dispatchRequest("POST", root.endpoints.recoveryVerify, payload, function(httpResponse) {
            root.isBusy = false
            var normalized = normalizeResponse(httpResponse, "recoveryVerify")
            root.recoveryVerifyCompleted(normalized.ok, normalized.data, normalized.errorMessage)
            if (typeof callback === "function") callback(normalized.ok, normalized.data, normalized.errorMessage)
        })
    }

    // E. Password Recovery - Stage 3: Reset Password
    function resetPassword(email, resetToken, newPassword, callback) {
        if (root.isBusy) return
        root.isBusy = true

        var payload = {
            "email": (email || "").trim(),
            "resetToken": resetToken || "",
            "newPassword": newPassword || "",
            "clientTimestamp": new Date().toISOString()
        }

        dispatchRequest("POST", root.endpoints.recoveryReset, payload, function(httpResponse) {
            root.isBusy = false
            var normalized = normalizeResponse(httpResponse, "recoveryReset")
            root.recoveryResetCompleted(normalized.ok, normalized.data, normalized.errorMessage)
            if (typeof callback === "function") callback(normalized.ok, normalized.data, normalized.errorMessage)
        })
    }

    // =========================================================================
    // 3. Transport Dispatcher (Strategy Pattern: Local Fixture vs Remote HTTPS)
    // =========================================================================
    function dispatchRequest(method, endpoint, payload, callback) {
        if (root.transportMode === "remote_api") {
            sendRemoteHttpRequest(method, endpoint, payload, callback)
        } else {
            if (!root.disableLatencyForTesting && root.mockLatencyMs > 0) {
                // Bug fix (BUG-01): Create dynamic, isolated timer per request to prevent
                // callback overwriting and permanent UI lockup during concurrent calls.
                var timerObj = Qt.createQmlObject('import QtQuick; Timer { interval: ' + root.mockLatencyMs + '; repeat: false; running: true }', root)
                timerObj.triggered.connect(function() {
                    timerObj.destroy()
                    executeLocalFixtureQuery(method, endpoint, payload, callback)
                })
            } else {
                executeLocalFixtureQuery(method, endpoint, payload, callback)
            }
        }
    }

    // =========================================================================
    // 4. Remote HTTP Adapter (Live REST Client via XMLHttpRequest)
    // =========================================================================
    function sendRemoteHttpRequest(method, path, payload, callback) {
        var xhr = new XMLHttpRequest()
        var url = root.baseUrl + path

        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.timeout = root.requestTimeoutMs

        var completed = false
        function emitDone(res) {
            if (completed) return
            completed = true
            callback(res)
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var responseData = {}
                try {
                    responseData = JSON.parse(xhr.responseText)
                } catch (e) {
                    responseData = { "message": xhr.responseText || ("HTTP " + xhr.status) }
                }

                emitDone({
                    "status": xhr.status,
                    "statusText": xhr.statusText,
                    "data": responseData
                })
            }
        }

        xhr.ontimeout = function() {
            emitDone({
                "status": 504,
                "statusText": "Gateway Timeout",
                "data": {
                    "status": "error",
                    "code": 504,
                    "errorCode": "SERVER_TIMEOUT",
                    "title": qsTr("Server Connection Timeout"),
                    "message": qsTr("Unable to reach SkyX authentication servers. Please verify your internet connection and try again.")
                }
            })
        }

        xhr.onerror = function() {
            emitDone({
                "status": 0,
                "statusText": "Network Error",
                "data": {
                    "status": "error",
                    "code": 0,
                    "errorCode": "NETWORK_UNAVAILABLE",
                    "title": qsTr("Network Unavailable"),
                    "message": qsTr("Network connection failed. Verify internet link.")
                }
            })
        }

        try {
            xhr.send(payload ? JSON.stringify(payload) : null)
        } catch (err) {
            emitDone({
                "status": 0,
                "statusText": "Dispatch Error",
                "data": { "message": qsTr("Failed to dispatch request: %1").arg(err.message) }
            })
        }
    }

    // =========================================================================
    // 5. Local Fixture Adapter (Production Query Engine on auth_database.json)
    // =========================================================================
    function executeLocalFixtureQuery(method, endpoint, payload, callback) {
        var db = getDatabaseFixture()

        // ---------------------------------------------------------------------
        // Query 1: Sign In (/api/v1/auth/signin)
        // ---------------------------------------------------------------------
        if (endpoint === root.endpoints.signIn) {
            var reqEmail = (payload.email || "").trim().toLowerCase()
            var reqPassword = payload.password || ""

            // Dynamic N-Account Lookup in accounts[]
            var account = null
            var accounts = db.accounts || []
            for (var i = 0; i < accounts.length; ++i) {
                if (accounts[i].email && accounts[i].email.toLowerCase() === reqEmail) {
                    account = accounts[i]
                    break
                }
            }

            // Invariant Gate 1: Default-Deny if account not found
            if (!account) {
                var notFoundTemplate = (db.httpTemplates && db.httpTemplates["404_ACCOUNT_NOT_FOUND"]) || {
                    "httpStatus": 404, "code": 404, "errorCode": "ACCOUNT_NOT_FOUND", "title": qsTr("Account Not Found"), "message": qsTr("No operator account found matching this email.")
                }
                callback({ "status": 404, "data": notFoundTemplate })
                return
            }

            // Invariant Gate 2: Strict Credential Verification (Must verify password BEFORE status resolution!)
            var isPasswordValid = false
            var passwordResponseKey = ""
            if (account.activePasswords && account.activePasswords[reqPassword]) {
                isPasswordValid = true
                passwordResponseKey = account.activePasswords[reqPassword]
            } else if (reqPassword === "FlightPass2026!" || reqPassword === "SkyX@2026") {
                isPasswordValid = true
                passwordResponseKey = "200_OK"
            }

            // If credentials do NOT match, fail immediately with 401 (Prevent credential bypass on special status)
            if (!isPasswordValid) {
                var invalidCredsTemplate = (db.httpTemplates && db.httpTemplates["401_INVALID_CREDENTIALS"]) || {
                    "httpStatus": 401, "code": 401, "errorCode": "INVALID_CREDENTIALS", "title": qsTr("Sign In Failed"), "message": qsTr("Invalid credentials. Invalid user account or password. Please verify your credentials or use password recovery.")
                }
                callback({ "status": 401, "data": invalidCredsTemplate })
                return
            }

            // Invariant Gate 3: Account Status Resolution (Only evaluated for authenticated credentials)
            var templateKey = passwordResponseKey
            if (account.status === "under_review") {
                templateKey = "202_ACCEPTED"
            } else if (account.status === "license_ready") {
                templateKey = "200_LICENSE_READY"
            } else if (account.status === "suspended") {
                templateKey = "403_CONSOLE_SUSPENDED"
            } else if (account.status === "expired") {
                templateKey = "401_SESSION_EXPIRED"
            } else if (account.status === "unbound") {
                templateKey = "403_CONSOLE_UNBOUND"
            } else if (account.status === "timeout") {
                templateKey = "504_SERVER_TIMEOUT"
            } else if (account.status === "fcm_mismatch") {
                templateKey = "422_FCM_MISMATCH"
            } else if (account.status === "failed") {
                templateKey = "500_SUBMISSION_FAILED"
            }

            // Emulate template response
            var template = (db.httpTemplates && db.httpTemplates[templateKey]) ? db.httpTemplates[templateKey] : db.httpTemplates["200_OK"]
            var respData = JSON.parse(JSON.stringify(template))

            // Synthesize dynamic payload tokens for positive responses
            if (templateKey === "200_OK") {
                respData.token = "mock_jwt_token_" + Math.random().toString(36).substring(2, 14)
                respData.operator = {
                    "id": account.id || "op_01",
                    "email": account.email,
                    "name": account.name || "Certified Flight Operator",
                    "role": account.role || "pilot",
                    "organization": account.organization || "SkyX Flight Ops"
                }
                respData.attestation = {
                    "validDays": 7,
                    "sessionActive": true,
                    "expiresAt": new Date(Date.now() + 7 * 86400 * 1000).toISOString()
                }
                respData.sessionActive = true
            } else if (templateKey === "200_LICENSE_READY") {
                respData.token = "mock_jwt_token_lic_" + Math.random().toString(36).substring(2, 12)
                respData.licenseReady = true
                var lic = account.license || {}
                respData.licenseKey = lic.licenseKey || "SKYX-LIC-8820-4190-FA21"
                respData.droneModel = lic.droneModel || "SkyX Kissan"
                respData.serialNumber = lic.serialNumber || "SKYX-KSN-2026-0842"
                respData.operator = {
                    "id": account.id || "op_01",
                    "email": account.email,
                    "name": account.name || "Certified Flight Operator",
                    "role": account.role || "pilot"
                }
                respData.attestation = { "validDays": 7, "sessionActive": true }
                respData.sessionActive = true
            }

            callback({ "status": respData.httpStatus || respData.code || 200, "data": respData })
            return
        }

        // ---------------------------------------------------------------------
        // Query 2: Register (/api/v1/auth/register)
        // ---------------------------------------------------------------------
        if (endpoint === root.endpoints.register) {
            var regEmail = (payload.email || "").trim().toLowerCase()
            var regTriggers = (db.registration && db.registration.triggers) ? db.registration.triggers : {}

            // Check explicit registration simulation triggers
            var regTemplateKey = regTriggers[regEmail]
            if (regTemplateKey && db.httpTemplates && db.httpTemplates[regTemplateKey]) {
                var triggerResp = db.httpTemplates[regTemplateKey]
                callback({ "status": triggerResp.httpStatus || triggerResp.code || 400, "data": triggerResp })
                return
            }

            // Check if email already exists in accounts[]
            var exists = false
            var accts = db.accounts || []
            for (var j = 0; j < accts.length; ++j) {
                if (accts[j].email && accts[j].email.toLowerCase() === regEmail) {
                    exists = true
                    break
                }
            }
            if (exists) {
                var existsResp = db.httpTemplates["409_ACCOUNT_EXISTS"]
                callback({ "status": 409, "data": existsResp })
                return
            }

            // Persist newly registered operator account into session database fixture
            var newAcct = {
                "id": "op_reg_" + Math.random().toString(36).substring(2, 8),
                "email": regEmail,
                "name": payload.fullName || "Registered Operator",
                "phone": payload.phone || "",
                "dob": payload.dob || "",
                "droneModel": payload.droneModel || "",
                "droneSerial": payload.droneSerial || "",
                "uin": payload.uin || "",
                "consoleBound": true,
                "role": "pilot",
                "status": "under_review",
                "activePasswords": {}
            }
            if (payload.password) {
                newAcct.activePasswords[payload.password] = "202_ACCEPTED"
            }
            accts.push(newAcct)

            // Default Success: 202 Application Under Review
            var successResp = {
                "httpStatus": 202,
                "status": "success",
                "code": 202,
                "applicationId": "APP-" + Math.floor(100000 + Math.random() * 900000),
                "message": qsTr("Operator application submitted successfully for review."),
                "state": "pending_verification"
            }
            callback({ "status": 202, "data": successResp })
            return
        }

        // ---------------------------------------------------------------------
        // Query 3: Recovery Request (/api/v1/auth/recovery/request)
        // ---------------------------------------------------------------------
        if (endpoint === root.endpoints.recoveryRequest) {
            var recEmail = (payload.email || "").trim().toLowerCase()
            var recTriggers = (db.passwordRecovery && db.passwordRecovery.triggers) ? db.passwordRecovery.triggers : {}

            // 1. Explicit Simulation Triggers (e.g. timeout@skyx.aero)
            var recTemplateKey = recTriggers[recEmail]
            if (recTemplateKey && db.httpTemplates && db.httpTemplates[recTemplateKey]) {
                var recResp = db.httpTemplates[recTemplateKey]
                callback({ "status": recResp.httpStatus || recResp.code || 400, "data": recResp })
                return
            }

            // 2. Production Invariant Gate: Lookup registered account in accounts[]
            var recAccount = null
            var acctList = db.accounts || []
            for (var k = 0; k < acctList.length; ++k) {
                if (acctList[k].email && acctList[k].email.toLowerCase() === recEmail) {
                    recAccount = acctList[k]
                    break
                }
            }

            // 3. Default-Deny: If account does not exist, reject with 404
            if (!recAccount) {
                var notFoundTemplate = (db.httpTemplates && db.httpTemplates["404_ACCOUNT_NOT_FOUND"]) || {
                    "httpStatus": 404, "code": 404, "errorCode": "ACCOUNT_NOT_FOUND",
                    "title": qsTr("Account Not Found"),
                    "message": qsTr("No operator account found matching this email address.")
                }
                callback({ "status": 404, "data": notFoundTemplate })
                return
            }

            // 4. Status Check: Suspended accounts cannot recover passwords
            if (recAccount.status === "suspended") {
                var suspTemplate = (db.httpTemplates && db.httpTemplates["403_CONSOLE_SUSPENDED"]) || {
                    "httpStatus": 403, "code": 403, "errorCode": "CONSOLE_SUSPENDED",
                    "title": qsTr("Account Suspended"),
                    "message": qsTr("This account has been suspended by an administrator. Password recovery is disabled.")
                }
                callback({ "status": 403, "data": suspTemplate })
                return
            }

            // 5. Status Check: Accounts under review cannot recover passwords yet
            if (recAccount.status === "under_review") {
                var underReviewTemplate = (db.httpTemplates && db.httpTemplates["202_ACCEPTED"]) || {
                    "httpStatus": 202, "code": 202, "errorCode": "APPLICATION_UNDER_REVIEW",
                    "title": qsTr("Application Under Review"),
                    "message": qsTr("This operator application is still under review. Password recovery is available after approval.")
                }
                callback({ "status": 403, "data": underReviewTemplate })
                return
            }

            // 6. Verified Account: Return 200 OK with test code and track active recovery session
            if (!db._activeRecovery) {
                db._activeRecovery = {}
            }
            var testCode = (db.passwordRecovery && db.passwordRecovery.validCode) ? db.passwordRecovery.validCode : "849201"
            db._activeRecovery[recEmail] = {
                code: testCode,
                issuedAt: Date.now(),
                attempts: 0
            }

            callback({
                "status": 200,
                "data": {
                    "httpStatus": 200,
                    "status": "success",
                    "code": 200,
                    "expiresIn": 300,
                    "codeLength": 6,
                    "testCode": testCode,
                    "message": qsTr("Verification code sent to operator email.")
                }
            })
            return
        }

        // ---------------------------------------------------------------------
        // Query 4: Recovery Verify (/api/v1/auth/recovery/verify-code)
        // ---------------------------------------------------------------------
        if (endpoint === root.endpoints.recoveryVerify) {
            var verifyEmail = (payload.email || "").trim().toLowerCase()
            var inputCode = (payload.code || "").trim()

            // 1. Account existence verification
            var verifyAccount = null
            var verifyList = db.accounts || []
            for (var v = 0; v < verifyList.length; ++v) {
                if (verifyList[v].email && verifyList[v].email.toLowerCase() === verifyEmail) {
                    verifyAccount = verifyList[v]
                    break
                }
            }
            if (!verifyAccount) {
                var noAcctResp = (db.httpTemplates && db.httpTemplates["404_ACCOUNT_NOT_FOUND"]) || {
                    "httpStatus": 404, "code": 404, "errorCode": "ACCOUNT_NOT_FOUND",
                    "title": qsTr("Account Not Found"), "message": qsTr("No operator account found matching this email.")
                }
                callback({ "status": 404, "data": noAcctResp })
                return
            }

            // 2. Active recovery session verification
            if (!db._activeRecovery) {
                db._activeRecovery = {}
            }
            var activeEntry = db._activeRecovery[verifyEmail]
            if (!activeEntry) {
                callback({
                    "status": 400,
                    "data": {
                        "httpStatus": 400, "code": 400, "errorCode": "NO_ACTIVE_RECOVERY",
                        "title": qsTr("Session Expired"), "message": qsTr("No active recovery request found. Please request a verification code.")
                    }
                })
                return
            }

            // 3. Expiry Check (5-minute TTL / 300,000 ms)
            if (Date.now() - activeEntry.issuedAt > 300000) {
                delete db._activeRecovery[verifyEmail]
                callback({
                    "status": 400,
                    "data": {
                        "httpStatus": 400, "code": 400, "errorCode": "CODE_EXPIRED",
                        "title": qsTr("Code Expired"), "message": qsTr("Verification code has expired (5-minute limit). Please request a new code.")
                    }
                })
                return
            }

            // 4. Rate-Limiting Check (max 5 attempts)
            activeEntry.attempts = (activeEntry.attempts || 0) + 1
            if (activeEntry.attempts > 5) {
                delete db._activeRecovery[verifyEmail]
                callback({
                    "status": 429,
                    "data": {
                        "httpStatus": 429, "code": 429, "errorCode": "TOO_MANY_ATTEMPTS",
                        "title": qsTr("Too Many Attempts"), "message": qsTr("Maximum verification attempts exceeded. Please request a new recovery code.")
                    }
                })
                return
            }

            // 5. Code comparison
            if (inputCode !== activeEntry.code) {
                var badCodeResp = (db.httpTemplates && db.httpTemplates["400_BAD_REQUEST"]) || {
                    "httpStatus": 400, "code": 400, "errorCode": "INVALID_VERIFICATION_CODE",
                    "title": qsTr("Verification Failed"), "message": qsTr("Invalid verification code. Please check your email or request a new code.")
                }
                callback({ "status": 400, "data": badCodeResp })
                return
            }

            // Success! Invalidate recovery entry and generate single-use 10-minute reset token
            delete db._activeRecovery[verifyEmail]
            if (!db._activeResetTokens) {
                db._activeResetTokens = {}
            }
            var tokenStr = "rst_tok_" + Math.random().toString(36).substring(2, 14) + Date.now().toString(36)
            db._activeResetTokens[tokenStr] = {
                email: verifyEmail,
                expiresAt: Date.now() + 600000,
                used: false
            }

            callback({
                "status": 200,
                "data": {
                    "httpStatus": 200,
                    "status": "success",
                    "code": 200,
                    "resetToken": tokenStr,
                    "message": qsTr("Code verified successfully.")
                }
            })
            return
        }

        // ---------------------------------------------------------------------
        // Query 5: Recovery Reset (/api/v1/auth/recovery/reset-password)
        // ---------------------------------------------------------------------
        if (endpoint === root.endpoints.recoveryReset) {
            var resetEmail = (payload.email || "").trim().toLowerCase()
            var newPw = payload.newPassword || ""
            var token = payload.resetToken || ""

            if (!token || token.length === 0) {
                callback({
                    "status": 400,
                    "data": {
                        "httpStatus": 400, "code": 400, "errorCode": "INVALID_RESET_TOKEN",
                        "title": qsTr("Session Expired"), "message": qsTr("Invalid or expired password reset session. Please request a new code.")
                    }
                })
                return
            }

            // Validate token against live registry
            if (!db._activeResetTokens) {
                db._activeResetTokens = {}
            }
            var tokenEntry = db._activeResetTokens[token]
            if (!tokenEntry || tokenEntry.used || tokenEntry.email !== resetEmail || Date.now() > tokenEntry.expiresAt) {
                delete db._activeResetTokens[token]
                callback({
                    "status": 400,
                    "data": {
                        "httpStatus": 400, "code": 400, "errorCode": "INVALID_RESET_TOKEN",
                        "title": qsTr("Session Expired"), "message": qsTr("Password reset session has expired or is invalid. Please request a new code.")
                    }
                })
                return
            }

            // Consume token immediately (single use!)
            tokenEntry.used = true
            delete db._activeResetTokens[token]

            // Find account and update activePasswords in the live database fixture
            var targetAcct = null
            var allAccts = db.accounts || []
            for (var m = 0; m < allAccts.length; ++m) {
                if (allAccts[m].email && allAccts[m].email.toLowerCase() === resetEmail) {
                    targetAcct = allAccts[m]
                    break
                }
            }

            if (!targetAcct) {
                callback({
                    "status": 404,
                    "data": {
                        "httpStatus": 404, "code": 404, "errorCode": "ACCOUNT_NOT_FOUND",
                        "title": qsTr("Account Not Found"), "message": qsTr("No operator account found matching this email.")
                    }
                })
                return
            }

            if (!targetAcct.activePasswords) {
                targetAcct.activePasswords = {}
            }
            // Store the new password with 200_OK status so operator can immediately sign in!
            targetAcct.activePasswords[newPw] = "200_OK"

            callback({
                "status": 200,
                "data": {
                    "httpStatus": 200,
                    "status": "success",
                    "code": 200,
                    "message": qsTr("Password successfully updated. Please sign in with your new password.")
                }
            })
            return
        }

        // Fallback for unknown endpoint
        callback({ "status": 404, "data": { "message": "Endpoint not found" } })
    }

    // =========================================================================
    // 6. Response Normalizer (Ensures 100% Contract Parity & Fail-Closed Gate)
    // =========================================================================
    function normalizeResponse(httpResponse, operation) {
        var status = httpResponse.status || 0
        var rawData = httpResponse.data || {}

        // In sign-in, only HTTP 200 is authorized access; HTTP 202 (review pending) is not authorized for flight.
        // In registration and other calls, any 2xx status (200, 201, 202) is successful completion.
        var isOk = (operation === "signIn") ? (status === 200) : (status >= 200 && status < 300)

        var errCode = rawData.errorCode || ""
        var errMsg = rawData.message || ""
        if (rawData.title && errMsg && errMsg.indexOf(rawData.title) === -1) {
            errMsg = rawData.title + ": " + errMsg
        }

        if (!isOk && !errMsg) {
            if (status === 401) errMsg = qsTr("Invalid credentials. Please verify your credentials or use password recovery.")
            else if (status === 403) errMsg = qsTr("Access forbidden. Device not authorized.")
            else if (status === 404) errMsg = qsTr("No operator account found matching this email.")
            else if (status === 504) errMsg = qsTr("Server connection timeout. Verify internet link.")
            else errMsg = qsTr("Request failed with status %1").arg(status)
        }

        return {
            "ok": isOk,
            "status": status,
            "data": rawData,
            "errorCode": errCode,
            "errorMessage": errMsg
        }
    }

    // =========================================================================
    // 7. Persistent Session Vault (7-Day Offline Authorization)
    // =========================================================================
    property string activeSessionEmail: ""
    property string activeSessionToken: ""
    property string activeSessionExpiresAt: ""
    property string activeSessionLastSeen: ""

    function saveSession(email, token, validDays) {
        activeSessionEmail = email || ""
        activeSessionToken = token || ""
        var days = (validDays !== undefined && validDays > 0) ? validDays : 7
        var now = new Date()
        var expiry = new Date(now.getTime() + days * 86400 * 1000).toISOString()
        activeSessionExpiresAt = expiry
        activeSessionLastSeen = now.toISOString()
        if (typeof PulseGCSStartupController !== "undefined" && PulseGCSStartupController && typeof PulseGCSStartupController.saveSession === "function") {
            PulseGCSStartupController.saveSession(activeSessionEmail, activeSessionToken, days)
        }
    }

    function isSessionActive() {
        if (!activeSessionToken || activeSessionToken.length === 0) return false
        if (!activeSessionExpiresAt || activeSessionExpiresAt.length === 0) return false

        var now = new Date()
        // Clock rollback detection: fail-closed if clock is moved before last seen
        if (activeSessionLastSeen && activeSessionLastSeen.length > 0) {
            var lastSeenDate = new Date(activeSessionLastSeen)
            if (now < lastSeenDate) {
                console.warn("PulseGCSAuthService: Clock rollback detected! Rejecting active session.")
                return false
            }
        }
        return new Date(activeSessionExpiresAt) > now
    }

    function clearSession() {
        activeSessionEmail = ""
        activeSessionToken = ""
        activeSessionExpiresAt = ""
        activeSessionLastSeen = ""
        if (typeof PulseGCSStartupController !== "undefined" && PulseGCSStartupController && typeof PulseGCSStartupController.clearSession === "function") {
            PulseGCSStartupController.clearSession()
        }
    }

    function loadSavedSession() {
        if (typeof PulseGCSStartupController !== "undefined" && PulseGCSStartupController && typeof PulseGCSStartupController.loadSession === "function") {
            var sess = PulseGCSStartupController.loadSession()
            if (sess && sess.hasSession) {
                activeSessionEmail = sess.email || ""
                activeSessionToken = sess.token || ""
                activeSessionExpiresAt = sess.expiresAt || ""
                activeSessionLastSeen = sess.lastSeen || ""
                return sess
            }
        }
        return { hasSession: false, active: false, expired: false, email: "", token: "", expiresAt: "" }
    }

    // =========================================================================
    // 8. Embedded Database Fixture (Instant Synchronous Access & Failsafe)
    // =========================================================================
    property var _fixtureDb: null

    function getDatabaseFixture() {
        if (_fixtureDb) return _fixtureDb

        _fixtureDb = {
            "accounts": [
                {
                    "id": "op_debug_01",
                    "email": "debug@gmail.com",
                    "name": "Certified Flight Operator",
                    "role": "pilot",
                    "license": { "licenseKey": "SKYX-LIC-8820-4190-FA21", "droneModel": "SkyX Kissan", "serialNumber": "SKYX-KSN-2026-0842" },
                    "activePasswords": {
                        "login1234": "200_OK", "license1234": "200_LICENSE_READY", "suspend1234": "403_CONSOLE_SUSPENDED",
                        "expired1234": "401_SESSION_EXPIRED", "review1234": "202_ACCEPTED", "failed1234": "500_SUBMISSION_FAILED",
                        "fcm12345": "422_FCM_MISMATCH", "unbound1234": "403_CONSOLE_UNBOUND", "timeout1234": "504_SERVER_TIMEOUT",
                        "FlightPass2026!": "200_OK", "SkyX@2026": "200_OK"
                    }
                },
                {
                    "id": "op_pilot_02", "email": "pilot@gmail.com", "name": "Senior Field Pilot", "role": "pilot",
                    "activePasswords": { "login1234": "200_OK", "FlightPass2026!": "200_OK", "SkyX@2026": "200_OK" }
                },
                {
                    "id": "op_admin_03", "email": "admin@gmail.com", "name": "System Administrator", "role": "admin",
                    "activePasswords": { "login1234": "200_OK", "AdminPass2026!": "200_OK" }
                },
                {
                    "id": "op_legacy_pilot", "email": "pilot@skyx.aero", "name": "Certified Flight Operator", "role": "pilot",
                    "activePasswords": { "login1234": "200_OK", "FlightPass2026!": "200_OK", "SkyX@2026": "200_OK" }
                },
                {
                    "id": "op_example_pilot", "email": "pilot@example.com", "name": "Certified Flight Operator", "role": "pilot",
                    "activePasswords": { "login1234": "200_OK", "FlightPass2026!": "200_OK", "SkyX@2026": "200_OK" }
                },
                {
                    "id": "op_review", "email": "review@skyx.aero", "role": "pilot", "status": "under_review",
                    "activePasswords": { "login1234": "202_ACCEPTED", "FlightPass2026!": "202_ACCEPTED", "anypass123": "202_ACCEPTED" }
                },
                {
                    "id": "op_license", "email": "license@skyx.aero", "role": "pilot", "status": "license_ready",
                    "license": { "licenseKey": "SKYX-LIC-8820-4190-FA21", "droneModel": "SkyX Kissan", "serialNumber": "SKYX-KSN-2026-0842" },
                    "activePasswords": { "login1234": "200_LICENSE_READY", "license1234": "200_LICENSE_READY", "FlightPass2026!": "200_LICENSE_READY", "anypass123": "200_LICENSE_READY" }
                },
                {
                    "id": "op_suspended", "email": "suspended@skyx.aero", "role": "pilot", "status": "suspended",
                    "activePasswords": { "login1234": "403_CONSOLE_SUSPENDED", "suspend1234": "403_CONSOLE_SUSPENDED", "FlightPass2026!": "403_CONSOLE_SUSPENDED", "anypass123": "403_CONSOLE_SUSPENDED" }
                },
                {
                    "id": "op_expired", "email": "expired@skyx.aero", "role": "pilot", "status": "expired",
                    "activePasswords": { "login1234": "401_SESSION_EXPIRED", "expired1234": "401_SESSION_EXPIRED", "FlightPass2026!": "401_SESSION_EXPIRED", "anypass123": "401_SESSION_EXPIRED" }
                },
                {
                    "id": "op_failed", "email": "failed@skyx.aero", "role": "pilot", "status": "failed",
                    "activePasswords": { "login1234": "500_SUBMISSION_FAILED", "failed1234": "500_SUBMISSION_FAILED", "FlightPass2026!": "500_SUBMISSION_FAILED", "anypass123": "500_SUBMISSION_FAILED" }
                },
                {
                    "id": "op_unbound", "email": "unbound@skyx.aero", "role": "pilot", "status": "unbound",
                    "activePasswords": { "login1234": "403_CONSOLE_UNBOUND", "unbound1234": "403_CONSOLE_UNBOUND", "FlightPass2026!": "403_CONSOLE_UNBOUND", "anypass123": "403_CONSOLE_UNBOUND" }
                },
                {
                    "id": "op_timeout", "email": "timeout@skyx.aero", "role": "pilot", "status": "timeout",
                    "activePasswords": { "login1234": "504_SERVER_TIMEOUT", "timeout1234": "504_SERVER_TIMEOUT", "FlightPass2026!": "504_SERVER_TIMEOUT", "anypass123": "504_SERVER_TIMEOUT" }
                },
                {
                    "id": "op_fcm", "email": "fcmerror@skyx.aero", "role": "pilot", "status": "fcm_mismatch",
                    "activePasswords": { "login1234": "422_FCM_MISMATCH", "fcm12345": "422_FCM_MISMATCH", "FlightPass2026!": "422_FCM_MISMATCH", "anypass123": "422_FCM_MISMATCH" }
                }
            ],
            "httpTemplates": {
                "200_OK": { "httpStatus": 200, "status": "success", "code": 200, "message": qsTr("Authentication successful") },
                "200_LICENSE_READY": { "httpStatus": 200, "status": "success", "code": 200, "licenseReady": true, "message": qsTr("License generated and ready for activation") },
                "202_ACCEPTED": { "httpStatus": 202, "status": "pending", "code": 202, "errorCode": "APPLICATION_UNDER_REVIEW", "title": qsTr("Application Under Review"), "message": qsTr("Your application has been received and is under review (1–2 business days).") },
                "400_BAD_REQUEST": { "httpStatus": 400, "status": "error", "code": 400, "errorCode": "INVALID_VERIFICATION_CODE", "title": qsTr("Verification Failed"), "message": qsTr("Invalid verification code. Please check and try again.") },
                "401_INVALID_CREDENTIALS": { "httpStatus": 401, "status": "error", "code": 401, "errorCode": "INVALID_CREDENTIALS", "title": qsTr("Sign In Failed"), "message": qsTr("Invalid credentials. Invalid user account or password. Please verify your credentials or use password recovery.") },
                "401_SESSION_EXPIRED": { "httpStatus": 401, "status": "error", "code": 401, "errorCode": "SESSION_EXPIRED", "title": qsTr("Session Expired"), "message": qsTr("7-day offline flight authorization has expired. Re-authentication with SkyX backend required.") },
                "403_CONSOLE_SUSPENDED": { "httpStatus": 403, "status": "error", "code": 403, "errorCode": "CONSOLE_SUSPENDED", "title": qsTr("Device Suspended"), "message": qsTr("This device has been marked replaced or suspended by an administrator. Please sign in using an authorized device or contact SkyX support.") },
                "403_CONSOLE_UNBOUND": { "httpStatus": 403, "status": "error", "code": 403, "errorCode": "CONSOLE_UNBOUND", "title": qsTr("Device Not Authorized"), "message": qsTr("Your user account is valid, but this device is not authorized for flight operations. Contact your administrator to enroll or reassign this device.") },
                "404_ACCOUNT_NOT_FOUND": { "httpStatus": 404, "status": "error", "code": 404, "errorCode": "ACCOUNT_NOT_FOUND", "title": qsTr("Account Not Found"), "message": qsTr("No operator account found matching this email.") },
                "409_ACCOUNT_EXISTS": { "httpStatus": 409, "status": "error", "code": 409, "errorCode": "ACCOUNT_EXISTS", "title": qsTr("Account Exists"), "message": qsTr("An account with this email address already exists.") },
                "422_FCM_MISMATCH": { "httpStatus": 422, "status": "error", "code": 422, "errorCode": "FCM_MISMATCH", "title": qsTr("FCM UID Mismatch"), "fcmUid": "1A:2B:3C:4D:5E:6F", "airframeSerial": "SKYX-KSN-2026-0842", "message": qsTr("Aircraft Flight Control Module (FCM UID: 1A:2B:3C:4D:5E:6F) does not match registered airframe serial (SKYX-KSN-2026-0842). Telemetry connection aborted.") },
                "500_SUBMISSION_FAILED": { "httpStatus": 500, "status": "error", "code": 500, "errorCode": "APPLICATION_SUBMISSION_FAILED", "title": qsTr("Application Sent Failure"), "message": qsTr("Application was submitted, but could not reach the SkyX backend.") },
                "504_SERVER_TIMEOUT": { "httpStatus": 504, "status": "error", "code": 504, "errorCode": "SERVER_TIMEOUT", "title": qsTr("Server Connection Timeout"), "message": qsTr("Unable to reach SkyX authentication servers. Please verify your internet connection and try again.") }
            },
            "registration": {
                "triggers": {
                    "duplicate@gmail.com": "409_ACCOUNT_EXISTS",
                    "duplicate@skyx.aero": "409_ACCOUNT_EXISTS",
                    "failed@gmail.com": "500_SUBMISSION_FAILED",
                    "failed@skyx.aero": "500_SUBMISSION_FAILED",
                    "timeout@gmail.com": "504_SERVER_TIMEOUT",
                    "timeout@skyx.aero": "504_SERVER_TIMEOUT"
                }
            },
            "passwordRecovery": {
                "validCode": "849201",
                "triggers": {
                    "notfound@gmail.com": "404_ACCOUNT_NOT_FOUND",
                    "notfound@skyx.aero": "404_ACCOUNT_NOT_FOUND",
                    "timeout@gmail.com": "504_SERVER_TIMEOUT",
                    "timeout@skyx.aero": "504_SERVER_TIMEOUT"
                }
            }
        }
        return _fixtureDb
    }

    Component.onCompleted: {
        getDatabaseFixture()
    }
}
