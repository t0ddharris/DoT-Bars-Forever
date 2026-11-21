local addonName, ns = ...
local L = ns.L
local WHITE = "Interface\\Buttons\\WHITE8X8"
ns.views = {}

-- LibSharedMedia-3.0 is optional and never bundled: another addon (BugSack, Prat,
-- TipTac, a SharedMedia pack...) may have loaded it. Its "statusbar" textures join
-- the built-in ones, so any installed pack shows up in the texture list.
local function SharedMedia()
    local stub = LibStub
    if type(stub) ~= "table" and type(stub) ~= "function" then return nil end
    local ok, lsm = pcall(stub, "LibSharedMedia-3.0", true)
    return ok and type(lsm) == "table" and lsm or nil
end

local textureCache
function ns.TextureList()
    if textureCache then return textureCache end
    local list, keys, paths = {}, {}, {}
    for _, t in ipairs(ns.textures) do
        list[#list + 1] = t
        keys[t.key], paths[string.lower(t.path)] = true, true
    end
    local lsm = SharedMedia()
    local ok, names = pcall(function() return lsm and lsm:List("statusbar") end)
    if ok and type(names) == "table" then
        for _, name in ipairs(names) do
            local fetched, path = pcall(lsm.Fetch, lsm, "statusbar", name, true)
            -- Skip duplicates of the built-in art (LSM registers the same stock textures).
            local same = type(path) == "string" and paths[string.lower(path)]
            if fetched and type(name) == "string" and not keys[name] and not same
                and (type(path) == "string" or type(path) == "number") then
                list[#list + 1] = {key = name, name = name, path = path, shared = true}
                keys[name] = true
                if type(path) == "string" then paths[string.lower(path)] = true end
            end
        end
    end
    textureCache = list
    return list
end

function ns.ResetTextures() textureCache, ns.fontCache = nil, nil end

function ns.FindTexture(key)
    for _, t in ipairs(ns.TextureList()) do
        if t.key == key then return t end
    end
end

-- The saved texture, or Flat while its SharedMedia pack is not loaded.
function ns.BarTexture()
    local t = ns.FindTexture(ns.db and ns.db.texture) or ns.textures[1]
    return t.path
end

-- A pack can register textures after this addon loads: refresh the list and,
-- when the saved texture has just appeared, apply it.
function ns.WatchSharedMedia()
    local lsm = SharedMedia()
    if not lsm or ns.watchingMedia or type(lsm.RegisterCallback) ~= "function" then return end
    ns.watchingMedia = true
    -- Offer DoT Bars Forever's own textures to other addons. Our list skips them as
    -- duplicates of the built-in entries (same path).
    for _, t in ipairs(ns.textures) do
        if t.own and type(lsm.Register) == "function" then
            pcall(lsm.Register, lsm, "statusbar", "DoT Bars Forever " .. t.name, t.path)
        end
    end
    textureCache = nil
    lsm.RegisterCallback(ns, "LibSharedMedia_Registered", function(_, mediatype, key)
        if mediatype ~= "statusbar" and mediatype ~= "font" then return end
        textureCache, ns.fontCache = nil, nil
        if ns.RefreshOptions then ns.RefreshOptions() end
        if ns.db and (key == ns.db.texture or key == ns.db.font) then ns.Apply() end
    end)
end

-- STANDARD_TEXT_FONT follows the client locale; FRIZQT is the Latin fallback.
-- The options window always uses it; bar text uses the chosen bar font.
function ns.Font()
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- Built-in fonts plus any "font" media registered with LibSharedMedia (for example
-- Dartez SharedMedia's fonts when that pack is installed).
function ns.FontList()
    if ns.fontCache then return ns.fontCache end
    local list, keys, paths = {}, {}, {}
    for _, f in ipairs(ns.fonts) do
        list[#list + 1] = f
        keys[f.key] = true
        if f.path then paths[string.lower(f.path)] = true end
    end
    local lsm = SharedMedia()
    local ok, names = pcall(function() return lsm and lsm:List("font") end)
    if ok and type(names) == "table" then
        for _, name in ipairs(names) do
            local fetched, path = pcall(lsm.Fetch, lsm, "font", name, true)
            if fetched and type(name) == "string" and type(path) == "string"
                and not keys[name] and not paths[string.lower(path)] then
                list[#list + 1] = {key = name, name = name, path = path, shared = true}
                keys[name], paths[string.lower(path)] = true, true
            end
        end
    end
    ns.fontCache = list
    return list
end

function ns.FindFont(key)
    for _, f in ipairs(ns.FontList()) do
        if f.key == key then return f end
    end
end

-- The bar font: the saved choice, or the default while its pack is not loaded.
function ns.BarFont()
    local f = ns.FindFont(ns.db and ns.db.font)
    return f and f.path or ns.Font()
end

function ns.Text(parent, size, text, x, y, color)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(ns.Font(), size, "")
    f:SetPoint("TOPLEFT", x or 0, y or 0)
    f:SetJustifyH("LEFT")
    f:SetTextColor(unpack(color or {.90, .92, .97}))
    f:SetText(text or "")
    return f
end

function ns.Surface(parent, color)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(unpack(color or {.055, .065, .09, .97}))
    return t
end

function ns.CreateBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(ns.BarTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    ns.Surface(bar, {.10, .11, .16, .92})
    local c = ns.colors[ns.db.color]
    bar:SetStatusBarColor(c[1], c[2], c[3], .85)
    local textLayer = CreateFrame("Frame", nil, bar)
    textLayer:SetAllPoints()
    textLayer:SetFrameLevel(bar:GetFrameLevel() + 5)
    local label = ns.Text(textLayer, ns.db.fontSize, "", 8, 0)
    label:ClearAllPoints()
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -58, 0)
    label:SetWordWrap(false)
    local time = ns.Text(textLayer, ns.db.fontSize, "", 0, 0)
    time:ClearAllPoints()
    time:SetPoint("RIGHT", -8, 0)
    label:SetFont(ns.BarFont(), ns.db.fontSize, "")
    time:SetFont(ns.BarFont(), ns.db.fontSize, "")
    bar.dbfLabel, bar.dbfTime = label, time
    return bar, label, time
end

ns.previews = {}
function ns.AnimatePreview(parent, bar, time, duration)
    bar.dbfPreview = true
    bar:SetMinMaxValues(0, duration or 18)
    local sample = {parent = parent, bar = bar, time = time, duration = duration or 18, elapsed = 0}
    ns.previews[#ns.previews + 1] = sample
    parent:SetScript("OnUpdate", function(_, elapsed)
        sample.elapsed = (sample.elapsed + elapsed) % sample.duration
        local left = sample.duration - sample.elapsed
        bar:SetValue(left)
        time:SetText(string.format("%.1fs", left))
    end)
    bar:SetValue(sample.duration)
    time:SetText(string.format("%.1fs", sample.duration))
end

-- A sample takes its spell's color; a stack or options sample shows slot 1's.
function ns.SampleColor(key)
    local entry = key and ns.EntryByKey(key) or ns.OrderedEntries()[1]
    return ns.EntryColor(entry)
end

function ns.RefreshPreviews()
    for _, sample in ipairs(ns.previews) do
        local r, g, b = ns.SampleColor(sample.bar.entryKey)
        sample.bar:SetStatusBarTexture(ns.BarTexture())
        sample.bar:SetStatusBarColor(r, g, b, .85)
        -- Samples follow the bar font and text size immediately (they are never locked).
        for _, font in ipairs({sample.bar.dbfLabel, sample.bar.dbfTime}) do
            font:SetFont(ns.BarFont(), ns.db.fontSize, "")
        end
    end
end

local function StyleRecordNow(view, record)
    local config = record.config()
    local width, height = config.width, config.height
    local offset = ns.db.icons and height + 5 or 0
    record.button:SetSize(width, height)
    record.icon:SetSize(height, height)
    record.icon:SetShown(ns.db.icons)
    record.bar:SetSize(width - offset, height)
    record.label:SetShown(width - offset >= 110)
    -- Each button only ever shows its own DoT family, so its color is known up front.
    local r, g, b = ns.EntryColor(ns.EntryByKey(record.key))
    record.bar:SetStatusBarTexture(ns.BarTexture())
    record.bar:SetStatusBarColor(r, g, b, .85)
    for _, font in ipairs({record.label, record.time}) do
        font:SetFont(ns.BarFont(), ns.db.fontSize, "")
    end
end

-- While an aura is assigned, the client makes the button and its bar forbidden
-- to addon code (seen in game: "Attempt to access forbidden object"). A style
-- change then fails; it is retried every second until the aura has gone.
local restyle = {}
local retrying = false
local function RetryStyles()
    retrying = false
    for record, view in pairs(restyle) do
        if pcall(StyleRecordNow, view, record) then restyle[record] = nil end
    end
    if next(restyle) and C_Timer and C_Timer.After then
        retrying = true
        C_Timer.After(1, RetryStyles)
    end
end

-- Live bars still waiting for their DoT to end before a style change applies.
function ns.PendingRestyles()
    local n = 0
    for _ in pairs(restyle) do n = n + 1 end
    return n
end

local function StyleRecord(view, record)
    if pcall(StyleRecordNow, view, record) then restyle[record] = nil; return end
    restyle[record] = view
    if not retrying and C_Timer and C_Timer.After then
        retrying = true
        C_Timer.After(1, RetryStyles)
    end
end

local function InitializeButton(view, getConfig, key)
    return function(button)
        local config = getConfig()
        local width, height = config.width, config.height
        button:SetSize(width, height)
        button:SetMouseClickEnabled(false)
        button:SetMouseMotionEnabled(false)
        local offset = ns.db.icons and height + 5 or 0
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT")
        icon:SetSize(height, height)
        icon:SetTexCoord(.07, .93, .07, .93)
        icon:SetShown(ns.db.icons)
        local bar, label, time = ns.CreateBar(button, width - offset, height)
        bar:SetPoint("RIGHT")
        button:SetIcon(icon)
        button:SetSpellName(label)
        button:SetDurationText(time, {})
        button:SetDurationBar(bar, {direction = Enum.StatusBarTimerDirection.RemainingTime,
            interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate})
        view.bars[#view.bars + 1] = bar
        local record = {button = button, icon = icon, bar = bar, label = label, time = time, config = getConfig, key = key}
        view.records[#view.records + 1] = record
        StyleRecord(view, record)
    end
end

-- Editors are independent of the restricted aura frames. They never inspect
-- aura visibility, dimensions or values. Only explicit layout mode shows them.
local function Editor(view, config, caption, x, y, width, height, key)
    local f = view.editors[key]
    if f then
        f.config = config
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", x, y)
        f:SetSize(width, height)
        f.label:SetText(caption)
        f:SetShown(ns.editing == true and ns.db.enabled and ns.db.groups[view.unit].enabled)
        return
    end
    f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f.config = config
    -- Layout handles sit above every ordinary window, including the options panel.
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetSize(width, height)
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(120, 16, 700, 64)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({bgFile = WHITE, edgeFile = WHITE, edgeSize = 1})
    f:SetBackdropColor(.13, .10, .22, .95)
    f:SetBackdropBorderColor(.64, .43, .96, 1)
    local bar, label, time = ns.CreateBar(f, width - 2, height - 2)
    -- Anchored to both corners, the sample bar itself follows the grip while sizing.
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    label:SetText(caption)
    f.preview, f.label = bar, label
    bar.entryKey = key ~= "stack" and key or nil
    ns.AnimatePreview(f, bar, time, 18)
    local controls = CreateFrame("Frame", nil, f)
    controls:SetAllPoints()
    controls:SetFrameLevel(bar:GetFrameLevel() + 10)
    local function Save()
        f:StopMovingOrSizing()
        local config = f.config
        local cx, cy = f:GetCenter()
        local px, py = UIParent:GetCenter()
        config.x, config.y = math.floor(cx - px + .5), math.floor(cy - py + .5)
        config.width, config.height = math.floor(f:GetWidth() + .5), math.floor(f:GetHeight() + .5)
        -- Individual editor coordinates are absolute UIParent-center offsets.
        ns.Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
    end
    f:SetScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
    f:SetScript("OnDragStop", Save)
    local grip = CreateFrame("Button", nil, controls)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT")
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnEnter", function()
        if GameTooltip then GameTooltip:SetOwner(grip, "ANCHOR_TOPLEFT"); GameTooltip:SetText(L.DRAG_TO_RESIZE_THIS_BAR); GameTooltip:Show() end
    end)
    grip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not InCombatLockdown() then f:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then Save() end end)
    f:SetShown(ns.editing == true and ns.db.enabled and ns.db.groups[view.unit].enabled)
    view.editors[key] = f
end

-- A DoT group's place in the shared stack. Each bar is a full-width line; groups
-- start new lines and are spaced like lines within a group.
function ns.StackLayout(g, index)
    return {elementWidth = g.width, elementHeight = g.height, elementSpacing = 0, lineSpacing = g.gap,
        groupSpacing = 0, groupLineSpacing = g.gap, forceNewLine = true, layoutIndex = index or 1}
end

-- Called on the player's own DoT casts, in or out of combat. Only group order
-- changes. If the client refuses the change, stacks keep slot order instead.
function ns.ReorderStacks()
    if ns.castOrderUnavailable or not ns.db or not ns.db.enabled then return end
    local stackIndex = ns.StackIndex()
    for unit, view in pairs(ns.views) do
        local g = ns.db.groups[unit]
        if view.stack and not g.free and view.stackGroups then
            for _, entry in ipairs(ns.OrderedEntries()) do
                if view.stackGroups[entry.key] then
                    local ok = pcall(view.stack.SetAuraGroupLayout, view.stack, "dot:" .. entry.key,
                        ns.StackLayout(g, stackIndex[entry.key]))
                    if not ok then
                        ns.castOrderUnavailable = true
                        ns.lastCast = {}
                        ns.Report(L.CAST_ORDER_UNAVAILABLE)
                        return
                    end
                end
            end
        end
    end
end

local function MakeContainer(parent, unit)
    local c = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    c:SetPoint("TOPLEFT")
    return c
end

local function NewView(unit)
    local g = ns.db.groups[unit]
    local view = {unit = unit, bars = {}, containers = {}, editors = {}, records = {}, slots = {}}
    view.root = CreateFrame("Frame", nil, UIParent)
    view.root:SetSize(g.width, g.height)
    view.root:SetPoint("CENTER", UIParent, "CENTER", g.x, g.y)
    return view
end

local function UpdateView(view)
    local unit = view.unit
    local g = ns.db.groups[unit]
    view.root:SetSize(g.width, g.height)
    view.root:ClearAllPoints()
    view.root:SetPoint("CENTER", UIParent, "CENTER", g.x, g.y)
    for _, c in ipairs(view.containers) do c:SetUnit("none"); c:Hide() end
    for _, e in pairs(view.editors) do e:Hide() end
    -- Only the player's own DoTs: that is what DoT Bars Forever is for.
    local filter = "HARMFUL|PLAYER"
    local active = {}
    if not g.free then
        local container = view.stack
        local fresh = not container
        if fresh then
            container = MakeContainer(view.root, unit)
            view.stack = container
            view.containers[#view.containers + 1] = container
        end
        -- The client's flow layout packs active auras, including in combat.
        -- Never use IsShown/GetHeight to infer secret aura state in addon Lua.
        container:SetFlowLayoutAnchorPoint(g.growUp and "BOTTOMLEFT" or "TOPLEFT")
        container:ClearAllPoints()
        container:SetPoint(g.growUp and "BOTTOMLEFT" or "TOPLEFT", view.root, g.growUp and "BOTTOMLEFT" or "TOPLEFT")
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,
            g.growUp and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
        container:SetFlowLayoutMaximumLineSize(g.width)
        -- One aura group per DoT family in the same flow layout: a group's buttons only
        -- ever show that family, so each bar's color is known without reading secret aura
        -- data. Group order (layoutIndex) follows cast order, then slot order.
        view.stackGroups = view.stackGroups or {}
        local stackIndex, tracked = ns.StackIndex(), {}
        for _, entry in ipairs(ns.OrderedEntries()) do tracked[entry.key] = true end
        -- Groups outlive catalog entries and profile switches. Retire every stale
        -- group, including custom spells no longer present in Entries().
        for key in pairs(view.stackGroups) do
            if not tracked[key] then container:SetAuraGroupEnabled("dot:" .. key, false) end
        end
        for _, entry in ipairs(ns.Entries()) do
            local key, groupKey = entry.key, "dot:" .. entry.key
            local candidates = {includeSpellIDs = ns.SpellSet(entry), maxDuration = 86400}
            if tracked[key] and not view.stackGroups[key] then
                container:AddAuraGroup(groupKey, filter, {
                    maxFrameCount = 8,
                    candidateFilters = candidates,
                    layout = ns.StackLayout(g, stackIndex[key]),
                    initializeFrame = InitializeButton(view, function() return ns.db.groups[unit] end, key),
                })
                view.stackGroups[key] = true
            elseif view.stackGroups[key] then
                container:SetAuraGroupFilterString(groupKey, filter)
                container:SetAuraGroupCandidateFilters(groupKey, candidates)
                if tracked[key] then container:SetAuraGroupLayout(groupKey, ns.StackLayout(g, stackIndex[key])) end
                container:SetAuraGroupEnabled(groupKey, tracked[key] == true)
            end
        end
        active[1] = container
        Editor(view, g, string.format(L.SAMPLE_UNIT, ns.unitNames[unit]), g.x, g.y, g.width, g.height, "stack")
    else
        -- Slot order from the spell tray: slot 1 is the first bar.
        for index, entry in ipairs(ns.OrderedEntries()) do
            do
                local pos = g.spells[entry.key]
                if not pos then
                    local width, height = ns.SlotSize(g, entry.key)
                    local dir, y = g.growUp and 1 or -1, g.y
                    for _, other in ipairs(ns.OrderedEntries()) do
                        local placed = g.spells[other.key]
                        if placed then
                            local nextY = placed.y + dir * (placed.height / 2 + g.gap + height / 2)
                            if dir * nextY > dir * y then y = nextY end
                        end
                    end
                    pos = {x = g.x, y = math.floor(y + .5), width = width, height = height}
                    g.spells[entry.key] = pos
                end
                local key = entry.key
                local container = view.slots[key]
                local fresh = not container
                if fresh then
                    container = MakeContainer(view.root, unit)
                    view.slots[key] = container
                    view.containers[#view.containers + 1] = container
                end
                container:ClearAllPoints()
                container:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
                container:SetSize(pos.width, pos.height)
                if fresh then container:AddAuraSlot(entry.key, filter, {
                    candidateFilters = {includeSpellIDs = ns.SpellSet(entry), maxDuration = 86400},
                    initializeFrame = function(button)
                        InitializeButton(view, function() return ns.db.groups[unit].spells[key] or ns.db.groups[unit] end, key)(button)
                        button:SetPoint("TOPLEFT", container, "TOPLEFT")
                    end,
                }) else
                    container:SetAuraSlotFilterString(key, filter)
                    container:SetAuraSlotCandidateFilters(key, {includeSpellIDs = ns.SpellSet(entry), maxDuration = 86400})
                end
                active[#active + 1] = container
                Editor(view, pos, entry.name, pos.x, pos.y, pos.width, pos.height, key)
            end
        end
    end
    view.root:SetShown(ns.db.enabled and g.enabled)
    view.active = active
    for _, record in ipairs(view.records) do StyleRecord(view, record) end
    for _, c in ipairs(active) do
        c:Show()
        c:SetUnit(ns.db.enabled and g.enabled and unit or "none")
        c:UpdateAllAuras()
    end
end

function ns.HideEditors()
    for _, view in pairs(ns.views) do
        for _, editor in pairs(view.editors) do editor:StopMovingOrSizing(); editor:Hide() end
    end
end

function ns.RefreshUnits()
    for unit, view in pairs(ns.views) do
        local enabled = ns.db.enabled and ns.db.groups[unit].enabled
        for _, c in ipairs(view.active or {}) do
            c:SetUnit(enabled and unit or "none")
            c:UpdateAllAuras()
        end
    end
end

function ns.Rebuild()
    if C_AddOns and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    if not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or
        not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") then
        ns.engineStatus = L.CUSTOMAURACONTAINERTEMPLATE_UNAVAILABLE_UPDATE_THE_FOREVER_CLIENT
        if not ns.warned then ns.Report(ns.engineStatus); ns.warned = true end
        return
    end
    for _, unit in ipairs(ns.units) do
        ns.views[unit] = ns.views[unit] or NewView(unit)
        UpdateView(ns.views[unit])
    end
    ns.engineStatus = L.CLIENT_AURA_CONTAINERS_READY
end
