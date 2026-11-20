# DoT Bars Forever

A standalone WoW Forever addon for active damage-over-time bars. Interface **16001**, Lua **5.1**. No addon libraries required. Version 0.2.0 passes local syntax and simulated tests; in-game verification is pending (see [TESTING.md](TESTING.md)).

## Install

Extract [DoTBarsForever-0.2.0.zip](../releases/DoTBarsForever-0.2.0.zip) into:

```text
World of Warcraft/_forever_/Interface/AddOns/
```

The resulting file must be `AddOns/DoTBarsForever/DoTBarsForever.toc`. Restart the game after installing a new addon folder or after an update adds files (0.2.0 adds `Locale.lua`, `Launcher.lua` and `SpellTray.lua`). Enable DoT Bars Forever in the AddOns list. Existing 0.1.0 settings are kept.

## Use

- `/dotbars`: open the options window. Also available in the game's AddOns settings.
- **Minimap button**: left-click opens options, right-click toggles layout editing, drag moves it around the minimap. It can be hidden in options.
- `/dotbars unlock` / `/dotbars lock`: show or hide the drag and resize handles (outside combat).
- `/dotbars reset`: restore all unit positions and sizes; keep selected/custom spells.
- `/dotbars debug`: print the interface number and aura-engine availability.

**Tracking** enables target, target of target (`targettarget`), and focus independently. Each container follows only that unit token. By default, only your own DoTs appear. Nothing is shown for a unit unless it has an active matching DoT: there are no placeholder bars in normal play.

**Spells** starts with your class's damaging spell families from Dyre's reference data, including rank IDs. Uncheck any unwanted spell. The catalog covers Warlock, Priest, Druid, Hunter, Mage, Rogue, Shaman and Warrior; Paladins start with an empty list. It is a starter catalog, not a claim of exhaustive Forever spell coverage.

For a custom DoT, enter the **aura/debuff ID** (or comma-separated IDs for its ranks), confirm that the spell deals periodic damage, and select Add DoT. The aura ID can differ from the cast ID. The public API cannot reliably classify arbitrary spells as periodic damage; the checkbox is your declaration. Helpful auras are always filtered out, but a wrongly declared harmful non-DoT could appear.

**Spell tray**: open it from the options sidebar (it also switches on layout editing). It is a bar of action-button-style slots shared by all three units. The slots are the list of tracked DoTs, and the Spells page checkboxes stay in sync with them.

- Drag a spell from your spellbook or an action bar onto a slot, or click a slot while holding one. Dropping on the tray background fills the next empty slot.
- Below the slots, your class DoTs that are not slotted yet can be dragged into a slot or clicked to fill the next one.
- Drag between slots to reorder. Right-click a slot to remove that DoT.
- **Slot 1 is the top bar** for units using independent placement. Changing slots re-stacks independent bars in slot order from the unit anchor (upward when Grow upward is on); fine-tune them afterwards with the layout handles. Stacked layouts show active DoTs in the order the game applies them, which the addon cannot reorder.

A spell taken off an action bar leaves that bar, so it stays on your cursor after the drop for you to put back; a spellbook drag is cleared. Macros and items are refused and never cleared. A spell not in your list asks before it is added as a custom DoT. Some debuffs use a different ID from the spell you cast; if no bar appears, add the debuff ID on the Spells page. Slot changes are refused in combat, and the tray closes when combat starts.

**Layout** offers two modes per unit:

- **Stacked**: the client's aura layout packs only active DoTs. Width, height and spacing are configurable; **Grow upward** makes the stack build up from its anchor instead of down. Each DoT has its own group in the stack (so each bar's color is known), and groups are ordered by **cast order**: when you cast a tracked DoT, its bar moves to the end of the stack. DoTs not cast yet this session keep spell tray slot order. If the game ever refuses the reorder, a chat message says so and stacks keep slot order.
- **Independent**: each spell has its own position and size. Inactive spells are invisible in normal play.

While editing, each layout handle shows an animated sample bar that counts down, and a native corner grip resizes it. Handles and samples disappear on entering combat. Changes made during combat are saved and applied after combat. Settings are stored per character.

**Copy a layout:** on the Layout page, choose the unit whose layout you like, then use **Copy this layout to:** with one of the other units, or **Both**. It copies bar width, height, spacing, grow direction, stacked or independent mode, and each independent bar's size and arrangement. Each unit keeps its own screen position: independent bars keep their offsets from the source unit's anchor, placed around the target unit's anchor. Copying is refused in combat.

**Appearance** includes bar textures, five colors, font size and icon visibility. The options footer shows an animated sample bar.

**General** has Enable timers (uncheck to hide all live timers without losing your setup), Show minimap button, and which units to watch. DoT Bars Forever always shows only your own DoTs; the old "Only my DoTs" option was removed.

## Profiles

All settings (spells and slots, colors, layout, look) live in a **profile**. Profiles are account-wide (`DoTBarsForeverProfiles`); each character remembers which one it uses (`DoTBarsForeverDB.profile`).

