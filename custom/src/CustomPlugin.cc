#include "CustomPlugin.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlComponent>
#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickWindow>

QGC_LOGGING_CATEGORY(CustomLog, "PulseGCS.CustomPlugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

/*===========================================================================*/

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
    qCDebug(CustomLog) << "PulseGCS CustomPlugin initialized";
}

QGCCorePlugin *CustomPlugin::instance()
{
    return _customPluginInstance();
}

QQmlApplicationEngine *CustomPlugin::createQmlApplicationEngine(QObject *parent)
{
    _qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);
    if (!_qmlEngine) {
        qCCritical(CustomLog) << "Failed to create QQmlApplicationEngine from base QGCCorePlugin";
        return nullptr;
    }

    _urlInterceptor = new CustomOverrideInterceptor();
    _qmlEngine->addUrlInterceptor(_urlInterceptor);
    _qmlEngine->addImportPath(QStringLiteral("qrc:/Custom/qml"));
    qCDebug(CustomLog) << "PulseGCS CustomOverrideInterceptor registered with QQmlApplicationEngine";

    return _qmlEngine;
}

void CustomPlugin::createRootWindow(QQmlApplicationEngine *qmlEngine)
{
    QGCCorePlugin::createRootWindow(qmlEngine);

    if (!qmlEngine || qmlEngine->rootObjects().isEmpty()) {
        qCWarning(CustomLog) << "Unable to attach splash overlay: root window not created";
        return;
    }

    QQuickWindow *const mainWindow = qobject_cast<QQuickWindow *>(qmlEngine->rootObjects().constFirst());
    if (!mainWindow) {
        qCWarning(CustomLog) << "Unable to attach splash overlay: root object is not a QQuickWindow";
        return;
    }

    QQmlComponent splashComponent(qmlEngine, QUrl(QStringLiteral("qrc:/Custom/qml/PulseGCS/SplashScreen.qml")));
    if (splashComponent.status() != QQmlComponent::Ready) {
        qCWarning(CustomLog) << "SplashScreen component not ready:" << splashComponent.errorString();
        return;
    }

    QObject *const splashObject = splashComponent.create();
    if (!splashObject) {
        qCWarning(CustomLog) << "Failed to instantiate SplashScreen";
        return;
    }

    QQuickItem *const splashItem = qobject_cast<QQuickItem *>(splashObject);
    if (!splashItem) {
        qCWarning(CustomLog) << "SplashScreen root is not a QQuickItem";
        splashObject->deleteLater();
        return;
    }

    splashItem->setParentItem(mainWindow->contentItem());
    splashItem->setWidth(mainWindow->width());
    splashItem->setHeight(mainWindow->height());

    QObject::connect(mainWindow, &QQuickWindow::widthChanged, splashItem, [splashItem, mainWindow]() {
        splashItem->setWidth(mainWindow->width());
    });
    QObject::connect(mainWindow, &QQuickWindow::heightChanged, splashItem, [splashItem, mainWindow]() {
        splashItem->setHeight(mainWindow->height());
    });

    QObject::connect(splashObject, SIGNAL(splashCompleted()), splashObject, SLOT(deleteLater()));
    qCDebug(CustomLog) << "PulseGCS splash overlay attached to main window";
}

void CustomPlugin::destroyQmlApplicationEngine(QQmlApplicationEngine *qmlEngine)
{
    if (qmlEngine && (qmlEngine == _qmlEngine)) {
        if (_urlInterceptor) {
            qmlEngine->removeUrlInterceptor(_urlInterceptor);
            delete _urlInterceptor;
            _urlInterceptor = nullptr;
        }
        _qmlEngine = nullptr;
    }

    QGCCorePlugin::destroyQmlApplicationEngine(qmlEngine);
}

/*===========================================================================*/

CustomOverrideInterceptor::CustomOverrideInterceptor()
    : QQmlAbstractUrlInterceptor()
{
}

QUrl CustomOverrideInterceptor::intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type)
{
    switch (type) {
    case QQmlAbstractUrlInterceptor::QmlFile:
    case QQmlAbstractUrlInterceptor::UrlString:
        if (url.scheme() == QStringLiteral("qrc")) {
            const QString origPath = url.path();
            const QString overrideRes = QStringLiteral(":/Custom%1").arg(origPath);
            if (QFile::exists(overrideRes)) {
                const QString relPath = overrideRes.mid(2);
                QUrl result;
                result.setScheme(QStringLiteral("qrc"));
                result.setPath(QLatin1Char('/') + relPath);
                return result;
            }
        }
        break;
    default:
        break;
    }

    return url;
}
