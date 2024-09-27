local addonName, AddonNS = ...


AddonNS.Categories = {};





local UNASSIGNED_CATEGORY = { name = nil, protected = false };
local categorizers = OrderedMap:new()
local categories = {};
function AddonNS.Categories:RegisterCategorizer(name, categorizer, protected, description)
    categorizers:set(name, { categorizer = categorizer, protected = protected, description = description });
end

function AddonNS.Categories:GetConstantCategories()
    local constantCategories = {}
    for categoryName, _ in pairs(AddonNS.CategorShowAlways:GetAlwaysShownCategories()) do
        local protected = false; -- todo: replace once protection will be configurable
        if not categories[categoryName] then
            categories[categoryName] = { name = categoryName, protected = protected };
        end
        table.insert(constantCategories, categories[categoryName]);
    end
    return constantCategories;
end

function AddonNS.Categories:Categorize(itemID, itemButton)
    local categoryName;
    for _, categorizerDef in categorizers:iterate() do
        categoryName = categorizerDef.categorizer:Categorize(itemID, itemButton);
        if categoryName then
            if not categories[categoryName] then
                categories[categoryName] = {
                    name = categoryName,
                    protected = categorizerDef.protected,
                    OnRightClick = categorizerDef.categorizer.OnRightClick,
                    description = categorizerDef.description
                };
            end
            return categories[categoryName];
        end;
    end
    return UNASSIGNED_CATEGORY
end

function AddonNS.Categories:GetCategoryByName(categoryName)
    if categoryName == AddonNS.Const.UNASSIGNE_CATEGORY_DB_STORAGE_NAME then return UNASSIGNED_CATEGORY end;
    return categories[categoryName]
end



local function categoryRenamed(eventName, fromCategoryName, toCategoryName)
    AddonNS.printDebug(eventName)
    if (fromCategoryName == toCategoryName) then
        return
    end
    AddonNS.printDebug("received categoryRenamed event", fromCategoryName, toCategoryName)
    if categories[fromCategoryName] then
        if (not categories[toCategoryName]) then
            categories[toCategoryName] = categories[fromCategoryName];
            categories[fromCategoryName].name = toCategoryName;
        end
        categories[fromCategoryName] = nil;
    end
end

local function categoryDeleted(eventName, categoryName)
    categories[categoryName] = nil;
end


AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_RENAMED, categoryRenamed)
