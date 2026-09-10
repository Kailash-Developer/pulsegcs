# PulseGCS Theme Documentation (M1-US06 / M1-US07)

Review documents for the Option A — **Aperture Cyan** theme. Implementation uses `CustomPlugin::paletteOverride()` in the `custom/` overlay; no upstream `src/` theme forks.

| Document | Purpose |
|----------|---------|
| [PULSEGCS_TOKEN_MAP.md](PULSEGCS_TOKEN_MAP.md) | Brand tokens → `QGCPalette` roles (what to override) |
| [COMPONENT_COVERAGE.md](COMPONENT_COVERAGE.md) | Which QGC UI areas change (Tier 1/2/3) |
| [SCREENSHOT_ACCEPTANCE.md](SCREENSHOT_ACCEPTANCE.md) | Visual acceptance checklist vs Option A mocks |

**Locked decisions**

- Option A only (no B/C edition switch)
- Light and Dark palette slots use **identical** PulseGCS hex values
- Colour-only changes — no layout, navigation, or behavior changes
- Safety semantic colours stay stock QGC

**Implementation plan:** `.cursor/plans/m1-us06_us07_theme_edf04a3e.plan.md`
