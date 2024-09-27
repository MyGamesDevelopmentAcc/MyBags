local addonName, AddonNS = ...

local MAX_ITEMS_PER_COLUMN = AddonNS.Const.MAX_ITEMS_PER_COLUMN
local NUM_COLUMNS = AddonNS.Const.NUM_COLUMNS;
local UNASSIGNE_CATEGORY_DB_STORAGE_NAME=AddonNS.Const.UNASSIGNE_CATEGORY_DB_STORAGE_NAME

local categoriesColumnAssignments = {};
for i=1,  AddonNS.Const.NUM_COLUMNS do
    table.insert(categoriesColumnAssignments, {});
end

local categoryAssignments;

function AddonNS.Categories:OnInitialize()
    AddonNS.db.categoriesColumnAssignments = AddonNS.db.categoriesColumnAssignments or categoriesColumnAssignments;
    categoriesColumnAssignments = AddonNS.db.categoriesColumnAssignments;
end
AddonNS.Events:OnInitialize(AddonNS.Categories.OnInitialize)

local function getBagSize(arrangedItems)
    local sum = 0;
    for _, items in pairs(arrangedItems) do
        sum = sum + #items;
    end
    return sum;
end
local function getCategorySafeNameForStorage(category)
    return category.name or UNASSIGNE_CATEGORY_DB_STORAGE_NAME;
