# PulseGCS Component Coverage Map

Defines **where** the Option A theme applies in QGroundControl. Only listed areas should reflect PulseGCS colours; everything else stays stock.

**How theming propagates:** `paletteOverride()` → `QGCPalette` roles → shared QML controls (`QGCButton`, `QGCPopupDialog`, etc.) → ~170+ screens. One role change updates every instance of that control type.

---

## Tier 1 — Automatic (palette override only)

No per-screen QML edits required. Override the listed `QGCPalette` roles in `CustomPlugin::paletteOverride()`.

### Chrome and navigation

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Top ribbon / toolbar | `src/Toolbar/FlyViewToolBar.qml`, `src/Toolbar/PlanViewToolBar.qml`, `src/MainWindow/MainWindow.qml` | `toolbarBackground`, `window`, `windowTransparent`, `brandingPurple` |
| Toolbar indicators | `src/Toolbar/MainStatusIndicator.qml`, `BatteryIndicator.qml`, `GPSIndicator.qml`, etc. | `text`, `buttonHighlight`, `windowShade` |
| Left tool strip / side rail | `src/QmlControls/ToolStrip.qml`, `ToolStripHoverButton.qml`, `ToolStripDropPanel.qml` | `toolStripHoverColor`, `toolStripFGColor`, `buttonHighlight`, `buttonHighlightText`, `windowTransparent` |
| View switcher / tabs | `src/QmlControls/QGCTabButton.qml` | `button`, `buttonBorder`, `buttonHighlight` |
| Tool drawer | `src/MainWindow/MainWindow.qml` (tool drawer) | `window`, `windowShade`, `text` |

### Shared controls (app-wide)

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Buttons | `QGCButton.qml`, `QGCRoundButton.qml`, `QGCColumnButton.qml`, `SubMenuButton.qml` | `button`, `primaryButton`, `buttonBorder`, `buttonHighlight`, `buttonText`, `primaryButtonText` |
| Toggles / checkboxes | `QGCCheckBox.qml`, `SliderSwitch.qml`, `QGCCheckBoxSlider.qml` | `button`, `buttonBorder`, `buttonHighlight` |
| Cards / panels / sections | `QGCPopupDialog.qml`, `DropPanel.qml`, `ConfigSection.qml`, `MvPanelPage.qml` | `window`, `windowShade`, `windowShadeLight`, `windowShadeDark`, `groupBorder` |
| Form controls | `QGCTextField.qml`, `QGCComboBox.qml`, `QGCSlider.qml`, `FactValueSlider.qml` | `textField`, `textFieldText`, `text`, `buttonHighlight` |
| Section headers | `SectionHeader.qml` | `text`, `windowShade` |

### Fly View

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Guided confirm / slide dialogs | `src/FlyView/GuidedActionConfirm.qml`, `GuidedValueSlider.qml` | `windowShade`, `text`, `buttonHighlight`, `groupBorder` |
| Mission complete dialog | `FlyViewMissionCompleteDialog.qml` | `window`, `text`, `primaryButton` |
| Telemetry bar / side panels | `TelemetryValuesBar.qml`, `FlyViewTopRightPanel.qml` | `window`, `windowTransparent`, `text` |
| Multi-vehicle list | `MultiVehicleList.qml` | `windowShade`, `text`, `buttonHighlight` |
| Map UI chrome (not imagery) | `PhotoVideoControl.qml` | `mapButton`, `mapButtonHighlight` |

### Plan View

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Mission editor cards | `MissionItemEditor.qml`, `SimpleItemEditor.qml` | `missionItemEditor`, `windowShade`, `buttonHighlight`, `groupBorder`, `text` |
| Right panel | `PlanViewRightPanel.qml` | `window`, `windowShade`, `text` |
| Plan tree | `PlanTreeView.qml` | `windowShade`, `text`, `buttonHighlight` |
| Mission status | `MissionItemStatus.qml` | `text`, `buttonHighlight` |
| Toolbar | `PlanViewToolBar.qml`, `PlanToolBarIndicators.qml` | `toolbarBackground`, `text` |
| Map mission visuals | `QGCMapPolylineVisuals.qml`, `MissionItemIndexLabel.qml` | `mapMissionTrajectory`, `mapIndicator`, `mapIndicatorChild` |

