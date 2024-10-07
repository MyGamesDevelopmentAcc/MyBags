local addonName, AddonNS = ...

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;
AddonNS.itemButtonPlaceholder = {}

local container = ContainerFrameCombinedBags;
AddonNS.container = container;
local freeBagSlots = 10000;
local lockedUpdates = false;
function AddonNS.Events:BAG_UPDATE(event, bagID)
    AddonNS.printDebug("BAG_UPDATE", bagID)

    if (container.MyBags.updateItemLayoutCalledAtLeastOnce) then
        local newFreeBagSlots = CalculateTotalNumberOfFreeBagSlots()

        AddonNS.printDebug("FREE BAGS", newFreeBagSlots, freeBagSlots)
        if newFreeBagSlots <= freeBagSlots and not lockedUpdates then
            RunNextFrame(function()
                AddonNS.printDebug("FIRED")
                container:UpdateItemLayout();
            end);
        end
        lockedUpdates = true;
        RunNextFrame(function()
            lockedUpdates = false;
        end);
        freeBagSlots = newFreeBagSlots;
    end
end

function AddonNS.Events:INVENTORY_SEARCH_UPDATE(event, bagID)
    AddonNS.printDebug("INVENTORY_SEARCH_UPDATE", bagID)
    container:UpdateItemLayout();
end

AddonNS.Events:RegisterEvent("INVENTORY_SEARCH_UPDATE");

AddonNS.Events:RegisterEvent("BAG_UPDATE");
function container:GetColumns()
    return AddonNS.Const.NUM_ITEM_COLUMNS
end

local it = container:EnumerateValidItems()

