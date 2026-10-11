local addonName, AddonNS = ...

local ContainerControls = {}
ContainerControls.__index = ContainerControls
AddonNS.ContainerControls = ContainerControls

function ContainerControls:Create(editParent, helpParent, searchBox, helpAnchor, helpSide)
    local Controls = setmetatable({ searchBox = searchBox }, self)
    local editButton = CreateFrame("Button", nil, editParent, "UIPanelIconDropdownButtonTemplate")
    editButton:SetSize(20, 20)
    editButton:SetScript("OnClick", function()
        if AddonNS.BagViewState:IsCategoriesConfigMode() then
            AddonNS.CategoriesGUI:RequestExitEditMode()
        else
            AddonNS.BagViewState:SetMode("categories_config")
        end
    end)
    editButton:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText("Toggle edit mode")
        GameTooltip:Show()
    end)
    editButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local helpButton = CreateFrame("Button", nil, helpParent, "MainHelpPlateButton")
    helpButton:SetSize(64, 64)
    helpButton:SetScale(0.45)
    helpButton.mainHelpPlateButtonTooltipText = "Open query syntax and priority help"
    helpButton:SetScript("OnClick", function()
        AddonNS.CategoriesGUI:ToggleQueryHelpFrame(helpAnchor, helpSide)
    end)

    local checkbox = CreateFrame("CheckButton", nil, helpParent, "ChatConfigCheckButtonTemplate")
    checkbox:SetSize(30, 30)
    checkbox:SetHitRectInsets(7, 7, 7, 7)
    checkbox.Text:SetText("")
    checkbox.Text:Hide()
    checkbox:SetScript("OnClick", function(frame)
        AddonNS.BagViewState:SetShowScopeDisabledInConfigMode(frame:GetChecked() == true)
        frame:SetChecked(AddonNS.BagViewState:ShouldShowScopeDisabledInConfigMode())
    end)
    checkbox:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText("Show scope-disabled categories in edit mode")
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    Controls.editButton = editButton
    Controls.helpButton = helpButton
    Controls.scopeDisabledCheckbox = checkbox
    Controls:Hide()
    return Controls
end

function ContainerControls:Refresh()
    local editMode = AddonNS.BagViewState:IsCategoriesConfigMode()
    if editMode then
        self.editButton.Icon:SetVertexColor(1, 0.85, 0.2, 1)
    else
        self.editButton.Icon:SetVertexColor(0.78, 0.78, 0.78, 1)
    end
    self.helpButton:ClearAllPoints()
    self.helpButton:SetPoint("LEFT", self.searchBox, "RIGHT", 4, 0)
    self.scopeDisabledCheckbox:ClearAllPoints()
    self.scopeDisabledCheckbox:SetPoint("RIGHT", self.editButton, "LEFT", -2, 0)
    self.scopeDisabledCheckbox:SetChecked(AddonNS.BagViewState:ShouldShowScopeDisabledInConfigMode())
    self.scopeDisabledCheckbox:SetShown(editMode)
end

function ContainerControls:Hide()
    self.editButton:Hide()
    self.helpButton:Hide()
    self.scopeDisabledCheckbox:Hide()
end
