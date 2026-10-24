#include "PulseGCSStartupController.h"
#include "QGCLoggingCategory.h"
#include "qgc_version.h"

#include <QtCore/QApplicationStatic>

#if defined(Q_OS_ANDROID)
#include <QtCore/QJniObject>
#include <QtGui/QGuiApplication>
#endif

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

void PulseGCSStartupController::requestPortraitOrientation()
{
#if defined(Q_OS_ANDROID)
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (activity.isValid()) {
        qCDebug(PulseGCSStartupLog) << "Requesting Android PORTRAIT orientation (1)";
        activity.callMethod<void>("setRequestedOrientation", "(I)V", 1);
    }
#else
    qCDebug(PulseGCSStartupLog) << "requestPortraitOrientation (non-Android, no-op)";
#endif
}

void PulseGCSStartupController::requestLandscapeOrientation()
{
#if defined(Q_OS_ANDROID)
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (activity.isValid()) {
        qCDebug(PulseGCSStartupLog) << "Requesting Android SENSOR_LANDSCAPE orientation (6)";
        activity.callMethod<void>("setRequestedOrientation", "(I)V", 6);
    }
#else
    qCDebug(PulseGCSStartupLog) << "requestLandscapeOrientation (non-Android, no-op)";
#endif
}
