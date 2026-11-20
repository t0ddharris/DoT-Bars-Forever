DOT BARS FOREVER 0.2.0 - WOW FOREVER

Install this entire DoTBarsForever folder in:
World of Warcraft/_forever_/Interface/AddOns/
Restart the game, enable the addon, and type /dotbars.

Tracking: target, target of target, and focus; own DoTs by default.
Spells: class presets plus custom aura IDs (verify they deal periodic damage).
Layout: compact stacks growing up or down, or independently positioned and
resized spell bars. Spell tray: drag spells onto the screen, or click to place.
Minimap button: left-click options, right-click edit layout, drag to move.

/dotbars        : open options
/dotbars unlock : edit positions and sizes outside combat
/dotbars lock   : finish editing
/dotbars reset  : reset positions/sizes while keeping spell selections
/dotbars debug  : report interface and aura-engine availability

Only active matching harmful auras appear during normal play. Layout handles,
animated sample bars and the options preview are not live aura placeholders.
Combat changes apply after combat. Settings are saved per character.

Live bars use the client's native countdown fill. Appearance offers four
stock bar textures (Flat, Classic, Raid, Skill) and five colors. Smooth
Animated Bars is no longer used: live aura bars are locked to addon code while
a DoT is shown, so its liquid could only ever reach preview bars.

Custom entries require the debuff's aura ID (not always the cast ID).
There is no reliable public API to automatically classify arbitrary DoTs:
the verification checkbox is your declaration. Helpful auras are excluded.
Class rank lists adapted from Dyre's Debuff Tracker; see THIRD_PARTY_NOTICES.md.

Text is English only in this version.

STATUS: Lua syntax and simulated runtime tests pass. In-game verification of
0.2.0 inside WoW Forever is still pending.
