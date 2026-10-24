import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import PulseGCS

ColumnLayout {
    id: root
    spacing: 12

    property bool isOutdoor: false
    property string recoveryStage: "request" // "request" | "code" | "new_pw"
    property string recoveryEmail: ""
    property string recoveryCode: ""
    property string recoveryNewPw: ""
    property string recoveryConfirmPw: ""

    signal signInRequested()
    signal recoveryCompleted()
    signal noticeRequested(string type, string message)

    function resetFlow() {
        recoveryStage = "request"
        recoveryEmail = ""
        recoveryCode = ""
        recoveryNewPw = ""
        recoveryConfirmPw = ""
        noticeRequested("", "")
    }

    QGCPalette { id: qgcPal }

    // Centered Brand Lockup
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        Layout.bottomMargin: 4

        QGCVectorImage {
            Layout.preferredHeight: 44
            Layout.preferredWidth: 44
            Layout.alignment: Qt.AlignHCenter
            source: qgcPal.globalTheme === QGCPalette.Light ? "/res/pulsegcs-mark-light-bg.svg" : "/res/pulsegcs-mark-dark-bg.svg"
        }

        Text {
            text: qsTr("Forgot Password")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 16
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            Layout.alignment: Qt.AlignHCenter
            renderType: Text.QtRendering
        }
    }

    // =========================================================================
    // STAGE 1: REQUEST RESET CODE (REGISTERED EMAIL)
    // =========================================================================
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.recoveryStage === "request"
        Layout.preferredHeight: visible ? -1 : 0
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: qsTr("Enter your registered operator email. We will send a secure 6-digit recovery code.")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            color: PulseGCSTokens.mutedText(root.isOutdoor)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            renderType: Text.QtRendering
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: qsTr("Registered Email Address *")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            TextField {
                id: recovEmailField
                Layout.fillWidth: true
                implicitHeight: 36
                text: root.recoveryEmail
                placeholderText: qsTr("name@example.com")
                placeholderTextColor: PulseGCSTokens.metaText(root.isOutdoor)
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                leftPadding: 10
                rightPadding: 10
                renderType: Text.QtRendering
                background: Rectangle {
                    radius: PulseGCSTokens.radiusControl
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                    border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                }
                onTextChanged: root.recoveryEmail = text
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Button {
                id: recovBackToSignBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 36
                text: qsTr("‹ Back to Sign In")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: recovBackToSignBtn.text
                    font: recovBackToSignBtn.font
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
                    root.resetFlow()
                    root.signInRequested()
                }
            }

            Button {
                id: sendCodeBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 36
                text: qsTr("Send Reset Code")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: sendCodeBtn.text
                    font: sendCodeBtn.font
                    color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: sendCodeBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                              : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                }
                onClicked: {
                    var emailCheck = PulseGCSAuthValidator.validateEmail(root.recoveryEmail)
                    if (!emailCheck.valid) {
                        root.noticeRequested("err", emailCheck.error)
                        return
                    }
                    root.noticeRequested("ok", qsTr("Verification code sent to %1 (Simulated Code: 849201)").arg(root.recoveryEmail))
                    root.recoveryStage = "code"
                }
            }
        }

        // Centered footer link
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 4

            Text {
                text: qsTr("Remember your credentials?")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            Text {
                text: qsTr("Sign In")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.accentColor(root.isOutdoor)
                renderType: Text.QtRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.resetFlow()
                        root.signInRequested()
                    }
                }
            }
        }
    }

    // =========================================================================
    // STAGE 2: 6-DIGIT VERIFICATION CODE
    // =========================================================================
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.recoveryStage === "code"
        Layout.preferredHeight: visible ? -1 : 0
        spacing: 12

        Text {
            text: qsTr("Enter Verification Code")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 14
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            renderType: Text.QtRendering
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("We sent a 6-digit verification code to %1.").arg(root.recoveryEmail.length > 0 ? root.recoveryEmail : qsTr("your email address"))
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            color: PulseGCSTokens.mutedText(root.isOutdoor)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            renderType: Text.QtRendering
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: qsTr("6-Digit Verification Code *")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            TextField {
                id: recovCodeField
                Layout.fillWidth: true
                implicitHeight: 36
                text: root.recoveryCode
                placeholderText: qsTr("849201")
                placeholderTextColor: PulseGCSTokens.metaText(root.isOutdoor)
                font.family: ScreenTools.fixedFontFamily
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 4
                horizontalAlignment: TextInput.AlignHCenter
                color: PulseGCSTokens.accentColor(root.isOutdoor)
                maximumLength: 6
                leftPadding: 10
                rightPadding: 10
                renderType: Text.QtRendering
                background: Rectangle {
                    radius: PulseGCSTokens.radiusControl
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                    border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                }
                onTextChanged: root.recoveryCode = text
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 5
            Text {
                text: qsTr("Didn't receive code?")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
            Text {
                text: qsTr("Resend Code")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.accentColor(root.isOutdoor)
                renderType: Text.QtRendering
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.recoveryCode = ""
                        root.noticeRequested("ok", qsTr("Verification code re-sent to %1 (Simulated Code: 849201)").arg(root.recoveryEmail.length > 0 ? root.recoveryEmail : qsTr("your email address")))
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Button {
                id: recovCodeBackBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 36
                text: qsTr("‹ Back")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: recovCodeBackBtn.text
                    font: recovCodeBackBtn.font
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
                    root.noticeRequested("", "")
                    root.recoveryStage = "request"
                }
            }

            Button {
                id: verifyCodeBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 36
                text: qsTr("Verify Code ›")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: verifyCodeBtn.text
                    font: verifyCodeBtn.font
                    color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: verifyCodeBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                }
                onClicked: {
                    var codeCheck = PulseGCSAuthValidator.validateRecoveryCode(root.recoveryCode)
                    if (!codeCheck.valid) {
                        root.noticeRequested("err", codeCheck.error)
                        return
                    }
                    root.noticeRequested("", "")
                    root.recoveryStage = "new_pw"
                }
            }
        }

        // Centered footer link: Remember your credentials? Sign In
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 4

            Text {
                text: qsTr("Remember your credentials?")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            Text {
                text: qsTr("Sign In")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.accentColor(root.isOutdoor)
                renderType: Text.QtRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.resetFlow()
                        root.signInRequested()
                    }
                }
            }
        }
    }

    // =========================================================================
    // STAGE 3: SET NEW PASSWORD & CONFIRM PASSWORD
    // =========================================================================
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.recoveryStage === "new_pw"
        Layout.preferredHeight: visible ? -1 : 0
        spacing: 12

        Text {
            text: qsTr("Set New Password")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 14
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            renderType: Text.QtRendering
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Verification successful. Enter a new password for account %1.").arg(root.recoveryEmail.length > 0 ? root.recoveryEmail : qsTr("your account"))
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            color: PulseGCSTokens.mutedText(root.isOutdoor)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            renderType: Text.QtRendering
        }

        // New Password with reveal eye
        PulseGCSPasswordField {
            id: recovNewPwField
            Layout.fillWidth: true
            label: qsTr("New Password")
            requiredField: true
            placeholderText: qsTr("At least 8 characters")
            text: root.recoveryNewPw
            isOutdoor: root.isOutdoor
            onTextEdited: function(val) { root.recoveryNewPw = val }
        }

        // Confirm New Password with reveal eye
        PulseGCSPasswordField {
            id: recovConfirmPwField
            Layout.fillWidth: true
            label: qsTr("Confirm New Password")
            requiredField: true
            placeholderText: qsTr("Re-enter new password")
            text: root.recoveryConfirmPw
            helperText: qsTr("Minimum 8 characters with numbers and symbols.")
            isOutdoor: root.isOutdoor
            onTextEdited: function(val) { root.recoveryConfirmPw = val }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Button {
                id: recovCancelBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 36
                text: qsTr("Cancel")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: recovCancelBtn.text
                    font: recovCancelBtn.font
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
                    root.resetFlow()
                    root.signInRequested()
                }
            }

            Button {
                id: updatePwBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 36
                text: qsTr("Update Password")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: updatePwBtn.text
                    font: updatePwBtn.font
                    color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: updatePwBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                              : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                }
                onClicked: {
                    var matchCheck = PulseGCSAuthValidator.validatePasswordMatch(root.recoveryNewPw, root.recoveryConfirmPw)
                    if (!matchCheck.valid) {
                        root.noticeRequested("err", matchCheck.error)
                        return
                    }
                    root.noticeRequested("", "")
                    root.recoveryCompleted()
                }
            }
        }

        // Centered footer link
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4

            Text {
                text: qsTr("Cancel and Sign In")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.accentColor(root.isOutdoor)
                renderType: Text.QtRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.resetFlow()
                        root.signInRequested()
                    }
                }
            }
        }
    }
}

