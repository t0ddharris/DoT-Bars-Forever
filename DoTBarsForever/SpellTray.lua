local addonName, ns = ...
local L = ns.L
-- The spell tray is a bar of slots shared by every unit. Slot order is bar order.
local PER_ROW, PITCH, SIZE = 7, 44, 38
local tray, ghost
local slots, palette = {}, {}
local fromActionBar = false

local function Icon(entry)
    local info = entry and ns.SpellInfo(entry.ids[1])
    return info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- GetCursorInfo's spell returns are ("spell", slot, bookType, spellID[, baseSpellID]);
-- read them defensively because the generated catalog does not declare them.
-- nil: nothing on the cursor; false: something that is not a usable spell.
local function CursorSpell()
    if not GetCursorInfo then return nil end
    local kind, _, _, spellID, baseID = GetCursorInfo()
    if kind == nil or ns.Secret(kind) then return nil end
    if kind ~= "spell" then return false end
    for _, id in ipairs({spellID, baseID}) do
        if not ns.Secret(id) and type(id) == "number" and ns.SpellInfo(id) then return id end
    end
    return false
end

local function EntryForSpell(id) return ns.EntryForSpell(id) end

local function Slot(entry, index)
    if ns.SetSlot(entry.key, index) then
        for i, e in ipairs(ns.OrderedEntries()) do
            if e.key == entry.key then ns.Report(string.format(L.TRAY_SLOTTED, entry.name, i)) end
        end
        return true
    end
    return false
end

