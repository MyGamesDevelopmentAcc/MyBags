local addonName, AddonNS = ...
AddonNS = AddonNS or {} 

local CategorShowAlways = {};
AddonNS.CategorShowAlways = {};
local categoriesToAlwaysShow = {};

function AddonNS.CategorShowAlways:OnInitialize()
    AddonNS.db.categoriesToAlwaysShow = AddonNS.db.categoriesToAlwaysShow or categoriesToAlwaysShow;
    categoriesToAlwaysShow = AddonNS.db.categoriesToAlwaysShow;
end
AddonNS.Events:OnInitialize(AddonNS.CategorShowAlways.OnInitialize)

function AddonNS.CategorShowAlways:GetAlwaysShownCategories()
    return categoriesToAlwaysShow -- leaking table, but does it matter?
end
function AddonNS.CategorShowAlways:ShouldAlwaysShow(categoryName)
    return categoriesToAlwaysShow[categoryName];
end

function AddonNS.CategorShowAlways:SetAlwaysShow(categoryName, show)
    categoriesToAlwaysShow[categoryName] = show or nil;
end

local function categoryRenamed(eventName, fromCategoryName, toCategoryName)
    AddonNS.CategorShowAlways:SetAlwaysShow(toCategoryName,  AddonNS.CategorShowAlways:ShouldAlwaysShow(fromCategoryName));
    AddonNS.CategorShowAlways:SetAlwaysShow(fromCategoryName, nil);
end

local function categoryDeleted(eventName, categoryName)
    AddonNS.CategorShowAlways:SetAlwaysShow(categoryName, nil)
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_RENAMED, categoryRenamed)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)