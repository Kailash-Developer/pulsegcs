# ============================================================================
# PulseGCS Universal Version Configuration
# Single source of truth for product version + git-derived build number.
# Included from the root CMakeLists.txt immediately after Git.cmake.
# ============================================================================

include_guard(GLOBAL)

if(NOT PULSEGCS_APP_VERSION)
    message(FATAL_ERROR "PulseGCS: PULSEGCS_APP_VERSION must be set in CustomOverrides.cmake")
endif()

# Git.cmake sets QGC_APP_VERSION_DEV from describe before this runs.
set(PULSEGCS_BUILD_NUMBER "${QGC_APP_VERSION_DEV}")

# Universal product version for UI, QCoreApplication::applicationVersion(), and Android.
set(QGC_APP_VERSION_STR "${PULSEGCS_APP_VERSION}")

# Parse semver prefix for project() and Android versionCode major/minor/patch fields.
string(REGEX REPLACE "^v" "" _pulsegcs_version_clean "${PULSEGCS_APP_VERSION}")
if(_pulsegcs_version_clean MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(QGC_APP_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(QGC_APP_VERSION_MINOR "${CMAKE_MATCH_2}")
    set(QGC_APP_VERSION_PATCH "${CMAKE_MATCH_3}")
    set(QGC_APP_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
else()
    message(WARNING "PulseGCS: Could not parse semver from PULSEGCS_APP_VERSION '${PULSEGCS_APP_VERSION}'")
endif()

configure_file(
    "${CMAKE_SOURCE_DIR}/custom/cmake/qgc_version_pulsegcs.h.in"
    "${CMAKE_BINARY_DIR}/qgc_version.h"
    @ONLY
)

message(STATUS "PulseGCS: universal version ${PULSEGCS_APP_VERSION} (build ${PULSEGCS_BUILD_NUMBER})")
