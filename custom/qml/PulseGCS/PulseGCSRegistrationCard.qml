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
    property bool isBusy: false
    property bool isSubmitted: false
    property int currentStep: 1 // 1: Operator Information, 2: Aircraft & Console

    // Form fields
    property string regFullName: ""
    property string regPhone: ""
    property string regEmail: ""
    property string regPw: ""
    property string regConfirmPw: ""
    property string regDOB: ""
    property string regDroneModel: "SkyX Kissan"
    property string regDroneSerial: ""
    property string regUIN: ""
    property bool consoleBindingEnabled: true
    property bool showBindingHelp: false

    property alias step2BackButton: step2BackBtn
    property alias step2SubmitButton: step2SubmitBtn

    signal signInRequested()
    signal applicationSubmitted(var regData)
    signal noticeRequested(string type, string message)

    function resetForm() {
        currentStep = 1
        isSubmitted = false
        regFullName = ""
        regPhone = ""
        regEmail = ""
        regPw = ""
        regConfirmPw = ""
        regDOB = ""
        regDroneModel = "SkyX Kissan"
        regDroneSerial = ""
        regUIN = ""
        consoleBindingEnabled = true
        showBindingHelp = false
        if (fullNameField) fullNameField.text = ""
        if (phoneField) phoneField.text = ""
        if (emailField) emailField.text = ""
        if (regPwControl) {
            if (typeof regPwControl.clear === "function") {
                regPwControl.clear()
            } else {
                regPwControl.text = ""
            }
        }
        if (regConfirmPwControl) {
            if (typeof regConfirmPwControl.clear === "function") {
                regConfirmPwControl.clear()
            } else {
                regConfirmPwControl.text = ""
            }
        }
        if (dobField) {
            if (typeof dobField.clear === "function") {
                dobField.clear()
            } else {
                dobField.text = ""
            }
        }
        if (droneSerialField) droneSerialField.text = ""
        if (uinField) uinField.text = ""
        if (droneModelCombo) {
            droneModelCombo.currentIndex = 0
        }
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
                KeyNavigation.tab: phoneField
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
                placeholderText: qsTr("9876543210")
                placeholderTextColor: PulseGCSTokens.metaText(root.isOutdoor)
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                leftPadding: 10
                rightPadding: 10
                inputMethodHints: Qt.ImhDigitsOnly
                maximumLength: 10
                renderType: Text.QtRendering
                KeyNavigation.tab: emailField
                KeyNavigation.backtab: fullNameField
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
                placeholderText: qsTr("name@example.com")
                placeholderTextColor: PulseGCSTokens.metaText(root.isOutdoor)
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                leftPadding: 10
                rightPadding: 10
                renderType: Text.QtRendering
                KeyNavigation.tab: regPwControl.inputItem
                KeyNavigation.backtab: phoneField
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
            nextTabItem: regConfirmPwControl.inputItem
            backTabItem: emailField
            onTextEdited: function(val) { root.regPw = val }
        }

        // Confirm Password with eye reveal
        PulseGCSPasswordField {
            id: regConfirmPwControl
            Layout.fillWidth: true
            label: qsTr("Confirm account password")
            requiredField: true
            placeholderText: qsTr("Re-enter your account password")
            text: root.regConfirmPw
            helperText: qsTr("Must match account password entered above.")
            isOutdoor: root.isOutdoor
            nextTabItem: dobField.firstFocusItem
            backTabItem: regPwControl.inputItem
            onTextEdited: function(val) { root.regConfirmPw = val }
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
            PulseGCSDateField {
                id: dobField
                Layout.fillWidth: true
                implicitHeight: 34
                isOutdoor: root.isOutdoor
                text: root.regDOB
                previousTabItem: regConfirmPwControl.inputItem
                nextTabItem: step1NextBtn
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
                KeyNavigation.backtab: dobField.lastFocusItem
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
                    var pwMatchCheck = PulseGCSAuthValidator.validatePasswordMatch(root.regPw, root.regConfirmPw)
                    if (!pwMatchCheck.valid) {
                        root.noticeRequested("err", pwMatchCheck.error)
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
            text: qsTr("Aircraft & Console Details")
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
                text: qsTr("Drone Model *")
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
                KeyNavigation.tab: droneSerialField

                contentItem: Text {
                    leftPadding: 12
                    rightPadding: 28
                    text: droneModelCombo.displayText
                    font: droneModelCombo.font
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                }

                indicator: Text {
                    anchors.right: droneModelCombo.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: droneModelCombo.verticalCenter
                    text: droneModelCombo.popup.visible ? "▲" : "▼"
                    font.pixelSize: 9
                    font.family: ScreenTools.normalFontFamily
                    color: PulseGCSTokens.metaText(root.isOutdoor)
                    renderType: Text.QtRendering
                }

                background: Rectangle {
                    radius: PulseGCSTokens.radiusControl
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                    border.color: (droneModelCombo.activeFocus || droneModelCombo.popup.visible)
                                  ? PulseGCSTokens.accentColor(root.isOutdoor)
                                  : PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                }

                popup: Popup {
                    y: droneModelCombo.height + 3
                    width: droneModelCombo.width
                    implicitHeight: Math.min(200, contentItem.implicitHeight + 8)
                    padding: 4
                    topMargin: 0
                    bottomMargin: 0

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: droneModelCombo.popup.visible ? droneModelCombo.delegateModel : null
                        currentIndex: droneModelCombo.highlightedIndex
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    background: Rectangle {
                        radius: PulseGCSTokens.radiusControl
                        color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfaceElevated
                        border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                        border.width: 1
                    }
                }

                delegate: ItemDelegate {
                    id: itemDel
                    width: droneModelCombo.width - 8
                    height: 32
                    padding: 0
                    highlighted: droneModelCombo.highlightedIndex === index

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 10
                        text: modelData
                        font.family: ScreenTools.normalFontFamily
                        font.pixelSize: 12
                        font.bold: droneModelCombo.currentIndex === index
                        color: (droneModelCombo.currentIndex === index)
                               ? PulseGCSTokens.accentColor(root.isOutdoor)
                               : PulseGCSTokens.primaryText(root.isOutdoor)
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }

                    background: Rectangle {
                        radius: 4
                        color: (droneModelCombo.currentIndex === index)
                               ? (root.isOutdoor ? PulseGCSTokens.outdoorCardTintSolid : PulseGCSTokens.cardTintSolid)
                               : (itemDel.hovered || itemDel.highlighted
                                  ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShade : PulseGCSTokens.buttonSurface)
                                  : "transparent")
                    }
                }

                onActivated: function(index) {
                    root.regDroneModel = textAt(index)
                }

                onCurrentTextChanged: {
                    if (currentText.length > 0) {
                        root.regDroneModel = currentText
                    }
                }

                Component.onCompleted: {
                    currentIndex = 0
                    if (!root.regDroneModel || root.regDroneModel.length === 0) {
                        root.regDroneModel = textAt(0)
                    }
                }
            }
        }

        // Drone Serial Number
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Drone Serial Number *")
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
                KeyNavigation.tab: uinField
                KeyNavigation.backtab: droneModelCombo
                background: Rectangle {
                    radius: PulseGCSTokens.radiusControl
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                    border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                }
                onTextChanged: root.regDroneSerial = text
            }
        }

        // Drone UIN Number (Optional)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: qsTr("Drone UIN Number (Optional)")
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
                placeholderText: qsTr("e.g. UIN-IND-XXXX-XXXX")
                placeholderTextColor: PulseGCSTokens.metaText(root.isOutdoor)
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                leftPadding: 10
                rightPadding: 10
                renderType: Text.QtRendering
                KeyNavigation.tab: bindSwitch
                KeyNavigation.backtab: droneSerialField
                background: Rectangle {
                    radius: PulseGCSTokens.radiusControl
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                    border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                }
                onTextChanged: root.regUIN = text
            }
        }

        // Console Binding Card (Matching docs/M3 screens.html .console-binding-card)
        Rectangle {
            id: consoleBindingCard
            Layout.fillWidth: true
            radius: 8
            color: root.consoleBindingEnabled
                   ? (root.isOutdoor ? "#E8F4F7" : Qt.rgba(22/255, 50/255, 74/255, 0.85))
                   : (root.isOutdoor ? "#F4F7FA" : Qt.rgba(22/255, 50/255, 74/255, 0.65))
            border.color: root.consoleBindingEnabled
                          ? (root.isOutdoor ? PulseGCSTokens.outdoorAccent : Qt.rgba(47/255, 208/255, 232/255, 0.50))
                          : (root.isOutdoor ? PulseGCSTokens.outdoorBorderSubtle : Qt.rgba(140/255, 163/255, 184/255, 0.22))
            border.width: 1

            implicitHeight: bindingCol.implicitHeight + 20

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            ColumnLayout {
                id: bindingCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Simple Row: Label + Help Button + Compact 38x20 Toggle Switch
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

                    // Help Circle Button
                    Rectangle {
                        implicitWidth: 18
                        implicitHeight: 18
                        radius: 9
                        color: helpMouse.containsMouse
                               ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShade : PulseGCSTokens.buttonSurface)
                               : "transparent"
                        border.color: helpMouse.containsMouse
                                      ? PulseGCSTokens.accentColor(root.isOutdoor)
                                      : Qt.rgba(140/255, 163/255, 184/255, 0.35)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "?"
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: helpMouse.containsMouse
                                   ? PulseGCSTokens.accentColor(root.isOutdoor)
                                   : PulseGCSTokens.mutedText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }

                        MouseArea {
                            id: helpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showBindingHelp = !root.showBindingHelp
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Compact M3 Toggle Switch (38px x 20px, 14px knob)
                    Switch {
                        id: bindSwitch
                        implicitWidth: 38
                        implicitHeight: 20
                        checked: root.consoleBindingEnabled
                        onToggled: root.consoleBindingEnabled = checked
                        KeyNavigation.tab: step2SubmitBtn
                        KeyNavigation.backtab: uinField

                        indicator: Rectangle {
                            implicitWidth: 38
                            implicitHeight: 20
                            radius: 10
                            color: bindSwitch.checked
                                   ? PulseGCSTokens.accentColor(root.isOutdoor)
                                   : (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : Qt.rgba(140/255, 163/255, 184/255, 0.35))
                            border.color: bindSwitch.checked
                                          ? PulseGCSTokens.accentColor(root.isOutdoor)
                                          : Qt.rgba(140/255, 163/255, 184/255, 0.25)
                            border.width: 1

                            Rectangle {
                                x: bindSwitch.checked ? 21 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 7
                                color: bindSwitch.checked
                                       ? (root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink)
                                       : (root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.primaryText(root.isOutdoor))

                                Behavior on x {
                                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }
                }

                // Help Explanation Box (.binding-help-box)
                Rectangle {
                    visible: root.showBindingHelp
                    Layout.fillWidth: true
                    radius: 6
                    color: root.isOutdoor ? "#FFFFFF" : Qt.rgba(10/255, 20/255, 32/255, 0.60)
                    border.color: root.isOutdoor ? "#DCE5EC" : Qt.rgba(140/255, 163/255, 184/255, 0.20)
                    border.width: 1
                    implicitHeight: helpCol.implicitHeight + 16

                    ColumnLayout {
                        id: helpCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: qsTr("Why bind to this console?")
                                font.family: ScreenTools.normalFontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: PulseGCSTokens.primaryText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "✕"
                                font.pixelSize: 10
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showBindingHelp = false
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("PulseGCS binds each active flight license to a single operating console to ensure operational security and regulatory compliance. Device identity details are collected automatically in the background and verified by SKYX Engineering during approval.")
                            font.family: ScreenTools.normalFontFamily
                            font.pixelSize: 10
                            lineHeight: 1.3
                            color: PulseGCSTokens.mutedText(root.isOutdoor)
                            wrapMode: Text.WordWrap
                            renderType: Text.QtRendering
                        }
                    }
                }
            }
        }

        // Divider Line before Action Buttons (Matching M3 screens .step2-card)
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 1
            color: Qt.rgba(140/255, 163/255, 184/255, 0.18)
        }

        // Step 2 Action Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 12

            Button {
                id: step2BackBtn
                text: root.isSubmitted ? qsTr("Close") : qsTr("‹ Back")
                implicitHeight: 34
                implicitWidth: root.isSubmitted ? 100 : 90
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
                    if (root.isSubmitted) {
                        root.resetForm()
                        root.signInRequested()
                    } else {
                        root.currentStep = 1
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                id: step2SubmitBtn
                text: root.isSubmitted ? qsTr("Edit Submission") : (root.isBusy ? qsTr("Submitting...") : qsTr("Submit Application"))
                enabled: !root.isBusy
                implicitHeight: 34
                implicitWidth: 150
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 11
                font.bold: true
                KeyNavigation.backtab: bindSwitch
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: (!root.isSubmitted && root.isBusy) ? 8 : 0

                        PulseGCSCircularLoader {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 16
                            lineWidth: 2.0
                            color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                            running: !root.isSubmitted && root.isBusy
                            visible: !root.isSubmitted && root.isBusy
                            width: (!root.isSubmitted && root.isBusy) ? size : 0
                            height: (!root.isSubmitted && root.isBusy) ? size : 0
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: step2SubmitBtn.text
                            font: step2SubmitBtn.font
                            color: root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.ink
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            renderType: Text.QtRendering
                        }
                    }
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: step2SubmitBtn.pressed ? PulseGCSTokens.accentHoverColor(root.isOutdoor)
                                                 : (root.isOutdoor ? PulseGCSTokens.outdoorAccentCore : PulseGCSTokens.accent)
                    opacity: root.isBusy ? 0.75 : 1.0
                }
                onClicked: {
                    if (root.isSubmitted) {
                        root.noticeRequested("", "")
                        root.isSubmitted = false
                        root.currentStep = 1
                        return
                    }

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

