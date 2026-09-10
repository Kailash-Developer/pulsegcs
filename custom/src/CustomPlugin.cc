#include "CustomPlugin.h"
#include "PulseGCSThemeTokens.h"
#include "QGCLoggingCategory.h"
#include "QGCPalette.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlComponent>
#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickWindow>

QGC_LOGGING_CATEGORY(CustomLog, "PulseGCS.CustomPlugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

namespace
{

void setThemedRole(
    QGCPalette::PaletteColorInfo_t &colorInfo,
    const QColor &lightEnabled,
    const QColor &lightDisabled,
    const QColor &darkEnabled,
    const QColor &darkDisabled)
{
    colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled] = lightEnabled;
    colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = lightDisabled;
    colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled] = darkEnabled;
    colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled] = darkDisabled;
}

} // namespace

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

void CustomPlugin::paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo)
{
    using namespace PulseGCSTheme;

    if (colorName == QStringLiteral("window")) {
        setThemedRole(colorInfo, outdoorWindow(), outdoorWindowDisabled(), ink(), inkDisabled());
    } else if (colorName == QStringLiteral("windowTransparent")) {
        setThemedRole(colorInfo, outdoorWindowTransparent(), outdoorWindowDisabled(), inkTransparent(), inkDisabled());
    } else if (colorName == QStringLiteral("windowShade")) {
        setThemedRole(colorInfo, outdoorWindowShade(), outdoorWindowShadeDisabled(), surfacePanel(), surfacePanelDisabled());
    } else if (colorName == QStringLiteral("windowShadeLight")) {
        setThemedRole(colorInfo, outdoorWindowShadeLight(), outdoorWindowShadeLightDisabled(), surfaceElevated(), surfaceElevatedDisabled());
    } else if (colorName == QStringLiteral("windowShadeDark")) {
        setThemedRole(colorInfo, outdoorWindowShadeDark(), outdoorWindowShadeDarkDisabled(), ink(), inkDisabled());
    } else if (colorName == QStringLiteral("toolbarBackground")) {
        setThemedRole(colorInfo, outdoorToolbar(), outdoorToolbar(), surfaceToolbar(), surfaceToolbar());
    } else if (colorName == QStringLiteral("text")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextMuted(), textPrimary(), textMuted());
    } else if (colorName == QStringLiteral("buttonText")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextMuted(), textPrimary(), textMuted());
    } else if (colorName == QStringLiteral("buttonHighlightText")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextMuted(), textPrimary(), textMuted());
    } else if (colorName == QStringLiteral("primaryButtonText")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextMuted(), textPrimary(), textMuted());
    } else if (colorName == QStringLiteral("textFieldText")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextMuted(), textPrimary(), textMuted());
    } else if (colorName == QStringLiteral("warningText")) {
        // Semantic red — Light/Dark contrast tuned
        setThemedRole(colorInfo, QColor(0xB3, 0x00, 0x00), QColor(0xCC, 0x08, 0x08), QColor(0xF8, 0x57, 0x61), QColor(0xCC, 0x08, 0x08));
    } else if (colorName == QStringLiteral("button")) {
        setThemedRole(colorInfo, outdoorButtonSurface(), outdoorButtonSurfaceDisabled(), buttonSurface(), buttonSurfaceDisabled());
    } else if (colorName == QStringLiteral("buttonBorder")) {
        setThemedRole(colorInfo, outdoorAccent(), outdoorWindowShadeLight(), accent(), surfaceElevated());
    } else if (colorName == QStringLiteral("buttonHighlight")) {
        setThemedRole(colorInfo, outdoorAccentHover(), outdoorWindowShadeLight(), accentHover(), surfaceElevated());
    } else if (colorName == QStringLiteral("primaryButton")) {
        setThemedRole(colorInfo, outdoorAccent(), outdoorButtonSurfaceDisabled(), accent(), buttonSurfaceDisabled());
    } else if (colorName == QStringLiteral("textField")) {
        setThemedRole(colorInfo, outdoorWindow(), outdoorWindowShade(), surfacePanel(), surfacePanelDisabled());
    } else if (colorName == QStringLiteral("groupBorder")) {
        setThemedRole(colorInfo, outdoorWindowShadeLight(), outdoorWindowShadeLightDisabled(), surfaceElevated(), surfaceElevatedDisabled());
    } else if (colorName == QStringLiteral("missionItemEditor")) {
        setThemedRole(colorInfo, outdoorCardTint(), outdoorCardTintDisabled(), cardTint(), cardTintDisabled());
    } else if (colorName == QStringLiteral("toolStripHoverColor")) {
        setThemedRole(colorInfo, outdoorAccentHover(), outdoorWindowShadeLight(), accentHover(), surfaceElevated());
    } else if (colorName == QStringLiteral("toolStripFGColor")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextMuted(), textPrimary(), textMuted());
    } else if (colorName == QStringLiteral("brandingPurple")) {
        setThemedRole(colorInfo, outdoorAccent(), outdoorAccent(), accent(), accent());
    } else if (colorName == QStringLiteral("brandingBlue")) {
        setThemedRole(colorInfo, outdoorAccent(), outdoorAccent(), accent(), accent());
    } else if (colorName == QStringLiteral("mapMissionTrajectory")) {
        setThemedRole(colorInfo, outdoorAccent(), outdoorAccent(), accent(), accent());
    } else if (colorName == QStringLiteral("mapIndicator")) {
        setThemedRole(colorInfo, outdoorAccent(), outdoorAccent(), accent(), accent());
    } else if (colorName == QStringLiteral("mapIndicatorChild")) {
        setThemedRole(colorInfo, outdoorAccentHover(), outdoorAccentHover(), accentHover(), accentHover());
    } else if (colorName == QStringLiteral("mapButton")) {
        setThemedRole(colorInfo, outdoorButtonSurface(), outdoorButtonSurfaceDisabled(), buttonSurface(), buttonSurfaceDisabled());
    } else if (colorName == QStringLiteral("mapButtonHighlight")) {
        setThemedRole(colorInfo, outdoorAccentHover(), outdoorAccentHover(), accentHover(), accentHover());
    } else if (colorName == QStringLiteral("mapWidgetBorderLight")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextPrimary(), textPrimary(), textPrimary());
    } else if (colorName == QStringLiteral("mapWidgetBorderDark")) {
        setThemedRole(colorInfo, outdoorWindowShadeDark(), outdoorWindowShadeDarkDisabled(), ink(), inkDisabled());
    } else if (colorName == QStringLiteral("modifiedParamValue")) {
        setThemedRole(colorInfo, outdoorAccent(), outdoorAccent(), accent(), accent());
    } else if (colorName == QStringLiteral("photoCaptureButtonColor")) {
        setThemedRole(colorInfo, outdoorTextPrimary(), outdoorTextMuted(), textPrimary(), textMuted());
    } else if (colorName == QStringLiteral("surveyPolygonInterior")) {
        setThemedRole(colorInfo, surveyPolygonFillOutdoor(), surveyPolygonFillOutdoor(), surveyPolygonFillIndoor(), surveyPolygonFillIndoor());
    }
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
