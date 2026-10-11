local addonName, AddonNS = ...

-- events
AddonNS.ItemsOrder = {};

local items_current_order = {};
function AddonNS.ItemsOrder:OnInitialize()
    AddonNS.db.itemOrder = AddonNS.db.itemOrder or items_current_order;
    items_current_order = AddonNS.db.itemOrder;
end

AddonNS.Events:OnInitialize(AddonNS.ItemsOrder.OnInitialize)


-- The first list (items to be sorted)
local order_map = {}
local order_map_changed = true;
local function getItemIdOrError(itemButton)
    local itemID = itemButton and itemButton._myBagsItemId
    if not itemID then
        error("ItemsOrder:Sort missing cached item id on item button")
    end
    return itemID
end

local function recreateAnOrderMapIfNeeded()
    if order_map_changed then
        order_map = {};
        for index, id in ipairs(items_current_order) do
            order_map[id] = index
        end
        order_map_changed = false;
    end
end

function AddonNS.ItemsOrder:Sort(itemButtonsList)
    -- Create a map for quick lookup of the order positions
    if (itemButtonsList[1] == AddonNS.itemButtonPlaceholder) then return; end;

    recreateAnOrderMapIfNeeded()
    local itemToItemIDMap = {};

    for i = #itemButtonsList, 1, -1 do
        local itemButton = itemButtonsList[i]
        local itemID = getItemIdOrError(itemButton)
        itemToItemIDMap[itemButton] = itemID
    end

    -- Fast path for tiny lists to avoid table.sort overhead.
    if #itemButtonsList == 2 then
        local itemButtonA = itemButtonsList[1]
        local itemButtonB = itemButtonsList[2]
        local itemA_ID = itemToItemIDMap[itemButtonA]
        local itemB_ID = itemToItemIDMap[itemButtonB]
        local posA = order_map[itemA_ID]
        local posB = order_map[itemB_ID]
        local inOrder

        if posA and posB then
            inOrder = posA < posB
        elseif posA then
            inOrder = true
        elseif posB then
            inOrder = false
        else
            inOrder = itemA_ID < itemB_ID
        end

        if not inOrder then
            itemButtonsList[1], itemButtonsList[2] = itemButtonsList[2], itemButtonsList[1]
        end
    else
        table.sort(itemButtonsList, function(itemButtonA, itemButtonB)
            local itemA_ID = itemToItemIDMap[itemButtonA];
            local itemB_ID = itemToItemIDMap[itemButtonB];
            local posA = order_map[itemA_ID]
            local posB = order_map[itemB_ID]
            if posA and posB then
                return posA < posB
            end
            if posA then
                return true
            end
            if posB then
                return false
            end
            return itemA_ID < itemB_ID
        end)
    end

    local last_index = 0
    local orderChanged = false
    for i = #itemButtonsList, 1, -1 do
        local id = itemToItemIDMap[itemButtonsList[i]]
        if order_map[id] then
            last_index = order_map[id]
            break
        end
    end

    for _, item in ipairs(itemButtonsList) do
        if not order_map[itemToItemIDMap[item]] then
            table.insert(items_current_order, last_index + 1, itemToItemIDMap[item])
            last_index = last_index + 1
            orderChanged = true
        end
    end
    if orderChanged then
        order_map_changed = true
    end
end

function AddonNS.ItemsOrder:Move(itemID, targetedItemID, targetCategory, insertionSide)
    assert(insertionSide == "before" or insertionSide == "after" or insertionSide == "end",
        "ItemsOrder:Move requires a visual insertion side")
    if targetCategory:IsProtected() then
        return
    end
    if itemID == targetedItemID then
        return
    end
    recreateAnOrderMapIfNeeded()
    local pickedIndex = order_map[itemID]
    local insertIndex
    if insertionSide == "end" then
        assert(targetedItemID == nil, "End insertion must target a category")
        -- The visible layout reverses this global sequence, so index one is
        -- the visual end of every category, including the source category.
        insertIndex = 1
    else
        assert(targetedItemID, "Item insertion requires a target item ID")
        local targetIndex = assert(order_map[targetedItemID], "Target item missing from order map")
        if pickedIndex and pickedIndex < targetIndex then
            targetIndex = targetIndex - 1
        end
        insertIndex = insertionSide == "before" and targetIndex + 1 or targetIndex
    end
    if pickedIndex then
        table.remove(items_current_order, pickedIndex)
    end
    table.insert(items_current_order, insertIndex, itemID)
    order_map_changed = true
end

local function itemMoved(eventName, itemID, targetedItemID, sourceCategory, targetCategory,
                         sourceButton, targetButton, insertionSide)
    AddonNS.ItemsOrder:Move(itemID, targetedItemID, targetCategory, insertionSide)
end
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.ITEM_MOVED, itemMoved)
