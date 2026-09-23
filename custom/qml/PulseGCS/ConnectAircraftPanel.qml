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
    property var _unpairedDevicesCache: ({})
    property bool _isScanning: _btConfig ? _btConfig.scanning : false
    property string _statusMessage: ""

    // -------------------------------------------------------------------------
    // Authoritative Connection State & Vehicle Classification
    // -------------------------------------------------------------------------
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _activeAircraftInfo: PulseGCSAircraftManager.activeAircraftInfo
    property int _connectionState: _activeAircraftInfo ? _activeAircraftInfo.connectionState : -1
    property real _discoveryProgress: _activeAircraftInfo ? _activeAircraftInfo.discoveryProgress : 0.0
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

    readonly property bool _isConnected: _activeVehicle !== null
        && _connectionState === PulseGCSAircraft.Connected
    readonly property bool _isConnectingOrSyncing: _connectionAttemptActive
        || _connectionState === PulseGCSAircraft.Connecting
        || _connectionState === PulseGCSAircraft.ParameterSync
    readonly property bool _isBackendReconnecting: _wasConnectedInSession
        && !_userCancelled
        && _btConfig !== null
        && _btConfig.linkActive
        && (_activeVehicle === null || _connectionState !== PulseGCSAircraft.Connected)
    readonly property bool _isCommunicationLost: _wasConnectedInSession
        && !_userCancelled
        && ((_connectionState === PulseGCSAircraft.CommunicationLost)
            || (_activeVehicle && _activeVehicle.vehicleLinkManager && _activeVehicle.vehicleLinkManager.communicationLost)
            || _isBackendReconnecting)
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
                                            && !_isCommunicationLost
                                            && (_showConnectionError || _showCancelledNotice || _showDisconnectedNotice)

    property var _activeLink: _btConfig ? _btConfig.link : null

    on_ActiveVehicleChanged: {
        if (_disconnectPending && !_activeVehicle && (!_btConfig || !_btConfig.linkActive)) {
            _finalizeDisconnect()
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
            if (_lostElapsedSeconds > 0 && (_lostElapsedSeconds % 8) === 0 && _reconnectAttempt < _maxReconnectAttempts) {
                _reconnectAttempt++
            }
            _statusMessage = qsTr("Communication lost with %1. Auto-reconnecting (attempt %2/%3)...")
                              .arg(_aircraftDisplayName())
                              .arg(_reconnectAttempt)
                              .arg(_maxReconnectAttempts)
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
        _userCancelled = true
        _autoConnectAttempted = true
        _reconnectAttempt = 1
        _lostElapsedSeconds = 0
        disconnectDevice()
        _statusMessage = qsTr("Reconnect cancelled.")
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
        if (visible && _btConfig && !_isScanning && _isScanAllowed) {
            startScan()
        }
    }

    // Connection Watchdog Timer (12 seconds safety timeout for initial handshake)
    Timer {
        id: connectionWatchdog
        interval: 12000
        running: _connectionAttemptActive && _connectionState !== PulseGCSAircraft.Connected
        repeat: false
        onTriggered: {
            if (_connectionAttemptActive && _connectionState !== PulseGCSAircraft.Connected) {
                _connectionAttemptActive = false
                _hasConnectionFailed = true
                _hasCancelled = false
                _hasDisconnected = false
                let devName = _connectingDeviceName.length > 0 ? _connectingDeviceName : qsTr("device")
                _lastFailureDetail = qsTr("Connection timed out. Ensure the device is powered on and within range, then retry.")
                _statusMessage = qsTr("Connection to %1 failed: %2").arg(devName).arg(_lastFailureDetail)
                console.log("Unexpected Bluetooth/connection loss: preserving native reconnect")
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
        _hasDisconnected = true
        _hasCancelled = false
        _hasConnectionFailed = false
        _statusMessage = qsTr("Disconnected")
        _refreshDeviceLists()
    }

    // -------------------------------------------------------------------------
    // Bluetooth Lifecycle & Discovery Functions
    // -------------------------------------------------------------------------
    function _initBluetooth() {
        let configs = QGroundControl.linkManager.linkConfigurations
        for (let i = 0; i < configs.count; i++) {
            let cfg = configs.get(i)
            if (cfg && cfg.linkType === LinkConfiguration.TypeBluetooth && cfg.name === "PulseGCS Bluetooth Link") {
                _btConfig = cfg
                break
            }
        }

        if (!_btConfig) {
            _btConfig = QGroundControl.linkManager.createConfiguration(LinkConfiguration.TypeBluetooth, "PulseGCS Bluetooth Link")
            if (_btConfig) {
                _btConfig.dynamic = false
                _btConfig.autoConnect = true
                QGroundControl.linkManager.endCreateConfiguration(_btConfig)
            }
        }

        if (_btConfig) {
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
        _hasConnectionFailed = false
        _hasCancelled = false
        _hasDisconnected = false
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
                liveAddressMap[devModel[m].address] = devModel[m]
            }
        }

        // Fast-path: Query OS connected devices directly (0ms latency on Android)
        let connectedAddressMap = {}
        if (typeof _btConfig.getConnectedDevices === "function") {
            let osConnected = _btConfig.getConnectedDevices() || []
            for (let c = 0; c < osConnected.length; c++) {
                if (osConnected[c] && osConnected[c].address) {
                    connectedAddressMap[osConnected[c].address] = true
                }
            }
        }

        let paired = []
        let pairedAddressMap = {}
        if (typeof _btConfig.getAllPairedDevices === "function") {
            let rawPaired = _btConfig.getAllPairedDevices() || []
            for (let i = 0; i < rawPaired.length; i++) {
                let p = rawPaired[i]
                if (p && p.address) {
                    pairedAddressMap[p.address] = true
                    let rawName = (p.name && p.name.trim().length > 0) ? p.name.trim() : ""
                    let isSkyx = _isDeviceSkyx(rawName)
                    let liveDev = liveAddressMap[p.address]
                    let rssiVal = (liveDev && liveDev.rssi !== undefined && liveDev.rssi !== null) ? liveDev.rssi : ((p.rssi !== undefined && p.rssi !== null) ? p.rssi : 0)
                    let isConnected = !!connectedAddressMap[p.address]
                    let isConfigured = (_btConfig && _btConfig.address === p.address)
                    let isDetected = isConnected || isConfigured || (liveDev !== undefined) || (rssiVal !== 0)
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

        // 2. Build Discovered Devices list from scanned devices and unbonded cache, excluding paired devices
        let discoveredMap = {}

        // Add any cached unbonded devices that are not in paired map
        for (let addr in _unpairedDevicesCache) {
            if (!pairedAddressMap[addr]) {
                discoveredMap[addr] = _unpairedDevicesCache[addr]
            } else {
                delete _unpairedDevicesCache[addr]
            }
        }

        // Reuse devModel already declared above at line 287
        for (let j = 0; j < devModel.length; j++) {
            let d = devModel[j]
            if (d && d.address) {
                let isAlreadyPaired = pairedAddressMap[d.address] || (typeof _btConfig.isPaired === "function" && _btConfig.isPaired(d.address))
                if (!isAlreadyPaired) {
                    let rawName = (d.name && d.name.trim().length > 0) ? d.name.trim() : ""
                    let isSkyx = _isDeviceSkyx(rawName)
                    discoveredMap[d.address] = {
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
        // If a stored/known paired aircraft is currently available and no vehicle or connection
        // attempt is active, automatically initiate connection without manual user interaction.
        if (!_autoConnectAttempted && !_userCancelled && !_connectionAttemptActive && !_isCommunicationLost && !_disconnectPending && _activeVehicle === null) {
            let availablePaired = null
            for (let k = 0; k < _pairedDevices.length; k++) {
                let dev = _pairedDevices[k]
                if (dev.connected || dev.isConfigured || dev.detected || (_btConfig && _btConfig.address === dev.address)) {
                    availablePaired = dev
                    break
                }
            }

            if (availablePaired) {
                _autoConnectAttempted = true
                console.log("PulseGCS: Known aircraft available (" + availablePaired.name + "), automatically connecting immediately...")
                connectDevice(availablePaired)
            }
        }
    }

    function _isDeviceConnected(address) {
        if (!address || _connectionState !== PulseGCSAircraft.Connected || !_activeVehicle) {
            return false
        }
        if (_btConfig && _btConfig.address === address) {
            return true
        }
        if (_connectingAddress === address && _connectionState === PulseGCSAircraft.Connected) {
            return true
        }
        return false
    }

    function pairDevice(address) {
        if (!address || !_btConfig) {
            return
        }
        _statusMessage = qsTr("Pairing request sent to %1. Follow the on-screen prompt.").arg(address)
        if (typeof _btConfig.requestPairing === "function") {
            _btConfig.requestPairing(address)
        }
    }

    function unpairDevice(device) {
        if (!device || !device.address || !_btConfig) {
            return
        }

        if (_isDeviceConnected(device.address)) {
            disconnectDevice()
        }

        _statusMessage = qsTr("Unpairing %1...").arg(device.name)
        if (typeof _btConfig.removePairing === "function") {
            _btConfig.removePairing(device.address)
        }

        _unpairedDevicesCache[device.address] = {
            name: device.name,
            rawName: device.rawName,
            address: device.address,
            rssi: device.rssi,
            paired: false,
            isSkyx: device.isSkyx,
            transportType: device.transportType || "bluetooth"
        }

        _refreshDeviceLists()
        if (_isScanAllowed && !_isScanning) {
            startScan()
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
        _userCancelled = false
        _lastFailureDetail = ""
        _statusMessage = qsTr("Connecting to %1...").arg(_connectingDeviceName)

        if (_btConfig) {
            if (typeof _btConfig.setDeviceByAddress === "function") {
                _btConfig.setDeviceByAddress(device.address)
            } else {
                _btConfig.address = device.address
                _btConfig.deviceName = device.name
            }

            _btConfig.dynamic = false
            _btConfig.autoConnect = true

            QGroundControl.linkManager.createConnectedLink(_btConfig)
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
        _reconnectAttempt = 1
        _lostElapsedSeconds = 0

        if (_activeVehicle && typeof _activeVehicle.closeVehicle === "function") {
            _activeVehicle.closeVehicle()
        }

        let linkIsActive = false
        if (_btConfig) {
            console.log("User initiated disconnect: suppressing native reconnect")
            linkIsActive = _btConfig.linkActive
            QGroundControl.linkManager.disconnectLinkConfiguration(_btConfig)
        }

        if (linkIsActive || _activeVehicle !== null) {
            _disconnectPending = true
            disconnectWatchdog.restart()
        } else {
            _finalizeDisconnect()
        }
    }

    function _handleConnectionError(errorMsg) {
        if (_connectionAttemptActive) {
            _connectionAttemptActive = false
            connectionWatchdog.stop()
            _hasConnectionFailed = true
            _hasCancelled = false
            _hasDisconnected = false
            let devName = _connectingDeviceName.length > 0 ? _connectingDeviceName : qsTr("device")
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
        if (_btConfig) {
            console.log("User initiated disconnect: suppressing native reconnect")
            QGroundControl.linkManager.disconnectLinkConfiguration(_btConfig)
        }
        _statusMessage = qsTr("Connection cancelled.")
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
            _handleConnectionError(errorString)
        }

        function onAdapterStateChanged() {
            if (_btConfig && _btConfig.adapterAvailable && _btConfig.adapterPoweredOn && _isScanAllowed && !_isScanning && _discoveredDevices.length === 0) {
                startScan()
            }
        }
    }

    Connections {
        target: _activeLink
        ignoreUnknownSignals: true

        function onCommunicationError(title, error) {
            let msg = (error && error.length > 0) ? error : title
            if (_connectionAttemptActive) {
                _handleConnectionError(msg)
            } else if (_isCommunicationLost || _connectionState === PulseGCSAircraft.Connected) {
                _lastFailureDetail = _humanizeSocketError(msg)
                _statusMessage = qsTr("Link error: %1").arg(_lastFailureDetail)
            }
        }

        function onDisconnected() {
            if (_connectionAttemptActive) {
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
            if (_connectionState === PulseGCSAircraft.ParameterSync) {
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
            visible: _isScanning && _isScanAllowed && !_connectionAttemptActive && !_isCommunicationLost

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
            visible: !_isConnected && _scanTimedOut && !_isScanning && _discoveredDevices.length === 0 && _pairedDevices.length === 0

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

        // Active Connection Handshake Banner
        Rectangle {
            Layout.fillWidth: true
            height: connectingBannerRow.implicitHeight + 16
            radius: PulseGCSTokens.radiusCard
            color: PulseGCSTokens.cardTintBackground(root.isOutdoor)
            border.color: PulseGCSTokens.accentColor(root.isOutdoor)
            border.width: 1
            visible: _connectionAttemptActive && !_isCommunicationLost

            RowLayout {
                id: connectingBannerRow
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
                    color: PulseGCSTokens.accentColor(root.isOutdoor)

                    SequentialAnimation on opacity {
                        running: _connectionAttemptActive
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 500 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 500 }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: _statusMessage.length > 0 ? _statusMessage : qsTr("Connecting to aircraft...")
                        font.pixelSize: 12
                        font.bold: true
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        renderType: Text.QtRendering
                    }

                    PulseGCSProgressBar {
                        Layout.fillWidth: true
                        indeterminate: _connectionState !== PulseGCSAircraft.ParameterSync
                        progress: _discoveryProgress
                        isOutdoor: root.isOutdoor
                    }
                }

                Button {
                    text: qsTr("Cancel")
                    implicitHeight: 28
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
                    return qsTr("Connection cancelled. Attempt stopped by operator.")
                }
                if (_showDisconnectedNotice) {
                    return _lastKnownAircraftName.length > 0
                        ? qsTr("Disconnected from %1. None active.").arg(_lastKnownAircraftName)
                        : qsTr("Aircraft disconnected. None active.")
                }
                return ""
            }
            actionText: _showConnectionError ? qsTr("Retry") : qsTr("Search Again")
            isOutdoor: root.isOutdoor
            onActionClicked: {
                if (_showConnectionError) {
                    retryLastConnection()
                } else if (_isScanAllowed) {
                    startScan()
                }
            }
        }

        // =====================================================================
        // M2-US09: Dedicated Connection Lost / Auto-Reconnecting Card
        // =====================================================================
        Rectangle {
            id: connectionLostCard
            Layout.fillWidth: true
            height: lostRow.implicitHeight + 20
            radius: PulseGCSTokens.radiusCard
            color: PulseGCSTokens.statusBackgroundColor("warn", root.isOutdoor)
            border.color: PulseGCSTokens.statusColor("warn", root.isOutdoor)
            border.width: 1
            visible: _isCommunicationLost

            RowLayout {
                id: lostRow
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    color: PulseGCSTokens.statusColor("warn", root.isOutdoor)

                    SequentialAnimation on opacity {
                        running: root._isCommunicationLost
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.25; duration: 500 }
                        NumberAnimation { from: 0.25; to: 1.0; duration: 500 }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        spacing: 8
                        Text {
                            text: qsTr("CONNECTION LOST")
                            font.pixelSize: 13
                            font.bold: true
                            color: PulseGCSTokens.primaryText(root.isOutdoor)
                            renderType: Text.QtRendering
                        }
                        PulseGCSStatusPill {
                            status: "accentpill"
                            text: qsTr("RECONNECTING · ATTEMPT %1/%2").arg(root._reconnectAttempt).arg(root._maxReconnectAttempts)
                            pulsing: true
                            isOutdoor: root.isOutdoor
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Attempting to reconnect to %1 — last heartbeat %2s ago. Last-known telemetry remains visible.")
                              .arg(root._aircraftDisplayName())
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

                RowLayout {
                    spacing: 8

                    Button {
                        text: qsTr("Retry Now")
                        implicitHeight: 32
                        implicitWidth: Math.max(88, contentItem.implicitWidth + 20)
                        font.pixelSize: 11
                        font.bold: true
                        onClicked: root.retryLastConnection()

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
                                if (_activeVehicle && _activeVehicle.healthAndArmingCheckReport && _activeVehicle.healthAndArmingCheckReport.supported) {
                                    if (!_activeVehicle.healthAndArmingCheckReport.canArm && _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count > 0) return "warn"
                                }
                                return "ok"
                            }
                            text: {
                                if (_connectionState === PulseGCSAircraft.ParameterSync) return qsTr("CHECKING")
                                if (_activeVehicle && _activeVehicle.healthAndArmingCheckReport && _activeVehicle.healthAndArmingCheckReport.supported) {
                                    if (!_activeVehicle.healthAndArmingCheckReport.canArm && _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count > 0) return qsTr("NOT READY")
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
                                let issues = (_activeVehicle && _activeVehicle.healthAndArmingCheckReport && _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode) ? _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count : 0
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
                                if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfig === "function") {
                                    mainWindow.showVehicleConfig()
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
                    visible: !_isConnected && _pairedDevices.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Paired Aircraft (%1)").arg(_pairedDevices.length)
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
                            subtitleText: modelData.address
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
                                unpairDevice(modelData)
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
                    visible: !_isConnected && _discoveredDevices.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Discovered Aircraft (%1)").arg(_discoveredDevices.length)
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
                            isSelected: _connectionAttemptActive && _connectingAddress === modelData.address

                            primaryActionText: (_connectionAttemptActive && _connectingAddress === modelData.address) ? qsTr("Pairing...") : qsTr("Pair")
                            primaryActionEnabled: !_connectionAttemptActive

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
                    visible: !_isConnected && !_isScanning && !_scanTimedOut && _discoveredDevices.length === 0 && _pairedDevices.length === 0

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
