local addonName, ns = ...
local L = ns.L

-- Rank lists adapted from Dyre's Debuff Tracker (MIT, John Bedworth).
-- Only damaging aura families: no control-only spells or generic curse matching.
-- Durations always come from the client, never these reference spell lists.
ns.catalog = {}
local function Dot(class, key, name, ids)
    ns.catalog[#ns.catalog + 1] = {class = class, key = key, name = name, ids = ids}
end
Dot("WARLOCK", "corruption", "Corruption", {172,6222,6223,7648,11671,11672,25311})
Dot("WARLOCK", "agony", "Bane of Agony", {980,1014,6217,11711,11712,11713})
Dot("WARLOCK", "doom", "Bane of Doom", {603})
Dot("WARLOCK", "immolate", "Immolate", {348,707,1094,2941,11665,11667,11668,25309})
Dot("WARLOCK", "siphon", "Siphon Life", {18265,18879,18880,18881})
Dot("PRIEST", "pain", "Shadow Word: Pain", {589,594,970,992,2767,10892,10893,10894})
Dot("PRIEST", "plague", "Devouring Plague", {2944,19276,19277,19278,19279,19280})
Dot("PRIEST", "holyfire", "Holy Fire", {14914,15262,15263,15264,15265,15266,15267,15261})
Dot("DRUID", "moonfire", "Moonfire", {8921,8924,8925,8926,8927,8928,8929,9833,9834,9835})
Dot("DRUID", "swarm", "Insect Swarm", {5570,24974,24975,24976,24977})
Dot("DRUID", "roots", "Entangling Roots", {339,1062,5195,5196,9852,9853})
Dot("DRUID", "rake", "Rake", {1822,1823,1824,9904})
Dot("DRUID", "rip", "Rip", {1079,9492,9493,9752,9894,9896})
Dot("DRUID", "pounce", "Pounce Bleed", {9007,9824,9826})
Dot("DRUID", "lacerate", "Lacerate", {414644,1235826,1235827,1328616,1328617,414647})
Dot("HUNTER", "serpent", "Serpent Sting", {1978,13549,13550,13551,13552,13553,13554,13555,25295})
Dot("HUNTER", "trap", "Immolation Trap", {13797,14298,14299,14300,14301})
Dot("MAGE", "fireball", "Fireball", {133,143,145,3140,8400,8401,8402,10148,10149,10150,10151,25306})
Dot("MAGE", "pyro", "Pyroblast", {11366,12505,12522,12523,12524,12525,12526,18809})
Dot("MAGE", "frostfire", "Frostfire Bolt", {401502,1237312,1237313})
Dot("ROGUE", "rupture", "Rupture", {1943,8639,8640,11273,11274,11275})
Dot("ROGUE", "garrote", "Garrote", {703,8631,8632,8633,11289,11290})
Dot("SHAMAN", "flame", "Flame Shock", {8050,8052,8053,10447,10448,29228})
Dot("WARRIOR", "rend", "Rend", {772,6546,6547,6548,11572,11573,11574})

-- Spell schools of the catalog DoTs (game facts) and this addon's own color per school.
-- Custom spells have no known school and use the chosen bar color unless given one.
ns.dotSchools = {
    corruption = "shadow", agony = "shadow", doom = "shadow", immolate = "fire", siphon = "shadow",
    pain = "shadow", plague = "shadow", holyfire = "holy",
    moonfire = "arcane", swarm = "nature", roots = "nature",
    rake = "physical", rip = "physical", pounce = "physical", lacerate = "physical",
    serpent = "nature", trap = "fire",
    fireball = "fire", pyro = "fire", frostfire = "frost",
    rupture = "physical", garrote = "physical", flame = "fire", rend = "physical",
}
-- What a DoT does comes ahead of its school: curses and banes share one color, life
-- drains another. Custom spells named "Curse of ..." or "Bane of ..." count as curses.
ns.dotKinds = {agony = "curse", doom = "curse", siphon = "drain", plague = "drain"}
ns.schoolColors = {
    physical = {.86, .30, .27}, holy = {1, .84, .42}, fire = {1, .48, .20}, nature = {.42, .80, .32},
    frost = {.42, .76, 1}, shadow = {.64, .43, .96}, arcane = {.92, .55, 1},
    curse = {.90, .26, .42}, drain = {.30, .86, .48},
}

ns.units = {"target", "targettarget", "focus"}
ns.unitNames = {target = L.UNIT_TARGET, targettarget = L.UNIT_TARGET_TARGET, focus = L.UNIT_FOCUS}
ns.colors = {
    {name = L.COLOR_AMETHYST, .64, .43, .96},
    {name = L.COLOR_JADE, .19, .80, .65},
    {name = L.COLOR_EMBER, 1, .43, .23},
    {name = L.COLOR_GLACIER, .29, .70, 1},
    {name = L.COLOR_GOLD, .96, .74, .32},
}
-- Built-in bar fill textures: stock client art referenced by path, nothing copied.
-- `key` is saved and must never change; SharedMedia textures are added at runtime.
ns.textures = {
    {key = "Flat", name = L.TEXTURE_FLAT, path = "Interface\\Buttons\\WHITE8X8"},
    {key = "Classic", name = L.TEXTURE_CLASSIC, path = "Interface\\TargetingFrame\\UI-StatusBar"},
    {key = "Raid", name = L.TEXTURE_RAID, path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"},
    {key = "Skill", name = L.TEXTURE_SKILL, path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"},
    -- Original DoT Bars Forever art (development/scripts/make-textures.js), shipped in Media/.
    {key = "Smooth", name = L.TEXTURE_SMOOTH, path = "Interface\\AddOns\\DoTBarsForever\\Media\\Bar-Smooth", own = true},
    {key = "Glass", name = L.TEXTURE_GLASS, path = "Interface\\AddOns\\DoTBarsForever\\Media\\Bar-Glass", own = true},
    {key = "Gloss", name = L.TEXTURE_GLOSS, path = "Interface\\AddOns\\DoTBarsForever\\Media\\Bar-Gloss", own = true},
}
-- Built-in fonts: the client's own font files, referenced by path. "Default" follows the
-- client locale (STANDARD_TEXT_FONT). SharedMedia fonts are added at runtime.
ns.fonts = {
    {key = "Default", name = L.FONT_DEFAULT},
    {key = "Friz Quadrata", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF"},
    {key = "Arial Narrow", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF"},
    {key = "Morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF"},
    {key = "Skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF"},
}
-- Saves before textures had names stored a position in this list's first four entries.
ns.legacyTextureCount = 4
