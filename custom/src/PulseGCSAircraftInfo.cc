#include "PulseGCSAircraftInfo.h"
#include "PulseGCSAircraftContract.h"

#include "ParameterManager.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

QGC_LOGGING_CATEGORY(PulseGCSAircraftLog, "PulseGCS.Aircraft")

PulseGCSAircraftInfo::PulseGCSAircraftInfo(Vehicle *vehicle, QObject *parent)
    : QObject(parent)
    , _vehicle(vehicle)
    , _systemId(vehicle ? vehicle->id() : 0)
    , _firmwareId(vehicle ? vehicle->firmwareTypeString() : QStringLiteral("Unknown"))
    , _model(vehicle ? vehicle->vehicleTypeString() : QStringLiteral("Unknown"))
    , _serialNumber(vehicle ? vehicle->vehicleUIDStr() : QStringLiteral("Unknown"))
{
    if (_vehicle && _vehicle->firmwareMajorVersion() > 0) {
        _applicationVersion = QStringLiteral("%1.%2.%3")
            .arg(_vehicle->firmwareMajorVersion())
            .arg(_vehicle->firmwareMinorVersion())
            .arg(_vehicle->firmwarePatchVersion());
    }

    _updateClassification();

    qCDebug(PulseGCSAircraftLog) << "created for systemId:" << _systemId
                                << "firmware:" << _firmwareId
                                << "model:" << _model
                                << "isSkyx:" << _isSkyx;
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
}

PulseGCSAircraftInfo::~PulseGCSAircraftInfo()
{
    qCDebug(PulseGCSAircraftLog) << "destroyed for systemId:" << _systemId;
}

Vehicle *PulseGCSAircraftInfo::vehicle() const
{
    return _vehicle.data();
}

void PulseGCSAircraftInfo::connectSignals()
{
    if (!_vehicle) {
        return;
    }

    // Vehicle link lifecycle — allLinksRemoved lives on VehicleLinkManager.
    VehicleLinkManager *const vlm = _vehicle->vehicleLinkManager();
    if (vlm) {
        connect(vlm, &VehicleLinkManager::allLinksRemoved,
                this, &PulseGCSAircraftInfo::_onAllLinksRemoved);
        connect(vlm, &VehicleLinkManager::communicationLostChanged,
                this, &PulseGCSAircraftInfo::_onCommunicationLostChanged);
    }

    // Identity signals on Vehicle.
    connect(_vehicle, &Vehicle::firmwareTypeChanged,    this, &PulseGCSAircraftInfo::_onFirmwareTypeChanged);
    connect(_vehicle, &Vehicle::vehicleTypeChanged,     this, &PulseGCSAircraftInfo::_onVehicleTypeChanged);
    connect(_vehicle, &Vehicle::firmwareVersionChanged, this, &PulseGCSAircraftInfo::_onFirmwareVersionChanged);
    connect(_vehicle, &Vehicle::vehicleUIDChanged,      this, &PulseGCSAircraftInfo::_onVehicleUIDChanged);

    // Parameter synchronization lifecycle.
    ParameterManager *const pm = _vehicle->parameterManager();
    if (pm) {
        connect(pm, &ParameterManager::loadProgressChanged,
                this, &PulseGCSAircraftInfo::_onParameterManagerLoadProgressChanged);
        connect(pm, &ParameterManager::parametersReadyChanged, this, [this](bool ready) {
            if (!_vehicle) {
                return;
            }
            if (ready) {
                qCDebug(PulseGCSAircraftLog) << "parametersReady for systemId:" << _systemId;
                _discoveryProgress = 1.0;
                emit discoveryProgressChanged(_discoveryProgress);
                if (!_isDuplicateIdentity && !_communicationLost) {
                    _setConnectionState(PulseGCS::ConnectionState::Connected);
                }
            }
        });
    }

    // Connection lifecycle — initialConnectComplete acts as a fallback completion trigger.
    connect(_vehicle, &Vehicle::initialConnectComplete, this, &PulseGCSAircraftInfo::_onInitialConnectComplete);

    // Synchronize initial connection state based on current parameter manager state.
    if (pm && pm->parametersReady()) {
        _discoveryProgress = 1.0;
        _setConnectionState(PulseGCS::ConnectionState::Connected);
    } else if (pm && pm->loadProgress() > 0.0f) {
        _discoveryProgress = static_cast<double>(pm->loadProgress());
        _setConnectionState(PulseGCS::ConnectionState::ParameterSync);
    } else {
        _setConnectionState(PulseGCS::ConnectionState::Connecting);
    }

    _updateClassification();
}

