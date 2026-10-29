#include "PulseGCSAuthService.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QUuid>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>
#include <QtQml/QQmlEngine>

QGC_LOGGING_CATEGORY(PulseGCSAuthLog, "PulseGCS.AuthService")

namespace {
Q_APPLICATION_STATIC(PulseGCSAuthService, _authServiceInstance);
}

PulseGCSAuthService::PulseGCSAuthService(QObject *parent)
    : QObject(parent)
    , _baseUrl(QStringLiteral("https://api.pulsegcs.skyx.aero"))
    , _networkManager(new QNetworkAccessManager(this))
{
#ifdef PULSEGCS_AUTH_LOCAL_MOCK
    qCDebug(PulseGCSAuthLog) << "PulseGCSAuthService initialized in LOCAL MOCK mode (reading project sample data)";
#else
    qCDebug(PulseGCSAuthLog) << "PulseGCSAuthService initialized in REMOTE REST API mode (" << _baseUrl << ")";
#endif
}

PulseGCSAuthService::~PulseGCSAuthService() = default;

PulseGCSAuthService *PulseGCSAuthService::instance()
{
    return _authServiceInstance();
}

bool PulseGCSAuthService::isLocalMock() const
{
#ifdef PULSEGCS_AUTH_LOCAL_MOCK
    return true;
#else
    return false;
#endif
}

void PulseGCSAuthService::setBaseUrl(const QString &url)
{
    if (_baseUrl != url) {
        _baseUrl = url;
        emit baseUrlChanged();
    }
}

void PulseGCSAuthService::setBusy(bool busy)
{
    if (_isBusy != busy) {
        _isBusy = busy;
        emit isBusyChanged();
    }
}

QVariantMap PulseGCSAuthService::endpoints() const
{
    QVariantMap ep;
    ep[QStringLiteral("signIn")] = QStringLiteral("/api/v1/auth/signin");
    ep[QStringLiteral("register")] = QStringLiteral("/api/v1/auth/register");
    ep[QStringLiteral("recoveryRequest")] = QStringLiteral("/api/v1/auth/recovery/request");
    ep[QStringLiteral("recoveryVerify")] = QStringLiteral("/api/v1/auth/recovery/verify-code");
    ep[QStringLiteral("recoveryReset")] = QStringLiteral("/api/v1/auth/recovery/reset-password");
    ep[QStringLiteral("health")] = QStringLiteral("/api/v1/health");
    return ep;
}

void PulseGCSAuthService::invokeCallback(const QJSValue &callback, bool success, const QVariantMap &data, const QString &errorMsg)
{
    if (callback.isCallable()) {
        QQmlEngine *engine = qmlEngine(this);
        QJSValue dataVal = engine ? engine->toScriptValue(data) : QJSValue();
        QJSValueList args;
        args << success << dataVal << errorMsg;
        const_cast<QJSValue&>(callback).call(args);
    }
}

QJsonObject PulseGCSAuthService::loadMockDatabase() const
{
    const QStringList candidatePaths = {
        QStringLiteral("custom/data/mock/auth_database.json"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/custom/data/mock/auth_database.json"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/../custom/data/mock/auth_database.json"),
        QStringLiteral(":/Custom/data/mock/auth_database.json")
    };

    for (const QString &path : candidatePaths) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QByteArray raw = file.readAll();
            file.close();
            QJsonDocument doc = QJsonDocument::fromJson(raw);
            if (doc.isObject()) {
                qCDebug(PulseGCSAuthLog) << "Loaded mock auth database from:" << path;
                return doc.object();
            }
        }
    }

    qCWarning(PulseGCSAuthLog) << "Unable to locate auth_database.json on disk or in resources";
    return QJsonObject();
}

// ============================================================================
// Public Auth Methods (Branching on PULSEGCS_AUTH_LOCAL_MOCK)
// ============================================================================

