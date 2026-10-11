local UI = assert(loadfile("tests/helpers/ui.lua"))()
CreateFrame = UI.CreateFrame
UIParent = CreateFrame()
BagItemSearchBox = CreateFrame()
BagItemAutoSortButton = CreateFrame()
hooksecurefunc = function() end
C_AddOns = { IsAddOnLoaded = function() return true end }
StaticPopupDialogs = {}
local popup
StaticPopup_Show = function(name) popup = name; return {} end
StaticPopup_Hide = function() end
local Library = {
    CreateButtonFrame = function(_, name, width, height)
        local frame = CreateFrame(nil, name, UIParent)
        frame:SetSize(width, height)
        frame.Inset = CreateFrame(nil, nil, frame)
        return frame
    end,
}
LibStub = function() return Library end
local category = {
    name = "Tools",
    GetId = function() return "cus-1" end,
    GetName = function(self) return self.name end,
}
local mode = "categories_config"
local AddonNS = {
    container = CreateFrame(),
    QueryHelpDocs = { text = "Query reference" },
    Const = { Events = {
        BAG_VIEW_MODE_CHANGED = "mode", SCOPE_DISABLED_CONFIG_VISIBILITY_CHANGED = "visibility",
        CUSTOM_QUERY_EDITOR_FOCUS_CHANGED = "focus",
    } },
    Events = { RegisterCustomEvent = function() end, TriggerCustomEvent = function() end },
    QueueContainerUpdateItemLayout = function() end,
    BagViewState = {
        IsCategoriesConfigMode = function() return mode == "categories_config" end,
        ShouldShowScopeDisabledInConfigMode = function() return false end,
        SetMode = function(_, value) mode = value end,
    },
    CategoryStore = { Get = function(_, id) if id == "cus-1" then return category end end },
    CustomCategories = {
        GetCategories = function() return { ["cus-1"] = category } end,
        GetScopeVisibility = function() return { bag = true, ["bank-character"] = true, ["bank-account"] = true } end,
        GetQuery = function() return "" end,
        GetEffectivePriority = function() return 1 end,
        RenameCategory = function(_, value, name) value.name = name end,
    },
    CategorShowAlways = { ShouldAlwaysShow = function() return false end },
}
BagItemSearchBox.parent, BagItemAutoSortButton.parent = AddonNS.container, AddonNS.container
assert(loadfile("containerControls.lua"))("MyBags", AddonNS)
assert(loadfile("categoriesGUI.lua"))("MyBags", AddonNS)
local editor, nameEditBox
for _, frame in ipairs(UI.frames) do
    if frame.name == "MyBags_CategoryEditorFrame" then editor = frame end
    if frame.template == "InputBoxTemplate" and frame.maxLetters == 64 then nameEditBox = frame end
end
assert(editor and nameEditBox)
local bankControls = AddonNS.ContainerControls:Create(CreateFrame(), CreateFrame(), CreateFrame(), CreateFrame(), "right")

AddonNS.CategoriesGUI:SelectCategoryById("cus-1")
nameEditBox:SetText("Changed")
bankControls.editButton:Fire("OnClick")
assert(popup == "CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM" and mode == "categories_config")
assert(editor:IsShown() and category.name == "Tools", "bank exit must preserve pending draft until decision")
StaticPopupDialogs.CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM.OnAccept()
assert(category.name == "Changed" and mode == "normal" and not editor:IsShown(), "save and exit commits draft before closing")

mode = "categories_config"
AddonNS.CategoriesGUI:SelectCategoryById("cus-1")
nameEditBox:SetText("Discard me")
bankControls.editButton:Fire("OnClick")
StaticPopupDialogs.CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM.OnCancel()
assert(category.name == "Changed" and mode == "normal" and not editor:IsShown(), "discard exit keeps saved category")

mode, popup = "categories_config", nil
AddonNS.CategoriesGUI:SelectCategoryById("cus-1")
bankControls.editButton:Fire("OnClick")
assert(popup == nil and mode == "normal" and not editor:IsShown(), "unchanged draft exits immediately")
print("category_editor_exit_test passed")
