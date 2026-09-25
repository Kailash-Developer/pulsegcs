import QtQuick
import QtQuick.Controls
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    property string status: "neutral"
    property string text: ""
    property bool showDot: true
    property bool pulsing: false
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    property color customTextColor: PulseGCSTokens.statusColor(status, isOutdoor)
    property color customBgColor: PulseGCSTokens.statusBackgroundColor(status, isOutdoor)
    property color customBorderColor: Qt.rgba(customTextColor.r, customTextColor.g, customTextColor.b, isOutdoor ? 0.30 : 0.20)

    implicitWidth: contentRow.implicitWidth + 18
    implicitHeight: 22
    radius: PulseGCSTokens.radiusPill
    color: customBgColor
    border.color: customBorderColor
    border.width: 1

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            id: dot
            width: 6
            height: 6
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: root.customTextColor
            visible: root.showDot

            SequentialAnimation on opacity {
                running: root.visible && root.pulsing && root.showDot
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.35; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }

            SequentialAnimation on scale {
                running: root.visible && root.pulsing && root.showDot
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.25; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.25; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text.length > 0 ? root.text.toUpperCase() : root.status.toUpperCase()
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 0.3
            color: root.customTextColor
            renderType: Text.QtRendering
        }
    }
}
