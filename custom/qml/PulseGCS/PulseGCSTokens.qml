pragma Singleton
import QtQuick
import QGroundControl

QtObject {
    id: root

    // ========================================================================
    // Indoor Theme Tokens (Dark — Command Center)
    // ========================================================================
    readonly property color ink: "#0A1420"
    readonly property color surfaceToolbar: "#0D1B2A"
    readonly property color surfacePanel: "#112537"
    readonly property color surfaceElevated: "#16324A"
    readonly property color textPrimary: "#EAF4FB"
    readonly property color textMuted: "#9FB7CC"
    readonly property color textMeta: "#6E869D"
    readonly property color accent: "#2FD0E8"
    readonly property color accentHover: "#5BDCF0"
    readonly property color accentCore: "#0E9CB3"
    readonly property color cardTint: Qt.rgba(47/255, 208/255, 232/255, 0.07)
    readonly property color cardTintSolid: "#122A3E"
    readonly property color buttonSurface: "#16283A"
    readonly property color buttonBorder: Qt.rgba(140/255, 163/255, 184/255, 0.16)
    readonly property color borderSubtle: Qt.rgba(140/255, 163/255, 184/255, 0.12)
    readonly property color divider: Qt.rgba(140/255, 163/255, 184/255, 0.14)

    // Indoor Semantic Status Tokens
    readonly property color ok: "#3ED598"
    readonly property color okBg: Qt.rgba(62/255, 213/255, 152/255, 0.12)
    readonly property color warn: "#F2B84B"
    readonly property color warnBg: Qt.rgba(242/255, 184/255, 75/255, 0.12)
    readonly property color err: "#F0684F"
    readonly property color errBg: Qt.rgba(240/255, 104/255, 79/255, 0.12)
    readonly property color neutral: "#8CA3B8"
    readonly property color neutralBg: Qt.rgba(140/255, 163/255, 184/255, 0.10)
    readonly property color surveyPolygonFillIndoor: Qt.rgba(47/255, 208/255, 232/255, 0.40)

    // ========================================================================
    // Outdoor Theme Tokens (Light — Sunlight High-Contrast)
    // ========================================================================
    readonly property color outdoorWindow: "#FFFFFF"
    readonly property color outdoorWindowShade: "#EDF2F6"
    readonly property color outdoorWindowShadeLight: "#F6F9FB"
    readonly property color outdoorWindowShadeDark: "#DCE5EC"
    readonly property color outdoorToolbar: "#F3F6F8"
    readonly property color outdoorTextPrimary: "#14202B"
    readonly property color outdoorTextMuted: "#4C6072"
    readonly property color outdoorTextMeta: "#748899"
    readonly property color outdoorAccent: "#0092A8"
    readonly property color outdoorAccentHover: "#00B2CC"
    readonly property color outdoorAccentCore: "#00788A"
    readonly property color outdoorCardTint: Qt.rgba(0/255, 146/255, 168/255, 0.06)
    readonly property color outdoorCardTintSolid: "#E0F7FA"
    readonly property color outdoorButtonSurface: "#FFFFFF"
    readonly property color outdoorButtonBorder: "#DCE5EC"
    readonly property color outdoorBorderSubtle: "#DCE5EC"
    readonly property color outdoorDivider: "#DCE5EC"

    // Outdoor Semantic Status Tokens
    readonly property color outdoorOk: "#178A57"
    readonly property color outdoorOkBg: Qt.rgba(23/255, 138/255, 87/255, 0.10)
    readonly property color outdoorWarn: "#97650B"
    readonly property color outdoorWarnBg: Qt.rgba(151/255, 101/255, 11/255, 0.10)
    readonly property color outdoorErr: "#C13A24"
    readonly property color outdoorErrBg: Qt.rgba(193/255, 58/255, 36/255, 0.09)
    readonly property color outdoorNeutral: "#5D7286"
    readonly property color outdoorNeutralBg: Qt.rgba(93/255, 114/255, 134/255, 0.09)
    readonly property color surveyPolygonFillOutdoor: Qt.rgba(0/255, 146/255, 168/255, 0.50)

    // ========================================================================
    // Dimensions & Radii
    // ========================================================================
    readonly property real radiusCard: 10
    readonly property real radiusPill: 999
    readonly property real radiusButton: 7
    readonly property real radiusControl: 8
    readonly property real radiusIconBox: 7

    // ========================================================================
    // Dynamic Theme Helper Functions & Reactive Theme State
    // ========================================================================
    readonly property bool isOutdoor: QGroundControl.globalPalette.globalTheme === QGCPalette.Light

    // Prefer PulseGCSTokens.isOutdoor in property bindings. Passing an explicit theme
    // argument is for one-shot evaluation only and will not subscribe to paletteChanged.
    function isOutdoorTheme(theme) {
        if (theme !== undefined) {
            return theme === QGCPalette.Light
        }
        return isOutdoor
    }

    function surfaceBackground(isOutdoor) {
        return isOutdoor ? outdoorWindow : surfacePanel
    }

    function surfaceElevatedBackground(isOutdoor) {
        return isOutdoor ? outdoorWindowShade : surfaceElevated
    }

    function surfaceToolbarBackground(isOutdoor) {
        return isOutdoor ? outdoorToolbar : surfaceToolbar
    }

    function cardTintBackground(isOutdoor) {
        return isOutdoor ? outdoorCardTint : cardTint
    }

    function primaryText(isOutdoor) {
        return isOutdoor ? outdoorTextPrimary : textPrimary
    }

    function mutedText(isOutdoor) {
        return isOutdoor ? outdoorTextMuted : textMuted
    }

    function metaText(isOutdoor) {
        return isOutdoor ? outdoorTextMeta : textMeta
    }

    function accentColor(isOutdoor) {
        return isOutdoor ? outdoorAccent : accent
    }

    function accentHoverColor(isOutdoor) {
        return isOutdoor ? outdoorAccentHover : accentHover
    }

    function buttonBackground(isOutdoor) {
        return isOutdoor ? outdoorButtonSurface : buttonSurface
    }

    function buttonBorderColor(isOutdoor) {
        return isOutdoor ? outdoorButtonBorder : buttonBorder
    }

    function subtleBorder(isOutdoor) {
        return isOutdoor ? outdoorBorderSubtle : borderSubtle
    }

    function dividerColor(isOutdoor) {
        return isOutdoor ? outdoorDivider : divider
    }

    function statusColor(status, isOutdoor) {
        var s = ("" + status).toLowerCase()
        if (s === "ok" || s === "success" || s === "connected" || s === "paired") {
            return isOutdoor ? outdoorOk : ok
        } else if (s === "warn" || s === "warning" || s === "reconnecting" || s === "lost" || s === "commlost") {
            return isOutdoor ? outdoorWarn : warn
        } else if (s === "err" || s === "error" || s === "danger" || s === "failed") {
            return isOutdoor ? outdoorErr : err
        } else if (s === "accentpill" || s === "accent" || s === "searching" || s === "discovering" || s === "syncing" || s === "connecting") {
            return isOutdoor ? outdoorAccent : accent
        } else {
            return isOutdoor ? outdoorNeutral : neutral
        }
    }

    function statusBackgroundColor(status, isOutdoor) {
        var s = ("" + status).toLowerCase()
        if (s === "ok" || s === "success" || s === "connected" || s === "paired") {
            return isOutdoor ? outdoorOkBg : okBg
        } else if (s === "warn" || s === "warning" || s === "reconnecting" || s === "lost" || s === "commlost") {
            return isOutdoor ? outdoorWarnBg : warnBg
        } else if (s === "err" || s === "error" || s === "danger" || s === "failed") {
            return isOutdoor ? outdoorErrBg : errBg
        } else if (s === "accentpill" || s === "accent" || s === "searching" || s === "discovering" || s === "syncing" || s === "connecting") {
            return isOutdoor ? outdoorCardTint : cardTint
        } else {
            return isOutdoor ? outdoorNeutralBg : neutralBg
        }
    }
}

