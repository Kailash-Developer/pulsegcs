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

    color: PulseGCSTokens.surfaceBackground(root.isOutdoor)
    QGCPalette { id: qgcPal }

    // Backend Authentication & Mock/Live Service
    property alias authService: authService
    PulseGCSAuthService {
        id: authService
        baseUrl: "https://api.pulsegcs.skyx.aero"
        mockMode: true
    }

    // Navigation and state machine
    property string currentView: "signin" // "signin" | "register" | "recovery"
    property string inlineNoticeType: ""
    property string inlineNoticeMsg: ""

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
                                    root.showNotice("ok", qsTr("Operator authorized. 7-day flight console attestation active."))
                                    root.signInSucceeded(email)
                                } else {
                                    root.showNotice("err", errorMsg)
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
                                    applicationSentPopup.open()
                                    root.registrationCompleted(regData)
                                } else {
                                    root.showNotice("err", errorMsg)
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
        width: Math.min(parent.width - 40, 420)
        padding: 24

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
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
                    color: PulseGCSTokens.cardTint
                    border.color: PulseGCSTokens.accentColor(root.isOutdoor)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.family: ScreenTools.normalFontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: PulseGCSTokens.accentColor(root.isOutdoor)
                        renderType: Text.QtRendering
                    }
                }

                Text {
                    text: qsTr("Application Sent to SkyX Backend")
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 15
                    font.bold: true
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    renderType: Text.QtRendering
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 14
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
                text: qsTr("Your application has been received and is under review (1–2 business days).")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                font.bold: true
                color: PulseGCSTokens.accentColor(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 6
                color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    Text {
                        text: qsTr("Reference:")
                        font.family: ScreenTools.normalFontFamily
                        font.pixelSize: 11
                        color: PulseGCSTokens.mutedText(root.isOutdoor)
                        renderType: Text.QtRendering
                    }
                    Text {
                        text: "#SKYX-REG-2026-9041"
                        font.family: ScreenTools.fixedFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: PulseGCSTokens.accentColor(root.isOutdoor)
                        renderType: Text.QtRendering
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                Button {
                    id: popupDemoBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Explore in Demo Mode")

                    contentItem: Text {
                        text: popupDemoBtn.text
                        font: popupDemoBtn.font
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
                        applicationSentPopup.close()
                        root.demoModeClicked()
                    }
                }

                Button {
                    id: popupSignBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    text: qsTr("Return to Sign In")

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

    // 2. Password Updated Popup
    Popup {
        id: passwordUpdatedPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 40, 380)
        padding: 24

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
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
}
