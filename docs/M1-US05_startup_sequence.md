# M1-US05 — Startup Sequence Fix

Documents the PulseGCS startup gate that ensures users see the ink splash before MainWindow chrome.

## Root cause (stock custom overlay behavior)

1. **Wrong ordering** — `CustomPlugin::createRootWindow()` loaded `MainWindow.qml` before attaching `SplashScreen.qml`, so the full UI tree built while `visible: true`.
2. **Android splash dismissed too early** — `JNI_OnLoad` called `hideSplashScreen(333)` while QML startup often takes seconds, leaving a blank `#071A2B` gap.
3. **MainWindow activity during splash** — `firstRunPromptManager.nextPrompt()` could run under the splash overlay.
4. **No content suppression** — underlying MainWindow children could bleed through during splash fade-out.

## Target sequence

```text
OS splash (#071A2B, sticky)
  → precompile SplashScreen.qml
  → load MainWindow (visible=false)
  → suppress content opacity, attach splash overlay
  → show window (first Qt frame = splash only)
  → splashCompleted
  → restore opacity, startupFinished, hide OS splash (Android)
  → first-run prompts
```

## Implementation

| Component | File | Role |
|-----------|------|------|
| Startup gate | `custom/src/PulseGCSStartupController.*` | `active` property + `startupFinished` signal |
| Splash attach | `custom/src/CustomPlugin.cc` | Precompile splash, hide window, suppress content, `SIGNAL`→slot connect |
| MainWindow gate | `custom/qml/QGroundControl/MainWindow.qml` | `visible: false`, defer `firstRunPromptManager` until `startupFinished` |
| Android sticky | `custom/android/AndroidManifest.xml` | `splash_screen_sticky=true` |
| Android defer | `src/Android/AndroidInit.cc` | Skip `hideSplashScreen(333)` when `QGC_CUSTOM_BUILD` |
| Android handoff | `CustomPlugin::_onSplashCompleted()` | `hideSplashScreen(0)` on splash complete |

## Android sticky splash rationale

The OS drawable (`custom/android/res/drawable/splashscreen.xml`) is flat `#071A2B`, matching the QML splash ground. Sticky mode keeps that drawable visible until PulseGCS explicitly hides it after the QML splash is mounted — eliminating the blank gap between OS splash and Qt content.

## Verification checklist

### Desktop

- [ ] `just build` succeeds
- [ ] Cold launch: first frame is ink + splash (not map/toolbar chrome)
- [ ] MainWindow UI not visible during splash animation
- [ ] Splash completes → MainWindow appears without flicker
- [ ] Repeat 3–5 cold launches

### Android

- [ ] APK build succeeds (`custom/tools/build_android_release.sh` or project Android preset)
- [ ] Cold start: OS `#071A2B` → QML splash (no blank gap) → MainWindow
- [ ] No double-splash UX regression (static OS ink → animated QML brand on same color)
- [ ] Warm relaunch: sequence stable
- [ ] First-run prompts appear only after splash

## Explicit non-goals

- No M1-US06 theme/palette changes in this story
- No MainWindow layout or navigation changes beyond startup gating
- No `QThread::sleep` or blocking UI-thread waits (splash uses `Timer` in QML)