- **First load:** a character goes on the profile named after its class (for example "Warlock"), created with that class's DoTs filled in. Other characters of the same class join the same profile unless you switch them.
- **Upgrading:** an existing character's settings become its class profile, or a "Name - Realm" profile if another character already filled the class one. Nothing is lost.
- **05 Profiles page:** click a profile to use it; create a new one by name, either from class defaults or as a copy of the current profile; **Reset current profile** returns it to class defaults; **Delete** removes another profile. Reset and delete ask first in the addon's own window (it never uses Blizzard's shared popups, which taints them). Profile changes are refused in combat.

**Renamed (2026-11-20):** formerly Just DoT Timer. The addon is now **DoT Bars Forever**: folder `DoTBarsForever`, saved variables `DoTBarsForeverDB` (per character) and `DoTBarsForeverProfiles` (account). The game treats a renamed folder as a new addon, so settings saved by Just DoT Timer do not carry over automatically: delete the old `JustDoTTimer` folder and set DoT Bars Forever up again (slash command `/dotbars`). The developer's own saves were converted by hand.

## DoT colors

With **Color DoTs by spell school** on (the default), each DoT's bar takes its school's color: shadow purple, fire orange, nature green, arcane pink, frost blue, holy gold, physical red. Off, every bar uses the chosen bar color. On the **Spells** page, each DoT has a color swatch: click it to pick a color for that DoT, right-click to return to its default. The game's color picker is used when the client offers its setup call; otherwise each click cycles through the school and bar colors. Custom spells have no known school, so they use the bar color until given one.

How it works within the client's rules: the spell on a live bar is secret to addon code, so a bar can't be recolored after looking at its aura. Instead, the stacked layout uses **one aura group per DoT** in a shared flow layout (`AddAuraGroup` with `layoutIndex`, `forceNewLine` and `groupLineSpacing`), and each group's buttons only ever show that DoT. Its color is set when the bar is created. Independent placement already has one slot per DoT. Cast order comes from the player's own `UNIT_SPELLCAST_SUCCEEDED` events (ignored when the spell ID is secret), which update each group's `layoutIndex`. The school table and colors are this addon's own; True Colors Forever (cast bars by school) inspired the idea, but none of its data was copied.

## Bar styles

Seven textures are built in, so nothing else needs installing:
- **Stock client art**, referenced by path: **Flat** (`Interface\Buttons\WHITE8X8`, the default), **Classic** (`Interface\TargetingFrame\UI-StatusBar`), **Raid** (`Interface\RaidFrame\Raid-Bar-Hp-Fill`) and **Skill** (`Interface\PaperDollInfoFrame\UI-Character-Skills-Bar`).
- **DoT Bars Forever's own clean, minimal art** in `DoTBarsForever/Media/`: **Smooth** (gentle top-to-bottom shade), **Glass** (lighter upper band with a soft edge) and **Gloss** (one wide, soft sheen). They are original 256×32 TGA luminance ramps generated by `development/scripts/make-textures.js`, which also writes an HTML preview to `development/texture-work/`. They are registered with LibSharedMedia as "DoT Bars Forever Smooth/Glass/Gloss" so other addons can use them.

**SharedMedia packs:** if any other addon has loaded LibSharedMedia-3.0 (BugSack, Prat, TipTac and Platynator embed it), every bar texture registered with it is listed too, so any SharedMedia texture pack you install shows up. DoT Bars Forever does not bundle LibSharedMedia or any pack. A pack that registers textures after login is picked up when it does. Duplicates of the built-in art are hidden.

The Appearance page lists all textures in a scrolling list. Each row draws the texture in the current bar color and says whether it is built-in or from SharedMedia. The choice is saved **by name** (older saves by list position are migrated). If the saved texture's pack is missing, bars use Flat and the page says so; the choice comes back when the pack does. The options preview, layout samples and live bars all follow the choice. Live bars that are showing a DoT are restyled once that aura ends, because the client locks them while an aura is assigned.

Bundling third-party packs was considered and declined. LibSharedMedia itself is LGPL 2.1, but the packs found have no license or "All Rights Reserved" (for example Dartez SharedMedia, which is also mostly fonts), and the plugin guidance says to reference client art rather than vendor it. Installed alongside, those packs still show up through LibSharedMedia.

While an aura is assigned, the client locks the live button and its bar against addon code. A style change made then (for example, right after combat with a DoT still up) cannot be applied, so that bar is retried every second until it is free. All other bars change at once.

## Smooth Animated Bars (removed)

SAB support was removed on 2026-11-17 at the user's request, after the live-liquid attempts below failed. What follows is the history.

Live DoT bars use the client's native duration bar (`SetTimerDuration` with remaining-time direction), which drains on its own and disappears when the aura ends.

