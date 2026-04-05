local addonName, AddonNS = ...

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING
local CATEGORY_HEIGHT = AddonNS.Const.CATEGORY_HEIGHT
local ITEMS_PER_ROW = AddonNS.Const.ITEMS_PER_ROW

local BANK_CHARACTER_SCOPE = "bank-character"
local BANK_ACCOUNT_SCOPE = "bank-account"
local containerItemInfoCache = assert(AddonNS.ContainerItemInfoCache, "ContainerItemInfoCache missing")

local BankView = {
    headerFrames = {},
    dropFrames = {},
    currentScope = BANK_CHARACTER_SCOPE,
    visibleTabIds = {},
    refreshQueued = false,
    hooksInstalled = false,
    dataRetryCount = 0,
    -- itemButtonsSignature = nil,
    searchSizeLockActive = false,
    searchLockedPanelWidth = nil,
    searchLockedPanelHeight = nil,
    searchUnlockPending = false,
    needsInitialPositionUpdate = false,
    initialPositionUpdateQueued = false,
    categorizationVersion = 0,
}

local BANK_VIEWPORT_TOP = -58
local BANK_VIEWPORT_BOTTOM = 40
local BANK_VIEWPORT_LEFT = 26
local BANK_VIEWPORT_RIGHT = -28
local BANK_CONTENT_PADDING_BOTTOM = 8
local SHOW_COLUMN_DROP_AREAS = false
local BANK_CONTENT_LEFT_PADDING = 6
local BANK_CONTENT_FIRST_ROW_Y = 30
local BANK_SEARCH_BOX_LEFT_X = 78
local BANK_SEARCH_BOX_TOP_Y = -33
local QUERY_HELP_SIDE_RIGHT = "right"
local QUERY_HELP_TOOLTIP_TEXT = "Open query syntax and priority help"
local SCOPE_DISABLED_CHECKBOX_TOOLTIP_TEXT = "Show scope-disabled categories in edit mode"
local EDIT_CATEGORY_TOOLTIP = "Edit"
local DELETE_CATEGORY_TOOLTIP = "Delete"
local DELETE_CATEGORY_HINT = "Shift-click to delete without confirmation."
local CATEGORY_VISIBLE_TEXTURE = "Interface\\FriendsFrame\\StatusIcon-Online"
local CATEGORY_HIDDEN_TEXTURE = "Interface\\FriendsFrame\\StatusIcon-Offline"
local CAPACITY_LABEL_FORMAT = "%d/%d"
local BANK_DEFAULT_ITEM_SIZE = 41
local BANK_RESIZE_HANDLE_SIZE = 16
local BANK_MIN_NUM_COLUMNS = 5
local BANK_MAX_NUM_COLUMNS = 10
local AUTO_DEPOSIT_BUTTON_WIDTH_SCALE = 0.7
local calculateScaledDepositButtonWidth
local applyScaledDepositButtonWidth

local function getScopeForBankType(bankType)
    if bankType == Enum.BankType.Account then
        return BANK_ACCOUNT_SCOPE
    end
    return BANK_CHARACTER_SCOPE
end

local function getScopeVisibilityLabel(scope)
    if scope == BANK_CHARACTER_SCOPE then
        return "Bank"
    end
    if scope == BANK_ACCOUNT_SCOPE then
        return "Warbank"
    end
    return "Bags"
end

local function ensureItemButtonBagMethods(itemButton)
    if itemButton.GetBankTabID and itemButton.GetContainerSlotID then
        function itemButton:GetBagID()
            return self:GetBankTabID()
        end

        function itemButton:GetID()
            return self:GetContainerSlotID()
        end

        return
    end
    if not itemButton.GetBagID and itemButton.GetBankTabID then
        function itemButton:GetBagID()
            return self:GetBankTabID()
        end
    end
    if not itemButton.GetID and itemButton.GetContainerSlotID then
        function itemButton:GetID()
            return self:GetContainerSlotID()
        end
    end
end

local function resolveBankButtonContainerSlot(itemButton)
    local bagID = nil
    if itemButton.GetBankTabID then
        bagID = itemButton:GetBankTabID()
    end
    if bagID == nil and itemButton.GetBagID then
        bagID = itemButton:GetBagID()
    end

    local slotID = nil
    if itemButton.GetContainerSlotID then
        slotID = itemButton:GetContainerSlotID()
    end
    if slotID == nil and itemButton.GetID then
        slotID = itemButton:GetID()
    end

    if type(bagID) ~= "number" or type(slotID) ~= "number" then
        return nil, nil
    end
    return bagID, slotID
end

local function getPurchasedTabIdsForActiveType(panel)
    local tabData = panel.purchasedBankTabData
    if type(tabData) ~= "table" then
        tabData = C_Bank.FetchPurchasedBankTabData(panel:GetActiveBankType()) or {}
    end

    local tabIds = {}
    for index = 1, #tabData do
        local id = tabData[index] and tabData[index].ID
        if type(id) == "number" and id > 0 then
            table.insert(tabIds, id)
        end
    end
    return tabIds, tabData
end

local function buildVisibleTabIds(tabIds)
    local set = {}
    for index = 1, #tabIds do
        set[tabIds[index]] = true
    end
    return set
end

local function shouldRefreshForBagUpdate(visibleTabIds, bagID)
    if bagID == nil then
        return true
    end
    return visibleTabIds[bagID] == true
end

local function generateAllTabItemButtons(panel, activeBankType, tabIds)
    panel.itemButtonPool:ReleaseAll()
    for tabIndex = 1, #tabIds do
        local tabID = tabIds[tabIndex]
        local slots = C_Container.GetContainerNumSlots(tabID)
        if type(slots) == "number" and slots > 0 then
            for containerSlotID = 1, slots do
                local button = panel.itemButtonPool:Acquire()
                button:Init(activeBankType, tabID, containerSlotID)
                button:Show()
            end
        end
    end
end

local function hasAnyActiveItemButtons(panel)
    for _ in panel:EnumerateValidItems() do
        return true
    end
    return false
end

local function countActiveItemButtons(panel)
    local count = 0
    for _ in panel:EnumerateValidItems() do
        count = count + 1
    end
    return count
end

local function countExpectedButtonsForTabs(tabIds)
    local expected = 0
    for index = 1, #tabIds do
        local tabID = tabIds[index]
        local slotCount = C_Container.GetContainerNumSlots(tabID) or 0
        if slotCount > 0 then
            expected = expected + slotCount
        end
    end
    return expected
end

local function buildItemButtonsSignature(activeBankType, tabIds)
    local parts = { tostring(activeBankType) }
    for index = 1, #tabIds do
        local tabID = tabIds[index]
        local slotCount = C_Container.GetContainerNumSlots(tabID) or 0
        table.insert(parts, tostring(tabID) .. ":" .. tostring(slotCount))
    end
    return table.concat(parts, "|")
end

local function applyCachedIncludeInSearch(panel)
    for itemButton in panel:EnumerateValidItems() do
        local defaultMatch = itemButton:GetMatchesSearch()
        if type(defaultMatch) == "boolean" then
            itemButton._myBagsDefaultSearchMatch = defaultMatch
        end
        if itemButton.searchOverlay and itemButton.searchOverlay.SetAlpha then
            itemButton.searchOverlay:SetAlpha(0)
        end
        if itemButton.ItemContextOverlay and itemButton.ItemContextOverlay.SetAlpha then
            itemButton.ItemContextOverlay:SetAlpha(0)
        end
    end
end

local function hideBlizzardBankTabs(panel)
    for tabButton in panel.bankTabPool:EnumerateActive() do
        tabButton:Hide()
    end
    panel.PurchaseTab:Hide()
end

local function shouldShowPurchaseTabButton(activeBankType)
    return C_Bank.CanPurchaseBankTab(activeBankType) and not C_Bank.HasMaxBankTabs(activeBankType)
end

local function refreshSearchBoxLayout()
    if not BankItemSearchBox or not BagItemSearchBox then
        return
    end
    BankItemSearchBox:ClearAllPoints()
    BankItemSearchBox:SetPoint("TOPLEFT", BankFrame, "TOPLEFT", BANK_SEARCH_BOX_LEFT_X, BANK_SEARCH_BOX_TOP_Y)
    BankItemSearchBox:SetWidth(BagItemSearchBox:GetWidth())
