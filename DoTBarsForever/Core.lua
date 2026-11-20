local addonName, ns = ...
local L = ns.L

function ns.Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = ns.Copy(v) end
    return copy
end

function ns.Defaults()
    local db = {version = 1, enabled = true, texture = "Flat", icons = true,
        fontSize = 12, color = 1, minimap = true, minimapAngle = 220, custom = {}, disabled = {}, order = {}, groups = {},
        colorBySchool = true, spellColors = {}, font = "Default"}
    for i, unit in ipairs(ns.units) do
        db.groups[unit] = {enabled = true, width = 260, height = 26, gap = 5,
            x = -330 + (i - 1) * 310, y = -140, free = false, growUp = false, spells = {}}
    end
    return db
end

local function Merge(target, defaults)
    for k, v in pairs(defaults) do
        if type(target[k]) ~= type(v) then target[k] = ns.Copy(v)
        elseif type(v) == "table" then Merge(target[k], v) end
    end
end

local function Clamp(value, lo, hi, default)
    if type(value) ~= "number" or value ~= value then return default end
    return math.max(lo, math.min(hi, value))
end

-- Geometry is stored in whole pixels; resize handles report fractional sizes.
local function Whole(value, lo, hi, default)
    return math.floor(Clamp(value, lo, hi, default) + .5)
end

