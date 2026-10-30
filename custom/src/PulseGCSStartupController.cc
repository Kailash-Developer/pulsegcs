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
#include <QtCore/QCryptographicHash>
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

namespace {
QByteArray obfuscateVaultToken(const QString &token, const QString &devId)
{
    if (token.isEmpty()) return QByteArray();
    const QByteArray key = QCryptographicHash::hash((devId + QStringLiteral(":PulseGCS_Session_Salt_2026")).toUtf8(), QCryptographicHash::Sha256);
    QByteArray raw = token.toUtf8();
    const QByteArray mac = QCryptographicHash::hash(raw + key, QCryptographicHash::Sha256).left(16);
    for (qsizetype i = 0; i < raw.size(); ++i) {
        raw[i] = raw[i] ^ key[i % key.size()];
    }
    return (mac + raw).toBase64();
}

QString deobfuscateVaultToken(const QByteArray &b64, const QString &devId)
{
    if (b64.isEmpty()) return QString();
    const QByteArray combined = QByteArray::fromBase64(b64);
    if (combined.size() < 16) return QString();
    const QByteArray mac = combined.left(16);
    QByteArray raw = combined.mid(16);
    const QByteArray key = QCryptographicHash::hash((devId + QStringLiteral(":PulseGCS_Session_Salt_2026")).toUtf8(), QCryptographicHash::Sha256);
    for (qsizetype i = 0; i < raw.size(); ++i) {
        raw[i] = raw[i] ^ key[i % key.size()];
    }
    const QByteArray expectedMac = QCryptographicHash::hash(raw + key, QCryptographicHash::Sha256).left(16);
    if (mac != expectedMac) {
        qCWarning(PulseGCSStartupLog) << "PulseGCS SECURITY: Vault token HMAC mismatch! Foreign hardware or corrupted session.";
        return QString();
    }
    return QString::fromUtf8(raw);
}
}

void PulseGCSStartupController::saveSession(const QString &email, const QString &token, int validDays)
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PulseGCSAuth"));
    settings.setValue(QStringLiteral("email"), email.trimmed());

    // Obfuscate token bound to hardware deviceId (BUG-03)
    const QString devId = deviceId();
    settings.setValue(QStringLiteral("tokenEncrypted"), obfuscateVaultToken(token, devId));
    settings.remove(QStringLiteral("token")); // Purge plaintext legacy storage

    const QDateTime now = QDateTime::currentDateTimeUtc();
    const QDateTime expiresAt = now.addDays(validDays);
    settings.setValue(QStringLiteral("expiresAt"), expiresAt.toString(Qt::ISODate));
    settings.setValue(QStringLiteral("lastSeen"), now.toString(Qt::ISODate));
    settings.endGroup();
    qCDebug(PulseGCSStartupLog) << "PulseGCS: Saved 7-day session for" << email << "expiring at" << expiresAt;
}

