local addonName, AddonNS = ...

-- events
local Custom = {};
AddonNS.CustomCategories = {}
local categorizedItems = {}
local customCategories = {}

AddonNS.Categories:RegisterCategorizer("Custom categorizer", Custom);

-- function Custom:GetConstantCategories()
--     local categories = {};
--     for i, _ in pairs(customCategories) do
--         table.insert(categories, i);
--     end
--     table.sort(categories)
--     return categories;
-- end

function Custom:Categorize(itemID)
    return categorizedItems[itemID];
end

function AddonNS.CustomCategories:OnInitialize()

    AddonNS.db.customCategories = AddonNS.db.customCategories or customCategories;
    customCategories = AddonNS.db.customCategories;

    for category, items in pairs(customCategories) do
        for i, v in ipairs(items) do
            categorizedItems[v] = category;
        end
    end
end

function AddonNS.CustomCategories:OnShutDown()
    customCategories = {};
    for itemID, categoryName in ipairs(categorizedItems) do
        categorizedItems[categoryName] = categorizedItems[categoryName] or {};
        table.insert(categorizedItems[categoryName], itemID);
    end
end

AddonNS.Events:OnInitialize(AddonNS.CustomCategories.OnInitialize)
AddonNS.Events:RegisterEvent("PLAYER_LOGOUT", AddonNS.CustomCategories.OnShutDown);
function AddonNS.CustomCategories:GetCategories()
    local categories = {};
    for i, _ in pairs(customCategories) do
        categories[i] = true;
    end
    return categories;
end


function AddonNS.CustomCategories:NewCategory(categoryName)
    customCategories[categoryName] = customCategories[categoryName] or {};
end

function AddonNS.CustomCategories:RenameCategory(fromCategoryName, toCategoryName)
    if (customCategories[fromCategoryName]) then
        if (customCategories[toCategoryName]) then
            for i, v in ipairs(customCategories[fromCategoryName]) do
                table.insert(customCategories[toCategoryName], v);
            end
        else
            customCategories[toCategoryName] = customCategories[fromCategoryName];
        end
        customCategories[fromCategoryName] = nil;
        -- update categorization
        for i, v in ipairs(customCategories[toCategoryName]) do
            categorizedItems[v] = toCategoryName;
        end
        AddonNS.Events:TriggerCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_RENAMED, fromCategoryName, toCategoryName);
    end
end

function AddonNS.CustomCategories:DeleteCategory(categoryName)
    for i, v in ipairs(customCategories[categoryName]) do
        categorizedItems[v] = nil;
    end
    customCategories[categoryName] = nil;
    AddonNS.Events:TriggerCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_DELETED, categoryName);
end


local function itemMoved(eventName, pickedItemID, targetedItemID, pickedItemCategory, targetItemCategory,
                         pickedItemButton,
                         targetItemButton)
    
    AddonNS.CustomCategories:AssignToCategory(targetItemCategory, pickedItemID)
end



function AddonNS.CustomCategories:AssignToCategory(newCategory, itemID)
    if (newCategory.protected) then return end;
    AddonNS.printDebug("AssignToCategory changing category of ", itemID, " to ", newCategory and newCategory.name)
    local newCategoryName = newCategory and newCategory.name;
    self:AssignToCategoryByName(newCategoryName, itemID)
end

function AddonNS.CustomCategories:AssignToCategoryByName(newCategoryName, itemID)

    AddonNS.printDebug(" AssignToCategoryByNamechanging category of ", itemID, " to ", newCategoryName)
    local previousCategoryName = categorizedItems[itemID];
    categorizedItems[itemID] = newCategoryName;
    local i = 1;
    if (customCategories[previousCategoryName]) then
        while i <= #customCategories[previousCategoryName] do
            if customCategories[previousCategoryName][i] == itemID then
                table.remove(customCategories[previousCategoryName], i);
                break
            end
            i = i + 1;
        end
    end
    if (newCategoryName) then
        customCategories[newCategoryName] = customCategories[newCategoryName] or {};
        table.insert(customCategories[newCategoryName], itemID);
    end
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Events.ITEM_MOVED, itemMoved)
