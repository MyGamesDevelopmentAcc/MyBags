local addonName, AddonNS = ...

AddonNS.CategoryFrame = {}

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING
local EDIT_CATEGORY_TOOLTIP = "Edit"
local DELETE_CATEGORY_TOOLTIP = "Delete"
local DELETE_CATEGORY_HINT = "Shift-click to delete without confirmation."
local CATEGORY_VISIBLE_TEXTURE = "Interface\\FriendsFrame\\StatusIcon-Online"
local CATEGORY_HIDDEN_TEXTURE = "Interface\\FriendsFrame\\StatusIcon-Offline"

local ADD_CATEGORY_CONTROL_LABEL = "|cff90ff90+ Add Category|r"
local ADD_CATEGORY_CONTROL_LABEL_HOVER = "|cffffff80+ Add Category|r"
local EXPORT_CATEGORY_CONTROL_LABEL = "|cffffe266Export Categories|r"
local EXPORT_CATEGORY_CONTROL_LABEL_HOVER = "|cffffff9fExport Categories|r"
local IMPORT_CATEGORY_CONTROL_LABEL = "|cffffe266Import Categories|r"
local IMPORT_CATEGORY_CONTROL_LABEL_HOVER = "|cffffff9fImport Categories|r"
local ADD_CATEGORY_CONTROL_BACKDROP = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local ADD_CATEGORY_CONTROL_STYLE = {
    normal = {
        bg = { 0.08, 0.18, 0.08, 0.86 },
        border = { 0.30, 0.85, 0.30, 1 },
        label = ADD_CATEGORY_CONTROL_LABEL,
    },
    hover = {
        bg = { 0.14, 0.30, 0.14, 0.92 },
        border = { 0.55, 1, 0.55, 1 },
        label = ADD_CATEGORY_CONTROL_LABEL_HOVER,
    },
}

local CONTROL_STYLE_BY_KIND = {
    add = ADD_CATEGORY_CONTROL_STYLE,
    export = {
        normal = {
            bg = { 0.20, 0.17, 0.06, 0.86 },
            border = { 0.95, 0.82, 0.32, 1 },
            label = EXPORT_CATEGORY_CONTROL_LABEL,
        },
        hover = {
            bg = { 0.32, 0.27, 0.10, 0.92 },
            border = { 1, 0.90, 0.45, 1 },
            label = EXPORT_CATEGORY_CONTROL_LABEL_HOVER,
        },
    },
    import = {
        normal = {
            bg = { 0.20, 0.17, 0.06, 0.86 },
            border = { 0.95, 0.82, 0.32, 1 },
            label = IMPORT_CATEGORY_CONTROL_LABEL,
        },
        hover = {
            bg = { 0.32, 0.27, 0.10, 0.92 },
            border = { 1, 0.90, 0.45, 1 },
            label = IMPORT_CATEGORY_CONTROL_LABEL_HOVER,
        },
    },
}

local function styleCategoryControl(frame, isHovered)
    local styleSet = CONTROL_STYLE_BY_KIND[frame.controlKind]
    local style = isHovered and styleSet.hover or styleSet.normal
    frame.addControlBackdrop:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], style.bg[4])
    frame.addControlBackdrop:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], style.border[4])
    frame:SetText(style.label)
end

function AddonNS.CategoryFrame:EnsureControlBackdrop(frame)
    if frame.addControlBackdrop then
        return
    end
    frame.addControlBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.addControlBackdrop:SetBackdrop(ADD_CATEGORY_CONTROL_BACKDROP)
    frame.addControlBackdrop:SetAllPoints(frame)
    frame.addControlBackdrop:EnableMouse(false)
    frame.addControlBackdrop:SetFrameLevel(frame:GetFrameLevel() - 1)
    frame.addControlBackdrop:Hide()
end

function AddonNS.CategoryFrame:StyleControl(frame, isHovered)
    styleCategoryControl(frame, isHovered)
end

