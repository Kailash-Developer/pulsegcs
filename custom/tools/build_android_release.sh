#!/usr/bin/env bash
# ==============================================================================
# PulseGCS Android Signed Release APK Build Script
# ==============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

# 1. Paths and Toolchain Configuration
QT_ROOT="/home/kailash/Qt/6.11.1"
QT_ANDROID_PATH="${QT_ROOT}/android_arm64_v8a"
QT_HOST_PATH="${QT_ROOT}/gcc_64"
ANDROIDDEPLOYQT_BIN="${QT_HOST_PATH}/bin/androiddeployqt"
BUILD_DIR="${REPO_ROOT}/build/android_arm64_release"
KEYSTORE_PATH="${REPO_ROOT}/custom/deploy/android/pulsegcs-release.keystore"
KEY_ALIAS="pulsegcs-release"

echo "================================================================="
echo "   PulseGCS Android Release Build Pipeline"
echo "================================================================="
echo "Repo Root          : ${REPO_ROOT}"
echo "Build Directory    : ${BUILD_DIR}"
echo "androiddeployqt    : ${ANDROIDDEPLOYQT_BIN}"
echo "Release Keystore   : ${KEYSTORE_PATH}"
echo "Keystore Alias     : ${KEY_ALIAS}"
echo "================================================================="

# 2. Keystore Verification & Password Retrieval
if [ ! -f "${KEYSTORE_PATH}" ]; then
    echo "[!] Error: Release keystore not found at ${KEYSTORE_PATH}"
    echo "    Generate it first by running: python3 custom/tools/generate_release_keystore.py"
    exit 1
fi

if [ -z "${QT_ANDROID_KEYSTORE_STORE_PASS}" ]; then
    echo -n "Enter Keystore Password: "
    read -s KEYSTORE_PASS
    echo
    export QT_ANDROID_KEYSTORE_STORE_PASS="${KEYSTORE_PASS}"
    export QT_ANDROID_KEYSTORE_KEY_PASS="${KEYSTORE_PASS}"
fi

export QT_ANDROID_KEYSTORE_PATH="${KEYSTORE_PATH}"
export QT_ANDROID_KEYSTORE_ALIAS="${KEY_ALIAS}"

# 3. Configure CMake with Qt 6 Android Toolchain
echo ""
echo "[1/2] Configuring CMake for Android arm64-v8a Release..."
cmake -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="${QT_ANDROID_PATH}/lib/cmake/Qt6/qt.toolchain.cmake" \
    -DCMAKE_PREFIX_PATH="${QT_ANDROID_PATH}" \
    -DQT_HOST_PATH="${QT_HOST_PATH}" \
    -DQT_ANDROID_ABIS="arm64-v8a" \
    -DCMAKE_BUILD_TYPE=Release \
    -DQGC_APP_NAME=PulseGCS \
    -DQT_ANDROID_SIGN_APK=ON

# 4. Build Signed APK
echo ""
echo "[2/2] Compiling and Packaging Signed Release APK..."
cmake --build "${BUILD_DIR}" --target PulseGCS_make_apk --parallel $(nproc)

APK_PATH="${BUILD_DIR}/android-build/PulseGCS.apk"

echo ""
echo "================================================================="
echo "  [SUCCESS] PulseGCS Signed Release APK Ready!"
echo "================================================================="
echo "APK Output Location : ${APK_PATH}"
echo "androiddeployqt Path: ${ANDROIDDEPLOYQT_BIN}"
echo "================================================================="
