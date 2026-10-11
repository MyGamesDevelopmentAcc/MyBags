local addonName, AddonNS = ...

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING
local CATEGORY_HEIGHT = AddonNS.Const.CATEGORY_HEIGHT
local ITEMS_PER_ROW = AddonNS.Const.ITEMS_PER_ROW

AddonNS.CategoryLayout = {}

-- itemSize includes item spacing. Return frame-independent positions; each
-- view applies its own anchors and uses blockHeight for the category body.
function AddonNS.CategoryLayout:Calculate(categoryAssignments, scope, itemSize, leftPadding, firstRowY, emptyColumnControlSpacing)
    local categoryPositions = {}
    local positions = {}
    local columnsBottom = {}
    local rowsByColumn = {}
    local columnPixelWidth = itemSize * ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
    local isCategoriesConfigMode = AddonNS.BagViewState:IsCategoriesConfigMode()

    local function placeColumn(columnIndex, categories)
        local columnStartX = leftPadding + (columnIndex - 1) * columnPixelWidth
        local currentRow = {}
        local currentRowY = firstRowY
        local rowWithNewCategory = false
        local rowCount = 0

        local function flushCurrentRow()
            local xOffset = 0
            for rowIndex = 1, #currentRow do
                local itemButton = currentRow[rowIndex]
                if itemButton ~= AddonNS.itemButtonPlaceholder then
                    positions[itemButton] = {
                        x = columnStartX + xOffset,
                        y = currentRowY,
                    }
                end
                xOffset = xOffset + itemSize
            end
            currentRow = {}
            currentRowY = currentRowY + itemSize
            rowCount = rowCount + 1
            rowWithNewCategory = false
        end

        for index, categoryObj in ipairs(categories) do
            local category = categoryObj.category
            local items = categoryObj.items
            local itemsCount = categoryObj.itemsCount or #items
            local collapsed = AddonNS.Collapsed.isCollapsed(category, scope)
            local isHeaderOnly = collapsed or itemsCount == 0
            local categoryRequiresNewLine = isCategoriesConfigMode or isHeaderOnly or category.separateLine
            local categoryRequiresFullRowWidth = isCategoriesConfigMode or isHeaderOnly
            local requiredNewLine =
                categoryRequiresNewLine
                or #currentRow == 0
                or (#currentRow > 0 and ((rowWithNewCategory and #currentRow + itemsCount > ITEMS_PER_ROW) or not rowWithNewCategory))

            if index == 1 then
                currentRowY = currentRowY + CATEGORY_HEIGHT
            elseif requiredNewLine then
                if #currentRow > 0 then
                    flushCurrentRow()
                end
                currentRowY = currentRowY + CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING
            end

            local nextCategoryObj = categories[index + 1]
            local nextCategoryExists = nextCategoryObj ~= nil
            local expandCategoryToRightColumnBoundary = 0
            if not categoryRequiresFullRowWidth and #currentRow + itemsCount < ITEMS_PER_ROW then
                local nextCategoryItemsCount = 0
                if nextCategoryExists then
                    nextCategoryItemsCount = nextCategoryObj.itemsCount or #(nextCategoryObj.items)
                end
                local shouldExpandToBoundary =
                    (not nextCategoryExists)
                    or AddonNS.Collapsed.isCollapsed(nextCategoryObj.category, scope)
                    or nextCategoryItemsCount == 0
                    or nextCategoryObj.category.separateLine
                    or #currentRow + itemsCount + nextCategoryItemsCount > ITEMS_PER_ROW
                if shouldExpandToBoundary then
                    expandCategoryToRightColumnBoundary = ITEMS_PER_ROW - #currentRow - itemsCount
                end
            end

            local categoryWidthSlots = ITEMS_PER_ROW
            if not categoryRequiresFullRowWidth then
                categoryWidthSlots = math.min(ITEMS_PER_ROW, itemsCount + expandCategoryToRightColumnBoundary)
            end
            table.insert(categoryPositions, {
                category = category,
                itemsCount = itemsCount,
                x = columnStartX + itemSize * #currentRow - ITEM_SPACING / 2,
                y = currentRowY - CATEGORY_HEIGHT,
                width = itemSize * categoryWidthSlots,
                height = CATEGORY_HEIGHT,
                blockHeight = CATEGORY_HEIGHT +
                    ((not isHeaderOnly and math.ceil(itemsCount / ITEMS_PER_ROW) * itemSize) or 0),
                scope = scope,
            })

            rowWithNewCategory = true
            if not isHeaderOnly then
                for itemIndex = #items, 1, -1 do
                    local itemButton = items[itemIndex]
                    table.insert(currentRow, itemButton)
                    if #currentRow >= ITEMS_PER_ROW then
                        flushCurrentRow()
                    end
                end
            end
        end

        if #currentRow > 0 then
            flushCurrentRow()
        end

        columnsBottom[columnIndex] = currentRowY
        rowsByColumn[columnIndex] = rowCount
    end

    for columnIndex, categories in ipairs(categoryAssignments) do
        placeColumn(columnIndex, categories)
    end

    local contentBottom = firstRowY
    local rows = 0
    for index = 1, #columnsBottom do
        if columnsBottom[index] >= contentBottom then
            contentBottom = columnsBottom[index]
            rows = rowsByColumn[index]
        end
    end

    if isCategoriesConfigMode then
        local lastColumnIndex = math.max(1, #categoryAssignments)
        local columnBottomY = columnsBottom[lastColumnIndex] or firstRowY
        local controlGap = columnBottomY > firstRowY and AddonNS.Const.COLUMN_SPACING or emptyColumnControlSpacing
        local addControlY = columnBottomY + controlGap
        local controlHeight = AddonNS.Const.CATEGORY_HEIGHT
        local controlSpacing = AddonNS.Const.COLUMN_SPACING
        local controlX = leftPadding + (lastColumnIndex - 1) * columnPixelWidth - ITEM_SPACING / 2
        local controlWidth = itemSize * ITEMS_PER_ROW

        table.insert(categoryPositions, {
            isAddCategoryControl = true,
            scope = scope,
            x = controlX,
            y = addControlY,
            width = controlWidth,
            height = controlHeight,
            blockHeight = controlHeight,
        })
        table.insert(categoryPositions, {
            isExportCategoryControl = true,
            scope = scope,
            x = controlX,
            y = addControlY + controlHeight + controlSpacing,
            width = controlWidth,
            height = controlHeight,
            blockHeight = controlHeight,
        })
        table.insert(categoryPositions, {
            isImportCategoryControl = true,
            scope = scope,
            x = controlX,
            y = addControlY + (controlHeight + controlSpacing) * 2,
            width = controlWidth,
            height = controlHeight,
            blockHeight = controlHeight,
        })

        local addControlBottomY = addControlY + (controlHeight + controlSpacing) * 2 + controlHeight
        if addControlBottomY > contentBottom then
            contentBottom = addControlBottomY
        end
    end

    return positions, categoryPositions, contentBottom, rows
end

