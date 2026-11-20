local addonName, ns = ...
local L = ns.L

function ns.UpdateMinimap()
    if not Minimap then return end
    local b = ns.minimapButton
    if not b then
        b = CreateFrame("Button", "DoTBarsForeverMinimapButton", Minimap)
        ns.minimapButton = b
        -- The usual round minimap button: dark round backing, a round-masked icon and the
        -- game's gold tracking ring, so it matches other addons' buttons.
        b:SetSize(31, 31)
        b:SetFrameStrata("MEDIUM")
        b:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        local back = b:CreateTexture(nil, "BACKGROUND")
        back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        back:SetSize(24, 24)
        back:SetPoint("CENTER")
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\TimerBars.tga")
        icon:SetSize(20, 20)
        icon:SetPoint("CENTER")
        if b.CreateMaskTexture and icon.AddMaskTexture then
            local mask = b:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(icon)
            icon:AddMaskTexture(mask)
        end
        b.icon = icon
        local ring = b:CreateTexture(nil, "OVERLAY")
        ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        ring:SetSize(53, 53)
        ring:SetPoint("TOPLEFT")
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        -- Whether a drag release also fires OnClick is client-dependent; each new press clears the flag.
        b:HookScript("OnMouseDown", function() b.dragged = nil end)
        b:SetScript("OnClick", function(_, button)
            if b.dragged then b.dragged = nil; return end
            if button == "RightButton" then ns.SetEditing(not ns.editing) else ns.ToggleOptions() end
        end)
        b:SetScript("OnDragStart", function()
            b.dragged = true
            b:SetScript("OnUpdate", function()
                local x, y = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                local cx, cy = Minimap:GetCenter()
                local atan2 = math.atan2
                if not atan2 then return end
                ns.db.minimapAngle = math.deg(atan2(y / scale - cy, x / scale - cx))
                ns.UpdateMinimap()
            end)
        end)
        b:SetScript("OnDragStop", function() b:SetScript("OnUpdate", nil) end)
        b:SetScript("OnEnter", function()
            GameTooltip:SetOwner(b, "ANCHOR_LEFT")
            GameTooltip:SetText("DoT Bars Forever")
            GameTooltip:AddLine(L.LEFT_CLICK_OPTIONS, 1, 1, 1)
            GameTooltip:AddLine(L.RIGHT_CLICK_EDIT_LAYOUT, 1, 1, 1)
            GameTooltip:AddLine(L.DRAG_MOVE_MINIMAP_BUTTON, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local angle = math.rad(ns.db.minimapAngle)
    local radius = Minimap:GetWidth() / 2 + 10
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    b:SetShown(ns.db.minimap)
end