void PulseGCSAuthService::signIn(const QString &email, const QString &password, const QJSValue &callback)
{
    if (_isBusy) return;
    setBusy(true);

#ifdef PULSEGCS_AUTH_LOCAL_MOCK
    processLocalSignIn(email, password, callback);
#else
    QJsonObject payload;
    payload[QStringLiteral("email")] = email.trimmed();
    payload[QStringLiteral("password")] = password;
    payload[QStringLiteral("deviceId")] = QStringLiteral("console-skyx-dev-01");
    payload[QStringLiteral("clientTimestamp")] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    postHttpRequest(endpoints()[QStringLiteral("signIn")].toString(), payload,
                    [this, callback](bool success, const QVariantMap &data, const QString &errorMsg) {
                        setBusy(false);
                        emit signInCompleted(success, data, errorMsg);
                        invokeCallback(callback, success, data, errorMsg);
                    });
#endif
}

void PulseGCSAuthService::registerOperator(const QVariantMap &payload, const QJSValue &callback)
{
    if (_isBusy) return;
    setBusy(true);

#ifdef PULSEGCS_AUTH_LOCAL_MOCK
    processLocalRegister(payload, callback);
#else
    QJsonObject jsonPayload = QJsonObject::fromVariantMap(payload);
    postHttpRequest(endpoints()[QStringLiteral("register")].toString(), jsonPayload,
                    [this, callback](bool success, const QVariantMap &data, const QString &errorMsg) {
                        setBusy(false);
                        emit registrationCompleted(success, data, errorMsg);
                        invokeCallback(callback, success, data, errorMsg);
                    });
#endif
}

void PulseGCSAuthService::requestRecoveryCode(const QString &email, const QJSValue &callback)
{
    if (_isBusy) return;
    setBusy(true);

#ifdef PULSEGCS_AUTH_LOCAL_MOCK
    processLocalRecoveryRequest(email, callback);
#else
    QJsonObject payload;
    payload[QStringLiteral("email")] = email.trimmed();

    postHttpRequest(endpoints()[QStringLiteral("recoveryRequest")].toString(), payload,
                    [this, callback](bool success, const QVariantMap &data, const QString &errorMsg) {
                        setBusy(false);
                        emit recoveryRequestCompleted(success, data, errorMsg);
                        invokeCallback(callback, success, data, errorMsg);
                    });
#endif
}

void PulseGCSAuthService::verifyRecoveryCode(const QString &email, const QString &code, const QJSValue &callback)
{
    if (_isBusy) return;
    setBusy(true);

#ifdef PULSEGCS_AUTH_LOCAL_MOCK
    processLocalRecoveryVerify(email, code, callback);
#else
    QJsonObject payload;
    payload[QStringLiteral("email")] = email.trimmed();
    payload[QStringLiteral("code")] = code.trimmed();

    postHttpRequest(endpoints()[QStringLiteral("recoveryVerify")].toString(), payload,
                    [this, callback](bool success, const QVariantMap &data, const QString &errorMsg) {
                        setBusy(false);
                        emit recoveryVerifyCompleted(success, data, errorMsg);
                        invokeCallback(callback, success, data, errorMsg);
                    });
#endif
}

void PulseGCSAuthService::resetPassword(const QString &email, const QString &resetToken, const QString &newPassword, const QJSValue &callback)
{
    if (_isBusy) return;
    setBusy(true);

#ifdef PULSEGCS_AUTH_LOCAL_MOCK
    processLocalRecoveryReset(email, resetToken, newPassword, callback);
#else
    QJsonObject payload;
    payload[QStringLiteral("email")] = email.trimmed();
    payload[QStringLiteral("resetToken")] = resetToken;
    payload[QStringLiteral("newPassword")] = newPassword;

    postHttpRequest(endpoints()[QStringLiteral("recoveryReset")].toString(), payload,
                    [this, callback](bool success, const QVariantMap &data, const QString &errorMsg) {
                        setBusy(false);
                        emit recoveryResetCompleted(success, data, errorMsg);
                        invokeCallback(callback, success, data, errorMsg);
                    });
#endif
}

// ============================================================================
// Local Mode Processors (Data-driven from auth_database.json)
// ============================================================================

