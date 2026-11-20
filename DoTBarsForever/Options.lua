local addonName, ns = ...
local L = ns.L
local panel, pages, selectedUnit = nil, {}, "target"
local refreshers = {}
local accent = {1, .82, .25}

local function Button(parent, text, width, x, y, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 30)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b.label = b:GetFontString()
    b:SetScript("OnClick", callback)
    return b
end

local function Check(parent, label, description, x, y, get, set)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(26, 26)
    b:SetPoint("TOPLEFT", x, y)
    ns.Text(b, 13, label, 32, -4)
    if description then
        local d = ns.Text(b, 11, description, 32, -24, {.55, .60, .70})
        d:SetWidth(460)
    end
    local function Update() b:SetChecked(get()) end
    refreshers[#refreshers + 1] = Update
    Update()
    b:SetScript("OnClick", function() set(b:GetChecked() == true); ns.Apply(); ns.RefreshOptions() end)
    return b
end

local function Slider(parent, title, x, y, lo, hi, step, get, set)
    local label = ns.Text(parent, 12, title, x, y)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y - 26)
    s:SetSize(220, 18)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s.Low:SetText(tostring(lo))
    s.High:SetText(tostring(hi))
    local updating
    local function Update()
        updating = true
        s:SetValue(get())
        label:SetText(title .. "  |cffb794f6" .. string.format("%d", math.floor(get() + .5)) .. "|r")
        updating = false
    end
    refreshers[#refreshers + 1] = Update
    s:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        value = math.floor(value / step + .5) * step
        set(value)
        label:SetText(title .. "  |cffb794f6" .. string.format("%d", math.floor(value + .5)) .. "|r")
        ns.Apply()
    end)
    Update()
    return s
end

