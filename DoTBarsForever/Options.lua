local addonName, ns = ...
local L = ns.L
local panel, pages, selectedUnit = nil, {}, "target"
local refreshers = {}
local accent = {1, .82, .25}
local content

local function Tooltip(widget, getText)
    widget:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(getText(self), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local WINDOW_WIDTH, WINDOW_HEIGHT = 820, 660
local function Number(value, fallback)
    return type(value) == "number" and value == value and value > 0 and value < math.huge and value or fallback
end

function ns.OptionsScaleLimit(width, height)
    return math.min(1.5, math.max(1, width - 24) / WINDOW_WIDTH, math.max(1, height - 24) / WINDOW_HEIGHT)
end

-- The whole frame is scaled. Logical geometry never stretches or reflows.
local function SetupWindow()
    content = panel
    panel:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    local saved = type(ns.charDB.optionsWindow) == "table" and ns.charDB.optionsWindow or {}
    local preferred = Number(saved.scale, math.min(Number(saved.width, WINDOW_WIDTH) / WINDOW_WIDTH,
        Number(saved.height, WINDOW_HEIGHT) / WINDOW_HEIGHT))
    preferred = math.max(.55, math.min(1.5, preferred))
    local actual, dragging = 1, nil
    local function Place(scale, left, top)
        panel:SetScale(scale)
        if left and top then
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
        end
        actual = scale
    end
    local function Anchor()
        return panel:GetLeft() and panel:GetLeft() * actual, panel:GetTop() and panel:GetTop() * actual
    end
    function ns.FitOptionsWindow()
        local left, top = Anchor()
        local limit = ns.OptionsScaleLimit(UIParent:GetWidth(), UIParent:GetHeight())
        local scale = math.min(preferred, limit)
        if left and top then
            left = math.max(12, math.min(left, UIParent:GetWidth() - WINDOW_WIDTH * scale - 12))
            top = math.min(UIParent:GetHeight() - 12, math.max(top, WINDOW_HEIGHT * scale + 12))
        end
        Place(scale, left, top)
    end
    function ns.SetOptionsScale(value)
        preferred = math.max(.55, math.min(1.5, Number(value, 1)))
        ns.charDB.optionsWindow = {scale = preferred}
        ns.FitOptionsWindow()
    end
    local function Stop()
        dragging = nil
        panel:SetClampedToScreen(true)
        panel:SetScript("OnUpdate", nil)
        panel:StopMovingOrSizing()
        ns.FitOptionsWindow()
    end
    panel:HookScript("OnShow", ns.FitOptionsWindow)
    panel:HookScript("OnHide", Stop)
    local grip = CreateFrame("Button", nil, panel)
    grip:SetSize(24, 24); grip:SetPoint("BOTTOMRIGHT", -5, 5)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local x, y = GetCursorPosition()
        local left, top = Anchor()
        if not left or not top then return end
        panel:StopMovingOrSizing()
        -- Clamp only on release. Automatic clamping during SetScale can move
        -- the frame between scale and anchor updates, causing visible jumps.
        panel:SetClampedToScreen(false)
        local limit = math.min(1.5, (UIParent:GetWidth() - 12 - left) / WINDOW_WIDTH, (top - 12) / WINDOW_HEIGHT)
        dragging = {x = x, y = y, scale = actual, left = left, top = top,
            parentScale = UIParent:GetEffectiveScale(), limit = math.max(actual, limit)}
        panel:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then Stop(); return end
            local cx, cy = GetCursorPosition()
            local parentScale = dragging.parentScale
            -- Project diagonal drag onto the fixed-aspect window diagonal.
            local delta = ((cx - dragging.x) * WINDOW_WIDTH + (dragging.y - cy) * WINDOW_HEIGHT)
                / (parentScale * (WINDOW_WIDTH * WINDOW_WIDTH + WINDOW_HEIGHT * WINDOW_HEIGHT))
            preferred = math.min(dragging.limit, math.max(math.min(.55, dragging.scale), dragging.scale + delta))
            ns.charDB.optionsWindow = {scale = preferred}
            Place(preferred, dragging.left, dragging.top)
        end)
    end)
    -- Consume the grip drag rather than letting an ancestor start moving too.
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() end)
    grip:SetScript("OnDragStop", Stop)
    grip:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then Stop() end end)
    Tooltip(grip, function() return L.RESIZE_OPTIONS end)
    panel.resizeGrip = grip
    ns.charDB.optionsWindow = {scale = preferred}
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED"); watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:SetScript("OnEvent", function() Stop() end)
    ns.FitOptionsWindow()
