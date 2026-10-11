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
    dropFrameByCategoryId = {},
    currentScope = BANK_CHARACTER_SCOPE,
    visibleTabIds = {},
    refreshQueued = false,
    hooksInstalled = false,
    dataRetryCount = 0,
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
local CAPACITY_LABEL_FORMAT = "%d/%d"
local BANK_DEFAULT_ITEM_SIZE = 41
local BANK_RESIZE_HANDLE_SIZE = 16
local BANK_MIN_NUM_COLUMNS = 5
local BANK_MAX_NUM_COLUMNS = 10
local AUTO_DEPOSIT_BUTTON_WIDTH_SCALE = 0.7
local calculateScaledDepositButtonWidth
local applyScaledDepositButtonWidth


local itemButtonPool = CreateFramePool("ItemButton", nil, "BankItemButtonTemplate");

local function mergeIterators(iter1, state1, init1, iter2, state2, init2)
    local currentIter = iter1
    local currentState = state1
    local currentVar = init1
    local usingFirst = true

    return function()
        local value = currentIter(currentState, currentVar)
        currentVar = value

        if value ~= nil then
            return value
        end

        if usingFirst then
            usingFirst = false
            currentIter = iter2
            currentState = state2
            currentVar = init2

            value = currentIter(currentState, currentVar)
            currentVar = value

            return value
        end

        return nil
    end
end

local myEnumerateValidItemsFunction;
local function myEnumerateValidItems()
    -- if (myEnumerateValidItemsFunction == nil) then
    local iter1, state1, init1 = BankPanel.itemButtonPool:EnumerateActive();
    local iter2, state2, init2 = itemButtonPool:EnumerateActive();
    myEnumerateValidItemsFunction = mergeIterators(iter1, state1, init1, iter2, state2, init2);
    -- end
    return myEnumerateValidItemsFunction;
end

local function getScopeForBankType(bankType)
    if bankType == Enum.BankType.Account then
        return BANK_ACCOUNT_SCOPE
    end
    return BANK_CHARACTER_SCOPE
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

local function generateAllTabItemButtons(panel, tabIds)
    itemButtonPool:ReleaseAll()
    for tabIndex = 1, #tabIds do
        local tabID = tabIds[tabIndex]
        if (tabID ~= panel.selectedTabID) then
            local slots = C_Container.GetContainerNumSlots(tabID)
            for containerSlotID = 1, slots do
                local button = itemButtonPool:Acquire()
                button:Init(panel.bankType, tabID, containerSlotID)
                button:Show()
            end
        end
    end
end

local function applyCachedIncludeInSearch(panel)
    for itemButton in itemButtonPool:EnumerateActive() do
        local itemInfo = C_Container.GetContainerItemInfo(itemButton:GetBankTabID(), itemButton:GetContainerSlotID());
        local isFiltered = itemInfo and itemInfo.isFiltered;
        itemButton:SetMatchesSearch(not isFiltered);
    end

    for itemButton in myEnumerateValidItems() do
        local defaultMatch = itemButton:GetMatchesSearch()
        if type(defaultMatch) == "boolean" then
            itemButton._myBagsDefaultSearchMatch = defaultMatch
        end
        AddonNS.ItemButtonSearchOverlay:Apply(itemButton, true)
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

local function showControls(self, panel)
    if not self.controls then
        self.controls = AddonNS.ContainerControls:Create(panel, BankFrame, BankItemSearchBox, BankFrame, "right")
        self.controls.editButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -9, -34)
    end
    self.controls:Refresh()
    panel.AutoSortButton:Hide()
    self.controls.editButton:Show()
    self.controls.helpButton:Show()
end

local function hideControls(self)
    if self.controls then
        self.controls:Hide()
    end
end

local function ensureItemButtonHooks(itemButton)
    if not AddonNS.DragAndDrop:HookItemButton(itemButton) then
        return
    end
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
    for itemButton in myEnumerateValidItems() do
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
    for itemButton in myEnumerateValidItems() do
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

