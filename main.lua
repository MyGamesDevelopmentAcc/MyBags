local addonName, AddonNS = ...

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;
AddonNS.itemButtonPlaceholder = {}



local categoryAssignments = {
}

local categorizeItems = true;
local arrangedItems = {}
local positionsInBags = {}; -- should we clean this also?
local categoryPositions = {};

local function extend(f, f2)
    return function(...)
        return f2(f, ...);
    end
end
local UpdateItemLayoutCalledAtLeastOnce = false


local function UpdateItemLayout(f, ...)
    AddonNS.printDebug("UpdateItemLayout")
    UpdateItemLayoutCalledAtLeastOnce = true;
    categorizeItems = true;
    return f(...);
end


local container = ContainerFrameCombinedBags;
AddonNS.container = container;
local freeBagSlots = 10000;
local lockedUpdates = false;
function AddonNS.Events:BAG_UPDATE(event, bagID)
    AddonNS.printDebug("BAG_UPDATE", bagID)

    if (UpdateItemLayoutCalledAtLeastOnce) then
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

AddonNS.Events:RegisterEvent("BAG_UPDATE");
function container:GetColumns()
    return 12
end

container.UpdateItemLayout = extend(container.UpdateItemLayout, UpdateItemLayout);


local it = container:EnumerateValidItems()

local rows = 0;
local height = 0;


