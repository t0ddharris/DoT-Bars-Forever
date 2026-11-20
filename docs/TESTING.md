# In-game acceptance checklist (0.2.0)

Status: **partly run in game** (see the results logs below). Testing used Witchcraft, a connected-client bridge, with the user performing gameplay.

Setup: Forever client build (from `/dotbars debug` or the login screen), DoT Bars Forever 0.2.0 (Smooth Animated Bars no longer used). Run `/console scriptErrors 1`.

| # | Check | Expected |
|---|---|---|
| 1 | Log in / `/reload` | No Lua errors; `/dotbars debug` reports interface and engine |
| 2 | Apply a DoT to a hostile target | Only that DoT appears; the native fill drains and the bar disappears at expiry |
| 3 | Apply a second DoT; let one expire; refresh one | Stack packs with no gap; timers follow client durations |
| 4 | Switch to an undotted target, clear target, reacquire | No previous target's bars persist |
| 5 | Set focus; target a unit with its own target | target, targettarget and focus each show only their own DoTs |
| 6 | Outside editing | No placeholder or empty bars anywhere |
| 7 | Appearance: pick each of Flat, Classic, Raid and Skill | Swatches, options preview, layout samples and live bars all show that texture; none is blank or missing |
| 8 | Minimap button: left-click, right-click, drag, then click again | Opens options; toggles editing; position persists; first click after a drag still works |
| 9 | Spell tray: drag a spell onto the screen; click another; resize one | Bars land at drop/default positions; size and position persist after `/reload` |
| 10 | Grow upward on/off for a stacked unit | Stack builds up or down from its anchor |
| 11 | Enter combat while editing / with tray open; change an option in combat | Handles and tray hide; live bars continue; change applies after combat with no blocked-action warning |
| 12 | Add a custom DoT while the tray is open | Tray list updates immediately |
| 13 | `/reload` and relog | All settings preserved |
| 14 | Combat with live DoTs (historical: with SAB enabled) | Original `Liquid.lua:406 SetVertexColor ... forbidden object` error does not occur |
| 15 | Live fills are back after the relay revert | Native fill drains; no Lua errors |
| 16 | Change the texture right after combat while a DoT is still up | No Lua error; that bar switches within about a second of the DoT ending |
| 17 | Stacked: two DoTs of different schools on one target | Each bar in its school color; no empty gap between bars; no gap where an untracked/inactive DoT's group sits |
| 18 | In combat, cast DoT A, then DoT B, then recast A | Stack order follows casts (A's bar moves to the end on recast); no "can't be reordered" message, no Lua error or blocked action |
| 19 | Spells page: click a DoT's swatch, pick a color; right-click it | Live bar and samples take the color; right-click restores the school color; picker vs. preset cycling noted |
| 20 | Turn off Color DoTs by spell school | All bars use the bar color |
| 22 | Layout page: style Target, then Copy this layout to Focus, then to Both | Other units take the size, spacing, growth and mode at their own screen positions; refused in combat |
| 21 | Pick a bar font (built-in and a SharedMedia one) and change text size | Samples change at once; live bars change when their DoT ends; `/dotbars debug` shows how many bars are waiting |

2026-11-20 results (user in game, Witchcraft connected; the baseline holds one stale "DoTBarsForever called SetAllowDangerousScripts()" from 2026-11-17, 5 reloads earlier, with no matching call in our code):

| # | Result | Evidence |
|---|---|---|
| 17 | **Pass** | Screenshot: Corruption purple, Immolate orange, adjacent with normal spacing; no gap for inactive DoT groups. Fresh Witchcraft read (sampled after the test): no new errors. |
| 18 | **Pass** | Target grows upward (saved `growUp = true`), so the end of the stack is the top. Recasting Corruption put it on top; then, per the user, recasting Immolate moved Immolate to the top. In-combat `SetAuraGroupLayout` was accepted (no "can't be reordered" message). |
| — | **Bug found, fixed** | Text size "didn't change": samples never re-applied fonts, and live bars only restyle once their DoT ends (the client locks them). Samples now update at once; `/dotbars debug` reports bars still waiting. Font choice added (game fonts plus SharedMedia fonts). |

Witchcraft: after each reproduction, read `wow_get_errors` and compare timestamps/repeat counts with the action; a clean, fresh read means no errors were observed in that capture, not proof of correctness. Visual checks need a screenshot or the user's confirmation.

## Results log

2026-11-17, Forever client `D:\World of Warcraft\_forever_\Wow.exe`, the developer's Warlock character, DoT Bars Forever 0.2.0, SAB 1.11.0, Witchcraft 0.2.0 (locally patched, see local developer notes). The user restarted the game at about 21:16 and reloaded at 21:23.

| # | Result | Evidence |
|---|---|---|
| 1 | **Partial pass (load only)** | The saved variables written at 21:23 contain the 0.2.0 keys (`minimap`, `minimapAngle`, `growUp`), so 0.2.0 loaded and saved. Witchcraft `wow_get_errors`, sampled 21:24:23 and connected: 0 stored errors. BugGrabber's saved log: newest entry 20:47:47, before the 0.2.0 install, so no errors from 21:16 to 21:23. `/dotbars debug` output not yet captured. |
| 2, 4 | **User-reported pass** | After applying a DoT, switching targets and fighting, the user said it "seemed to work". No screenshots; details such as exact expiry timing were not reported separately. |
| 14 | **Pass so far (one session)** | The user fought with DoTs and SAB enabled. Witchcraft error reads from 21:24:23 to 21:28:27 (connected; samples 31-64 s old) all showed 0 stored errors. Witchcraft keeps error history across reloads, so no error has been recorded since this session began. The last `Liquid.lua:406` forbidden-object error in BugGrabber is from 20:47:47, under 0.1.0. One outdoor session only; restricted-instance combat not tested. |
| 7 (B1, B2) | **User-reported pass, with follow-ups** | Handles and animated samples appear; the native corner grip shows. The user's screenshots found four problems: resizing drew a box before the bar followed; handles drew under the options window; the options window covered other windows; the bar height label read `20.16668510437`. All four were fixed after this report (bar anchored to both handle corners; whole-pixel saves and labels; handles on `FULLSCREEN_DIALOG`; options and tray on `HIGH` + toplevel). The fixes need an in-game re-check. |
| SAB | **Expected limitation confirmed** | The user saw the liquid on edit-layout samples but flat fills on live bars in combat. This is by design (see GUIDE.md). |
| 9 | **Fail twice, redesigned** | The second attempt likely ran the previous build: the user reloaded at 21:43:28, before the install finished at 21:43:58. At the user's request the tray was then rebuilt as one shared bar of spell slots (slot order = independent bar order); installed at 21:50:28. Simulated tests cover spellbook and action-bar drops, reordering, removal, macro refusal and unknown-spell confirmation. In-game re-check pending. Earlier note: the user found the tray unintuitive, and dragging a spell from an action bar never worked (it was not implemented). Added: a screen-wide drop zone for spells on the cursor during layout editing; spellbook and action-bar drops; a confirmation for unknown spells; a highlighted unit choice; numbered steps. Covered by simulated tests; in-game re-check pending. `GetCursorInfo` returns are read defensively, because the generated catalog does not declare them. |
| 1 | `/dotbars debug` output not captured | — |
| 3, 5-13 | Not run | Targettarget/focus, placeholders, previews, minimap, spell tray, growth, combat lockouts, custom-spell refresh and reload persistence are still pending. |

| Live liquid relay | **Fail, removed** | 2026-11-17 ~22:08, outdoor (Greater Duskbat). `/dotbars liquid`: `GetMinMaxValues` raised "Attempt to access forbidden object from code tainted by an AddOn"; `IsShown` failed too; mirrors never reached SAB. Fills were left hidden by the fallback (screenshot). The relay was reverted; the revert needs an in-game re-check (row 15). |

| C_UnitAuras probe | **Blocked in combat** | 2026-11-17 ~22:20, Tirisfal. Out of combat: `ids true 0` (plain). In combat with DoTs: `GetUnitAuraInstanceIDs` false, "Auras cannot be accessed when secret while tainted". The script-permission accept worked after the popup fix (user ran /run successfully). |
| Popup taint | **Fail, fixed (re-check pending)** | 2026-11-17 ~22:15: accepting WoW's "allow scripts" prompt for `/run` raised `ADDON_ACTION_FORBIDDEN`, with `SetAllowDangerousScripts()` blamed on DoTBarsForever. The cause was `SpellTray.lua` writing `StaticPopupDialogs` and calling `StaticPopup_Show`, which tainted Blizzard's shared popups. It is replaced by the addon's own confirmation window (`DoTBarsForeverConfirm`); tests assert that DoT Bars Forever never touches `StaticPopupDialogs`. |

Smooth Animated Bars support was removed on 2026-11-17; the rows above that mention it are history.
