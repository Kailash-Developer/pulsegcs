#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

QMLTESTRUNNER="${HOME}/Qt/6.11.1/gcc_64/bin/qmltestrunner"

if [ ! -x "${QMLTESTRUNNER}" ]; then
    echo "ERROR: qmltestrunner not found at ${QMLTESTRUNNER}"
    exit 1
fi

TESTS=(
    "${SCRIPT_DIR}/tst_M3_AuthValidator.qml"
    "${SCRIPT_DIR}/tst_M3_SignIn.qml"
    "${SCRIPT_DIR}/tst_M3_Registration.qml"
    "${SCRIPT_DIR}/tst_M3_PasswordRecovery.qml"
    "${SCRIPT_DIR}/tst_M3_AuthService.qml"
    "${SCRIPT_DIR}/tst_M3_StoriesCompletion.qml"
    "${SCRIPT_DIR}/tst_M3_DemoMode.qml"
)

echo "======================================================================"
echo "[PulseGCS M3] Running Upstream-Style Qt Quick Tests (QtTest)"
echo "======================================================================"

for t in "${TESTS[@]}"; do
    echo ""
    echo ">>> Running test: $(basename "$t")"
    "${QMLTESTRUNNER}" -platform offscreen \
        -import "${REPO_DIR}/custom/tests/mocks" \
        -import "${REPO_DIR}/custom/qml" \
        -input "$t"
done

echo ""
echo "======================================================================"
echo "All Milestone 3 Qt Quick Tests passed successfully!"
echo "======================================================================"