### Vehicle Setup

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Config shell | `VehicleConfigView.qml`, `SetupPage.qml` | Inherits Tier 1 shared controls |
| Firmware plugins | `src/AutoPilotPlugins/**` (PX4, APM, Common) | Inherits Tier 1 shared controls |
| Calibration / joystick | `JoystickComponentButtons.qml`, `RemoteControlCalibration.qml` | `windowShade`, `text`, `buttonHighlight` |

### App Settings

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Settings shell | `AppSettings.qml` | `window`, `windowShade`, `text` |
| Link / comms | `LinkConfigurationManager.qml`, `TcpSettings.qml`, `BluetoothSettings.qml` | Inherits shared controls |
| Help (custom redirect) | `custom/qml/HelpSettings.qml` | Inherits shared controls |
| Offline maps | `OfflineMapEditor.qml` | `window`, `text`, `button` |

### Analyze

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Analyze shell | `AnalyzeView.qml`, `AnalyzePage.qml` | `window`, `text` |
| MAVLink inspector | `MAVLinkInspectorPage.qml`, `MAVLinkChart.qml` | `window`, `text` (chart series → Tier 2 if needed) |
| Log viewer | `LogViewerPage.qml`, `LogViewerFieldsPanel.qml` | `window`, `text` |
| Vibration | `VibrationPage.qml` | `window`, `text` |

### Parameters

| UI area | Key files | Palette roles |
|---------|-----------|---------------|
| Parameter editor | `ParameterEditor.qml`, `ParameterEditorDialog.qml` | `text`, `modifiedParamValue`, `windowShade` |

---

## Tier 2 — Targeted interceptor fixes (colour-only)

Palette cannot reach these; copy upstream QML to `custom/qml/QGroundControl/**` and change **colour only**.

| UI area | File | Issue | Proposed fix |
|---------|------|-------|--------------|
| Terrain profile flight line | `src/PlanView/TerrainStatus.qml` | `flightSeries.color: "orange"` | `qgcPal.mapMissionTrajectory` or accent |
| Corridor scan map line | `src/PlanView/CorridorScanMapVisual.qml` | `lineColor: "#be781c"` | palette role |
| Log viewer chart series | `src/AnalyzeView/LogViewer/LogViewerChart.qml` | hard-coded hex | change only decorative series |
| Remaining grep hits | `src/**/*.qml` | `#be781c`, `#4A2C6D` decorative | map to accent / `mapMissionTrajectory` |

**Audit command (at implementation):**

```bash
rg '#be781c|#4A2C6D|#4a2c6d' src --glob '*.qml'
rg 'color:\s*"(orange|purple)"' src/PlanView --glob '*.qml'
```

---

## Tier 3 — Explicitly excluded (do not change)

| Area | Reason |
|------|--------|
| `colorGreen`, `colorRed`, `colorYellow`, `colorOrange`, `colorBlue`, `colorGrey` | Arming, alerts, traffic-light semantics |
| `alertBackground`, `alertBorder`, `alertText` | Warning banners |
| `statusPassedText`, `statusFailedText`, `statusPendingText` | Calibration / test status |
| `surveyPolygonTerrainCollision` | Safety collision warning |
| `videoCaptureButtonColor` | Record button (red) |
| `surveyPolygonInterior` | Coverage area fill (green) |
| Attitude instrument sky / ground | Aviation-standard colours |
| Map satellite / terrain imagery | No imagery changes |
| Vehicle position marker (red triangle) | Safety visibility |
| `QGCMapPalette` | Map overlay text contrast |
| Terrain graph `terrainSeries` (green), `collisionSeries` (red), `missingSeries` (yellow) | Semantic data series |

---

## Coverage summary

| Tier | Approx. scope | Effort |
|------|---------------|--------|
| Tier 1 | Ribbons, buttons, cards, panels, dialogs, editors, Setup, Settings, Analyze | One `paletteOverride()` implementation |
| Tier 2 | ~5–15 QML files with hard-coded decorative colours | Minimal interceptor copies |
| Tier 3 | Safety + map semantics | Zero changes |

---

## Related docs

- [PULSEGCS_TOKEN_MAP.md](PULSEGCS_TOKEN_MAP.md) — hex values per role
- [SCREENSHOT_ACCEPTANCE.md](SCREENSHOT_ACCEPTANCE.md) — visual sign-off checklist