end

local function ensureEditModeButton(self, panel)
    if self.editModeButton then
        return self.editModeButton
    end

    local button = CreateFrame("Button", nil, panel, "UIPanelIconDropdownButtonTemplate")
    button:SetSize(20, 20)
    button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -9, -34)
    button:SetScript("OnClick", function()
        if AddonNS.BagViewState:IsCategoriesConfigMode() then
            AddonNS.BagViewState:SetMode("normal")
            return
        end
        AddonNS.BagViewState:SetMode("categories_config")
    end)

    button:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText("Toggle edit mode")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:Hide()
    self.editModeButton = button
    return button
end

local function showEditModeButton(self, panel)
    local button = ensureEditModeButton(self, panel)
    if AddonNS.BagViewState:IsCategoriesConfigMode() then
        button.Icon:SetVertexColor(1, 0.85, 0.2, 1)
    else
        button.Icon:SetVertexColor(0.78, 0.78, 0.78, 1)
    end
    panel.AutoSortButton:Hide()
    button:Show()
end

local function hideEditModeButton(self)
    if self.editModeButton then
        self.editModeButton:Hide()
    end
end

local function ensureSearchHelpButton(self)
    if self.searchHelpButton then
        return self.searchHelpButton
    end
    local button = CreateFrame("Button", nil, BankFrame, "MainHelpPlateButton")
    button:SetSize(64, 64)
    button:SetScale(0.45)
    button.mainHelpPlateButtonTooltipText = QUERY_HELP_TOOLTIP_TEXT
    button:SetScript("OnClick", function()
        AddonNS.CategoriesGUI:ToggleQueryHelpFrame(BankFrame, QUERY_HELP_SIDE_RIGHT)
    end)
    button:Hide()
    self.searchHelpButton = button
    return button
end

local function showSearchHelpButton(self)
    local button = ensureSearchHelpButton(self)
    button:ClearAllPoints()
    button:SetPoint("LEFT", BankItemSearchBox, "RIGHT", 4, 0)
    button:Show()
end

local function hideSearchHelpButton(self)
    if self.searchHelpButton then
        self.searchHelpButton:Hide()
    end
end

local function ensureSearchScopeDisabledCheckbox(self)
    if self.searchScopeDisabledCheckbox then
        return self.searchScopeDisabledCheckbox
    end
    local checkbox = CreateFrame("CheckButton", nil, BankFrame, "ChatConfigCheckButtonTemplate")
    checkbox:SetSize(30, 30)
    checkbox:SetHitRectInsets(7, 7, 7, 7)
    checkbox.Text:SetText("")
    checkbox.Text:Hide()
    checkbox:SetScript("OnClick", function(selfCheckbox)
        AddonNS.BagViewState:SetShowScopeDisabledInConfigMode(selfCheckbox:GetChecked() == true)
        selfCheckbox:SetChecked(AddonNS.BagViewState:ShouldShowScopeDisabledInConfigMode())
    end)
    checkbox:SetScript("OnEnter", function(selfCheckbox)
        GameTooltip:SetOwner(selfCheckbox, "ANCHOR_TOP")
        GameTooltip:SetText(SCOPE_DISABLED_CHECKBOX_TOOLTIP_TEXT)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    checkbox:Hide()
    self.searchScopeDisabledCheckbox = checkbox
    return checkbox
end

local function showSearchScopeDisabledCheckbox(self, panel)
    local editButton = ensureEditModeButton(self, panel)
    local checkbox = ensureSearchScopeDisabledCheckbox(self)
    checkbox:ClearAllPoints()
    checkbox:SetPoint("RIGHT", editButton, "LEFT", -2, 0)
    checkbox:SetChecked(AddonNS.BagViewState:ShouldShowScopeDisabledInConfigMode())
    checkbox:SetShown(AddonNS.BagViewState:IsCategoriesConfigMode())
end

local function hideSearchScopeDisabledCheckbox(self)
    if self.searchScopeDisabledCheckbox then
        self.searchScopeDisabledCheckbox:Hide()
    end
end

local function ensureItemButtonHooks(itemButton)
    if itemButton.myBagAddonHooked then
        return
    end
    itemButton:HookScript("OnDragStart", AddonNS.DragAndDrop.itemStartDrag)
    itemButton:HookScript("OnDragStop", AddonNS.DragAndDrop.itemStopDrag)
    itemButton:HookScript("PreClick", AddonNS.DragAndDrop.itemOnClick)
    itemButton:HookScript("OnReceiveDrag", AddonNS.DragAndDrop.itemOnReceiveDrag)
    itemButton:HookScript("OnEnter", function(button)
        local category = button.ItemCategory
        if not category then
            return
        end
        local bankView = AddonNS.BankView
        if not bankView or not bankView.dropFrameByCategoryId then
            return
        end
        local hintFrame = bankView.dropFrameByCategoryId[category:GetId()]
        if hintFrame and hintFrame:IsShown() then
            AddonNS.gui:SetHoveredCategoryFrame(hintFrame)
        end
    end)
    itemButton:HookScript("OnLeave", function(button)
        local category = button.ItemCategory
        if not category then
            return
        end
        local bankView = AddonNS.BankView
        if not bankView or not bankView.dropFrameByCategoryId then
            return
        end
        local hintFrame = bankView.dropFrameByCategoryId[category:GetId()]
        if hintFrame then
            AddonNS.gui:ClearHoveredCategoryFrame(hintFrame)
        end
    end)

    itemButton.myBagAddonHooked = true
end

local function getActiveBankPanel()
    assert(BankPanel, "BankPanel missing")
    return BankPanel
end

local function hideHeaders(self)
    for index = 1, #self.headerFrames do
        self.headerFrames[index]:Hide()
    end
    for index = 1, #self.dropFrames do
        self.dropFrames[index]:Hide()
    end
    self.dropFrameByCategoryId = {}
end

local function hideContentArea(self)
    if self.contentFrame then
        self.contentFrame:Hide()
    end
end

local function hideAllItemButtons(panel)
    for itemButton in panel:EnumerateValidItems() do
        itemButton:Hide()
    end
end

local function ensureCapacityOverlay(self, panel)
    if self.capacityOverlay then
        return self.capacityOverlay
    end

    local overlay = CreateFrame("Frame", nil, panel)
    overlay:SetSize(50, 20)
    overlay:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 26, 7)
    overlay:EnableMouse(true)

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", overlay, "LEFT", 0, 0)
    label:SetPoint("RIGHT", overlay, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(1, 0.82, 0.2, 1)

    overlay.label = label
    self.capacityOverlay = overlay
    return overlay
end

local function ensurePurchaseTabButton(self, panel)
    if self.purchaseTabButton then
        return self.purchaseTabButton
    end

    local button = CreateFrame("Button", nil, panel)
    button:SetSize(20, 20)
    button:SetScript("OnClick", function(frame)
        StaticPopup_Show("CONFIRM_BUY_BANK_TAB", nil, nil, { bankType = frame.bankType })
    end)
    button:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText("Click to purchase the next bank tab and increase bank capacity.")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("128-RedButton-Plus")
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetAtlas("128-RedButton-Plus")
    highlight:SetAlpha(0.55)
    highlight:SetBlendMode("ADD")

    button:Hide()
    self.purchaseTabButton = button
    return button
end

local function refreshBottomBar(self, panel, activeBankType, tabIds)
    local capacityState = AddonNS.GetBankCapacityState(tabIds)
    local capacityOverlay = ensureCapacityOverlay(self, panel)
    capacityOverlay.label:SetText(CAPACITY_LABEL_FORMAT:format(capacityState.taken, capacityState.total))
    capacityOverlay:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Bank capacity")
        GameTooltip:AddLine(
            "You are using " .. capacityState.taken .. " slots out of " .. capacityState.total ..
            " (" .. capacityState.free .. " available).",
            1, 1, 1, true
        )
        GameTooltip:Show()
    end)
    capacityOverlay:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    capacityOverlay:Show()

    local purchaseButton = ensurePurchaseTabButton(self, panel)
    purchaseButton:ClearAllPoints()
    purchaseButton:SetPoint("LEFT", capacityOverlay, "RIGHT", 4, 0)
    purchaseButton.bankType = activeBankType
    purchaseButton:SetShown(shouldShowPurchaseTabButton(activeBankType))

    panel.AutoDepositFrame:ClearAllPoints()
    panel.AutoDepositFrame:SetPoint("BOTTOM", panel, "BOTTOM", 0, 3)

    local autoDepositFrame = panel.AutoDepositFrame
    local autoDepositButton = autoDepositFrame.DepositButton
    local includeReagentsCheckbox = autoDepositFrame.IncludeReagentsCheckbox
    local includeReagentsLabel = includeReagentsCheckbox.Text

    applyScaledDepositButtonWidth(autoDepositButton)
    autoDepositButton:ClearAllPoints()
    includeReagentsCheckbox:ClearAllPoints()
    includeReagentsLabel:ClearAllPoints()
    if activeBankType == Enum.BankType.Account then
        local labelWidth = includeReagentsLabel:GetStringWidth() or 0
        local checkboxToMoneyGap = math.ceil(labelWidth) + 8
        includeReagentsCheckbox:SetPoint("RIGHT", panel.MoneyFrame, "LEFT", -checkboxToMoneyGap, 0)
        autoDepositButton:SetPoint("RIGHT", includeReagentsCheckbox, "LEFT", -10, 0)
        includeReagentsLabel:SetPoint("LEFT", includeReagentsCheckbox, "RIGHT", 4, 0)
        includeReagentsLabel:SetJustifyH("LEFT")
    else
        autoDepositButton:SetPoint("CENTER", autoDepositFrame, "CENTER", 0, 0)
        includeReagentsCheckbox:SetPoint("LEFT", autoDepositButton, "RIGHT", 10, 0)
        includeReagentsLabel:SetPoint("LEFT", includeReagentsCheckbox, "RIGHT", 4, 0)
        includeReagentsLabel:SetJustifyH("LEFT")
    end
