import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import PulseGCS

Rectangle {
    id: root
    anchors.fill: parent

    // Public API properties & signals
    property bool isOutdoor: qgcPal.globalTheme === QGCPalette.Light
    signal signInSucceeded(string email)
    signal demoModeClicked()
    signal registrationCompleted(var regData)

    color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShade : PulseGCSTokens.ink
    QGCPalette { id: qgcPal }

    // Backend Authentication & Mock/Live Service
    property alias authService: authService
    property alias signInCard: signInCard
    PulseGCSAuthService {
        id: authService
        baseUrl: "https://api.pulsegcs.skyx.aero"
        mockMode: true
    }

    // Navigation and state machine
    property string currentView: "signin" // "signin" | "register" | "recovery"
    property string inlineNoticeType: ""
    property string inlineNoticeMsg: ""

    // Popups aliases for testability & external access
    property alias licenseReadyPopup: licenseReadyPopup
    property alias suspendedLockoutPopup: suspendedLockoutPopup
    property alias sessionExpiredPopup: sessionExpiredPopup
    property alias fcmMismatchPopup: fcmMismatchPopup
    property alias applicationSentPopup: applicationSentPopup
    property alias submissionIssuePopup: submissionIssuePopup
    property alias passwordUpdatedPopup: passwordUpdatedPopup

    // M3-US07: License Key state
    property string issuedLicenseKey: "SKYX-LIC-8820-4190-FA21"
    property string licensedDroneModel: "SkyX Kissan"
    property string licensedDroneSerial: "SKYX-KSN-2026-0842"
    property string currentLicensedUser: ""
    property bool licenseCopied: false

    // M3-US09: FCM Mismatch state
    property string fcmMismatchUid: "1A:2B:3C:4D:5E:6F"
    property string fcmMismatchSerial: "SKYX-KSN-2026-0842"

    // Clipboard helper
    TextEdit {
        id: copyHelper
        visible: false
    }

    function copyToClipboard(textToCopy) {
        if (typeof PulseGCSStartupController !== "undefined" && typeof PulseGCSStartupController.copyToClipboard === "function") {
            PulseGCSStartupController.copyToClipboard(textToCopy)
        }
        copyHelper.text = textToCopy
        copyHelper.selectAll()
        copyHelper.copy()
    }

    function showLicenseReadyModal(key, model, serial) {
        if (key) issuedLicenseKey = key
        if (model) licensedDroneModel = model
        if (serial) licensedDroneSerial = serial
        licenseCopied = false
        licenseReadyPopup.open()
    }

    function showApplicationUnderReviewModal() {
        applicationSentPopup.open()
    }

    function showSubmissionIssueModal() {
        submissionIssuePopup.open()
    }

    function showSuspendedModal() {
        suspendedLockoutPopup.open()
    }

    function showSessionExpiredModal() {
        sessionExpiredPopup.open()
    }

    function showFcmMismatchModal(uid, serial) {
        if (uid) fcmMismatchUid = uid
        if (serial) fcmMismatchSerial = serial
        fcmMismatchPopup.open()
    }

    Timer {
        id: copyResetTimer
        interval: 2500
        repeat: false
        onTriggered: root.licenseCopied = false
    }

    // Auto-dismiss timer for M3 notification banner (Option 1: 5s auto-close)
    Timer {
        id: noticeTimer
        interval: 5000
        repeat: false
        onTriggered: root.clearNotice()
    }

    function clearNotice() {
        noticeTimer.stop()
        inlineNoticeType = ""
        inlineNoticeMsg = ""
    }

    function showNotice(type, msg) {
        if (!msg || msg.length === 0) {
            clearNotice()
            return
        }
        inlineNoticeType = type
        inlineNoticeMsg = msg
        noticeTimer.restart()
    }

    // =========================================================================
    // Responsive Scrollable Stage (Fully interactive with ScrollBar & Touch Drag)
    // =========================================================================
    Flickable {
        id: scrollStage
        anchors.fill: parent
        anchors.topMargin: ScreenTools.isAndroid ? Math.max(ScreenTools.defaultFontPixelHeight * 1.5, 24) : 16
        anchors.bottomMargin: 16
        contentWidth: width
        contentHeight: scrollContainer.height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.DragAndOvershootBounds
        clip: true
        interactive: true
        pressDelay: 100

        ScrollBar.vertical: ScrollBar {
            id: vbar
            policy: ScrollBar.AsNeeded
        }

        Item {
            id: scrollContainer
            width: scrollStage.width
            height: Math.max(scrollStage.height, mainCard.height + 48)

            Rectangle {
                id: mainCard
                width: Math.min(parent.width - 32, 420)
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(24, (parent.height - height) / 2)
                height: cardLayout.implicitHeight + 44
                radius: PulseGCSTokens.radiusCard
                color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
                border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                border.width: 1

                ColumnLayout {
                    id: cardLayout
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 22
                    spacing: 14

                    // Shared Inline Notice Bar (if active)
                    PulseGCSNoticeBar {
                        id: noticeBar
                        Layout.fillWidth: true
                        visible: root.inlineNoticeMsg.length > 0
                        Layout.preferredHeight: visible ? -1 : 0
                        noticeType: root.inlineNoticeType.length > 0 ? root.inlineNoticeType : "info"
                        message: root.inlineNoticeMsg
                        isOutdoor: root.isOutdoor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearNotice()
                        }
                    }

                    // Module 1: Operator Sign In Card (M3-US01)
                    PulseGCSSignInCard {
                        id: signInCard
                        Layout.fillWidth: true
                        visible: root.currentView === "signin"
                        Layout.preferredHeight: visible ? -1 : 0
                        isOutdoor: root.isOutdoor

                        onSignInRequested: function(email, password) {
                            root.clearNotice()
                            authService.signIn(email, password, function(success, data, errorMsg) {
                                if (success) {
                                    if (data && data.licenseReady) {
                                        root.issuedLicenseKey = data.licenseKey || "SKYX-LIC-8820-4190-FA21"
                                        root.licensedDroneModel = data.droneModel || "SkyX Kissan"
                                        root.licensedDroneSerial = data.serialNumber || "SKYX-KSN-2026-0842"
                                        root.currentLicensedUser = email
                                        root.licenseCopied = false
                                        root.clearNotice()
                                        licenseReadyPopup.open()
                                        return
                                    }
                                    root.showNotice("ok", qsTr("Session Authenticated: Cryptographic identity verified. Your 7-day offline flight authorization is active on this device."))
                                    root.signInSucceeded(email)
                                } else {
                                    if (data && data.errorCode === "CONSOLE_SUSPENDED") {
                                        root.clearNotice()
                                        suspendedLockoutPopup.open()
                                    } else if (data && data.errorCode === "SESSION_EXPIRED") {
                                        root.clearNotice()
                                        sessionExpiredPopup.open()
                                    } else if (data && data.errorCode === "APPLICATION_UNDER_REVIEW") {
                                        root.clearNotice()
                                        applicationSentPopup.open()
                                    } else if (data && data.errorCode === "APPLICATION_SUBMISSION_FAILED") {
                                        root.clearNotice()
                                        submissionIssuePopup.open()
                                    } else if (data && data.errorCode === "CONSOLE_UNBOUND") {
                                        root.showNotice("warn", errorMsg)
                                    } else if (data && data.errorCode === "FCM_MISMATCH") {
                                        root.clearNotice()
                                        if (data.fcmUid) root.fcmMismatchUid = data.fcmUid
                                        if (data.airframeSerial) root.fcmMismatchSerial = data.airframeSerial
                                        fcmMismatchPopup.open()
                                    } else {
                                        root.showNotice("err", errorMsg)
                                    }
                                }
                            })
                        }

                        onDemoModeRequested: {
                            root.clearNotice()
                            root.demoModeClicked()
                        }

                        onForgotPasswordRequested: {
                            root.clearNotice()
                            recoveryCard.resetFlow()
                            root.currentView = "recovery"
                        }

                        onRegisterRequested: {
                            root.clearNotice()
                            registrationCard.resetForm()
                            root.currentView = "register"
                        }

                        onNoticeRequested: function(type, msg) {
                            root.showNotice(type, msg)
                        }
                    }

                    // Module 2: Registration Card (M3-US02, Steps 1 & 2)
                    PulseGCSRegistrationCard {
                        id: registrationCard
                        Layout.fillWidth: true
                        visible: root.currentView === "register"
                        Layout.preferredHeight: visible ? -1 : 0
                        isOutdoor: root.isOutdoor

                        onSignInRequested: {
                            root.clearNotice()
                            root.currentView = "signin"
                        }

                        onApplicationSubmitted: function(regData) {
                            root.clearNotice()
                            authService.register(regData, function(success, data, errorMsg) {
                                if (success) {
                                    if (data && data.licenseReady) {
                                        root.issuedLicenseKey = data.licenseKey || "SKYX-LIC-8820-4190-FA21"
                                        root.licensedDroneModel = data.droneModel || regData.droneModel || "SkyX Kissan"
                                        root.licensedDroneSerial = data.serialNumber || regData.droneSerial || "SKYX-KSN-2026-0842"
                                        root.currentLicensedUser = regData.email
                                        root.licenseCopied = false
                                        root.clearNotice()
                                        licenseReadyPopup.open()
                                    } else {
                                        root.clearNotice()
                                        applicationSentPopup.open()
                                    }
                                    root.registrationCompleted(regData)
                                } else {
                                    if (data && data.errorCode === "ACCOUNT_EXISTS") {
                                        root.showNotice("err", errorMsg)
                                    } else {
                                        root.clearNotice()
                                        submissionIssuePopup.open()
                                    }
                                }
                            })
                        }

                        onNoticeRequested: function(type, msg) {
                            root.showNotice(type, msg)
                        }
                    }

                    // Module 3: Password Recovery Card (M3-US03, Stages 1, 2, & 3)
                    PulseGCSRecoveryCard {
                        id: recoveryCard
                        Layout.fillWidth: true
                        visible: root.currentView === "recovery"
                        Layout.preferredHeight: visible ? -1 : 0
                        isOutdoor: root.isOutdoor
                        authService: authService

                        onSignInRequested: {
                            root.clearNotice()
                            root.currentView = "signin"
                        }

                        onRecoveryCompleted: {
                            root.clearNotice()
                            passwordUpdatedPopup.open()
                        }

                        onNoticeRequested: function(type, msg) {
                            root.showNotice(type, msg)
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // MODALS / POPUPS (M3 Specification Exact Shapes & Behavior)
    // =========================================================================

    // 1. Application Sent to SkyX Backend Popup
    Popup {
        id: applicationSentPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 32, 440)
        padding: 24

        Overlay.modal: Rectangle {
            color: Qt.rgba(5/255, 12/255, 20/255, 0.75)
        }

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: root.isOutdoor ? PulseGCSTokens.subtleBorder(true) : Qt.rgba(47/255, 208/255, 232/255, 0.35)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: root.isOutdoor ? Qt.rgba(0/255, 146/255, 168/255, 0.12) : Qt.rgba(47/255, 208/255, 232/255, 0.15)
                    border.color: root.isOutdoor ? Qt.rgba(0/255, 146/255, 168/255, 0.3) : Qt.rgba(47/255, 208/255, 232/255, 0.35)
                    border.width: 1

                    Canvas {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = root.isOutdoor ? "#0092A8" : "#2FD0E8"
                            ctx.fillStyle = root.isOutdoor ? Qt.rgba(0/255, 146/255, 168/255, 0.2) : Qt.rgba(47/255, 208/255, 232/255, 0.2)
                            ctx.lineWidth = 1.8
                            ctx.lineJoin = "round"
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(21, 1)
                            ctx.lineTo(14, 21)
                            ctx.lineTo(10, 12)
                            ctx.lineTo(1, 8)
                            ctx.closePath()
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(21, 1)
                            ctx.lineTo(10, 12)
                            ctx.stroke()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    renderType: Text.QtRendering
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: applicationSentPopup.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Application Sent to SkyX Backend")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 16
                font.bold: true
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Your application has been received and is under review (1–2 business days).")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 13
                font.bold: true
                color: root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Application Reference: ") + "<font color='" + (root.isOutdoor ? "#007D93" : "#2FD0E8") + "'><b>#SKYX-REG-2026-9041</b></font>"
                textFormat: Text.RichText
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            // Action Button: Clean single Go to Sign In button
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8

                Item { Layout.fillWidth: true }

                Button {
                    id: popupSignBtn
                    implicitHeight: 36
                    implicitWidth: 140
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    text: qsTr("Go to Sign In")

                    contentItem: Text {
                        text: popupSignBtn.text
                        font: popupSignBtn.font
                        color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: popupSignBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                    : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                    }

                    onClicked: {
                        applicationSentPopup.close()
                        root.currentView = "signin"
                    }
                }
            }
        }
    }

    // 1b. Application Submission Issue Popup (M3 Launch Status: Submission Issue)
    Popup {
        id: submissionIssuePopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 32, 440)
        padding: 24

        Overlay.modal: Rectangle {
            color: Qt.rgba(5/255, 12/255, 20/255, 0.75)
        }

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: root.isOutdoor ? PulseGCSTokens.outdoorErr : Qt.rgba(239/255, 68/255, 68/255, 0.35)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: root.isOutdoor ? PulseGCSTokens.outdoorErrBg : Qt.rgba(239/255, 68/255, 68/255, 0.15)
                    border.color: root.isOutdoor ? PulseGCSTokens.outdoorErr : Qt.rgba(239/255, 68/255, 68/255, 0.35)
                    border.width: 1

                    Canvas {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#EF4444"
                            ctx.lineWidth = 1.8
                            ctx.beginPath()
                            ctx.arc(11, 11, 9, 0, 2 * Math.PI)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(11, 6)
                            ctx.lineTo(11, 12)
                            ctx.stroke()
                            ctx.fillStyle = "#EF4444"
                            ctx.beginPath()
                            ctx.arc(11, 15.5, 1.2, 0, 2 * Math.PI)
                            ctx.fill()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    renderType: Text.QtRendering
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: submissionIssuePopup.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Application Sent Failure")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 16
                font.bold: true
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Application was submitted, but could not reach the SkyX backend.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 13
                font.bold: true
                color: "#EF4444"
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Please check your internet connection and try submitting again. Your operator and aircraft details have been preserved.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                Button {
                    id: popupFailedCloseBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Close")

                    contentItem: Text {
                        text: popupFailedCloseBtn.text
                        font: popupFailedCloseBtn.font
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface
                        border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                        border.width: 1
                    }

                    onClicked: {
                        submissionIssuePopup.close()
                    }
                }

                Button {
                    id: popupRetrySubmitBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Retry Submission")

                    contentItem: Text {
                        text: popupRetrySubmitBtn.text
                        font: popupRetrySubmitBtn.font
                        color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: popupRetrySubmitBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                           : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                    }

                    onClicked: {
                        submissionIssuePopup.close()
                        root.currentView = "register"
                    }
                }
            }
        }
    }

    // 2. Password Updated Popup
    Popup {
        id: passwordUpdatedPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 40, 380)
        padding: 24

        Overlay.modal: Rectangle {
            color: Qt.rgba(5/255, 12/255, 20/255, 0.75)
        }

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: root.isOutdoor ? PulseGCSTokens.subtleBorder(true) : Qt.rgba(47/255, 208/255, 232/255, 0.35)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: root.isOutdoor ? PulseGCSTokens.outdoorOkBg : PulseGCSTokens.okBg
                    border.color: root.isOutdoor ? PulseGCSTokens.outdoorOk : PulseGCSTokens.ok
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.family: ScreenTools.normalFontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: root.isOutdoor ? PulseGCSTokens.outdoorOk : PulseGCSTokens.ok
                        renderType: Text.QtRendering
                    }
                }

                Text {
                    text: qsTr("Password Updated")
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    font.bold: true
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    renderType: Text.QtRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Your credentials have been securely updated. You can now sign in with your new password.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            Button {
                id: recovDoneBtn
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 6
                text: qsTr("Sign In Now ›")
                implicitHeight: 34
                implicitWidth: 120
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true

                contentItem: Text {
                    text: recovDoneBtn.text
                    font: recovDoneBtn.font
                    color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }

                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: recovDoneBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                }

                onClicked: {
                    passwordUpdatedPopup.close()
                    recoveryCard.resetFlow()
                    root.currentView = "signin"
                }
            }
        }
    }

    // =========================================================================
    // 3. M3-US07: First-Login License Key Activation Modal
    // =========================================================================
    Popup {
        id: licenseReadyPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 32, 440)
        padding: 24

        Overlay.modal: Rectangle {
            color: Qt.rgba(5/255, 12/255, 20/255, 0.75)
        }

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: root.isOutdoor ? PulseGCSTokens.outdoorOk : Qt.rgba(16/255, 185/255, 129/255, 0.35)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: root.isOutdoor ? "#E6F4EA" : Qt.rgba(16/255, 185/255, 129/255, 0.15)
                    border.color: root.isOutdoor ? "#34A853" : Qt.rgba(16/255, 185/255, 129/255, 0.35)
                    border.width: 1

                    Canvas {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = root.isOutdoor ? "#0D9488" : "#10B981"
                            ctx.lineWidth = 1.8
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.arc(7, 15, 5, 0, 2 * Math.PI)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(11, 11)
                            ctx.lineTo(20, 2)
                            ctx.moveTo(16, 6)
                            ctx.lineTo(19, 9)
                            ctx.moveTo(19, 3)
                            ctx.lineTo(21, 5)
                            ctx.stroke()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    renderType: Text.QtRendering
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: licenseReadyPopup.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("License Key Generated")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 16
                font.bold: true
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Application approved! Your device flight license is ready.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 13
                font.bold: true
                color: root.isOutdoor ? "#0D9488" : "#10B981"
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Please copy and paste this license key for future reference.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            // Issued License Key Card with Copy Action
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 8
                color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: qsTr("ISSUED LICENSE KEY")
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 9
                            font.bold: true
                            color: PulseGCSTokens.mutedText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        Text {
                            text: root.issuedLicenseKey
                            font.family: ScreenTools.fixedFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: PulseGCSTokens.accentColor(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                    }

                    Button {
                        id: copyKeyBtn
                        implicitHeight: 32
                        implicitWidth: root.licenseCopied ? 88 : 84
                        font.family: ScreenTools.normalFontFamily
                        font.pixelSize: 11
                        font.bold: true

                        contentItem: Text {
                            text: root.licenseCopied ? qsTr("✓ Copied!") : qsTr("Copy Key")
                            font: copyKeyBtn.font
                            color: root.licenseCopied ? (root.isOutdoor ? "#0D9488" : "#10B981") : PulseGCSTokens.primaryText(root.isOutdoor)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            renderType: Text.QtRendering
                        }

                        background: Rectangle {
                            radius: PulseGCSTokens.radiusButton
                            color: root.licenseCopied ? (root.isOutdoor ? "#E6F4EA" : Qt.rgba(16/255, 185/255, 129/255, 0.15)) : (root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.surfacePanel)
                            border.color: root.licenseCopied ? (root.isOutdoor ? "#34A853" : "#10B981") : PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                            border.width: 1
                        }

                        onClicked: {
                            root.copyToClipboard(root.issuedLicenseKey)
                            root.licenseCopied = true
                            copyResetTimer.restart()
                        }
                    }
                }
            }

            // Reference Pill Container
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 74
                radius: 6
                color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("License ID:")
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 11
                            color: PulseGCSTokens.mutedText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.issuedLicenseKey
                            font.family: ScreenTools.fixedFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: PulseGCSTokens.accentColor(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Drone Model:")
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 11
                            color: PulseGCSTokens.mutedText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.licensedDroneModel
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Serial Number:")
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 11
                            color: PulseGCSTokens.mutedText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.licensedDroneSerial
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                    }
                }
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8

                Item { Layout.fillWidth: true }

                Button {
                    id: licenseProceedBtn
                    implicitHeight: 36
                    implicitWidth: 160
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    text: qsTr("Proceed to Sign In ›")

                    contentItem: Text {
                        text: licenseProceedBtn.text
                        font: licenseProceedBtn.font
                        color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: licenseProceedBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                         : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                    }

                    onClicked: {
                        licenseReadyPopup.close()
                        root.currentView = "signin"
                        if (root.currentLicensedUser && root.currentLicensedUser.length > 0) {
                            signInCard.email = root.currentLicensedUser
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 4. M3-US11: Device Suspended / Replaced (HTTP 403) Lockout Modal
    // =========================================================================
    Popup {
        id: suspendedLockoutPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 32, 420)
        padding: 24

        Overlay.modal: Rectangle {
            color: Qt.rgba(5/255, 12/255, 20/255, 0.75)
        }

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: root.isOutdoor ? PulseGCSTokens.outdoorErr : Qt.rgba(239/255, 68/255, 68/255, 0.35)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: root.isOutdoor ? PulseGCSTokens.outdoorErrBg : Qt.rgba(239/255, 68/255, 68/255, 0.15)
                    border.color: root.isOutdoor ? PulseGCSTokens.outdoorErr : Qt.rgba(239/255, 68/255, 68/255, 0.35)
                    border.width: 1

                    Canvas {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                            ctx.lineWidth = 1.8
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.arc(11, 7, 4.5, Math.PI, 0)
                            ctx.lineTo(15.5, 10)
                            ctx.moveTo(6.5, 7)
                            ctx.lineTo(6.5, 10)
                            ctx.stroke()
                            ctx.strokeRect(5, 10, 12, 10)
                            ctx.fillStyle = root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                            ctx.beginPath()
                            ctx.arc(11, 14, 1.5, 0, 2 * Math.PI)
                            ctx.fill()
                            ctx.beginPath()
                            ctx.moveTo(11, 14)
                            ctx.lineTo(11, 17)
                            ctx.stroke()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    renderType: Text.QtRendering
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: suspendedLockoutPopup.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Device Suspended")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 16
                font.bold: true
                color: root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("This device has been marked replaced or suspended by an administrator. Please sign in using an authorized device or contact SkyX support.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10

                Item { Layout.fillWidth: true }

                Button {
                    id: suspendedDismissBtn
                    implicitHeight: 34
                    implicitWidth: 120
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Close")

                    contentItem: Text {
                        text: suspendedDismissBtn.text
                        font: suspendedDismissBtn.font
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface
                        border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                        border.width: 1
                    }

                    onClicked: suspendedLockoutPopup.close()
                }
            }
        }
    }

    // =========================================================================
    // 5. M3-US08: 7-Day Session Vault Expired Warning Modal
    // =========================================================================
    Popup {
        id: sessionExpiredPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 32, 420)
        padding: 24

        Overlay.modal: Rectangle {
            color: Qt.rgba(5/255, 12/255, 20/255, 0.75)
        }

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: root.isOutdoor ? PulseGCSTokens.outdoorWarn : Qt.rgba(245/255, 158/255, 11/255, 0.35)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWarnBg : Qt.rgba(245/255, 158/255, 11/255, 0.15)
                    border.color: root.isOutdoor ? PulseGCSTokens.outdoorWarn : Qt.rgba(245/255, 158/255, 11/255, 0.35)
                    border.width: 1

                    Canvas {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = root.isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
                            ctx.lineWidth = 1.8
                            ctx.lineJoin = "round"
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(11, 2)
                            ctx.lineTo(20, 19)
                            ctx.lineTo(2, 19)
                            ctx.closePath()
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(11, 8)
                            ctx.lineTo(11, 13)
                            ctx.stroke()
                            ctx.fillStyle = root.isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
                            ctx.beginPath()
                            ctx.arc(11, 16.5, 1.1, 0, 2 * Math.PI)
                            ctx.fill()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    renderType: Text.QtRendering
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sessionExpiredPopup.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Session Expired")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 16
                font.bold: true
                color: root.isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Your 7-day offline flight authorization has expired.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 13
                font.bold: true
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Your 7-day offline flight authorization on this device has ended. Please sign in to renew your flight credentials.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 10

                Button {
                    id: sessionCloseBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Close")

                    contentItem: Text {
                        text: sessionCloseBtn.text
                        font: sessionCloseBtn.font
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface
                        border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                        border.width: 1
                    }

                    onClicked: sessionExpiredPopup.close()
                }

                Button {
                    id: sessionAuthBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Re-Authenticate Now")

                    contentItem: Text {
                        text: sessionAuthBtn.text
                        font: sessionAuthBtn.font
                        color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: sessionAuthBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                      : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                    }

                    onClicked: {
                        sessionExpiredPopup.close()
                        root.currentView = "signin"
                        root.showNotice("info", qsTr("Please enter your password to refresh your 7-day offline flight session on this device."))
                    }
                }
            }
        }
    }

    // =========================================================================
    // 6. M3-US09: FCM Silicon UID Verification Failure & Telemetry Lockout Modal
    // =========================================================================
    Popup {
        id: fcmMismatchPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 32, 440)
        padding: 24

        Overlay.modal: Rectangle {
            color: Qt.rgba(5/255, 12/255, 20/255, 0.75)
        }

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: root.isOutdoor ? PulseGCSTokens.outdoorErr : Qt.rgba(239/255, 68/255, 68/255, 0.35)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: root.isOutdoor ? PulseGCSTokens.outdoorErrBg : Qt.rgba(239/255, 68/255, 68/255, 0.15)
                    border.color: root.isOutdoor ? PulseGCSTokens.outdoorErr : Qt.rgba(239/255, 68/255, 68/255, 0.35)
                    border.width: 1

                    Canvas {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                            ctx.lineWidth = 1.8
                            ctx.beginPath()
                            ctx.arc(11, 11, 9, 0, 2 * Math.PI)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(7, 7)
                            ctx.lineTo(15, 15)
                            ctx.moveTo(15, 7)
                            ctx.lineTo(7, 15)
                            ctx.stroke()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    renderType: Text.QtRendering
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fcmMismatchPopup.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("FCM UID Mismatch")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 16
                font.bold: true
                color: root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Aircraft Flight Control Module (FCM UID: %1) does not match registered airframe serial (%2). Telemetry connection aborted.")
                          .arg(root.fcmMismatchUid)
                          .arg(root.fcmMismatchSerial)
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Telemetry handshake halted. The ground station will switch back to the Connect Aircraft screen.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 10

                Button {
                    id: fcmDismissBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Dismiss")

                    contentItem: Text {
                        text: fcmDismissBtn.text
                        font: fcmDismissBtn.font
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface
                        border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                        border.width: 1
                    }

                    onClicked: fcmMismatchPopup.close()
                }

                Button {
                    id: fcmRetryBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Retry Connection")

                    contentItem: Text {
                        text: fcmRetryBtn.text
                        font: fcmRetryBtn.font
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusButton
                        color: fcmRetryBtn.pressed ? "#DC2626" : (root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err)
                    }

                    onClicked: {
                        fcmMismatchPopup.close()
                        root.showNotice("info", qsTr("Retrying FCM handshake & telemetry verification..."))
                    }
                }
            }
        }
    }
}