end

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
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", x, y); row:SetSize(740, 34)
    ns.Text(row, 14, title, 0, -6)
    local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 220, -8); slider:SetSize(410, 18)
    slider:SetMinMaxValues(lo, hi); slider:SetValueStep(step); slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(""); slider.High:SetText("")
    local input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", 655, -2); input:SetSize(70, 28)
    input:SetAutoFocus(false); input:SetMaxLetters(6)
    local updating
    local function Update()
        updating = true
        slider:SetValue(get()); input:SetText(tostring(math.floor(get() + .5)))
        updating = false
    end
    local function Commit(value)
        if not value or value ~= value then Update(); return end
        set(math.max(lo, math.min(hi, math.floor(value / step + .5) * step)))
        Update(); ns.Apply()
    end
    slider:SetScript("OnValueChanged", function(_, value) if not updating then Commit(value) end end)
    input:SetScript("OnEnterPressed", function(self) Commit(tonumber(self:GetText())); self:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(self) Update(); self:ClearFocus() end)
    input:SetScript("OnEditFocusLost", Update)
    refreshers[#refreshers + 1] = Update; Update()
    row.slider, row.input = slider, input
    return row
end

local function Section(parent, text, y)
    ns.Text(parent, 15, text, 0, y, accent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(.65, .52, .30, .45)
    line:SetPoint("TOPLEFT", 0, y - 25); line:SetSize(740, 1)
end

local function Page(title, subtitle)
    local p = CreateFrame("Frame", nil, panel)
    p:SetPoint("TOPLEFT", 40, -120); p:SetSize(740, 450)
    local sub = ns.Text(p, 13, subtitle, 0, 0, {.80, .78, .72})
    sub:SetWidth(740)
    pages[#pages + 1] = p
    return p
end

local function Choice(parent, text, width, x, y, get, callback)
    -- Tabs/segments are plain buttons with flat artwork only: no template, so hover and
    -- press never reveal native button borders or glow. Gold underline marks selection.
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 30); b:SetPoint("TOPLEFT", x, y)
    ns.Surface(b, {.12, .115, .10, 1})
    -- Hover: a soft warm gradient rising from the bottom edge, no button artwork.
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(); hover:SetColorTexture(1, 1, 1, 1)
    if not (type(hover.SetGradient) == "function" and CreateColor and pcall(hover.SetGradient, hover,
        "VERTICAL", CreateColor(1, .78, .30, .18), CreateColor(1, .78, .30, 0))) then
        hover:SetColorTexture(1, .82, .25, .07)
    end
    b.hover = hover
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("CENTER", 0, 1); b.label:SetText(text)
    b:SetScript("OnClick", callback)
    b:SetScript("OnMouseDown", function() b.label:SetPoint("CENTER", 1, 0) end)
    b:SetScript("OnMouseUp", function() b.label:SetPoint("CENTER", 0, 1) end)
    local mark = b:CreateTexture(nil, "OVERLAY")
    mark:SetColorTexture(1, .78, .24, 1)
    mark:SetPoint("BOTTOMLEFT", 1, 0); mark:SetPoint("BOTTOMRIGHT", -1, 0); mark:SetHeight(2)
    refreshers[#refreshers + 1] = function()
        local selected = get()
        mark:SetShown(selected)
        b.label:SetTextColor(selected and 1 or .85, selected and .82 or .83, selected and .35 or .77)
    end
    return b
end

-- Small addon-owned dropdown; no writes to Blizzard's shared popup registries.
local openMenu
local function Dropdown(parent, width, x, y, items, get, set)
    local button = Button(parent, "", width, x, y, function() end)
    local menu = CreateFrame("Frame", nil, button, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width, #items * 28 + 8); menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12, insets={left=3,right=3,top=3,bottom=3}})
    for i, item in ipairs(items) do
        local option = Button(menu, item.label, width - 8, 4, -4 - (i - 1) * 28, function()
            set(item.value); menu:Hide(); openMenu=nil; ns.Apply(); ns.RefreshOptions()
        end)
        option:SetHeight(26)
        refreshers[#refreshers + 1] = function() option:SetText(item.label) end
    end
    menu:Hide()
    button:SetScript("OnClick", function()
        local show = not menu:IsShown()
        if openMenu then openMenu:Hide() end
        if show then menu:Show(); openMenu=menu else openMenu=nil end
    end)
    parent:HookScript("OnHide", function() menu:Hide(); if openMenu==menu then openMenu=nil end end)
    refreshers[#refreshers + 1] = function()
        for _, item in ipairs(items) do if item.value == get() then button:SetText(item.label .. "  |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:14|t") end end
    end
    return button
end

-- Per-spell colors. Blizzard's color picker differs between client families, so it is
-- used only when its setup call exists; otherwise a click cycles preset colors.
local function SetSpellColor(key, color)
    ns.db.spellColors[key] = color
    ns.Apply(); ns.RefreshOptions()
end

local function PresetColors()
    local list = {}
    for _, school in ipairs({"shadow", "fire", "curse", "drain", "nature", "arcane", "frost", "holy", "physical"}) do
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
            row:SetSize(700, 37)
            ns.Surface(row, {.09, .10, .14, 1})
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(26, 26)
            row.check:SetPoint("LEFT", 4, 0)
            row.name = ns.Text(row, 12, "", 38, -5)
            row.name:SetWidth(510); row.name:SetWordWrap(false)
            row:EnableMouse(true)
            Tooltip(row, function(self) return self.entry and self.entry.name or "" end)
            row.ids = ns.Text(row, 10, "", 38, -22, {.55, .60, .70})
            row.remove = Button(row, L.REMOVE, 74, 618, -4, function()
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
            spellRows[i] = row
        end
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
    panel = CreateFrame("Frame", "DoTBarsForeverOptions", UIParent)
    panel:SetPoint("CENTER"); panel:SetFrameStrata("HIGH"); panel:SetToplevel(true)
    panel:SetClampedToScreen(true); panel:SetMovable(true); panel:EnableMouse(true)
    -- Only the title area moves the window; controls and the scale grip never do.
    local mover = CreateFrame("Frame", nil, panel)
    mover:SetPoint("TOPLEFT", 18, -10); mover:SetSize(480, 48)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function() panel:StartMoving() end)
    mover:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); ns.FitOptionsWindow() end)
    panel.titleMover = mover
    local border = CreateFrame("Frame", nil, panel, "DialogBorderTemplate")
    border:SetAllPoints(); border:EnableMouse(false)
    ns.Text(panel, 26, "DoT Bars Forever", 28, -20, accent)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5); close:SetScript("OnClick", function() panel:Hide() end)
    SetupWindow()
    local footer = panel:CreateTexture(nil, "ARTWORK")
    footer:SetColorTexture(.65, .52, .30, .45); footer:SetPoint("TOPLEFT", 24, -590); footer:SetSize(772, 1)
    panel.edit = Button(panel, L.EDIT_LAYOUT, 145, 28, -610, function()
        ns.SetEditing(not ns.editing); ns.RefreshOptions()
    end)
    local shared = ns.Text(panel, 13, "", 205, -618, {.88,.84,.72})
    shared:SetWidth(400); shared:SetWordWrap(false)
    refreshers[#refreshers + 1] = function() shared:SetText(string.format(L.PROFILE_FOOTER, ns.CurrentProfile() or "")) end
    Button(panel, CLOSE or "Close", 120, 650, -610, function() panel:Hide() end)

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
    scroll:SetPoint("TOPLEFT", 0, -65); scroll:SetSize(706, 205)
    listChild = CreateFrame("Frame", nil, scroll); listChild:SetSize(700, 200)
    scroll:SetScrollChild(listChild)
    spellRows = {}
    emptyLabel = ns.Text(listChild, 12, L.NO_CLASS_PRESETS_ADD_YOUR_FIRST_DOT_BELOW, 8, -10)
    ns.Text(spells, 11, L.CUSTOM_DOT_AURA_SPELL_IDS, 0, -286, accent)
    local input = CreateFrame("EditBox", nil, spells, "InputBoxTemplate")
    input:SetAutoFocus(false); input:SetMaxLetters(400)
    input:SetSize(540, 28); input:SetPoint("TOPLEFT", 8, -310)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local verified = CreateFrame("CheckButton", nil, spells, "UICheckButtonTemplate")
    verified:SetSize(24, 24); verified:SetPoint("TOPLEFT", 0, -346)
    ns.Text(verified, 11, L.I_VERIFIED_THAT_THIS_SPELL_DEALS_DAMAGE_OVER_TIME, 30, -5)
    local result = ns.Text(spells, 11, L.USE_THE_DEBUFF_ID_WHICH_CAN_DIFFER_FROM_THE_CAST_SPELL_ID, 0, -383, {.62, .66, .76})
    result:SetWidth(520)
    Button(spells, L.ADD_DOT, 145, 570, -308, function()
        local ok, message = ns.AddCustom(input:GetText(), verified:GetChecked())
        result:SetText(message)
        if ok then input:SetText(""); verified:SetChecked(false); input:ClearFocus(); RefreshSpellList() end
    end)

    Button(spells, L.SPELL_TRAY, 145, 570, -26, function() ns.ToggleSpellTray() end)

    local layout = Page(L.NAV_LAYOUT, L.LAYOUT_DESCRIPTION)
    for i, unit in ipairs(ns.units) do
        local token = unit
        Choice(layout, ns.unitNames[unit], 180, (i - 1) * 184, -38,
            function() return selectedUnit == token end, function() selectedUnit = token; ns.RefreshOptions() end)
    end
    Section(layout, L.PLACEMENT, -88)
    ns.Text(layout, 14, L.BAR_LAYOUT, 0, -130)
    Choice(layout, L.STACKED, 170, 220, -122, function() return not ns.db.groups[selectedUnit].free end,
        function() ns.db.groups[selectedUnit].free=false; ns.Apply(); ns.RefreshOptions() end)
    Choice(layout, L.INDEPENDENT, 170, 395, -122, function() return ns.db.groups[selectedUnit].free end,
        function() ns.db.groups[selectedUnit].free=true; ns.Apply(); ns.RefreshOptions() end)
    ns.Text(layout, 14, L.GROWTH_DIRECTION, 0, -170)
    Dropdown(layout, 235, 220, -162, {{label=L.DOWNWARD,value=false},{label=L.UPWARD,value=true}},
        function() return ns.db.groups[selectedUnit].growUp end, function(v) ns.db.groups[selectedUnit].growUp=v end)
    Section(layout, L.DIMENSIONS_SPACING, -210)
    local w = Slider(layout, L.BAR_WIDTH, 0, -246, 120, 700, 5,
        function() return ns.db.groups[selectedUnit].width end, function(v) ns.db.groups[selectedUnit].width=v end)
    local h = Slider(layout, L.BAR_HEIGHT, 0, -282, 16, 64, 1,
        function() return ns.db.groups[selectedUnit].height end, function(v) ns.db.groups[selectedUnit].height=v end)
    local help = ns.Text(layout, 12, L.INDEPENDENT_SIZE_HELP, 0, -250, {.8,.78,.72}); help:SetWidth(730)
    local arrange = Button(layout, L.ARRANGE_SLOTS, 240, 0, -280, function()
        local unit, profile = selectedUnit, ns.db
        ns.Confirm(string.format(L.ARRANGE_CONFIRM, ns.unitNames[unit]), L.ARRANGE_SLOTS, function()
            if ns.db==profile and ns.ArrangeBySlots(unit) then ns.Apply(); ns.RefreshOptions() end
        end)
    end)
    refreshers[#refreshers+1] = function()
        local independent=ns.db.groups[selectedUnit].free
        w:SetShown(not independent); h:SetShown(not independent)
        help:SetShown(independent); arrange:SetShown(independent)
    end
    Slider(layout, L.SPACE_BETWEEN_BARS, 0, -318, 0, 24, 1,
        function() return ns.db.groups[selectedUnit].gap end, function(v) ns.db.groups[selectedUnit].gap=v end)
    Section(layout, L.COPY_LAYOUT, -366)
    local copyLabel=ns.Text(layout, 13, "", 0, -410)
    local destination="other"
    local function Others()
        local list={}; for _,unit in ipairs(ns.units) do if unit~=selectedUnit then list[#list+1]=unit end end
        return list
    end
    local destinations={{label=L.OTHER_UNIT,value="other"},{label=L.SECOND_OTHER_UNIT,value="second"},{label=L.COPY_LAYOUT_BOTH,value="both"}}
    refreshers[#refreshers+1]=function()
        local others=Others(); destinations[1].label=ns.unitNames[others[1]]; destinations[2].label=ns.unitNames[others[2]]
        copyLabel:SetText(string.format(L.COPY_SOURCE, ns.unitNames[selectedUnit]))
    end
    Dropdown(layout, 250, 220, -402, destinations, function() return destination end, function(v) destination=v end)
    Button(layout, L.COPY, 100, 485, -402, function()
        local others=Others()
        ns.CopyLayout(selectedUnit,destination=="both" and others or {others[destination=="second" and 2 or 1]})
        ns.RefreshOptions()
    end)
    Button(layout, L.RESET_THIS_LAYOUT, 140, 600, -402, function()
        local unit, profile = selectedUnit, ns.db
        ns.Confirm(string.format(L.RESET_LAYOUT_CONFIRM, ns.unitNames[unit]), L.RESET_THIS_LAYOUT, function()
            if ns.db ~= profile or InCombatLockdown() then return end
            local enabled = ns.db.groups[unit].enabled
            ns.db.groups[unit] = ns.Copy(ns.Defaults().groups[unit])
            ns.db.groups[unit].enabled = enabled
            ns.Apply(); ns.RefreshOptions()
        end)
    end)
    ns.Text(layout, 11, L.COPY_POSITION_HELP, 0, -440, {.70,.68,.62})

    local style = Page(L.QUIET_DETAIL_CLEAR_TIMERS, L.A_RESTRAINED_PALETTE_READABLE_LABELS_AND_SIMPLE_BAR_TEXTURES)
    Check(style, L.SPELL_ICONS, nil, 0, -40,
        function() return ns.db.icons end, function(v) ns.db.icons = v end)
    Check(style, L.COLOR_BY_SCHOOL, nil, 200, -40,
        function() return ns.db.colorBySchool end, function(v) ns.db.colorBySchool = v end)
    -- Fallback color: custom DoTs with no known type, or every DoT when type colors are off.
    ns.Text(style, 13, L.OTHER_DOTS_COLOR, 470, -46)
    local colorItems = {}
    for i, color in ipairs(ns.colors) do
        colorItems[i] = {value = i, label = string.format("|cff%02x%02x%02x%s|r",
            math.floor(color[1] * 255 + .5), math.floor(color[2] * 255 + .5), math.floor(color[3] * 255 + .5), color.name)}
    end
    ns.otherColorDropdown = Dropdown(style, 160, 580, -38, colorItems,
        function() return ns.db.color end, function(v) ns.db.color = v end)
    -- Two scrolling lists side by side: built-in items, then any from SharedMedia.
    -- Texture rows draw the texture in the bar color; font rows draw their name in that font.
    local function MediaList(x, title, getList, field, decorate)
        ns.Text(style, 11, title, x, -90, accent)
        local scroll = CreateFrame("ScrollFrame", nil, style, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", x, -112)
        scroll:SetSize(340, 110)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(340, 110)
        scroll:SetScrollChild(child)
        local rows = {}
        refreshers[#refreshers + 1] = function()
            local list = getList()
            for i, item in ipairs(list) do
                local row = rows[i]
                if not row then
                    row = CreateFrame("Button", nil, child)
                    row:SetSize(336, 20)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
                    ns.Surface(row, {.10, .11, .16, .92})
                    row.swatch = row:CreateTexture(nil, "ARTWORK")
                    row.swatch:SetPoint("TOPLEFT", 1, -1)
                    row.swatch:SetPoint("BOTTOMRIGHT", -1, 1)
                    row.mark = row:CreateTexture(nil, "OVERLAY")
                    row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(3)
                    row.mark:SetColorTexture(1, .82, .25, 1)
                    row.label = ns.Text(row, 11, "", 10, -4)
                    row.label:SetWidth(225); row.label:SetWordWrap(false)
                    Tooltip(row, function(self) return self.fullName or "" end)
                    row.source = ns.Text(row, 10, "", 0, -5, {.85, .87, .92})
                    row.source:ClearAllPoints(); row.source:SetPoint("RIGHT", -6, 0)
                    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
                    row:SetScript("OnClick", function(self)
                        ns.db[field] = self.key; ns.Apply(); ns.RefreshOptions()
                    end)
                    rows[i] = row
                end
                row.key = item.key
                row.fullName = item.name
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
    ns.fontRows = MediaList(380, L.BAR_FONT, ns.FontList, "font", function(row, f)
        row.swatch:SetColorTexture(.13, .14, .20, 1)
        -- A font a pack lists but the client cannot load falls back to the default.
        if not pcall(row.label.SetFont, row.label, f.path or ns.Font(), 12, "") then
            row.label:SetFont(ns.Font(), 12, "")
        end
    end)
    local mediaNote = ns.Text(style, 10, "", 0, -232, {.57, .62, .72})
    mediaNote:SetWidth(740)
    refreshers[#refreshers + 1] = function()
        if not ns.FindTexture(ns.db.texture) then
            mediaNote:SetText(string.format(L.TEXTURE_NOT_LOADED, ns.db.texture))
        elseif not ns.FindFont(ns.db.font) then
            mediaNote:SetText(string.format(L.FONT_NOT_LOADED, ns.db.font))
        else
            mediaNote:SetText(L.TEXTURE_SHAREDMEDIA_NOTE)
        end
    end
    -- Per-DoT colors: click a chip to pick, right-click to return to its type color.
    ns.Text(style, 11, L.DOT_COLORS, 0, -258, accent)
    local chipHelp = ns.Text(style, 10, L.SPELL_COLOR_HELP, 120, -259, {.57, .62, .72})
    chipHelp:SetWidth(600)
    local chipScroll = CreateFrame("ScrollFrame", nil, style, "UIPanelScrollFrameTemplate")
    chipScroll:SetPoint("TOPLEFT", 0, -278); chipScroll:SetSize(712, 50)
    local chipChild = CreateFrame("Frame", nil, chipScroll); chipChild:SetSize(712, 50)
    chipScroll:SetScrollChild(chipChild)
    local chips = {}
    refreshers[#refreshers + 1] = function()
        local entries = ns.Entries()
        for i, entry in ipairs(entries) do
            local chip = chips[i]
            if not chip then
                chip = CreateFrame("Button", nil, chipChild)
                chip:SetSize(136, 22)
                chip:SetPoint("TOPLEFT", ((i - 1) % 5) * 142, -math.floor((i - 1) / 5) * 26)
                ns.Surface(chip, {.10, .11, .16, .92})
                local hover = chip:CreateTexture(nil, "HIGHLIGHT")
                hover:SetAllPoints(); hover:SetColorTexture(1, .82, .25, .08)
                chip.swatch = chip:CreateTexture(nil, "ARTWORK")
                chip.swatch:SetPoint("LEFT", 4, 0); chip.swatch:SetSize(30, 14)
                chip.label = ns.Text(chip, 11, "", 40, -5)
                chip.label:SetWidth(92); chip.label:SetWordWrap(false)
                chip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                chip:SetScript("OnClick", function(self, button)
                    if button == "RightButton" then SetSpellColor(self.entry.key, nil) else PickSpellColor(self.entry) end
                end)
                Tooltip(chip, function(self) return (self.entry and self.entry.name or "") .. "\n" .. L.SPELL_COLOR_HELP end)
                chips[i] = chip
            end
            chip.entry = entry
            chip.swatch:SetTexture(ns.BarTexture())
            chip.swatch:SetVertexColor(ns.EntryColor(entry))
            chip.label:SetText(entry.name)
            chip:Show()
        end
        for i = #entries + 1, #chips do chips[i]:Hide() end
        chipChild:SetHeight(math.max(50, math.ceil(#entries / 5) * 26))
    end
    ns.colorChips = chips
    Slider(style, L.TEXT_SIZE, 0, -338, 9, 20, 1,
        function() return ns.db.fontSize end, function(v) ns.db.fontSize = v end)
    local lockedNote = ns.Text(style, 10, L.STYLE_LOCKED_NOTE, 0, -376, {.57, .62, .72})
    lockedNote:SetWidth(740)

    -- Profiles: switch, create (from class defaults or as a copy), reset, delete.
    local profiles = Page(L.PROFILES_TITLE, L.PROFILES_SUBTITLE)
    local current = ns.Text(profiles, 13, "", 0, -74, accent)
    ns.Text(profiles, 11, L.PROFILE_LIST, 0, -104, accent)
    local profileScroll = CreateFrame("ScrollFrame", nil, profiles, "UIPanelScrollFrameTemplate")
    profileScroll:SetPoint("TOPLEFT", 0, -122)
    profileScroll:SetSize(410, 176)
    local profileChild = CreateFrame("Frame", nil, profileScroll)
    profileChild:SetSize(410, 176)
    profileScroll:SetScrollChild(profileChild)
    local profileRows = {}
    refreshers[#refreshers + 1] = function()
        current:SetText(string.format(L.PROFILE_CURRENT, ns.CurrentProfile() or ""))
        local names = ns.ProfileNames()
        for i, name in ipairs(names) do
            local row = profileRows[i]
            if not row then
                row = CreateFrame("Button", nil, profileChild)
                row:SetSize(406, 26)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 30)
                ns.Surface(row, {.09, .10, .14, 1})
                row.mark = row:CreateTexture(nil, "OVERLAY")
                row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(3)
                row.mark:SetColorTexture(1, .82, .25, 1)
                row.label = ns.Text(row, 12, "", 10, -6)
                row.label:SetWidth(300); row.label:SetWordWrap(false)
                row.tag = ns.Text(row, 10, L.PROFILE_IN_USE, 0, -7, {.57, .62, .72})
                row.tag:ClearAllPoints(); row.tag:SetPoint("RIGHT", -10, 0)
                row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
                row:SetScript("OnClick", function(self) ns.UseProfile(self.name) end)
                row.delete = Button(row, L.PROFILE_DELETE, 64, 338, 2, function()
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
    ns.Text(profiles, 11, L.PROFILE_NEW, 460, -104, accent)
    local profileName = CreateFrame("EditBox", nil, profiles, "InputBoxTemplate")
    profileName:SetAutoFocus(false); profileName:SetMaxLetters(32)
    profileName:SetSize(200, 28); profileName:SetPoint("TOPLEFT", 466, -122)
    profileName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local copyCurrent = CreateFrame("CheckButton", nil, profiles, "UICheckButtonTemplate")
    copyCurrent:SetSize(24, 24); copyCurrent:SetPoint("TOPLEFT", 458, -156)
    local copyText = ns.Text(copyCurrent, 11, L.PROFILE_COPY_CURRENT, 28, -5)
    copyText:SetWidth(220)
    local profileStatus = ns.Text(profiles, 10, "", 460, -230, {1, .45, .35})
    profileStatus:SetWidth(210)
    local function Create()
        local ok, err = ns.CreateProfile(profileName:GetText(), copyCurrent:GetChecked() == true)
        profileStatus:SetText(ok and "" or (err or ""))
        if ok then profileName:SetText(""); profileName:ClearFocus() end
    end
    profileName:SetScript("OnEnterPressed", Create)
    ns.profileName, ns.profileCopy = profileName, copyCurrent
    Button(profiles, L.PROFILE_CREATE, 120, 460, -194, Create)
    Button(profiles, L.PROFILE_RESET, 200, 0, -318, function()
        local name, profile = ns.CurrentProfile(), ns.db
        ns.Confirm(string.format(L.PROFILE_RESET_CONFIRM, name), L.PROFILE_RESET,
            function() ns.ResetProfile(name, profile) end)
    end)

    local nav, selectedPage = {}, 1
    ns.optionPages = pages
    for i, title in ipairs({L.NAV_TRACKING,L.NAV_SPELLS,L.NAV_LAYOUT,L.NAV_APPEARANCE,L.NAV_PROFILES}) do
        local index=i
        nav[i]=Choice(panel,title,145,40+(i-1)*148,-72,function() return selectedPage==index end,function()
            if openMenu then openMenu:Hide(); openMenu=nil end
            selectedPage=index
            for n,page in ipairs(pages) do page:SetShown(n==index) end
            ns.RefreshOptions()
        end)
    end
    ns.optionTabs=nav
    for i,p in ipairs(pages) do p:SetShown(i==1) end
    local preview=CreateFrame("Frame",nil,style)
    preview:SetPoint("TOPLEFT",0,-392); preview:SetSize(740,56)
    ns.Surface(preview, {.075, .082, .115, 1})
    ns.Text(preview, 10, L.STYLE_PREVIEW, 14, -12, accent)
    ns.Text(preview, 10, L.SAMPLE_ONLY, 14, -34, {.5, .55, .65})
    local bar, label, time = ns.CreateBar(preview, 520, 27)
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
    ns.optionsStatus = ns.Text(panel, 10, "", 40, -574, {.65, .64, .60})
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
