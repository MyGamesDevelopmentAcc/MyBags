-- Exercise the bag iterator and renderer with the real shared modules.
local UI = assert(loadfile("tests/helpers/ui.lua"))()
CreateFrame = UI.CreateFrame
UIParent = CreateFrame()
GameTooltip = { Hide = function() end }
LibStub = function() return {} end
hooksecurefunc = function() end
TooltipDataProcessor = { AddTooltipPostCall = function() end }
Enum = { TooltipDataType = { Item = 1 }, BagIndex = { ReagentBag = 5 } }
InCombatLockdown = function() return false end
GetMouseFoci = function() return {} end
InputUtil = { IsMouseOver = function() return false end }
local cursorX, cursorY = 0, 0
GetCursorPosition = function() return cursorX, cursorY end
local editMode, collapsed = false, false
local categoryDrag = false
local droppedCategory
local category = {
    GetId = function() return "cus-1" end,
    GetName = function() return "Tools" end,
    GetDisplayName = function() return "Tools" end,
    IsProtected = function() return false end,
}
local buttons = { CreateFrame(), CreateFrame() }
for index, button in ipairs(buttons) do
    button:SetSize(6, 6)
    button.GetBagID = function() return 0 end
    button.GetID = function() return index end
end
ContainerFrameCombinedBags = CreateFrame()
ContainerFrameCombinedBags.Items = buttons
ContainerFrameCombinedBags.MoneyFrame = CreateFrame(nil, nil, ContainerFrameCombinedBags)
ContainerFrameCombinedBags.MyBags = { arrangedItems = {}, positionsInBags = { [99] = { stale = true } } }
ContainerFrameCombinedBags.EnumerateValidItems = function()
    return function(_, index)
        index = index + 1
        if buttons[index] then return index, buttons[index] end
    end
end
BagItemSearchBox, BankItemSearchBox = CreateFrame(), CreateFrame()
local AddonNS = {
    Const = {
        ITEM_SPACING = 4, CATEGORY_HEIGHT = 20, ITEMS_PER_ROW = 4, COLUMN_SPACING = 12,
        Events = {
            CATEGORIZER_CATEGORIES_UPDATED = "categories", COLLAPSED_CHANGED = "collapsed",
            ITEM_MOVED = "item", BAG_VIEW_MODE_CHANGED = "mode", CUSTOM_QUERY_EDITOR_FOCUS_CHANGED = "focus",
        },
    },
    Events = { RegisterEvent = function() end, RegisterCustomEvent = function() end },
    Collapsed = { isCollapsed = function(_, scope) assert(scope == "bag"); return collapsed end },
    ContainerItemInfoCache = { Get = function(_, bagID, slotID) return { itemID = slotID, isFiltered = slotID == 2 } end },
    BagViewState = { IsCategoriesConfigMode = function() return editMode end },
    QueryCategories = {},
    CustomCategories = {
        GetCategories = function() return { ["cus-1"] = category } end,
        IsVisibleInScope = function() return true end,
    },
    Categories = {
        Categorize = function() return category end,
        ArrangeCategoriesIntoColumns = function(_, arranged, scope)
            assert(scope == "bag")
            local items = arranged[category] or {}
            local displayed = collapsed and {} or items
            return { { { category = category, items = displayed, itemsCount = #items } }, {} }
        end,
        GetLastCategoryInColumn = function() return category end,
    },
    CategoryStore = { GetColumnCount = function() return 2 end },
    ItemButtonSearchOverlay = { Apply = function(_, button, included) button.included = included end },
    DragAndDrop = {
        HookItemButton = function(_, button) button.myBagAddonHooked = true end,
        IsItemDragActive = function() return false end,
        IsCategoryDragActive = function() return categoryDrag end,
        GetCategoryDropHint = function() return nil end,
        categoryOnMouseUp = function() end,
        categoryOnReceiveDrag = function(frame) droppedCategory = frame.ItemCategory end,
        categoryStartDrag = function() end,
        backgroundOnReceiveDrag = function() error("category body must not use column drop") end,
    },
    ResizeHandle = { Create = function() return { Refresh = function() end, Stop = function() end } end },
}
for _, module in ipairs({ "containerSearch.lua", "categoryLayout.lua", "utils/searchCategoryBaseline.lua", "main.lua", "categoryBackground.lua", "categoryFrame.lua", "gui.lua" }) do
    assert(loadfile(module))("MyBags", AddonNS)
end
local container = ContainerFrameCombinedBags
local function refresh()
    container.MyBags.arrangedItems = {}
    for _ in AddonNS.newEnumerateValidItems(container) do end
    AddonNS.gui:RegenerateCategories(100, container.MyBags.categoryPositions)
end
refresh()
assert(container.MyBags.positionsInBags[99] == nil, "refresh removes stale bag positions")
assert(container.MyBags.positionsInBags[0][2].x == 0 and container.MyBags.positionsInBags[0][1].x == 10)
assert(container.MyBags.height == 30 and container.MyBags.rows == 1, "bag dimensions retain row/header accounting")
local frame = AddonNS.gui.categoryFrameByCategoryId["cus-1"]
assert(frame:GetHeight() == 30 and frame:GetWidth() == 40, "bag frame covers both header and item body")
assert(frame.MyBagsScope == "bag" and frame.MyBagsContainerRef == container)
assert(frame:GetScript("OnReceiveDrag"), "bag renderer restores category interaction")

BagItemSearchBox:SetText("search")
refresh()
assert(buttons[1].included and not buttons[2].included, "bag iterator uses shared search inclusion")
assert(container.MyBags.positionsInBags[0][2] == nil, "filtered items cannot retain stale positions")
assert(container.MyBags.categoryPositions[1].itemsCount == 1)
BagItemSearchBox:SetText("")
collapsed = true
refresh()
assert(next(container.MyBags.positionsInBags) == nil and container.MyBags.rows == 0)
assert(container.MyBags.height == 20 and frame:GetHeight() == 20, "collapsed bag retains header without item rows")
collapsed, editMode = false, true
refresh()
assert(#container.MyBags.categoryPositions == 4, "edit mode adds all three shared controls")
assert(AddonNS.gui.categoriesFrames[2].controlKind == "add")
assert(AddonNS.gui.categoriesFrames[3].controlKind == "export")
assert(AddonNS.gui.categoriesFrames[4].controlKind == "import")
editMode = false
refresh()
assert(not AddonNS.gui.categoriesFrames[2]:IsShown(), "extra pooled frames are hidden after leaving edit mode")

categoryDrag = true
local background = frame:GetParent()
background:SetSize(300, 200)
cursorX, cursorY = 10, 10
background:Fire("OnUpdate")
assert(not frame.hintOverlay:IsShown(), "category hover tracking must not introduce a category-drag highlight")
background:Fire("OnReceiveDrag")
assert(droppedCategory == category, "real bag background routes category drags to the category body")
print("bag_category_presentation_test passed")
