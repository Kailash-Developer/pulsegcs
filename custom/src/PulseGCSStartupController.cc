#include "PulseGCSStartupController.h"
#include "QGCLoggingCategory.h"
#include "qgc_version.h"

#include <QtCore/QApplicationStatic>

#ifndef PULSEGCS_BUILD_NUMBER
#define PULSEGCS_BUILD_NUMBER "0"
#endif

QGC_LOGGING_CATEGORY(PulseGCSStartupLog, "PulseGCS.StartupController")

Q_APPLICATION_STATIC(PulseGCSStartupController, _startupControllerInstance);

PulseGCSStartupController::PulseGCSStartupController(QObject *parent)
    : QObject(parent)
{
    qCDebug(PulseGCSStartupLog) << "PulseGCSStartupController initialized";
}

PulseGCSStartupController *PulseGCSStartupController::instance()
{
    return _startupControllerInstance();
}

QString PulseGCSStartupController::appVersion()
{
    return QStringLiteral(QGC_APP_VERSION_STR);
}

QString PulseGCSStartupController::buildNumber()
{
    return QStringLiteral(PULSEGCS_BUILD_NUMBER);
}

void PulseGCSStartupController::setActive(bool active)
{
    if (_active == active) {
        qCDebug(PulseGCSStartupLog) << "setActive unchanged =" << _active;
        return;
    }

    _active = active;
    qCDebug(PulseGCSStartupLog) << "active changed to:" << _active;
    emit activeChanged(_active);
    if (!_active) {
        qCDebug(PulseGCSStartupLog) << "emitting startupFinished";
        emit startupFinished();
    }
}
