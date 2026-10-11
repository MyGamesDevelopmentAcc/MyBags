local editMode = false
local collapsedScopes = {}
local AddonNS = {
    Const = { ITEM_SPACING = 4, CATEGORY_HEIGHT = 20, ITEMS_PER_ROW = 4, COLUMN_SPACING = 12 },
    itemButtonPlaceholder = {},
    BagViewState = { IsCategoriesConfigMode = function() return editMode end },
    Collapsed = { isCollapsed = function(category, scope) return collapsedScopes[scope] == category end },
}
assert(loadfile("categoryLayout.lua"))("MyBags", AddonNS)
local Layout = AddonNS.CategoryLayout
local first, second, third = {}, {}, {}
local a, b, c, d, e = {}, {}, {}, {}, {}
local assignments = {
    {
        { category = first, items = { a, b }, itemsCount = 2 },
        { category = second, items = { c }, itemsCount = 1 },
        { category = third, items = { d, e }, itemsCount = 2 },
    },
    {},
}
for _, scope in ipairs({ "bag", "bank-character", "bank-account" }) do
    local positions, headers, height, rows = Layout:Calculate(assignments, scope, 10, 6, 30, 12)
    assert(positions[b].x == 6 and positions[a].x == 16, "item order must remain reversed")
    assert(positions[c].x == 26 and positions[c].y == positions[a].y, "small categories share a row")
    assert(headers[1].width == 20 and headers[2].width == 20, "last fitting category fills row remainder")
    assert(headers[3].y == 72 and positions[e].y == 92, "overflow creates a separated row")
    assert(height == 102 and rows == 2, "height includes headers and row count includes items only")
    assert(headers[1].scope == scope, "layout must retain supplied scope")
end

collapsedScopes["bank-account"] = first
local positions, headers = Layout:Calculate(assignments, "bank-account", 10, 0, 0, 0)
assert(positions[a] == nil and positions[b] == nil, "collapsed items have no positions")
assert(headers[1].width == 40 and headers[1].blockHeight == 20, "collapsed category uses a full-width header")
assert(headers[2].y == 32, "following category must be isolated from collapsed header")
positions = Layout:Calculate(assignments, "bag", 10, 0, 0, 0)
assert(positions[a] ~= nil, "collapse state must remain separate by scope")

first.separateLine = true
second.separateLine = true
positions, headers = Layout:Calculate(assignments, "bag", 10, 0, 0, 0)
assert(headers[2].y == 42 and positions[c].y == 62, "separate-line categories start a new row")
first.separateLine, second.separateLine = nil, nil

editMode = true
for _, scope in ipairs({ "bag", "bank-character", "bank-account" }) do
    positions, headers = Layout:Calculate(assignments, scope, 10, 0, 0, 0)
    assert(headers[1].width == 40 and headers[2].width == 40, "edit mode gives categories full width")
    assert(headers[2].y > headers[1].y, "edit mode isolates each category")
    assert(headers[4].isAddCategoryControl and headers[5].isExportCategoryControl and headers[6].isImportCategoryControl)
    assert(headers[4].x == 50 and headers[4].y == 0, "controls belong to the last configured column")
end

editMode = false
local empty = { category = first, items = {}, itemsCount = 0 }
positions, headers = Layout:Calculate({ { empty, assignments[1][2] } }, "bag", 10, 0, 0, 0)
assert(headers[1].width == 40 and headers[1].blockHeight == 20, "empty categories are header-only")
assert(headers[2].y == 32, "empty headers separate following items")
local _, bagHeaders = Layout:Calculate(assignments, "bag", 10, 0, 0, 0)
local _, bankHeaders = Layout:Calculate(assignments, "bank-character", 10, 6, 30, 12)
for index = 1, #bagHeaders do
    assert(bankHeaders[index].x - bagHeaders[index].x == 6)
    assert(bankHeaders[index].y - bagHeaders[index].y == 30, "views differ only by supplied starting coordinates")
end
print("category_layout_test passed")
