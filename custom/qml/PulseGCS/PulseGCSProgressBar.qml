import QtQuick
import QtQuick.Controls
import QGroundControl
import PulseGCS

Item {
    id: root

    property real progress: 0.0 // 0.0 to 1.0
    property bool indeterminate: false
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    property real trackHeight: 6
    property real trackRadius: trackHeight / 2
    property color barColor: PulseGCSTokens.accentColor(isOutdoor)
    property color trackColor: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : Qt.rgba(140/255, 163/255, 184/255, 0.18)

    implicitWidth: 200
    implicitHeight: trackHeight

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.trackRadius
        color: root.trackColor
        clip: true

        Rectangle {
            id: determinateBar
            visible: !root.indeterminate
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(track.width, track.width * Math.max(0.0, Math.min(1.0, root.progress))))
            radius: root.trackRadius
            color: root.barColor

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }
        }

        Rectangle {
            id: indeterminateBar
            visible: root.indeterminate
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: track.width * 0.35
            radius: root.trackRadius
            color: root.barColor

            SequentialAnimation on x {
                running: root.visible && root.indeterminate
                loops: Animation.Infinite
                NumberAnimation {
                    from: -indeterminateBar.width
                    to: track.width
                    duration: 1200
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
