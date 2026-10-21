import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import PulseGCS

ColumnLayout {
    id: root
    spacing: 14

    property bool isOutdoor: false
    property string email: ""
    property string password: ""

    signal signInRequested(string email, string password)
    signal demoModeRequested()
    signal forgotPasswordRequested()
    signal registerRequested()
    signal noticeRequested(string type, string message)

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
            text: qsTr("Sign In")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 16
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            Layout.alignment: Qt.AlignHCenter
            renderType: Text.QtRendering
        }
    }

    // Email Input Field
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: qsTr("Email address *")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            font.bold: true
            color: PulseGCSTokens.mutedText(root.isOutdoor)
            renderType: Text.QtRendering
        }

        TextField {
            id: emailField
            Layout.fillWidth: true
            implicitHeight: 36
            text: root.email
            placeholderText: qsTr("Enter your registered email")
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
            onTextChanged: root.email = text
        }
    }

    // Password Input Field with Forgot Password Action
    PulseGCSPasswordField {
        id: pwControl
        Layout.fillWidth: true
        label: qsTr("Password")
        requiredField: true
        actionText: qsTr("Forgot password?")
        placeholderText: qsTr("Enter your password")
        text: root.password
        isOutdoor: root.isOutdoor
        onActionClicked: root.forgotPasswordRequested()
        onTextEdited: function(newText) { root.password = newText }
    }

    // Action Buttons: Demo Mode & Sign In Side by Side
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 10

        Button {
            id: demoBtn
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: 36
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 12
            font.bold: true
            text: qsTr("Demo Mode")

            contentItem: Text {
                text: demoBtn.text
                font: demoBtn.font
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

            onClicked: root.demoModeRequested()
        }

        Button {
            id: submitBtn
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: 36
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 12
            font.bold: true
            text: qsTr("Sign In")

            contentItem: Text {
                text: submitBtn.text
                font: submitBtn.font
                color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }

            background: Rectangle {
                radius: PulseGCSTokens.radiusButton
                color: submitBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                         : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
            }

            onClicked: {
                var emailVal = PulseGCSAuthValidator.validateEmail(root.email)
                if (!emailVal.valid) {
                    root.noticeRequested("err", emailVal.error)
                    return
                }
                var pwVal = PulseGCSAuthValidator.validatePassword(root.password)
                if (!pwVal.valid) {
                    root.noticeRequested("err", pwVal.error)
                    return
                }
                root.signInRequested(root.email, root.password)
            }
        }
    }

    // 7-day Session Note
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: qsTr("Session remains valid offline for up to 7 days on this registered console.")
        font.family: ScreenTools.normalFontFamily
        font.pixelSize: 10
        color: PulseGCSTokens.metaText(root.isOutdoor)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        renderType: Text.QtRendering
    }

    // Router to Registration
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 4
        spacing: 5

        Text {
            text: qsTr("New to PulseGCS?")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            color: PulseGCSTokens.mutedText(root.isOutdoor)
            renderType: Text.QtRendering
        }

        Text {
            text: qsTr("Create an account")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            font.bold: true
            color: PulseGCSTokens.accentColor(root.isOutdoor)
            renderType: Text.QtRendering

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.registerRequested()
            }
        }
    }
}
