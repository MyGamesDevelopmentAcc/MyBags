local addonName, AddonNS = ...

local JunkCategorizer = {};

AddonNS.Categories:RegisterCategorizer("Junk", JunkCategorizer, false);


function JunkCategorizer:Categorize(itemID, itemButton)
    local itemInfo = C_Container.GetContainerItemInfo(itemButton:GetBagID(), itemButton:GetID())
    return itemInfo.quality == Enum.ItemQuality.Poor and ITEM_QUALITY_COLORS[Enum.ItemQuality.Poor].hex.."Junk";
end