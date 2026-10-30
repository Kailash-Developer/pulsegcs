#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QPointer>

class LogReplayLink;
#ifdef QT_DEBUG
class MockLink;
#endif

Q_DECLARE_LOGGING_CATEGORY(PulseGCSStartupLog)

class PulseGCSStartupController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(QString buildNumber READ buildNumber CONSTANT)
    Q_PROPERTY(bool isDemoSimulationActive READ isDemoSimulationActive NOTIFY demoSimulationActiveChanged)

public:
    explicit PulseGCSStartupController(QObject *parent = nullptr);
    ~PulseGCSStartupController() override = default;

    static PulseGCSStartupController *instance();

    bool active() const { return _active; }
    void setActive(bool active);
    static QString appVersion();
    static QString buildNumber();

    bool isDemoSimulationActive() const;
    Q_INVOKABLE bool startDemoSimulation();
    Q_INVOKABLE void stopDemoSimulation();
    Q_INVOKABLE QString demoMissionPlanPath();

    Q_INVOKABLE void requestPortraitOrientation();
    Q_INVOKABLE void requestLandscapeOrientation();
    Q_INVOKABLE void copyToClipboard(const QString &text);

    // M3-US08 / M3-US01 / M3-US04: Persistent 7-Day Session Vault & Device Identity
    Q_INVOKABLE void saveSession(const QString &email, const QString &token, int validDays = 7);
    Q_INVOKABLE QVariantMap loadSession();
    Q_INVOKABLE void clearSession();
    Q_INVOKABLE QString deviceId();

signals:
    void activeChanged(bool active);
    void startupFinished();
    void demoSimulationActiveChanged(bool active);

private:
    bool _active = false;
    QPointer<LogReplayLink> _demoReplayLink;
#ifdef QT_DEBUG
    QPointer<MockLink> _demoMockLink;
#endif
};
