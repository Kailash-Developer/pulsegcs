# M1 — Upstream `src/` Hooks (PulseGCS Custom Build)

PulseGCS keeps almost all product work under `custom/`. These **four upstream files** are patched because the behaviour cannot be achieved from the custom overlay alone.

Related: [M1-US05_startup_sequence.md](M1-US05_startup_sequence.md)

---

## Summary

| File | Story | Why `custom/` is not enough |
|------|-------|-----------------------------|
| `src/Android/AndroidInit.cc` | US05 | OS splash is dismissed in `JNI_OnLoad` before `CustomPlugin` exists |
| `src/QGCApplication.cc` | US05 | `QGCPositionManager::init()` runs during core boot, before splash |
| `src/PositionManager/PositionManager.{h,cpp}` | US05 | Safe deferred `init()` after splash (one-shot guard) |
| `src/QmlControls/ColoredSvgImageProvider.cc` | US04 | `image://coloredsvg` bypasses the QML URL interceptor |

Custom counterparts: `custom/src/CustomPlugin.cc` (splash attach, `hideSplashScreen(0)`, calls `QGCPositionManager::init()` after splash), logo assets in `custom/res/`.

All hooks are guarded with `#ifndef QGC_CUSTOM_BUILD` or are harmless for stock QGC (ColoredSvg fallback only when `:/Custom/...` exists).

---

## 1. Android sticky splash — `src/Android/AndroidInit.cc`

**Problem:** `JNI_OnLoad` calls `hideSplashScreen(333)` ~333 ms after process start. QML splash often needs longer; this leaves a blank `#071A2B` gap before Qt content is ready.

**Change:** Skip the early hide when `QGC_CUSTOM_BUILD` is defined.

```cpp
#ifndef QGC_CUSTOM_BUILD
    QNativeInterface::QAndroidApplication::hideSplashScreen(333);
#endif
```

**Custom side:** `CustomPlugin` calls `hideSplashScreen(0)` after the QML splash overlay is mounted (or on fail-open). Android manifest uses sticky splash (`custom/android/AndroidManifest.xml`).

---

## 2. Deferred location init — `src/QGCApplication.cc`

**Problem:** `_initForNormalAppBoot()` always calls `QGCPositionManager::instance()->init()`, which can show the OS location permission dialog while the splash is still visible.

**Change:** Skip boot-time `init()` for custom builds.

```cpp
#ifndef QGC_CUSTOM_BUILD
    QGCPositionManager::instance()->init();
#else
    // PulseGCS: location permission is requested after splash (CustomPlugin).
#endif
```

**Custom side:** `CustomPlugin::createRootWindow()` / fail-open calls `QGCPositionManager::instance()->init()` after splash completes or on splash failure.

---

## 3. One-shot position manager init — `src/PositionManager/PositionManager.{h,cpp}`

**Problem:** After deferring boot-time `init()`, splash completion must call `init()` without double-initializing if something else invokes it later.

**Change:** Guard `init()` with `_initCalled` (early return on second call).

**Custom side:** Same as §2 — single deferred call from `CustomPlugin` after splash.

---

## 4. Custom logo loading for coloured SVG — `src/QmlControls/ColoredSvgImageProvider.cc`

**Problem:** Toolbar and other UI use `image://coloredsvg/...`. That provider does not go through `CustomOverrideInterceptor`, so `:/res/QGCLogoFull.svg` never maps to `:/Custom/res/...`.

**Change:** If `:/Custom` + original path exists on disk in the resource system, use it instead.

```cpp
if (path.startsWith(QLatin1String(":/"))) {
    const QString customPath = QStringLiteral(":/Custom") + path.mid(1);
    if (QFile::exists(customPath)) {
        path = customPath;
    }
}
```

**Custom side:** Handoff logo SVGs and `custom/custom.qrc` aliases (`QGCLogoFull.svg`, etc.). Stock QGC is unchanged when no custom resource exists.

---

## Revert / upstream merge notes

- Removing PulseGCS: revert these four files; custom overlay alone will not restore splash timing, deferred location, or coloured-SVG logos.
- Upstream QGC updates: re-apply or reconcile these small hunks when merging new QGC releases.
- Prefer keeping diffs minimal; do not fork broader `src/` behaviour for M1.

---

## PR checklist blurb (copy-paste)

Minimal `src/` hooks (cannot do in `custom/` alone):

1. `AndroidInit.cc` — skip early `hideSplashScreen`; JNI runs before CustomPlugin  
2. `QGCApplication.cc` + `PositionManager` — defer location init; CustomPlugin calls `init()` after splash  
3. `ColoredSvgImageProvider.cc` — Pulse logos for `image://coloredsvg` (interceptor does not apply)

All other M1 work is in `custom/`.
