# PulseGCS Environment & Codebase Context Baseline

## 1. System & Host Environment Baseline
- **Operating System**: Ubuntu 24.04 LTS (Kernel: `Linux 7.0.0-30-generic x86_64`)
- **Primary C++ Compiler**: GCC 13.3.0 / Clang 18 (C++20 Standard Enforced)
- **Build System Generator**: CMake 3.28.3 (Minimum Required: `3.25`) with Ninja 1.11.1
- **Python Runtime**: Python 3.10.21 (Workspace virtualenv `.venv` used for MAVLink & QML code generators)
- **Primary IDE / Workspaces**: Qt Creator 13+, VS Code with Claude Code & Cursor

---

## 2. Qt Framework Specification
Source of truth: `.github/build-config.json`
- **Qt Version**: `6.11.1` (Minimum Version: `6.11.0`)
- **Core Modules**:
  - `QtCore`, `QtGui`, `QtWidgets`
  - `QtQuick`, `QtQml`, `QtQuickControls2`, `QtQuickLayouts`, `QtQuickWidgets`, `QtQuickVectorImage`
  - `QtLocation`, `QtPositioning`, `QtLocationPrivate`
  - `QtMultimedia`, `QtMultimediaQuickPrivate`
  - `QtGraphs`, `QtQuick3D`
  - `QtSensors`, `QtStateMachine`, `QtHttpServer`
  - `QtTextToSpeech`, `QtXml`, `QtSql`, `QtSvg`, `QtConcurrent`
- **Optional / Platform Modules**:
  - `QtSerialPort`, `QtBluetooth`
  - `QtWaylandClient` (Linux platform plugin)

---

## 3. Android Cross-Compilation Baseline
Source of truth: `.github/build-config.json`
- **Android Target Platform API**: `36` (Android 15)
- **Android Minimum SDK**: `28` (Android 9.0 Pie)
- **Android Build Tools**: `36.0.0`
- **Android Command-Line Tools**: `14742923`
- **Android NDK Version**: `r27c` (Full NDK Version String: `27.2.12479018`)
- **Java Development Kit (JDK)**: OpenJDK `21`
- **Android ABI Targets**: `arm64-v8a` (Primary target for modern ground station tablets), `armeabi-v7a`, `x86_64`

---

## 4. GStreamer Video Pipeline Specification
Source of truth: `.github/build-config.json`
- **GStreamer Default Version**: `1.28.4` (Minimum Version: `1.20.0`)
- **GStreamer Platform Builds**:
  - Android: `1.28.4` (SHA256: `a48aeb1b4fbae67a2fe0a0daa55af4a6af22b48f15a9c09f09dcd9ab3e8e943e`)
  - Linux: System / Prebuilt `1.28.4` with hardware acceleration (`va`, `vulkan`, `nvcodec`, `qsv`)
  - Windows: `1.28.4` MSVC x64 / ARM64 (`d3d11`, `d3d12`, `nvcodec`)
  - macOS: `1.28.4` Apple Silicon & Intel (`applemedia`, `dav1d`)
- **Core Plugins**:
  - `app`, `coreelements`, `isomp4`, `libav`, `matroska`, `mpegtsdemux`, `multifile`, `opengl`, `openh264`, `playback`, `rtp`, `rtpmanager`, `rtsp`, `sdpelem`, `tcp`, `typefindfunctions`, `udp`, `videoparsersbad`, `vpx`, `videoconvertscale`, `videoconvert`, `videoscale`

---

## 5. Quality Assurance & Static Analysis Tooling
Configured in `.pre-commit-config.yaml`:
- `clang-format` (C++ code formatting)
- `clang-tidy` (C++ static analysis and bug prevention)
- `ruff` (Python formatting & linting)
- `pyright` (Python static type checking)
- `shellcheck` (Shell script verification)
- `qmllint` (Qt QML syntax and type verification)
- `clazy` (Qt-specific C++ semantic checks)
- `check-no-qassert` (Enforces zero `Q_ASSERT` in production code)
- `check-no-fixed-qwait` (Prevents flaky tests with fixed `QTest::qWait`)
- `vehicle-null-check` (Ensures safe `activeVehicle()` and `Vehicle*` pointer access)

---

## 6. Build Commands Reference
- `just configure` - Configure CMake build directory
- `just build` - Run incremental compilation
- `just lint` - Execute fast pre-commit lint gate
- `just test` - Run unit test suite
- `just check` - Run full lint + unit test verification
