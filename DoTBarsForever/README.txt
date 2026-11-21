DOT BARS FOREVER 0.3.0 - WOW FOREVER

Install this entire DoTBarsForever folder in:
World of Warcraft/_forever_/Interface/AddOns/
Restart the game, enable the addon, and type /dotbars.

Tracking: target, target of target, and focus; only your own DoTs.
Spells: class presets plus custom aura IDs (verify they deal periodic damage).
Layout: compact stacks growing up or down, or independently positioned and
resized spell bars. Spell tray: drop spells into slots to track them.
Slot edits preserve manual positions and sizes. Use Layout > Arrange by slot
order to deliberately arrange independent bars for the selected unit.
Options: top tabs; drag the lower-right corner to
scale the entire window. Screen fit and preferred scale are per character.
Minimap button: left-click options, right-click edit layout, drag to move.

/dotbars        : open options
/dotbars unlock : edit positions and sizes outside combat
/dotbars lock   : finish editing
/dotbars reset  : reset positions/sizes while keeping spell selections
/dotbars debug  : report interface and aura-engine availability

Only active matching harmful auras appear during normal play. Layout handles,
animated sample bars and the options preview are not live aura placeholders.
Combat changes apply after combat. Addon settings live in account-wide shared
profiles; each character starts with a separate class-character profile.
Existing class profiles are copied once without changing their saved layouts.
You can explicitly choose a shared profile. Window scale stays per character.

Live bars use the client's native countdown fill. Appearance offers four
stock bar textures (Flat, Classic, Raid, Skill), three original textures
(Smooth, Glass, Gloss), school colors and per-spell overrides. Installed
SharedMedia packs can provide additional textures and fonts. Smooth
Animated Bars is no longer used: live aura bars are locked to addon code while
a DoT is shown, so its liquid could only ever reach preview bars.

Custom entries require the debuff's aura ID (not always the cast ID).
There is no reliable public API to automatically classify arbitrary DoTs:
the verification checkbox is your declaration. Helpful auras are excluded.
Class rank lists adapted from Dyre's Debuff Tracker; see THIRD_PARTY_NOTICES.md.

Text is English only in this version.

STATUS: Lua syntax and 234 simulated assertions pass. Earlier 0.2.0 behavior
has partial in-game verification; the 0.3.0 redesign and profile migration
still need an in-game visual and interaction check.