void PulseGCSAuthService::processLocalSignIn(const QString &email, const QString &password, const QJSValue &callback)
{
    setBusy(false);
    const QString normEmail = email.trimmed().toLower();
    const QString pw = password;

    QJsonObject db = loadMockDatabase();
    QJsonArray accounts = db[QStringLiteral("accounts")].toArray();
    QJsonObject httpResponses = db[QStringLiteral("httpTemplates")].toObject();
    if (httpResponses.isEmpty()) {
        httpResponses = db[QStringLiteral("httpResponses")].toObject();
    }

    QJsonObject account;
    bool found = false;
    for (const QJsonValue &av : accounts) {
        QJsonObject a = av.toObject();
        if (a[QStringLiteral("email")].toString().trimmed().toLower() == normEmail) {
            account = a;
            found = true;
            break;
        }
    }

    // 1. Account Not Found (404) -> Strict Default-Deny
    if (!found) {
        QVariantMap err = httpResponses[QStringLiteral("404_ACCOUNT_NOT_FOUND")].toObject().toVariantMap();
        QString msg = err[QStringLiteral("message")].toString();
        emit signInCompleted(false, err, msg);
        invokeCallback(callback, false, err, msg);
        return;
    }

    // 2. Lookup Password Triggers
    QJsonObject activePasswords = account[QStringLiteral("activePasswords")].toObject();
    QString responseKey = activePasswords[pw].toString();

    // If password doesn't match account's configured passwords -> Default-Deny 401
    if (responseKey.isEmpty()) {
        QVariantMap err = httpResponses[QStringLiteral("401_INVALID_CREDENTIALS")].toObject().toVariantMap();
        QString msg = err[QStringLiteral("message")].toString();
        emit signInCompleted(false, err, msg);
        invokeCallback(callback, false, err, msg);
        return;
    }

    QJsonObject respObj = httpResponses[responseKey].toObject();
    Q_UNUSED(respObj.value(QStringLiteral("httpStatus")));
    QVariantMap data = respObj.toVariantMap();

    // Positive Case: 200 OK Standard Login
    if (responseKey == QStringLiteral("200_OK")) {
        data[QStringLiteral("token")] = QStringLiteral("mock_jwt_token_") + QUuid::createUuid().toString(QUuid::WithoutBraces).left(12);
        QVariantMap op;
        op[QStringLiteral("id")] = account[QStringLiteral("id")].toString();
        op[QStringLiteral("email")] = account[QStringLiteral("email")].toString();
        op[QStringLiteral("name")] = account[QStringLiteral("name")].toString(QStringLiteral("Certified Flight Operator"));
        op[QStringLiteral("role")] = account[QStringLiteral("role")].toString(QStringLiteral("pilot"));
        data[QStringLiteral("operator")] = op;

        QVariantMap att;
        att[QStringLiteral("validDays")] = 7;
        att[QStringLiteral("sessionActive")] = true;
        att[QStringLiteral("expiresAt")] = QDateTime::currentDateTimeUtc().addDays(7).toString(Qt::ISODate);
        data[QStringLiteral("attestation")] = att;
        data[QStringLiteral("sessionActive")] = true;

        emit signInCompleted(true, data, QString());
        invokeCallback(callback, true, data, QString());
        return;
    }

    // Positive Case: 200 OK First-Login License Ready Modal
    if (responseKey == QStringLiteral("200_LICENSE_READY")) {
        data[QStringLiteral("token")] = QStringLiteral("mock_jwt_token_lic_") + QUuid::createUuid().toString(QUuid::WithoutBraces).left(10);
        data[QStringLiteral("licenseReady")] = true;
        QJsonObject licObj = account[QStringLiteral("license")].toObject();
        data[QStringLiteral("licenseKey")] = licObj[QStringLiteral("licenseKey")].toString(QStringLiteral("SKYX-LIC-8820-4190-FA21"));
        data[QStringLiteral("droneModel")] = licObj[QStringLiteral("droneModel")].toString(QStringLiteral("SkyX Kissan"));
        data[QStringLiteral("serialNumber")] = licObj[QStringLiteral("serialNumber")].toString(QStringLiteral("SKYX-KSN-2026-0842"));

        QVariantMap op;
        op[QStringLiteral("id")] = account[QStringLiteral("id")].toString();
        op[QStringLiteral("email")] = account[QStringLiteral("email")].toString();
        op[QStringLiteral("name")] = account[QStringLiteral("name")].toString(QStringLiteral("Certified Flight Operator"));
        op[QStringLiteral("role")] = account[QStringLiteral("role")].toString(QStringLiteral("pilot"));
        data[QStringLiteral("operator")] = op;

        QVariantMap att;
        att[QStringLiteral("validDays")] = 7;
        att[QStringLiteral("sessionActive")] = true;
        data[QStringLiteral("attestation")] = att;
        data[QStringLiteral("sessionActive")] = true;

        emit signInCompleted(true, data, QString());
        invokeCallback(callback, true, data, QString());
        return;
    }

    // Negative Cases: (401, 403, 202, 422, 500, 504)
    QString msg = data[QStringLiteral("message")].toString();
    emit signInCompleted(false, data, msg);
    invokeCallback(callback, false, data, msg);
}

