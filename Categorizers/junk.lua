local addonName, AddonNS = ...

local JunkCategorizer = {};

AddonNS.Categories:RegisterCategorizer("Junk", JunkCategorizer, false);
local name = ITEM_QUALITY_COLORS[Enum.ItemQuality.Poor].hex.."Junk";
function JunkCategorizer:GetConstantCategories()
    return {name}
end
function JunkCategorizer:Categorize(itemID, itemButton)
    local itemInfo = C_Container.GetContainerItemInfo(itemButton:GetBagID(), itemButton:GetID())
    return itemInfo.quality == Enum.ItemQuality.Poor and name;
end 