function ns.InitializeDB(saved)
    local db = type(saved) == "table" and saved or {}
    -- Textures were saved by list position before SharedMedia; keep that choice by name.
    if type(db.texture) == "number" then
        local old = ns.textures[math.floor(Clamp(db.texture, 1, ns.legacyTextureCount, 1))]
        db.texture = old.key
    end
    Merge(db, ns.Defaults())
    db.fontSize = Clamp(db.fontSize, 9, 20, 12)
    db.color = math.floor(Clamp(db.color, 1, #ns.colors, 1))
    -- A name not available right now (a SharedMedia pack not loaded) is kept for when it returns.
    if db.texture == "" then db.texture = "Flat" end
    -- Smooth Animated Bars support was removed; drop its old settings.
    db.liquid, db.liquidLive = nil, nil
    -- "Only my DoTs" is no longer optional: DoT Bars Forever always shows only your own DoTs.
    db.mine = nil
    db.minimapAngle = Clamp(db.minimapAngle, -360, 360, 220)
    local order = {}
    for _, key in ipairs(db.order) do
        if type(key) == "string" then order[#order + 1] = key end
    end
    db.order = order
    -- Per-spell color overrides: {r, g, b} in 0..1 keyed by spell family.
    for key, c in pairs(db.spellColors) do
        if type(key) ~= "string" or type(c) ~= "table" then db.spellColors[key] = nil
        else
            for i = 1, 3 do c[i] = Clamp(c[i], 0, 1, 1) end
            for k in pairs(c) do if k ~= 1 and k ~= 2 and k ~= 3 then c[k] = nil end end
        end
    end
    for _, unit in ipairs(ns.units) do
        local g = db.groups[unit]
        g.width = Whole(g.width, 120, 700, 260)
        g.height = Whole(g.height, 16, 64, 26)
        g.gap = Whole(g.gap, 0, 24, 5)
        g.x = Whole(g.x, -10000, 10000, 0)
        g.y = Whole(g.y, -10000, 10000, -140)
        for key, pos in pairs(g.spells) do
            if type(pos) ~= "table" then g.spells[key] = nil
            else
                pos.width = Whole(pos.width, 120, 700, g.width)
                pos.height = Whole(pos.height, 16, 64, g.height)
                pos.x = Whole(pos.x, -10000, 10000, g.x)
                pos.y = Whole(pos.y, -10000, 10000, g.y)
            end
        end
    end
    return db
end

-- Profiles. Every setting lives in a named profile in the account-wide
-- DoTBarsForeverProfiles; each character remembers its profile name in DoTBarsForeverDB.
-- A character without one gets the profile named after its class (created with that
-- class's DoTs on first load), so characters of one class share a setup by default.
local function ClassProfileName()
    local localized = UnitClass and UnitClass("player")
    if type(localized) == "string" and not ns.Secret(localized) and localized ~= "" then return localized end
    return L.PROFILE_DEFAULT
end

local function CharacterName()
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if type(name) ~= "string" or ns.Secret(name) then return L.PROFILE_DEFAULT end
    if type(realm) == "string" and not ns.Secret(realm) and realm ~= "" then return name .. " - " .. realm end
    return name
end

function ns.ResolveProfiles(charDB, store)
    store = type(store) == "table" and store or {}
    store.profiles = type(store.profiles) == "table" and store.profiles or {}
    for name, profile in pairs(store.profiles) do
        if type(name) ~= "string" or type(profile) ~= "table" then store.profiles[name] = nil end
    end
    charDB = type(charDB) == "table" and charDB or {}
    if charDB.groups and not (type(charDB.profile) == "string" and store.profiles[charDB.profile]) then
        -- Saved before profiles existed: this character's settings become a profile,
        -- named after the class unless another character already took that name.
        -- The old settings are copied, not moved: if the account-wide profile store is
        -- not saved yet (the game reads a new SavedVariables line only on a full
        -- restart), the next load simply migrates again and nothing is lost.
        local name = ClassProfileName()
        if store.profiles[name] then name = CharacterName() end
        local settings = {}
        for k, v in pairs(charDB) do if k ~= "profile" then settings[k] = ns.Copy(v) end end
        store.profiles[name] = settings
        charDB.profile = name
    end
    if type(charDB.profile) ~= "string" or not store.profiles[charDB.profile] then
        charDB.profile = ClassProfileName()
        store.profiles[charDB.profile] = store.profiles[charDB.profile] or {}
    end
    ns.charDB, ns.profileStore = charDB, store
    ns.db = ns.InitializeDB(store.profiles[charDB.profile])
    store.profiles[charDB.profile] = ns.db
    return charDB, store
end

function ns.CurrentProfile() return ns.charDB and ns.charDB.profile end

function ns.ProfileNames()
    local names = {}
    for name in pairs(ns.profileStore.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function Switched()
    ns.lastCast, ns.castSerial = {}, 0
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.UseProfile(name)
    if InCombatLockdown() then ns.Report(L.FINISH_COMBAT_BEFORE_CHANGING_PROFILES); return false end
    local profile = ns.profileStore.profiles[name]
    if not profile then return false end
    ns.charDB.profile = name
    ns.db = ns.InitializeDB(profile)
    Switched()
    ns.Report(string.format(L.PROFILE_NOW_USING, name))
    return true
end

-- A new profile starts from this class's defaults, or as a copy of the current one.
function ns.CreateProfile(name, copyCurrent)
    if InCombatLockdown() then ns.Report(L.FINISH_COMBAT_BEFORE_CHANGING_PROFILES); return false end
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" or #name > 32 then return false, L.PROFILE_NAME_INVALID end
    if ns.profileStore.profiles[name] then return false, string.format(L.PROFILE_EXISTS, name) end
    ns.profileStore.profiles[name] = ns.InitializeDB(copyCurrent and ns.Copy(ns.db) or {})
    ns.UseProfile(name)
    return true
end

-- Back to this class's defaults: every class DoT on, default layout and look.
function ns.ResetProfile()
    if InCombatLockdown() then ns.Report(L.FINISH_COMBAT_BEFORE_CHANGING_PROFILES); return false end
    local name = ns.CurrentProfile()
    ns.db = ns.InitializeDB({})
    ns.profileStore.profiles[name] = ns.db
    Switched()
    ns.Report(string.format(L.PROFILE_RESET_DONE, name))
    return true
end

function ns.DeleteProfile(name)
    if InCombatLockdown() then ns.Report(L.FINISH_COMBAT_BEFORE_CHANGING_PROFILES); return false end
    if name == ns.CurrentProfile() or not ns.profileStore.profiles[name] then return false end
    ns.profileStore.profiles[name] = nil
    if ns.RefreshOptions then ns.RefreshOptions() end
    ns.Report(string.format(L.PROFILE_DELETED, name))
    return true
end

function ns.Report(message)
    print("|cffab80f5DoT Bars Forever|r  " .. message)
end

function ns.SpellInfo(id)
    if not C_Spell or not C_Spell.GetSpellInfo then return nil end
    local info = C_Spell.GetSpellInfo(id)
    if ns.Secret(info) or type(info) ~= "table" or ns.Secret(info.name) or type(info.name) ~= "string" then return nil end
    return info
end

function ns.EntryByKey(key)
    for _, entry in ipairs(ns.Entries()) do
        if entry.key == key then return entry end
    end
end

-- A spell ID (cast or aura, any rank) to its tracked family: exact ID, then same name.
function ns.EntryForSpell(id)
    for _, entry in ipairs(ns.Entries()) do
        if ns.SpellSet(entry)[id] then return entry end
    end
    local info = ns.SpellInfo(id)
    if info then
        for _, entry in ipairs(ns.Entries()) do
            local first = ns.SpellInfo(entry.ids[1])
            if first and first.name == info.name then return entry end
        end
    end
end

-- A DoT's bar color: the player's override, else its school (when on), else the bar color.
function ns.EntryColor(entry)
    local custom = entry and ns.db.spellColors[entry.key]
    if custom then return custom[1], custom[2], custom[3] end
    local school = entry and ns.db.colorBySchool and ns.schoolColors[ns.dotSchools[entry.key] or ""]
    if school then return school[1], school[2], school[3] end
    local c = ns.colors[ns.db.color]
    return c[1], c[2], c[3]
end

-- Stacked bars follow cast order: the player's own casts (UNIT_SPELLCAST_SUCCEEDED,
-- read only when its spell ID is not secret) move that DoT's group to the end.
-- Spells not yet cast this session keep slot order ahead of them.
ns.castSerial, ns.lastCast = 0, {}
function ns.StackIndex()
    local list = {}
    for slot, entry in ipairs(ns.OrderedEntries()) do
        list[#list + 1] = {key = entry.key, slot = slot, cast = ns.lastCast[entry.key] or 0}
    end
    table.sort(list, function(a, b)
        if a.cast ~= b.cast then return a.cast < b.cast end
        return a.slot < b.slot
    end)
    local index = {}
    for i, item in ipairs(list) do index[item.key] = i end
    return index
end

function ns.Entries()
    local result = {}
    for _, entry in ipairs(ns.catalog) do
        if entry.class == ns.class then result[#result + 1] = entry end
    end
    for _, entry in ipairs(ns.db.custom) do result[#result + 1] = entry end
    return result
end

-- The spell tray's shared slot bar: tracked (enabled) entries in slot order. Saved order
-- comes first; entries enabled elsewhere (the Spells page, a new character) join the end.
function ns.OrderedEntries()
    local byKey, seen, keys, result = {}, {}, {}, {}
    for _, entry in ipairs(ns.Entries()) do byKey[entry.key] = entry end
    local function Add(key)
        local entry = byKey[key]
        if entry and not seen[key] and not ns.db.disabled[key] then
            seen[key] = true
            keys[#keys + 1], result[#result + 1] = key, entry
        end
    end
    for _, key in ipairs(ns.db.order) do Add(key) end
    for _, entry in ipairs(ns.Entries()) do Add(entry.key) end
    ns.db.order = keys
    return result
end

-- Independent bars follow slot order from each unit's anchor; handles can fine-tune afterwards.
-- The size a newly shown independent bar takes: that of the first slotted bar already sized,
-- so a new bar matches the ones the player resized rather than the unit's default.
function ns.SlotSize(g, except)
    for _, entry in ipairs(ns.OrderedEntries()) do
        local pos = entry.key ~= except and g.spells[entry.key]
        if pos then return pos.width, pos.height end
    end
    return g.width, g.height
end

function ns.ArrangeBySlots()
    for _, unit in ipairs(ns.units) do
        local g = ns.db.groups[unit]
        if g.free then
            local width, height = ns.SlotSize(g)
            local dir, center, lastHalf = g.growUp and 1 or -1, g.y, nil
            for _, entry in ipairs(ns.OrderedEntries()) do
                local old = g.spells[entry.key]
                local w, h = old and old.width or width, old and old.height or height
                -- Bars are center-anchored: step by both half-heights so mixed sizes never overlap.
                if lastHalf then center = center + dir * (lastHalf + g.gap + h / 2) end
                g.spells[entry.key] = {x = g.x, y = math.floor(center + .5), width = w, height = h}
                lastHalf = h / 2
            end
        end
    end
end

function ns.SetSlot(key, index)
    if InCombatLockdown() then return false end
    local keys, wasSlotted = {}, false
    for _, entry in ipairs(ns.OrderedEntries()) do
        if entry.key ~= key then keys[#keys + 1] = entry.key else wasSlotted = true end
    end
    ns.db.disabled[key] = nil
    if not wasSlotted then
        -- Newly slotted: forget any stale size so it matches the bars already shown.
        for _, unit in ipairs(ns.units) do ns.db.groups[unit].spells[key] = nil end
    end
    index = math.max(1, math.min(index or #keys + 1, #keys + 1))
    table.insert(keys, index, key)
    ns.db.order = keys
    ns.ArrangeBySlots()
    ns.Apply()
    return true
end

function ns.ClearSlot(key)
    if InCombatLockdown() then return false end
    ns.db.disabled[key] = true
    ns.ArrangeBySlots()
    ns.Apply()
    return true
end

-- Copy one unit's layout style to others: sizes, spacing, growth, stacked/independent
-- mode and each independent bar's size and arrangement. Each target unit keeps its own
-- anchor, so independent bars keep their offsets from the source anchor around it.
function ns.CopyLayout(from, targets)
    if InCombatLockdown() then ns.Report(L.FINISH_COMBAT_BEFORE_EDITING_THE_LAYOUT); return false end
    local src = ns.db.groups[from]
    if not src then return false end
    local names = {}
    for _, unit in ipairs(targets) do
        local dst = ns.db.groups[unit]
        if dst and unit ~= from then
            dst.width, dst.height, dst.gap = src.width, src.height, src.gap
            dst.growUp, dst.free = src.growUp, src.free
            dst.spells = {}
            for key, pos in pairs(src.spells) do
                dst.spells[key] = {x = dst.x + (pos.x - src.x), y = dst.y + (pos.y - src.y),
                    width = pos.width, height = pos.height}
            end
            names[#names + 1] = ns.unitNames[unit]
        end
    end
    if #names == 0 then return false end
    ns.Apply()
    ns.Report(string.format(L.LAYOUT_COPIED, ns.unitNames[from], table.concat(names, ", ")))
    return true
end

function ns.SpellSet(entry)
    local set = {}
    for _, id in ipairs(entry.ids) do
        set[id] = true
        local info = ns.SpellInfo(id)
        if info and ns.bookIDs and ns.bookIDs[info.name] then
            for _, rank in ipairs(ns.bookIDs[info.name]) do set[rank] = true end
        end
    end
    return set
end

function ns.RefreshSpellbook()
    ns.bookIDs = {}
    local api = C_SpellBook
    if not api or not api.GetNumSpellBookSkillLines or not api.GetSpellBookSkillLineInfo
        or not api.GetSpellBookItemInfo or not Enum.SpellBookSpellBank then return end
    for line = 1, api.GetNumSpellBookSkillLines() do
        local info = api.GetSpellBookSkillLineInfo(line)
        if info then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local spell = api.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                if spell and not ns.Secret(spell.name) and not ns.Secret(spell.spellID)
                    and type(spell.name) == "string" and type(spell.spellID) == "number" then
                    local ids = ns.bookIDs[spell.name] or {}
                    ids[#ids + 1] = spell.spellID
                    ns.bookIDs[spell.name] = ids
                end
            end
        end
    end
end

function ns.SelectedIDs()
    local set = {}
    for _, entry in ipairs(ns.Entries()) do
        if not ns.db.disabled[entry.key] then
            for id in pairs(ns.SpellSet(entry)) do set[id] = true end
        end
    end
    return set
end

-- Unknown spells cannot be classified as periodic damage by the public API.
-- The user verifies the tooltip; HARMFUL filtering still excludes every HoT/buff.
function ns.AddCustom(text, confirmed)
    if not confirmed then return false, L.CONFIRM_THAT_THIS_SPELL_DEALS_DAMAGE_OVER_TIME end
    local ids, seen = {}, {}
    for token in (text .. ","):gmatch("(.-),") do
        local id = tonumber(token:match("^%s*(%d+)%s*$"))
        if not id or id < 1 or id > 2147483647 then
            return false, L.ENTER_AURA_SPELL_IDS_SEPARATED_BY_COMMAS_FOR_EXAMPLE_172_6222
        end
        if not seen[id] then ids[#ids + 1], seen[id] = id, true end
    end
    if #ids == 0 or #ids > 40 then return false, L.USE_BETWEEN_1_AND_40_AURA_IDS_PER_SPELL end
    if #ns.db.custom >= 40 then return false, L.YOU_CAN_ADD_UP_TO_40_CUSTOM_SPELL_FAMILIES end
    for _, entry in ipairs(ns.Entries()) do
        for _, id in ipairs(entry.ids) do
            if seen[id] then return false, string.format(L.DUPLICATE_SPELL, entry.name) end
        end
    end
    local info = ns.SpellInfo(ids[1])
    if not info then
        if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(ids[1]) end
        return false, L.SPELL_DATA_IS_UNAVAILABLE_CHECK_THE_ID_THEN_TRY_ADD_AGAIN_IN_A_MOMENT
    end
    ns.db.custom[#ns.db.custom + 1] = {key = "custom" .. ids[1], name = info.name, ids = ids, custom = true}
    ns.Apply()
    return true, string.format(L.ADDED_SPELL, info.name)
end

function ns.Apply()
    if not ns.ready then return end
    if InCombatLockdown() then
        ns.pending = true
        if ns.optionsStatus then ns.optionsStatus:SetText(L.CHANGES_SAVED_APPLIED_WHEN_COMBAT_ENDS) end
        return
    end
    ns.pending = nil
    ns.Rebuild()
    if ns.UpdateMinimap then ns.UpdateMinimap() end
    if ns.RefreshPreviews then ns.RefreshPreviews() end
    -- Spell list or editing changes must not leave an open tray showing stale rows.
    if ns.UpdateSpellTray then ns.UpdateSpellTray() end
end

function ns.SetEditing(on)
    if InCombatLockdown() then ns.Report(L.FINISH_COMBAT_BEFORE_EDITING_THE_LAYOUT); return end
    ns.editing = on
    ns.Apply()
end

local events = {}
function events.ADDON_LOADED(_, name)
    if name ~= addonName then
        -- A load-on-demand addon can bring LibSharedMedia after login.
        if ns.ready and not ns.watchingMedia then
            ns.ResetTextures(); ns.WatchSharedMedia()
            if ns.watchingMedia then ns.Apply(); if ns.RefreshOptions then ns.RefreshOptions() end end
        end
        return
    end
    DoTBarsForeverDB, DoTBarsForeverProfiles = ns.ResolveProfiles(DoTBarsForeverDB, DoTBarsForeverProfiles)
end
function events.PLAYER_LOGIN()
    local _, class = UnitClass("player")
    ns.class = not ns.Secret(class) and class or "UNKNOWN"
    ns.RefreshSpellbook()
    ns.ready = true
    ns.WatchSharedMedia()
    ns.Apply()
    ns.RegisterSettings()
end
function events.PLAYER_REGEN_DISABLED()
    if ns.editing then
        ns.editing = false
        ns.HideEditors()
        if ns.UpdateSpellTray then ns.UpdateSpellTray() end
        -- Live containers were never replaced by samples, so they remain current.
    end
end
function events.PLAYER_REGEN_ENABLED()
    if ns.pending then ns.Apply() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end
function events.SPELLS_CHANGED()
    if ns.ready then ns.RefreshSpellbook(); ns.Apply() end
end
function events.PLAYER_ENTERING_WORLD() if ns.ready then ns.RefreshUnits() end end
function events.PLAYER_TARGET_CHANGED() if ns.ready then ns.RefreshUnits() end end
function events.PLAYER_FOCUS_CHANGED() if ns.ready then ns.RefreshUnits() end end
function events.UNIT_TARGET(_, unit)
    if not ns.Secret(unit) and unit == "target" and ns.ready then ns.RefreshUnits() end
end
function events.UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if not ns.ready or ns.Secret(unit) or unit ~= "player" then return end
    if ns.Secret(spellID) or type(spellID) ~= "number" then return end
    local entry = ns.EntryForSpell(spellID)
    if not entry or ns.db.disabled[entry.key] then return end
    ns.castSerial = ns.castSerial + 1
    ns.lastCast[entry.key] = ns.castSerial
    if ns.ReorderStacks then ns.ReorderStacks() end
end

ns.events = events
ns.driver = CreateFrame("Frame")
ns.driver:SetScript("OnEvent", function(self, event, ...)
    if events[event] then events[event](self, ...) end
end)
for event in pairs(events) do ns.driver:RegisterEvent(event) end

SLASH_DOTBARS1 = "/dotbars"
SlashCmdList.DOTBARS = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "unlock" then ns.SetEditing(true)
    elseif command == "lock" then ns.SetEditing(false)
    elseif command == "reset" then
        for unit, g in pairs(ns.Defaults().groups) do ns.db.groups[unit] = g end
        ns.Apply()
        ns.Report(L.POSITIONS_AND_SIZES_RESET_YOUR_SPELL_SELECTIONS_WERE_KEPT)
    elseif command == "debug" then
        ns.Report("Interface " .. tostring(select(4, GetBuildInfo())) .. "; engine: " .. (ns.engineStatus or L.NOT_STARTED))
        ns.Report(string.format(L.DEBUG_STATUS, ns.PendingRestyles and ns.PendingRestyles() or 0,
            ns.castOrderUnavailable and L.DEBUG_SLOT_ORDER or L.DEBUG_CAST_ORDER, ns.castSerial or 0))
    else ns.ToggleOptions() end
end
