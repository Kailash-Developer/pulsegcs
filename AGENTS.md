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

## Context Ledger & Graphify Knowledge Architecture (Strict Token Efficiency)

Enforced universally for all agents, subagents, and sessions to eliminate redundant codebase reading and maximize token efficiency.

### Core Principle
Agents must **NEVER** re-read the broader codebase to understand system architecture, past decisions, or established workflows. Instead, agents must read the living **Context Ledger** (`.context_ledger.md`) and the **Graphify Knowledge Map** (`.graphify_knowledge.json` / diagrams). Full file inspection is strictly prohibited unless targeting a precise, minimal line range for an active edit.

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