end

local function hideBottomBarControls(self)
    if self.capacityOverlay then
        self.capacityOverlay:Hide()
    end
    if self.purchaseTabButton then
        self.purchaseTabButton:Hide()
    end
end

local function getViewportWidthForColumns(columnCount, columnPixelWidth)
    return BANK_CONTENT_LEFT_PADDING + columnCount * columnPixelWidth
end

local function getPanelWidthForColumns(columnCount, columnPixelWidth)
    local viewportWidth = getViewportWidthForColumns(columnCount, columnPixelWidth)
    return viewportWidth - BANK_VIEWPORT_RIGHT + BANK_VIEWPORT_LEFT
end

local function getPanelHeightForContent(contentBottom)
    local viewportHeight = contentBottom + BANK_CONTENT_PADDING_BOTTOM
    return viewportHeight - BANK_VIEWPORT_TOP + BANK_VIEWPORT_BOTTOM
end

local function getCurrentItemSize(panel)
    for itemButton in panel:EnumerateValidItems() do
        return itemButton:GetHeight() + ITEM_SPACING
    end
    return BANK_DEFAULT_ITEM_SIZE + ITEM_SPACING
end

local function applyBankScopeColumnCount(target, scope)
    local resolvedScope = scope or BANK_CHARACTER_SCOPE
    AddonNS:SetNumColumns(target, resolvedScope)
end

local function refreshBankFrameScale()
    if AddonNS.ApplyBankFrameScale then
        AddonNS.ApplyBankFrameScale()
    end
end

calculateScaledDepositButtonWidth = function(baseWidth)
    return math.floor(baseWidth * AUTO_DEPOSIT_BUTTON_WIDTH_SCALE + 0.5)
end

applyScaledDepositButtonWidth = function(autoDepositButton)
    if autoDepositButton._myBagsBaseWidth == nil then
        autoDepositButton._myBagsBaseWidth = autoDepositButton:GetWidth()
    end
    autoDepositButton:SetWidth(calculateScaledDepositButtonWidth(autoDepositButton._myBagsBaseWidth))
end

local function shouldShowBankResizeHandle(bankFrameShown, panelShown, inCombat)
    return bankFrameShown and panelShown and not inCombat
end

local function resolveTargetPanelSize(computedWidth, computedHeight, lockedWidth, lockedHeight, lockActive)
    if not lockActive then
        return computedWidth, computedHeight
    end
    return lockedWidth or computedWidth, lockedHeight or computedHeight
end

local function updateSearchSizeLock(self, panel, searchText)
    local searchActive = searchText ~= ""
    if searchActive then
        self.searchUnlockPending = false
        if not self.searchSizeLockActive then
            self.searchSizeLockActive = true
            self.searchLockedPanelWidth = panel:GetWidth()
            self.searchLockedPanelHeight = panel:GetHeight()
        end
        return
    end

    if self.searchSizeLockActive and not self.searchUnlockPending then
        self.searchUnlockPending = true
        return
    end

    self.searchSizeLockActive = false
    self.searchLockedPanelWidth = nil
    self.searchLockedPanelHeight = nil
    self.searchUnlockPending = false
end

local function refreshPositionsAndScale()
    refreshBankFrameScale()
    if UpdateUIPanelPositions then
        UpdateUIPanelPositions(BankFrame)
    end
    if ContainerFrameCombinedBags:IsShown() then
        AddonNS.ApplyContainerFrameScale()
    end
end

local function updateFrameSizeForContent(self, panel, contentBottom)
    -- local previousPanelHeight = panel:GetHeight()
    local columnCount = AddonNS.CategoryStore:GetColumnCount(self.currentScope)
    local columnPixelWidth = self.columnPixelWidth
    local panelWidth = getPanelWidthForColumns(columnCount, columnPixelWidth)
    local panelHeight = getPanelHeightForContent(contentBottom)
    panelWidth, panelHeight = resolveTargetPanelSize(
        panelWidth,
        panelHeight,
        self.searchLockedPanelWidth,
        self.searchLockedPanelHeight,
        self.searchSizeLockActive
    )

    panel:SetSize(panelWidth, panelHeight)
    BankFrame:SetSize(panelWidth, panelHeight)

    refreshPositionsAndScale()
    -- local heightGrew = previousPanelHeight and panelHeight > (previousPanelHeight + POSITION_UPDATE_HEIGHT_GROWTH_THRESHOLD)


    if self.needsInitialPositionUpdate and not self.initialPositionUpdateQueued then
        self.initialPositionUpdateQueued = true
        RunNextFrame(function()
            self.initialPositionUpdateQueued = false
            if not BankFrame:IsShown() then
                return
            end
            refreshPositionsAndScale()
            self.needsInitialPositionUpdate = false
        end)
    end
end

local function ensureResizeController(self, panel)
    if self.resizeController then
        return self.resizeController
    end

    local controller = AddonNS.ResizeHandle:Create({
        parentFrame = panel,
        previewParent = self.backgroundFrame,
        minColumns = BANK_MIN_NUM_COLUMNS,
        maxColumns = BANK_MAX_NUM_COLUMNS,
        anchor = {
            point = "BOTTOMRIGHT",
            relativeTo = panel,
            relativePoint = "BOTTOMRIGHT",
            x = -2,
            y = 2,
        },
        GetColumnPixelWidth = function()
            if self.columnPixelWidth and self.columnPixelWidth > 0 then
                return self.columnPixelWidth
            end
            local itemSize = getCurrentItemSize(panel)
            return itemSize * ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
        end,
        GetCurrentColumns = function()
            local scope = self.currentScope or BANK_CHARACTER_SCOPE
            return AddonNS.CategoryStore:GetColumnCount(scope)
        end,
        GetWidth = function()
            return panel:GetWidth()
        end,
        GetHeight = function()
            return panel:GetHeight()
        end,
        SetWidth = function(width)
            panel:SetWidth(width)
            BankFrame:SetWidth(width)
        end,
        SetHeight = function(height)
            panel:SetHeight(height)
            BankFrame:SetHeight(height)
        end,
        CalculateDesiredWidth = function(startWidth, deltaX)
            return startWidth + deltaX
        end,
        ApplyTargetColumns = function(target)
            local scope = self.currentScope or BANK_CHARACTER_SCOPE
            applyBankScopeColumnCount(target, scope)
        end,
        OnApplied = function()
            self:RefreshNow(self.currentScope)
        end,
        OnCancel = function()
            self:RefreshNow(self.currentScope)
        end,
        ShouldShow = function()
            return shouldShowBankResizeHandle(BankFrame:IsShown(), panel:IsShown(), InCombatLockdown())
        end,
        IsDisabled = function()
            return InCombatLockdown() or self.searchSizeLockActive
        end,
    })

    controller.handle:SetSize(BANK_RESIZE_HANDLE_SIZE, BANK_RESIZE_HANDLE_SIZE)
    self.resizeController = controller
    return controller
