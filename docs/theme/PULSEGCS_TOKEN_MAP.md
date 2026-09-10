# PulseGCS Token Map (Option A — Aperture Cyan)

Maps PulseGCS brand tokens to QGroundControl `QGCPalette` roles for `CustomPlugin::paletteOverride()`.

**Source of truth (at implementation):** `custom/src/PulseGCSThemeTokens.h`

**Mechanism:** `QGCCorePlugin::paletteOverride()` in `custom/src/CustomPlugin.cc`, using a `setThemedRole()` helper so **Light (Outdoor)** and **Dark (Indoor)** slots receive tailored, theme-appropriate values.

---

## Brand Tokens (Locked)

### Indoor Theme Tokens (Dark — Command Center)

| Token | Hex | Alpha | Usage |
|-------|-----|-------|-------|
| `ink` | `#071A2B` | 100% | Deepest background, window chrome |
| `inkDisabled` | `#071A2B` | 70% | Disabled window background |
| `inkTransparent` | `#071A2B` | 80% | Translucent window background |
| `surfaceToolbar` | `#101F22` | 100% | Top ribbon / toolbar fill |
| `surfacePanel` | `#0D2A40` | 100% | Side panels, cards, shaded regions |
| `surfacePanelDisabled` | `#0D2A40` | 70% | Disabled panels and cards |
| `surfaceElevated` | `#1E3B52` | 100% | Borders, dividers, elevated chrome |
| `surfaceElevatedDisabled` | `#1E3B52` | 70% | Disabled elevated borders |
| `textPrimary` | `#EAF2F7` | 100% | Primary labels on dark surfaces |
| `textMuted` | `#7E96AB` | 100% | Disabled / secondary text |
| `textMeta` | `#5E778C` | 100% | Tertiary labels (version, metadata) |
| `accent` | `#11BED4` | 100% | Primary UI accent (buttons, mission line, active states) |
| `accentHover` | `#0EA0B4` | 100% | Hover / pressed highlight |
| `accentCore` | `#00C4DE` | 100% | Splash brand mark diamond (splash only) |
| `cardTint` | `#9CDAE2` | 100% | Mission editor card highlight |
| `cardTintDisabled` | `#9CDAE2` | 70% | Disabled card highlight |
| `buttonSurface` | `#1A2F33` | 100% | Default button fill on dark chrome |
| `buttonSurfaceDisabled` | `#1A2F33` | 70% | Disabled button fill |
| `surveyPolygonFillIndoor` | `#11BED4` | 40% | Survey / corridor polygon fill (Indoor) |

### Outdoor Theme Tokens (Light — Sunlight High-Contrast)

| Token | Hex | Alpha | Usage |
|-------|-----|-------|-------|
| `outdoorWindow` | `#FFFFFF` | 100% | Base light background |
| `outdoorWindowDisabled` | `#F0F0F0` | 100% | Disabled light window background |
| `outdoorWindowTransparent`| `#FFFFFF` | 80% | Translucent light window |
| `outdoorWindowShade` | `#E8EEF2` | 100% | Soft grey panel surface |
| `outdoorWindowShadeDisabled` | `#E8EEF2` | 70% | Disabled panel surface |
| `outdoorWindowShadeLight` | `#D0DCE4` | 100% | Card borders, subtle dividers |
| `outdoorWindowShadeLightDisabled` | `#D0DCE4` | 70% | Disabled borders |
| `outdoorWindowShadeDark` | `#B8C8D4` | 100% | High-contrast borders / map widget frame |
| `outdoorWindowShadeDarkDisabled` | `#B8C8D4` | 70% | Disabled dark borders |
| `outdoorToolbar` | `#F5F8FA` | 100% | Toolbar fill in light mode |
| `outdoorTextPrimary` | `#1A2B3C` | 100% | High-contrast deep navy text |
| `outdoorTextMuted` | `#7E96AB` | 100% | Secondary / disabled text |
| `outdoorTextMeta` | `#5E778C` | 100% | Tertiary metadata text |
| `outdoorAccent` | `#11BED4` | 100% | Aperture Cyan accent (outdoor) |
| `outdoorAccentHover` | `#0EA0B4` | 100% | Hover / pressed state (outdoor) |
| `outdoorCardTint` | `#E0F7FA` | 100% | Light cyan tint for mission cards |
| `outdoorCardTintDisabled` | `#E0F7FA` | 70% | Disabled card tint |
| `outdoorButtonSurface` | `#FFFFFF` | 100% | Button fill on light surfaces |
| `outdoorButtonSurfaceDisabled` | `#E8EEF2` | 100% | Disabled button fill |
| `surveyPolygonFillOutdoor` | `#11BED4` | 50% | Survey / corridor polygon fill (Outdoor) |

---

## Token → QGCPalette Role Mapping

### Surfaces & Backgrounds