void PulseGCSAuthService::processLocalRegister(const QVariantMap &payload, const QJSValue &callback)
{
    setBusy(false);
    QString email = payload[QStringLiteral("email")].toString().trimmed().toLower();

    QJsonObject db = loadMockDatabase();
    QJsonObject regSection = db[QStringLiteral("registration")].toObject();
    QJsonObject httpResponses = db[QStringLiteral("httpTemplates")].toObject();
    if (httpResponses.isEmpty()) {
        httpResponses = db[QStringLiteral("httpResponses")].toObject();
    }

    QJsonObject emailTriggers = regSection[QStringLiteral("triggers")].toObject();
    if (emailTriggers.isEmpty()) {
        emailTriggers = regSection[QStringLiteral("emailTriggers")].toObject();
    }
    QString responseKey = emailTriggers[email].toString();

    // Check if email already exists in accounts[]
    if (responseKey.isEmpty()) {
        QJsonArray accounts = db[QStringLiteral("accounts")].toArray();
        for (const QJsonValue &av : accounts) {
            if (av.toObject()[QStringLiteral("email")].toString().trimmed().toLower() == email) {
                responseKey = QStringLiteral("409_ACCOUNT_EXISTS");
                break;
            }
        }
    }

    // Fallback checks
    if (responseKey.isEmpty()) {
        if (email.contains(QStringLiteral("duplicate")) || email.contains(QStringLiteral("exists"))) {
            responseKey = QStringLiteral("409_ACCOUNT_EXISTS");
        } else if (email.contains(QStringLiteral("failed")) || email.contains(QStringLiteral("fail"))) {
            responseKey = QStringLiteral("500_SUBMISSION_FAILED");
        } else if (email.contains(QStringLiteral("timeout"))) {
            responseKey = QStringLiteral("504_SERVER_TIMEOUT");
        } else {
            responseKey = QStringLiteral("202_ACCEPTED");
        }
    }

    QJsonObject respObj = httpResponses[responseKey].toObject();
    QVariantMap data = respObj.toVariantMap();
    int httpStatus = respObj[QStringLiteral("httpStatus")].toInt();

    if (httpStatus >= 200 && httpStatus < 300) {
        data[QStringLiteral("applicationId")] = QStringLiteral("APP-") + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8).toUpper();
        data[QStringLiteral("message")] = tr("Operator application submitted successfully and is pending administrative review.");
        emit registrationCompleted(true, data, QString());
        invokeCallback(callback, true, data, QString());
    } else {
        QString msg = data[QStringLiteral("message")].toString();
        emit registrationCompleted(false, data, msg);
        invokeCallback(callback, false, data, msg);
    }
}

void PulseGCSAuthService::processLocalRecoveryRequest(const QString &email, const QJSValue &callback)
{
    setBusy(false);
    QString normEmail = email.trimmed().toLower();
    QJsonObject db = loadMockDatabase();
    QJsonObject recSection = db[QStringLiteral("passwordRecovery")].toObject();
    QJsonObject httpResponses = db[QStringLiteral("httpTemplates")].toObject();
    if (httpResponses.isEmpty()) {
        httpResponses = db[QStringLiteral("httpResponses")].toObject();
    }

    QJsonObject emailTriggers = recSection[QStringLiteral("triggers")].toObject();
    if (emailTriggers.isEmpty()) {
        emailTriggers = recSection[QStringLiteral("emailTriggers")].toObject();
    }
    QString responseKey = emailTriggers[normEmail].toString();

    if (!responseKey.isEmpty()) {
        QVariantMap err = httpResponses[responseKey].toObject().toVariantMap();
        emit recoveryRequestCompleted(false, err, err[QStringLiteral("message")].toString());
        invokeCallback(callback, false, err, err[QStringLiteral("message")].toString());
        return;
    }

    QString code = recSection[QStringLiteral("validCode")].toString(QStringLiteral("849201"));
    QVariantMap data = httpResponses[QStringLiteral("200_OK")].toObject().toVariantMap();
    data[QStringLiteral("message")] = tr("A 6-digit recovery code has been sent to %1").arg(email);
    data[QStringLiteral("testCode")] = code;
    emit recoveryRequestCompleted(true, data, QString());
    invokeCallback(callback, true, data, QString());
}

