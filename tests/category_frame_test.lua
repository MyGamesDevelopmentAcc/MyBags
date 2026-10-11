local UI = assert(loadfile("tests/helpers/ui.lua"))()
CreateFrame = UI.CreateFrame
local editMode, shiftDown = false, false
local selected, popupName, deleted
local hoverFrame
local visibility = { bag = true, ["bank-character"] = false, ["bank-account"] = true }
local collapsedScopes = {}
local category = {
    GetId = function() return "cus-1" end,
    GetName = function() return "Tools" end,
    GetDisplayName = function() return "Tools" end,
    IsProtected = function(self) return self.protected end,
    protected = false,
}
local AddonNS = {
    Const = { ITEM_SPACING = 4 },
    BagViewState = { IsCategoriesConfigMode = function() return editMode end },
    CustomCategories = {
        GetCategories = function() return { ["cus-1"] = category } end,
        IsVisibleInScope = function(_, value, scope) assert(value == category); return visibility[scope] end,
        SetVisibleInScope = function(_, value, scope, visible) assert(value == category); visibility[scope] = visible end,
    },
    Collapsed = { isCollapsed = function(_, scope) return collapsedScopes[scope] end },
    CategoriesGUI = {
        SelectCategoryById = function(_, id) selected = id end,
        ToggleExportFrame = function() popupName = "export" end,
        ToggleImportFrame = function() popupName = "import" end,
    },
    gui = {
        SetHoveredCategoryFrame = function(_, frame) hoverFrame = frame end,
        ClearHoveredCategoryFrame = function(_, frame) if hoverFrame == frame then hoverFrame = nil end end,
        StartCategoryDragVisual = function() end,
        StopCategoryDragVisual = function() end,
    },
    DragAndDrop = {
        categoryOnMouseUp = function(frame, button) frame.lastMouseButton = button end,
        categoryOnReceiveDrag = function(frame) frame.receivedCategory = frame.ItemCategory end,
        categoryStartDrag = function(frame) frame.draggedCategory = frame.ItemCategory end,
    },
}
GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
PlaySound = function() end
IsShiftKeyDown = function() return shiftDown end
StaticPopupDialogs = { DELETE_CATEGORY_CONFIRM = { OnAccept = function(_, value) deleted = value end } }
local dialog = {}
StaticPopup_Show = function(name) popupName = name; return dialog end
assert(loadfile("categoryFrame.lua"))("MyBags", AddonNS)
local Frames = AddonNS.CategoryFrame
local parent = UI.CreateFrame()
local itemButton = UI.CreateFrame()
AddonNS.itemButtonPlaceholder = {}
local position = { category = category, itemsCount = 5, items = { itemButton, AddonNS.itemButtonPlaceholder }, itemSize = 45 }
for _, scope in ipairs({ "bag", "bank-character", "bank-account" }) do
    local frame = Frames:Create(parent)
    Frames:Configure(frame, position, scope)
    assert(frame:GetParent() == parent and frame.MyBagsScope == scope)
    assert(frame.MyBagsItems == position.items and frame.MyBagsItemSize == 45)
    assert(itemButton.MyBagsCategoryFrame == frame, "item resolves its configured category frame")
    local dropSurface = UI.CreateFrame()
    Frames:BindItems(dropSurface, position)
    assert(itemButton.MyBagsCategoryFrame == dropSurface, "bank body replaces header as item preview target")
    Frames:BindItems(frame, position)
    assert(frame.fs:GetText() == "Tools" and frame:IsShown())
    assert(not frame.editButton:IsShown() and not frame.deleteButton:IsShown(), "normal mode hides edit controls")
    frame:Fire("OnReceiveDrag")
    assert(frame.receivedCategory == category, "shared frame passes category object to drag handler")
    frame:Fire("OnDragStart")
    assert(frame.draggedCategory == category)

    editMode = true
    Frames:Configure(frame, position, scope)
    assert(frame.editButton:IsShown() and frame.deleteButton:IsShown() and frame.scopeVisibilityButton:IsShown())
    local expectedTexture = visibility[scope] and "Interface\\FriendsFrame\\StatusIcon-Online" or "Interface\\FriendsFrame\\StatusIcon-Offline"
    assert(frame.scopeVisibilityButton.Icon.texture == expectedTexture)
    frame.editButton:Fire("OnClick")
    assert(selected == "cus-1")
    local previous = visibility[scope]
    frame.scopeVisibilityButton:Fire("OnClick")
    assert(visibility[scope] == not previous, "visibility action changes supplied scope")
    frame.deleteButton:Fire("OnClick")
    assert(popupName == "DELETE_CATEGORY_CONFIRM" and dialog.data == category, "confirmation carries category object")
    shiftDown = true
    frame.deleteButton:Fire("OnClick")
    assert(deleted == category)
    shiftDown = false
    category.protected = true
    Frames:Configure(frame, position, scope)
    assert(not frame.deleteButton:IsShown() and frame.editButton:IsShown(), "protected categories remain editable but cannot be deleted")
    category.protected = false
    collapsedScopes[scope] = true
    Frames:Configure(frame, position, scope)
    assert(frame.fs:GetText():find("(5)", 1, true), "collapsed labels include item counts")
    collapsedScopes[scope] = false

    for _, control in ipairs({ { isAddCategoryControl = true }, { isExportCategoryControl = true }, { isImportCategoryControl = true } }) do
        Frames:Configure(frame, control, scope)
        assert(frame.ItemCategory == nil and frame.addControlBackdrop:IsShown())
        assert(frame.MyBagsItems == nil and frame.MyBagsItemSize == nil, "controls clear category preview data")
        assert(frame:GetScript("OnDragStart") == nil and frame:GetScript("OnReceiveDrag") == nil)
        assert(not frame.editButton:IsShown() and not frame.deleteButton:IsShown())
        frame:Fire("OnMouseUp", "LeftButton")
        local expected = control.isAddCategoryControl and "CREATE_CATEGORY_CONFIRM" or control.isExportCategoryControl and "export" or "import"
        assert(popupName == expected)
        popupName = nil
        frame:Fire("OnMouseUp", "RightButton")
        assert(popupName == nil, "controls ignore right-clicks")
        Frames:Configure(frame, position, scope)
        assert(frame.ItemCategory == category and not frame.addControlBackdrop:IsShown())
        assert(frame:GetScript("OnDragStart") and frame:GetScript("OnReceiveDrag"), "reused frame restores category handlers")
    end
    frame:Fire("OnEnter")
    assert(hoverFrame == frame)
    frame:Hide()
    assert(hoverFrame == nil, "hiding a category clears hover state")
    editMode = false
end
local ok = pcall(function() Frames:Configure({}, position, "bag") end)
assert(not ok, "incomplete internal frame contract must fail")
print("category_frame_test passed")