end

local function refreshResizeHandle(self, panel)
    if not self.backgroundFrame then
        return
    end
    ensureResizeController(self, panel):Refresh()
end

local function evaluateSearchVisibility(defaultMatch, searchEvaluator, itemInfo, itemButton)
    local includeInSearch = defaultMatch
    local queryMatch = false
    if not defaultMatch and searchEvaluator then
        local payload = AddonNS.CustomCategories:GetItemQueryPayload(itemInfo.itemID, itemButton, itemInfo)
        includeInSearch, queryMatch = AddonNS.QueryCategories:EvaluateSearchUnion(defaultMatch, searchEvaluator, payload)
    end
    return includeInSearch, queryMatch
end

local function setItemButtonSearchOverlayAlpha(itemButton, alpha)
    if itemButton.searchOverlay and itemButton.searchOverlay.SetAlpha then
        itemButton.searchOverlay:SetAlpha(alpha)
    end
    if itemButton.ItemContextOverlay and itemButton.ItemContextOverlay.SetAlpha then
        itemButton.ItemContextOverlay:SetAlpha(alpha)
    end
end

local function setMyBagsIncludeInSearch(itemButton, includeInSearch)
    itemButton._myBagsIncludeInSearch = includeInSearch == true
    if includeInSearch then
        setItemButtonSearchOverlayAlpha(itemButton, 0)
        return
    end
    setItemButtonSearchOverlayAlpha(itemButton, 1)
end

local function shouldRetryForMissingItemData(hasAnyButtons, hadAnyItemData, retryCount)
    return hasAnyButtons and (not hadAnyItemData) and retryCount < 6
end

local function buildCategoryCacheKey(itemButton, itemInfo, scope, categorizationVersion)
    return table.concat({
        tostring(itemButton:GetBagID()),
        tostring(itemButton:GetID()),
        tostring(itemInfo.itemID),
        tostring(itemInfo.stackCount),
        tostring(itemInfo.quality),
        tostring(itemInfo.hyperlink),
        tostring(scope),
        tostring(categorizationVersion),
    }, ":")
end

local function resolveCachedOrComputeCategory(self, itemButton, itemInfo, scope)
    local cacheKey = buildCategoryCacheKey(itemButton, itemInfo, scope, self.categorizationVersion)
    if itemButton._myBagsCategoryCacheKey == cacheKey and itemButton._myBagsCategoryCacheValue then
        return itemButton._myBagsCategoryCacheValue
    end
    local category = AddonNS.Categories:Categorize(itemInfo.itemID, itemButton)
    itemButton._myBagsCategoryCacheKey = cacheKey
    itemButton._myBagsCategoryCacheValue = category
    return category
end

local function invalidateCategorizationCacheVersion(self)
    self.categorizationVersion = self.categorizationVersion + 1
end

local function applySearchUnionMatchState(panel, searchEvaluator)
    if not searchEvaluator then
        return
    end
    for itemButton in panel:EnumerateValidItems() do
        local bagID, slotID = resolveBankButtonContainerSlot(itemButton)
        if bagID and slotID then
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info then
                local defaultMatch = not info.isFiltered
                local includeInSearch = evaluateSearchVisibility(defaultMatch, searchEvaluator, info, itemButton)
                setMyBagsIncludeInSearch(itemButton, includeInSearch)
            end
        end
    end
end

local function ensureDropAreaOverlay(self, index)
    if self.dropAreaOverlays[index] then
        return self.dropAreaOverlays[index]
    end

    local overlay = CreateFrame("Frame", nil, self.contentFrame, "BackdropTemplate")
    overlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile =
    "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
    overlay:SetBackdropColor(0.22, 0.45, 0.95, 0.08)
    overlay:SetBackdropBorderColor(0.38, 0.62, 1, 0.28)
    overlay:EnableMouse(false)

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", overlay, "TOP", 0, -4)
    label:SetTextColor(0.75, 0.86, 1, 0.75)
    overlay.label = label

    self.dropAreaOverlays[index] = overlay
    return overlay
end

local function hideDropAreaOverlays(self)
    if not self.dropAreaOverlays then
        return
    end
    for index = 1, #self.dropAreaOverlays do
        self.dropAreaOverlays[index]:Hide()
    end
end

local function updateDropAreaOverlays(self, scope)
    if not SHOW_COLUMN_DROP_AREAS then
        hideDropAreaOverlays(self)
        return
    end
    if not self.contentFrame then
        hideDropAreaOverlays(self)
        return
    end

    local columnCount = AddonNS.CategoryStore:GetColumnCount(scope)
    local areaWidth = self.contentFrame:GetWidth() or 0
    local areaHeight = self.contentFrame:GetHeight() or 0
    local columnPixelWidth = self.columnPixelWidth
    local firstColumnStartX = self.firstColumnStartX
    if columnCount <= 0 or areaWidth <= 0 or areaHeight <= 0 or not columnPixelWidth or not firstColumnStartX then
        hideDropAreaOverlays(self)
        return
    end

    for index = 1, columnCount do
        local overlay = ensureDropAreaOverlay(self, index)
        local startX = firstColumnStartX + (index - 1) * columnPixelWidth
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT", startX, 0)
        overlay:SetSize(columnPixelWidth, areaHeight)
        overlay.label:SetText(index)
        overlay:Show()
    end
    for index = columnCount + 1, #self.dropAreaOverlays do
        self.dropAreaOverlays[index]:Hide()
    end
end

local function getCursorPositionForFrame(frame)
    local cursorX, cursorY = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local localX = cursorX / scale
    local localY = cursorY / scale
    return localX, localY
end

local function getMouseRelativePosition(frame)
    local localX, localY = getCursorPositionForFrame(frame)
    localX = localX - frame:GetLeft()
    localY = localY - frame:GetBottom()
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    if localX < 0 or localX > width or localY < 0 or localY > height then
        return nil, nil
    end
    return localX, width
end

local function getBackgroundHintFrame(self, frame, scope)
    if not self.dropFrames then
        return nil
    end
    local cursorX, cursorY = getCursorPositionForFrame(frame)
    for index = 1, #self.dropFrames do
        local dropFrame = self.dropFrames[index]
        if dropFrame and dropFrame:IsShown() and dropFrame.MyBagsScope == scope and dropFrame.ItemCategory then
            local left = dropFrame:GetLeft()
            local right = dropFrame:GetRight()
            local bottom = dropFrame:GetBottom()
            local top = dropFrame:GetTop()
            if left and right and bottom and top and cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top then
                return dropFrame
            end
        end
    end
    return nil
end

local function getBackgroundColumnFallbackHintFrame(self, frame, scope)
    local relativeX, frameWidth = getMouseRelativePosition(frame)
    if not relativeX or not frameWidth then
        return nil
    end
    local columnNo = self:ResolveDropColumn(relativeX, scope, frameWidth)
    if not columnNo then
        return nil
    end
    local targetCategory = AddonNS.Categories:GetLastCategoryInColumn(columnNo, scope)
    if not targetCategory or not targetCategory.GetId then
        return nil
    end
    if not self.dropFrameByCategoryId then
        return nil
    end
    return self.dropFrameByCategoryId[targetCategory:GetId()]
end