-- Our own confirmation window. Never write to StaticPopupDialogs or call
-- StaticPopup_Show: on Forever that table belongs to the load-on-demand
-- Blizzard_StaticPopup_Game, and touching it from addon code taints the shared
-- popups, so later protected dialogs (for example "allow scripts") are blocked
-- with ADDON_ACTION_FORBIDDEN blamed on this addon.
local confirm
local function ConfirmButton(parent, text, x, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(120, 24)
    b:SetPoint("BOTTOM", x, 14)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Shows the addon's own confirmation window: message, accept label, action on accept.
function ns.Confirm(message, acceptLabel, onAccept)
    ns.ConfirmTrack(nil, nil)
    confirm.text:SetText(message)
    confirm.accept:SetText(acceptLabel)
    confirm.onAccept = onAccept
    confirm:Show()
end

function ns.ConfirmTrack(name, data)
    if not confirm then
        confirm = CreateFrame("Frame", "DoTBarsForeverConfirm", UIParent, "BackdropTemplate")
        confirm:SetFrameStrata("DIALOG")
        confirm:SetToplevel(true)
        confirm:SetSize(400, 170)
        confirm:SetPoint("CENTER", 0, 120)
        confirm:EnableMouse(true)
        confirm:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        confirm:SetBackdropColor(.055, .065, .09, .97)
        confirm:SetBackdropBorderColor(.64, .43, .96, 1)
        confirm.text = ns.Text(confirm, 12, "", 16, -16)
        confirm.text:SetWidth(368)
        confirm.text:SetWordWrap(true)
        confirm.accept = ConfirmButton(confirm, L.TRAY_TRACK, -66, function()
            local pending, action = confirm.data, confirm.onAccept
            confirm:Hide()
            if action then action() elseif pending then ns.TrackDroppedSpell(pending, true) end
        end)
        confirm.cancel = ConfirmButton(confirm, CANCEL or "Cancel", 66, function() confirm:Hide() end)
        UISpecialFrames[#UISpecialFrames + 1] = "DoTBarsForeverConfirm"
        ns.confirmFrame = confirm
    end
    if name == nil then return end -- created for ns.Confirm
    confirm.data, confirm.onAccept = data, nil
    confirm.accept:SetText(L.TRAY_TRACK)
    confirm.text:SetText(string.format(L.TRAY_CONFIRM_CUSTOM, name))
    confirm:Show()
end

-- data = {id = spellID, index = slot}
function ns.TrackDroppedSpell(data, confirmed)
    local entry = EntryForSpell(data.id)
    if not entry and confirmed then
        local ok, message = ns.AddCustom(tostring(data.id), true)
        if not ok then ns.Report(message); return false end
        entry = ns.db.custom[#ns.db.custom]
    end
    if not entry then
        local info = ns.SpellInfo(data.id)
        ns.ConfirmTrack(info and info.name or tostring(data.id), data)
        return false
    end
    return Slot(entry, data.index)
end

-- A spell from the spellbook or an action bar dropped (or clicked) onto a slot.
local function CursorDrop(index)
    if InCombatLockdown() then return false end
    local id = CursorSpell()
    if id == nil then return false end
    -- Never clear a macro or item: taken off an action bar, it would be lost.
    if not id then ns.Report(L.TRAY_NOT_A_SPELL); return true end
    local info = ns.SpellInfo(id)
    if fromActionBar then
        -- It has left that action bar; keep it on the cursor so it can go back.
        ns.Report(string.format(L.TRAY_PUT_BACK, info and info.name or tostring(id)))
    elseif ClearCursor then
        ClearCursor()
    end
    ns.TrackDroppedSpell({id = id, index = index}, false)
    return true
end

local function SlotUnderMouse()
    if not MouseIsOver then return nil end
    for i, slot in ipairs(slots) do
        if slot:IsShown() and MouseIsOver(slot) then return i end
    end
end

local function FinishDrag(cancel)
    if not ghost or not ghost.entry then return end
    local entry = ghost.entry
    ghost.entry = nil
    ghost:Hide()
    ghost:SetScript("OnUpdate", nil)
    if cancel or InCombatLockdown() then return end
    local target = SlotUnderMouse()
    if target then Slot(entry, target) end
end

local function Drag(entry)
    if InCombatLockdown() or not entry then return end
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetSize(SIZE, SIZE)
        ghost:SetFrameStrata("TOOLTIP")
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
        ghost.icon:SetAllPoints()
        ghost.icon:SetTexCoord(.07, .93, .07, .93)
        ghost:EnableMouse(false)
    end
    ghost.entry = entry
    ghost.icon:SetTexture(Icon(entry))
    ghost:Show()
    ghost:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints()
        ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        if not IsMouseButtonDown("LeftButton") then FinishDrag(false) end
    end)
end

local function ShowTooltip(button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.entry then
        if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(button.entry.ids[1])
        else GameTooltip:SetText(button.entry.name) end
        GameTooltip:AddLine(button.isSlot and L.TRAY_SLOT_HINT or L.TRAY_AVAILABLE, .6, .8, 1, true)
    else
        GameTooltip:SetText(L.TRAY_EMPTY_SLOT)
        GameTooltip:AddLine(L.TRAY_EMPTY_SLOT_HINT, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function SlotButton(parent, isSlot)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIZE, SIZE)
    b.isSlot = isSlot
    local art = b:CreateTexture(nil, "BACKGROUND")
    art:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    art:SetPoint("CENTER")
    art:SetSize(SIZE * 1.65, SIZE * 1.65)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(.07, .93, .07, .93)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    if isSlot then b.number = ns.Text(b, 10, "", 3, -2, {1, .82, .25}) end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:HookScript("OnMouseDown", function(self) self.dragged = nil end)
    b:SetScript("OnDragStart", function(self)
        if self.entry then self.dragged = true; Drag(self.entry) end
    end)
    b:SetScript("OnDragStop", function() FinishDrag(false) end)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

local function Place(button, index)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", tray, "TOPLEFT", 20 + ((index - 1) % PER_ROW) * PITCH,
        button.rowTop - math.floor((index - 1) / PER_ROW) * PITCH)
end

local function Rows(count) return math.max(1, math.ceil(count / PER_ROW)) end

function ns.UpdateSpellTray()
    if not tray then return end
    if not ns.editing then FinishDrag(true); tray:Hide(); return end
    local ordered = ns.OrderedEntries()
    local slotted = {}
    for _, entry in ipairs(ordered) do slotted[entry.key] = true end
    local holding = CursorSpell() ~= nil
    -- Always one empty slot after the last spell, in whole rows.
    local slotCount = math.max(PER_ROW, Rows(#ordered + 1) * PER_ROW)
    local top = -84
    for i = 1, slotCount do
        local b = slots[i]
        if not b then
            b = SlotButton(tray, true)
            local index = i
            b:SetScript("OnReceiveDrag", function() CursorDrop(index) end)
            b:SetScript("OnClick", function(self, button)
                if self.dragged then self.dragged = nil; return end
                if CursorDrop(index) then return end
                if button == "RightButton" and self.entry then ns.ClearSlot(self.entry.key) end
            end)
            slots[i] = b
        end
        b.rowTop = top
        Place(b, i)
        b.entry = ordered[i]
        b.icon:SetTexture(b.entry and Icon(b.entry) or nil)
        b.icon:SetShown(b.entry ~= nil)
        b.number:SetText(i)
        if holding and not b.entry then b:LockHighlight() else b:UnlockHighlight() end
        b:Show()
    end
    for i = slotCount + 1, #slots do slots[i]:Hide() end
    local y = top - Rows(slotCount) * PITCH - 8
    tray.availableTitle:ClearAllPoints()
    tray.availableTitle:SetPoint("TOPLEFT", 18, y)
    y = y - 20
    local available = {}
    for _, entry in ipairs(ns.Entries()) do
        if not slotted[entry.key] then available[#available + 1] = entry end
    end
    for i, entry in ipairs(available) do
        local b = palette[i]
        if not b then
            b = SlotButton(tray, false)
            b:SetScript("OnClick", function(self)
                if self.dragged then self.dragged = nil; return end
                if self.entry then Slot(self.entry, #ns.OrderedEntries() + 1) end
            end)
            palette[i] = b
        end
        b.rowTop = y
        Place(b, i)
        b.entry = entry
        b.icon:SetTexture(Icon(entry))
        b:Show()
    end
    for i = #available + 1, #palette do palette[i]:Hide() end
    tray.noneAvailable:SetShown(#available == 0)
    tray.noneAvailable:ClearAllPoints()
    tray.noneAvailable:SetPoint("TOPLEFT", 18, y - 4)
    y = y - (#available > 0 and Rows(#available) * PITCH or 22) - 6
    tray.footer:ClearAllPoints()
    tray.footer:SetPoint("TOPLEFT", 18, y)
    tray.customNote:ClearAllPoints()
    tray.customNote:SetPoint("TOPLEFT", 18, y - 44)
    tray:SetHeight(-(y - 44) + 30)
end

function ns.ToggleSpellTray()
    if InCombatLockdown() then ns.Report(L.FINISH_COMBAT_BEFORE_PLACING_SPELLS); return end
    if tray and tray:IsShown() then tray:Hide(); FinishDrag(true); return end
    ns.SetEditing(true)
    if not tray then
        tray = CreateFrame("Frame", "DoTBarsForeverSpellTray", UIParent, "ButtonFrameTemplate")
        ns.spellTray = tray
        tray:SetSize(PER_ROW * PITCH + 40, 360)
        tray:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -150)
        tray:SetFrameStrata("HIGH")
        tray:SetToplevel(true)
        tray:SetClampedToScreen(true)
        tray:SetMovable(true); tray:EnableMouse(true); tray:RegisterForDrag("LeftButton")
        tray:SetScript("OnDragStart", function() tray:StartMoving() end)
        tray:SetScript("OnDragStop", function() tray:StopMovingOrSizing() end)
        -- A spell dropped anywhere on the tray goes into the first empty slot.
        tray:SetScript("OnReceiveDrag", function() CursorDrop(#ns.OrderedEntries() + 1) end)
        if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(tray) end
        if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(tray) end
        if tray.Inset then tray.Inset:Hide() end
        if tray.SetTitle then tray:SetTitle(L.DOT_SPELL_TRAY) end
        local help = ns.Text(tray, 11, L.TRAY_HELP, 18, -34)
        help:SetWidth(PER_ROW * PITCH)
        ns.Text(tray, 12, L.TRAY_SLOTS, 18, -64, {1, .82, .25})
        tray.availableTitle = ns.Text(tray, 12, L.TRAY_AVAILABLE, 18, 0, {1, .82, .25})
        tray.noneAvailable = ns.Text(tray, 11, L.TRAY_NONE_AVAILABLE, 18, 0, {.75, .78, .85})
        tray.footer = ns.Text(tray, 10, L.TRAY_FOOTER, 18, 0, {.75, .78, .85})
        tray.footer:SetWidth(PER_ROW * PITCH)
        tray.customNote = ns.Text(tray, 10, L.CUSTOM_DOTS_CAN_BE_ADDED_ON_THE_SPELLS_OPTIONS_PAGE, 18, 0, {.6, .63, .7})
        tray:SetScript("OnHide", function() FinishDrag(true) end)
        UISpecialFrames[#UISpecialFrames + 1] = "DoTBarsForeverSpellTray"
    end
    ns.UpdateSpellTray()
    tray:Show()
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("CURSOR_CHANGED")
watcher:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
watcher:SetScript("OnEvent", function(_, event)
    local holding = GetCursorInfo and GetCursorInfo()
    if event == "ACTIONBAR_SLOT_CHANGED" then
        -- A slot emptying while a spell sits on the cursor means it came off an action bar.
        if holding then fromActionBar = true end
        return
    end
    if not holding then fromActionBar = false end
    if tray and tray:IsShown() then ns.UpdateSpellTray() end
end)
