local UI = assert(loadfile("tests/helpers/ui.lua"))()
CreateFrame = UI.CreateFrame
UIParent = CreateFrame()
local focus, itemID, cursorX = nil, 9, 0
GetMouseFoci = function() return { focus } end
GetCursorPosition = function() return cursorX, 0 end
local protected, visible, collapsed = false, true, false
local category = {
    IsProtected = function() return protected end,
    IsVisibleInScope = function(_, scope) assert(scope); return visible end,
}
local AddonNS = {
    Const = { ITEM_SPACING = 4, CATEGORY_HEIGHT = 20 },
    DragAndDrop = { GetDraggedItemID = function() return itemID end },
    Collapsed = { isCollapsed = function() return collapsed end },
}
assert(loadfile("itemInsertionPreview.lua"))("MyBags", AddonNS)
local Preview = AddonNS.ItemInsertionPreview
local marker
for _, frame in ipairs(UI.frames) do
    if frame.Texture then marker = frame end
end
assert(marker and marker.Texture.atlas == "CDM-vertical" and not marker.mouseEnabled)
for _, scope in ipairs({ "bag", "bank-character", "bank-account" }) do
    local categoryFrame = CreateFrame()
    categoryFrame.ItemCategory, categoryFrame.MyBagsScope = category, scope
    categoryFrame.MyBagsItemSize = 44
    local last, first = CreateFrame(), CreateFrame()
    last:SetSize(40, 40)
    last.left, last._myBagsItemId = 100, 1
    first:SetSize(40, 40)
    first.left, first._myBagsItemId = 50, 2
    last.MyBagsCategoryFrame, first.MyBagsCategoryFrame = categoryFrame, categoryFrame
    categoryFrame.MyBagsItems = { last, first }
    focus, cursorX = last, 110
    Preview:Update()
    assert(marker:IsShown() and marker.points[1][2] == last and marker.points[1][3] == "LEFT")
    assert(marker.points[1][4] == -2, "before marker sits in gap to icon's left")
    cursorX = 130
    Preview:Update()
    assert(marker.points[1][3] == "RIGHT" and marker.points[1][4] == 2)
    last:SetScale(2)
    cursorX = 210
    focus = last:CreateTexture()
    Preview:Update()
    assert(marker.points[1][2] == last and marker.points[1][3] == "LEFT", "child focus and cursor scale must resolve correctly")
    assert(marker.scale == 2 and marker:GetHeight() == 48)
    assert(marker.Texture:GetWidth() == 52 and marker.Texture:GetHeight() == 48, "atlas glow retains Blizzard texture width")
    last:SetScale(1)
    focus = categoryFrame
    Preview:Update()
    assert(marker.points[1][2] == last and marker.points[1][3] == "RIGHT", "header drop marks category end")
    itemID = 1
    Preview:Update()
    assert(marker.points[1][2] == first, "append endpoint excludes dragged ID's existing stacks")
    itemID = 9
    local background = CreateFrame()
    background.MyBagsResolveDropColumn = function() return 1 end
    background.GetCategoryFrameAtCursor = function() return categoryFrame end
    focus = background
    Preview:Update()
    assert(marker:IsShown() and marker.points[1][2] == last, "background category fallback marks end")
    categoryFrame.MyBagsItems = {}
    focus = categoryFrame
    Preview:Update()
    assert(marker:IsShown() and marker.points[1][2] == categoryFrame and marker.points[1][3] == "TOPLEFT")
    assert(marker.points[1][5] == -40, "empty category marker sits below its title")
    categoryFrame.MyBagsItems = { last, first }
    focus, itemID = last, 1
    Preview:Update()
    assert(not marker:IsShown(), "same item ID target cannot show a move")
    itemID, protected = 9, true
    Preview:Update()
    assert(not marker:IsShown(), "protected target cannot show legal marker")
    protected, visible = false, false
    Preview:Update()
    assert(not marker:IsShown(), "scope-disabled target cannot show legal marker")
    visible, collapsed = true, true
    Preview:Update()
    assert(not marker:IsShown(), "collapsed categories have no visible icon gap")
    collapsed = false
    focus = { isAddCategoryControl = true, GetParent = function() return background end }
    Preview:Update()
    assert(not marker:IsShown(), "category controls are not insertion targets")
    focus = CreateFrame()
    Preview:Update()
    assert(not marker:IsShown(), "leaving addon targets clears marker")
    focus, itemID = last, nil
    Preview:Update()
    assert(not marker:IsShown(), "canceling item drag hides marker")
    itemID = 9
end
Preview:Hide()
assert(not marker:IsShown())
print("item_insertion_preview_test passed")