| QGCPalette Role | Outdoor (Light) Enabled | Outdoor (Light) Disabled | Indoor (Dark) Enabled | Indoor (Dark) Disabled |
|-----------------|------------------------|-------------------------|----------------------|-----------------------|
| `window` | `#FFFFFF` (`outdoorWindow`) | `#F0F0F0` (`outdoorWindowDisabled`) | `#071A2B` (`ink`) | `#071A2B` @ 70% (`inkDisabled`) |
| `windowTransparent` | `#FFFFFF` @ 80% (`outdoorWindowTransparent`) | `#F0F0F0` (`outdoorWindowDisabled`) | `#071A2B` @ 80% (`inkTransparent`) | `#071A2B` @ 70% (`inkDisabled`) |
| `windowShade` | `#E8EEF2` (`outdoorWindowShade`) | `#E8EEF2` @ 70% (`outdoorWindowShadeDisabled`) | `#0D2A40` (`surfacePanel`) | `#0D2A40` @ 70% (`surfacePanelDisabled`) |
| `windowShadeLight` | `#D0DCE4` (`outdoorWindowShadeLight`) | `#D0DCE4` @ 70% (`outdoorWindowShadeLightDisabled`) | `#1E3B52` (`surfaceElevated`) | `#1E3B52` @ 70% (`surfaceElevatedDisabled`) |
| `windowShadeDark` | `#B8C8D4` (`outdoorWindowShadeDark`) | `#B8C8D4` @ 70% (`outdoorWindowShadeDarkDisabled`) | `#071A2B` (`ink`) | `#071A2B` @ 70% (`inkDisabled`) |
| `toolbarBackground` | `#F5F8FA` (`outdoorToolbar`) | `#F5F8FA` (`outdoorToolbar`) | `#101F22` (`surfaceToolbar`) | `#101F22` (`surfaceToolbar`) |
| `missionItemEditor` | `#E0F7FA` (`outdoorCardTint`) | `#E0F7FA` @ 70% (`outdoorCardTintDisabled`) | `#9CDAE2` (`cardTint`) | `#9CDAE2` @ 70% (`cardTintDisabled`) |

### Text & Labels

| QGCPalette Role | Outdoor (Light) Enabled | Outdoor (Light) Disabled | Indoor (Dark) Enabled | Indoor (Dark) Disabled |
|-----------------|------------------------|-------------------------|----------------------|-----------------------|
| `text` | `#1A2B3C` (`outdoorTextPrimary`) | `#7E96AB` (`outdoorTextMuted`) | `#EAF2F7` (`textPrimary`) | `#7E96AB` (`textMuted`) |
| `buttonText` | `#1A2B3C` (`outdoorTextPrimary`) | `#7E96AB` (`outdoorTextMuted`) | `#EAF2F7` (`textPrimary`) | `#7E96AB` (`textMuted`) |
| `buttonHighlightText` | `#1A2B3C` (`outdoorTextPrimary`) | `#7E96AB` (`outdoorTextMuted`) | `#EAF2F7` (`textPrimary`) | `#7E96AB` (`textMuted`) |
| `primaryButtonText` | `#1A2B3C` (`outdoorTextPrimary`) | `#7E96AB` (`outdoorTextMuted`) | `#EAF2F7` (`textPrimary`) | `#7E96AB` (`textMuted`) |
| `textFieldText` | `#1A2B3C` (`outdoorTextPrimary`) | `#7E96AB` (`outdoorTextMuted`) | `#EAF2F7` (`textPrimary`) | `#7E96AB` (`textMuted`) |
| `warningText` | `#B30000` | `#CC0808` | `#F85761` | `#CC0808` |

### Controls & Inputs

| QGCPalette Role | Outdoor (Light) Enabled | Outdoor (Light) Disabled | Indoor (Dark) Enabled | Indoor (Dark) Disabled |
|-----------------|------------------------|-------------------------|----------------------|-----------------------|
| `button` | `#FFFFFF` (`outdoorButtonSurface`) | `#E8EEF2` (`outdoorButtonSurfaceDisabled`) | `#1A2F33` (`buttonSurface`) | `#1A2F33` @ 70% (`buttonSurfaceDisabled`) |
| `buttonBorder` | `#11BED4` (`outdoorAccent`) | `#D0DCE4` (`outdoorWindowShadeLight`) | `#11BED4` (`accent`) | `#1E3B52` (`surfaceElevated`) |
| `buttonHighlight` | `#0EA0B4` (`outdoorAccentHover`) | `#D0DCE4` (`outdoorWindowShadeLight`) | `#0EA0B4` (`accentHover`) | `#1E3B52` (`surfaceElevated`) |
| `primaryButton` | `#11BED4` (`outdoorAccent`) | `#E8EEF2` (`outdoorButtonSurfaceDisabled`) | `#11BED4` (`accent`) | `#1A2F33` @ 70% (`buttonSurfaceDisabled`) |
| `textField` | `#FFFFFF` (`outdoorWindow`) | `#E8EEF2` (`outdoorWindowShade`) | `#0D2A40` (`surfacePanel`) | `#0D2A40` @ 70% (`surfacePanelDisabled`) |
| `groupBorder` | `#D0DCE4` (`outdoorWindowShadeLight`) | `#D0DCE4` @ 70% (`outdoorWindowShadeLightDisabled`) | `#1E3B52` (`surfaceElevated`) | `#1E3B52` @ 70% (`surfaceElevatedDisabled`) |
| `toolStripHoverColor` | `#0EA0B4` (`outdoorAccentHover`) | `#D0DCE4` (`outdoorWindowShadeLight`) | `#0EA0B4` (`accentHover`) | `#1E3B52` (`surfaceElevated`) |
| `toolStripFGColor` | `#1A2B3C` (`outdoorTextPrimary`) | `#7E96AB` (`outdoorTextMuted`) | `#EAF2F7` (`textPrimary`) | `#7E96AB` (`textMuted`) |

