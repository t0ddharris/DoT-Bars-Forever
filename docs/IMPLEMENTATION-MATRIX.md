# Revision checkpoint (0.2.0)

No Git checkout exists in this workspace. Working files are under `DoTBarsForever/`; the 0.1.0 ZIP and extracted copy are retained in `releases/`.

| Requirements | Work | State | Evidence |
|---|---|---|---|
| 01,02 | Native live timers; SAB removed from restricted aura ancestry | Implemented; in-game pending | User traceback; pinned Blizzard `SetTimerDuration` binding; tests assert SAB never receives a live bar |
| 01,02b | Live liquid via mirror relay | **Ruled out in game, removed** | 2026-11-17: `GetMinMaxValues` on the live bar raised "forbidden object" with a DoT shown; tests assert no live bar (stacked or independent) reaches SAB |
| 11 | Bar textures (Flat/Classic/Raid/Skill), SAB removed (option, preview hook, OptionalDeps, old `liquid` settings dropped); locked-bar restyle retry | Implemented; in-game pending | Tests: texture default, live and sample follow the choice, locked bar retried via `C_Timer.After`, saved value clamped, old setting dropped |
| 03,04 | Animated synthetic samples; native size-grabber texture replaces slash text | Implemented; in-game pending | Tests: preview value decreases; SAB attaches only to `dbfPreview` bars |
| 05 | Minimap button (options, layout edit, drag angle, hide setting) | Implemented; in-game pending | Tests: visibility setting, click-after-drag handling |
| 06 | Spell tray popup with drag and click placement | Implemented; in-game pending | Tests: placement, combat refusal, open tray refreshes when spells change, click-after-drag handling |
| 07 | Up/down stack growth | Implemented; in-game pending | Tests: flow direction and anchor |
| 08 | SAB/Forever-inspired native styling | Implemented; visual check pending | Native templates; `STANDARD_TEXT_FONT` with FRIZQT fallback |
| 09 | Settings entry, English catalog, controller assessment | Implemented (English only) | `Locale.lua`; controller support not claimed |
| 10 | Folder convention, saved-data migration, versioned packaging | Implemented | `package.ps1` reads the TOC version; 0.1.0 artifacts preserved |

Test evidence: `npm --prefix development test` — Lua 5.1 syntax for all 7 files and 145 simulated assertions. The runner fails unless an explicit `PASS` line is printed and no traceback/error appears, because fengari can exit 0 after a Lua runtime error.

Runtime testing: Witchcraft 0.2.0 installed and configured (see local developer notes (local developer notes, not published)); real-client checks in [TESTING.md](TESTING.md) **not yet run**.

Known limitation: live liquid animation is **not** supported. Smooth Animated Bars support was removed on 2026-11-17 (see GUIDE.md).
