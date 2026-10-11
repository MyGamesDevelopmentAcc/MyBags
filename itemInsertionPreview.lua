local addonName, AddonNS = ...

AddonNS.ItemInsertionPreview = {}

local Preview = AddonNS.ItemInsertionPreview
local marker = CreateFrame("Frame", nil, UIParent)
marker:SetFrameStrata("TOOLTIP")
marker:EnableMouse(false)
marker:SetSize(8, 52)
marker.Texture = marker:CreateTexture(nil, "ARTWORK")
marker.Texture:SetSize(52, 52)
marker.Texture:SetPoint("CENTER", marker, "CENTER")
marker.Texture:SetBlendMode("ADD")
marker.Texture:SetAtlas("CDM-vertical")
marker:Hide()

function Preview:GetInsertionSide(itemButton)
    if not itemButton then
        return "end"
    end
    local cursorX = GetCursorPosition()
    cursorX = cursorX / itemButton:GetEffectiveScale()
    local centerX = itemButton:GetLeft() + itemButton:GetWidth() / 2
    return cursorX < centerX and "before" or "after"
end

function Preview:GetTarget()
    -- Mouse focus is external: walk child textures/overlays to the addon-owned
    -- item, category, or background frame that supplies its strict contract.
    local focus = GetMouseFoci()[1]
    while focus do
        if focus.MyBagsCategoryFrame then
            return focus.MyBagsCategoryFrame, focus
        end
        if focus.ItemCategory and focus.MyBagsItems then
            return focus
        end
        if focus.isAddCategoryControl then
            return nil
        end
        if focus.MyBagsResolveDropColumn then
            return focus:GetCategoryFrameAtCursor()
        end
        if not focus.GetParent then
            return nil
        end
        focus = focus:GetParent()
    end
end

function Preview:Hide()
    marker:Hide()
end

function Preview:Update()
    local itemID = AddonNS.DragAndDrop:GetDraggedItemID()
    if not itemID then
        self:Hide()
        return
    end
    local categoryFrame, targetButton = self:GetTarget()
    if not categoryFrame or not categoryFrame:IsShown() then
        self:Hide()
        return
    end
    local category = categoryFrame.ItemCategory
    if category:IsProtected() or not category:IsVisibleInScope(categoryFrame.MyBagsScope) or
        AddonNS.Collapsed.isCollapsed(category, categoryFrame.MyBagsScope) then
        self:Hide()
        return
    end
    if targetButton and targetButton._myBagsItemId == itemID then
        self:Hide()
        return
    end

    local anchor = targetButton
    local side = self:GetInsertionSide(targetButton)
    if not targetButton then
        -- Category item arrays are sorted in reverse of their visible order.
        -- Exclude every stack of the dragged ID from the append endpoint.
        for _, button in ipairs(categoryFrame.MyBagsItems) do
            if button._myBagsItemId ~= itemID then
                anchor = button
                break
            end
        end
    end
    local anchorFrame = anchor or categoryFrame
    marker:SetScale(anchorFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
    marker:ClearAllPoints()
    if anchor then
        marker:SetHeight(anchor:GetHeight() + AddonNS.Const.ITEM_SPACING * 2)
        if side == "before" then
            marker:SetPoint("CENTER", anchor, "LEFT", -AddonNS.Const.ITEM_SPACING / 2, 0)
        else
            marker:SetPoint("CENTER", anchor, "RIGHT", AddonNS.Const.ITEM_SPACING / 2, 0)
        end
    else
        local itemHeight = categoryFrame.MyBagsItemSize - AddonNS.Const.ITEM_SPACING
        marker:SetHeight(itemHeight + AddonNS.Const.ITEM_SPACING * 2)
        marker:SetPoint("CENTER", categoryFrame, "TOPLEFT", AddonNS.Const.ITEM_SPACING / 2,
            -AddonNS.Const.CATEGORY_HEIGHT - itemHeight / 2)
    end
    marker.Texture:SetHeight(marker:GetHeight())
    marker:Show()
end

-- Keep target tracking independent of category hint updates, including movement
-- between the two halves of an item and cancellation outside addon frames.
local tracker = CreateFrame("Frame")
tracker:SetScript("OnUpdate", function()
    Preview:Update()
end)