AddonNS.emptyItemButton = nil
local function newIterator(container, index)
    local arrangedItems = container.MyBags.arrangedItems;
    local positionsInBags = container.MyBags.positionsInBags;
    local index, itemButton = it(container, index);
    if (index == 1) then AddonNS.emptyItemButton = nil end -- reset itemButom
    if (itemButton) then
        -- [[ checking hooks]]
        if (not itemButton.myBagAddonHooked) then
            -- TODO: prolly need to remove this hook when not merged bags are used to not destroy by accident proper categorisations?
            -- todo: this should be done once during these creation steps, not here.

            itemButton:SetScript("PreClick", function(...)
                AddonNS.DragAndDrop.itemOnClick(...)
            end);

            local oldOnReceiveDrag = itemButton:GetScript("OnReceiveDrag")
            itemButton:SetScript("OnReceiveDrag",
                function(...)
                    AddonNS.printDebug("overwritten OnReceiveDrag")
                    AddonNS.DragAndDrop.itemOnReceiveDrag(...);
                    oldOnReceiveDrag(...)
                end);
            itemButton:HookScript("OnDragStart", AddonNS.DragAndDrop.itemStartDrag);

            itemButton.myBagAddonHooked = true;
        end


        -- [[ CATEGORISATION ]]
        local info = C_Container.GetContainerItemInfo(itemButton:GetBagID(), itemButton:GetID());
        itemButton.ItemCategory = nil;
        if (info and not info.isFiltered) then
            itemButton.ItemCategory = AddonNS.Categories:Categorize(info.itemID, itemButton);
            arrangedItems[itemButton.ItemCategory] = arrangedItems[itemButton.ItemCategory] or
                {}

            table.insert(arrangedItems[itemButton.ItemCategory], itemButton);
        elseif itemButton:GetBagID() ~= Enum.BagIndex.ReagentBag then
            AddonNS.emptyItemButton = itemButton;
        end
    else --[[ iterator finished so we can now tackle the list and calcualte the positions of items, as we now have all the items]]
        local itemSize = container.Items[1]:GetHeight() + ITEM_SPACING;
        container.MyBags.rows = 0;
        container.MyBags.height = 0;
        container.MyBags.categoryPositions = {};
        local function placeItemsInGrid(categoriesObj, columnStartX)
            local currentRow = {}
            local itemPlaceholder = AddonNS.itemButtonPlaceholder;
            local currentRowWidth = 0
            local currentRowY = 0
            local rowWithNewCategory = false;
            local currentRowNo = 0;
            local function flushCurrentRow()
                local xOffset = 0
                for _, item in ipairs(currentRow) do
                    if item ~= itemPlaceholder then
                        positionsInBags[item:GetBagID()] = positionsInBags[item:GetBagID()] or {};
                        positionsInBags[item:GetBagID()][item:GetID()] = {
                            id = item:GetID(),
                            x = columnStartX + xOffset,
                            y = currentRowY,
                        };
                    end
                    xOffset = xOffset + itemSize
                end
                currentRow = {}
                currentRowWidth = 0
                currentRowY = currentRowY + itemSize
                rowWithNewCategory = false;
                currentRowNo = currentRowNo + 1;
            end

            for i, categoryObj in ipairs(categoriesObj) do
                local categoryItemsCount = #categoryObj.items;
                local isCategoryFolded = categoryObj.category.folded;
                local categoryRequiresNewLine = isCategoryFolded or categoryObj.category.separateLine;
                local requiredNewLine =
                    categoryRequiresNewLine
                    or #currentRow == 0
                    or #currentRow > 0 and
                    (rowWithNewCategory and currentRowWidth + itemSize * (categoryItemsCount) > AddonNS.Const.ITEMS_PER_ROW * itemSize or not rowWithNewCategory)

                if (i == 1) then
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT;
                elseif requiredNewLine then
                    if (#currentRow > 0) then
                        flushCurrentRow();
                    end
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING;
                end
                local nextCategoryExists = categoriesObj[i + 1] and true or false; -- to be explict, for increased readability

                local expandCategoryToRightColumnBoundary =
                    (#currentRow + categoryItemsCount < AddonNS.Const.ITEMS_PER_ROW and
                        (
                            isCategoryFolded
                            or (not nextCategoryExists)
                            or categoriesObj[i + 1].category.folded
                            or categoriesObj[i + 1].category.separateLine
                            or #currentRow + categoryItemsCount + #categoriesObj[i + 1].items > AddonNS.Const.ITEMS_PER_ROW
                        )
                    )
                    and (AddonNS.Const.ITEMS_PER_ROW - #currentRow - categoryItemsCount) or 0
                table.insert(container.MyBags.categoryPositions,
                    {
                        category = categoryObj.category,
                        x = columnStartX + itemSize * #currentRow - ITEM_SPACING / 2,
                        y = currentRowY - AddonNS.Const.CATEGORY_HEIGHT,
                        width = itemSize *
                            (categoryItemsCount > AddonNS.Const.ITEMS_PER_ROW and AddonNS.Const.ITEMS_PER_ROW or categoryItemsCount + expandCategoryToRightColumnBoundary),
                        height = AddonNS.Const.CATEGORY_HEIGHT + ((not isCategoryFolded and
                            math.ceil(categoryItemsCount / AddonNS.Const.ITEMS_PER_ROW) *
                            itemSize) or 0),
                    });
                rowWithNewCategory = true;
                local items = categoryObj.items;
                if (not isCategoryFolded) then
                    for j = #items, 1, -1 do
                        local item = items[j];
                        table.insert(currentRow, item)
                        currentRowWidth = currentRowWidth + itemSize
                        if #currentRow >= AddonNS.Const.ITEMS_PER_ROW then
                            flushCurrentRow()
                        end
                    end
                end
            end

            if #currentRow > 0 then
                flushCurrentRow()
            end
            if (container.MyBags.height <= currentRowY) then
                container.MyBags.height = currentRowY;
                container.MyBags.rows = currentRowNo;
            end
        end

        -- Calculate positions for each column
        local categoryAssignments = {}
        categoryAssignments = AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems) -- todo: this object is quite weird. Why is it a local global used among two functions :/


        local columnSize = itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING;
        for colIndex, categoryObjs in ipairs(categoryAssignments) do
            local columnStartX = (colIndex - 1) * columnSize
            placeItemsInGrid(categoryObjs, columnStartX)
        end
    end
    return index, itemButton;
end

function AddonNS.newEnumerateValidItems(container)
    return newIterator, container, 0;
end
