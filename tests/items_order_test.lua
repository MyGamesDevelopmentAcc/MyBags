local function category(protected)
    return { IsProtected = function() return protected end }
end
local function environment(ids)
    local handler
    local AddonNS = {
        db = { itemOrder = ids },
        Const = { Events = { ITEM_MOVED = "move" } },
        Events = {
            OnInitialize = function() end,
            RegisterCustomEvent = function(_, _, fn) handler = fn end,
        },
    }
    assert(loadfile("itemsOrder.lua"))("MyBags", AddonNS)
    AddonNS.ItemsOrder:OnInitialize()
    return AddonNS, function(itemID, targetID, source, target, side)
        handler("move", itemID, targetID, source, target, nil, nil, side)
    end
end
local function assertVisualOrder(AddonNS, ids, expected)
    local buttons = {}
    for _, id in ipairs(ids) do table.insert(buttons, { _myBagsItemId = id }) end
    AddonNS.ItemsOrder:Sort(buttons)
    local visual = {}
    for index = #buttons, 1, -1 do table.insert(visual, buttons[index]._myBagsItemId) end
    assert(table.concat(visual, ",") == expected, "unexpected visual order: " .. table.concat(visual, ","))
end
for _, scenario in ipairs({
    { 4, 2, "before", "3,4,2,1" },
    { 4, 2, "after", "3,2,4,1" },
    { 1, 3, "before", "4,1,3,2" },
    { 1, 3, "after", "4,3,1,2" },
    { 4, nil, "end", "3,2,1,4" },
    { 1, nil, "end", "4,3,2,1" },
}) do
    local AddonNS, move = environment({ 1, 2, 3, 4 })
    local target = category(false)
    move(scenario[1], scenario[2], target, target, scenario[3])
    assertVisualOrder(AddonNS, { 1, 2, 3, 4 }, scenario[4])
end
local singletonNS, singletonMove = environment({})
singletonNS.ItemsOrder:Sort({ { _myBagsItemId = 7 } })
assert(table.concat(singletonNS.db.itemOrder, ",") == "7", "single-icon categories register their insertion target")
singletonMove(8, 7, nil, category(false), "after")
assertVisualOrder(singletonNS, { 7, 8 }, "7,8")

local AddonNS, move = environment({ 1, 2, 3, 4 })
move(9, 2, nil, category(false), "before")
assertVisualOrder(AddonNS, { 1, 2, 3, 4, 9 }, "4,3,9,2,1")
move(8, nil, nil, category(false), "end")
assertVisualOrder(AddonNS, { 1, 2, 3, 4, 9, 8 }, "4,3,9,2,1,8")
move(4, nil, category(true), category(false), "end")
assertVisualOrder(AddonNS, { 1, 2, 3, 4, 9, 8 }, "3,9,2,1,8,4")
local previous = table.concat(AddonNS.db.itemOrder, ",")
move(3, nil, category(false), category(true), "end")
assert(table.concat(AddonNS.db.itemOrder, ",") == previous, "protected target cannot reorder items")
move(3, 3, category(false), category(false), "before")
assert(table.concat(AddonNS.db.itemOrder, ",") == previous, "dropping on another stack of the same ID is a no-op")
local ok = pcall(function() move(3, 999, category(false), category(false), "before") end)
assert(not ok and table.concat(AddonNS.db.itemOrder, ",") == previous, "invalid item target fails before modifying order")
ok = pcall(function() move(3, nil, category(false), category(false), nil) end)
assert(not ok, "missing insertion side violates event contract")
print("items_order_test passed")
