local addonName, AddonNS = ...

local NewItemCategorizer = {};

AddonNS.Categories:RegisterCategorizer("New", NewItemCategorizer, true);


function NewItemCategorizer:Categorize(itemID, itemButton)
    local isNew =C_NewItems.IsNewItem(itemButton:GetBagID(), itemButton:GetID())
    return isNew and "|cff9999ff".."New";
end