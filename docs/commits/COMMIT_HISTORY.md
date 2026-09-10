# PulseGCS Downstream Commit History & User Story Ledger

## 1. Upstream Base Reference
- **Upstream Repository**: `https://github.com/mavlink/qgroundcontrol`
- **Fork Baseline Commit SHA**: `4568b5856`
- **Baseline Date**: 2026-03-24
- **Primary Downstream Branch**: `pulse-main`
- **Upstream Tracking Branch**: `origin/master`

---

## 2. Commit Message Standards & Governance
All downstream commits for PulseGCS must follow **Conventional Commits** augmented with explicit User Story and Milestone tags:

```text
<type>(<scope>): <summary> [<UserStoryID>]

[Detailed explanation of architectural motivation, design patterns, and impact]

[Issue / PR References if applicable]
Co-Authored-By: PulseGCS Team <dev@pulsegcs.com>
```

### Commit Types:
- `feat`: New feature or user-facing capability (e.g. `feat(Identity): implement custom overlay [M1-US04]`)
- `fix`: Bug fix or crash resolution (e.g. `fix(Vehicle): guard null vehicle pointer in telemetry [M1-US02]`)
- `docs`: Documentation, context, or commit ledger updates (e.g. `docs(Context): create toolchain snapshot [M1-US04]`)
- `build`: Build system, CMake, dependencies, or packaging updates (e.g. `build(Android): configure custom package overlay [M1-US04]`)
- `refactor`: Code refactoring without behavioral changes
- `test`: Unit or integration test additions / fixes
- `chore`: Routine maintenance, asset cleanup, or script updates

---

## 3. Milestone 1 (M1) User Story Map

| User Story ID | Title | Priority | Primary Scope | Status |
|---|---|---|---|---|
| **M1-US01** | Vehicle Connection & Telemetry | Critical | Link layer & telemetry parsing | Ready |
| **M1-US02** | Multi-Vehicle Safe Routing | High | Safe activeVehicle pointer routing | Ready |
| **M1-US03** | Parameter & Fact Management | High | Vehicle parameter persistence & Facts | Ready |
| **M1-US04** | Application Identity & Branding | Critical | Custom build overlay, Android ID, branding | Completed |
| **M1-US05** | Video Streaming Stabilization | High | GStreamer pipeline & decoder acceleration | Ready |

---

## 4. Downstream Commit Ledger

| Commit SHA | Date | Author | User Story | Commit Subject & Scope | Impact / Notes |
|---|---|---|---|---|---|
| `4568b5856` | 2026-03-24 | Upstream | Baseline | Upstream QGC master baseline | Fork synchronization point |
| *pending* | 2026-09-08 | PulseGCS | M1-US04 | docs(Context): create environment, commit tracking, and branding comparison baselines [M1-US04] | Adds ENV_CONTEXT.md, COMMIT_HISTORY.md, context.md, BRANDING_COMPARISON.md |
| *pending* | 2026-09-08 | PulseGCS | M1-US04 | feat(Identity): configure custom overlay, Android package, splash theme, and branding assets [M1-US04] | Implements custom/ build overlay, CustomPlugin, Android manifest, splash theme, Help QML redirect |
| *pending* | 2026-09-08 | PulseGCS | M1-US04 | docs(Release): add Android signing and package identity governance [M1-US04] | Controlled release documentation for com.pulsegcs.app |

---

## 5. Audit & Maintenance Procedure
1. Whenever a new feature, fix, or documentation update is committed to `pulse-main` or a feature branch, append the commit details to the Downstream Commit Ledger table above.
2. Ensure every commit SHA is verified with `git rev-parse --short HEAD`.
3. Verify that all changes strictly adhere to the non-invasive `custom/` overlay architecture to maintain clean rebase capability against upstream `origin/master`.
