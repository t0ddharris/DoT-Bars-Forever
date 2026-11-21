# DoT Bars Forever implementation matrix

Current local version: 0.2.1. Repository: https://github.com/t0ddharris/DoT-Bars-Forever . This working update has not been published.

| Requirements | Implementation | Verification |
|---|---|---|
| 01–02 | Native aura containers and duration fills; no external live-bar renderer | Prior partial 0.2.0 in-game evidence in TESTING.md; retained simulated coverage |
| 03–08, 11 | Separate samples, movable bars, minimap, spell tray, growth, native shell, seven textures | Simulated; historical in-game results and outstanding checks in TESTING.md |
| 09 | Settings entry and English fallback; controller assessment | No controller support claim; hardware/navigation not tested |
| 10 | Shared profiles and saved layout preservation; versioned ZIP | Existing migrations retained; packaging inspected |
| 12 | Disable groups absent from current catalog/selection | Regression checks for deletion, re-add and profile switch pass |
| 13 | Tray edits keep geometry; explicit confirmed Arrange per unit | Add/remove/reorder/re-enable and combat-refusal regressions pass |
| 14 | Reset captures profile name and table identity | Stale confirmation rejected; valid reset passes |
| 15 | Adaptive options with lower-right grip, scrolling and saved size | Simulated fit at narrow/short dimensions, resize lifecycle and scroll-clamp checks pass; visual acceptance pending |
| 16 | Selected-unit highlight, shared-profile banner, bounded names/tooltips, mode-aware controls | Implemented; in-game visual/interaction checks pending |

Validation: npm --prefix development test — seven Lua 5.1 syntax checks and 211 simulated assertions. Simulated tests do not establish real-client behavior. Witchcraft was disconnected and supplied no error data during this work; the new UI has not been visually verified. See REQUIREMENTS.md for the source pin and TESTING.md for the remaining acceptance checks.


## Approved redesign implementation (2026-11-20)
REQ-17: approved native metal/charcoal shell, top tabs, grouped Layout controls, Appearance-only preview and persistent footer. REQ-18: fixed logical dimensions; slider and corner grip scale the entire frame, retaining top-left anchor, per-character preference and screen fit. REQ-19: one-time class-character copies, preserving source/custom profiles and manual geometry, realm collision handling and explicit sharing. In progress; native visual acceptance pending. Controller grip remains pointer-based; directional navigation unverified. English localization and Settings entry retained.

REQ-17–19 implementation complete in 0.3.0; 229 simulated assertions pass. Native visual, controller and gameplay acceptance remain pending. No change to the restricted live-bar renderer.
