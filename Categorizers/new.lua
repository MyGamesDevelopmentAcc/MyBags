local addonName, AddonNS = ...

local NewItemCategorizer = {}
local CATEGORIZER_ID = "new"

local newItems = {}

local rawNew = {
    GetId = function() return "" end,
    GetName = function() return "|cff9999ffNew" end,
    IsProtected = function() return true end,
    OnRightClick = function()
        return NewItemCategorizer:OnRightClick()
    end,
    OnItemUnassigned = function(_, _, context)
        if not context then
            return
        end
        local sourceButton = context.pickedItemButton or context.targetItemButton
        if not sourceButton then
            return
        end
        local bagID = sourceButton:GetBagID()
        local slotIndex = sourceButton:GetID()
        C_NewItems.RemoveNewItem(bagID, slotIndex)
        newItems[bagID] = newItems[bagID] or {}
        newItems[bagID][slotIndex] = nil
    end,
}

local function category()
    return rawNew
end

function NewItemCategorizer:ListCategories()
    return { rawNew }
end

function NewItemCategorizer:GetAlwaysVisibleCategories()
    return { }
end

function NewItemCategorizer:Categorize(itemID, itemButton)
    if not AddonNS.NewItemsSettings:IsEnabled() then
        return nil
    end
    local containerIndex = itemButton:GetBagID()
    local slotIndex = itemButton:GetID()
    local isNew = C_NewItems.IsNewItem(containerIndex, slotIndex)
    if isNew then
        newItems[containerIndex] = newItems[containerIndex] or {}
        newItems[containerIndex][slotIndex] = itemID
    end
    if newItems[containerIndex] and newItems[containerIndex][slotIndex] == itemID then
        return category()
    end
    return nil
end

function NewItemCategorizer:OnRightClick()
    C_NewItems.ClearAll()
    newItems = {}
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, NewItemCategorizer)
    return true
end

function NewItemCategorizer:CheckNewItems(bagID)
    newItems[bagID] = newItems[bagID] or {}
    for slotIndex, expectedItemID in pairs(newItems[bagID]) do
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
        if (not itemLocation:IsValid() or expectedItemID ~= C_Item.GetItemID(itemLocation)) then
            newItems[bagID][slotIndex] = nil
        end
    end
end

AddonNS.Categories:RegisterCategorizer("New", NewItemCategorizer, CATEGORIZER_ID)

AddonNS.Events:RegisterEvent("BAG_UPDATE", NewItemCategorizer.CheckNewItems)
