#pragma once

#include <QtGui/QColor>

namespace PulseGCSTheme
{

// Option A — Aperture Cyan (M1-US06 / M1-US07)

// ============================================================================
// Indoor Theme Tokens (Dark — Command Center)
// ============================================================================

inline QColor ink()
{
    return QColor(0x07, 0x1A, 0x2B);
}

inline QColor inkDisabled()
{
    return QColor(0x07, 0x1A, 0x2B, 0xB3);
}

inline QColor inkTransparent()
{
    return QColor(0x07, 0x1A, 0x2B, 0xCC);
}

inline QColor surfaceToolbar()
{
    return QColor(0x10, 0x1F, 0x22);
}

inline QColor surfacePanel()
{
    return QColor(0x0D, 0x2A, 0x40);
}

inline QColor surfacePanelDisabled()
{
    return QColor(0x0D, 0x2A, 0x40, 0xB3);
}

inline QColor surfaceElevated()
{
    return QColor(0x1E, 0x3B, 0x52);
}

inline QColor surfaceElevatedDisabled()
{
    return QColor(0x1E, 0x3B, 0x52, 0xB3);
}

inline QColor textPrimary()
{
    return QColor(0xEA, 0xF2, 0xF7);
}

inline QColor textMuted()
{
    return QColor(0x7E, 0x96, 0xAB);
}

inline QColor textMeta()
{
    return QColor(0x5E, 0x77, 0x8C);
}

inline QColor accent()
{
    return QColor(0x11, 0xBE, 0xD4);
}

inline QColor accentHover()
{
    return QColor(0x0E, 0xA0, 0xB4);
}

inline QColor accentCore()
{
    return QColor(0x00, 0xC4, 0xDE);
}

inline QColor cardTint()
{
    return QColor(0x9C, 0xDA, 0xE2);
}

inline QColor cardTintDisabled()
{
    return QColor(0x9C, 0xDA, 0xE2, 0xB3);
}

inline QColor buttonSurface()
{
    return QColor(0x1A, 0x2F, 0x33);
}

inline QColor buttonSurfaceDisabled()
{
    return QColor(0x1A, 0x2F, 0x33, 0xB3);
}

inline QColor surveyPolygonFillIndoor()
{
    return QColor(0x11, 0xBE, 0xD4, 0x66);
}

// ============================================================================
// Outdoor Theme Tokens (Light — Sunlight High-Contrast)
// ============================================================================

inline QColor outdoorWindow()
{
    return QColor(0xFF, 0xFF, 0xFF);
}

inline QColor outdoorWindowDisabled()
{
    return QColor(0xF0, 0xF0, 0xF0);
}

inline QColor outdoorWindowTransparent()
{
    return QColor(0xFF, 0xFF, 0xFF, 0xCC);
}

inline QColor outdoorWindowShade()
{
    return QColor(0xE8, 0xEE, 0xF2);
}

inline QColor outdoorWindowShadeDisabled()
{
    return QColor(0xE8, 0xEE, 0xF2, 0xB3);
}

inline QColor outdoorWindowShadeLight()
{
    return QColor(0xD0, 0xDC, 0xE4);
}

inline QColor outdoorWindowShadeLightDisabled()
{
    return QColor(0xD0, 0xDC, 0xE4, 0xB3);
}

inline QColor outdoorWindowShadeDark()
{
    return QColor(0xB8, 0xC8, 0xD4);
}

inline QColor outdoorWindowShadeDarkDisabled()
{
    return QColor(0xB8, 0xC8, 0xD4, 0xB3);
}

inline QColor outdoorToolbar()
{
    return QColor(0xF5, 0xF8, 0xFA);
}

inline QColor outdoorTextPrimary()
{
    return QColor(0x1A, 0x2B, 0x3C);
}

inline QColor outdoorTextMuted()
{
    return QColor(0x7E, 0x96, 0xAB);
}

inline QColor outdoorTextMeta()
{
    return QColor(0x5E, 0x77, 0x8C);
}

inline QColor outdoorAccent()
{
    return QColor(0x11, 0xBE, 0xD4);
}

inline QColor outdoorAccentHover()
{
    return QColor(0x0E, 0xA0, 0xB4);
}

inline QColor outdoorCardTint()
{
    return QColor(0xE0, 0xF7, 0xFA);
}

inline QColor outdoorCardTintDisabled()
{
    return QColor(0xE0, 0xF7, 0xFA, 0xB3);
}

inline QColor outdoorButtonSurface()
{
    return QColor(0xFF, 0xFF, 0xFF);
}

inline QColor outdoorButtonSurfaceDisabled()
{
    return QColor(0xE8, 0xEE, 0xF2);
}

inline QColor surveyPolygonFillOutdoor()
{
    return QColor(0x11, 0xBE, 0xD4, 0x80);
}

} // namespace PulseGCSTheme
