#pragma once

#include <QtCore/QMap>
#include <QtCore/QObject>
#include <QtQmlIntegration/QtQmlIntegration>

#include "PulseGCSAircraftContract.h"

class PulseGCSAircraftInfo;
class Vehicle;
class QmlObjectListModel;

Q_DECLARE_LOGGING_CATEGORY(PulseGCSAircraftManagerLog)

class PulseGCSAircraftManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("uncreatable type")
    Q_MOC_INCLUDE("PulseGCSAircraftInfo.h")
    Q_MOC_INCLUDE("Vehicle.h")
    Q_MOC_INCLUDE("QmlObjectListModel.h")

    Q_PROPERTY(PulseGCSAircraftInfo *activeAircraftInfo READ activeAircraftInfo NOTIFY activeAircraftInfoChanged)
    Q_PROPERTY(QmlObjectListModel   *aircraftList       READ aircraftList       CONSTANT)
    Q_PROPERTY(int                   aircraftCount      READ aircraftCount      NOTIFY aircraftCountChanged)

public:
    explicit PulseGCSAircraftManager(QObject *parent = nullptr);
    ~PulseGCSAircraftManager() override;

    static PulseGCSAircraftManager *instance();

    PulseGCSAircraftInfo *activeAircraftInfo() const { return _activeAircraftInfo; }
    QmlObjectListModel *aircraftList() const { return _aircraftListModel; }
    int aircraftCount() const { return _aircraftInfoMap.size(); }
    PulseGCSAircraftInfo *aircraftInfoForId(int systemId) const;

signals:
    void activeAircraftInfoChanged(PulseGCSAircraftInfo *activeAircraftInfo);
    void aircraftCountChanged(int aircraftCount);
    void aircraftAdded(PulseGCSAircraftInfo *aircraftInfo);
    void aircraftRemoved(int systemId);

private slots:
    void _onVehicleAdded(Vehicle *vehicle);
    void _onVehicleRemoved(Vehicle *vehicle);
    void _onActiveVehicleChanged(Vehicle *vehicle);
    void _checkDuplicateIdentities();

private:
    void _setActiveAircraftInfo(PulseGCSAircraftInfo *info);

    QMap<int, PulseGCSAircraftInfo *> _aircraftInfoMap;
    QmlObjectListModel *_aircraftListModel = nullptr;
    PulseGCSAircraftInfo *_activeAircraftInfo = nullptr;
};