void PulseGCSAircraftInfo::setDuplicateIdentity(bool duplicate)
{
    if (_isDuplicateIdentity == duplicate) {
        return;
    }
    _isDuplicateIdentity = duplicate;
    emit isDuplicateIdentityChanged(_isDuplicateIdentity);
    qCDebug(PulseGCSAircraftLog) << "systemId:" << _systemId << "duplicate identity set to:" << duplicate;

    if (_isDuplicateIdentity) {
        _setConnectionState(PulseGCS::ConnectionState::IdentityConflict);
    } else {
        restoreConnectionState();
    }
}

void PulseGCSAircraftInfo::restoreConnectionState()
{
    if (_isDuplicateIdentity) {
        _setConnectionState(PulseGCS::ConnectionState::IdentityConflict);
        return;
    }
    if (!_vehicle) {
        _setConnectionState(PulseGCS::ConnectionState::Disconnected);
        return;
    }
    if (_communicationLost && (_hasEstablishedSession || _connectionState == PulseGCS::ConnectionState::ParameterSync)) {
        _setConnectionState(PulseGCS::ConnectionState::CommunicationLost);
        return;
    }

    ParameterManager *const pm = _vehicle->parameterManager();
    if (pm && pm->parametersReady()) {
        _discoveryProgress = 1.0;
        emit discoveryProgressChanged(_discoveryProgress);
        _setConnectionState(PulseGCS::ConnectionState::Connected);
        return;
    }
    if (pm && pm->loadProgress() > 0.0f) {
        _discoveryProgress = static_cast<double>(pm->loadProgress());
        emit discoveryProgressChanged(_discoveryProgress);
        _setConnectionState(PulseGCS::ConnectionState::ParameterSync);
        return;
    }

    _setConnectionState(PulseGCS::ConnectionState::Connecting);
}

void PulseGCSAircraftInfo::_onAllLinksRemoved(Vehicle *vehicle)
{
    if (vehicle != _vehicle) {
        return;
    }
    qCDebug(PulseGCSAircraftLog) << "allLinksRemoved for systemId:" << _systemId;
    _vehicle = nullptr;
    _communicationLost = false;
    _hasEstablishedSession = false;
    emit communicationLostChanged(false);
    _setConnectionState(PulseGCS::ConnectionState::Disconnected);
}

void PulseGCSAircraftInfo::_onFirmwareTypeChanged()
{
    if (!_vehicle) {
        return;
    }
    const QString newFirmwareId = _vehicle->firmwareTypeString();
    if (_firmwareId != newFirmwareId) {
        qCDebug(PulseGCSAircraftLog) << "firmwareId changed to:" << newFirmwareId;
        _firmwareId = newFirmwareId;
        emit firmwareIdChanged(_firmwareId);
        _updateClassification();
    }
}

void PulseGCSAircraftInfo::_onVehicleTypeChanged()
{
    if (!_vehicle) {
        return;
    }
    const QString newModel = _vehicle->vehicleTypeString();
    if (_model != newModel) {
        qCDebug(PulseGCSAircraftLog) << "model changed to:" << newModel;
        _model = newModel;
        emit modelChanged(_model);
        _updateClassification();
    }
}

void PulseGCSAircraftInfo::_onFirmwareVersionChanged()
{
    if (!_vehicle) {
        return;
    }
    if (_vehicle->firmwareMajorVersion() <= 0) {
        return;
    }
    const QString newVersion = QStringLiteral("%1.%2.%3")
        .arg(_vehicle->firmwareMajorVersion())
        .arg(_vehicle->firmwareMinorVersion())
        .arg(_vehicle->firmwarePatchVersion());
    if (_applicationVersion != newVersion) {
        qCDebug(PulseGCSAircraftLog) << "applicationVersion changed to:" << newVersion;
        _applicationVersion = newVersion;
        emit applicationVersionChanged(_applicationVersion);
        _updateClassification();
    }
}

void PulseGCSAircraftInfo::_onVehicleUIDChanged()
{
    if (!_vehicle) {
        return;
    }
    const QString newSerial = _vehicle->vehicleUIDStr();
    if (_serialNumber != newSerial) {
        qCDebug(PulseGCSAircraftLog) << "serialNumber changed to:" << newSerial;
        _serialNumber = newSerial;
        emit serialNumberChanged(_serialNumber);
        _updateClassification();
    }
}

