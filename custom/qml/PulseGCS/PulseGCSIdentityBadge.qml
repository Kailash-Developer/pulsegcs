import QtQuick
import QtQuick.Controls
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    property bool isSkyx: true
    property string text: isSkyx ? qsTr("SKYX AIRCRAFT") : qsTr("STANDARD AIRCRAFT")
    property bool compact: false
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    implicitWidth: badgeRow.implicitWidth + (compact ? 10 : 16)
    implicitHeight: compact ? 18 : 22
    radius: 5

    color: isSkyx ? (isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent)
                  : PulseGCSTokens.statusBackgroundColor("neutral", isOutdoor)

    border.color: isSkyx ? "transparent"
                         : (isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : Qt.rgba(140/255, 163/255, 184/255, 0.22))
    border.width: isSkyx ? 0 : 1

    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: badgeText
            anchors.verticalCenter: parent.verticalCenter
            text: root.text.toUpperCase()
            font.pixelSize: root.compact ? 9 : 10
            font.bold: true
            font.weight: root.isSkyx ? Font.ExtraBold : Font.Bold
            font.letterSpacing: 0.3
            color: root.isSkyx ? (root.isOutdoor ? "#FFFFFF" : "#04222B")
                               : PulseGCSTokens.statusColor("neutral", root.isOutdoor)
            renderType: Text.QtRendering
        }
    }
}
