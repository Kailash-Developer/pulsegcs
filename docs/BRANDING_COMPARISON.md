# PulseGCS vs QGroundControl Branding & Asset Comparison Table

This document provides a comprehensive mapping between upstream **QGroundControl Core Code/Assets** and **PulseGCS Custom Overlay Code/Assets**, detailing the exact file paths, redirection mechanisms, and current implementation status.

---

## 1. Summary Status Matrix

| Branding Category | Upstream Core Path | PulseGCS Custom Overlay Path | Mechanism / Strategy | Status |
|---|---|---|---|---|
| **App Title & Metadata** | `CMakeLists.txt`<br>`cmake/modules/Git.cmake` | `custom/cmake/CustomOverrides.cmake` | CMake Cache Variable Override (`QGC_APP_NAME="PulseGCS"`) | **Changes Made** |
| **Android Package Identifier** | `android/AndroidManifest.xml` (`org.mavlink.qgroundcontrol`) | `custom/cmake/CustomOverrides.cmake`<br>`custom/android/AndroidManifest.xml` | CMake Override + Directory Overlay (`com.pulsegcs.app`) | **Changes Made** |
| **Android Application Label** | `android/res/values/strings.xml` (`QGroundControl`) | `custom/android/AndroidManifest.xml` (`-- %%INSERT_APP_NAME%% --`) | CMake manifest token replacement to `PulseGCS` | **Changes Made** |
| **Android Launcher Icons (Mipmap)** | `android/res/mipmap-*/ic_launcher.png` | `custom/android/res/mipmap-*/ic_launcher.png` | Directory Overlay (PulseGCS Cyan/Slate Icons) | **Changes Made** *(Replace with final PNGs if desired)* |
| **Android Adaptive Icon Foreground** | `android/res/drawable/ic_launcher_foreground.xml` | `custom/android/res/drawable/ic_launcher_foreground.xml` | Vector XML Overlay (Pulse Wave + Radar motif) | **Changes Made** |
| **Android Adaptive Icon Background** | `android/res/values/ic_launcher_colors.xml` (`#4B2C6D` Purple) | `custom/android/res/values/ic_launcher_colors.xml` (`#121820` Dark Slate) | Values XML Overlay (Replaced QGC purple with PulseGCS dark theme) | **Changes Made** |
| **Android Splash Theme & Background** | `android/res/values/apptheme.xml`<br>`android/res/values/splashscreentheme.xml` | `custom/android/res/values/apptheme.xml`<br>`custom/android/res/values/splashscreentheme.xml` | Values XML Overlay (Replaced purple/black with `#121820` and API 31+ support) | **Changes Made** |
| **Android Splash Layer List** | `android/res/drawable/splashscreen.xml` | `custom/android/res/drawable/splashscreen.xml` | Drawable XML Overlay (`#121820` background) | **Changes Made** |
| **Android Splash/Drawable Icons** | `android/res/drawable-*/icon.png` (Purple QGC icons) | `custom/android/res/drawable-*/icon.png` | Directory Overlay (Replaced purple icons with PulseGCS icons) | **Changes Made** *(Replace with final PNGs if desired)* |
| **Help Section / Docs & Links** | `src/AppSettings/HelpSettings.qml`<br>(QGC documentation & forums) | `custom/qml/HelpSettings.qml`<br>`custom/custom.qrc` | `CustomOverrideInterceptor` QML redirect to PulseGCS support & community | **Changes Made** |
| **Main Toolbar / Navigation Logo** | `resources/QGCLogoFull.svg`<br>(`qrc:/res/QGCLogoFull.svg`) | `custom/res/Custom/res/QGCLogoFull.svg`<br>`custom/custom.qrc` | `CustomOverrideInterceptor` (`qrc:/Custom/res/QGCLogoFull.svg`) | **Changes Made** *(Replace with final SVG if desired)* |
| **White / Inverted Header Logo** | `resources/QGCLogoWhite.svg`<br>(`qrc:/res/QGCLogoWhite.svg`) | `custom/res/Custom/res/QGCLogoWhite.svg`<br>`custom/custom.qrc` | `CustomOverrideInterceptor` (`qrc:/Custom/res/QGCLogoWhite.svg`) | **Changes Made** *(Replace with final SVG if desired)* |
| **Directional Map Arrow Logo** | `resources/QGCLogoArrow.svg`<br>(`qrc:/res/QGCLogoArrow.svg`) | `custom/res/Custom/res/QGCLogoArrow.svg`<br>`custom/custom.qrc` | `CustomOverrideInterceptor` (`qrc:/Custom/res/QGCLogoArrow.svg`) | **Changes Made** *(Replace with final SVG if desired)* |
| **Desktop / In-App Splash Screen** | `resources/SplashScreen.png`<br>(`qrc:/res/SplashScreen.png`) | `custom/res/Custom/res/SplashScreen.png`<br>`custom/custom.qrc` | `CustomOverrideInterceptor` (`qrc:/Custom/res/SplashScreen.png`) | **Changes Made** *(Drop high-res original PNG here)* |
| **Desktop Window Icon** | `resources/icons/qgroundcontrol.ico`<br>(`qrc:/res/qgroundcontrol.ico`) | `custom/res/Custom/res/qgroundcontrol.ico`<br>`custom/custom.qrc` | `CustomOverrideInterceptor` (`qrc:/Custom/res/qgroundcontrol.ico`) | **Changes Made** *(Drop original .ico here)* |
| **Linux AppImage Scalable Icon** | `resources/icons/qgroundcontrol.svg` | `custom/res/icons/pulsegcs.svg` | CMake Override (`QGC_APPIMAGE_ICON_SCALABLE_PATH`) | **Changes Made** *(Drop original .svg here)* |
| **Windows Executable Icon** | `deploy/windows/WindowsQGC.ico` | `custom/deploy/windows/WindowsQGC.ico` | CMake Override (`QGC_WINDOWS_ICON_PATH`) | **Changes Made** *(Drop original .ico here)* |
| **Windows Installer Header** | `deploy/windows/installheader.bmp` | `custom/deploy/windows/installheader.bmp` | CMake Override (`QGC_WINDOWS_INSTALL_HEADER_PATH`) | **Changes Made** *(Drop original .bmp here)* |
| **macOS Bundle Icon** | `resources/icons/mac.icns` | `custom/res/icons/pulsegcs.icns` | CMake Override (`QGC_MACOS_ICON_PATH`) | **Yet to change** *(Optional for macOS releases)* |

