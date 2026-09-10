# PulseGCS Screenshot Acceptance (M1-US07)

Visual sign-off checklist for **Option A — Aperture Cyan**. Compare a built PulseGCS binary against the approved reference mocks (Fly View, Plan View, Survey editor).

**Rules**

- Colour and surface treatment only — no layout, spacing, or control changes
- Light and Dark QGC theme toggle must produce **identical** PulseGCS colours
- Safety semantics (green arming, red vehicle/record, battery/GPS traffic lights) stay stock

---

## Reference mocks

| Mock | Description |
|------|-------------|
| **Baseline** | Stock QGC Fly View — purple status circle, orange mission path, default chrome |
| **Option A — Fly** | Dark toolbar, cyan active nav icon, cyan dialog borders, cyan map path, dark side rail |
| **Option A — Plan** | Cyan mission segments and waypoints, cyan tab underline, cyan survey controls, cyan terrain graph |
| **Option A — Survey** | Cyan selected tool-strip button, cyan terrain checkbox, cyan profile graph stroke |

Reference images were provided during M1-US06/US07 planning (Option A mocks labelled in screenshots).

---

## Fly View checklist

| # | Element | Expected (Option A) | Palette role / fix |
|---|---------|---------------------|-------------------|
| F1 | Top toolbar background | Solid dark `#101F22`, not transparent | `toolbarBackground` |
| F2 | Active view icon (Fly/Plan) | Cyan outline or fill | `buttonHighlight`, `buttonBorder` |
| F3 | Status circle (e.g. "Ready To Fly") | Cyan ring/fill (not purple) | `brandingPurple` → accent |
| F4 | Status text "Ready To Fly" | Green text preserved | `colorGreen` (unchanged) |
| F5 | Goto / slide-to-confirm dialog | Cyan header or border | `groupBorder`, `buttonHighlight` |
| F6 | Mission path on map | Cyan (not orange) | `mapMissionTrajectory` |
| F7 | Left tool strip | Dark panel; cyan hover/active | `toolStripHoverColor`, `buttonHighlight` |
| F8 | Side telemetry / HUD chrome | Dark glass; cyan degree marks if shown | `window`, `groupBorder` |
| F9 | Vehicle marker on map | Red triangle (unchanged) | excluded |
| F10 | Record button | Red (unchanged) | `videoCaptureButtonColor` excluded |
| F11 | Battery / GPS / link icons | Green/amber/red semantics (unchanged) | semantic colours excluded |
| F12 | Attitude indicator | Sky blue / ground green (unchanged) | excluded |

---

## Plan View checklist

| # | Element | Expected (Option A) | Palette role / fix |
|---|---------|---------------------|-------------------|
| P1 | Mission polyline | Cyan | `mapMissionTrajectory` |
| P2 | Waypoint circles / labels | Cyan fill or stroke | `mapIndicator`, `mapIndicatorChild` |
| P3 | Mission / Fence / Rally tabs | Cyan active underline | `buttonHighlight`, `buttonBorder` |
| P4 | Right mission editor panel | Dark `#0D2A40` surface | `windowShade`, `missionItemEditor` |
| P5 | Active altitude / numeric field | Cyan focus ring | `buttonBorder`, `buttonHighlight` |
| P6 | Survey mode button (selected) | Solid cyan fill | `primaryButton`, `buttonHighlight` |
| P7 | "Vehicle follows terrain" checkbox | Cyan check fill | `buttonHighlight` |
| P8 | Terrain profile graph — flight line | Cyan stroke (not orange) | Tier 2: `TerrainStatus.qml` |
| P9 | Terrain graph — terrain line | Green (semantic, unchanged) | excluded |
| P10 | Terrain graph — collision line | Red (semantic, unchanged) | excluded |
| P11 | Planned home marker | Red / semantic (unchanged) | excluded |
| P12 | Loiter / home green markers | Green (unchanged) | excluded |

---

## Full-app checklist (beyond Fly / Plan)

| # | View | Check |
|---|------|-------|
| A1 | Vehicle Setup | Dark panels, cyan highlights on active section, stock safety colours |
| A2 | App Settings | Same palette as Fly/Plan; readable text on dark surfaces |
| A3 | Analyze (MAVLink, Log, Vibration) | Window chrome themed; data series colours semantic unless decorative |
| A4 | Parameter editor | Modified values cyan; failed/passed status colours unchanged |
| A5 | Indicator drawer pages | `windowShade` panels, cyan accents |
| A6 | Popups / `QGCPopupDialog` | Dark card, cyan border on focus actions |

---

## Indoor / outdoor regression

| # | Test | Pass criteria |
|---|------|---------------|
| T1 | Toggle QGC theme Light ↔ Dark in Settings | Cosmetic colours **identical** (toolbar, mission line, buttons) |
| T2 | Screenshot diff Fly View both modes | No visible accent colour shift |
| T3 | Screenshot diff Plan View both modes | No visible accent colour shift |

---

## Safety regression (must match stock QGC)

| # | Element | Pass criteria |
|---|---------|---------------|
| S1 | GPS indicator | Green / amber / red states distinguishable |
| S2 | Battery indicator | Charge levels colour-coded as stock |
| S3 | Arming text | Green "Ready To Fly" / red disarm states |
| S4 | Alerts / preflight warnings | Yellow/red alert banners unchanged |
| S5 | Terrain collision | Red warning in graph and survey |
| S6 | Record / video | Red record button |

---

## Layout regression (no structural changes)

| # | Check | Method |
|---|-------|--------|
| L1 | No control repositioning | Visual compare; no anchor/size diffs in custom QML |
| L2 | `objectName` inventory unchanged | Grep custom interceptors vs upstream |
| L3 | Navigation unchanged | Fly ↔ Plan ↔ Setup ↔ Settings flows work |

---

## Functional smoke test

| # | Action | Pass |
|---|--------|------|
| M1 | Launch app | Splash → MainWindow (M1-US05); theme visible immediately after |
| M2 | Connect vehicle (or mock link) | Telemetry renders; colours don't break readability |
| M3 | Switch Fly ↔ Plan | Toolbar and tool strip themed in both |
| M4 | Open mission editor | Cards and map line cyan |
| M5 | Open Settings | Panels themed |
| M6 | Guided action dialog | Cyan border; slide control works |

---

## Sign-off

| Reviewer | Date | Fly | Plan | Full-app | Safety | Notes |
|----------|------|-----|------|----------|--------|-------|
| | | ☐ | ☐ | ☐ | ☐ | |

---

## Related docs

- [PULSEGCS_TOKEN_MAP.md](PULSEGCS_TOKEN_MAP.md)
- [COMPONENT_COVERAGE.md](COMPONENT_COVERAGE.md)
