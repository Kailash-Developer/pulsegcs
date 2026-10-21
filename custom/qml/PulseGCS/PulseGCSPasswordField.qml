import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import PulseGCS

ColumnLayout {
    id: control
    spacing: 4

    property string label: qsTr("Password")
    property bool requiredField: false
    property string placeholderText: qsTr("Enter your password")
    property string text: ""
    property string helperText: ""
    property string actionText: ""
    property bool isOutdoor: false
    property alias echoMode: textField.echoMode
    property bool showPassword: false

    signal textEdited(string newText)
    signal actionClicked()

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: control.label + (control.requiredField ? " *" : "")
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            font.bold: true
            color: PulseGCSTokens.mutedText(control.isOutdoor)
            renderType: Text.QtRendering
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: control.actionText.length > 0
            text: control.actionText
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 11
            font.bold: true
            color: PulseGCSTokens.accentColor(control.isOutdoor)
            renderType: Text.QtRendering

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: control.actionClicked()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 36

        TextField {
            id: textField
            anchors.fill: parent
            text: control.text
            placeholderText: control.placeholderText
            placeholderTextColor: PulseGCSTokens.metaText(control.isOutdoor)
            echoMode: control.showPassword ? TextInput.Normal : TextInput.Password
            font.family: ScreenTools.normalFontFamily
            font.pixelSize: 12
            color: PulseGCSTokens.primaryText(control.isOutdoor)
            leftPadding: 10
            rightPadding: 36
            renderType: Text.QtRendering
            background: Rectangle {
                radius: PulseGCSTokens.radiusControl
                color: control.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
                border.color: PulseGCSTokens.subtleBorder(control.isOutdoor)
                border.width: 1
            }
            onTextChanged: {
                if (control.text !== text) {
                    control.text = text
                    control.textEdited(text)
                }
            }
        }

        Item {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            Canvas {
                id: eyeCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = control.showPassword ? PulseGCSTokens.accentColor(control.isOutdoor) : PulseGCSTokens.metaText(control.isOutdoor)
                    ctx.lineWidth = 1.6
                    ctx.beginPath()
                    ctx.arc(12, 12, 3, 0, 2 * Math.PI)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(3, 12)
                    ctx.quadraticCurveTo(12, 4, 21, 12)
                    ctx.quadraticCurveTo(12, 20, 3, 12)
                    ctx.stroke()
                    if (!control.showPassword) {
                        ctx.beginPath()
                        ctx.moveTo(4, 4)
                        ctx.lineTo(20, 20)
                        ctx.stroke()
                    }
                }
            }

            Connections {
                target: control
                function onShowPasswordChanged() { eyeCanvas.requestPaint() }
                function onIsOutdoorChanged() { eyeCanvas.requestPaint() }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: control.showPassword = !control.showPassword
            }
        }
    }

    Text {
        visible: control.helperText.length > 0
        text: control.helperText
        font.family: ScreenTools.normalFontFamily
        font.pixelSize: 10
        color: PulseGCSTokens.metaText(control.isOutdoor)
        renderType: Text.QtRendering
    }
}
