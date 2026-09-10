# ============================================================================
# PulseGCS Custom Build & Module Configuration
# Non-invasive build overlay for PulseGCS Application Identity [M1-US04]
# ============================================================================

message(STATUS "PulseGCS: Adding Custom Plugin and Build Configuration")

# ============================================================================
# Custom Android Package Template Overlay
# ============================================================================

if(ANDROID)
    set(CUSTOM_ANDROID_DIR "${CMAKE_SOURCE_DIR}/custom/android")
    if(EXISTS "${CUSTOM_ANDROID_DIR}")
        file(GLOB CUSTOM_ANDROID_FILES "${CUSTOM_ANDROID_DIR}/*")
        if(CUSTOM_ANDROID_FILES)
            message(STATUS "PulseGCS: Custom Android package template found. Overlaying custom files...")
            set(DEFAULT_ANDROID_DIR "${CMAKE_SOURCE_DIR}/android")
            set(FINAL_ANDROID_DIR "${CMAKE_BINARY_DIR}/custom/android")

            file(COPY "${DEFAULT_ANDROID_DIR}/." DESTINATION "${FINAL_ANDROID_DIR}")
            execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory "${CUSTOM_ANDROID_DIR}" "${FINAL_ANDROID_DIR}")

            # Clean up reference previews from build directory to satisfy Android AAPT2 resource rules
            file(GLOB_RECURSE INVALID_VALUES_PREVIEWS "${FINAL_ANDROID_DIR}/res/values*/*.png" "${FINAL_ANDROID_DIR}/res/values*/*.jpg")
            if(INVALID_VALUES_PREVIEWS)
                file(REMOVE ${INVALID_VALUES_PREVIEWS})
            endif()
            file(REMOVE
                "${FINAL_ANDROID_DIR}/res/drawable/ic_launcher_foreground.png"
                "${FINAL_ANDROID_DIR}/res/drawable/splashscreen.png"
                "${FINAL_ANDROID_DIR}/res/mipmap-anydpi-v26/ic_launcher.png"
            )

            # Track changes to Android directories
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                "${DEFAULT_ANDROID_DIR}/"
                "${CUSTOM_ANDROID_DIR}/"
            )

            set(QGC_ANDROID_PACKAGE_SOURCE_DIR "${FINAL_ANDROID_DIR}" CACHE PATH "Path to a custom Android package template" FORCE)
            message(STATUS "PulseGCS: Android package template path set to: ${QGC_ANDROID_PACKAGE_SOURCE_DIR}")
        else()
            message(STATUS "PulseGCS: Custom Android package template directory empty. Using default.")
        endif()
    else()
        message(STATUS "PulseGCS: No custom Android package template found. Using default.")
    endif()
endif()

# ============================================================================
# Custom Resources and Import Paths
# ============================================================================

list(APPEND CUSTOM_RESOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/custom.qrc
)
set(QGC_RESOURCES ${QGC_RESOURCES} ${CUSTOM_RESOURCES} CACHE STRING "Paths to .qrc Resources" FORCE)

# ============================================================================
# Custom Plugin Sources
# ============================================================================

set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    CACHE INTERNAL "" FORCE
)

# ============================================================================
# Custom Build Target Configuration
# ============================================================================

set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="CustomPlugin.h"
    CUSTOMCLASS=CustomPlugin
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_QT_COMPONENTS
    Core
    Quick
    Qml
    CACHE INTERNAL "" FORCE
)
