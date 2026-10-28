# AGENTS.md

Instructions for AI coding agents (Codex, Claude Code, etc.) working on QGroundControl.

## Quick References

- [CODING_STYLE.md](CODING_STYLE.md) — Naming, formatting, C++20 features, QML style, logging
- [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) — Architecture patterns (Fact System, Multi-Vehicle, FirmwarePlugin)
- [tools/README.md](tools/README.md) — Development scripts and tooling
- [test/README.md](test/README.md) — Test framework, base classes, CTest labels, MultiSignalSpy, coverage
- [.github/ci-overview.md](.github/ci-overview.md) — CI workflow/action/script layout and conventions
- [.pre-commit-config.yaml](.pre-commit-config.yaml) — All enforced linters (clang-format, clang-tidy, ruff, pyright, shellcheck, actionlint, zizmor, qmllint, clazy, vehicle-null-check, check-no-qassert, check-no-qtest-ignore-message)

## Golden Rules (enforced — violations fail CI)

These are the non-negotiables. The first four are QGC's core architecture patterns; the rest are
enforced by pre-commit hooks, so ignoring them wastes a build cycle. Full list with code examples:
[.github/CONTRIBUTING.md#architecture-patterns](.github/CONTRIBUTING.md#architecture-patterns) and
[CODING_STYLE.md#common-pitfalls](CODING_STYLE.md#common-pitfalls).

- **Fact System** — ALL vehicle parameters flow through Facts; never create custom parameter storage.
- **Multi-Vehicle** — ALWAYS null-check `activeVehicle()` / `Vehicle*` before dereferencing (`vehicle-null-check`).
- **Firmware Plugin** — use `vehicle->firmwarePlugin()` for firmware-specific behavior, not `if (px4)` branches.
- **QML Integration** — register types with `QML_ELEMENT`/`QML_SINGLETON`/`QML_UNCREATABLE`; expose state via `Q_PROPERTY`.
- **No `Q_ASSERT` in production code** — use defensive checks with early returns (`check-no-qassert`).
- **No `QTest::ignoreMessage`** in tests — use `expectLogMessage`/`ignoreLogMessage` (`check-no-qtest-ignore-message`).
- **No fixed-delay `QTest::qWait(<n>)`** — use `QTRY_*_WITH_TIMEOUT` or `QSignalSpy::wait` (`check-no-fixed-qwait`).
- **Valid QML Module Whitelist** — NEVER invent submodules (e.g. `QGroundControl.ScreenTools` or `QGroundControl.Palette` do NOT exist; both live in `QGroundControl.Controls`).
- **Signal-Slot Strict Parity** — Every signal connected in a parent view MUST exist in the child component declaration.

## Critical Files (Read First!)

1. `src/FactSystem/Fact.h` — Parameter system foundation
2. `src/Vehicle/Vehicle.h` — Core vehicle model
3. `src/FirmwarePlugin/FirmwarePlugin.h` — Firmware abstraction

## Code Structure

Key modules (full tree under `src/` — ~33 subdirectories):

```text
src/
├── Vehicle/          # Vehicle state/comms
├── Comms/            # Link layer (serial, UDP, TCP, Bluetooth)
├── FactSystem/       # Parameter management
├── FirmwarePlugin/   # PX4/ArduPilot abstraction
├── AutoPilotPlugins/ # Vehicle setup UI
├── MissionManager/   # Mission planning
├── MAVLink/          # Protocol handling
├── VideoManager/     # Video pipeline (GStreamer)
├── FlyView/          # In-flight UI
├── PlanView/         # Mission planning UI
├── QmlControls/      # Reusable QML components
└── Settings/         # Persistent settings
```

## Build & Test Commands

The `just` recipes are the canonical workflow — see [tools/README.md](tools/README.md) for the full list.
[.github/ci-overview.md](.github/ci-overview.md) documents how CI invokes builds and tests; match CI, don't guess.

```bash
just configure          # CMake configure (pulls submodules first)
just build              # incremental build; uses all cores (override with JOBS=N)
just test               # ctest, LABELS="Unit|Integration" EXCLUDE="Flaky|Network"
just lint               # fast pre-commit gate (clang-format, ruff, qmllint, ...)
just check              # lint + test (run before declaring done)
just format-fix         # apply clang-format / ruff-format
just info               # print resolved versions (Qt, CMake, GStreamer)
```

- **Build incrementally** — rebuild every few file edits during multi-file C++/Qt work, not just at the end; fix build errors before continuing.
- **Tight test loops** — iterate one test with `ctest -R <name>` (or `--gtest_filter`); only run the full label on the final pass. CI runs `ctest --output-on-failure -L Unit`.
- **Match CI** — before running tests/lint locally, use the same command CI runs ([.github/ci-overview.md](.github/ci-overview.md)), not a local guess.

## Definition of Done

Before considering a change complete:

1. `just build` succeeds.
2. `just lint` (or `pre-commit run --all-files` for the full sweep) passes.
3. Relevant tests pass (`ctest -R <name>` for the touched area; full `-L Unit` on the final pass).
4. Commit message follows Conventional Commits (below).

## Commit & Review Conventions

Commit messages follow **Conventional Commits** — the type drives release automation
(`.releaserc.json` → semantic-release). Use: `feat`, `fix`, `perf`, `revert` (release-triggering);
`docs`, `style`, `chore`, `refactor`, `test`, `build`, `ci` (no release). Example: `fix(Vehicle): guard null activeVehicle in telemetry handler`.

Your output will be reviewed by another AI agent before being accepted. Keep changes focused and
minimal, use clear naming, and leave explanatory commit messages. Avoid unrelated changes,
commented-out code, or ambiguous TODOs.

---

**Key Principle**: Match the style of code you're editing. See [CODING_STYLE.md](CODING_STYLE.md) for conventions and [CODING_STYLE.md#examples](CODING_STYLE.md#examples) for canonical Vehicle/Fact/QML snippets.

---

## Git Branching Strategy & Milestone Lifecycle Protocol

Enforced across all milestones and user stories by the dedicated agent: `git_branching_strategist_Agent`.

### Hierarchy & Architecture

```text
Milestone Baseline Branch (e.g. M3-US01-US11)
  │
  ├──► Step A: Story Dev Branch (e.g. feature/m3-us01-dev)
  │      │
  │      └──► Step B: Story Test Branch (e.g. test/m3-us01-test)
  │             │
  │             └──► Step C: Testing Verified & Cleared
  │                    │
  ├──◄─────────────────┴── Step D: Merge back to Milestone Baseline (M3-US01-US11)
  │
  ├──► Next Cycle: US02 (feature/m3-us02-dev -> test/m3-us02-test -> Merge back)
  └──► ... repeats iteratively until the final User Story of the Milestone.
```

### Operational Rules

1. **Milestone Baseline Branch**:
   - Master umbrella branch named `<Milestone>-US01-US<N>` (e.g. `M3-US01-US11`).
   - Direct unreviewed development on this branch is strictly prohibited.
2. **User Story Development (`feature/<milestone>-<us_id>-dev`)**:
   - Branch off the Milestone Baseline Branch for the specific story.
   - All feature implementation code is isolated strictly here.
3. **Dedicated Testing Branch (`test/<milestone>-<us_id>-test`)**:
   - Branch off the story dev branch.
   - Run incremental desktop and Android APK builds, unit tests, and SITL verifications.
4. **Promotion & Merge**:
   - Once testing passes and is cleared, merge the verified code back into the Milestone Baseline Branch.
   - Clean up dev/test temporary branches.
5. **Iteration**:
   - Advance sequentially to the next user story (e.g. `US02`) and repeat the exact cycle. Zero code leakage between user stories.

---

## Strict Git & Governance Rules

### 1. No Auto-Commit (Mandatory User Confirmation)
- **STRICT PROHIBITION**: Antigravity, subagents, and tools MUST **NEVER auto-commit** code changes to Git on their own.
- When development on any user story or milestone is implemented, tested, and finalized, the agent MUST present the summary of changes and **explicitly ask the user for permission** to commit.
- Commit execution is only permitted after receiving clear, affirmative user authorization.

### 2. Zero Upstream Tampering
- All modifications MUST be isolated strictly to `custom/`.
- Modifying files under upstream QGroundControl `src/` is strictly prohibited.

### 3. Canonical Pull Request (PR) Protocol & Mandatory Template
- **Multiple Focused PRs**: Do NOT combine entire milestones into one massive PR. Split milestone work into small, story-aligned, reviewable PRs.
- **Mandatory PR Template Format**: Every PR description MUST strictly adhere to this standardized layout with short, crisp bullet points and exact test execution commands:
```markdown
## Description
<!-- Short and crisp description of changes. What problem does this solve? -->

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] CI/Build changes
- [ ] Other

## Testing
- [ ] Tested locally
- [ ] Added/updated unit tests
- [ ] Tested with simulator (SITL)
- [ ] Tested with hardware

```bash
# Exact CLI command executed to test
```
*Exact test count and result (e.g. 44/44 passed with 0 failures).*

### Platforms Tested
- [ ] Linux
- [ ] Windows
- [ ] macOS
- [ ] Android
- [ ] iOS

### Flight Stacks Tested
<!-- If applicable -->
- [ ] PX4
- [ ] ArduPilot

## Screenshots
<!-- If applicable, add screenshots to help explain your changes -->

## Checklist
- [x] I have read the [Contribution Guidelines](CONTRIBUTING.md)
- [x] My code follows the project's coding standards
- [x] I have added tests that prove my fix/feature works
- [x] New and existing unit tests pass locally

## Related Issues
Closes <User_Story_ID>

---
By submitting this pull request, I confirm that my contribution is made under the terms of the project's dual license (Apache 2.0 and GPL v3).
```

---

## Context Ledger & Graphify Knowledge Architecture (Out of Git & Strict Token Efficiency)

Enforced universally for all agents, subagents, and sessions to eliminate redundant codebase reading and maximize token efficiency.

### Core Principle
- The Context Ledger (`.context_ledger.md`) and Graphify Knowledge Base (`.graphify_knowledge.json`) are **STRICTLY OUT OF GIT** (added to `.gitignore`). They serve exclusively as local machine/agent memory for token efficiency and must never be tracked or committed to Git.
- Agents must **NEVER** re-read the broader codebase to understand system architecture, past decisions, or established workflows. Instead, agents must read `.context_ledger.md` and `.graphify_knowledge.json`. Full file inspection is strictly prohibited unless targeting a precise, minimal line range for an active edit.

### 1. The Context Ledger (`.context_ledger.md`)
Maintained continuously at the workspace root as a living transcript:
* **Entry Schema**:
  - **Timestamp & Story ID**: (e.g., `[2026-10-08 | M3-US01]`)
  - **Action / Feature**: What was attempted, implemented, or refactored.
  - **Failure / Iteration Log**: If a test failed, record *why* it failed, what didn't work, and the exact diff transition from old state to working state.
  - **Verified Working State**: Clear statement of the working logic and verified behavior.
  - **Key Files & Exact Lines**: Specific anchors so subsequent agents jump straight to the source without scanning directories.

### 2. Graphify Knowledge Base (`.graphify_knowledge.json`)
A structured relationship graph tracking components, state flow, dependencies, and rules:
* Nodes: Components, QML views, C++ singletons, Fact groups, state variables.
* Edges: Signals, slot bindings, data flows, and state transitions.
* **Mandatory Graph Update**: Whenever an agent completes or modifies a feature, it must incrementally update `.graphify_knowledge.json` (and corresponding flowcharts) so future agents query the graph instead of crawling files.

### 3. Agent Execution Order & Token Budget Rules
Every agent operating in this repository **MUST** follow this strict read protocol:
1. **First Priority**: Read `.context_ledger.md` and `.graphify_knowledge.json`.
2. **Second Priority**: If and only if specialized information is missing, read **ONLY** the specific relevant file and line range using targeted tools (`view_file` with precise `StartLine`/`EndLine`).
3. **Prohibited**:
   - Never grep or read entire directories or large file trees when knowledge is already established.
   - Never re-analyze already-solved bugs or re-examine completed user story files.
   - Never finish a task without appending the final verified state to the Context Ledger and updating the Graphify knowledge base.

---

## Error-Free Code Generation & Ledger Invariant Protocol (Zero Regressions)

To ensure zero repeated runtime errors, every agent and subagent generating or modifying code MUST strictly comply with this three-step pre-flight protocol:

### Step 1: Consult the Context Ledger Anti-Pattern Registry
Before touching code, agents MUST read the `## Known Anti-Patterns & Prohibited Constructs` section of `.context_ledger.md`. Repeating an error recorded in the registry is considered a critical workflow failure.

### Step 2: Adhere to Canonical Module Whitelist & Signal Parity
1. **Canonical Qt 6 / QGroundControl QML Imports**:
   - Never guess or extrapolate module paths from C++ class names or singletons.
   - Allowed QML modules in this repository:
     - `import QtQuick`
     - `import QtQuick.Controls`
     - `import QtQuick.Layouts`
     - `import QtQuick.Window`
     - `import QtQuick.Dialogs`
     - `import QGroundControl`
     - `import QGroundControl.Controls` (Contains `ScreenTools`, `QGCPalette`, `QGCButton`, etc.)
     - `import QGroundControl.FactControls`
     - `import QGroundControl.FlyView`
     - `import QGroundControl.FlightMap`
     - `import QGroundControl.PlanView`
     - `import QGroundControl.Toolbar`
     - `import PulseGCS` or `import PulseGCS 1.0`
   - **STRICTLY PROHIBITED**: `QGroundControl.ScreenTools`, `QGroundControl.Palette`, `QGroundControl.Controls.Button`, or any non-existent submodule.
2. **Parent-Child Signal & Property Parity**:
   - When parenting an element (e.g. `PulseGCSSignInView` in `MainWindow.qml`), cross-check that every `on<SignalName>` handler in the parent matches an explicit `signal <signalName>(...)` in the child component.
   - Every exposed property referenced by external callers must be explicitly declared and typed.
3. **Type-Property Validity (e.g. No `color` on `Item`)**:
   - Qt Quick `Item` and layout components (`ColumnLayout`, `RowLayout`) do NOT have a `color` property.
   - Use `Rectangle` for any component that defines a background color, border, or radius.

### Step 3: Mandatory Pre-Flight Verification Gate Before Notifying User
Before notifying the user to initiate a build, the agent MUST run:
1. Static import and syntax check across all modified QML files.
2. The verification test suite (`node custom/tests/test_auth_validators.js` or corresponding feature test runner).
3. If any test or import check fails, the agent must diagnose and resolve it immediately without prompting the user to build.


