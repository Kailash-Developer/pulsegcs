#include "PulseGCSAircraftManager.h"
#include "PulseGCSAircraftInfo.h"

#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#include "QmlObjectListModel.h"
#include "Vehicle.h"

#include <QtCore/QApplicationStatic>

QGC_LOGGING_CATEGORY(PulseGCSAircraftManagerLog, "PulseGCS.AircraftManager")

Q_APPLICATION_STATIC(PulseGCSAircraftManager, _aircraftManagerInstance);

PulseGCSAircraftManager::PulseGCSAircraftManager(QObject *parent)
    : QObject(parent)
    , _aircraftListModel(new QmlObjectListModel(this))
{
    qCDebug(PulseGCSAircraftManagerLog) << "PulseGCSAircraftManager initialized";

    MultiVehicleManager *const mvm = MultiVehicleManager::instance();
    if (mvm) {
        connect(mvm, &MultiVehicleManager::vehicleAdded,   this, &PulseGCSAircraftManager::_onVehicleAdded);
        connect(mvm, &MultiVehicleManager::vehicleRemoved, this, &PulseGCSAircraftManager::_onVehicleRemoved);
        connect(mvm, &MultiVehicleManager::activeVehicleChanged,
                this, &PulseGCSAircraftManager::_onActiveVehicleChanged);

        QmlObjectListModel *const existing = mvm->vehicles();
        if (existing) {
            const int count = existing->count();
            for (int i = 0; i < count; ++i) {
                auto *vehicle = existing->value<Vehicle *>(i);
                if (vehicle) {
                    _onVehicleAdded(vehicle);
                }
            }
        }

        _onActiveVehicleChanged(mvm->activeVehicle());
    }
}

PulseGCSAircraftManager::~PulseGCSAircraftManager()
{
    qCDebug(PulseGCSAircraftManagerLog) << "PulseGCSAircraftManager destroyed;"
                                        << _aircraftInfoMap.size() << "entries cleared";
    if (_aircraftListModel) {
        _aircraftListModel->clear();
    }
    qDeleteAll(_aircraftInfoMap);
    _aircraftInfoMap.clear();
}

/*static*/
PulseGCSAircraftManager *PulseGCSAircraftManager::instance()
{
    return _aircraftManagerInstance();
}

PulseGCSAircraftInfo *PulseGCSAircraftManager::aircraftInfoForId(int systemId) const
{
    return _aircraftInfoMap.value(systemId, nullptr);
}

void PulseGCSAircraftManager::_onVehicleAdded(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }
    const int systemId = vehicle->id();
    if (_aircraftInfoMap.contains(systemId)) {
        qCWarning(PulseGCSAircraftManagerLog) << "vehicleAdded for already-tracked systemId:" << systemId;
        return;
    }

    auto *info = new PulseGCSAircraftInfo(vehicle, this);
    info->connectSignals();
    connect(info, &PulseGCSAircraftInfo::serialNumberChanged,
            this, &PulseGCSAircraftManager::_checkDuplicateIdentities);

    _aircraftInfoMap.insert(systemId, info);
    if (_aircraftListModel) {
        _aircraftListModel->append(info);
    }

    qCDebug(PulseGCSAircraftManagerLog) << "aircraft added for systemId:" << systemId
                                        << "total aircraft:" << _aircraftInfoMap.size();

    emit aircraftAdded(info);
    emit aircraftCountChanged(_aircraftInfoMap.size());

    _checkDuplicateIdentities();

    MultiVehicleManager *const mvm = MultiVehicleManager::instance();
    if (mvm && mvm->activeVehicle() == vehicle) {
        _setActiveAircraftInfo(info);
    }
}

void PulseGCSAircraftManager::_onVehicleRemoved(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }
    const int systemId = vehicle->id();
    PulseGCSAircraftInfo *const info = _aircraftInfoMap.take(systemId);
    if (!info) {
        qCWarning(PulseGCSAircraftManagerLog) << "vehicleRemoved for unknown systemId:" << systemId;
        return;
    }

    if (_aircraftListModel) {
        _aircraftListModel->removeOne(info);
    }

    qCDebug(PulseGCSAircraftManagerLog) << "aircraft removed for systemId:" << systemId
                                        << "remaining aircraft:" << _aircraftInfoMap.size();

    emit aircraftRemoved(systemId);
    emit aircraftCountChanged(_aircraftInfoMap.size());

    if (_activeAircraftInfo == info) {
        _setActiveAircraftInfo(nullptr);
    }

    _checkDuplicateIdentities();
    info->deleteLater();
}

void PulseGCSAircraftManager::_onActiveVehicleChanged(Vehicle *vehicle)
{
    if (!vehicle) {
        _setActiveAircraftInfo(nullptr);
        return;
    }
    _setActiveAircraftInfo(_aircraftInfoMap.value(vehicle->id(), nullptr));
}

void PulseGCSAircraftManager::_checkDuplicateIdentities()
{
    QMap<QString, int> serialCounts;
    for (auto *info : _aircraftInfoMap) {
        if (!info) {
            continue;
        }
        const QString &sn = info->serialNumber();
        if (!sn.isEmpty() && sn != QStringLiteral("Unknown") && sn != QStringLiteral("0")) {
            serialCounts[sn]++;
        }
    }

    for (auto *info : _aircraftInfoMap) {
        if (!info) {
            continue;
        }
        const QString &sn = info->serialNumber();
        const bool isDup = (!sn.isEmpty()
            && sn != QStringLiteral("Unknown")
            && sn != QStringLiteral("0")
            && serialCounts.value(sn, 0) > 1);

        info->setDuplicateIdentity(isDup);
    }
}

void PulseGCSAircraftManager::_setActiveAircraftInfo(PulseGCSAircraftInfo *info)
{
    if (_activeAircraftInfo == info) {
        return;
    }
    qCDebug(PulseGCSAircraftManagerLog) << "activeAircraftInfo ->"
                                        << (info ? info->systemId() : -1);
    _activeAircraftInfo = info;
    emit activeAircraftInfoChanged(_activeAircraftInfo);
}
