import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import PulseGCS

ColumnLayout {
    id: root
    spacing: 11

    property bool isOutdoor: false
    property int currentStep: 1 // 1: Operator Information, 2: Aircraft & Console

    // Form fields
    property string regFullName: ""
    property string regPhone: ""
    property string regEmail: ""
    property string regPw: ""
    property string regDOB: ""
    property string regDroneModel: "SkyX Kissan"
    property string regDroneSerial: ""
    property string regUIN: ""
    property bool consoleBindingEnabled: true
    property bool showBindingHelp: false

    signal signInRequested()
    signal applicationSubmitted(var regData)
    signal noticeRequested(string type, string message)

    function resetForm() {
        currentStep = 1
        regFullName = ""
        regPhone = ""
        regEmail = ""
        regPw = ""
        regDOB = ""
        regDroneModel = "SkyX Kissan"
        regDroneSerial = ""
        regUIN = ""
        consoleBindingEnabled = true
        showBindingHelp = false
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
            text: qsTr("Registration")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 16
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            Layout.alignment: Qt.AlignHCenter
            renderType: Text.QtRendering
        }
    }

    // Wizard Progress Indicator
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            radius: 11
            color: (root.currentStep === 1) ? PulseGCSTokens.accentColor(root.isOutdoor) : (root.isOutdoor ? PulseGCSTokens.outdoorOk : PulseGCSTokens.ok)
            Text {
                anchors.centerIn: parent
                text: (root.currentStep === 1) ? "1" : "✓"
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                renderType: Text.QtRendering
            }
        }

        Text {
            text: qsTr("Operator Information")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            font.bold: root.currentStep === 1
            color: root.currentStep === 1 ? PulseGCSTokens.primaryText(root.isOutdoor) : PulseGCSTokens.mutedText(root.isOutdoor)
            renderType: Text.QtRendering
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: PulseGCSTokens.subtleBorder(root.isOutdoor)
        }

        Rectangle {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            radius: 11
            color: root.currentStep === 2 ? PulseGCSTokens.accentColor(root.isOutdoor)
                                          : (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
            Text {
                anchors.centerIn: parent
                text: "2"
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: root.currentStep === 2 ? (root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink) : PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
        }

        Text {
            text: qsTr("Aircraft & Console")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            font.bold: root.currentStep === 2
            color: root.currentStep === 2 ? PulseGCSTokens.primaryText(root.isOutdoor) : PulseGCSTokens.mutedText(root.isOutdoor)
            renderType: Text.QtRendering
        }
    }

    // =========================================================================
    // STEP 1: OPERATOR DETAILS
    // =========================================================================
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.currentStep === 1
        Layout.preferredHeight: visible ? -1 : 0
        spacing: 11

        Text {
            text: qsTr("Operator Details")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 14
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            renderType: Text.QtRendering
        }

        // Full Name
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Full name *")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
            TextField {
                id: fullNameField
                Layout.fillWidth: true
                implicitHeight: 34
                text: root.regFullName
                placeholderText: qsTr("Legal operator name")
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
                onTextChanged: root.regFullName = text
            }
        }

        // Phone Number
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Phone number *")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
            TextField {
                id: phoneField
                Layout.fillWidth: true
                implicitHeight: 34
                text: root.regPhone
                placeholderText: qsTr("+91 98765 43210")
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
                onTextChanged: root.regPhone = text
            }
        }

        // Email Address
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
                implicitHeight: 34
                text: root.regEmail
                placeholderText: qsTr("pilot@skyx.aero")
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
                onTextChanged: root.regEmail = text
            }
        }

        // Password with eye reveal
        PulseGCSPasswordField {
            id: regPwControl
            Layout.fillWidth: true
            label: qsTr("Account password")
            requiredField: true
            placeholderText: qsTr("Enter your account password")
            text: root.regPw
            helperText: qsTr("Use 8 or more characters with letters, numbers & symbols.")
            isOutdoor: root.isOutdoor
            onTextEdited: function(val) { root.regPw = val }
        }

        // Date of Birth
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Date of birth *")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
            TextField {
                id: dobField
                Layout.fillWidth: true
                implicitHeight: 34
                text: root.regDOB
                placeholderText: qsTr("DD / MM / YYYY (e.g. 1995-06-15)")
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
                onTextChanged: root.regDOB = text
            }
        }

        // Step 1 Navigation Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 12

            Button {
                id: step1BackBtn
                text: qsTr("Sign In")
                implicitHeight: 34
                implicitWidth: 90
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: step1BackBtn.text
                    font: step1BackBtn.font
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
                onClicked: root.signInRequested()
            }

            Item { Layout.fillWidth: true }

            Button {
                id: step1NextBtn
                text: qsTr("Next ›")
                implicitHeight: 34
                implicitWidth: 110
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: step1NextBtn.text
                    font: step1NextBtn.font
                    color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: step1NextBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                }
                onClicked: {
                    var nameCheck = PulseGCSAuthValidator.validateFullName(root.regFullName)
                    if (!nameCheck.valid) {
                        root.noticeRequested("err", nameCheck.error)
                        return
                    }
                    var phoneCheck = PulseGCSAuthValidator.validatePhone(root.regPhone)
                    if (!phoneCheck.valid) {
                        root.noticeRequested("err", phoneCheck.error)
                        return
                    }
                    var emailCheck = PulseGCSAuthValidator.validateEmail(root.regEmail)
                    if (!emailCheck.valid) {
                        root.noticeRequested("err", emailCheck.error)
                        return
                    }
                    var pwCheck = PulseGCSAuthValidator.validatePassword(root.regPw)
                    if (!pwCheck.valid) {
                        root.noticeRequested("err", pwCheck.error)
                        return
                    }
                    var dobCheck = PulseGCSAuthValidator.validateDOB(root.regDOB)
                    if (!dobCheck.valid) {
                        root.noticeRequested("err", dobCheck.error)
                        return
                    }
                    root.noticeRequested("", "")
                    root.currentStep = 2
                }
            }
        }
    }

    // =========================================================================
    // STEP 2: AIRCRAFT HARDWARE & CONSOLE BINDING
    // =========================================================================
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.currentStep === 2
        Layout.preferredHeight: visible ? -1 : 0
        spacing: 11

        Text {
            text: qsTr("Aircraft & Console Binding")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 14
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            renderType: Text.QtRendering
        }

        // Drone Model
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Drone model *")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
            ComboBox {
                id: droneModelCombo
                Layout.fillWidth: true
                implicitHeight: 34
                model: ["SkyX Kissan", "SkyX Carter", "SkyX Cargo", "SkyX Tether"]
                currentIndex: 0
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                background: Rectangle {
                    radius: PulseGCSTokens.radiusControl
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                    border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                }
                onCurrentTextChanged: root.regDroneModel = currentText
            }
        }

        // Drone Serial
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Visible drone serial number *")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
            TextField {
                id: droneSerialField
                Layout.fillWidth: true
                implicitHeight: 34
                text: root.regDroneSerial
                placeholderText: qsTr("e.g. SKYX-KSN-2026-0842")
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
                onTextChanged: root.regDroneSerial = text
            }
            Text {
                text: qsTr("Found on physical aircraft chassis plate or barcode label.")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 10
                color: PulseGCSTokens.metaText(root.isOutdoor)
                renderType: Text.QtRendering
            }
        }

        // Civil Aviation UIN (Optional)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Civil aviation UIN (Optional)")
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }
            TextField {
                id: uinField
                Layout.fillWidth: true
                implicitHeight: 34
                text: root.regUIN
                placeholderText: qsTr("e.g. UIN-IND-XXXX-XXXX (Optional)")
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
                onTextChanged: root.regUIN = text
            }
        }

        // Console Binding Card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: bindingCol.implicitHeight + 20
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated
            border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
            border.width: 1

            ColumnLayout {
                id: bindingCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: qsTr("Bind license to this console")
                        font.family: ScreenTools.normalFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        renderType: Text.QtRendering
                    }

                    Text {
                        text: "ℹ"
                        font.pixelSize: 13
                        color: PulseGCSTokens.accentColor(root.isOutdoor)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showBindingHelp = !root.showBindingHelp
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Switch {
                        id: bindSwitch
                        checked: root.consoleBindingEnabled
                        onToggled: root.consoleBindingEnabled = checked
                    }
                }

                Text {
                    visible: root.showBindingHelp
                    Layout.fillWidth: true
                    text: qsTr("PulseGCS binds each active flight license to a single operating console to ensure operational security. Device identity details are verified by SKYX Engineering.")
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: 10
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    wrapMode: Text.WordWrap
                    renderType: Text.QtRendering
                }
            }
        }

        // Step 2 Action Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 12

            Button {
                id: step2BackBtn
                text: qsTr("‹ Back")
                implicitHeight: 34
                implicitWidth: 90
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: step2BackBtn.text
                    font: step2BackBtn.font
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
                    root.currentStep = 1
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                id: step2SubmitBtn
                text: qsTr("Submit Application")
                implicitHeight: 34
                implicitWidth: 150
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                contentItem: Text {
                    text: step2SubmitBtn.text
                    font: step2SubmitBtn.font
                    color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: step2SubmitBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                 : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                }
                onClicked: {
                    var serialCheck = PulseGCSAuthValidator.validateDroneSerial(root.regDroneSerial)
                    if (!serialCheck.valid) {
                        root.noticeRequested("err", serialCheck.error)
                        return
                    }
                    var bindCheck = PulseGCSAuthValidator.validateConsoleBinding(root.consoleBindingEnabled)
                    if (!bindCheck.valid) {
                        root.noticeRequested("warn", bindCheck.error)
                        return
                    }
                    root.noticeRequested("", "")
                    root.applicationSubmitted({
                        fullName: root.regFullName,
                        phone: root.regPhone,
                        email: root.regEmail,
                        pw: root.regPw,
                        dob: root.regDOB,
                        droneModel: root.regDroneModel,
                        droneSerial: root.regDroneSerial,
                        uin: root.regUIN,
                        consoleBound: root.consoleBindingEnabled
                    })
                }
            }
        }
    }
}

