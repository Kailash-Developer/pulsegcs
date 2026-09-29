#pragma once

#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QString>
#include <QtQmlIntegration/QtQmlIntegration>

#include "PulseGCSAircraftContract.h"

class Vehicle;

class PulseGCSAircraftInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("uncreatable type")
    Q_MOC_INCLUDE("Vehicle.h")

    Q_PROPERTY(int                                systemId            READ systemId            CONSTANT)
    Q_PROPERTY(QString                            firmwareId          READ firmwareId           NOTIFY firmwareIdChanged)
    Q_PROPERTY(QString                            model               READ model                NOTIFY modelChanged)
    Q_PROPERTY(QString                            applicationVersion  READ applicationVersion   NOTIFY applicationVersionChanged)
    Q_PROPERTY(QString                            serialNumber        READ serialNumber          NOTIFY serialNumberChanged)
    Q_PROPERTY(double                             discoveryProgress   READ discoveryProgress     NOTIFY discoveryProgressChanged)
    Q_PROPERTY(PulseGCS::ConnectionState          connectionState     READ connectionState       NOTIFY connectionStateChanged)
    Q_PROPERTY(PulseGCS::TelemetryClassification  classification      READ classification        NOTIFY classificationChanged)
    Q_PROPERTY(bool                               isSkyx              READ isSkyx               NOTIFY isSkyxChanged)
    Q_PROPERTY(bool                               isDuplicateIdentity READ isDuplicateIdentity  NOTIFY isDuplicateIdentityChanged)
    Q_PROPERTY(bool                               communicationLost   READ communicationLost    NOTIFY communicationLostChanged)
    Q_PROPERTY(Vehicle*                           vehicle             READ vehicle             CONSTANT)

public:
    explicit PulseGCSAircraftInfo(Vehicle *vehicle, QObject *parent = nullptr);
    ~PulseGCSAircraftInfo() override;

    int systemId() const { return _systemId; }
    QString firmwareId() const { return _firmwareId; }
    QString model() const { return _model; }
    QString applicationVersion() const { return _applicationVersion; }
    QString serialNumber() const { return _serialNumber; }
    double discoveryProgress() const { return _discoveryProgress; }
    PulseGCS::ConnectionState connectionState() const { return _connectionState; }
    PulseGCS::TelemetryClassification classification() const { return _classification; }
    bool isSkyx() const { return _isSkyx; }
    bool isDuplicateIdentity() const { return _isDuplicateIdentity; }
    bool communicationLost() const { return _communicationLost; }
    Vehicle *vehicle() const;

    void connectSignals();
    void setDuplicateIdentity(bool duplicate);
    void restoreConnectionState();

signals:
    void firmwareIdChanged(const QString &firmwareId);
    void modelChanged(const QString &model);
    void applicationVersionChanged(const QString &applicationVersion);
    void serialNumberChanged(const QString &serialNumber);
    void discoveryProgressChanged(double discoveryProgress);
    void connectionStateChanged(PulseGCS::ConnectionState connectionState);
    void classificationChanged(PulseGCS::TelemetryClassification classification);
    void isSkyxChanged(bool isSkyx);
    void isDuplicateIdentityChanged(bool isDuplicateIdentity);
    void communicationLostChanged(bool communicationLost);

private slots:
    void _onAllLinksRemoved(Vehicle *vehicle);
    void _onFirmwareTypeChanged();
    void _onVehicleTypeChanged();
    void _onFirmwareVersionChanged();
    void _onVehicleUIDChanged();
    void _onInitialConnectComplete();
    void _onCommunicationLostChanged(bool communicationLost);
    void _onParameterManagerLoadProgressChanged(float value);

private:
    void _setConnectionState(PulseGCS::ConnectionState newState);
    void _updateClassification();

    QPointer<Vehicle> _vehicle;
    int _systemId = 0;
    QString _firmwareId;
    QString _model = QStringLiteral("Unknown");
    QString _applicationVersion = QStringLiteral("Unknown");
    QString _serialNumber = QStringLiteral("Unknown");
    double _discoveryProgress = 0.0;
    PulseGCS::ConnectionState _connectionState = PulseGCS::ConnectionState::Searching;
    PulseGCS::TelemetryClassification _classification = PulseGCS::TelemetryClassification::Unknown;
    bool _isSkyx = false;
    bool _isDuplicateIdentity = false;
    bool _communicationLost = false;
    bool _hasEstablishedSession = false;
};