### Brand, Mission & Map Accents

| QGCPalette Role | Outdoor (Light) Enabled | Outdoor (Light) Disabled | Indoor (Dark) Enabled | Indoor (Dark) Disabled |
|-----------------|------------------------|-------------------------|----------------------|-----------------------|
| `brandingPurple` | `#11BED4` (`outdoorAccent`) | `#11BED4` | `#11BED4` (`accent`) | `#11BED4` |
| `brandingBlue` | `#11BED4` (`outdoorAccent`) | `#11BED4` | `#11BED4` (`accent`) | `#11BED4` |
| `mapMissionTrajectory` | `#11BED4` (`outdoorAccent`) | `#11BED4` | `#11BED4` (`accent`) | `#11BED4` |
| `mapIndicator` | `#11BED4` (`outdoorAccent`) | `#11BED4` | `#11BED4` (`accent`) | `#11BED4` |
| `mapIndicatorChild` | `#0EA0B4` (`outdoorAccentHover`) | `#0EA0B4` | `#0EA0B4` (`accentHover`) | `#0EA0B4` |
| `mapButton` | `#FFFFFF` (`outdoorButtonSurface`) | `#E8EEF2` (`outdoorButtonSurfaceDisabled`) | `#1A2F33` (`buttonSurface`) | `#1A2F33` @ 70% (`buttonSurfaceDisabled`) |
| `mapButtonHighlight` | `#0EA0B4` (`outdoorAccentHover`) | `#0EA0B4` | `#0EA0B4` (`accentHover`) | `#0EA0B4` |
| `mapWidgetBorderLight` | `#1A2B3C` (`outdoorTextPrimary`) | `#1A2B3C` | `#EAF2F7` (`textPrimary`) | `#EAF2F7` |
| `mapWidgetBorderDark` | `#B8C8D4` (`outdoorWindowShadeDark`) | `#B8C8D4` @ 70% (`outdoorWindowShadeDarkDisabled`) | `#071A2B` (`ink`) | `#071A2B` @ 70% (`inkDisabled`) |
| `modifiedParamValue` | `#11BED4` (`outdoorAccent`) | `#11BED4` | `#11BED4` (`accent`) | `#11BED4` |
| `photoCaptureButtonColor`| `#1A2B3C` (`outdoorTextPrimary`) | `#7E96AB` (`outdoorTextMuted`) | `#EAF2F7` (`textPrimary`) | `#7E96AB` (`textMuted`) |
| `surveyPolygonInterior` | `#11BED4` @ 50% (`surveyPolygonFillOutdoor`) | `#11BED4` @ 50% | `#11BED4` @ 40% (`surveyPolygonFillIndoor`) | `#11BED4` @ 40% |

---

## Roles Explicitly NOT Overridden (Safety / Semantics)

Leave at stock QGC values in **both** Light and Dark:

| Role | Reason |
|------|--------|
| `colorGreen` | Arming ready, GPS good, success |
| `colorYellow` | Caution |
| `colorOrange` | Warnings |
| `colorRed` | Errors, disarm, critical |
| `colorBlue` | Informational semantic |
| `colorGrey` | Neutral semantic |
| `colorYellowGreen` | Semantic |
| `alertBackground`, `alertBorder`, `alertText` | Alert banners |
| `statusPassedText`, `statusFailedText`, `statusPendingText` | Calibration status |
| `surveyPolygonTerrainCollision` | Terrain collision (red) |
| `videoCaptureButtonColor` | Record button stays red |

---

## Android Native Chrome

| Resource | Token | Hex |
|----------|-------|-----|
| `custom/android/res/values/apptheme.xml` — `statusBarColor`, `navigationBarColor`, `windowBackground` | `ink` | `#071A2B` |
| Splash drawable `splashscreen.xml` solid fill | `ink` | `#071A2B` |

---

## Implementation Notes

1. **`setThemedRole(colorInfo, lightEnabled, lightDisabled, darkEnabled, darkDisabled)`** — writes distinct hex values into `colorInfo[Light][*]` (Outdoor) and `colorInfo[Dark][*]` (Indoor).
2. Toggling indoor/outdoor theme in QGC Application Settings switches between the Dark Command Center palette and High-Contrast Outdoor palette.
3. `surveyPolygonInterior` provides translucent Aperture Cyan fill for survey grids and corridor scan areas, replacing stock green while leaving `surveyPolygonTerrainCollision` red.