local function refreshBackgroundHoverHint(self, frame)
    if not AddonNS.DragAndDrop:IsItemDragActive() and not AddonNS.DragAndDrop:IsCategoryDragActive() then
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
        return
    end
    local scope = frame.MyBagsScope or self.currentScope
    local hintFrame = getBackgroundHintFrame(self, frame, scope)
    if not hintFrame then
        hintFrame = getBackgroundColumnFallbackHintFrame(self, frame, scope)
    end
    if hintFrame and hintFrame:IsShown() then
        AddonNS.gui:SetHoveredCategoryFrame(hintFrame)
        return
    end
    AddonNS.gui:ClearHoveredCategoryFrame(frame)
end

local function handleBackgroundDrop(self, frame, mouseButtonName)
    if mouseButtonName and mouseButtonName ~= "LeftButton" then
        return
    end
    if AddonNS.DragAndDrop:IsItemDragActive() or AddonNS.DragAndDrop:IsCategoryDragActive() then
        local scope = frame.MyBagsScope or self.currentScope
        local hintFrame = getBackgroundHintFrame(self, frame, scope)
        if hintFrame and hintFrame:IsShown() then
            AddonNS.DragAndDrop.categoryOnReceiveDrag(hintFrame)
            return
        end
    end
    AddonNS.DragAndDrop.backgroundOnReceiveDrag(frame, mouseButtonName)
end

