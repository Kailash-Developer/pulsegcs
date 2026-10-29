#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantMap>
#include <QtCore/QJsonObject>
#include <QtQml/QJSValue>

class QNetworkAccessManager;
class QNetworkReply;

// ============================================================================
// BACKEND MODE TOGGLE: LOCAL MOCK vs. REMOTE REST API
// ============================================================================
// Define PULSEGCS_AUTH_LOCAL_MOCK to read from project sample data.
// Comment out or undefine to connect to the live HTTP REST API.
#define PULSEGCS_AUTH_LOCAL_MOCK 1
// ============================================================================

class PulseGCSAuthService : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    Q_PROPERTY(bool isLocalMock READ isLocalMock CONSTANT)
    Q_PROPERTY(QVariantMap endpoints READ endpoints CONSTANT)

public:
    explicit PulseGCSAuthService(QObject *parent = nullptr);
    ~PulseGCSAuthService() override;

    static PulseGCSAuthService *instance();

    QString baseUrl() const { return _baseUrl; }
    void setBaseUrl(const QString &url);

    bool isBusy() const { return _isBusy; }
    bool isLocalMock() const;

    QVariantMap endpoints() const;

    // Public Invokable API (Common across Local and API modes)
    Q_INVOKABLE void signIn(const QString &email, const QString &password, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void registerOperator(const QVariantMap &payload, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void requestRecoveryCode(const QString &email, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void verifyRecoveryCode(const QString &email, const QString &code, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void resetPassword(const QString &email, const QString &resetToken, const QString &newPassword, const QJSValue &callback = QJSValue());

signals:
    void signInCompleted(bool success, const QVariantMap &data, const QString &errorMessage);
    void registrationCompleted(bool success, const QVariantMap &data, const QString &errorMessage);
    void recoveryRequestCompleted(bool success, const QVariantMap &data, const QString &errorMessage);
    void recoveryVerifyCompleted(bool success, const QVariantMap &data, const QString &errorMessage);
    void recoveryResetCompleted(bool success, const QVariantMap &data, const QString &errorMessage);

    void baseUrlChanged();
    void isBusyChanged();

private:
    void setBusy(bool busy);
    void invokeCallback(const QJSValue &callback, bool success, const QVariantMap &data, const QString &errorMsg);

    // Common JSON database loader for local mode
    QJsonObject loadMockDatabase() const;

    // Local mode processors
    void processLocalSignIn(const QString &email, const QString &password, const QJSValue &callback);
    void processLocalRegister(const QVariantMap &payload, const QJSValue &callback);
    void processLocalRecoveryRequest(const QString &email, const QJSValue &callback);
    void processLocalRecoveryVerify(const QString &email, const QString &code, const QJSValue &callback);
    void processLocalRecoveryReset(const QString &email, const QString &resetToken, const QString &newPassword, const QJSValue &callback);

    // API mode processors (Network REST client)
    void postHttpRequest(const QString &path, const QJsonObject &payload,
                         std::function<void(bool success, const QVariantMap &data, const QString &errorMsg)> handler);

    QString _baseUrl;
    bool _isBusy = false;
    QNetworkAccessManager *_networkManager = nullptr;
};