If [Smooth Animated Bars](https://github.com/Jordanburch101/smooth-animated-bars) is installed and **Liquid preview effects** is on, SAB animates only the synthetic preview and layout sample bars. Live bars are deliberately never given to SAB. In 0.1.0 they were, and because live bars live under restricted aura frames, SAB's later asynchronous texture updates hit forbidden objects (`Liquid.lua: calling SetVertexColor on bad self`). A `pcall` around registration cannot catch those later failures, so the integration was removed for live bars.

SAB's own README (commit `4ec22f82`, "For addon authors") explains the cause. It supports `"health"` and `"power"` unit bars, places the liquid's frames as **children of the bar it is given**, and says nothing about timer or aura bars. Inside an aura button those child frames become forbidden, which produced the original `Liquid.lua:406` error. SAB's own DoT marker (your DoTs as liquid on the target's health bar) is a separate SAB feature that does work.

Why the timer cannot simply go to another bar: in the pinned Forever source, `CustomAuraButtonSharedMixin:SetDurationBar` requires the bar to be the aura button or one of its descendants (`AuraContainerUtil.ValidateInboundScriptObject`). It then gives the bar a secret `BarValue` aspect and forbids reparenting. Anchoring another bar to the live bar would inherit secret anchoring, and in the stacked layout which DoT occupies which row is itself secret.

### Live liquid: mirror relay tried and ruled out (2026-11-17)

Rechecked against SAB at `4ec22f8` (1.11.0, still the latest commit) and its open issues (#1-#12). None of the issues covers aura or timer bars. SAB's own DoT tracker (`Dots.lua`) uses cast events and `UNIT_COMBAT`, not aura APIs.

The idea was a plain mirror StatusBar outside the aura tree. Each frame it would copy the live bar's `GetMinMaxValues`/`GetValue` (declared as secret returns), follow `button:IsShown()` through `SetAlphaFromBoolean`, and only the mirror would go to SAB. Simulated tests passed. **In game it failed at once.** With a DoT shown, the first read raised `calling 'GetMinMaxValues' on bad self (Attempt to access forbidden object from code tainted by an AddOn)`, and `IsShown` failed the same way. While an aura is assigned, the button and its bar are forbidden objects to addon code, not merely secret-valued. The relay was removed. The safety fallback also failed: it called `SetStatusBarColor` on the forbidden bar, which left the live fills hidden until a reload.

Lessons: any code that touches a live aura button or its descendants must assume they can be forbidden while an aura is assigned. Source declarations of secret returns do not imply that addon code may call the method.

**Limitation:** live bars cannot get the liquid by reading the aura frame. Only a data source that never touches the aura frames could drive a mirror. `C_UnitAuras` on `target` was probed in game on 2026-11-17. Out of combat, `GetUnitAuraInstanceIDs("target", "HARMFUL|PLAYER")` returned a plain table (`true 0`). In combat with DoTs ticking, both `HARMFUL` and `HARMFUL|PLAYER` failed: "Auras cannot be accessed when secret while tainted by '*** ForceTaint_Strong ***'". **The aura-API route is closed.** The only remaining source is cast-event estimation like SAB's `Dots.lua`, which is approximate.

## Implementation and sources

The addon uses `CustomAuraContainerTemplate`, `AddAuraGroup` (stacked layout) and `AddAuraSlot` (independent positions). Blizzard binds the duration bar, icon, name and countdown text. Addon Lua does not read aura durations, do arithmetic on secret values, or use the combat log. Stacked growth uses `SetFlowLayoutAnchorPoint` and `SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, Up/Down)`.

API sources: canonical [WoWAddonAPIAgents](https://github.com/JBurlison/WoWAddonAPIAgents) plugin 2.7.0, bundled Forever snapshot 1.60.1.70862 (Gethe/wow-ui-source `9dc84f0d3bbae1768ac3405b3716000bd93eda06`). Upstream fallback for the timer binding and flow layout details: Forever 1.60.1.70959, commit `3d8abb1da73acd38e412e24fb3f99454a6392346`.

Other references inspected on November 17, 2026:

- [ClassTimer](https://github.com/Stanzilla/ClassTimer): bar-oriented functionality reference; no source code copied.
- [Dyre's class data](https://github.com/jbedworth/DyresDebuffTracker/blob/main/tests/toolkit/ClassData.lua): selected spell ID/rank lists adapted under MIT; see `DoTBarsForever/THIRD_PARTY_NOTICES.md`.
- [Dyre's aura adapter](https://github.com/jbedworth/DyresDebuffTracker/blob/main/tests/toolkit/Auras.lua): reference for the engine-managed timer approach.
- [SAB](https://github.com/Jordanburch101/smooth-animated-bars): former visual style reference and optional preview renderer (removed 2026-11-17) (`Editor.lua`/`Wizard.lua` styling inspected).

## Development

```text
npm --prefix development ci --ignore-scripts --cache development/.npm-cache
npm --prefix development test
powershell -File development/scripts/package.ps1
```

`luaparse` checks every shipped Lua file against Lua 5.1 syntax. Fengari runs a simulated WoW API covering unit bindings, filters, unit switches, custom entries, layout reuse, growth direction, combat deferral, bar textures and the locked-bar restyle retry, minimap and spell tray behavior. `tests/run-lua.js` fails the run unless the explicit `PASS` line appears with no traceback, since fengari can exit 0 after a Lua error. These tests cannot reproduce Blizzard's restricted/secret execution or native rendering. The package script names the ZIP from the TOC `## Version`.
