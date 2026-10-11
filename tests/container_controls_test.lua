local UI = assert(loadfile("tests/helpers/ui.lua"))()
CreateFrame = UI.CreateFrame
local mode, showDisabled = "normal", false
local pendingExit, helpAnchor, helpSide
local AddonNS = {
    BagViewState = {
        IsCategoriesConfigMode = function() return mode == "categories_config" end,
        SetMode = function(_, value) mode = value end,
        ShouldShowScopeDisabledInConfigMode = function() return showDisabled end,
        SetShowScopeDisabledInConfigMode = function(_, value) assert(type(value) == "boolean"); showDisabled = value end,
    },
    CategoriesGUI = {
        RequestExitEditMode = function() pendingExit = function() mode = "normal" end end,
        ToggleQueryHelpFrame = function(_, anchor, side) helpAnchor, helpSide = anchor, side end,
    },
}
assert(loadfile("containerControls.lua"))("MyBags", AddonNS)
for _, side in ipairs({ "left", "right" }) do
    mode, pendingExit = "normal", nil
    local parent, helpParent, search = UI.CreateFrame(), UI.CreateFrame(), UI.CreateFrame()
    local Controls = AddonNS.ContainerControls:Create(parent, helpParent, search, parent, side)
    assert(Controls.editButton:GetParent() == parent and Controls.helpButton:GetParent() == helpParent)
    assert(not Controls.editButton:IsShown() and not Controls.helpButton:IsShown())
    Controls:Refresh()
    assert(not Controls.scopeDisabledCheckbox:IsShown())
    Controls.editButton:Fire("OnClick")
    assert(mode == "categories_config")
    Controls:Refresh()
    assert(Controls.scopeDisabledCheckbox:IsShown() and Controls.editButton.Icon.color[1] == 1)
    Controls.scopeDisabledCheckbox:SetChecked(true)
    Controls.scopeDisabledCheckbox:Fire("OnClick")
    assert(showDisabled)
    Controls.helpButton:Fire("OnClick")
    assert(helpAnchor == parent and helpSide == side, "help preserves supplied view anchor and direction")
    Controls.editButton:Fire("OnClick")
    assert(mode == "categories_config" and pendingExit, "exit must wait for editor unsaved-changes decision")
    pendingExit()
    Controls:Refresh()
    assert(mode == "normal" and not Controls.scopeDisabledCheckbox:IsShown())
    assert(Controls.editButton.Icon.color[1] == 0.78)
    Controls:Hide()
    assert(not Controls.editButton:IsShown() and not Controls.helpButton:IsShown() and not Controls.scopeDisabledCheckbox:IsShown())
end
AddonNS.CategoriesGUI.RequestExitEditMode = nil
mode = "categories_config"
local Controls = AddonNS.ContainerControls:Create(UI.CreateFrame(), UI.CreateFrame(), UI.CreateFrame(), UI.CreateFrame(), "right")
local ok = pcall(function() Controls.editButton:Fire("OnClick") end)
assert(not ok, "editor exit method is a mandatory contract")
print("container_controls_test passed")
