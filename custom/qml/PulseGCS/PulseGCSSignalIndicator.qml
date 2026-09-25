import QtQuick
import QtQuick.Controls
import QGroundControl
import PulseGCS

Item {
    id: root

    property int rssi: 0
    property int signalLevel: -1 // -1 means auto-calculate from rssi
    property bool showText: false
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    readonly property int computedLevel: {
        if (signalLevel >= 0) return Math.min(4, Math.max(0, signalLevel))
        if (rssi === 0) return 0
        if (rssi >= -60) return 4
        if (rssi >= -75) return 3
        if (rssi >= -85) return 2
        if (rssi >= -95) return 1
        return 0
    }

    readonly property color activeColor: isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
    readonly property color inactiveColor: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : Qt.rgba(140/255, 163/255, 184/255, 0.28)

    implicitWidth: row.implicitWidth
    implicitHeight: 14

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Row {
            id: barsRow
            anchors.bottom: parent.bottom
            spacing: 2
            height: 13

            Repeater {
                model: [4, 7, 10, 13]

                Rectangle {
                    required property int modelData
                    required property int index

                    width: 3
                    height: modelData
                    radius: 1
                    anchors.bottom: parent.bottom
                    color: (index < root.computedLevel) ? root.activeColor : root.inactiveColor
                }
            }
        }

        Text {
            id: rssiLabel
            visible: root.showText
            anchors.verticalCenter: parent.verticalCenter
            text: root.rssi !== 0 ? qsTr("%1 dBm").arg(root.rssi) : qsTr("No Signal")
            font.pixelSize: 10
            font.bold: true
            color: root.computedLevel > 0 ? PulseGCSTokens.metaText(root.isOutdoor) : PulseGCSTokens.statusColor("neutral", root.isOutdoor)
            renderType: Text.QtRendering
        }
    }
}
