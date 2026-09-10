#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
Q_DECLARE_LOGGING_CATEGORY(PulseGCSStartupLog)

class PulseGCSStartupController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(QString buildNumber READ buildNumber CONSTANT)

public:
    explicit PulseGCSStartupController(QObject *parent = nullptr);
    ~PulseGCSStartupController() override = default;

    static PulseGCSStartupController *instance();

    bool active() const { return _active; }
    void setActive(bool active);
    static QString appVersion();
    static QString buildNumber();

signals:
    void activeChanged(bool active);
    void startupFinished();

private:
    bool _active = false;
};