local function shouldRetryForMissingItemData(hasAnyButtons, hadAnyItemData, retryCount)
    return hasAnyButtons and (not hadAnyItemData) and retryCount < 6
end

local function invalidateCategorizationCacheVersion(self)
    self.categorizationVersion = self.categorizationVersion + 1
end


local function ensureDropAreaOverlay(self, index)
    if self.dropAreaOverlays[index] then
        return self.dropAreaOverlays[index]
    end

    local overlay = CreateFrame("Frame", nil, self.contentFrame, "BackdropTemplate")
    overlay:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile =
        "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10
    })
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
    AddonNS.CategoryBackground:Install(backgroundFrame, {
        GetCategoryFrames = function()
            return self.dropFrames
        end,
        GetCategoryFrame = function(category)
            return self.dropFrameByCategoryId[category:GetId()]
        end,
        ResolveDropColumn = function(relativeX, scope, width)
            return self:ResolveDropColumn(relativeX, scope, width)
        end,
    })

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
    if not bankView.headerFrames[index] then
        bankView.headerFrames[index] = AddonNS.CategoryFrame:Create(bankView.backgroundFrame)
    end
    return bankView.headerFrames[index]
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
        AddonNS.CategoryBackground:ReceiveCategoryMouseUp(frame, button)
    end)

    dropFrame.hintOverlay = hintOverlay
    self.dropFrames[index] = dropFrame
    return dropFrame
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

    for itemButton in myEnumerateValidItems() do
        if not positions[itemButton] then
            itemButton:Hide()
        end
    end
end

