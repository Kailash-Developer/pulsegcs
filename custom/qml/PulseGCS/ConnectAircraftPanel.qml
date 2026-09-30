import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import PulseGCS 1.0

Rectangle {
    id: root
    color: PulseGCSTokens.surfaceBackground(isOutdoor)

    signal aircraftConnected(var link)
    signal planMapRequested()
    signal advancedConnectionRequested()
    signal closed()

    QGCPalette { id: qgcPal }

    readonly property bool isOutdoor: PulseGCSTokens.isOutdoor

    // -------------------------------------------------------------------------
    // Bluetooth Link Configuration & Device State
    // -------------------------------------------------------------------------
    property var _btConfig: null
    property var _discoveredDevices: []
    property var _pairedDevices: []
    property var _sessionPairedAddresses: ({})
    property string _pairingAddress: ""
    property bool _isScanning: _btConfig ? _btConfig.scanning : false
    property string _statusMessage: ""

    property var _unpairTargetDevice: null

    Popup {
        id: unpairConfirmPopup
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 40, 360)
        padding: 20

        background: Rectangle {
            radius: PulseGCSTokens.radiusCard
            color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
            border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                text: qsTr("Unpair Aircraft")
                font.pixelSize: 15
                font.bold: true
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: _unpairTargetDevice ? qsTr("Are you sure you want to unpair %1?").arg(_unpairTargetDevice.name || _unpairTargetDevice.address) : ""
                font.pixelSize: 12
                color: PulseGCSTokens.mutedText(root.isOutdoor)
                renderType: Text.QtRendering
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Cancel")
                    implicitHeight: 32
                    font.pixelSize: 11
                    font.bold: true
                    onClicked: unpairConfirmPopup.close()
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

                Button {
                    text: qsTr("Unpair")
                    implicitHeight: 32
                    font.pixelSize: 11
                    font.bold: true
                    onClicked: {
                        let target = _unpairTargetDevice
                        unpairConfirmPopup.close()
                        if (target) {
                            unpairDevice(target)
                        }
                    }
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: PulseGCSTokens.statusColor("err", root.isOutdoor)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                    }
                    background: Rectangle {
                        radius: 6
                        color: root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface
                        border.color: PulseGCSTokens.statusColor("err", root.isOutdoor)
                        border.width: 1
                    }
                }
            }
        }
    }

    Timer {
        id: pairingWatchdog
        interval: 30000
        repeat: false
        onTriggered: {
            if (_pairingAddress.length > 0) {
                console.log("PulseGCS: Pairing attempt timed out for", _pairingAddress)
                _pairingAddress = ""
                _lastFailureDetail = qsTr("Pairing timed out. Confirm the aircraft is in pairing mode and retry.")
                _statusMessage = _lastFailureDetail
                _hasConnectionFailed = true
                _hasCancelled = false
                _hasDisconnected = false
                _refreshDeviceLists()
            }
        }
    }

    // -------------------------------------------------------------------------
    // Authoritative Connection State & Vehicle Classification
    // -------------------------------------------------------------------------
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _activeAircraftInfo: PulseGCSAircraftManager.activeAircraftInfo
    property int _connectionState: _activeAircraftInfo ? _activeAircraftInfo.connectionState : -1
    property real _discoveryProgress: {
        if (_activeAircraftInfo && _activeAircraftInfo.discoveryProgress > 0) {
            return _activeAircraftInfo.discoveryProgress
        }
        if (_activeVehicle && _activeVehicle.loadProgress !== undefined) {
            return _activeVehicle.loadProgress
        }
        return 0.0
    }
    property bool _isSkyx: _activeAircraftInfo ? _activeAircraftInfo.isSkyx : false

    property string _connectingAddress: ""
    property string _connectingDeviceName: ""
    property bool _connectionAttemptActive: false
    property bool _userCancelled: false
    property int _reconnectAttempt: 1
    property int _maxReconnectAttempts: 5
    property int _lostElapsedSeconds: 0
    property string _lastKnownAircraftName: ""
    property string _lastFailureDetail: ""
    property bool _autoConnectAttempted: false
    property bool _wasConnectedInSession: false
    property bool _disconnectPending: false
    property bool _manualScanActive: false
    property bool _isReconnectAborted: false
    readonly property bool _isRecoveryFailed: _isCommunicationLost
        && _reconnectAttempt >= _maxReconnectAttempts
        && _lostElapsedSeconds >= (_maxReconnectAttempts * 8)

    readonly property bool _isConnected: _activeVehicle !== null
        && !_isCommunicationLost
        && (_connectionState === PulseGCSAircraft.Connected
            || (_activeVehicle.parameterManager && _activeVehicle.parameterManager.parametersReady))
    readonly property bool _isRCLostOnly: false
    readonly property bool _isParameterSyncing: !_isConnected
        && !_isCommunicationLost
        && !_hasCancelled
        && !_hasConnectionFailed
        && !_hasDisconnected
        && ((_connectionState === PulseGCSAircraft.ParameterSync)
            || (_activeVehicle !== null && _activeVehicle.parameterManager && !_activeVehicle.parameterManager.parametersReady))
    readonly property bool _isConnecting: !_isConnected
        && !_isParameterSyncing
        && !_isCommunicationLost
        && !_hasCancelled
        && !_hasConnectionFailed
        && !_hasDisconnected
        && (_connectionState === PulseGCSAircraft.Connecting || _connectionAttemptActive)
    readonly property bool _isConnectingOrSyncing: _isConnecting || _isParameterSyncing
    readonly property bool _isBackendReconnecting: _wasConnectedInSession
        && !_userCancelled
        && _btConfig !== null
        && _btConfig.linkActive
        && _connectionState !== PulseGCSAircraft.Connecting
        && _connectionState !== PulseGCSAircraft.ParameterSync
        && (_activeVehicle === null || _connectionState !== PulseGCSAircraft.Connected)
    readonly property bool _isCommunicationLost: (!_userCancelled || _isReconnectAborted)
        && !_hasDisconnected
        && ((_connectionState === PulseGCSAircraft.CommunicationLost)
            || (_activeVehicle && _activeVehicle.vehicleLinkManager && _activeVehicle.vehicleLinkManager.communicationLost)
            || (_wasConnectedInSession && _isBackendReconnecting)
            || (_wasConnectedInSession && _activeVehicle === null && !_disconnectPending))
    readonly property bool _isScanAllowed: !_disconnectPending
        && !_connectionAttemptActive
        && !_isConnectingOrSyncing
        && !_isCommunicationLost
        && !_isBackendReconnecting
        && !_isConnected
        && (_activeVehicle === null || !_activeVehicle)
    property bool _hasConnectionFailed: false
    property bool _hasCancelled: false
    property bool _hasDisconnected: false

    readonly property bool _isInitialFailed: _connectionState === PulseGCSAircraft.InitialFailed
    readonly property bool _isIdentityConflict: _connectionState === PulseGCSAircraft.IdentityConflict

    readonly property bool _showConnectionError: !_connectionAttemptActive
                                                  && !_isScanning
                                                  && !_isCommunicationLost
                                                  && !_isConnectingOrSyncing
                                                  && !_isConnected
                                                  && (_hasConnectionFailed || _isInitialFailed || _isIdentityConflict)

    readonly property bool _showCancelledNotice: !_connectionAttemptActive
                                                  && !_isScanning
                                                  && !_isCommunicationLost
                                                  && !_isConnectingOrSyncing
                                                  && _hasCancelled

    readonly property bool _showDisconnectedNotice: !_connectionAttemptActive
                                                     && !_isScanning
                                                     && !_isCommunicationLost
                                                     && !_isConnectingOrSyncing
                                                     && !_isConnected
                                                     && _hasDisconnected

    readonly property bool _showNoticeBar: !_isScanning
                                            && !_connectionAttemptActive
                                            && !_isConnectingOrSyncing
                                            && !_isCommunicationLost
                                            && (_showConnectionError || _showCancelledNotice || _showDisconnectedNotice)

    property var _activeLink: _btConfig ? _btConfig.link : null

    on_ActiveVehicleChanged: {
        _resolveActiveBtConfig()
        if (_disconnectPending && !_activeVehicle && (!_btConfig || !_btConfig.linkActive)) {
            _finalizeDisconnect()
        } else if (!_activeVehicle && !_connectionAttemptActive) {
            _refreshDeviceLists()
        }
        if (_activeVehicle) {
            _connectionAttemptActive = false
            _connectingAddress = ""
            _connectingDeviceName = ""
            _userCancelled = false
            _hasCancelled = false
            _hasConnectionFailed = false
            _isReconnectAborted = false
        }
    }

    on_IsConnectedChanged: {
        if (_isConnected) {
            _connectionAttemptActive = false
            _connectingAddress = ""
            _connectingDeviceName = ""
            _wasConnectedInSession = true
            _userCancelled = false
            _hasCancelled = false
            _hasConnectionFailed = false
            _isReconnectAborted = false
            _reconnectAttempt = 1
            _lostElapsedSeconds = 0
        }
    }

    on_ConnectionStateChanged: {
        if (_connectionState === PulseGCSAircraft.Connected) {
            _wasConnectedInSession = true
            _userCancelled = false
            _hasCancelled = false
            _hasConnectionFailed = false
            _isReconnectAborted = false
            _reconnectAttempt = 1
            _lostElapsedSeconds = 0
        } else if (_connectionState === PulseGCSAircraft.Connecting || _connectionState === PulseGCSAircraft.ParameterSync) {
            if (!_userCancelled || _activeVehicle !== null) {
                _userCancelled = false
                _hasCancelled = false
                _hasConnectionFailed = false
            }
        }
    }

    // -------------------------------------------------------------------------
    // M2-US01 Discovery Timer & Timeout Watchdog
    // -------------------------------------------------------------------------
    property int _scanElapsedSeconds: 0
    property bool _scanTimedOut: false

    Timer {
        id: scanElapsedTimer
        interval: 1000
        running: _isScanning
        repeat: true
        onTriggered: {
            _scanElapsedSeconds++
            if (_scanElapsedSeconds >= 30 && _discoveredDevices.length === 0 && _pairedDevices.length === 0) {
                _scanTimedOut = true
                stopScan()
            }
        }
    }

    Timer {
        id: lostElapsedTimer
        interval: 1000
        running: _isCommunicationLost
        repeat: true
        onTriggered: {
            _lostElapsedSeconds++
            if (!_isReconnectAborted) {
                if (_lostElapsedSeconds > 0 && (_lostElapsedSeconds % 8) === 0 && _reconnectAttempt < _maxReconnectAttempts) {
                    _reconnectAttempt++
                }
                if (_reconnectAttempt >= _maxReconnectAttempts && _lostElapsedSeconds >= (_maxReconnectAttempts * 8)) {
                    let activeCfg = _resolveActiveBtConfig()
                    if (activeCfg && !activeCfg.suppressAutoReconnect) {
                        console.log("PulseGCS: Max recovery attempts reached (" + _maxReconnectAttempts + "). Suppressing native auto-reconnect for " + activeCfg.name)
                        activeCfg.setSuppressAutoReconnect(true)
                    }
                }
                _statusMessage = qsTr("Communication lost with %1. Auto-reconnecting (attempt %2/%3)...")
                                  .arg(_aircraftDisplayName())
                                  .arg(_reconnectAttempt)
                                  .arg(_maxReconnectAttempts)
            }
        }
    }

    function _formatElapsed(sec) {
        let m = Math.floor(sec / 60)
        let s = sec % 60
        return (m < 10 ? "0" + m : "" + m) + ":" + (s < 10 ? "0" + s : "" + s)
    }

    function _aircraftDisplayName() {
        if (_activeAircraftInfo && _activeAircraftInfo.model && _activeAircraftInfo.model !== "Unknown") {
            return _activeAircraftInfo.model
        }
        if (_connectingDeviceName.length > 0) {
            return _connectingDeviceName
        }
        if (_lastKnownAircraftName.length > 0) {
            return _lastKnownAircraftName
        }
        return _isSkyx ? qsTr("SkyX Aircraft") : qsTr("Aircraft")
    }

    function _humanizeSocketError(raw) {
        let msg = raw ? ("" + raw) : ""
        let lower = msg.toLowerCase()
        if (lower.indexOf("servicenotfound") !== -1 || lower.indexOf("connection to service failed") !== -1) {
            return qsTr("Bluetooth service not found. The aircraft radio may be off, out of range, or already paired to another controller.")
        }
        if (lower.indexOf("read failed") !== -1 || lower.indexOf("socket might closed") !== -1 || lower.indexOf("read ret: -1") !== -1) {
            return qsTr("Bluetooth socket closed unexpectedly. The radio dropped the link — retry once the aircraft is powered and in range.")
        }
        if (lower.indexOf("workaround") !== -1) {
            return qsTr("Bluetooth handshake fallback failed. Unpair the device in Android Bluetooth settings, then pair again from PulseGCS.")
        }
        if (lower.indexOf("device not open") !== -1) {
            return qsTr("Bluetooth adapter closed the socket. Confirm Bluetooth is enabled, then retry the connection.")
        }
        if (lower.indexOf("timed out") !== -1 || lower.indexOf("timeout") !== -1) {
            return qsTr("Connection timed out. Ensure the aircraft is powered on, telemetry is active, and within wireless range.")
        }
        if (msg.length > 0) {
            return msg
        }
        return qsTr("Connection failed. Check that the aircraft is powered on and within range, then retry.")
    }

    function retryLastConnection() {
        _userCancelled = false
        _hasConnectionFailed = false
        _hasCancelled = false
        _hasDisconnected = false
        _lastFailureDetail = ""
        _statusMessage = ""
        let activeCfg = _resolveActiveBtConfig()
        if (activeCfg) {
            if (activeCfg.suppressAutoReconnect) {
                activeCfg.setSuppressAutoReconnect(false)
            }
            if (typeof activeCfg.resetReconnectBackoff === "function") {
                activeCfg.resetReconnectBackoff()
            }
        }
        if (_connectingAddress.length > 0) {
            connectDevice({
                address: _connectingAddress,
                name: _connectingDeviceName,
                rawName: _connectingDeviceName
            })
            return
        }
        if (_btConfig && _btConfig.address && _btConfig.address.length > 0) {
            connectDevice({
                address: _btConfig.address,
                name: _btConfig.deviceName || _connectingDeviceName,
                rawName: _btConfig.deviceName || _connectingDeviceName
            })
            return
        }
        if (_isScanAllowed) {
            startScan()
        }
    }

    function abortReconnect() {
        _isReconnectAborted = true
        _userCancelled = true
        let activeCfg = _resolveActiveBtConfig()
        if (activeCfg && typeof activeCfg.setSuppressAutoReconnect === "function") {
            activeCfg.setSuppressAutoReconnect(true)
        }
        _hasCancelled = true
        _hasDisconnected = false
        _hasConnectionFailed = false
        _statusMessage = qsTr("Reconnection failed: User terminated the action...")
    }

    Component.onCompleted: {
        _initBluetooth()
    }

    Component.onDestruction: {
        if (_btConfig && _btConfig.scanning) {
            _btConfig.stopScan()
        }
    }

    onVisibleChanged: {
        if (visible) {
            _resolveActiveBtConfig()
            if (_activeVehicle !== null) {
                // Vehicle already connected (e.g. via startup auto-connect)
                if (_isConnected) {
                    let vehicleName = _aircraftDisplayName()
                    _lastKnownAircraftName = vehicleName
                    _statusMessage = qsTr("Connected to %1").arg(vehicleName)
                } else if (_isParameterSyncing) {
                    let pct = Math.round(_discoveryProgress * 100)
                    _statusMessage = qsTr("Syncing parameters (%1%)...").arg(pct)
                }
            } else if (_btConfig && !_isScanning && _isScanAllowed && !_hasConnectionFailed && !_hasCancelled && !_hasDisconnected) {
                startScan()
            }
        }
    }

    // Connection Watchdog Timer (15 seconds safety timeout for initial link/handshake)
    Timer {
        id: connectionWatchdog
        interval: 15000
        running: _isConnecting
        repeat: false
        onTriggered: {
            if (_isConnecting) {
                _connectionAttemptActive = false
                _hasConnectionFailed = true
                _hasCancelled = false
                _hasDisconnected = false
                let devName = _aircraftDisplayName()
                _lastFailureDetail = qsTr("No heartbeat received within timeout. Ensure the aircraft is powered on and within wireless range.")
                _statusMessage = qsTr("Connection to %1 failed: %2").arg(devName).arg(_lastFailureDetail)
                console.log("Unexpected Bluetooth/connection loss: preserving native reconnect")
            }
        }
    }

    // Parameter Synchronization Watchdog Timer (60s safety timeout per prototype US05)
    Timer {
        id: paramSyncWatchdog
        interval: 60000
        running: _isParameterSyncing
        repeat: false
        onTriggered: {
            if (_isParameterSyncing) {
                _connectionAttemptActive = false
                _hasConnectionFailed = true
                _hasCancelled = false
                _hasDisconnected = false
                let devName = _aircraftDisplayName()
                _lastFailureDetail = qsTr("Parameter synchronization timed out. Download stalled or connection was interrupted.")
                _statusMessage = qsTr("Sync failed for %1: %2").arg(devName).arg(_lastFailureDetail)
            }
        }
    }

    // Disconnect Watchdog Timer (ensures UI transitions to post-disconnect state even if link drops silently)
    Timer {
        id: disconnectWatchdog
        interval: 3000
        repeat: false
        onTriggered: {
            if (_disconnectPending) {
                console.log("PulseGCS: Disconnect watchdog fired, finalizing disconnect state.")
                _finalizeDisconnect()
            }
        }
    }

    function _finalizeDisconnect() {
        if (!_disconnectPending) {
            return
        }
        _disconnectPending = false
        disconnectWatchdog.stop()
        if (_userCancelled) {
            _hasDisconnected = false
            _hasCancelled = true
            _hasConnectionFailed = false
            if (!_statusMessage || _statusMessage === qsTr("Disconnecting...")) {
                _statusMessage = _isReconnectAborted ? qsTr("Reconnection cancelled.") : qsTr("Aircraft disconnected. None active.")
            }
        } else {
            _hasDisconnected = true
            _hasCancelled = false
            _hasConnectionFailed = false
            _statusMessage = qsTr("Aircraft disconnected. None active.")
        }
        _refreshDeviceLists()
    }

    // -------------------------------------------------------------------------
    // Bluetooth Lifecycle & Discovery Functions
    // -------------------------------------------------------------------------
    function _generateAutoLinkName(device) {
        if (!device) {
            return "auto-Aircraft"
        }
        let cleanAddr = (device.address && device.address.length > 0) ? device.address.replace(/[:-]/g, "").toUpperCase() : ""
        let suffix = cleanAddr.length >= 4 ? cleanAddr.slice(-4) : cleanAddr

        let cleanName = (device.rawName && device.rawName.trim().length > 0) ? device.rawName.trim() : (device.name ? device.name.trim() : "")
        if (cleanName.length > 0 && cleanName.indexOf("Unknown Device") !== 0) {
            return suffix.length > 0 ? ("auto-" + cleanName + "-" + suffix) : ("auto-" + cleanName)
        }
        if (suffix.length > 0) {
            return "auto-" + suffix
        }
        return "auto-Aircraft"
    }

    function _isAddressConfigured(address) {
        if (!address) {
            return false
        }
        let addrUpper = address.trim().toUpperCase()
        if (addrUpper.length === 0 || addrUpper === "0") {
            return false
        }
        if (_btConfig && (_btConfig.address || "").trim().toUpperCase() === addrUpper) {
            return true
        }
        let configs = QGroundControl.linkManager.linkConfigurations
        for (let i = 0; i < configs.count; i++) {
            let cfg = configs.get(i)
            let cfgAddrUpper = (cfg && cfg.address) ? cfg.address.trim().toUpperCase() : ""
            if (cfg && cfg.linkType === LinkConfiguration.TypeBluetooth && cfgAddrUpper.length > 0 && cfgAddrUpper === addrUpper) {
                return true
            }
        }
        return false
    }

    function _resolveActiveBtConfig() {
        let configs = QGroundControl.linkManager.linkConfigurations
        if (!configs || configs.count === 0) {
            return _btConfig
        }

        let primaryName = (_activeVehicle && _activeVehicle.vehicleLinkManager) ? _activeVehicle.vehicleLinkManager.primaryLinkName : ""

        // 1. Match registered Bluetooth config by primary link name of active vehicle
        if (primaryName && primaryName.length > 0) {
            for (let i = 0; i < configs.count; i++) {
                let cfg = configs.get(i)
                if (cfg && cfg.linkType === LinkConfiguration.TypeBluetooth && cfg.name === primaryName) {
                    _btConfig = cfg
                    return cfg
                }
            }
        }

        // 2. Match registered Bluetooth config that currently has an active link
        for (let j = 0; j < configs.count; j++) {
            let c = configs.get(j)
            if (c && c.linkType === LinkConfiguration.TypeBluetooth && (c.linkActive || c.link !== null)) {
                _btConfig = c
                return c
            }
        }

        // 3. Match registered Bluetooth config by connecting address if available
        if (_connectingAddress && _connectingAddress.length > 0) {
            for (let k = 0; k < configs.count; k++) {
                let aCfg = configs.get(k)
                if (aCfg && aCfg.linkType === LinkConfiguration.TypeBluetooth && aCfg.address === _connectingAddress) {
                    _btConfig = aCfg
                    return aCfg
                }
            }
        }

        return _btConfig
    }

    function _initBluetooth() {
        let configs = QGroundControl.linkManager.linkConfigurations

        // 1. One-time cleanup: remove any unconfigured legacy "PulseGCS Bluetooth Link" helper from previous runs
        for (let i = configs.count - 1; i >= 0; i--) {
            let cfg = configs.get(i)
            if (cfg && cfg.linkType === LinkConfiguration.TypeBluetooth) {
                if (cfg.name === "PulseGCS Bluetooth Link" && (!cfg.address || cfg.address === "0" || cfg.address.length === 0)) {
                    console.log("PulseGCS: Removing unconfigured legacy Bluetooth link from previous session")
                    QGroundControl.linkManager.removeConfiguration(cfg)
                }
            }
        }

        // 2. Look for an existing valid Bluetooth configuration in LinkManager
        let existingValid = null
        for (let j = 0; j < configs.count; j++) {
            let c = configs.get(j)
            if (c && c.linkType === LinkConfiguration.TypeBluetooth) {
                if (c.linkActive || c.link !== null) {
                    existingValid = c
                    break
                }
                if (c.address && c.address !== "0" && c.address.length > 0) {
                    if (c.name && c.name.indexOf("auto-") === 0) {
                        existingValid = c
                        break
                    }
                    if (!existingValid) {
                        existingValid = c
                    }
                }
            }
        }

        if (existingValid) {
            _btConfig = existingValid
        } else if (!_btConfig) {
            // 3. Create a temporary scanning helper without persisting it to LinkManager or QSettings
            _btConfig = QGroundControl.linkManager.createConfiguration(LinkConfiguration.TypeBluetooth, "")
            if (_btConfig) {
                _btConfig.dynamic = true
                _btConfig.autoConnect = false
                // Do NOT call endCreateConfiguration() here. An unconfigured helper must never be persisted.
            }
        }

        if (_btConfig) {
            if (typeof _btConfig.powerOnAdapter === "function" && !_btConfig.isAdapterAvailable()) {
                _btConfig.powerOnAdapter()
            }
            _refreshDeviceLists()
            if (_isScanAllowed) {
                startScan()
            }
        } else {
            _statusMessage = qsTr("Bluetooth adapter not available on this device.")
        }
    }

    function startScan() {
        if (!_isScanAllowed) {
            return
        }
        if (_isScanning || (_btConfig && _btConfig.scanning)) {
            return
        }
        // Transition to SEARCHING state: reset prior terminal states
        _manualScanActive = true
        _hasConnectionFailed = false
        _hasCancelled = false
        _userCancelled = false
        _scanTimedOut = false
        _scanElapsedSeconds = 0
        _lastFailureDetail = ""
        if (!_btConfig) {
            _initBluetooth()
        }
        if (_btConfig && _isScanAllowed) {
            _statusMessage = qsTr("Searching for aircraft...")
            _btConfig.startScan()
            _refreshDeviceLists()
        }
    }

    function stopScan() {
        if (_btConfig && _btConfig.scanning) {
            _btConfig.stopScan()
        }
        _manualScanActive = false
        _scanElapsedSeconds = 0
        scanElapsedTimer.stop()
    }

    function _isDeviceSkyx(name) {
        if (!name) return false
        let n = name.toUpperCase()
        return n.indexOf("SKYX") !== -1 || n.indexOf("PULSE") !== -1 || n.indexOf("APERTURE") !== -1
    }

    function _refreshDeviceLists() {
        if (!_btConfig) {
            _discoveredDevices = []
            _pairedDevices = []
            return
        }

        // 1. Build Paired Devices list first from OS bonded devices
        let devModel = _btConfig.devicesModel || []
        let liveAddressMap = {}
        for (let m = 0; m < devModel.length; m++) {
            if (devModel[m] && devModel[m].address) {
                liveAddressMap[devModel[m].address.trim().toUpperCase()] = devModel[m]
            }
        }

        // Fast-path: Query OS connected devices directly (0ms latency on Android)
        let connectedAddressMap = {}
        if (typeof _btConfig.getConnectedDevices === "function") {
            let osConnected = _btConfig.getConnectedDevices() || []
            for (let c = 0; c < osConnected.length; c++) {
                if (osConnected[c] && osConnected[c].address) {
                    connectedAddressMap[osConnected[c].address.trim().toUpperCase()] = true
                }
            }
        }

        let paired = []
        let pairedAddressMap = {}

        // Query confirmed paired devices from OS
        if (typeof _btConfig.getAllPairedDevices === "function") {
            let rawPaired = _btConfig.getAllPairedDevices() || []
            for (let i = 0; i < rawPaired.length; i++) {
                let p = rawPaired[i]
                if (p && p.address) {
                    let addrUpper = p.address.trim().toUpperCase()
                    if (addrUpper.length > 0 && addrUpper !== "0") {
                        pairedAddressMap[addrUpper] = true
                        _sessionPairedAddresses[addrUpper] = true
                        let rawName = (p.name && p.name.trim().length > 0) ? p.name.trim() : ""
                        let isSkyx = _isDeviceSkyx(rawName)
                        let liveDev = liveAddressMap[addrUpper]
                        let rssiVal = (liveDev && liveDev.rssi !== undefined && liveDev.rssi !== null) ? liveDev.rssi : ((p.rssi !== undefined && p.rssi !== null) ? p.rssi : 0)
                        let isConnected = !!connectedAddressMap[addrUpper]
                        let isConfigured = _isAddressConfigured(p.address)
                        let isDetected = isConnected || (liveDev !== undefined) || (rssiVal !== 0)
                        paired.push({
                            name: rawName.length > 0 ? rawName : qsTr("Unknown Device (%1)").arg(p.address),
                            rawName: rawName,
                            address: p.address,
                            rssi: rssiVal,
                            paired: true,
                            detected: isDetected,
                            connected: isConnected,
                            isConfigured: isConfigured,
                            isSkyx: isSkyx,
                            transportType: "bluetooth"
                        })
                    }
                }
            }
        }

        // Check if any device in live devModel is paired via isPaired() or recorded in _sessionPairedAddresses
        for (let sIdx = 0; sIdx < devModel.length; sIdx++) {
            let sDev = devModel[sIdx]
            if (sDev && sDev.address) {
                let sAddrUpper = sDev.address.trim().toUpperCase()
                if (sAddrUpper.length > 0 && sAddrUpper !== "0" && !pairedAddressMap[sAddrUpper]) {
                    let isDevPaired = (_btConfig && typeof _btConfig.isPaired === "function" && _btConfig.isPaired(sDev.address))
                        || !!_sessionPairedAddresses[sAddrUpper]
                    if (isDevPaired) {
                        pairedAddressMap[sAddrUpper] = true
                        _sessionPairedAddresses[sAddrUpper] = true
                        let rawName = (sDev.name && sDev.name.trim().length > 0) ? sDev.name.trim() : ""
                        let isSkyx = _isDeviceSkyx(rawName)
                        let rssiVal = (sDev.rssi !== undefined && sDev.rssi !== null) ? sDev.rssi : 0
                        let isConnected = !!connectedAddressMap[sAddrUpper]
                        let isConfigured = _isAddressConfigured(sDev.address)
                        let isDetected = isConnected || (rssiVal !== 0)
                        paired.push({
                            name: rawName.length > 0 ? rawName : qsTr("Unknown Device (%1)").arg(sDev.address),
                            rawName: rawName,
                            address: sDev.address,
                            rssi: rssiVal,
                            paired: true,
                            detected: isDetected,
                            connected: isConnected,
                            isConfigured: isConfigured,
                            isSkyx: isSkyx,
                            transportType: "bluetooth"
                        })
                    }
                }
            }
        }

        // Include saved/known Bluetooth configurations from LinkManager
        let configs = QGroundControl.linkManager.linkConfigurations
        if (configs) {
            for (let cIdx = configs.count - 1; cIdx >= 0; cIdx--) {
                let savedCfg = configs.get(cIdx)
                if (savedCfg && savedCfg.linkType === LinkConfiguration.TypeBluetooth && savedCfg.address) {
                    let savedAddrUpper = savedCfg.address.trim().toUpperCase()
                    if (savedAddrUpper.length > 0 && savedAddrUpper !== "0") {
                        let isOsPaired = (_btConfig && typeof _btConfig.isPaired === "function" && _btConfig.isPaired(savedCfg.address))
                            || !!_sessionPairedAddresses[savedAddrUpper]

                        if (!isOsPaired) {
                            // User unpaired in Android Settings: remove stale configuration from LinkManager
                            console.log("PulseGCS: Stale unbonded Bluetooth config detected for", savedCfg.address, "- removing configuration")
                            QGroundControl.linkManager.removeConfiguration(savedCfg)
                            if (_btConfig === savedCfg) {
                                _btConfig = null
                            }
                            continue
                        }

                        if (!pairedAddressMap[savedAddrUpper]) {
                            pairedAddressMap[savedAddrUpper] = true
                            _sessionPairedAddresses[savedAddrUpper] = true
                            let cfgName = (savedCfg.deviceName && savedCfg.deviceName.trim().length > 0)
                                ? savedCfg.deviceName.trim()
                                : (savedCfg.name ? savedCfg.name.trim() : "")
                            if (cfgName.indexOf("auto-") === 0) {
                                cfgName = cfgName.substring(5)
                            }
                            let isSkyx = _isDeviceSkyx(cfgName)
                            let liveDev = liveAddressMap[savedAddrUpper]
                            let rssiVal = (liveDev && liveDev.rssi !== undefined && liveDev.rssi !== null) ? liveDev.rssi : 0
                            let isConnected = !!connectedAddressMap[savedAddrUpper]
                            let isDetected = isConnected || (liveDev !== undefined) || (rssiVal !== 0)
                            paired.push({
                                name: cfgName.length > 0 ? cfgName : qsTr("Unknown Device (%1)").arg(savedCfg.address),
                                rawName: cfgName,
                                address: savedCfg.address,
                                rssi: rssiVal,
                                paired: true,
                                detected: isDetected,
                                connected: isConnected,
                                isConfigured: true,
                                isSkyx: isSkyx,
                                transportType: "bluetooth"
                            })
                        }
                    }
                }
            }
        }

        // Authoritative active connection inclusion:
        // If an aircraft is currently connected or active, ensure its Bluetooth device entry is present in paired list
        let activeCfg = _resolveActiveBtConfig()
        let activeAddr = (activeCfg && activeCfg.address) ? activeCfg.address : (_connectingAddress.length > 0 ? _connectingAddress : "")
        let activeAddrUpper = activeAddr.trim().toUpperCase()
        if (activeAddrUpper.length > 0 && activeAddrUpper !== "0") {
            let isActivelyConn = _isDeviceConnected(activeAddrUpper)
            if (isActivelyConn) {
                if (pairedAddressMap[activeAddrUpper]) {
                    // Ensure the existing entry has connected and detected flagged true
                    for (let pIdx = 0; pIdx < paired.length; pIdx++) {
                        if ((paired[pIdx].address || "").trim().toUpperCase() === activeAddrUpper) {
                            paired[pIdx].connected = true
                            paired[pIdx].detected = true
                            break
                        }
                    }
                } else {
                    // Active RC is connected but not returned in live discovery/paired array; add it explicitly
                    pairedAddressMap[activeAddrUpper] = true
                    _sessionPairedAddresses[activeAddrUpper] = true
                    let devName = (activeCfg && activeCfg.deviceName && activeCfg.deviceName.length > 0)
                        ? activeCfg.deviceName
                        : (_connectingDeviceName.length > 0 ? _connectingDeviceName : (activeCfg ? activeCfg.name : ""))
                    let cleanName = (devName && devName.trim().length > 0) ? devName.trim() : ""
                    if (cleanName.indexOf("auto-") === 0) {
                        cleanName = cleanName.substring(5)
                    }
                    let isSkyx = _isDeviceSkyx(cleanName)
                    let liveDev = liveAddressMap[activeAddrUpper]
                    let rssiVal = (liveDev && liveDev.rssi !== undefined && liveDev.rssi !== null) ? liveDev.rssi : 0
                    paired.push({
                        name: cleanName.length > 0 ? cleanName : qsTr("Unknown Device (%1)").arg(activeAddr),
                        rawName: cleanName,
                        address: activeAddr,
                        rssi: rssiVal,
                        paired: true,
                        detected: true,
                        connected: true,
                        isConfigured: true,
                        isSkyx: isSkyx,
                        transportType: "bluetooth"
                    })
                }
            }
        }

        // Sort paired devices: OS connected first, then configured/saved aircraft, then SKYX first, then detected, then signal strength
        paired.sort(function(a, b) {
            if (a.connected && !b.connected) return -1
            if (!a.connected && b.connected) return 1
            if (a.isConfigured && !b.isConfigured) return -1
            if (!a.isConfigured && b.isConfigured) return 1
            if (a.isSkyx && !b.isSkyx) return -1
            if (!a.isSkyx && b.isSkyx) return 1
            if (a.detected && !b.detected) return -1
            if (!a.detected && b.detected) return 1
            return (b.rssi || 0) - (a.rssi || 0)
        })
        _pairedDevices = paired

        // 2. Build Discovered Devices list from scanned devices, strictly excluding paired or configured devices
        let discoveredMap = {}

        for (let j = 0; j < devModel.length; j++) {
            let d = devModel[j]
            if (d && d.address) {
                let addrUpper = d.address.trim().toUpperCase()
                if (addrUpper.length === 0 || addrUpper === "0") {
                    continue
                }
                let isDevPaired = pairedAddressMap[addrUpper]
                    || !!_sessionPairedAddresses[addrUpper]
                    || (_btConfig && typeof _btConfig.isPaired === "function" && _btConfig.isPaired(d.address) === true)
                let isKnownConfigured = _isAddressConfigured(d.address)

                if (isDevPaired) {
                    if (!pairedAddressMap[addrUpper]) {
                        pairedAddressMap[addrUpper] = true
                        _sessionPairedAddresses[addrUpper] = true
                        let rawName = (d.name && d.name.trim().length > 0) ? d.name.trim() : ""
                        let isSkyx = _isDeviceSkyx(rawName)
                        let rssiVal = (d.rssi !== undefined && d.rssi !== null) ? d.rssi : 0
                        let isConnected = !!connectedAddressMap[addrUpper]
                        let isConfigured = isKnownConfigured
                        let isDetected = isConnected || (rssiVal !== 0)
                        paired.push({
                            name: rawName.length > 0 ? rawName : qsTr("Unknown Device (%1)").arg(d.address),
                            rawName: rawName,
                            address: d.address,
                            rssi: rssiVal,
                            paired: true,
                            detected: isDetected,
                            connected: isConnected,
                            isConfigured: isConfigured,
                            isSkyx: isSkyx,
                            transportType: "bluetooth"
                        })
                    }
                    continue
                }

                // Only genuinely unpaired and unconfigured devices belong in Discovered Aircraft
                if (!isKnownConfigured) {
                    let rawName = (d.name && d.name.trim().length > 0) ? d.name.trim() : ""
                    let isSkyx = _isDeviceSkyx(rawName)
                    discoveredMap[addrUpper] = {
                        name: rawName.length > 0 ? rawName : qsTr("Unknown Device (%1)").arg(d.address),
                        rawName: rawName,
                        address: d.address,
                        rssi: (d.rssi !== undefined && d.rssi !== null) ? d.rssi : 0,
                        paired: false,
                        isSkyx: isSkyx,
                        transportType: "bluetooth"
                    }
                }
            }
        }

        let discovered = []
        for (let key in discoveredMap) {
            discovered.push(discoveredMap[key])
        }

        // Sort discovered devices: SKYX first, then by signal strength
        discovered.sort(function(a, b) {
            if (a.isSkyx && !b.isSkyx) return -1
            if (!a.isSkyx && b.isSkyx) return 1
            return (b.rssi || 0) - (a.rssi || 0)
        })
        _discoveredDevices = discovered

        // 3. Known / Paired Aircraft Auto-Connect
        // Requirement:
        // - If EXACTLY 1 device is paired (_pairedDevices.length === 1), automatically initiate connection.
        // - If more than 1 device is paired (or 0), do NOT auto-connect; pilot must choose from the list.
        // - If connection fails or is cancelled, do NOT re-attempt auto-connect.
        if (!_hasDisconnected && !_hasConnectionFailed && !_hasCancelled && !_manualScanActive
            && !_autoConnectAttempted && !_userCancelled && !_connectionAttemptActive
            && !_isCommunicationLost && !_disconnectPending && _activeVehicle === null) {

            if (_pairedDevices.length === 1) {
                let singlePaired = _pairedDevices[0]
                if (singlePaired && (singlePaired.connected || singlePaired.isConfigured || singlePaired.detected || _isAddressConfigured(singlePaired.address))) {
                    _autoConnectAttempted = true
                    console.log("PulseGCS: Exactly 1 paired aircraft available (" + singlePaired.name + "), automatically connecting to connecting panel...")
                    connectDevice(singlePaired)
                }
            } else if (_pairedDevices.length > 1) {
                // More than 1 paired device: do not auto-connect, mark as attempted so it stays on the paired device selection list
                _autoConnectAttempted = true
                console.log("PulseGCS: Multiple paired devices detected (" + _pairedDevices.length + "). Auto-connect suppressed; awaiting pilot selection.")
            }
        }
    }

    function _isDeviceConnected(address) {
        if (!address || _connectionState !== PulseGCSAircraft.Connected || !_activeVehicle) {
            return false
        }
        let addrUpper = address.trim().toUpperCase()
        if (addrUpper.length === 0 || addrUpper === "0") {
            return false
        }
        if (_btConfig && (_btConfig.address || "").trim().toUpperCase() === addrUpper) {
            return true
        }
        if (_connectingAddress && _connectingAddress.trim().toUpperCase() === addrUpper && _connectionState === PulseGCSAircraft.Connected) {
            return true
        }
        return false
    }

    function pairDevice(address) {
        if (!address || !_btConfig) {
            return
        }
        let cleanAddrUpper = address.trim().toUpperCase()
        _pairingAddress = cleanAddrUpper
        pairingWatchdog.restart()
        _statusMessage = qsTr("Pairing request sent to %1. Follow the on-screen prompt.").arg(address)
        if (typeof _btConfig.requestPairing === "function") {
            _btConfig.requestPairing(address)
        }
        _refreshDeviceLists()
    }

    function unpairDevice(device) {
        if (!device || !device.address || !_btConfig) {
            return
        }

        let devAddrUpper = (device.address || "").trim().toUpperCase()
        if (devAddrUpper.length === 0 || devAddrUpper === "0") {
            return
        }

        if (_isDeviceConnected(devAddrUpper)) {
            disconnectDevice()
        }

        let isOsPaired = !!device.paired
        if (isOsPaired) {
            _statusMessage = qsTr("Unpaired %1 successfully.").arg(device.name)
            if (typeof _btConfig.removePairing === "function") {
                _btConfig.removePairing(devAddrUpper)
            }
        } else {
            _statusMessage = qsTr("Removed configuration for %1.").arg(device.name)
        }
        _hasCancelled = true
        _hasConnectionFailed = false
        _hasDisconnected = false

        if (typeof _sessionPairedAddresses[devAddrUpper] !== "undefined") {
            delete _sessionPairedAddresses[devAddrUpper]
        }
        if (_pairingAddress === devAddrUpper) {
            _pairingAddress = ""
            pairingWatchdog.stop()
        }
        // Purge session memory for this aircraft so re-pairing doesn't falsely show "Reconnect"
        if (_lastKnownAircraftName === (device.name || "") || _lastKnownAircraftName === (device.rawName || "")) {
            _lastKnownAircraftName = ""
        }
        if (_connectingAddress === devAddrUpper) {
            _connectingAddress = ""
            _connectingDeviceName = ""
        }

        let configs = QGroundControl.linkManager.linkConfigurations
        if (configs) {
            for (let i = configs.count - 1; i >= 0; i--) {
                let cfg = configs.get(i)
                let cfgAddrUpper = (cfg && cfg.address) ? cfg.address.trim().toUpperCase() : ""
                if (cfg && cfg.linkType === LinkConfiguration.TypeBluetooth && cfgAddrUpper.length > 0 && cfgAddrUpper === devAddrUpper) {
                    QGroundControl.linkManager.removeConfiguration(cfg)
                }
            }
        }
        if (_btConfig && (_btConfig.address || "").trim().toUpperCase() === devAddrUpper) {
            _btConfig = null
        }

        if (!_btConfig) {
            _initBluetooth()
        } else {
            _refreshDeviceLists()
            if (_isScanAllowed && !_isScanning) {
                startScan()
            }
        }
    }

    function connectDevice(device) {
        if (!device || !device.address) {
            return
        }

        if (_activeVehicle && _connectionState === PulseGCSAircraft.Connected) {
            if (_btConfig) {
                QGroundControl.linkManager.disconnectLinkConfiguration(_btConfig)
            }
        }

        stopScan()

        _hasConnectionFailed = false
        _hasCancelled = false
        _hasDisconnected = false
        _connectingAddress = device.address
        _connectingDeviceName = (device.rawName && device.rawName.length > 0) ? device.rawName : device.name
        _lastKnownAircraftName = _connectingDeviceName
        _connectionAttemptActive = true
        _autoConnectAttempted = true
        _userCancelled = false
        _manualScanActive = false
        _lastFailureDetail = ""
        _statusMessage = qsTr("Connecting to %1...").arg(_connectingDeviceName)

        let linkName = _generateAutoLinkName(device)
        let configs = QGroundControl.linkManager.linkConfigurations
        let targetConfig = null

        // 1. Check whether an existing Bluetooth configuration already represents this device/address
        for (let i = 0; i < configs.count; i++) {
            let cfg = configs.get(i)
            if (cfg && cfg.linkType === LinkConfiguration.TypeBluetooth) {
                if (cfg.address && cfg.address === device.address) {
                    targetConfig = cfg
                    break
                }
            }
        }

        if (targetConfig) {
            // 2. Reuse the existing configuration
            console.log("PulseGCS: Reusing existing Bluetooth configuration for", device.address, ":", targetConfig.name)
            if (typeof targetConfig.setDeviceByAddress === "function") {
                targetConfig.setDeviceByAddress(device.address)
            }
            if (_btConfig && _btConfig !== targetConfig && typeof targetConfig.copyFrom === "function") {
                targetConfig.copyFrom(_btConfig)
            }
            targetConfig.dynamic = false
            targetConfig.autoConnect = true

            // If name is legacy or generic auto, update it to auto-<device-name>
            if (targetConfig.name === "PulseGCS Bluetooth Link" || targetConfig.name.indexOf("auto-") === 0) {
                targetConfig.name = linkName
            }
            _btConfig = targetConfig
        } else {
            // 3. No existing configuration found for this device address.
            // Check if current _btConfig is an unpersisted helper (not in LinkManager)
            let isCurrentInLinkManager = false
            for (let j = 0; j < configs.count; j++) {
                if (configs.get(j) === _btConfig) {
                    isCurrentInLinkManager = true
                    break
                }
            }

            if (!isCurrentInLinkManager && _btConfig) {
                // Promote our unpersisted helper into the persistent configuration
                console.log("PulseGCS: Promoting helper to persistent auto configuration:", linkName, device.address)
                _btConfig.name = linkName
                if (typeof _btConfig.setDeviceByAddress === "function") {
                    _btConfig.setDeviceByAddress(device.address)
                }
                _btConfig.dynamic = false
                _btConfig.autoConnect = true
                QGroundControl.linkManager.endCreateConfiguration(_btConfig)
                targetConfig = _btConfig
            } else {
                // Create a new persistent configuration for this device
                console.log("PulseGCS: Creating new persistent auto configuration:", linkName, device.address)
                let newConfig = QGroundControl.linkManager.createConfiguration(LinkConfiguration.TypeBluetooth, linkName)
                if (newConfig) {
                    if (_btConfig && typeof newConfig.copyFrom === "function") {
                        newConfig.copyFrom(_btConfig)
                    }
                    if (typeof newConfig.setDeviceByAddress === "function") {
                        newConfig.setDeviceByAddress(device.address)
                    }
                    newConfig.dynamic = false
                    newConfig.autoConnect = true
                    QGroundControl.linkManager.endCreateConfiguration(newConfig)
                    _btConfig = newConfig
                    targetConfig = newConfig
                }
            }
        }

        if (targetConfig) {
            QGroundControl.linkManager.createConnectedLink(targetConfig)
        }
    }

    function disconnectDevice() {
        _wasConnectedInSession = false
        _userCancelled = true
        _hasDisconnected = false
        _hasCancelled = false
        _hasConnectionFailed = false
        _statusMessage = qsTr("Disconnecting...")
        _connectingAddress = ""
        _connectingDeviceName = ""
        _connectionAttemptActive = false
        _manualScanActive = false
        _reconnectAttempt = 1
        _lostElapsedSeconds = 0

        _resolveActiveBtConfig()

        let linkIsActive = false
        if (_btConfig) {
            console.log("User initiated disconnect: suppressing native reconnect for", _btConfig.name)
            linkIsActive = _btConfig.linkActive
            QGroundControl.linkManager.disconnectLinkConfiguration(_btConfig)
        }

        if (_activeVehicle && typeof _activeVehicle.closeVehicle === "function") {
            _activeVehicle.closeVehicle()
        }

        if (linkIsActive || _activeVehicle !== null) {
            _disconnectPending = true
            disconnectWatchdog.restart()
        } else {
            _finalizeDisconnect()
        }
    }

    function _handleConnectionError(errorMsg) {
        if (_userCancelled) {
            return
        }
        if (_connectionAttemptActive || _isConnectingOrSyncing) {
            if (_activeVehicle && _activeVehicle.vehicleLinkManager && _activeVehicle.vehicleLinkManager.communicationLost) {
                console.log("Communication lost detected during sync; deferring to recovery")
                return
            }
            _connectionAttemptActive = false
            connectionWatchdog.stop()
            paramSyncWatchdog.stop()
            _hasConnectionFailed = true
            _hasCancelled = false
            _hasDisconnected = false
            let devName = _aircraftDisplayName()
            _lastFailureDetail = _humanizeSocketError(errorMsg)
            _statusMessage = qsTr("Connection to %1 failed: %2").arg(devName).arg(_lastFailureDetail)
            console.log("Unexpected Bluetooth/connection loss: preserving native reconnect")
        }
    }

    function cancelConnection() {
        _connectionAttemptActive = false
        _userCancelled = true
        _hasCancelled = true
        _hasDisconnected = false
        _hasConnectionFailed = false
        connectionWatchdog.stop()
        paramSyncWatchdog.stop()
        _resolveActiveBtConfig()
        if (_btConfig) {
            console.log("User initiated disconnect: suppressing native reconnect for", _btConfig.name)
            QGroundControl.linkManager.disconnectLinkConfiguration(_btConfig)
        }
        if (_activeVehicle && typeof _activeVehicle.closeVehicle === "function") {
            _activeVehicle.closeVehicle()
        }
        _statusMessage = qsTr("Connection failed: User terminated the action...")
        if (_btConfig && typeof _btConfig.powerOnAdapter === "function" && !_btConfig.isAdapterAvailable()) {
            _btConfig.powerOnAdapter()
        }
        _refreshDeviceLists()
    }

    // -------------------------------------------------------------------------
    // Signal Observers
    // -------------------------------------------------------------------------
    Connections {
        target: _btConfig
        ignoreUnknownSignals: true

        function onLinkActiveChanged() {
            _refreshDeviceLists()
            if (_disconnectPending && !_btConfig.linkActive && _activeVehicle === null) {
                _finalizeDisconnect()
            }
        }

        function onDevicesModelChanged() {
            _refreshDeviceLists()
        }

        function onPairingStatusChanged() {
            if (_pairingAddress.length > 0 && _btConfig && typeof _btConfig.isPaired === "function" && _btConfig.isPaired(_pairingAddress)) {
                console.log("PulseGCS: Authoritative pairing confirmed for", _pairingAddress)
                _sessionPairedAddresses[_pairingAddress] = true
                _pairingAddress = ""
                pairingWatchdog.stop()
                _statusMessage = qsTr("Device paired successfully.")
            }
            _refreshDeviceLists()
        }

        function onScanningChanged() {
            let totalDetected = _discoveredDevices.length + _pairedDevices.length
            if (!_btConfig.scanning && totalDetected === 0 && !_connectionAttemptActive && !_scanTimedOut) {
                _statusMessage = qsTr("Scan completed. No devices detected.")
            } else if (!_btConfig.scanning && totalDetected > 0 && !_connectionAttemptActive) {
                _statusMessage = qsTr("Scan completed. %1 paired, %2 discovered.").arg(_pairedDevices.length).arg(_discoveredDevices.length)
            } else if (_btConfig.scanning) {
                _statusMessage = qsTr("Searching for aircraft...")
            }
        }

        function onErrorOccurred(errorString) {
            if (_pairingAddress.length > 0) {
                console.log("PulseGCS: Pairing error for", _pairingAddress, errorString)
                _pairingAddress = ""
                pairingWatchdog.stop()
                _statusMessage = qsTr("Pairing failed: %1").arg(errorString)
                _refreshDeviceLists()
            }
            _handleConnectionError(errorString)
        }

        function onAdapterStateChanged() {
            _refreshDeviceLists()
            if (_btConfig && _btConfig.adapterAvailable && _btConfig.adapterPoweredOn && _isScanAllowed && !_isScanning && _discoveredDevices.length === 0) {
                startScan()
            }
        }
    }

    Connections {
        target: _activeVehicle
        ignoreUnknownSignals: true

        function onLoadProgressChanged() {
            if (_isParameterSyncing) {
                let pct = Math.round(_discoveryProgress * 100)
                _statusMessage = qsTr("Syncing parameters (%1%)...").arg(pct)
            }
        }
    }

    Connections {
        target: _activeLink
        ignoreUnknownSignals: true

        function onCommunicationError(title, error) {
            let msg = (error && error.length > 0) ? error : title
            if (_connectionAttemptActive || _isConnectingOrSyncing) {
                _handleConnectionError(msg)
            } else if (_isCommunicationLost || _connectionState === PulseGCSAircraft.Connected) {
                _lastFailureDetail = _humanizeSocketError(msg)
                _statusMessage = qsTr("Link error: %1").arg(_lastFailureDetail)
            }
        }

        function onDisconnected() {
            if (_connectionAttemptActive || _isConnectingOrSyncing) {
                _handleConnectionError(qsTr("Link disconnected unexpectedly."))
            } else if (_disconnectPending) {
                _finalizeDisconnect()
            }
        }
    }

    Connections {
        target: _activeAircraftInfo
        ignoreUnknownSignals: true

        function onConnectionStateChanged() {
            _handleBackendConnectionState()
        }

        function onDiscoveryProgressChanged() {
            if (_connectionState === PulseGCSAircraft.ParameterSync || _isParameterSyncing) {
                let pct = Math.round(_discoveryProgress * 100)
                _statusMessage = qsTr("Syncing parameters (%1%)...").arg(pct)
            }
        }
    }

    Connections {
        target: PulseGCSAircraftManager
        ignoreUnknownSignals: true

        function onActiveAircraftInfoChanged() {
            _handleBackendConnectionState()
        }
    }

    function _handleBackendConnectionState() {
        if (!_activeAircraftInfo) {
            if (!_connectionAttemptActive && _statusMessage === "") {
                _statusMessage = qsTr("Disconnected")
            }
            return
        }

        switch (_connectionState) {
        case PulseGCSAircraft.Searching:
            if (_connectionAttemptActive) {
                _statusMessage = qsTr("Establishing link with %1...").arg(_connectingDeviceName)
            }
            break

        case PulseGCSAircraft.Connecting:
            _statusMessage = qsTr("Device detected. Handshaking...")
            break

        case PulseGCSAircraft.ParameterSync:
            connectionWatchdog.stop()
            let pct = Math.round(_discoveryProgress * 100)
            _statusMessage = qsTr("Syncing parameters (%1%)...").arg(pct)
            break

        case PulseGCSAircraft.Connected:
            _wasConnectedInSession = true
            _connectionAttemptActive = false
            _userCancelled = false
            _reconnectAttempt = 1
            _lostElapsedSeconds = 0
            connectionWatchdog.stop()
            paramSyncWatchdog.stop()
            let vehicleName = _activeAircraftInfo.model && _activeAircraftInfo.model !== "Unknown" ? _activeAircraftInfo.model : _connectingDeviceName
            if (vehicleName.length === 0) {
                vehicleName = _isSkyx ? qsTr("SkyX Aircraft") : qsTr("Vehicle")
            }
            _lastKnownAircraftName = vehicleName
            _statusMessage = qsTr("Connected to %1").arg(vehicleName)
            root.aircraftConnected(null)

            if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showFlyView === "function") {
                mainWindow.showFlyView()
            }
            break

        case PulseGCSAircraft.CommunicationLost:
            _connectionAttemptActive = false
            connectionWatchdog.stop()
            if (_lostElapsedSeconds === 0) {
                _reconnectAttempt = 1
            }
            _statusMessage = qsTr("Communication lost with %1. Auto-reconnecting (attempt %2/%3)...")
                              .arg(_aircraftDisplayName())
                              .arg(_reconnectAttempt)
                              .arg(_maxReconnectAttempts)
            break

        case PulseGCSAircraft.InitialFailed:
            _handleConnectionError(_lastFailureDetail.length > 0
                                   ? _lastFailureDetail
                                   : qsTr("Initial connection to %1 failed. Please retry.").arg(_aircraftDisplayName()))
            break

        case PulseGCSAircraft.IdentityConflict:
            _handleConnectionError(qsTr("Identity conflict detected for vehicle."))
            break

        case PulseGCSAircraft.Disconnected:
            if (_connectionAttemptActive) {
                _handleConnectionError(qsTr("Connection was disconnected."))
            } else if (_disconnectPending) {
                _finalizeDisconnect()
            }
            break

        default:
            break
        }
    }

    // -------------------------------------------------------------------------
    // Main Layout
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // Top Navigation Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: qsTr("Connect Aircraft")
                    font.pixelSize: 18
                    font.bold: true
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    renderType: Text.QtRendering
                }

                PulseGCSStatusPill {
                    visible: _isConnected
                    status: "ok"
                    text: qsTr("CONNECTED")
                    isOutdoor: root.isOutdoor
                }
            }

            Item { Layout.fillWidth: true }

            // Scan / Search Button
            Button {
                id: scanBtn
                text: _isScanning ? qsTr("Cancel Search") : qsTr("Scan Aircraft")
                enabled: _isScanning ? true : _isScanAllowed
                opacity: enabled ? 1.0 : 0.4
                implicitHeight: 32
                font.pixelSize: 11
                font.bold: true

                contentItem: Text {
                    text: scanBtn.text
                    font: scanBtn.font
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }

                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: scanBtn.pressed ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                          : (scanBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated)
                                                             : (root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface))
                    border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                    border.width: 1
                }

                onClicked: {
                    if (_isScanning) {
                        stopScan()
                    } else if (_isScanAllowed) {
                        _manualScanActive = true
                        startScan()
                    }
                }
            }

            // Close / Exit Button
            Button {
                id: exitBtn
                text: qsTr("Exit")
                enabled: !_isConnectingOrSyncing
                opacity: enabled ? 1.0 : 0.4
                implicitHeight: 32
                font.pixelSize: 11
                font.bold: true

                contentItem: Text {
                    text: exitBtn.text
                    font: exitBtn.font
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }

                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: exitBtn.pressed ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                          : (exitBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated)
                                                             : (root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface))
                    border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                    border.width: 1
                }

                onClicked: {
                    stopScan()
                    root.closed()
                    if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showFlyView === "function") {
                        mainWindow.showFlyView()
                    }
                }
            }
        }

        // =====================================================================
        // Discovery State Banners (States 1, 6, 7 & Connecting)
        // =====================================================================

        // State 1: Active Radar Search (#us01-searching)
        Rectangle {
            Layout.fillWidth: true
            height: searchingRow.implicitHeight + 20
            radius: PulseGCSTokens.radiusCard
            color: PulseGCSTokens.cardTintBackground(root.isOutdoor)
            border.color: Qt.rgba(PulseGCSTokens.accentColor(root.isOutdoor).r, PulseGCSTokens.accentColor(root.isOutdoor).g, PulseGCSTokens.accentColor(root.isOutdoor).b, 0.3)
            border.width: 1
            visible: _isScanning && _isScanAllowed && !_isConnectingOrSyncing && !_isCommunicationLost

            RowLayout {
                id: searchingRow
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 14

                PulseGCSRadarScanner {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    scanning: _isScanning
                    isOutdoor: root.isOutdoor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: 8
                        Text {
                            text: qsTr("Searching for Aircraft...")
                            font.pixelSize: 13
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        PulseGCSStatusPill {
                            status: "accentpill"
                            text: qsTr("SCANNING")
                            pulsing: true
                            isOutdoor: root.isOutdoor
                        }
                    }

                    Text {
                        text: qsTr("Scanning wireless link for broadcasting aircraft...")
                        font.pixelSize: 11
                        color: PulseGCSTokens.mutedText(root.isOutdoor)
                        renderType: Text.QtRendering
                    }

                    Text {
                        text: qsTr("Elapsed %1 — looking for aircraft").arg(_formatElapsed(_scanElapsedSeconds))
                        font.pixelSize: 10
                        font.bold: true
                        color: PulseGCSTokens.accentColor(root.isOutdoor)
                        renderType: Text.QtRendering
                    }
                }
            }
        }

        // State 7: Discovery Timeout Card (#us01-timeout)
        Rectangle {
            Layout.fillWidth: true
            height: timeoutRow.implicitHeight + 20
            radius: PulseGCSTokens.radiusCard
            color: PulseGCSTokens.statusBackgroundColor("warn", root.isOutdoor)
            border.color: Qt.rgba(PulseGCSTokens.statusColor("warn", root.isOutdoor).r, PulseGCSTokens.statusColor("warn", root.isOutdoor).g, PulseGCSTokens.statusColor("warn", root.isOutdoor).b, 0.35)
            border.width: 1
            visible: !_isConnected && !_isConnectingOrSyncing && _scanTimedOut && !_isScanning && _discoveredDevices.length === 0 && _pairedDevices.length === 0

            RowLayout {
                id: timeoutRow
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: PulseGCSTokens.statusBackgroundColor("warn", root.isOutdoor)
                    border.color: PulseGCSTokens.statusColor("warn", root.isOutdoor)
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        font.pixelSize: 16
                        font.bold: true
                        color: PulseGCSTokens.statusColor("warn", root.isOutdoor)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: 8
                        Text {
                            text: qsTr("Discovery Timed Out (30s)")
                            font.pixelSize: 13
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        PulseGCSStatusPill {
                            status: "warn"
                            text: qsTr("NO RESPONSE")
                            isOutdoor: root.isOutdoor
                        }
                    }

                    Text {
                        text: qsTr("No aircraft responded within the 30-second discovery window. Ensure aircraft telemetry is active.")
                        font.pixelSize: 11
                        color: PulseGCSTokens.mutedText(root.isOutdoor)
                        renderType: Text.QtRendering
                        wrapMode: Text.WordWrap
                    }
                }

                RowLayout {
                    spacing: 8
                    Button {
                        text: qsTr("Search Again")
                        enabled: _isScanAllowed
                        opacity: enabled ? 1.0 : 0.4
                        implicitHeight: 28
                        font.pixelSize: 11
                        font.bold: true
                        onClicked: {
                            if (_isScanAllowed) {
                                _manualScanActive = true
                                startScan()
                            }
                        }

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
                        text: qsTr("Manual Connection")
                        implicitHeight: 28
                        font.pixelSize: 11
                        font.bold: true
                        onClicked: {
                            root.advancedConnectionRequested()
                            if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showSettingsTool === "function") {
                                mainWindow.showSettingsTool("Comm Links")
                            }
                        }

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
        }


        // =====================================================================
        // Connection Lifecycle Notice Bar (Connection Failed, Cancelled, Disconnected)
        // =====================================================================
        PulseGCSNoticeBar {
            Layout.fillWidth: true
            visible: _showNoticeBar
            noticeType: _showConnectionError ? "err" : "info"
            message: {
                if (_showConnectionError) {
                    return _lastFailureDetail.length > 0 ? _lastFailureDetail : _statusMessage
                }
                if (_showCancelledNotice) {
                    return (_statusMessage.length > 0 && _statusMessage !== qsTr("Disconnecting..."))
                        ? _statusMessage
                        : qsTr("Connection cancelled. Attempt stopped by operator.")
                }
                if (_showDisconnectedNotice) {
                    return _lastKnownAircraftName.length > 0
                        ? qsTr("Disconnected from %1. None active.").arg(_lastKnownAircraftName)
                        : qsTr("Aircraft disconnected. None active.")
                }
                return ""
            }
            actionText: ""
            isOutdoor: root.isOutdoor
            onActionClicked: {}
        }



        // =====================================================================
        // Scrollable Devices List
        // =====================================================================
        Flickable {
            id: flickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: scrollCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: scrollCol
                width: flickable.width
                spacing: 16

                // -------------------------------------------------------------
                // Dedicated Connecting State Card (#us02-connecting)
                // -------------------------------------------------------------
                PulseGCSStateCard {
                    id: connectingCard
                    Layout.fillWidth: true
                    visible: _isConnecting
                    title: qsTr("Connecting")
                    subtitle: _aircraftDisplayName()
                    status: "accentpill"
                    statusText: qsTr("CONNECTING")
                    statusPulsing: true
                    showIdentityBadge: true
                    isSkyx: _isSkyx
                    accentTint: true
                    isOutdoor: root.isOutdoor

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Aircraft identity")
                                font.pixelSize: 11
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: _aircraftDisplayName()
                                font.pixelSize: 11
                                font.bold: true
                                color: PulseGCSTokens.primaryText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Connection info")
                                font.pixelSize: 11
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: _connectingAddress.length > 0 ? qsTr("Bluetooth · Pairing (%1)").arg(_connectingAddress) : qsTr("Bluetooth · Pairing…")
                                font.pixelSize: 11
                                font.family: "Monospace"
                                color: PulseGCSTokens.mutedText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: PulseGCSTokens.dividerColor(root.isOutdoor)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: _statusMessage.length > 0 ? _statusMessage : qsTr("Establishing wireless link and awaiting heartbeat...")
                                font.pixelSize: 11
                                color: PulseGCSTokens.mutedText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }

                            PulseGCSProgressBar {
                                Layout.fillWidth: true
                                indeterminate: true
                                isOutdoor: root.isOutdoor
                            }
                        }
                    }

                    footer: RowLayout {
                        width: parent ? parent.width : 300
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Cancel")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: cancelConnection()

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

                // -------------------------------------------------------------
                // Dedicated Parameter Synchronization Card (#us02-paramsync / #us05-progress)
                // -------------------------------------------------------------
                PulseGCSStateCard {
                    id: paramSyncCard
                    Layout.fillWidth: true
                    visible: _isParameterSyncing
                    title: qsTr("Parameter synchronization")
                    subtitle: _aircraftDisplayName()
                    status: "accentpill"
                    statusText: qsTr("SYNCING PARAMS")
                    statusPulsing: true
                    showIdentityBadge: true
                    isSkyx: _isSkyx
                    accentTint: true
                    isOutdoor: root.isOutdoor

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Aircraft identity")
                                font.pixelSize: 11
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: _aircraftDisplayName()
                                font.pixelSize: 11
                                font.bold: true
                                color: PulseGCSTokens.primaryText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Connection info")
                                font.pixelSize: 11
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Bluetooth · paired, heartbeat OK")
                                font.pixelSize: 11
                                font.family: "Monospace"
                                color: PulseGCSTokens.mutedText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: PulseGCSTokens.dividerColor(root.isOutdoor)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("Downloading vehicle parameters")
                                    font.pixelSize: 11
                                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                                    renderType: Text.QtRendering
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: qsTr("%1%").arg(Math.round(_discoveryProgress * 100))
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: PulseGCSTokens.accentColor(root.isOutdoor)
                                    renderType: Text.QtRendering
                                }
                            }

                            PulseGCSProgressBar {
                                Layout.fillWidth: true
                                indeterminate: _discoveryProgress <= 0.0
                                progress: _discoveryProgress
                                isOutdoor: root.isOutdoor
                            }

                            Text {
                                text: qsTr("This can take up to a minute on first connection.")
                                font.pixelSize: 10
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }
                    }

                    footer: RowLayout {
                        width: parent ? parent.width : 300
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Cancel")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: cancelConnection()

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

                // -------------------------------------------------------------
                // Dedicated Communication Lost / Reconnecting State Card (M2-US09)
                // -------------------------------------------------------------
                PulseGCSStateCard {
                    id: reconnectCard
                    Layout.fillWidth: true
                    visible: _isCommunicationLost
                    title: _isRecoveryFailed ? qsTr("Recovery failed") : (_lostElapsedSeconds < 4 ? qsTr("Communication lost") : qsTr("Reconnecting"))
                    subtitle: _aircraftDisplayName()
                    status: _isRecoveryFailed ? "err" : (_lostElapsedSeconds < 4 ? "warn" : "accentpill")
                    statusText: _isRecoveryFailed ? qsTr("RECONNECT FAILED") : (_lostElapsedSeconds < 4 ? qsTr("COMM LOST") : qsTr("RECONNECTING · ATTEMPT %1/%2").arg(root._reconnectAttempt).arg(root._maxReconnectAttempts))
                    statusPulsing: !_isRecoveryFailed
                    showIdentityBadge: true
                    isSkyx: _isSkyx
                    accentTint: !_isRecoveryFailed && _lostElapsedSeconds >= 4
                    isOutdoor: root.isOutdoor

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Aircraft identity")
                                font.pixelSize: 11
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: _aircraftDisplayName()
                                font.pixelSize: 11
                                font.bold: true
                                color: PulseGCSTokens.primaryText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Last heartbeat")
                                font.pixelSize: 11
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("%1s ago").arg(root._lostElapsedSeconds)
                                font.pixelSize: 11
                                font.family: "Monospace"
                                color: PulseGCSTokens.statusColor("warn", root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Recovery method")
                                font.pixelSize: 11
                                color: PulseGCSTokens.metaText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Bluetooth · automatic retry")
                                font.pixelSize: 11
                                font.family: "Monospace"
                                color: PulseGCSTokens.mutedText(root.isOutdoor)
                                renderType: Text.QtRendering
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: PulseGCSTokens.dividerColor(root.isOutdoor)
                        }

                        // Status / Progress description
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: _isReconnectAborted
                                    ? qsTr("Reconnection failed: User terminated the action. You may retry or disconnect.")
                                    : (_isRecoveryFailed
                                        ? qsTr("Automatic reconnection attempts exhausted. Confirm the aircraft is powered on and in range.")
                                        : (_lostElapsedSeconds < 4
                                            ? qsTr("Link interrupted. Stand by while PulseGCS attempts automatic recovery.")
                                            : qsTr("Attempting to restore link to %1 — attempt %2 of %3.")
                                                .arg(_aircraftDisplayName())
                                                .arg(root._reconnectAttempt)
                                                .arg(root._maxReconnectAttempts)))
                                font.pixelSize: 11
                                color: PulseGCSTokens.mutedText(root.isOutdoor)
                                wrapMode: Text.WordWrap
                                renderType: Text.QtRendering
                            }

                            PulseGCSProgressBar {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                visible: !_isRecoveryFailed && !_isReconnectAborted
                                indeterminate: true
                                isOutdoor: root.isOutdoor
                                barColor: _lostElapsedSeconds < 4 ? PulseGCSTokens.statusColor("warn", root.isOutdoor) : PulseGCSTokens.accentColor(root.isOutdoor)
                            }
                        }
                    }

                    footer: RowLayout {
                        width: parent ? parent.width : 300
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        // Cancel Reconnect (available while actively retrying and not aborted)
                        Button {
                            visible: !_isRecoveryFailed && !_isReconnectAborted
                            text: qsTr("Cancel Reconnect")
                            implicitHeight: 30
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

                        // Disconnect (available when user aborted reconnection)
                        Button {
                            visible: _isReconnectAborted
                            text: qsTr("Disconnect")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: {
                                _isReconnectAborted = false
                                _wasConnectedInSession = false
                                disconnectDevice()
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: PulseGCSTokens.statusColor("err", root.isOutdoor)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                renderType: Text.QtRendering
                            }
                            background: Rectangle {
                                radius: 6
                                color: root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface
                                border.color: PulseGCSTokens.statusColor("err", root.isOutdoor)
                                border.width: 1
                            }
                        }

                        // Search Again (available when failed)
                        Button {
                            visible: _isRecoveryFailed && !_isReconnectAborted
                            text: qsTr("Search Again")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: {
                                _userCancelled = true
                                _wasConnectedInSession = false
                                disconnectDevice()
                                _manualScanActive = true
                                startScan()
                            }

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

                        // Retry Now / Retry
                        Button {
                            text: _isReconnectAborted ? qsTr("Retry") : qsTr("Retry Now")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: {
                                root._isReconnectAborted = false
                                root._userCancelled = false
                                root._reconnectAttempt = 1
                                root._lostElapsedSeconds = 0
                                root.retryLastConnection()
                            }

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
                    }
                }

                // -------------------------------------------------------------
                // Authoritative Connected Aircraft Card (#us01-skyx / #us01-nonskyx Connected)
                // -------------------------------------------------------------
                PulseGCSStateCard {
                    Layout.fillWidth: true
                    visible: _isConnected
                    title: (_activeAircraftInfo && _activeAircraftInfo.model && _activeAircraftInfo.model !== "Unknown") ? _activeAircraftInfo.model : (_isSkyx ? qsTr("SkyX Autonomous Aircraft") : qsTr("Connected Aircraft"))
                    subtitle: {
                        let parts = []
                        if (_activeAircraftInfo && _activeAircraftInfo.systemId > 0) {
                            parts.push(qsTr("System ID: %1").arg(_activeAircraftInfo.systemId))
                        }
                        if (_activeAircraftInfo && _activeAircraftInfo.serialNumber && _activeAircraftInfo.serialNumber !== "Unknown") {
                            parts.push(qsTr("SN: %1").arg(_activeAircraftInfo.serialNumber))
                        }
                        if (typeof PulseGCSStartupController !== "undefined" && PulseGCSStartupController.appVersion) {
                            parts.push(qsTr("PulseGCS V%1").arg(PulseGCSStartupController.appVersion))
                        }
                        return parts.join(" | ")
                    }
                    status: "ok"
                    statusText: qsTr("ONLINE")
                    showIdentityBadge: true
                    isSkyx: _isSkyx
                    accentTint: _isSkyx
                    isOutdoor: root.isOutdoor

                    footer: RowLayout {
                        width: parent ? parent.width : 300
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Disconnect")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: disconnectDevice()

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

                        Button {
                            text: qsTr("Open Fly View")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: {
                                if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showFlyView === "function") {
                                    mainWindow.showFlyView()
                                }
                            }

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
                    }
                }

                // -------------------------------------------------------------
                // Compact Overall Readiness Card
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: PulseGCSTokens.radiusCard
                    color: root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfaceElevatedBackground(root.isOutdoor)
                    border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                    visible: _isConnected

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        PulseGCSStatusPill {
                            status: {
                                if (_connectionState === PulseGCSAircraft.ParameterSync) return "accentpill"
                                if (_activeVehicle) {
                                    if (_activeVehicle.healthAndArmingCheckReport && _activeVehicle.healthAndArmingCheckReport.supported) {
                                        if (!_activeVehicle.healthAndArmingCheckReport.canArm) return "err"
                                        if (_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors) return "warn"
                                        return "ok"
                                    } else if (_activeVehicle.readyToFlyAvailable) {
                                        return _activeVehicle.readyToFly ? "ok" : "warn"
                                    } else {
                                        return (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilotPlugin && _activeVehicle.autopilotPlugin.setupComplete) ? "ok" : "warn"
                                    }
                                }
                                return "ok"
                            }
                            text: {
                                if (_connectionState === PulseGCSAircraft.ParameterSync) return qsTr("CHECKING")
                                if (_activeVehicle) {
                                    if (_activeVehicle.healthAndArmingCheckReport && _activeVehicle.healthAndArmingCheckReport.supported) {
                                        return _activeVehicle.healthAndArmingCheckReport.canArm ? qsTr("READY") : qsTr("NOT READY")
                                    } else if (_activeVehicle.readyToFlyAvailable) {
                                        return _activeVehicle.readyToFly ? qsTr("READY") : qsTr("NOT READY")
                                    } else {
                                        return (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilotPlugin && _activeVehicle.autopilotPlugin.setupComplete) ? qsTr("READY") : qsTr("NOT READY")
                                    }
                                }
                                return qsTr("READY")
                            }
                            isOutdoor: root.isOutdoor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                let parts = []
                                if (_activeVehicle && _activeVehicle.battery) {
                                    let pct = _activeVehicle.battery.percentRemaining.value
                                    if (pct >= 0) {
                                        parts.push(qsTr("Battery: %1%").arg(Math.round(pct)))
                                    }
                                }
                                if (_activeVehicle && _activeVehicle.gps) {
                                    let sats = _activeVehicle.gps.count.value
                                    if (sats >= 0) {
                                        parts.push(qsTr("GPS: %1 Sats").arg(sats))
                                    }
                                }
                                if (_activeVehicle && _activeVehicle.rcRSSI && _activeVehicle.rcRSSI.rawValue > 0 && _activeVehicle.rcRSSI.rawValue <= 100) {
                                    parts.push(qsTr("RC: %1%").arg(Math.round(_activeVehicle.rcRSSI.rawValue)))
                                }
                                let issues = 0
                                if (_activeVehicle) {
                                    if (_activeVehicle.healthAndArmingCheckReport && _activeVehicle.healthAndArmingCheckReport.supported && _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode) {
                                        issues = _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count
                                    } else if (!_activeVehicle.allSensorsHealthy) {
                                        issues = 1
                                    }
                                }
                                parts.push(issues === 1 ? qsTr("1 Issue") : qsTr("%1 Issues").arg(issues))
                                return parts.join("  •  ")
                            }
                            font.pixelSize: 11
                            color: PulseGCSTokens.mutedText(root.isOutdoor)
                            elide: Text.ElideRight
                            renderType: Text.QtRendering
                        }

                        Button {
                            text: qsTr("Pre-Arm Checks")
                            implicitHeight: 30
                            font.pixelSize: 11
                            font.bold: true
                            onClicked: {
                                if (typeof mainWindow !== "undefined" && mainWindow) {
                                    if (typeof mainWindow.hideConnectAircraft === "function") {
                                        mainWindow.hideConnectAircraft()
                                    }
                                    if (typeof mainWindow.showVehicleConfig === "function") {
                                        mainWindow.showVehicleConfig()
                                    }
                                }
                            }
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
                                color: parent.pressed ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                                      : (parent.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated)
                                                                        : (root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface))
                                border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                                border.width: 1
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // Paired Aircraft / Known Devices (Shown First)
                // -------------------------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !_isConnected && !_isCommunicationLost && !_isConnectingOrSyncing && _pairedDevices.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Paired Devices (%1)").arg(_pairedDevices.length)
                            font.pixelSize: 13
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Repeater {
                        model: _pairedDevices

                        delegate: PulseGCSDeviceRow {
                            Layout.fillWidth: true
                            deviceName: modelData.name
                            deviceAddress: modelData.address
                            subtitleText: (!modelData.paired && modelData.isConfigured)
                                ? qsTr("Saved Link · %1").arg(modelData.address)
                                : modelData.address
                            transportType: modelData.transportType || "bluetooth"
                            isSkyx: modelData.isSkyx
                            showIdentityBadge: true
                            rssi: modelData.rssi || 0
                            showSignal: true
                            isOutdoor: root.isOutdoor
                            isSelected: _isDeviceConnected(modelData.address) || (_connectionAttemptActive && _connectingAddress === modelData.address)

                            status: {
                                if (_isDeviceConnected(modelData.address)) return "ok"
                                if (_isCommunicationLost && _btConfig && _btConfig.address === modelData.address) return "accentpill"
                                if (_connectionAttemptActive && _connectingAddress === modelData.address) return "accentpill"
                                if (!modelData.detected) return "subtle"
                                return ""
                            }
                            statusText: {
                                if (_isDeviceConnected(modelData.address)) return qsTr("CONNECTED")
                                if (_isCommunicationLost && _btConfig && _btConfig.address === modelData.address) return qsTr("RECONNECTING")
                                if (_connectionAttemptActive && _connectingAddress === modelData.address) return qsTr("ATTEMPTING CONNECTION...")
                                if (!modelData.detected) return qsTr("UNAVAILABLE")
                                return ""
                            }
                            statusPulsing: (_isCommunicationLost && _btConfig && _btConfig.address === modelData.address)
                                           || (_connectionAttemptActive && _connectingAddress === modelData.address)

                            secondaryActionText: {
                                if (_isCommunicationLost && _btConfig && _btConfig.address === modelData.address) {
                                    return ""
                                }
                                if (_connectionAttemptActive && _connectingAddress === modelData.address) {
                                    return ""
                                }
                                return qsTr("Unpair")
                            }
                            secondaryActionEnabled: !_isCommunicationLost && !_connectionAttemptActive && !_isDeviceConnected(modelData.address)

                            primaryActionText: {
                                if (_isDeviceConnected(modelData.address)) {
                                    return qsTr("Disconnect")
                                } else if (_isCommunicationLost && _btConfig && _btConfig.address === modelData.address) {
                                    return ""
                                } else if (_connectionAttemptActive && _connectingAddress === modelData.address) {
                                    return qsTr("Cancel")
                                } else if (modelData.isConfigured) {
                                    return qsTr("Reconnect")
                                } else {
                                    return qsTr("Connect")
                                }
                            }
                            primaryActionEnabled: {
                                if (_isCommunicationLost) return false
                                if (_connectionAttemptActive && _connectingAddress === modelData.address) return true
                                if (_connectionAttemptActive) return false
                                if (_isDeviceConnected(modelData.address)) return true
                                return true
                            }

                            onSecondaryActionClicked: {
                                _unpairTargetDevice = modelData
                                unpairConfirmPopup.open()
                            }

                            onPrimaryActionClicked: {
                                if (_isDeviceConnected(modelData.address)) {
                                    disconnectDevice()
                                } else if (_connectionAttemptActive && _connectingAddress === modelData.address) {
                                    cancelConnection()
                                } else if (!_connectionAttemptActive) {
                                    connectDevice(modelData)
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // Discovered Aircraft / Devices (Shown Second)
                // -------------------------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !_isConnected && !_isCommunicationLost && !_isConnectingOrSyncing && _discoveredDevices.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Discovered Devices (%1)").arg(_discoveredDevices.length)
                            font.pixelSize: 13
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("Sorted by SKYX Priority & RSSI")
                            font.pixelSize: 10
                            color: PulseGCSTokens.metaText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                    }

                    Repeater {
                        model: _discoveredDevices

                        delegate: PulseGCSDeviceRow {
                            Layout.fillWidth: true
                            deviceName: modelData.name
                            deviceAddress: modelData.address
                            subtitleText: modelData.address
                            transportType: modelData.transportType || "bluetooth"
                            isSkyx: modelData.isSkyx
                            showIdentityBadge: true
                            rssi: modelData.rssi || 0
                            showSignal: true
                            isOutdoor: root.isOutdoor
                            isSelected: (_pairingAddress.length > 0 && _pairingAddress === (modelData.address || "").trim().toUpperCase())
                                        || (_connectionAttemptActive && _connectingAddress === modelData.address)

                            primaryActionText: (_pairingAddress.length > 0 && _pairingAddress === (modelData.address || "").trim().toUpperCase())
                                ? qsTr("Pairing...")
                                : qsTr("Pair")
                            primaryActionEnabled: !_connectionAttemptActive && (_pairingAddress.length === 0 || _pairingAddress !== (modelData.address || "").trim().toUpperCase())

                            onPrimaryActionClicked: {
                                pairDevice(modelData.address)
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // State 6: Empty State / No Aircraft Found (#us01-none)
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    height: emptyCol.implicitHeight + 40
                    radius: PulseGCSTokens.radiusCard
                    color: PulseGCSTokens.surfaceElevatedBackground(root.isOutdoor)
                    border.color: PulseGCSTokens.subtleBorder(root.isOutdoor)
                    border.width: 1
                    visible: !_isConnected && !_isCommunicationLost && !_isConnectingOrSyncing && !_isScanning && !_scanTimedOut && _discoveredDevices.length === 0 && _pairedDevices.length === 0

                    ColumnLayout {
                        id: emptyCol
                        anchors.centerIn: parent
                        spacing: 10
                        width: Math.min(parent.width - 40, 420)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("No Aircraft Detected")
                            font.pixelSize: 15
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            text: qsTr("Ensure the aircraft is powered on, telemetry link is in pairing/discoverable mode, and within wireless range.")
                            font.pixelSize: 11
                            color: PulseGCSTokens.mutedText(root.isOutdoor)
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            renderType: Text.QtRendering
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Button {
                                text: qsTr("Scan Again")
                                enabled: _isScanAllowed
                                opacity: enabled ? 1.0 : 0.4
                                implicitHeight: 30
                                font.pixelSize: 11
                                font.bold: true
                                onClicked: {
                                    if (_isScanAllowed) {
                                        startScan()
                                    }
                                }

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
                                text: qsTr("Manual Connection")
                                implicitHeight: 30
                                font.pixelSize: 11
                                font.bold: true
                                onClicked: {
                                    root.advancedConnectionRequested()
                                    if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showSettingsTool === "function") {
                                        mainWindow.showSettingsTool("Comm Links")
                                    }
                                }

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
                }
            }
        }

        // =====================================================================
        // Footer Bar
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: PulseGCSTokens.dividerColor(root.isOutdoor)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                id: planMapBtn
                text: qsTr("Plan Map")
                implicitHeight: 32
                font.pixelSize: 11
                font.bold: true
                onClicked: {
                    root.planMapRequested()
                    if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showPlanView === "function") {
                        mainWindow.showPlanView()
                    }
                }

                contentItem: Text {
                    text: planMapBtn.text
                    font: planMapBtn.font
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: planMapBtn.pressed ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                              : (planMapBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated)
                                                                    : (root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface))
                    border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                    border.width: 1
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                id: manualLinkBtn
                text: qsTr("Advanced / Manual Connection")
                implicitHeight: 32
                font.pixelSize: 11
                font.bold: true
                onClicked: {
                    root.advancedConnectionRequested()
                    if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showSettingsTool === "function") {
                        mainWindow.showSettingsTool("Comm Links")
                    }
                }

                contentItem: Text {
                    text: manualLinkBtn.text
                    font: manualLinkBtn.font
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.QtRendering
                }
                background: Rectangle {
                    radius: PulseGCSTokens.radiusButton
                    color: manualLinkBtn.pressed ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                                 : (manualLinkBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated)
                                                                          : (root.isOutdoor ? PulseGCSTokens.outdoorButtonSurface : PulseGCSTokens.buttonSurface))
                    border.color: PulseGCSTokens.buttonBorderColor(root.isOutdoor)
                    border.width: 1
                }
            }
        }
    }
}
