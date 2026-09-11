# ============================================================================
# PulseGCS Custom Build Configuration Overrides
# Non-invasive build overlay for PulseGCS Brand Assets & Identity [M1-US04]
# ============================================================================

# ----------------------------------------------------------------------------
# Application Metadata & Package Identity
# ----------------------------------------------------------------------------

set(QGC_APP_NAME "PulseGCS" CACHE STRING "Application name" FORCE)
set(QGC_ORG_NAME "PulseGCS" CACHE STRING "Organization name" FORCE)
set(QGC_ORG_DOMAIN "pulsegcs.com" CACHE STRING "Organization domain" FORCE)
set(QGC_APP_DESCRIPTION "PulseGCS Ground Control Station" CACHE STRING "Application description" FORCE)
string(TIMESTAMP _copyright_year "%Y")
set(QGC_APP_COPYRIGHT "Copyright (c) ${_copyright_year} PulseGCS. All rights reserved." CACHE STRING "Copyright notice" FORCE)

# Package Identifier (Android package & platform bundle ID)
set(QGC_PACKAGE_NAME "com.pulsegcs.app" CACHE STRING "Package identifier" FORCE)
set(QGC_ANDROID_PACKAGE_NAME "com.pulsegcs.app" CACHE STRING "Android package identifier" FORCE)

# Universal product version (splash, app menu, Android versionName, QCoreApplication::applicationVersion).
# Bump the story suffix when the milestone changes. Build number is auto-derived from git commits-since-tag.
set(PULSEGCS_APP_VERSION "0.0.0-M1-US07" CACHE STRING "PulseGCS product version" FORCE)

# ----------------------------------------------------------------------------
# Custom Application Icons
# ----------------------------------------------------------------------------

# Linux AppImage Icon
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/pulsegcs.svg")
    set(QGC_APPIMAGE_ICON_SCALABLE_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/pulsegcs.svg" CACHE FILEPATH "AppImage Icon SVG Path" FORCE)
endif()

# macOS Icon
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/pulsegcs.icns")
    set(QGC_MACOS_ICON_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/pulsegcs.icns" CACHE FILEPATH "MacOS Icon Path" FORCE)
endif()

# Windows Application Icon
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsQGC.ico")
    set(QGC_WINDOWS_ICON_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsQGC.ico" CACHE FILEPATH "Windows Icon Path" FORCE)
endif()
