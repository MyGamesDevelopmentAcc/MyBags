local addonName, AddonNS = ...

AddonNS.Categories = {};

local categoriesColumnAssignments = { {}, {}, {} };
function AddonNS.Categories:OnInitialize()
    AddonNS.db.categoriesColumnAssignments = AddonNS.db.categoriesColumnAssignments or categoriesColumnAssignments;
    categoriesColumnAssignments = AddonNS.db.categoriesColumnAssignments;
end

AddonNS.Events:OnInitialize(AddonNS.Categories.OnInitialize)

local UNASSIGNED_CATEGORY = { name = nil, protected = false };
local categorizers = OrderedMap:new()
local categories = {};
function AddonNS.Categories:RegisterCategorizer(name, categorizer, protected)
    categorizers:set(name, { categorizer = categorizer, protected = protected });
end

function AddonNS.Categories:Categorize(itemID, itemButton)
    local categoryName;
    local protected = false;
    for _, categorizerDef in categorizers:iterate() do
        categoryName = categorizerDef.categorizer:Categorize(itemID, itemButton);
        if categoryName then
            protected = categorizerDef.protected;
            break;
        end;
    end
    if not categoryName then return UNASSIGNED_CATEGORY end

    if not categories[categoryName] then
        categories[categoryName] = { name = categoryName, protected = protected };
    elseif protected then
        categories[categoryName].protected = protected;
    end
    return categories[categoryName];
end

local UNASSIGNE_CATEGORY_DB_STORAGE_NAME = "UNASSIGNED_CATEGORY_DB_STORAGE_NAME";
function AddonNS.Categories:GetCategoryByName(categoryName)
    if categoryName == UNASSIGNE_CATEGORY_DB_STORAGE_NAME then return UNASSIGNED_CATEGORY end;
    return categories[categoryName]
end

local function getCategorySafeNameForStorage(category)
    return category.name or UNASSIGNE_CATEGORY_DB_STORAGE_NAME;
end
local function getBagSize(arrangedItems)
    local sum = 0;
    for _, obj in pairs(arrangedItems) do
        sum = sum + obj.itemsCount;
    end
    return sum;
