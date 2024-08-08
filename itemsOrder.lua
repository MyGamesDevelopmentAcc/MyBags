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
        itemToItemIDMap[itemButtonsList[i]] = C_Container.GetContainerItemInfo(itemButtonsList[i]:GetBagID(),
            itemButtonsList[i]:GetID()).itemID;
    end

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

    local last_index = 0
    for i = #itemButtonsList, 1, -1 do
        AddonNS.printDebug("scanning", i, itemToItemIDMap[itemButtonsList[i]]);
        local id = itemToItemIDMap[itemButtonsList[i]]
        if order_map[id] then
            last_index = order_map[id]
            order_map_changed = true;
            break
        end
    end
    if last_index == 0 then
        order_map_changed = true;
    end

    for _, item in ipairs(itemButtonsList) do
        AddonNS.printDebug(item, itemToItemIDMap[item], order_map[itemToItemIDMap[item]]);
        if not order_map[itemToItemIDMap[item]] then
            --AddonNS.printDebug("adding");
            table.insert(items_current_order, last_index + 1, itemToItemIDMap[item])
            last_index = last_index + 1
        end
    end
end

local function ItemsMoved(previousItemID, pickedItemID, changedCategory)
    if not previousItemID then return end;
    AddonNS.printDebug(previousItemID, pickedItemID, changedCategory)
    recreateAnOrderMapIfNeeded();
    local prevNo = order_map[previousItemID];
    local pickedNo = order_map[pickedItemID];

    AddonNS.printDebug(prevNo, pickedNo)
    if not prevNo or not pickedNo then
        AddonNS.printDebug("ERROR, moving items that are not ordered. Contact dev how did this happen.")
    end

    if changedCategory then
        table.remove(items_current_order, pickedNo)
        AddonNS.printDebug(prevNo, pickedNo, (prevNo > pickedNo and 1 or 0))
        table.insert(items_current_order, prevNo + (prevNo > pickedNo and 0 or 1), pickedItemID)
    else
        table.insert(items_current_order, prevNo, table.remove(items_current_order, pickedNo))
    end
    order_map_changed = true;
end

local function itemMoved(eventName, pickedItemID, targetedItemID, pickedItemCategory, targetItemCategory,
                         pickedItemButton,
                         targetItemButton)
    ItemsMoved(targetedItemID, pickedItemID, pickedItemCategory ~= targetItemCategory)
end
AddonNS.Events:RegisterCustomEvent(AddonNS.Events.ITEM_MOVED, itemMoved)