local function ensureBackground(self, parentFrame)
    if self.backgroundFrame then
        return
    end

    local backgroundFrame = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    backgroundFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, 0)
    backgroundFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0)
    backgroundFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    backgroundFrame:SetBackdropColor(0, 0, 0, 0)
    backgroundFrame:EnableMouse(true)
    backgroundFrame:SetScript("OnEnter", function(frame)
        refreshBackgroundHoverHint(self, frame)
    end)
    backgroundFrame:SetScript("OnLeave", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    backgroundFrame:SetScript("OnUpdate", function(frame)
        refreshBackgroundHoverHint(self, frame)
    end)
    backgroundFrame:HookScript("OnHide", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    backgroundFrame:SetScript("OnReceiveDrag", function(frame)
        handleBackgroundDrop(self, frame)
    end)
    backgroundFrame:SetScript("OnMouseUp", function(frame, mouseButtonName)
        handleBackgroundDrop(self, frame, mouseButtonName)
    end)
    backgroundFrame.myBagAddonHooked = true

    self.backgroundFrame = backgroundFrame
end

local function ensureContentArea(self, panel)
    if self.contentFrame then
        return
    end

    local contentFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", BANK_VIEWPORT_LEFT, BANK_VIEWPORT_TOP)
    contentFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", BANK_VIEWPORT_RIGHT, BANK_VIEWPORT_BOTTOM)
    contentFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    contentFrame:SetBackdropColor(0.02, 0.02, 0.02, 0.82)
    contentFrame:EnableMouse(false)
    contentFrame:SetClipsChildren(false)

    self.contentFrame = contentFrame
    self.dropAreaOverlays = self.dropAreaOverlays or {}
end

local function ensureHeaderFrame(bankView, index)
    if bankView.headerFrames[index] then
        return bankView.headerFrames[index]
    end

    local headerFrame = CreateFrame("Frame", nil, bankView.backgroundFrame, "BackdropTemplate")
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
        local scope = selfButton:GetParent().MyBagsScope or BANK_CHARACTER_SCOPE
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
        local scope = parent.MyBagsScope or BANK_CHARACTER_SCOPE
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
            AddonNS.gui:StyleCategoryControl(frame, true)
        end
        AddonNS.gui:SetHoveredCategoryFrame(frame)
    end)
    headerFrame:SetScript("OnLeave", function(frame)
        if frame.isAddCategoryControl then
            AddonNS.gui:StyleCategoryControl(frame, false)
        end
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    headerFrame:HookScript("OnHide", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    headerFrame:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
    headerFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)
    headerFrame:SetScript("OnDragStart", function(frame)
        AddonNS.gui:StartCategoryDragVisual(frame.ItemCategory:GetDisplayName() or "Unassigned")
        AddonNS.DragAndDrop.categoryStartDrag(frame)
        PlaySound(1183)
    end)
    headerFrame:SetScript("OnDragStop", function()
        AddonNS.gui:StopCategoryDragVisual()
        PlaySound(1200)
    end)
    function headerFrame.SetText(_, text)
        label:SetText(text)
    end

    function headerFrame.ApplyCategoryTextLayout(_)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
        label:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -ITEM_SPACING / 2, -ITEM_SPACING / 2)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetFontObject("GameFontNormal")
    end

    function headerFrame.ApplyCategoryTextLayoutWithEditButton(_)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
        label:SetPoint("TOPRIGHT", editButton, "TOPLEFT", -4, -ITEM_SPACING / 2)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetFontObject("GameFontNormal")
    end

    function headerFrame.ApplyCategoryTextLayoutWithEditAndDeleteButtons(_)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
        label:SetPoint("TOPRIGHT", scopeVisibilityButton, "TOPLEFT", -4, -ITEM_SPACING / 2)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetFontObject("GameFontNormal")
    end

    function headerFrame.ApplyCategoryTextLayoutWithScopeAndEditButtons(_)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
        label:SetPoint("TOPRIGHT", scopeVisibilityButton, "TOPLEFT", -4, -ITEM_SPACING / 2)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetFontObject("GameFontNormal")
    end

    function headerFrame.ApplyAddControlTextLayout(_)
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
    AddonNS.gui:EnsureCategoryControlBackdrop(headerFrame)
    bankView.headerFrames[index] = headerFrame
    return headerFrame
end

local function ensureDropFrame(self, index)
    if self.dropFrames[index] then
        return self.dropFrames[index]
    end

    local dropFrame = CreateFrame("Frame", nil, self.backgroundFrame, "BackdropTemplate")
    local dropFrameLevel = self.backgroundFrame:GetFrameLevel() - 1
    if dropFrameLevel < 0 then
        dropFrameLevel = 0
    end
    dropFrame:SetFrameLevel(dropFrameLevel)

    local hintOverlay = CreateFrame("Frame", nil, dropFrame, "BackdropTemplate")
    hintOverlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    hintOverlay:SetAllPoints(dropFrame)
    hintOverlay:EnableMouse(false)
    hintOverlay:Hide()

    dropFrame:EnableMouse(true)
    dropFrame:SetScript("OnEnter", function(frame)
        AddonNS.gui:SetHoveredCategoryFrame(frame)
    end)
    dropFrame:SetScript("OnLeave", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    dropFrame:HookScript("OnHide", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    dropFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)
    dropFrame:SetScript("OnMouseUp", function(frame, button)
        if button == "LeftButton" and GetCursorInfo() then
            AddonNS.DragAndDrop.categoryOnReceiveDrag(frame)
        end
    end)

    dropFrame.hintOverlay = hintOverlay
    self.dropFrames[index] = dropFrame
    return dropFrame
end

local function placeItemsAndBuildHeaders(scope, categoryAssignments, itemSize)
    local categoryPositions = {}
    local positions = {}
    local columnsBottom = {}
    local leftPadding = BANK_CONTENT_LEFT_PADDING
    local firstRowY = BANK_CONTENT_FIRST_ROW_Y
    local columnPixelWidth = itemSize * ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
    local isCategoriesConfigMode = AddonNS.BagViewState:IsCategoriesConfigMode()

    local function placeColumn(columnIndex, categories)
        local columnStartX = leftPadding + (columnIndex - 1) * columnPixelWidth
        local currentRow = {}
        local currentRowY = firstRowY
        local rowWithNewCategory = false

        local function flushCurrentRow()
            local xOffset = 0
            for rowIndex = 1, #currentRow do
                local itemButton = currentRow[rowIndex]
                if itemButton ~= AddonNS.itemButtonPlaceholder then
                    positions[itemButton] = {
                        x = columnStartX + xOffset,
                        y = currentRowY,
                    }
                end
                xOffset = xOffset + itemSize
            end
            currentRow = {}
            currentRowY = currentRowY + itemSize
            rowWithNewCategory = false
        end

        for index, categoryObj in ipairs(categories) do
            local category = categoryObj.category
            local items = categoryObj.items
            local itemsCount = categoryObj.itemsCount or #items
            local collapsed = AddonNS.Collapsed.isCollapsed(category, scope)
            local isHeaderOnly = collapsed or itemsCount == 0
            local categoryRequiresNewLine = isCategoriesConfigMode or isHeaderOnly or category.separateLine
            local categoryRequiresFullRowWidth = isCategoriesConfigMode or isHeaderOnly
            local requiredNewLine =
                categoryRequiresNewLine
                or #currentRow == 0
                or (#currentRow > 0 and ((rowWithNewCategory and #currentRow + itemsCount > ITEMS_PER_ROW) or not rowWithNewCategory))

            if index == 1 then
                currentRowY = currentRowY + CATEGORY_HEIGHT
            elseif requiredNewLine then
                if #currentRow > 0 then
                    flushCurrentRow()
                end
                currentRowY = currentRowY + CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING
            end

            local nextCategoryObj = categories[index + 1]
            local nextCategoryExists = nextCategoryObj ~= nil
            local expandCategoryToRightColumnBoundary = 0
            if not categoryRequiresFullRowWidth and #currentRow + itemsCount < ITEMS_PER_ROW then
                local nextCategoryItemsCount = 0
                if nextCategoryExists then
                    nextCategoryItemsCount = nextCategoryObj.itemsCount or #(nextCategoryObj.items)
                end
                local shouldExpandToBoundary =
                    (not nextCategoryExists)
                    or AddonNS.Collapsed.isCollapsed(nextCategoryObj.category, scope)
                    or nextCategoryItemsCount == 0
                    or nextCategoryObj.category.separateLine
                    or #currentRow + itemsCount + nextCategoryItemsCount > ITEMS_PER_ROW
                if shouldExpandToBoundary then
                    expandCategoryToRightColumnBoundary = ITEMS_PER_ROW - #currentRow - itemsCount
                end
            end

            local categoryWidthSlots = ITEMS_PER_ROW
            if not categoryRequiresFullRowWidth then
                categoryWidthSlots = math.min(ITEMS_PER_ROW, itemsCount + expandCategoryToRightColumnBoundary)
            end
            table.insert(categoryPositions, {
                category = category,
                itemsCount = itemsCount,
                x = columnStartX + itemSize * #currentRow - ITEM_SPACING / 2,
                y = currentRowY - CATEGORY_HEIGHT,
                width = itemSize * categoryWidthSlots,
                height = CATEGORY_HEIGHT,
                blockHeight = CATEGORY_HEIGHT +
                ((not isHeaderOnly and math.ceil(itemsCount / ITEMS_PER_ROW) * itemSize) or 0),
                scope = scope,
            })

            rowWithNewCategory = true
            if not isHeaderOnly then
                for itemIndex = #items, 1, -1 do
                    local itemButton = items[itemIndex]
                    table.insert(currentRow, itemButton)
                    if #currentRow >= ITEMS_PER_ROW then
                        flushCurrentRow()
                    end
                end
            end
        end

        if #currentRow > 0 then
            flushCurrentRow()
        end

        columnsBottom[columnIndex] = currentRowY
    end

    for columnIndex, categories in ipairs(categoryAssignments) do
        placeColumn(columnIndex, categories)
    end

    local contentBottom = 0
    for index = 1, #columnsBottom do
        if columnsBottom[index] > contentBottom then
            contentBottom = columnsBottom[index]
        end
    end

    if AddonNS.BagViewState:IsCategoriesConfigMode() then
        local lastColumnIndex = math.max(1, #categoryAssignments)
        local columnBottomY = columnsBottom[lastColumnIndex] or firstRowY
        local addControlY = columnBottomY + AddonNS.Const.COLUMN_SPACING
        local controlHeight = AddonNS.Const.CATEGORY_HEIGHT
        local controlSpacing = AddonNS.Const.COLUMN_SPACING
        local controlX = leftPadding + (lastColumnIndex - 1) * columnPixelWidth - ITEM_SPACING / 2
        local controlWidth = itemSize * ITEMS_PER_ROW

        table.insert(categoryPositions, {
            isAddCategoryControl = true,
            scope = scope,
            x = controlX,
            y = addControlY,
            width = controlWidth,
            height = controlHeight,
            blockHeight = controlHeight,
        })
        table.insert(categoryPositions, {
            isExportCategoryControl = true,
            scope = scope,
            x = controlX,
            y = addControlY + controlHeight + controlSpacing,
            width = controlWidth,
            height = controlHeight,
            blockHeight = controlHeight,
        })
        table.insert(categoryPositions, {
            isImportCategoryControl = true,
            scope = scope,
            x = controlX,
            y = addControlY + (controlHeight + controlSpacing) * 2,
            width = controlWidth,
            height = controlHeight,
            blockHeight = controlHeight,
        })

        local addControlBottomY = addControlY + (controlHeight + controlSpacing) * 2 + controlHeight
        if addControlBottomY > contentBottom then
            contentBottom = addControlBottomY
        end
    end

    return positions, categoryPositions, contentBottom
end

function BankView:ResolveDropColumn(relativeX, scope, frameWidth)
    local columnCount = AddonNS.CategoryStore:GetColumnCount(scope)
    if columnCount <= 0 then
        return nil
    end

    local columnPixelWidth = self.columnPixelWidth
    local firstColumnStartX = self.firstColumnStartX
    if not columnPixelWidth or not firstColumnStartX or columnPixelWidth <= 0 then
        local fallback = math.floor(relativeX * columnCount / frameWidth) + 1
        if fallback < 1 then
            fallback = 1
        elseif fallback > columnCount then
            fallback = columnCount
        end
        return fallback
    end

    local resolved = math.floor((relativeX - firstColumnStartX) / columnPixelWidth) + 1
    if resolved < 1 then
        return 1
    end
    if resolved > columnCount then
        return columnCount
    end
    return resolved
end

local function applyItemPositions(panel, parentFrame, positions)
    for itemButton, position in pairs(positions) do
        if itemButton:GetParent() ~= parentFrame then
            itemButton:SetParent(parentFrame)
        end
        itemButton:ClearAllPoints()
        itemButton:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", position.x, -position.y)
        itemButton:Show()
    end

    for itemButton in panel:EnumerateValidItems() do
        if not positions[itemButton] then
            itemButton:Hide()
        end
    end
end

local function renderHeaders(self, scope, panel, categoryPositions)
    self.backgroundFrame.MyBagsScope = scope
    local customCategories = AddonNS.CustomCategories:GetCategories()
    local dropFrameByCategoryId = {}

    for index = 1, #categoryPositions do
        local categoryPosition = categoryPositions[index]
        local frame = ensureHeaderFrame(self, index)
        local dropFrame = ensureDropFrame(self, index)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.backgroundFrame, "TOPLEFT", categoryPosition.x, -categoryPosition.y)
        frame:SetSize(categoryPosition.width, CATEGORY_HEIGHT)
        frame.MyBagsScope = scope
        frame.MyBagsContainerRef = panel
        frame.MyBagsHintAnchorFrame = self.backgroundFrame
        frame.MyBagsHintAlignToFrame = true

        if categoryPosition.isAddCategoryControl or categoryPosition.isExportCategoryControl or categoryPosition.isImportCategoryControl then
            frame.ItemCategory = nil
            frame.isAddCategoryControl = true
            frame.editButton:Hide()
            frame.deleteButton:Hide()
            frame.scopeVisibilityButton:Hide()
            frame:RegisterForDrag("LeftButton")
            frame:SetScript("OnReceiveDrag", nil)
            frame:SetScript("OnDragStart", nil)
            frame:SetScript("OnDragStop", nil)
            frame:SetScript("OnMouseUp", function(_, button)
                if button ~= "LeftButton" then
                    return
                end
                if categoryPosition.isAddCategoryControl then
                    StaticPopup_Show("CREATE_CATEGORY_CONFIRM")
                    return
                end
                if categoryPosition.isExportCategoryControl then
                    AddonNS.CategoriesGUI:ToggleExportFrame()
                    return
                end
                AddonNS.CategoriesGUI:ToggleImportFrame()
            end)
            if categoryPosition.isExportCategoryControl then
                frame.controlKind = "export"
            elseif categoryPosition.isImportCategoryControl then
                frame.controlKind = "import"
            else
                frame.controlKind = "add"
            end
            frame.addControlBackdrop:Show()
            frame:ApplyAddControlTextLayout()
            AddonNS.gui:StyleCategoryControl(frame, false)
            frame:Show()
            dropFrame:Hide()
        else
            frame.ItemCategory = categoryPosition.category
            frame.isAddCategoryControl = false
            frame.controlKind = nil
            frame.addControlBackdrop:Hide()
            frame:RegisterForDrag("LeftButton")
            frame:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
            frame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)
            frame:SetScript("OnDragStart", function(headerFrame)
                AddonNS.gui:StartCategoryDragVisual(headerFrame.ItemCategory:GetDisplayName() or "Unassigned")
                AddonNS.DragAndDrop.categoryStartDrag(headerFrame)
                PlaySound(1183)
            end)
            frame:SetScript("OnDragStop", function()
                AddonNS.gui:StopCategoryDragVisual()
                PlaySound(1200)
            end)

            local categoryId = categoryPosition.category:GetId()
            local canEditCategory = AddonNS.BagViewState:IsCategoriesConfigMode() and customCategories[categoryId] ~= nil
            local canToggleScopeVisibility = canEditCategory
            local canDeleteCategory = canEditCategory and not categoryPosition.category:IsProtected()
            frame.editButton:SetShown(canEditCategory)
            frame.scopeVisibilityButton:SetShown(canToggleScopeVisibility)
            frame.deleteButton:SetShown(canDeleteCategory)
            if canToggleScopeVisibility then
                local visible = AddonNS.CustomCategories:IsVisibleInScope(categoryPosition.category, scope)
                local texture = visible and CATEGORY_VISIBLE_TEXTURE or CATEGORY_HIDDEN_TEXTURE
                frame.scopeVisibilityButton.Icon:SetTexture(texture)
                frame.scopeVisibilityButton.Highlight:SetTexture(texture)
            end

            if canToggleScopeVisibility and canDeleteCategory then
                frame:ApplyCategoryTextLayoutWithEditAndDeleteButtons()
            elseif canToggleScopeVisibility then
                frame:ApplyCategoryTextLayoutWithScopeAndEditButtons()
            elseif canEditCategory then
                frame:ApplyCategoryTextLayoutWithEditButton()
            else
                frame:ApplyCategoryTextLayout()
            end

            dropFrame.ItemCategory = categoryPosition.category
            dropFrame.fs = frame.fs
            dropFrame.MyBagsScope = scope
            dropFrame.MyBagsContainerRef = panel
            dropFrame.MyBagsHintAnchorFrame = self.backgroundFrame
            dropFrame.MyBagsHintAlignToFrame = true
            dropFrame:ClearAllPoints()
            dropFrame:SetPoint("TOPLEFT", self.backgroundFrame, "TOPLEFT", categoryPosition.x, -categoryPosition.y)
            dropFrame:SetSize(categoryPosition.width, categoryPosition.blockHeight)
            dropFrame:Show()
            dropFrameByCategoryId[categoryId] = dropFrame

            local label = categoryPosition.category:GetDisplayName(categoryPosition.itemsCount) or
            categoryPosition.category:GetName()
            if AddonNS.Collapsed.isCollapsed(categoryPosition.category, scope) then
                label = label ..
                " (" .. categoryPosition.itemsCount .. ") |A:glues-characterSelect-icon-arrowDown:19:19:0:4|a"
            end
            frame:SetText(label)
            frame:Show()
        end
    end

    for index = #categoryPositions + 1, #self.headerFrames do
        self.headerFrames[index]:Hide()
    end
    for index = #categoryPositions + 1, #self.dropFrames do
        self.dropFrames[index]:Hide()
    end
    self.dropFrameByCategoryId = dropFrameByCategoryId
end

function BankView:Refresh(scope)
    local panel = getActiveBankPanel()
    if not BankFrame:IsShown() or not panel:IsShown() then
        hideHeaders(self)
        hideContentArea(self)
        hideEditModeButton(self)
        hideSearchHelpButton(self)
        hideSearchScopeDisabledCheckbox(self)
        hideBottomBarControls(self)
        if self.resizeController then
            self.resizeController:Refresh()
        end
        return
    end

    refreshSearchBoxLayout()
    showSearchHelpButton(self)
    showSearchScopeDisabledCheckbox(self, panel)
    local activeBankType = BankFrame:GetActiveBankType()
    local activeScope = scope or getScopeForBankType(activeBankType)
    local tabIds = getPurchasedTabIdsForActiveType(panel)
    self.visibleTabIds = buildVisibleTabIds(tabIds)
    self.currentScope = activeScope
    AddonNS:SetCurrentLayoutScope(activeScope)

    ensureContentArea(self, panel)
    panel.Header:Hide()
    self.contentFrame.MyBagsScope = activeScope
    ensureBackground(self, self.contentFrame)
    hideBlizzardBankTabs(panel)
    showEditModeButton(self, panel)
    refreshBottomBar(self, panel, activeBankType, tabIds)
    self.contentFrame:Show()
    self.backgroundFrame:Show()
    refreshResizeHandle(self, panel)
    updateDropAreaOverlays(self, activeScope)
    local itemButtonsSignature = buildItemButtonsSignature(activeBankType, tabIds)
    local expectedButtons = countExpectedButtonsForTabs(tabIds)
    local shouldRegenerateButtons =
        self.itemButtonsSignature ~= itemButtonsSignature
        or not hasAnyActiveItemButtons(panel)
        or countActiveItemButtons(panel) ~= expectedButtons
    if shouldRegenerateButtons then
        generateAllTabItemButtons(panel, activeBankType, tabIds) --TODO: BANK_TAINT
        self.itemButtonsSignature = itemButtonsSignature
    end
    local searchText = BankItemSearchBox:GetText() or ""
    local searchActive = searchText ~= ""
    local searchTextChanged = self.lastSearchText ~= searchText
    self.lastSearchText = searchText
    updateSearchSizeLock(self, panel, searchText)
    local searchEvaluator = AddonNS.QueryCategories:CompileAdHoc(searchText)
    local shouldRefreshItemButtonVisuals = shouldRegenerateButtons or not searchTextChanged

    local arrangedItems = {}
    local firstItemButton = nil
    local hadAnyButtons = false
    local hadAnyItemData = false

    AddonNS.emptyItemButton = nil
    for itemButton in panel:EnumerateValidItems() do
        hadAnyButtons = true
        ensureItemButtonBagMethods(itemButton)
        ensureItemButtonHooks(itemButton)
        if shouldRefreshItemButtonVisuals then
            itemButton:Refresh() --TODO: BANK_TAINT
        end
        itemButton.MyBagsScope = activeScope
        setMyBagsIncludeInSearch(itemButton, false)

        itemButton.ItemCategory = nil
        local bagID, slotID = resolveBankButtonContainerSlot(itemButton)
        if bagID and slotID then
            local info = containerItemInfoCache:Get(bagID, slotID)
            if info then
                hadAnyItemData = true
                local cachedDefaultMatch = itemButton._myBagsDefaultSearchMatch
                local defaultMatch = true
                if searchActive and type(cachedDefaultMatch) == "boolean" then
                    defaultMatch = cachedDefaultMatch
                elseif searchActive then
                    defaultMatch = not info.isFiltered
                end
                local includeInSearch = evaluateSearchVisibility(defaultMatch, searchEvaluator, info, itemButton)
                itemButton._myBagsItemId = info.itemID
                local category = nil
                if searchActive then
                    category = resolveCachedOrComputeCategory(self, itemButton, info, activeScope)
                    itemButton.ItemCategory = category
                    AddonNS.SearchCategoryBaseline:Add(arrangedItems, category, itemButton, false, true)
                end
                if includeInSearch then
                    setMyBagsIncludeInSearch(itemButton, true)
                    if not category then
                        category = resolveCachedOrComputeCategory(self, itemButton, info, activeScope)
                    end
                    itemButton.ItemCategory = category
                    AddonNS.SearchCategoryBaseline:Add(arrangedItems, category, itemButton, true, searchActive)
                    firstItemButton = firstItemButton or itemButton
                else
                    AddonNS.emptyItemButton = itemButton
                end
            else
                AddonNS.emptyItemButton = itemButton
            end
        end
    end

    if not firstItemButton then
        if shouldRetryForMissingItemData(hadAnyButtons, hadAnyItemData, self.dataRetryCount) then
            self.dataRetryCount = self.dataRetryCount + 1
            self:QueueRefresh(activeScope)
            hideHeaders(self)
            hideAllItemButtons(panel)
            return
        end
    end
    self.dataRetryCount = 0

    local itemSize = firstItemButton and (firstItemButton:GetHeight() + ITEM_SPACING) or getCurrentItemSize(panel)
    self.columnPixelWidth = itemSize * ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
    self.firstColumnStartX = BANK_CONTENT_LEFT_PADDING - ITEM_SPACING / 2
    local categoryAssignments = AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems, activeScope)
    local positions, categoryPositions, contentBottom = placeItemsAndBuildHeaders(activeScope, categoryAssignments,
        itemSize)

    updateFrameSizeForContent(self, panel, contentBottom)
    refreshResizeHandle(self, panel)
    updateDropAreaOverlays(self, activeScope)
    applyItemPositions(panel, self.backgroundFrame, positions)
    renderHeaders(self, activeScope, panel, categoryPositions)
end

function BankView:QueueRefresh(scope)
    if self.refreshQueued then
        return
    end
    self.refreshQueued = true
    RunNextFrame(function()
        self.refreshQueued = false
        self:Refresh(scope)
    end)
end

function BankView:GetCurrentScope()
    return self.currentScope
end

function BankView:RefreshNow(scope)
    self.refreshQueued = false
    self:Refresh(scope)
end

local function tryInstallHooks()
    if BankView.hooksInstalled then
        return true
    end
    if not BankPanel or not BankFrame then
        return false
    end

    BankFrame:HookScript("OnShow", function()
        BankView.needsInitialPositionUpdate = true
        BankView.initialPositionUpdateQueued = false
        BankView:RefreshNow()
    end)
    BankFrame:HookScript("OnHide", function()
        hideHeaders(BankView)
        hideContentArea(BankView)
        hideDropAreaOverlays(BankView)
        hideEditModeButton(BankView)
        hideSearchHelpButton(BankView)
        hideSearchScopeDisabledCheckbox(BankView)
        AddonNS.CategoriesGUI:HideQueryHelpFrame()
        hideBottomBarControls(BankView)
        if BankView.resizeController then
            BankView.resizeController:Stop()
            BankView.resizeController:Refresh()
        end
        if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
            AddonNS:SetCurrentLayoutScope("bag")
        end
        BankView.searchSizeLockActive = false
        BankView.searchLockedPanelWidth = nil
        BankView.searchLockedPanelHeight = nil
        BankView.searchUnlockPending = false
        BankView.lastSearchText = nil
        containerItemInfoCache:InvalidateAll()
        invalidateCategorizationCacheVersion(BankView)
        BankView.needsInitialPositionUpdate = false
        BankView.initialPositionUpdateQueued = false
    end)

    hooksecurefunc(BankPanel, "RefreshBankPanel", function()
        BankView:QueueRefresh()
    end)
    hooksecurefunc(BankPanel, "SelectTab", function()
        BankView:RefreshNow()
    end)
    hooksecurefunc(BankPanel, "GenerateItemSlotsForSelectedTab", function()
        for itemButton in BankPanel:EnumerateValidItems() do
            itemButton:Hide()
        end
        BankView:RefreshNow()
    end)
    hooksecurefunc(BankPanel, "UpdateSearchResults", function()
        applyCachedIncludeInSearch(BankPanel)
    end)
    hooksecurefunc(BankPanel, "Clean", function()
        BankView:QueueRefresh()
    end)

    AddonNS.Events:RegisterEvent("BAG_UPDATE", function(_, bagID)
        if not BankFrame:IsShown() then
            return
        end
        if shouldRefreshForBagUpdate(BankView.visibleTabIds, bagID) then
            if bagID == nil then
                containerItemInfoCache:InvalidateAll()
            else
                containerItemInfoCache:InvalidateBag(bagID)
            end
            invalidateCategorizationCacheVersion(BankView)
            BankView:QueueRefresh()
        end
    end)

    AddonNS.Events:RegisterEvent("INVENTORY_SEARCH_UPDATE", function()
        if BankFrame:IsShown() then
            BankView:QueueRefresh(BankView.currentScope)
        end
    end)

    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.COLLAPSED_CHANGED, function(_, _, scope)
        if scope == BANK_CHARACTER_SCOPE or scope == BANK_ACCOUNT_SCOPE then
            BankView:QueueRefresh(scope)
        end
    end)

    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, function()
        if BankFrame:IsShown() then
            invalidateCategorizationCacheVersion(BankView)
            BankView:QueueRefresh(BankView.currentScope)
        end
    end)

    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.ITEM_MOVED, function()
        containerItemInfoCache:InvalidateAll()
        invalidateCategorizationCacheVersion(BankView)
    end)

    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, function()
        if BankFrame:IsShown() then
            BankView:QueueRefresh(BankView.currentScope)
        end
    end)
    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.SCOPE_DISABLED_CONFIG_VISIBILITY_CHANGED, function()
        if BankFrame:IsShown() then
            BankView:RefreshNow(BankView.currentScope)
        end
    end)

    AddonNS.Events:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if BankView.resizeController then
            BankView.resizeController:Stop()
            BankView.resizeController:Refresh()
        end
    end)

    AddonNS.Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if BankView.resizeController then
            BankView.resizeController:Refresh()
        end
    end)

    BankView.hooksInstalled = true
    return true