local function Page(title, subtitle)
    local p = CreateFrame("Frame", nil, panel)
    p:SetPoint("TOPLEFT", 206, -98)
    p:SetSize(538, 422)
    ns.Text(p, 22, title, 0, 0)
    local sub = ns.Text(p, 11, subtitle, 0, -33, {.57, .62, .72})
    sub:SetWidth(528)
    pages[#pages + 1] = p
    return p
end

-- Per-spell colors. Blizzard's color picker differs between client families, so it is
-- used only when its setup call exists; otherwise a click cycles preset colors.
local function SetSpellColor(key, color)
    ns.db.spellColors[key] = color
    ns.Apply(); ns.RefreshOptions()
end

local function PresetColors()
    local list = {}
    for _, school in ipairs({"shadow", "fire", "nature", "arcane", "frost", "holy", "physical"}) do
        list[#list + 1] = ns.schoolColors[school]
    end
    for _, c in ipairs(ns.colors) do list[#list + 1] = {c[1], c[2], c[3]} end
    return list
end

local function PickSpellColor(entry)
    local r, g, b = ns.EntryColor(entry)
    local previous = ns.db.spellColors[entry.key]
    if not ColorPickerFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ColorPickerFrame")
    end
    local picker = ColorPickerFrame
    if picker and type(picker.SetupColorPickerAndShow) == "function" and type(picker.GetColorRGB) == "function" then
        local ok = pcall(picker.SetupColorPickerAndShow, picker, {
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = picker:GetColorRGB()
                SetSpellColor(entry.key, {nr, ng, nb})
            end,
            cancelFunc = function() SetSpellColor(entry.key, previous) end,
        })
        if ok then return end
    end
    local presets, next = PresetColors(), 1
    for i, c in ipairs(presets) do
        if math.abs(c[1] - r) < .01 and math.abs(c[2] - g) < .01 and math.abs(c[3] - b) < .01 then
            next = i % #presets + 1
        end
    end
    local c = presets[next]
    SetSpellColor(entry.key, {c[1], c[2], c[3]})
end

local spellRows, listChild, emptyLabel
local function RefreshSpellList()
    if not listChild then return end
    for _, row in ipairs(spellRows) do row:Hide() end
    local entries = ns.Entries()
    emptyLabel:SetShown(#entries == 0)
    for i, entry in ipairs(entries) do
        local row = spellRows[i]
        if not row then
            row = CreateFrame("Frame", nil, listChild)
            row:SetSize(490, 37)
            ns.Surface(row, {.09, .10, .14, 1})
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(26, 26)
            row.check:SetPoint("LEFT", 4, 0)
            row.name = ns.Text(row, 12, "", 38, -5)
            row.ids = ns.Text(row, 9, "", 38, -22, {.55, .60, .70})
            row.remove = Button(row, L.REMOVE, 74, 408, -4, function()
                for j, custom in ipairs(ns.db.custom) do
                    if custom.key == row.entry.key then
                        table.remove(ns.db.custom, j)
                        ns.db.disabled[custom.key] = nil
                        break
                    end
                end
                ns.Apply(); RefreshSpellList()
            end)
            row.check:SetScript("OnClick", function()
                ns.db.disabled[row.entry.key] = not row.check:GetChecked() or nil
                ns.Apply()
            end)
            -- This DoT's bar color: click to pick, right-click to return to its default.
            row.swatch = CreateFrame("Button", nil, row)
            row.swatch:SetSize(44, 18)
            row.swatch:SetPoint("TOPLEFT", 352, -10)
            row.swatch.fill = row.swatch:CreateTexture(nil, "ARTWORK")
            row.swatch.fill:SetAllPoints()
            row.swatch:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
            row.swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.swatch:SetScript("OnClick", function(_, button)
                if button == "RightButton" then SetSpellColor(row.entry.key, nil) else PickSpellColor(row.entry) end
            end)
            row.swatch:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.SPELL_COLOR)
                GameTooltip:AddLine(L.SPELL_COLOR_HELP, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            row.swatch:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            spellRows[i] = row
        end
        row.swatch.fill:SetTexture(ns.BarTexture())
        row.swatch.fill:SetVertexColor(ns.EntryColor(entry))
        row.entry = entry
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 42)
        row.name:SetText(entry.name)
        row.ids:SetText(string.format(L.IDS_SUMMARY, entry.custom and L.CUSTOM or L.CLASS_PRESET, #entry.ids))
        row.check:SetChecked(not ns.db.disabled[entry.key])
        row.remove:SetShown(entry.custom == true)
        row:Show()
    end
    listChild:SetHeight(math.max(200, #entries * 42))
end

function ns.RefreshOptions()
    for _, update in ipairs(refreshers) do update() end
    RefreshSpellList()
    if panel then
        panel.edit.label:SetText(ns.editing and L.FINISH_LAYOUT or L.EDIT_LAYOUT)
        if not ns.pending then ns.optionsStatus:SetText(L.SAVED_AUTOMATICALLY_TYPE_DOTBARS_TO_OPEN) end
    end
end

local function CreateOptions()
    panel = CreateFrame("Frame", "DoTBarsForeverOptions", UIParent, "ButtonFrameTemplate")
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(panel) end
    if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(panel) end
    if panel.Inset then panel.Inset:Hide() end
    if panel.SetTitle then panel:SetTitle("DoT Bars Forever") end
    panel:SetSize(780, 650)
    panel:SetPoint("CENTER")
    -- An ordinary window: other windows can rise above it when clicked.
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    local stripe = panel:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1); stripe:SetPoint("TOPRIGHT", -1, -1); stripe:SetHeight(3)
    stripe:SetColorTexture(0, 0, 0, 0)
    -- Heading sits fully below the title bar (about 22 units tall).
    ns.Text(panel, 26, "DoT Bars Forever", 24, -40)
    ns.Text(panel, 11, L.EVERY_TICK_IN_YOUR_OWN_SPACE, 260, -52, {.55, .60, .70})
    panel.edit = Button(panel, L.EDIT_LAYOUT, 150, 24, -294, function()
        ns.SetEditing(not ns.editing); ns.RefreshOptions()
    end)
    Button(panel, L.SPELL_TRAY, 150, 24, -332, function() ns.ToggleSpellTray() end)
    local editHint = ns.Text(panel, 11, L.PREVIEW_BARS_COUNT_DOWN_DRAG_TO_MOVE_PULL_THE_CORNER_TO_RESIZE_USE_THE_SPELL_TRAY_TO_PLACE_DOTS_IN_YOUR_LAYOUT, 26, -376, {.65, .62, .55})
    editHint:SetWidth(155)

    local tracking = Page(L.YOUR_DAMAGE_AT_A_GLANCE, L.ONLY_ACTIVE_DAMAGING_DEBUFFS_EACH_FRAME_FOLLOWS_ITS_OWN_UNIT)
    Check(tracking, L.ENABLE_TIMERS, L.HIDE_ALL_LIVE_TIMERS_WITHOUT_LOSING_YOUR_SETUP, 0, -68,
        function() return ns.db.enabled end, function(v) ns.db.enabled = v end)
    Check(tracking, L.SHOW_MINIMAP_BUTTON, nil, 0, -126,
        function() return ns.db.minimap end, function(v) ns.db.minimap = v end)
    ns.Text(tracking, 11, L.WATCH_THESE_UNITS, 0, -180, accent)
    for i, unit in ipairs(ns.units) do
        local token = unit
        Check(tracking, ns.unitNames[token], nil, 0, -202 - (i - 1) * 40,
            function() return ns.db.groups[token].enabled end,
            function(v) ns.db.groups[token].enabled = v end)
    end

    local spells = Page(L.MAKE_IT_YOUR_SPELL_LIST, L.CLASS_PRESETS_INCLUDE_RANKS_ADD_A_CUSTOM_DOT_USING_ITS_AURA_IDS)
    local scroll = CreateFrame("ScrollFrame", nil, spells, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -65); scroll:SetSize(496, 205)
    listChild = CreateFrame("Frame", nil, scroll); listChild:SetSize(490, 200)
    scroll:SetScrollChild(listChild)
    spellRows = {}
    emptyLabel = ns.Text(listChild, 12, L.NO_CLASS_PRESETS_ADD_YOUR_FIRST_DOT_BELOW, 8, -10)
    ns.Text(spells, 11, L.CUSTOM_DOT_AURA_SPELL_IDS, 0, -286, accent)
    local input = CreateFrame("EditBox", nil, spells, "InputBoxTemplate")
    input:SetAutoFocus(false); input:SetMaxLetters(400)
    input:SetSize(380, 28); input:SetPoint("TOPLEFT", 8, -310)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local verified = CreateFrame("CheckButton", nil, spells, "UICheckButtonTemplate")
    verified:SetSize(24, 24); verified:SetPoint("TOPLEFT", 0, -346)
    ns.Text(verified, 11, L.I_VERIFIED_THAT_THIS_SPELL_DEALS_DAMAGE_OVER_TIME, 30, -5)
    local result = ns.Text(spells, 11, L.USE_THE_DEBUFF_ID_WHICH_CAN_DIFFER_FROM_THE_CAST_SPELL_ID, 0, -383, {.62, .66, .76})
    result:SetWidth(520)
    Button(spells, L.ADD_DOT, 105, 411, -308, function()
        local ok, message = ns.AddCustom(input:GetText(), verified:GetChecked())
        result:SetText(message)
        if ok then input:SetText(""); verified:SetChecked(false); input:ClearFocus(); RefreshSpellList() end
    end)

    local layout = Page(L.A_PLACE_FOR_EVERY_TIMER, L.CHOOSE_A_UNIT_THEN_TUNE_ITS_BARS_YOUR_LAYOUT_PERSISTS_BETWEEN_SESSIONS)
    for i, unit in ipairs(ns.units) do
        local token = unit
        Button(layout, ns.unitNames[unit], i == 2 and 172 or 130, (i == 1 and 0 or i == 2 and 140 or 322), -65,
            function() selectedUnit = token; ns.RefreshOptions() end)
    end
    local unitLabel = ns.Text(layout, 12, "", 0, -108, accent)
    refreshers[#refreshers + 1] = function() unitLabel:SetText(string.format(L.EDITING_UNIT, ns.unitNames[selectedUnit])) end
    Check(layout, L.PLACE_EACH_SPELL_INDEPENDENTLY, L.OFF_PACK_ACTIVE_DOTS_INTO_A_STACK_ON_DRAG_AND_RESIZE_EACH_SPELL, 0, -136,
        function() return ns.db.groups[selectedUnit].free end,
        function(v) ns.db.groups[selectedUnit].free = v end)
    Slider(layout, L.BAR_WIDTH, 0, -210, 120, 700, 5,
        function() return ns.db.groups[selectedUnit].width end,
        function(v) ns.db.groups[selectedUnit].width = v end)
    Slider(layout, L.BAR_HEIGHT, 280, -210, 16, 64, 1,
        function() return ns.db.groups[selectedUnit].height end,
        function(v) ns.db.groups[selectedUnit].height = v end)
    Slider(layout, L.STACK_SPACING, 0, -294, 0, 24, 1,
        function() return ns.db.groups[selectedUnit].gap end,
        function(v) ns.db.groups[selectedUnit].gap = v end)
    Button(layout, L.RESET_THIS_LAYOUT, 190, 280, -310, function()
        ns.db.groups[selectedUnit] = ns.Copy(ns.Defaults().groups[selectedUnit])
        ns.Apply(); ns.RefreshOptions()
    end)
    Check(layout, L.GROW_BARS_UPWARD, L.OFF_GROW_DOWNWARD_EXISTING_INDEPENDENT_POSITIONS_ARE_PRESERVED, 0, -360,
        function() return ns.db.groups[selectedUnit].growUp end,
        function(v) ns.db.groups[selectedUnit].growUp = v end)
    -- Copy the edited unit's layout to the other units (or both).
    local copyLabel = ns.Text(layout, 11, L.COPY_LAYOUT_TO, 0, -404, accent)
    copyLabel:SetWidth(140)
    local copyButtons = {}
    local function Others()
        local list = {}
        for _, unit in ipairs(ns.units) do
            if unit ~= selectedUnit then list[#list + 1] = unit end
        end
        return list
    end
    for i = 1, 3 do
        local index = i
        copyButtons[i] = Button(layout, "", 120, 142 + (i - 1) * 128, -396, function()
            local others = Others()
            ns.CopyLayout(selectedUnit, index == 3 and others or {others[index]})
            ns.RefreshOptions()
        end)
    end
    for _, b in ipairs(copyButtons) do
        b:HookScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L.COPY_LAYOUT_TO)
            GameTooltip:AddLine(L.COPY_LAYOUT_HELP, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    refreshers[#refreshers + 1] = function()
        local others = Others()
        copyButtons[1]:SetText(ns.unitNames[others[1]])
        copyButtons[2]:SetText(ns.unitNames[others[2]])
        copyButtons[3]:SetText(L.COPY_LAYOUT_BOTH)
    end

    local style = Page(L.QUIET_DETAIL_CLEAR_TIMERS, L.A_RESTRAINED_PALETTE_READABLE_LABELS_AND_SIMPLE_BAR_TEXTURES)
    Check(style, L.SPELL_ICONS, L.KEEP_THE_SPELL_RECOGNIZABLE_AT_A_GLANCE, 0, -68,
        function() return ns.db.icons end, function(v) ns.db.icons = v end)
    Check(style, L.COLOR_BY_SCHOOL, L.COLOR_BY_SCHOOL_HELP, 0, -110,
        function() return ns.db.colorBySchool end, function(v) ns.db.colorBySchool = v end)
    -- Two scrolling lists side by side: built-in items, then any from SharedMedia.
    -- Texture rows draw the texture in the bar color; font rows draw their name in that font.
    local function MediaList(x, title, getList, field, decorate)
        ns.Text(style, 11, title, x, -160, accent)
        local scroll = CreateFrame("ScrollFrame", nil, style, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", x, -178)
        scroll:SetSize(232, 110)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(232, 110)
        scroll:SetScrollChild(child)
        local rows = {}
        refreshers[#refreshers + 1] = function()
            local list = getList()
            for i, item in ipairs(list) do
                local row = rows[i]
                if not row then
                    row = CreateFrame("Button", nil, child)
                    row:SetSize(228, 20)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
                    ns.Surface(row, {.10, .11, .16, .92})
                    row.swatch = row:CreateTexture(nil, "ARTWORK")
                    row.swatch:SetPoint("TOPLEFT", 1, -1)
                    row.swatch:SetPoint("BOTTOMRIGHT", -1, 1)
                    row.mark = row:CreateTexture(nil, "OVERLAY")
                    row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(3)
                    row.mark:SetColorTexture(1, .82, .25, 1)
                    row.label = ns.Text(row, 11, "", 10, -4)
                    row.source = ns.Text(row, 9, "", 0, -5, {.85, .87, .92})
                    row.source:ClearAllPoints(); row.source:SetPoint("RIGHT", -6, 0)
                    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
                    row:SetScript("OnClick", function(self)
                        ns.db[field] = self.key; ns.Apply(); ns.RefreshOptions()
                    end)
                    rows[i] = row
                end
                row.key = item.key
                decorate(row, item)
                row.label:SetText(item.name)
                row.source:SetText(item.shared and L.TEXTURE_FROM_SHAREDMEDIA or L.TEXTURE_BUILT_IN)
                local selected = item.key == ns.db[field]
                row.mark:SetShown(selected)
                row.label:SetTextColor(1, selected and .82 or 1, selected and .25 or 1)
                row:Show()
            end
            for i = #list + 1, #rows do rows[i]:Hide() end
            child:SetHeight(math.max(110, #list * 22))
        end
        return rows
    end
    ns.textureRows = MediaList(0, L.BAR_TEXTURE, ns.TextureList, "texture", function(row, t)
        local c = ns.colors[ns.db.color]
        row.swatch:SetTexture(t.path)
        row.swatch:SetVertexColor(c[1], c[2], c[3], .85)
        row.label:SetFont(ns.Font(), 11, "")
    end)
    ns.fontRows = MediaList(266, L.BAR_FONT, ns.FontList, "font", function(row, f)
        row.swatch:SetColorTexture(.13, .14, .20, 1)
        -- A font a pack lists but the client cannot load falls back to the default.
        if not pcall(row.label.SetFont, row.label, f.path or ns.Font(), 12, "") then
            row.label:SetFont(ns.Font(), 12, "")
        end
    end)
    local mediaNote = ns.Text(style, 10, "", 0, -292, {.57, .62, .72})
    mediaNote:SetWidth(500)
    refreshers[#refreshers + 1] = function()
        if not ns.FindTexture(ns.db.texture) then
            mediaNote:SetText(string.format(L.TEXTURE_NOT_LOADED, ns.db.texture))
        elseif not ns.FindFont(ns.db.font) then
            mediaNote:SetText(string.format(L.FONT_NOT_LOADED, ns.db.font))
        else
            mediaNote:SetText(L.TEXTURE_SHAREDMEDIA_NOTE)
        end
    end
    ns.Text(style, 11, L.BAR_COLOR, 0, -310, accent)
    for i, color in ipairs(ns.colors) do
        local index = i
        local b = Button(style, color.name, 98, (i - 1) * 105, -326, function()
            ns.db.color = index; ns.Apply(); ns.RefreshOptions()
        end)
        b.label:SetTextColor(color[1], color[2], color[3])
    end
    Slider(style, L.TEXT_SIZE, 0, -366, 9, 20, 1,
        function() return ns.db.fontSize end, function(v) ns.db.fontSize = v end)
    local lockedNote = ns.Text(style, 10, L.STYLE_LOCKED_NOTE, 240, -392, {.57, .62, .72})
    lockedNote:SetWidth(280)

    -- Profiles: switch, create (from class defaults or as a copy), reset, delete.
    local profiles = Page(L.PROFILES_TITLE, L.PROFILES_SUBTITLE)
    local current = ns.Text(profiles, 13, "", 0, -74, accent)
    ns.Text(profiles, 11, L.PROFILE_LIST, 0, -104, accent)
    local profileScroll = CreateFrame("ScrollFrame", nil, profiles, "UIPanelScrollFrameTemplate")
    profileScroll:SetPoint("TOPLEFT", 0, -122)
    profileScroll:SetSize(290, 176)
    local profileChild = CreateFrame("Frame", nil, profileScroll)
    profileChild:SetSize(290, 176)
    profileScroll:SetScrollChild(profileChild)
    local profileRows = {}
    refreshers[#refreshers + 1] = function()
        current:SetText(string.format(L.PROFILE_CURRENT, ns.CurrentProfile() or ""))
        local names = ns.ProfileNames()
        for i, name in ipairs(names) do
            local row = profileRows[i]
            if not row then
                row = CreateFrame("Button", nil, profileChild)
                row:SetSize(286, 26)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 30)
                ns.Surface(row, {.09, .10, .14, 1})
                row.mark = row:CreateTexture(nil, "OVERLAY")
                row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(3)
                row.mark:SetColorTexture(1, .82, .25, 1)
                row.label = ns.Text(row, 12, "", 10, -6)
                row.label:SetWidth(190); row.label:SetWordWrap(false)
                row.tag = ns.Text(row, 10, L.PROFILE_IN_USE, 0, -7, {.57, .62, .72})
                row.tag:ClearAllPoints(); row.tag:SetPoint("RIGHT", -10, 0)
                row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
                row:SetScript("OnClick", function(self) ns.UseProfile(self.name) end)
                row.delete = Button(row, L.PROFILE_DELETE, 64, 218, 2, function()
                    local name = row.name
                    ns.Confirm(string.format(L.PROFILE_DELETE_CONFIRM, name), L.PROFILE_DELETE,
                        function() ns.DeleteProfile(name) end)
                end)
                row.delete:SetHeight(22)
                profileRows[i] = row
            end
            row.name = name
            row.label:SetText(name)
            local inUse = name == ns.CurrentProfile()
            row.mark:SetShown(inUse)
            row.tag:SetShown(inUse)
            row.delete:SetShown(not inUse)
            row.label:SetTextColor(1, inUse and .82 or 1, inUse and .25 or 1)
            row:Show()
        end
        for i = #names + 1, #profileRows do profileRows[i]:Hide() end
        profileChild:SetHeight(math.max(176, #names * 30))
    end
    ns.profileRows = profileRows
    ns.Text(profiles, 11, L.PROFILE_NEW, 320, -104, accent)
    local profileName = CreateFrame("EditBox", nil, profiles, "InputBoxTemplate")
    profileName:SetAutoFocus(false); profileName:SetMaxLetters(32)
    profileName:SetSize(200, 28); profileName:SetPoint("TOPLEFT", 326, -122)
    profileName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local copyCurrent = CreateFrame("CheckButton", nil, profiles, "UICheckButtonTemplate")
    copyCurrent:SetSize(24, 24); copyCurrent:SetPoint("TOPLEFT", 318, -156)
    local copyText = ns.Text(copyCurrent, 11, L.PROFILE_COPY_CURRENT, 28, -5)
    copyText:SetWidth(180)
    local profileStatus = ns.Text(profiles, 10, "", 320, -230, {1, .45, .35})
    profileStatus:SetWidth(210)
    local function Create()
        local ok, err = ns.CreateProfile(profileName:GetText(), copyCurrent:GetChecked() == true)
        profileStatus:SetText(ok and "" or (err or ""))
        if ok then profileName:SetText(""); profileName:ClearFocus() end
    end
    profileName:SetScript("OnEnterPressed", Create)
    ns.profileName, ns.profileCopy = profileName, copyCurrent
    Button(profiles, L.PROFILE_CREATE, 120, 320, -194, Create)
    Button(profiles, L.PROFILE_RESET, 200, 0, -318, function()
        ns.Confirm(string.format(L.PROFILE_RESET_CONFIRM, ns.CurrentProfile()), L.PROFILE_RESET,
            function() ns.ResetProfile() end)
    end)

    local nav = {}
    for i, title in ipairs({L.NAV_TRACKING, L.NAV_SPELLS, L.NAV_LAYOUT, L.NAV_APPEARANCE, L.NAV_PROFILES}) do
        local index = i
        nav[i] = Button(panel, title, 150, 24, -103 - (i - 1) * 36, function()
            for j, page in ipairs(pages) do
                page:SetShown(j == index)
                nav[j].label:SetTextColor(j == index and 1 or .8, j == index and .82 or .8, j == index and .25 or .8)
            end
        end)
    end
    for i, p in ipairs(pages) do p:SetShown(i == 1) end
    nav[1].label:SetTextColor(unpack(accent))
    local preview = CreateFrame("Frame", nil, panel)
    preview:SetPoint("TOPLEFT", 24, -540); preview:SetSize(730, 68)
    ns.Surface(preview, {.075, .082, .115, 1})
    ns.Text(preview, 10, L.STYLE_PREVIEW, 14, -12, accent)
    ns.Text(preview, 10, L.SAMPLE_ONLY, 14, -34, {.5, .55, .65})
    local bar, label, time = ns.CreateBar(preview, 500, 27)
    bar:SetPoint("LEFT", 180, 0); label:SetText(L.CORRUPTION)
    ns.AnimatePreview(preview, bar, time, 18)
    refreshers[#refreshers + 1] = function()
        -- The sample shows slot 1's DoT, in that DoT's color.
        local first = ns.OrderedEntries()[1]
        label:SetText(first and first.name or L.CORRUPTION)
        bar:SetStatusBarTexture(ns.BarTexture())
        local r, g, b = ns.SampleColor()
        bar:SetStatusBarColor(r, g, b, .85)
        label:SetFont(ns.BarFont(), ns.db.fontSize, "")
        time:SetFont(ns.BarFont(), ns.db.fontSize, "")
    end
    ns.optionsStatus = ns.Text(panel, 10, "", 24, -626, {.5, .55, .65})
    UISpecialFrames[#UISpecialFrames + 1] = "DoTBarsForeverOptions"
    ns.RefreshOptions()
end

function ns.ToggleOptions()
    if not panel then CreateOptions() else panel:SetShown(not panel:IsShown()) end
    ns.RefreshOptions()
end

function ns.RegisterSettings()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local launcher = CreateFrame("Frame")
    ns.Text(launcher, 24, "DoT Bars Forever", 20, -20)
    ns.Text(launcher, 13, L.ACTIVE_DOTS_THREE_UNITS_YOUR_LAYOUT, 20, -60)
    Button(launcher, L.OPEN_OPTIONS, 180, 20, -100, ns.ToggleOptions)
    local category = Settings.RegisterCanvasLayoutCategory(launcher, "DoT Bars Forever")
    Settings.RegisterAddOnCategory(category)
end
