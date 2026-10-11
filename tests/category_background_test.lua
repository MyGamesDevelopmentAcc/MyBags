local UI = assert(loadfile("tests/helpers/ui.lua"))()
local cursorX, cursorY = 0, 0
local itemDrag, categoryDrag = false, false
local hovered, targeted, droppedColumn
GetCursorPosition = function() return cursorX, cursorY end
local category = { GetId = function() return "cus-1" end }
local AddonNS = {
    CategoryStore = { GetColumnCount = function() return 3 end },
    Categories = { GetLastCategoryInColumn = function(_, column, scope) return category end },
    DragAndDrop = {
        IsItemDragActive = function() return itemDrag end,
        IsCategoryDragActive = function() return categoryDrag end,
        categoryOnReceiveDrag = function(frame) targeted = frame.ItemCategory end,
    },
    gui = {
        SetHoveredCategoryFrame = function(_, frame) hovered = frame end,
        ClearHoveredCategoryFrame = function() hovered = nil end,
    },
}
AddonNS.DragAndDrop.backgroundOnReceiveDrag = function(frame)
    droppedColumn = AddonNS.CategoryBackground:GetDropColumn(frame, frame.MyBagsScope, frame.MyBagsResolveDropColumn)
end
assert(loadfile("categoryBackground.lua"))("MyBags", AddonNS)
local Background = AddonNS.CategoryBackground
for _, scope in ipairs({ "bag", "bank-character", "bank-account" }) do
    local frame = UI.CreateFrame()
    frame.MyBagsScope = scope
    frame:SetSize(300, 200)
    frame:SetScale(2)
    local target = UI.CreateFrame()
    target.MyBagsScope, target.ItemCategory = scope, category
    target.left, target.bottom = 100, 40
    target:SetSize(80, 60)
    Background:Install(frame, {
        GetCategoryFrames = function() return { target } end,
        GetCategoryFrame = function(value) assert(value == category); return target end,
        ResolveDropColumn = function(relativeX, activeScope, width)
            assert(activeScope == scope)
            return Background:ResolveBagColumn(relativeX, activeScope, width)
        end,
    })
    cursorX, cursorY = 240, 100
    assert(Background:GetHintFrame(frame, { target }, scope) == target, "hit testing must account for effective scale")
    for _, dragKind in ipairs({ "item", "category" }) do
        itemDrag, categoryDrag = dragKind == "item", dragKind == "category"
        hovered, targeted, droppedColumn = nil, nil, nil
        frame:Fire("OnUpdate")
        assert(hovered == target, "both kinds of drag track category area")
        frame:Fire("OnReceiveDrag")
        assert(targeted == category and droppedColumn == nil, "drop over category body targets its category")
        targeted = nil
        Background:ReceiveCategoryMouseUp(target, "LeftButton")
        assert(targeted == category, "bank category surface accepts active category and item drags on mouse-up")
        targeted = nil
        frame:Fire("OnMouseUp", "RightButton")
        assert(targeted == nil, "right-click cannot drop")
        cursorX, cursorY = 500, 350
        frame:Fire("OnUpdate")
        assert(hovered == target, "unused column space hints the last category")
        frame:Fire("OnMouseUp", "LeftButton")
        assert(droppedColumn == 3, "unused column space uses column placement")
        cursorX, cursorY = 240, 100
    end
    itemDrag, categoryDrag = false, false
    frame:Fire("OnUpdate")
    assert(hovered == nil, "no active drag clears hover")
    cursorX = -2
    assert(Background:GetDropColumn(frame, scope, frame.MyBagsResolveDropColumn) == nil, "outside cursor cannot resolve a column")
    cursorX, cursorY = 600, 0
    assert(Background:GetDropColumn(frame, scope, frame.MyBagsResolveDropColumn) == 3, "right edge stays within last column")
    cursorX, cursorY = 240, 100
    target:Hide()
    assert(Background:GetHintFrame(frame, { target }, scope) == nil, "hidden category surfaces do not receive drops")
    frame:Hide()
    assert(hovered == nil)
end
local frame = UI.CreateFrame()
cursorX, cursorY = 10, 10
local ok = pcall(function() Background:GetDropColumn(frame, "bag", nil) end)
assert(not ok, "missing column resolver must fail")
print("category_background_test passed")