end
function AddonNS.Categories:GetLastCategoryInColumn(columnNo)
    return categoryAssignments[columnNo][#categoryAssignments[columnNo]].category;
end
function AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems)
    for i, constantCategory in ipairs(AddonNS.Categories:GetConstantCategories()) do
        if not arrangedItems[constantCategory] then
            arrangedItems[constantCategory] = { AddonNS.itemButtonPlaceholder }
        end
    end
    categoryAssignments = { {}, {}, {} };
    local columnSum = { 0, 0, 0 };
    local knownCategories = {};
    -- Helper function to add category to a column, splitting if necessary
    local function addCategoryToColumn(category, items, column)
        local firstColumn = nil;
        items = not category.folded and items or {AddonNS.itemButtonPlaceholder}; -- clear items to be placed if the category is to be folded so they would not leak onto other columns
        AddonNS.ItemsOrder:Sort(items);
        if (#items == 0) then
            firstColumn = column;
            table.insert(categoryAssignments[column], { category = category, items = items });
            -- categoryAssignments[column], { category = category, items = itemsBatch })
        else
            while #items > 0 do
                local itemsBatch = {}
                if columnSum[column] + #items > MAX_ITEMS_PER_COLUMN then
                    local itemsToFit = MAX_ITEMS_PER_COLUMN - columnSum[column]
                    itemsBatch = items;
                    items = {};
                    local o = 1;
                    for i = itemsToFit + 1, #itemsBatch do
                        items[o] = itemsBatch[i];
                        itemsBatch[i] = nil;
                        o = o + 1;
                    end
                else
                    itemsBatch = items;
                    items = {};
                end
                columnSum[column] = columnSum[column] + #itemsBatch
                if (#itemsBatch > 0) then
                    table.insert(categoryAssignments[column], { category = category, items = itemsBatch });
                    firstColumn = firstColumn or column
                end

                if #items > 0 then
                    column = column + 1
                    if column > NUM_COLUMNS then
                        column = 1 -- Reset to the first column if we exceed the number of columns
                    end
                end
            end
        end
        return firstColumn
    end



    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        for _, categoryName in ipairs(categoriesNames) do
            local tempCat = AddonNS.Categories:GetCategoryByName(categoryName)
            if (arrangedItems[tempCat]) then
                addCategoryToColumn(tempCat, arrangedItems[tempCat], colIndex);
                knownCategories[tempCat] = true;
            end
        end
    end


    local predictedItemsPerColumn = getBagSize(arrangedItems) / NUM_COLUMNS * 1.1; -- 1.1 modifier to make sure initial columns get more items
    local column = 1;

    local categoriesToAssign = {};
    for category, items in pairs(arrangedItems) do
        if not knownCategories[category] then
            table.insert(categoriesToAssign, category);
        end
    end
    table.sort(categoriesToAssign, function(a, b)
        if a.name == nil then
            return false           -- Treat nil as greater than any other value
        elseif b.name == nil then
            return true            -- Treat any value as less than nil
        else
            return a.name < b.name -- Regular comparison for non-nil values
        end
    end)

    for index, category in ipairs(categoriesToAssign) do
        while (columnSum[column] > predictedItemsPerColumn and column <= NUM_COLUMNS) do
            column = column + 1;
        end
        local firstAssignedColumn = addCategoryToColumn(category, arrangedItems[category], column);
        table.insert(categoriesColumnAssignments[firstAssignedColumn], getCategorySafeNameForStorage(category));
    end
    return categoryAssignments;
end



local function categoryMoved(eventName, pickedCategory, targetCategory)
    AddonNS.printDebug(eventName)
    local pickedCategoryName = getCategorySafeNameForStorage(pickedCategory);
    local targetCategoryName = getCategorySafeNameForStorage(targetCategory);
    if (pickedCategoryName == targetCategoryName) then
        return
    end
    AddonNS.printDebug("received categoryMoved event", pickedCategoryName, targetCategory.name)
    local pickedCategoryPosition = {}
    local targetCategoryPostion = {}
    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            if categoriesNames[i] == pickedCategoryName then
                pickedCategoryPosition = { col = colIndex, row = i }
                table.remove(categoriesNames, i)
                if categoriesNames[i] == targetCategoryName then
                    targetCategoryPostion = { col = colIndex, row = i }
                end
            else
                if categoriesNames[i] == targetCategoryName then
                    targetCategoryPostion = { col = colIndex, row = i }
                end
                i = i + 1
            end
        end
    end
    local placeAbove =
        (
            pickedCategoryPosition.col ~= targetCategoryPostion.col or
            pickedCategoryPosition.col == targetCategoryPostion.col and pickedCategoryPosition.row > targetCategoryPostion.row) and
        0 or 1;
    table.insert(categoriesColumnAssignments[targetCategoryPostion.col], targetCategoryPostion.row + placeAbove,
        pickedCategoryName)
end



local function categoryMovedToColumn(eventName, pickedCategory, column)
    AddonNS.printDebug(eventName)
    local pickedCategoryName = getCategorySafeNameForStorage(pickedCategory);
    AddonNS.printDebug("received categoryMovedToColumn", pickedCategoryName, column)

    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            if categoriesNames[i] == pickedCategoryName then
                table.remove(categoriesNames, i)
                table.insert(categoriesColumnAssignments[column], pickedCategoryName)
                return;
            end
            i = i + 1
        end
    end
end

local function categoryRenamed(eventName, fromCategoryName, toCategoryName)
    AddonNS.printDebug(eventName)
    if (fromCategoryName == toCategoryName) then
        return
    end
    AddonNS.printDebug("received categoryRenamed event", fromCategoryName, toCategoryName)
    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            AddonNS.printDebug(" ", categoriesNames[i]);
            if categoriesNames[i] == fromCategoryName then
                categoriesNames[i] = toCategoryName;
                return;
            end
            i = i + 1
        end
    end
end

local function categoryDeleted(eventName, categoryName)
    AddonNS.printDebug(eventName)
    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            AddonNS.printDebug(" ", categoriesNames[i]);
            if categoriesNames[i] == categoryName then
                table.remove(categoriesNames, i);
                return;
            end
            i = i + 1
        end
    end
end


AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CATEGORY_MOVED, categoryMoved)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CATEGORY_MOVED_TO_COLUMN, categoryMovedToColumn)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_RENAMED, categoryRenamed)