---

## 2. Directory Paths for User Original Artwork Drop-in

When you are ready to drop in your final high-resolution logos and raster graphics, place your files directly into these exact paths:

### A. In-App QML & Desktop Assets
1. **Primary In-App Logo (Navigation Toolbar & Welcome)**:
   - `custom/res/Custom/res/QGCLogoFull.svg`
2. **Inverted / White Header Logo**:
   - `custom/res/Custom/res/QGCLogoWhite.svg`
3. **Directional Arrow / Marker Logo**:
   - `custom/res/Custom/res/QGCLogoArrow.svg`
4. **Desktop / In-App Startup Splash Screen**:
   - `custom/res/Custom/res/SplashScreen.png`
5. **Desktop Window / Taskbar Icon**:
   - `custom/res/Custom/res/qgroundcontrol.ico`

### B. Android Launcher & Splash Assets
1. **Android Splash & Drawable Icons**:
   - `custom/android/res/drawable-mdpi/icon.png` (48x48 px)
   - `custom/android/res/drawable-hdpi/icon.png` (72x72 px)
   - `custom/android/res/drawable-xhdpi/icon.png` (96x96 px)
   - `custom/android/res/drawable-xxhdpi/icon.png` (144x144 px)
   - `custom/android/res/drawable-xxxhdpi/icon.png` (192x192 px)
2. **Android Home Screen Launcher Icons**:
   - `custom/android/res/mipmap-mdpi/ic_launcher.png` (48x48 px)
   - `custom/android/res/mipmap-hdpi/ic_launcher.png` (72x72 px)
   - `custom/android/res/mipmap-xhdpi/ic_launcher.png` (96x96 px)
   - `custom/android/res/mipmap-xxhdpi/ic_launcher.png` (144x144 px)
   - `custom/android/res/mipmap-xxxhdpi/ic_launcher.png` (192x192 px)

### C. Desktop Packaging & OS Installers
1. **Linux AppImage SVG**:
   - `custom/res/icons/pulsegcs.svg`
2. **Windows Executable & Installer Icon**:
   - `custom/deploy/windows/WindowsQGC.ico`
   - `custom/res/icons/pulsegcs.ico`
3. **Windows Installer Banner**:
   - `custom/deploy/windows/installheader.bmp`
4. **macOS Bundle Icon (Optional)**:
   - `custom/res/icons/pulsegcs.icns`