local function getScopeVisibilityLabel(scope)
    if scope == "bank-character" then
        return "Bank"
    end
    if scope == "bank-account" then
        return "Warbank"
    end
    return "Bags"
end

function AddonNS.CategoryFrame:Create(parentFrame)
    local headerFrame = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    headerFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    headerFrame:SetBackdropColor(1, 0, 0, 0)

    local label = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
    label:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -ITEM_SPACING / 2, -ITEM_SPACING / 2)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetWordWrap(false)

    local hintOverlay = CreateFrame("Frame", nil, headerFrame, "BackdropTemplate")
    hintOverlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    hintOverlay:SetAllPoints(headerFrame)
    hintOverlay:EnableMouse(false)
    hintOverlay:Hide()

    local deleteButton = CreateFrame("Button", nil, headerFrame)
    deleteButton:SetSize(16, 16)
    deleteButton:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -6, -3)
    deleteButton:SetFrameLevel(headerFrame:GetFrameLevel() + 25)
    deleteButton:Hide()

    deleteButton.Icon = deleteButton:CreateTexture(nil, "ARTWORK")
    deleteButton.Icon:SetAllPoints()
    deleteButton.Icon:SetAtlas("common-icon-delete")

    deleteButton.Highlight = deleteButton:CreateTexture(nil, "HIGHLIGHT")
    deleteButton.Highlight:SetAllPoints()
    deleteButton.Highlight:SetAtlas("common-icon-delete")
    deleteButton.Highlight:SetAlpha(0.45)
    deleteButton.Highlight:SetBlendMode("ADD")

    local editButton = CreateFrame("Button", nil, headerFrame)
    editButton:SetSize(16, 16)
    editButton:SetPoint("TOPRIGHT", deleteButton, "TOPLEFT", -2, 0)
    editButton:SetFrameLevel(headerFrame:GetFrameLevel() + 25)
    editButton:Hide()

    editButton.Icon = editButton:CreateTexture(nil, "ARTWORK")
    editButton.Icon:SetPoint("TOPLEFT", editButton, "TOPLEFT", -4, 4)
    editButton.Icon:SetPoint("BOTTOMRIGHT", editButton, "BOTTOMRIGHT", 4, -4)
    editButton.Icon:SetAtlas("GM-icon-settings")
    editButton.Icon:SetVertexColor(1, 0.85, 0.2, 1)

    editButton.Highlight = editButton:CreateTexture(nil, "HIGHLIGHT")
    editButton.Highlight:SetPoint("TOPLEFT", editButton, "TOPLEFT", -2, 2)
    editButton.Highlight:SetPoint("BOTTOMRIGHT", editButton, "BOTTOMRIGHT", 2, -2)
    editButton.Highlight:SetAtlas("GM-icon-settings")
    editButton.Highlight:SetVertexColor(1, 0.85, 0.2, 1)
    editButton.Highlight:SetAlpha(0.45)
    editButton.Highlight:SetBlendMode("ADD")

    editButton:SetScript("OnEnter", function(selfButton)
        local category = selfButton:GetParent().ItemCategory
        GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
        GameTooltip:SetText(EDIT_CATEGORY_TOOLTIP .. " \"" .. category:GetName() .. "\" category")
        GameTooltip:Show()
    end)
    editButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    editButton:SetScript("OnClick", function(selfButton)
        local category = selfButton:GetParent().ItemCategory
        AddonNS.CategoriesGUI:SelectCategoryById(category:GetId())
    end)

    local scopeVisibilityButton = CreateFrame("Button", nil, headerFrame)
    scopeVisibilityButton:SetSize(16, 16)
    scopeVisibilityButton:SetPoint("TOPRIGHT", editButton, "TOPLEFT", -2, 0)
    scopeVisibilityButton:SetFrameLevel(headerFrame:GetFrameLevel() + 25)
    scopeVisibilityButton:Hide()

    scopeVisibilityButton.Icon = scopeVisibilityButton:CreateTexture(nil, "ARTWORK")
    scopeVisibilityButton.Icon:SetAllPoints()
    scopeVisibilityButton.Icon:SetTexture(CATEGORY_VISIBLE_TEXTURE)

    scopeVisibilityButton.Highlight = scopeVisibilityButton:CreateTexture(nil, "HIGHLIGHT")
    scopeVisibilityButton.Highlight:SetAllPoints()
    scopeVisibilityButton.Highlight:SetTexture(CATEGORY_VISIBLE_TEXTURE)
    scopeVisibilityButton.Highlight:SetAlpha(0.45)
    scopeVisibilityButton.Highlight:SetBlendMode("ADD")

    scopeVisibilityButton:SetScript("OnEnter", function(selfButton)
        local category = selfButton:GetParent().ItemCategory
        local scope = selfButton:GetParent().MyBagsScope
        local scopeLabel = getScopeVisibilityLabel(scope)
        local visible = AddonNS.CustomCategories:IsVisibleInScope(category, scope)
        GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
        if visible then
            GameTooltip:SetText("Visible in " .. scopeLabel)
        else
            GameTooltip:SetText("Hidden in " .. scopeLabel)
        end
        GameTooltip:AddLine(
            "When hidden, this category is not considered for categorization or display in " .. scopeLabel .. ".",
            1, 1, 1, true
        )
        GameTooltip:Show()
    end)
    scopeVisibilityButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    scopeVisibilityButton:SetScript("OnClick", function(selfButton)
        local parent = selfButton:GetParent()
        local category = parent.ItemCategory
        local scope = parent.MyBagsScope
        local visible = AddonNS.CustomCategories:IsVisibleInScope(category, scope)
        AddonNS.CustomCategories:SetVisibleInScope(category, scope, not visible)
    end)

    deleteButton:SetScript("OnEnter", function(selfButton)
        local category = selfButton:GetParent().ItemCategory
        GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
        GameTooltip:SetText(DELETE_CATEGORY_TOOLTIP .. " \"" .. category:GetName() .. "\" category")
        GameTooltip:AddLine(DELETE_CATEGORY_HINT, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    deleteButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    deleteButton:SetScript("OnClick", function(selfButton)
        local category = selfButton:GetParent().ItemCategory
        if IsShiftKeyDown() then
            StaticPopupDialogs["DELETE_CATEGORY_CONFIRM"].OnAccept(nil, category)
            return
        end
        local dialog = StaticPopup_Show("DELETE_CATEGORY_CONFIRM", category:GetName() or "")
        if dialog then
            dialog.data = category
        end
    end)

    headerFrame:EnableMouse(true)
    headerFrame:RegisterForDrag("LeftButton")
    headerFrame:SetScript("OnEnter", function(frame)
        if frame.isAddCategoryControl then
            AddonNS.CategoryFrame:StyleControl(frame, true)
        end
        AddonNS.gui:SetHoveredCategoryFrame(frame)
    end)
    headerFrame:SetScript("OnLeave", function(frame)
        if frame.isAddCategoryControl then
            AddonNS.CategoryFrame:StyleControl(frame, false)
        end
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    headerFrame:HookScript("OnHide", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    function headerFrame:SetText(text)
        label:SetText(text)
    end

    function headerFrame:ApplyCategoryTextLayout(rightControl)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", self, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
        if rightControl then
            label:SetPoint("TOPRIGHT", rightControl, "TOPLEFT", -4, -ITEM_SPACING / 2)
        else
            label:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ITEM_SPACING / 2, -ITEM_SPACING / 2)
        end
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetFontObject("GameFontNormal")
    end

    function headerFrame:ApplyAddControlTextLayout()
        label:ClearAllPoints()
        label:SetPoint("LEFT", headerFrame, "LEFT", 6, 0)
        label:SetPoint("RIGHT", headerFrame, "RIGHT", -6, 0)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetFontObject("GameFontHighlight")
    end

    headerFrame.label = label
    headerFrame.fs = label
    headerFrame.editButton = editButton
    headerFrame.deleteButton = deleteButton
    headerFrame.scopeVisibilityButton = scopeVisibilityButton
    headerFrame.hintOverlay = hintOverlay
    headerFrame.isAddCategoryControl = false
    self:EnsureControlBackdrop(headerFrame)
    return headerFrame
end

function AddonNS.CategoryFrame:BindItems(frame, categoryPosition)
    frame.MyBagsItems = categoryPosition.items
    frame.MyBagsItemSize = categoryPosition.itemSize
    for _, itemButton in ipairs(categoryPosition.items) do
        if itemButton ~= AddonNS.itemButtonPlaceholder then
            itemButton.MyBagsCategoryFrame = frame
        end
    end
end

function AddonNS.CategoryFrame:Configure(frame, categoryPosition, scope)
    frame.MyBagsScope = scope
    if categoryPosition.isAddCategoryControl or categoryPosition.isExportCategoryControl or categoryPosition.isImportCategoryControl then
        frame.ItemCategory = nil
        frame.MyBagsItems = nil
        frame.MyBagsItemSize = nil
        frame.isAddCategoryControl = true
        frame.editButton:Hide()
        frame.deleteButton:Hide()
        frame.scopeVisibilityButton:Hide()
        frame:SetScript("OnReceiveDrag", nil)
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        if categoryPosition.isExportCategoryControl then
            frame.controlKind = "export"
        elseif categoryPosition.isImportCategoryControl then
            frame.controlKind = "import"
        else
            frame.controlKind = "add"
        end
        frame:SetScript("OnMouseUp", function(controlFrame, button)
            if button ~= "LeftButton" then
                return
            end
            if controlFrame.controlKind == "add" then
                StaticPopup_Show("CREATE_CATEGORY_CONFIRM")
            elseif controlFrame.controlKind == "export" then
                AddonNS.CategoriesGUI:ToggleExportFrame()
            else
                AddonNS.CategoriesGUI:ToggleImportFrame()
            end
        end)
        frame.addControlBackdrop:Show()
        frame:ApplyAddControlTextLayout()
        self:StyleControl(frame, false)
    else
        local category = categoryPosition.category
        frame.ItemCategory = category
        self:BindItems(frame, categoryPosition)
        frame.isAddCategoryControl = false
        frame.controlKind = nil
        frame.addControlBackdrop:Hide()
        frame:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
        frame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)
        frame:SetScript("OnDragStart", function(categoryFrame)
            AddonNS.gui:StartCategoryDragVisual(categoryFrame.ItemCategory:GetDisplayName() or "Unassigned")
            AddonNS.DragAndDrop.categoryStartDrag(categoryFrame)
            PlaySound(1183)
        end)
        frame:SetScript("OnDragStop", function()
            AddonNS.gui:StopCategoryDragVisual()
            PlaySound(1200)
        end)
        local canEdit = AddonNS.BagViewState:IsCategoriesConfigMode() and
            AddonNS.CustomCategories:GetCategories()[category:GetId()] ~= nil
        local canDelete = canEdit and not category:IsProtected()
        frame.editButton:SetShown(canEdit)
        frame.scopeVisibilityButton:SetShown(canEdit)
        frame.deleteButton:SetShown(canDelete)
        if canEdit then
            local visible = AddonNS.CustomCategories:IsVisibleInScope(category, scope)
            local texture = visible and CATEGORY_VISIBLE_TEXTURE or CATEGORY_HIDDEN_TEXTURE
            frame.scopeVisibilityButton.Icon:SetTexture(texture)
            frame.scopeVisibilityButton.Highlight:SetTexture(texture)
            frame:ApplyCategoryTextLayout(frame.scopeVisibilityButton)
        else
            frame:ApplyCategoryTextLayout()
        end
        local label = category:GetDisplayName(categoryPosition.itemsCount) or "Unassigned"
        if AddonNS.Collapsed.isCollapsed(category, scope) then
            label = label .. " (" .. categoryPosition.itemsCount .. ") |A:glues-characterSelect-icon-arrowDown:19:19:0:4|a"
        end
        frame:SetText(label)
    end
    frame:Show()
end