end

AddonNS.BankView = BankView
AddonNS.BankViewTestHooks = {
    GetPurchasedTabIdsForActiveType = getPurchasedTabIdsForActiveType,
    BuildVisibleTabIds = buildVisibleTabIds,
    ShouldRefreshForBagUpdate = shouldRefreshForBagUpdate,
    GenerateAllTabItemButtons = generateAllTabItemButtons,
    BuildItemButtonsSignature = buildItemButtonsSignature,
    ApplyCachedIncludeInSearch = applyCachedIncludeInSearch,
    HasAnyActiveItemButtons = hasAnyActiveItemButtons,
    CountActiveItemButtons = countActiveItemButtons,
    CountExpectedButtonsForTabs = countExpectedButtonsForTabs,
    ShouldShowPurchaseTabButton = shouldShowPurchaseTabButton,
    GetBankCapacityState = function(tabIds)
        return AddonNS.GetBankCapacityState(tabIds)
    end,
    EvaluateSearchVisibility = evaluateSearchVisibility,
    ShouldRetryForMissingItemData = shouldRetryForMissingItemData,
    ApplySearchUnionMatchState = applySearchUnionMatchState,
    ApplyBankScopeColumnCount = applyBankScopeColumnCount,
    ResolveTargetPanelSize = resolveTargetPanelSize,
    CalculateScaledDepositButtonWidth = calculateScaledDepositButtonWidth,
    ShouldShowBankResizeHandle = shouldShowBankResizeHandle,
    PlaceItemsAndBuildHeaders = function(scope, panel, categoryAssignments, itemSize)
        return placeItemsAndBuildHeaders(scope, categoryAssignments, itemSize)
    end,
    GetBackgroundHintFrame = getBackgroundHintFrame,
    GetBackgroundColumnFallbackHintFrame = getBackgroundColumnFallbackHintFrame,
}

AddonNS.Events:OnInitialize(function()
    tryInstallHooks()
    if BankFrame_Open then
        hooksecurefunc("BankFrame_Open", function()
            tryInstallHooks()
            BankView:RefreshNow()
        end)
    end
    AddonNS.Events:RegisterEvent("BANKFRAME_OPENED", function()
        tryInstallHooks()
        BankView:RefreshNow()
    end)
end)
