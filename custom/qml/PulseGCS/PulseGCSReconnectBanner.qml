import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var activeAircraftInfo: PulseGCSAircraftManager.activeAircraftInfo
    property bool isOutdoor: PulseGCSTokens.isOutdoor
    property int maxReconnectAttempts: 5

    property var btConfig: null
    readonly property var _effectiveBtConfig: {
        if (btConfig) return btConfig
        let configs = QGroundControl.linkManager.linkConfigurations
        for (let i = 0; i < configs.count; i++) {
            let cfg = configs.get(i)
            if (cfg && (cfg.name === "PulseGCS Bluetooth Link" || cfg.linkType === LinkConfiguration.TypeBluetooth)) {
                return cfg
            }
        }
        return null
    }

    readonly property int connectionState: activeAircraftInfo ? activeAircraftInfo.connectionState : -1
    property bool _wasConnectedInSession: false

    readonly property bool _isBackendReconnecting: _wasConnectedInSession
        && _effectiveBtConfig !== null
        && _effectiveBtConfig.linkActive
        && connectionState !== PulseGCSAircraft.Connecting
        && connectionState !== PulseGCSAircraft.ParameterSync
        && (activeVehicle === null || connectionState !== PulseGCSAircraft.Connected)

    readonly property bool communicationLost: _wasConnectedInSession
        && ((activeAircraftInfo && (activeAircraftInfo.connectionState === PulseGCSAircraft.CommunicationLost || activeAircraftInfo.communicationLost))
            || (activeVehicle && activeVehicle.vehicleLinkManager && activeVehicle.vehicleLinkManager.communicationLost)
            || _isBackendReconnecting)
    readonly property bool reconnecting: communicationLost
    property bool panelOpen: false
    readonly property bool visibleForState: communicationLost && !panelOpen

    property int _reconnectAttempt: 1
    property int _lostElapsedSeconds: 0
    property string _lastKnownName: ""

    signal abortReconnect()
    signal retryNow()

    implicitHeight: visibleForState ? (contentRow.implicitHeight + 20) : 0
    implicitWidth: 480
    visible: visibleForState
    radius: 8
    z: 1000

    color: PulseGCSTokens.statusBackgroundColor("warn", isOutdoor)
    border.color: PulseGCSTokens.statusColor("warn", isOutdoor)
    border.width: 1

    function _aircraftName() {
        if (activeAircraftInfo && activeAircraftInfo.model && activeAircraftInfo.model !== "Unknown") {
            return activeAircraftInfo.model
        }
        if (_lastKnownName.length > 0) {
            return _lastKnownName
        }
        if (_effectiveBtConfig && _effectiveBtConfig.deviceName && _effectiveBtConfig.deviceName.length > 0) {
            return _effectiveBtConfig.deviceName
        }
        return qsTr("Aircraft")
    }

    onConnectionStateChanged: {
        if (connectionState === PulseGCSAircraft.Connected) {
            _wasConnectedInSession = true
        }
    }

    onCommunicationLostChanged: {
        if (communicationLost) {
            _lostElapsedSeconds = 0
            if (activeAircraftInfo && activeAircraftInfo.model && activeAircraftInfo.model !== "Unknown") {
                _lastKnownName = activeAircraftInfo.model
            } else if (_effectiveBtConfig && _effectiveBtConfig.deviceName && _effectiveBtConfig.deviceName.length > 0) {
                _lastKnownName = _effectiveBtConfig.deviceName
            }
            if (_reconnectAttempt < 1) {
                _reconnectAttempt = 1
            }
        } else {
            _reconnectAttempt = 1
            _lostElapsedSeconds = 0
        }
    }

    Timer {
        id: lostElapsedTimer
        interval: 1000
        running: root.communicationLost
        repeat: true
        onTriggered: {
            root._lostElapsedSeconds++
            // Native link recovery retries on its own cadence. Advance the displayed
            // attempt every ~8s so the operator sees progress without inventing a
            // second reconnect state machine.
            if (root._lostElapsedSeconds > 0 && (root._lostElapsedSeconds % 8) === 0) {
                if (root._reconnectAttempt < root.maxReconnectAttempts) {
                    root._reconnectAttempt++
                }
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: PulseGCSTokens.statusColor("warn", root.isOutdoor)

            SequentialAnimation on opacity {
                running: root.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.25; duration: 500 }
                NumberAnimation { from: 0.25; to: 1.0; duration: 500 }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                spacing: 8
                Text {
                    text: qsTr("CONNECTION LOST")
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.6
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    renderType: Text.QtRendering
                }
                PulseGCSStatusPill {
                    status: "accentpill"
                    text: qsTr("RECONNECTING · ATTEMPT %1/%2").arg(root._reconnectAttempt).arg(root.maxReconnectAttempts)
                    pulsing: true
                    isOutdoor: root.isOutdoor
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Attempting to reconnect to %1 — last heartbeat %2s ago. Last-known telemetry remains visible.")
                      .arg(root._aircraftName())
                      .arg(root._lostElapsedSeconds)
                font.pixelSize: 11
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                wrapMode: Text.WordWrap
                renderType: Text.QtRendering
            }

            PulseGCSProgressBar {
                Layout.fillWidth: true
                Layout.topMargin: 2
                indeterminate: true
                isOutdoor: root.isOutdoor
                barColor: PulseGCSTokens.statusColor("warn", root.isOutdoor)
            }
        }

        Button {
            text: qsTr("Retry Now")
            implicitHeight: 32
            implicitWidth: Math.max(88, contentItem.implicitWidth + 20)
            font.pixelSize: 11
            font.bold: true
            onClicked: root.retryNow()

            contentItem: Text {
                text: parent.text
                font: parent.font
                color: root.isOutdoor ? "#FFFFFF" : "#04222B"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }
            background: Rectangle {
                radius: 6
                color: PulseGCSTokens.accentColor(root.isOutdoor)
            }
        }

        Button {
            text: qsTr("Abort")
            implicitHeight: 32
            implicitWidth: Math.max(72, contentItem.implicitWidth + 20)
            font.pixelSize: 11
            font.bold: true
            onClicked: root.abortReconnect()

            contentItem: Text {
                text: parent.text
                font: parent.font
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }
            background: Rectangle {
                radius: 6
                color: root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface
                border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                border.width: 1
            }
        }
    }
}
