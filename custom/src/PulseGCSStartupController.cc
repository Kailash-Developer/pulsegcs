#include "PulseGCSStartupController.h"
#include "QGCLoggingCategory.h"
#include "qgc_version.h"
#include "LinkManager.h"
#include "LogReplayLink.h"

#ifdef QT_DEBUG
#include "MockLink.h"
#include "MockConfiguration.h"
#endif

#include <QtCore/QApplicationStatic>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtCore/QSysInfo>
#include <QtCore/QUuid>
#include <QtGui/QClipboard>
#include <QtGui/QGuiApplication>

#if defined(Q_OS_ANDROID)
#include <QtCore/QJniObject>
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

bool PulseGCSStartupController::isDemoSimulationActive() const
{
    if (_demoReplayLink && _demoReplayLink->isConnected()) {
        return true;
    }
#ifdef QT_DEBUG
    return _demoMockLink != nullptr && _demoMockLink->isConnected();
#else
    return false;
#endif
}

bool PulseGCSStartupController::startDemoSimulation()
{
    if (isDemoSimulationActive()) {
        qCDebug(PulseGCSStartupLog) << "PulseGCS: Demo simulation already active";
        return true;
    }

    // 1. Copy bundled demo flight tlog and demo mission plan from Qt Resource to writable AppData directory if needed
    const QString resourcePath = QStringLiteral(":/Custom/telemetry/demo_flight.tlog");
    const QString planResourcePath = QStringLiteral(":/Custom/telemetry/demo_mission.plan");
    const QString targetDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(targetDir);
    const QString targetFile = targetDir + QStringLiteral("/demo_flight.tlog");
    const QString targetPlanFile = targetDir + QStringLiteral("/demo_mission.plan");

    QFile::remove(targetFile); // Refresh fresh copy
    if (QFile::copy(resourcePath, targetFile)) {
        qCDebug(PulseGCSStartupLog) << "PulseGCS: Extracted bundled demo flight log to:" << targetFile;
    } else if (!QFile::exists(targetFile)) {
        qCWarning(PulseGCSStartupLog) << "PulseGCS: Failed to extract demo flight log from resource:" << resourcePath;
    }

    QFile::remove(targetPlanFile); // Refresh fresh copy
    if (QFile::copy(planResourcePath, targetPlanFile)) {
        qCDebug(PulseGCSStartupLog) << "PulseGCS: Extracted bundled demo mission plan to:" << targetPlanFile;
    } else if (!QFile::exists(targetPlanFile)) {
        const QString repoPlan = QStringLiteral("custom/resources/telemetry/demo_mission.plan");
        if (QFile::exists(repoPlan)) {
            QFile::copy(repoPlan, targetPlanFile);
            qCDebug(PulseGCSStartupLog) << "PulseGCS: Copied demo mission plan from repo to:" << targetPlanFile;
        } else {
            qCWarning(PulseGCSStartupLog) << "PulseGCS: Failed to extract demo mission plan from resource:" << planResourcePath;
        }
    }

    // 2. Start native LogReplayLink with bundled flight log
    if (QFile::exists(targetFile)) {
        qCDebug(PulseGCSStartupLog) << "PulseGCS: Starting native LogReplayLink with:" << targetFile;
        _demoReplayLink = LinkManager::instance()->startLogReplay(targetFile);
        if (_demoReplayLink) {
            _demoReplayLink->play();
            connect(_demoReplayLink, &LogReplayLink::playbackAtEnd, this, [this]() {
                if (_demoReplayLink && isDemoSimulationActive()) {
                    qCDebug(PulseGCSStartupLog) << "PulseGCS: Demo playback reached end, looping from beginning";
                    _demoReplayLink->movePlayhead(0.0);
                    _demoReplayLink->play();
                }
            });
            emit demoSimulationActiveChanged(true);
            qCDebug(PulseGCSStartupLog) << "PulseGCS: Native LogReplayLink successfully started & playing";
            return true;
        }
        qCWarning(PulseGCSStartupLog) << "PulseGCS: LinkManager failed to start LogReplayLink";
    }

#ifdef QT_DEBUG
    qCDebug(PulseGCSStartupLog) << "PulseGCS: Falling back to APM ArduCopter MockLink for Debug build";
    _demoMockLink = MockLink::startAPMArduCopterMockLink(MockConfiguration::OptionSendStatusText);
    const bool success = (_demoMockLink != nullptr);
    if (success) {
        emit demoSimulationActiveChanged(true);
        qCDebug(PulseGCSStartupLog) << "PulseGCS: Demo simulation MockLink started successfully";
    } else {
        qCWarning(PulseGCSStartupLog) << "PulseGCS: Failed to start Demo MockLink";
    }
    return success;
#else
    return false;
#endif
}