void PulseGCSAuthService::processLocalRecoveryVerify(const QString &email, const QString &code, const QJSValue &callback)
{
    Q_UNUSED(email)
    setBusy(false);
    QJsonObject db = loadMockDatabase();
    QString validCode = db[QStringLiteral("passwordRecovery")].toObject()[QStringLiteral("validCode")].toString(QStringLiteral("849201"));

    if (code.trimmed() != validCode) {
        QJsonObject httpResponses = db[QStringLiteral("httpTemplates")].toObject();
        if (httpResponses.isEmpty()) {
            httpResponses = db[QStringLiteral("httpResponses")].toObject();
        }
        QVariantMap err = httpResponses[QStringLiteral("400_BAD_REQUEST")].toObject().toVariantMap();
        emit recoveryVerifyCompleted(false, err, err[QStringLiteral("message")].toString());
        invokeCallback(callback, false, err, err[QStringLiteral("message")].toString());
        return;
    }

    QVariantMap data;
    data[QStringLiteral("status")] = QStringLiteral("success");
    data[QStringLiteral("code")] = 200;
    data[QStringLiteral("resetToken")] = QStringLiteral("rst_tok_") + QUuid::createUuid().toString(QUuid::WithoutBraces).left(16);
    data[QStringLiteral("message")] = tr("Verification successful. Please enter your new password.");
    emit recoveryVerifyCompleted(true, data, QString());
    invokeCallback(callback, true, data, QString());
}

void PulseGCSAuthService::processLocalRecoveryReset(const QString &email, const QString &resetToken, const QString &newPassword, const QJSValue &callback)
{
    Q_UNUSED(email)
    Q_UNUSED(resetToken)
    Q_UNUSED(newPassword)
    setBusy(false);

    QVariantMap data;
    data[QStringLiteral("status")] = QStringLiteral("success");
    data[QStringLiteral("code")] = 200;
    data[QStringLiteral("message")] = tr("Password has been reset successfully. You may now sign in.");
    emit recoveryResetCompleted(true, data, QString());
    invokeCallback(callback, true, data, QString());
}

// ============================================================================
// Remote REST API Implementation (Active when PULSEGCS_AUTH_LOCAL_MOCK is disabled)
// ============================================================================

void PulseGCSAuthService::postHttpRequest(const QString &path, const QJsonObject &payload,
                                          std::function<void(bool success, const QVariantMap &data, const QString &errorMsg)> handler)
{
    QUrl url(_baseUrl + path);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Accept", "application/json");

    QByteArray body = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = _networkManager->post(request, body);

    connect(reply, &QNetworkReply::finished, this, [reply, handler]() {
        reply->deleteLater();
        int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray respBody = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(respBody);
        QVariantMap data = doc.isObject() ? doc.object().toVariantMap() : QVariantMap();

        if (reply->error() == QNetworkReply::NoError && httpCode >= 200 && httpCode < 300) {
            handler(true, data, QString());
            return;
        }

        QString errorMsg;
        if (!data[QStringLiteral("message")].toString().isEmpty()) {
            errorMsg = data[QStringLiteral("message")].toString();
        } else if (httpCode == 401) {
            errorMsg = tr("Invalid credentials. Please re-enter your password.");
        } else if (httpCode == 403) {
            errorMsg = tr("This device has been marked replaced or suspended by an administrator.");
        } else if (httpCode == 404) {
            errorMsg = tr("No operator account found matching this email.");
        } else if (httpCode == 409) {
            errorMsg = tr("An account with this email address already exists.");
        } else if (httpCode == 0 || reply->error() != QNetworkReply::NoError) {
            errorMsg = tr("Network connection failed. Verify internet link: %1").arg(reply->errorString());
        } else {
            errorMsg = tr("Server returned HTTP error %1").arg(httpCode);
        }

        handler(false, data, errorMsg);
    });
}