AddonNS.emptyItemButton = nil
local function newIterator(container, index)
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
        if (info) then
            itemButton.ItemCategory = AddonNS.Categories:Categorize(info.itemID, itemButton);
            arrangedItems[itemButton.ItemCategory] = arrangedItems[itemButton.ItemCategory] or
                {}

            table.insert(arrangedItems[itemButton.ItemCategory], itemButton);
        elseif itemButton:GetBagID() ~= Enum.BagIndex.ReagentBag then
            AddonNS.emptyItemButton = itemButton;
        end
    else --[[ iterator finished so we can now tackle the list and calcualte the positions of items, as we now have all the items]]
        local itemSize = container.Items[1]:GetHeight() + ITEM_SPACING;
        rows = 0;
        height = 0;
        categoryPositions = {};
        local function placeItemsInGrid(categoriesObj, columnStartX)
            local currentRow = {}
            local itemPlaceholder = AddonNS.itemButtonPlaceholder;
            local currentRowWidth = 0
            local currentRowY = 0
            --local rowSubcolumn =0
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
                if (#currentRow == 0) then
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT;
                elseif #currentRow > 0 and (rowWithNewCategory and currentRowWidth + itemSize * (categoryItemsCount) > AddonNS.Const.ITEMS_PER_ROW * itemSize or not rowWithNewCategory) then
                    flushCurrentRow();
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING;
                end
                local expandCategoryToRightColumnBoundary = (#currentRow + categoryItemsCount < AddonNS.Const.ITEMS_PER_ROW and
                        #currentRow + categoryItemsCount + (categoriesObj[i + 1] and #categoriesObj[i + 1].items or AddonNS.Const.ITEMS_PER_ROW) > AddonNS.Const.ITEMS_PER_ROW) and
                    (AddonNS.Const.ITEMS_PER_ROW - #currentRow - categoryItemsCount) or 0
                table.insert(categoryPositions,
                    {
                        category = categoryObj.category,
                        x = columnStartX + itemSize * #currentRow - ITEM_SPACING / 2,
                        y = currentRowY - AddonNS.Const.CATEGORY_HEIGHT, --- ITEM_SPACING / 2
                        width = itemSize *
                            (categoryItemsCount > AddonNS.Const.ITEMS_PER_ROW and AddonNS.Const.ITEMS_PER_ROW or categoryItemsCount + expandCategoryToRightColumnBoundary),
                        height = AddonNS.Const.CATEGORY_HEIGHT + math.ceil(categoryItemsCount / AddonNS.Const.ITEMS_PER_ROW) *
                            itemSize,
                    });
                rowWithNewCategory = true;
                local items = categoryObj.items;
                for j = #items, 1, -1 do
                    local item = items[j];
                    if #currentRow >= AddonNS.Const.ITEMS_PER_ROW then
                        flushCurrentRow()
                    end
                    table.insert(currentRow, item)
                    currentRowWidth = currentRowWidth + itemSize
                end
            end

            if #currentRow > 0 then
                flushCurrentRow()
            end
            if (height <= currentRowY) then
                height = currentRowY;
                rows = currentRowNo;
            end
        end

        -- Calculate positions for each column
        categoryAssignments = AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems) -- todo: this object is quite weird. Why is it a local global used among two functions :/


        local columnSize = itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING;
        for colIndex, categoryObjs in ipairs(categoryAssignments) do
            local columnStartX = (colIndex - 1) * columnSize
            placeItemsInGrid(categoryObjs, columnStartX)
        end
    end
    return index, itemButton;
end

local function newEnumerateValidItems(container)
    return newIterator, container, 0;
end

container.EnumerateValidItems = extend(container.EnumerateValidItems,
    function(f, ...)
        if categorizeItems then
            AddonNS.printDebug("EnumerateValidItems override used")
            categorizeItems = false;
            arrangedItems = {}
            return newEnumerateValidItems(...);
        end
        return f(...);
    end);

local function calculateHeightForCategoriesTitles()
    return height - rows * (container.Items[1]:GetHeight() + ITEM_SPACING);
end
container.CalculateExtraHeight = extend(container.CalculateExtraHeight,
    function(f, ...)
        return calculateHeightForCategoriesTitles() + f(...);
    end
)

container.SetScale = extend(container.SetScale, function(f, container, scale)
    scale = scale > 0.75 and 0.75 or scale;
    return f(container, scale);
end);

container.CalculateWidth = extend(container.CalculateWidth,
    function(f, ...)
        return f(...) + 2 * AddonNS.Const.COLUMN_SPACING - container:GetColumns() * (AddonNS.Const.ORIGINAL_SPACING - ITEM_SPACING);
    end
)

container.GetInitialItemAnchor = extend(container.GetInitialItemAnchor,
    function(f, ...)
        AddonNS.printDebug("called anchor again?");
        local anchor = f(...);
        function container:GetRows()
            return rows;
        end

        container:UpdateFrameSize();

        local yFrameOffset = container:CalculateHeight() - container:GetPaddingHeight() -
            container:CalculateExtraHeight() + ITEM_SPACING + calculateHeightForCategoriesTitles();
        local point, relativeTo, relativePoint, x, y = anchor:Get();
        anchor:Set("TOPLEFT", relativeTo, "TOPLEFT", 0, 0);
        AddonNS.printDebug("Anchor", x, y)

        anchor.SetPointWithExtraOffset = extend(anchor.SetPointWithExtraOffset,
            function(f, self, possibleItem, clearAllPoints, extraOffsetX, extraOffsetY)
                if (possibleItem.ItemCategory) then
                    local newXOffset = positionsInBags[possibleItem:GetBagID()][possibleItem:GetID()].x;
                    local newYOffset = -positionsInBags[possibleItem:GetBagID()][possibleItem:GetID()].y + yFrameOffset;
                    possibleItem:Show();
                    return f(self, possibleItem, clearAllPoints, newXOffset, newYOffset);
                end
                possibleItem:Hide();
                return f(self, possibleItem, clearAllPoints, extraOffsetX, extraOffsetY);
            end);
        AddonNS.gui:RegenerateCategories(yFrameOffset, categoryPositions);

        return anchor;
    end);





container.UpdateItemSlots = extend(container.UpdateItemSlots,
    function(f, ...)
        AddonNS.printDebug("UpdateItemSlots")
        f(...);

        local bagSize = ContainerFrame_GetContainerNumSlots(Enum.BagIndex.ReagentBag);
        for i = 1, bagSize do
            local itemButton = container:AcquireNewItemButton();
            local slotID = bagSize - i + 1;
            itemButton:Initialize(Enum.BagIndex.ReagentBag, slotID);
        end
    end);

-- need to overwrite this as it is used during enumeration of items in the bags so otherwise it would not incorporate reagentsContainer
function container:SetBagSize()
    self.size = 0;
    for i = 0, Enum.BagIndex.ReagentBag, 1 do
        self.size = container.size + ContainerFrame_GetContainerNumSlots(i);
    end
end

function container:MatchesBagID(id)-- override to include reagent bags
    return id >= Enum.BagIndex.Backpack and id <= Enum.BagIndex.ReagentBag;
end