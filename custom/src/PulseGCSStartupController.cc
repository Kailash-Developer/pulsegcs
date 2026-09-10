#include "PulseGCSStartupController.h"
#include "QGCLoggingCategory.h"
#include "qgc_version.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QRegularExpression>

#ifndef PULSEGCS_APP_VERSION_STR
#define PULSEGCS_APP_VERSION_STR "0.0.0-M1-US07"
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
    return QStringLiteral(PULSEGCS_APP_VERSION_STR);
}

QString PulseGCSStartupController::buildNumber()
{
    static const QRegularExpression gitDescribeBuild(QStringLiteral("-([0-9]+)-g[0-9a-f]+$"));
    const QRegularExpressionMatch match = gitDescribeBuild.match(QStringLiteral(QGC_APP_VERSION_STR));
    if (match.hasMatch()) {
        return match.captured(1);
    }
    return QStringLiteral(QGC_APP_DATE).left(10);
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