void PulseGCSAircraftInfo::_onInitialConnectComplete()
{
    if (!_vehicle) {
        return;
    }
    qCDebug(PulseGCSAircraftLog) << "initialConnectComplete for systemId:" << _systemId;
    if (!_isDuplicateIdentity && !_communicationLost && _connectionState != PulseGCS::ConnectionState::Connected) {
        _discoveryProgress = 1.0;
        emit discoveryProgressChanged(_discoveryProgress);
        _setConnectionState(PulseGCS::ConnectionState::Connected);
    }
}

void PulseGCSAircraftInfo::_onCommunicationLostChanged(bool communicationLost)
{
    if (!_vehicle) {
        return;
    }
    if (_communicationLost == communicationLost) {
        return;
    }
    _communicationLost = communicationLost;
    emit communicationLostChanged(_communicationLost);
    qCDebug(PulseGCSAircraftLog) << "communicationLost changed to:" << _communicationLost
                                << "for systemId:" << _systemId;

    if (_isDuplicateIdentity) {
        return;
    }

    if (_communicationLost) {
        if (_hasEstablishedSession || _connectionState == PulseGCS::ConnectionState::ParameterSync) {
            _setConnectionState(PulseGCS::ConnectionState::CommunicationLost);
        }
    } else {
        restoreConnectionState();
    }
}

void PulseGCSAircraftInfo::_onParameterManagerLoadProgressChanged(float value)
{
    const double progress = static_cast<double>(value);
    if (qFuzzyCompare(_discoveryProgress, progress)) {
        return;
    }
    _discoveryProgress = progress;
    emit discoveryProgressChanged(_discoveryProgress);

    if (!_isDuplicateIdentity && !_communicationLost) {
        if (_connectionState == PulseGCS::ConnectionState::Connecting && progress > 0.0) {
            _setConnectionState(PulseGCS::ConnectionState::ParameterSync);
        }
    }
}

void PulseGCSAircraftInfo::_setConnectionState(PulseGCS::ConnectionState newState)
{
    if (_connectionState == newState) {
        return;
    }
    qCDebug(PulseGCSAircraftLog) << "systemId:" << _systemId << "connectionState:"
                                << static_cast<int>(_connectionState)
                                << "->" << static_cast<int>(newState);
    if (newState == PulseGCS::ConnectionState::Connected) {
        _hasEstablishedSession = true;
    } else if (newState == PulseGCS::ConnectionState::Disconnected ||
               newState == PulseGCS::ConnectionState::InitialFailed) {
        _hasEstablishedSession = false;
    }
    _connectionState = newState;
    emit connectionStateChanged(_connectionState);
}

void PulseGCSAircraftInfo::_updateClassification()
{
    // Layer B classification: Non-invasive classification of discovered vehicles into SKYX vs Non-SKYX
    QString cleanSerial = _serialNumber;
    cleanSerial.remove(QLatin1Char(':')).remove(QLatin1Char('-')).remove(QLatin1Char(' '));
    const bool skyxCandidate = _serialNumber.contains(QLatin1String(PulseGCS::kSkyxSerialMarker))
        || cleanSerial.contains(QLatin1String(PulseGCS::kSkyxSerialMarker));

    if (_isSkyx != skyxCandidate) {
        _isSkyx = skyxCandidate;
        emit isSkyxChanged(_isSkyx);
        qCDebug(PulseGCSAircraftLog) << "systemId:" << _systemId << "isSkyx changed to:" << _isSkyx;
    }

    // TelemetryClassification::Available requires all identity fields populated.
    const bool available = (_systemId != 0)
        && !_firmwareId.isEmpty()
        && (_firmwareId != QStringLiteral("Unknown"))
        && (_model != QStringLiteral("Unknown"))
        && (_applicationVersion != QStringLiteral("Unknown"));

    const PulseGCS::TelemetryClassification newClass = available
        ? PulseGCS::TelemetryClassification::Available
        : PulseGCS::TelemetryClassification::Unknown;

    if (_classification != newClass) {
        qCDebug(PulseGCSAircraftLog) << "systemId:" << _systemId << "classification:"
                                    << static_cast<int>(_classification)
                                    << "->" << static_cast<int>(newClass);
        _classification = newClass;
        emit classificationChanged(_classification);
    }
}
