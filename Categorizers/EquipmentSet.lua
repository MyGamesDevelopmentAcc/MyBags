local addonName, AddonNS = ...

-- events
local EquipmentSet = {};

AddonNS.Categories:RegisterCategorizer("EquipmentSet", EquipmentSet, true);

local itemSets = {};

function EquipmentSet:Categorize(itemID, itemButton)
    return itemSets[itemButton:GetBagID()] and itemSets[itemButton:GetBagID()][itemButton:GetID()] or nil;
end

local function setItemCategoryIfEmpty(bag, slot, category)
    itemSets[bag] = itemSets[bag] or {};
    if (not itemSets[bag][slot]) then
        itemSets[bag][slot] = category;
    end
end
local function setItemSetCategory(bag, slot, category)
    itemSets[bag] = itemSets[bag] or {};
    itemSets[bag][slot] = category;
end
local function cleanItemCategory(bag, slot)
    itemSets[bag] = itemSets[bag] or {};
    itemSets[bag][slot] = nil;
end
local iconSize = 16;
local function refreshEquipmentSets()
    itemSets = {};
    local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs()
    for _, equipmentSetID in pairs(equipmentSetIDs) do
        local name, iconFileID = C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID)

        local locations = C_EquipmentSet.GetItemLocations(equipmentSetID)

        for inventorySlotID, location in ipairs(locations) do
            if (location > 1 or location < -1) then
                local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
                if bag then
                    local iconString = "|T" .. iconFileID .. ":16:16:0:2:64:64:4:60:4:60|t ";
                    setItemCategoryIfEmpty(bag, slot, iconString .. "|CFFFF2459" .. name)
                end
            end
        end
    end
end

local function itemMoved(eventName, pickedItemID, targetedItemID, pickedItemCategory, targetItemCategory,
                         pickedItemButton,
                         targetItemButton)
    local pickedESCategory = pickedItemButton and EquipmentSet:Categorize(nil, pickedItemButton)
    local targetESCategory = targetItemButton and EquipmentSet:Categorize(nil, targetItemButton)
    if targetItemButton then
        if pickedESCategory then
            setItemSetCategory(targetItemButton:GetBagID(), targetItemButton:GetID(), pickedESCategory)
        else
            cleanItemCategory(targetItemButton:GetBagID(), targetItemButton:GetID())
        end
    end
    if pickedItemButton then
        if targetESCategory then
            setItemSetCategory(pickedItemButton:GetBagID(), pickedItemButton:GetID(), targetESCategory)
        else
            cleanItemCategory(pickedItemButton:GetBagID(), pickedItemButton:GetID())
        end
    end
end
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.ITEM_MOVED, itemMoved)
refreshEquipmentSets();
AddonNS.Events:RegisterEvent("BAG_UPDATE_DELAYED", refreshEquipmentSets);