void PulseGCSStartupController::stopDemoSimulation()
{
    if (_demoReplayLink) {
        qCDebug(PulseGCSStartupLog) << "PulseGCS: Stopping Demo LogReplayLink";
        LinkManager::instance()->disconnectLink(_demoReplayLink.data());
        _demoReplayLink.clear();
        emit demoSimulationActiveChanged(false);
    }

#ifdef QT_DEBUG
    if (_demoMockLink) {
        qCDebug(PulseGCSStartupLog) << "PulseGCS: Stopping Demo MockLink";
        LinkManager::instance()->disconnectLink(_demoMockLink.data());
        _demoMockLink.clear();
        emit demoSimulationActiveChanged(false);
    }
#endif
}

QString PulseGCSStartupController::demoMissionPlanPath()
{
    const QString targetDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(targetDir);
    const QString targetPlanFile = targetDir + QStringLiteral("/demo_mission.plan");

    const QString planResourcePath = QStringLiteral(":/Custom/telemetry/demo_mission.plan");
    if (QFile::exists(planResourcePath)) {
        if (!QFile::exists(targetPlanFile)) {
            QFile::copy(planResourcePath, targetPlanFile);
        }
        if (QFile::exists(targetPlanFile)) {
            return targetPlanFile;
        }
        return planResourcePath;
    }

    if (QFile::exists(targetPlanFile)) {
        return targetPlanFile;
    }

    const QString repoPlan = QStringLiteral("custom/resources/telemetry/demo_mission.plan");
    if (QFile::exists(repoPlan)) {
        return QFileInfo(repoPlan).absoluteFilePath();
    }

    return targetPlanFile;
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

void PulseGCSStartupController::copyToClipboard(const QString &text)
{
    if (QClipboard *clipboard = QGuiApplication::clipboard()) {
        clipboard->setText(text);
        qCDebug(PulseGCSStartupLog) << "Copied to clipboard:" << text;
    }
}

void PulseGCSStartupController::saveSession(const QString &email, const QString &token, int validDays)
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PulseGCSAuth"));
    settings.setValue(QStringLiteral("email"), email.trimmed());
    settings.setValue(QStringLiteral("token"), token);
    const QDateTime expiresAt = QDateTime::currentDateTimeUtc().addDays(validDays);
    settings.setValue(QStringLiteral("expiresAt"), expiresAt.toString(Qt::ISODate));
    settings.endGroup();
    qCDebug(PulseGCSStartupLog) << "PulseGCS: Saved 7-day session for" << email << "expiring at" << expiresAt;
}

QVariantMap PulseGCSStartupController::loadSession()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PulseGCSAuth"));
    const QString email = settings.value(QStringLiteral("email")).toString();
    const QString token = settings.value(QStringLiteral("token")).toString();
    const QString expiresStr = settings.value(QStringLiteral("expiresAt")).toString();
    settings.endGroup();

    QVariantMap res;
    res[QStringLiteral("hasSession")] = false;
    res[QStringLiteral("active")] = false;
    res[QStringLiteral("expired")] = false;
    res[QStringLiteral("email")] = email;
    res[QStringLiteral("token")] = token;
    res[QStringLiteral("expiresAt")] = expiresStr;

    if (email.isEmpty() || token.isEmpty() || expiresStr.isEmpty()) {
        return res;
    }

    res[QStringLiteral("hasSession")] = true;
    const QDateTime expiresAt = QDateTime::fromString(expiresStr, Qt::ISODate);
    if (!expiresAt.isValid()) {
        return res;
    }

    if (QDateTime::currentDateTimeUtc() < expiresAt) {
        res[QStringLiteral("active")] = true;
    } else {
        res[QStringLiteral("expired")] = true;
    }
    return res;
}

void PulseGCSStartupController::clearSession()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PulseGCSAuth"));
    settings.remove(QStringLiteral("email"));
    settings.remove(QStringLiteral("token"));
    settings.remove(QStringLiteral("expiresAt"));
    settings.endGroup();
    qCDebug(PulseGCSStartupLog) << "PulseGCS: Cleared stored session from QSettings";
}

QString PulseGCSStartupController::deviceId()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PulseGCSAuth"));
    QString devId = settings.value(QStringLiteral("deviceId")).toString();
    if (devId.isEmpty()) {
        const QByteArray machId = QSysInfo::machineUniqueId();
        if (!machId.isEmpty()) {
            devId = QStringLiteral("SKYX-DEV-") + machId.toHex().toUpper().left(12);
        } else {
            devId = QStringLiteral("SKYX-DEV-") + QUuid::createUuid().toString(QUuid::WithoutBraces).toUpper().left(12);
        }
        settings.setValue(QStringLiteral("deviceId"), devId);
    }
    settings.endGroup();
    return devId;
}