QVariantMap PulseGCSStartupController::loadSession()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PulseGCSAuth"));
    const QString email = settings.value(QStringLiteral("email")).toString();
    const QByteArray tokenEncrypted = settings.value(QStringLiteral("tokenEncrypted")).toByteArray();
    QString token;
    const QString devId = deviceId();
    if (!tokenEncrypted.isEmpty()) {
        token = deobfuscateVaultToken(tokenEncrypted, devId);
    } else {
        // Fallback for migration from unencrypted legacy sessions
        token = settings.value(QStringLiteral("token")).toString();
    }

    const QString expiresStr = settings.value(QStringLiteral("expiresAt")).toString();
    const QString lastSeenStr = settings.value(QStringLiteral("lastSeen")).toString();
    settings.endGroup();

    QVariantMap res;
    res[QStringLiteral("hasSession")] = false;
    res[QStringLiteral("active")] = false;
    res[QStringLiteral("expired")] = false;
    res[QStringLiteral("clockTampered")] = false;
    res[QStringLiteral("email")] = email;
    res[QStringLiteral("token")] = token;
    res[QStringLiteral("expiresAt")] = expiresStr;
    res[QStringLiteral("lastSeen")] = lastSeenStr;

    if (email.isEmpty() || token.isEmpty() || expiresStr.isEmpty()) {
        return res;
    }

    res[QStringLiteral("hasSession")] = true;
    const QDateTime expiresAt = QDateTime::fromString(expiresStr, Qt::ISODate);
    if (!expiresAt.isValid()) {
        return res;
    }

    const QDateTime now = QDateTime::currentDateTimeUtc();
    const QDateTime lastSeen = QDateTime::fromString(lastSeenStr, Qt::ISODate);

    // Clock rollback detection (BUG-02)
    if (lastSeen.isValid() && now < lastSeen) {
        qCWarning(PulseGCSStartupLog) << "PulseGCS SECURITY: System clock rollback detected! Current UTC:" << now << "< Last seen:" << lastSeen;
        res[QStringLiteral("clockTampered")] = true;
        res[QStringLiteral("active")] = false;
        res[QStringLiteral("expired")] = true;
        return res;
    }

    if (now < expiresAt) {
        res[QStringLiteral("active")] = true;
        // Monotonically advance lastSeen
        settings.beginGroup(QStringLiteral("PulseGCSAuth"));
        settings.setValue(QStringLiteral("lastSeen"), now.toString(Qt::ISODate));
        settings.endGroup();
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
    settings.remove(QStringLiteral("tokenEncrypted"));
    settings.remove(QStringLiteral("expiresAt"));
    settings.remove(QStringLiteral("lastSeen"));
    settings.endGroup();
    qCDebug(PulseGCSStartupLog) << "PulseGCS: Cleared stored session from QSettings";
}

QString PulseGCSStartupController::deviceId()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PulseGCSAuth"));
    QString devId = settings.value(QStringLiteral("deviceId")).toString();

    // Verify against persistent app data file in case QSettings was cleared (BUG-06)
    const QString targetDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(targetDir);
    const QString devIdFile = targetDir + QStringLiteral("/.skyx_device_id");

    if (devId.isEmpty()) {
        QFile f(devIdFile);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            devId = QString::fromUtf8(f.readAll()).trimmed();
            f.close();
        }
    }

    if (devId.isEmpty()) {
        QByteArray machId = QSysInfo::machineUniqueId();
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
        if (machId.isEmpty()) {
            QFile midFile(QStringLiteral("/etc/machine-id"));
            if (midFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                machId = midFile.readAll().trimmed();
                midFile.close();
            }
        }
        if (machId.isEmpty()) {
            QFile dbusFile(QStringLiteral("/var/lib/dbus/machine-id"));
            if (dbusFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                machId = dbusFile.readAll().trimmed();
                dbusFile.close();
            }
        }
#elif defined(Q_OS_ANDROID)
        if (machId.isEmpty()) {
            QJniObject activity = QNativeInterface::QAndroidApplication::context();
            if (activity.isValid()) {
                QJniObject contentResolver = activity.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");
                if (contentResolver.isValid()) {
                    QJniObject androidId = QJniObject::callStaticObjectMethod(
                        "android/provider/Settings$Secure",
                        "getString",
                        "(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;",
                        contentResolver.object<jobject>(),
                        QJniObject::fromString("android_id").object<jstring>()
                    );
                    if (androidId.isValid()) {
                        machId = androidId.toString().toUtf8();
                    }
                }
            }
        }
#endif
        if (!machId.isEmpty()) {
            devId = QStringLiteral("SKYX-DEV-") + machId.toHex().toUpper().left(12);
        } else {
            devId = QStringLiteral("SKYX-DEV-") + QUuid::createUuid().toString(QUuid::WithoutBraces).toUpper().left(12);
        }

        // Persist to disk file so cache wiping doesn't destroy device identity
        QFile f(devIdFile);
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            f.write(devId.toUtf8());
            f.close();
        }
        settings.setValue(QStringLiteral("deviceId"), devId);
    } else {
        // Ensure disk file is in sync
        QFile f(devIdFile);
        if (!f.exists() && f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            f.write(devId.toUtf8());
            f.close();
        }
    }
    settings.endGroup();
    return devId;
}