end
function AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems)
    local categoryAssignments = { {}, {}, {} };
    local columnSum = { 0, 0, 0 };
    local knownCategories = {};
    local MAX_ITEMS_PER_COLUMN = AddonNS.MAX_ITEMS_PER_COLUMN
    -- Helper function to add category to a column, splitting if necessary
    local function addCategoryToColumn(category, items, column)
        local firstColumn = nil;
        AddonNS.printDebug(category)
        AddonNS.printDebug(category.name)
        AddonNS.printDebug(#items)
        while #items > 0 do
            AddonNS.printDebug("rozklada",#items)
            local itemsBatch = {}
            if columnSum[column] + #items > MAX_ITEMS_PER_COLUMN then
                local itemsToFit = MAX_ITEMS_PER_COLUMN - columnSum[column]
                AddonNS.printDebug("to fit;",itemsToFit)
                itemsBatch = items;
                items = {};
                local o = 1;
                for i = itemsToFit + 1, #itemsBatch do
                    items[o] = itemsBatch[i];
                    itemsBatch[i] = nil;
                    o = o +1;
                end
                AddonNS.printDebug("o;",o);
            else
                itemsBatch = items;
                items = {};
            end
            columnSum[column] = columnSum[column] + #itemsBatch
            AddonNS.printDebug("dolozy",#itemsBatch, column)
            if (#itemsBatch > 0) then
                table.insert(categoryAssignments[column], { category = category, items = itemsBatch });
                firstColumn = firstColumn or column
            end

            if #items > 0 then
                column = column + 1
                if column > AddonNS.NUM_COLUMNS then
                    column = 1 -- Reset to the first column if we exceed the number of columns
                end
            end
        end
        return firstColumn
    end



    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        for _, categoryName in ipairs(categoriesNames) do
            local tempCat = AddonNS.Categories:GetCategoryByName(categoryName)
            if (tempCat and arrangedItems[tempCat]) then
                addCategoryToColumn(tempCat, arrangedItems[tempCat].items, colIndex);
                knownCategories[tempCat] = true;
            end
        end
    end


    local predictedItemsPerColumn = getBagSize(arrangedItems) / AddonNS.NUM_COLUMNS * 1.1; -- 1.1 modifier to make sure initial columns get more items
    local column = 1;
    AddonNS.printDebug(arrangedItems)
    for category, obj in pairs(arrangedItems) do
        if not knownCategories[category] then
            while (columnSum[column] > predictedItemsPerColumn and column <= AddonNS.NUM_COLUMNS) do
                column = column + 1;
            end
            
            local firstAssignedColumn = addCategoryToColumn(category, arrangedItems[category].items, column);
            table.insert(categoriesColumnAssignments[firstAssignedColumn], getCategorySafeNameForStorage(category));
        end
    end
    -- for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
    --     for _, categoryName in ipairs(categoriesNames) do
    --         local tempCat = AddonNS.Categories:GetCategoryByName(categoryName)
    --         if (tempCat and arrangedItems[tempCat]) then
    --             -- addCategoryToColumn(categoryAssignments[], tempCat);
    --             table.insert(categoryAssignments[colIndex], tempCat);
    --             knownCategories[tempCat] = true;
    --             columnSum[colIndex] = columnSum[colIndex] + arrangedItems[tempCat].itemsCount;
    --         end
    --     end
    -- end


    -- local predictedItemsPerColumn = getBagSize(arrangedItems) / AddonNS.NUM_COLUMNS;
    -- local column = 1;
    -- AddonNS.printDebug(arrangedItems)
    -- for category, obj in pairs(arrangedItems) do
    --     if not knownCategories[category] then
    --         while (columnSum[column] > predictedItemsPerColumn and column <= AddonNS.NUM_COLUMNS) do
    --             column = column + 1;
    --         end
    --         table.insert(categoryAssignments[column], category);
    --         table.insert(categoriesColumnAssignments[column], getCategorySafeNameForStorage(category));

    --         columnSum[column] = columnSum[column] + obj.itemsCount;
    --     end
    -- end
    return categoryAssignments;
end

local function categoryMoved(eventName, pickedCategory, targetCategory)
    local pickedCategoryName = getCategorySafeNameForStorage(pickedCategory);
    local targetCategoryName = getCategorySafeNameForStorage(targetCategory);
    if (pickedCategoryName == targetCategoryName) then
        return
    end
    AddonNS.printDebug("received category mved event", pickedCategoryName, targetCategory.name)
    local pickedCategoryPosition = {}
    local targetCategoryPostion = {}
    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            AddonNS.printDebug(" ", categoriesNames[i]);
            if categoriesNames[i] == pickedCategoryName then
                pickedCategoryPosition = { col = colIndex, row = i }
                AddonNS.printDebug("removing", i, categoriesNames[i])
                table.remove(categoriesNames, i)
                AddonNS.printDebug("after", i, categoriesNames[i])
                if categoriesNames[i] == targetCategoryName then
                    targetCategoryPostion = { col = colIndex, row = i }
                end
            else
                if categoriesNames[i] == targetCategoryName then
                    AddonNS.printDebug("found target", i, categoriesNames[i])
                    targetCategoryPostion = { col = colIndex, row = i }
                end
                i = i + 1
            end
        end
    end
    AddonNS.printDebug(pickedCategoryPosition.col, targetCategoryPostion.col, pickedCategoryPosition.row,
        targetCategoryPostion.row)
    local placeAbove =
        (
            pickedCategoryPosition.col ~= targetCategoryPostion.col or
            pickedCategoryPosition.col == targetCategoryPostion.col and pickedCategoryPosition.row > targetCategoryPostion.row) and
        0 or 1;
    table.insert(categoriesColumnAssignments[targetCategoryPostion.col], targetCategoryPostion.row + placeAbove,
        pickedCategoryName)
end


local function categoryMovedToColumn(eventName, pickedCategory, column)
    local pickedCategoryName = getCategorySafeNameForStorage(pickedCategory);
    AddonNS.printDebug("received category mved event to clumn", pickedCategoryName, column)

    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            AddonNS.printDebug(" ", categoriesNames[i]);
            if categoriesNames[i] == pickedCategoryName then
                AddonNS.printDebug("moving", colIndex, column)
                table.remove(categoriesNames, i)
                table.insert(categoriesColumnAssignments[column], pickedCategoryName)
                return;
            end
            i = i + 1
        end
    end
end

local function categoryRenamed(eventName, fromCategoryName, toCategoryName)
    if (fromCategoryName == toCategoryName) then
        return
    end
    AddonNS.printDebug("received category mved event", fromCategoryName, toCategoryName)
    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            AddonNS.printDebug(" ", categoriesNames[i]);
            if categoriesNames[i] == fromCategoryName then
                categoriesNames[i] = toCategoryName;
                if categories[fromCategoryName] then
                    if (not categories[toCategoryName]) then
                        categories[toCategoryName] = categories[fromCategoryName];
                        categories[fromCategoryName].name = toCategoryName;
                    end
                    categories[fromCategoryName] = nil;
                end
                return;
            end
            i = i + 1
        end
    end
end

local function categoryDeleted(eventName, categoryName)
    for colIndex, categoriesNames in ipairs(categoriesColumnAssignments) do
        local i = 1
        while i <= #categoriesNames do
            AddonNS.printDebug(" ", categoriesNames[i]);
            if categoriesNames[i] == categoryName then
                table.remove(categoriesNames, i);
                categories[categoryName] = nil;
                return;
            end
            i = i + 1
        end
    end
end


AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CATEGORY_MOVED, categoryMoved)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CATEGORY_MOVED_TO_COLUMN, categoryMovedToColumn)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_RENAMED, categoryRenamed)
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)