local function renderHeaders(self, scope, panel, categoryPositions)
    self.backgroundFrame.MyBagsScope = scope
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

        AddonNS.CategoryFrame:Configure(frame, categoryPosition, scope)
        if frame.isAddCategoryControl then
            dropFrame:Hide()
        else
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
            dropFrameByCategoryId[categoryPosition.category:GetId()] = dropFrame
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
        hideControls(self)
        hideBottomBarControls(self)
        if self.resizeController then
            self.resizeController:Refresh()
        end
        return
    end

    refreshSearchBoxLayout()
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
    showControls(self, panel)
    refreshBottomBar(self, panel, activeBankType, tabIds)
    self.contentFrame:Show()
    self.backgroundFrame:Show()
    refreshResizeHandle(self, panel)
    updateDropAreaOverlays(self, activeScope)
    local searchText = BankItemSearchBox:GetText() or ""
    local searchActive = searchText ~= ""
    self.lastSearchText = searchText
    updateSearchSizeLock(self, panel, searchText)
    local searchEvaluator = AddonNS.QueryCategories:CompileAdHoc(searchText)

    local arrangedItems = {}
    local firstItemButton = nil
    local hadAnyButtons = false
    local hadAnyItemData = false

    AddonNS.emptyItemButton = nil
    for itemButton in myEnumerateValidItems() do
        hadAnyButtons = true
        ensureItemButtonBagMethods(itemButton)
        ensureItemButtonHooks(itemButton)
        itemButton.MyBagsScope = activeScope
        AddonNS.ItemButtonSearchOverlay:Apply(itemButton, false)

        itemButton.ItemCategory = nil
        local bagID, slotID = resolveBankButtonContainerSlot(itemButton)
        if bagID and slotID then
            local info = containerItemInfoCache:Get(bagID, slotID)
            if info then
                hadAnyItemData = true
                local includeInSearch = AddonNS.ContainerSearch:ResolveIncludeInSearch(itemButton, info, searchActive, searchEvaluator)
                itemButton._myBagsItemId = info.itemID
                local category = nil
                if searchActive then
                    category = AddonNS.ContainerSearch:ResolveCategory(itemButton, info, activeScope, self.categorizationVersion)
                    itemButton.ItemCategory = category
                    AddonNS.SearchCategoryBaseline:Add(arrangedItems, category, itemButton, false, true)
                end
                if includeInSearch then
                    AddonNS.ItemButtonSearchOverlay:Apply(itemButton, true)
                    if not category then
                        category = AddonNS.ContainerSearch:ResolveCategory(itemButton, info, activeScope, self.categorizationVersion)
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
    local positions, categoryPositions, contentBottom = AddonNS.CategoryLayout:Calculate(categoryAssignments, activeScope,
        itemSize, BANK_CONTENT_LEFT_PADDING, BANK_CONTENT_FIRST_ROW_Y, AddonNS.Const.COLUMN_SPACING)

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
        -- BankView:RefreshNow()
    end)
    BankFrame:HookScript("OnHide", function()
        hideHeaders(BankView)
        hideContentArea(BankView)
        hideDropAreaOverlays(BankView)
        hideControls(BankView)
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
        generateAllTabItemButtons(BankPanel, getPurchasedTabIdsForActiveType(BankPanel))
    end)

    hooksecurefunc(BankPanel, "UpdateSearchResults", function()
        applyCachedIncludeInSearch(BankPanel)

        BankView:QueueRefresh(BankView.currentScope)
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
    MergeIterators = mergeIterators,
    GetPurchasedTabIdsForActiveType = getPurchasedTabIdsForActiveType,
    BuildVisibleTabIds = buildVisibleTabIds,
    ShouldRefreshForBagUpdate = shouldRefreshForBagUpdate,
    GenerateAllTabItemButtons = generateAllTabItemButtons,
    ApplyCachedIncludeInSearch = applyCachedIncludeInSearch,
    ShouldShowPurchaseTabButton = shouldShowPurchaseTabButton,
    GetBankCapacityState = function(tabIds)
        return AddonNS.GetBankCapacityState(tabIds)
    end,
    EvaluateSearchVisibility = function(...)
        return AddonNS.ContainerSearch:EvaluateVisibility(...)
    end,
    ResolveIncludeInSearch = function(...)
        return AddonNS.ContainerSearch:ResolveIncludeInSearch(...)
    end,
    ShouldRetryForMissingItemData = shouldRetryForMissingItemData,
    ApplyBankScopeColumnCount = applyBankScopeColumnCount,
    ResolveTargetPanelSize = resolveTargetPanelSize,
    CalculateScaledDepositButtonWidth = calculateScaledDepositButtonWidth,
    ShouldShowBankResizeHandle = shouldShowBankResizeHandle,
    PlaceItemsAndBuildHeaders = function(scope, panel, categoryAssignments, itemSize)
        return AddonNS.CategoryLayout:Calculate(categoryAssignments, scope, itemSize,
            BANK_CONTENT_LEFT_PADDING, BANK_CONTENT_FIRST_ROW_Y, AddonNS.Const.COLUMN_SPACING)
    end,
    GetBackgroundHintFrame = function(view, frame, scope)
        return AddonNS.CategoryBackground:GetHintFrame(frame, view.dropFrames, scope)
    end,
    GetBackgroundColumnFallbackHintFrame = function(view, frame, scope)
        return AddonNS.CategoryBackground:GetColumnHintFrame(frame, scope,
            function(relativeX, activeScope, width)
                return view:ResolveDropColumn(relativeX, activeScope, width)
            end,
            function(category)
                return view.dropFrameByCategoryId[category:GetId()]
            end)
    end,
}

AddonNS.Events:OnInitialize(function()
    tryInstallHooks()
    -- if BankFrame_Open then
    --     hooksecurefunc("BankFrame_Open", function()
    --         -- tryInstallHooks()
    --         BankView:RefreshNow()
    --     end)
    -- end
    -- AddonNS.Events:RegisterEvent("BANKFRAME_OPENED", function()
    --     -- tryInstallHooks()
    --     -- BankView:RefreshNow()
    -- end)
end)
