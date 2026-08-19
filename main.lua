local addonName, AddonNS = ...
local isCollapsed = AddonNS.Collapsed.isCollapsed;

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;
local SEARCH_BOX_MAX_LETTERS = 255
AddonNS.itemButtonPlaceholder = {}

local container = ContainerFrameCombinedBags;
AddonNS.container = container;
local containerItemInfoCache = assert(AddonNS.ContainerItemInfoCache, "ContainerItemInfoCache missing")
local triggerContainerUpdateItemLayout
local bagCategorizationVersion = 0
local bagSearchText = ""
local bagSearchActive = false
local searchQueryState = {
    text = "",
    evaluator = nil,
}

local function invalidateBagCategorizationCacheVersion()
    bagCategorizationVersion = bagCategorizationVersion + 1
end

local function buildBagCategoryCacheKey(itemButton, itemInfo)
    return table.concat({
        tostring(itemButton:GetBagID()),
        tostring(itemButton:GetID()),
        tostring(itemInfo.itemID),
        tostring(itemInfo.stackCount),
        tostring(itemInfo.quality),
        tostring(itemInfo.hyperlink),
        "bag",
        tostring(bagCategorizationVersion),
    }, ":")
end

local function resolveCachedOrComputeBagCategory(itemButton, itemInfo)
    local cacheKey = buildBagCategoryCacheKey(itemButton, itemInfo)
    if itemButton._myBagsCategoryCacheKey == cacheKey and itemButton._myBagsCategoryCacheValue then
        return itemButton._myBagsCategoryCacheValue
    end
    local category = AddonNS.Categories:Categorize(itemInfo.itemID, itemButton)
    itemButton._myBagsCategoryCacheKey = cacheKey
    itemButton._myBagsCategoryCacheValue = category
    return category
end

local function applySharedFrameScales()
    if AddonNS.ApplyContainerFrameScale then
        AddonNS.ApplyContainerFrameScale()
    end
    if BankFrame and BankFrame:IsShown() and AddonNS.ApplyBankFrameScale then
        AddonNS.ApplyBankFrameScale()
    end
end

local function triggerContainerOnTokenWatchChanged()
    if container:IsSearchAnchorLockActive() then
        securecallfunction(container.UpdateTokenTracker, container)
        triggerContainerUpdateItemLayout()
        applySharedFrameScales()
        return
    end
    securecallfunction(container.OnTokenWatchChanged, container);
    applySharedFrameScales()
end

AddonNS.TriggerContainerOnTokenWatchChanged = triggerContainerOnTokenWatchChanged;

triggerContainerUpdateItemLayout = function()
    securecallfunction(container.UpdateItemLayout, container);
end

AddonNS.TriggerContainerUpdateItemLayout = triggerContainerUpdateItemLayout;

local function queueContainerUpdateItemLayout()
    RunNextFrame(function()
        triggerContainerUpdateItemLayout();
        applySharedFrameScales()
    end);
end

AddonNS.QueueContainerUpdateItemLayout = queueContainerUpdateItemLayout;

local function resolveTooltipItemId(owner)
    if owner._myBagsItemId then
        return owner._myBagsItemId
    end
    local bagID = owner.GetBagID and owner:GetBagID() or nil
    local slotID = owner.GetID and owner:GetID() or nil
    if bagID == nil or slotID == nil then
        return nil
    end
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    return info and info.itemID or nil
end

local function resolveTooltipItemFrame(owner)
    local current = owner
    local depth = 0
    while current and depth < 6 do
        if current.GetBagID and current.GetID then
            local bagID = current:GetBagID()
            local slotID = current:GetID()
            if bagID ~= nil and slotID ~= nil then
                return current
            end
        end
        current = current.GetParent and current:GetParent() or nil
        depth = depth + 1
    end
    return nil
end

local function getScopeFromTooltipOwner(owner)
    if owner and owner.MyBagsScope then
        return owner.MyBagsScope
    end
    return "bag"
end

local function formatCategoryReason(itemID, category, reasonKind)
    local categoryId = category:GetId()
    if not categoryId:match("^cus%-") then
        return nil
    end
    if reasonKind == "manual" then
        return "Manual assignment"
    end
    if reasonKind == "query" then
        return "Priority: " .. AddonNS.CustomCategories:GetEffectivePriority(category)
    end
    if AddonNS.CustomCategories:IsManuallyAssignedToCategory(itemID, category) then
        return "Manual assignment"
    end
    return "Priority: " .. AddonNS.CustomCategories:GetEffectivePriority(category)
end

local MYBAGS_TOOLTIP_TITLE = "|cffff2459My|r Bags"
local MYBAGS_TOOLTIP_HINT_COLOR_PREFIX = "|cff72f272"
local QUERY_TOOLTIP_ATTRIBUTE_COLOR = "|cffffd100"
local QUERY_TOOLTIP_VALUE_COLOR = "|cff80d8ff"
local QUERY_TOOLTIP_MEANING_COLOR = "|cff9aa3b2"

local function addQueryAttributesToTooltip(tooltip, itemID, owner)
    local payload = AddonNS.CustomCategories:GetItemQueryPayload(itemID, owner)
    if not payload then
        return
    end

    local rows = AddonNS.QueryCategories:GetTooltipAttributeRows(payload)
    if #rows == 0 then
        return
    end

    GameTooltip_AddNormalLine(tooltip, MYBAGS_TOOLTIP_TITLE .. MYBAGS_TOOLTIP_HINT_COLOR_PREFIX .. " query attributes:|r")
    for index = 1, #rows do
        local row = rows[index]
        local line = " - " ..
            QUERY_TOOLTIP_ATTRIBUTE_COLOR .. row.name .. "|r: " ..
            QUERY_TOOLTIP_VALUE_COLOR .. tostring(row.value) .. "|r"
        if row.meaning and row.meaning ~= "" then
            line = line .. " " .. QUERY_TOOLTIP_MEANING_COLOR .. "(" .. row.meaning .. ")|r"
        end
        GameTooltip_AddNormalLine(tooltip, line)
    end
end

local function addCategoriesToTooltip(tooltip)
    if AddonNS.TooltipSettings:IsTooltipDisabled() then
        return
    end
    local owner = resolveTooltipItemFrame(tooltip:GetOwner())
    if not owner then
        return
    end
    local itemID = resolveTooltipItemId(owner)
    if not itemID then
        return
    end
    local scope = getScopeFromTooltipOwner(owner)
    GameTooltip_AddBlankLineToTooltip(tooltip)
    if not IsShiftKeyDown() then
        if AddonNS.TooltipSettings:ShouldShowShiftHintWhenNotHeld() then
            GameTooltip_AddNormalLine(tooltip,  MYBAGS_TOOLTIP_TITLE .. MYBAGS_TOOLTIP_HINT_COLOR_PREFIX ..
                " - Hold Shift to show matched categories|r")
            GameTooltip_AddBlankLineToTooltip(tooltip)
        end
        return
    end

    local matches = AddonNS.Categories:GetMatches(itemID, owner, {
        allowDuplicateCategoryIds = true,
        includeScopeDisabled = true,
        scope = scope,
    })
    if #matches == 0 then
        return
    end

    GameTooltip_AddNormalLine(tooltip, MYBAGS_TOOLTIP_TITLE .. MYBAGS_TOOLTIP_HINT_COLOR_PREFIX .." matched categories:|r")
    local seenManualByCategoryId = {}
    for i = 1, #matches do
        local category = matches[i]
        local categoryId = category:GetId()
        local reasonKind = nil
        if categoryId:match("^cus%-") and AddonNS.CustomCategories:IsManuallyAssignedToCategory(itemID, category) then
            if seenManualByCategoryId[categoryId] then
                reasonKind = "query"
            else
                reasonKind = "manual"
                seenManualByCategoryId[categoryId] = true
            end
        end
        local reason = formatCategoryReason(itemID, category, reasonKind)
        local line = i .. ". " .. category:GetName()
        if categoryId:match("^cus%-") and not AddonNS.CustomCategories:IsVisibleInScope(category, scope) then
            line = line .. " (disabled in this scope)"
        end
        if reason then
            line = line .. " (" .. reason .. ")"
        end
        GameTooltip_AddNormalLine(tooltip, line)
    end
    GameTooltip_AddBlankLineToTooltip(tooltip)
    addQueryAttributesToTooltip(tooltip, itemID, owner)
    GameTooltip_AddBlankLineToTooltip(tooltip)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addCategoriesToTooltip)

local function refreshTooltipOnShiftStateChange()
    if AddonNS.TooltipSettings:IsTooltipDisabled() then
        return
    end
    if not GameTooltip:IsShown() then
        return
    end
    local owner = resolveTooltipItemFrame(GameTooltip:GetOwner())
    if not owner then
        return
    end
    local bagID = owner:GetBagID()
    local slotID = owner:GetID()
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if not info then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(bagID, slotID)
end

function AddonNS.Events:MODIFIER_STATE_CHANGED(eventName, key, state)
    if key == "LSHIFT" or key == "RSHIFT" then
        refreshTooltipOnShiftStateChange()
    end
end

AddonNS.Events:RegisterEvent("MODIFIER_STATE_CHANGED")

local freeBagSlots = 10000;
local lockedUpdates = false;
local inventorySearchRefreshQueued = false
local bagSearchUnlockPending = false
local searchUnlockReanchorQueued = false

local function isBagFrameAnchorLockSearchBox(searchBox)
    return searchBox == BagItemSearchBox or searchBox == BankItemSearchBox or searchBox.anchorBag == container
end

local function getBagCapacityState()
    local freeItemSlots = 0
    local totalItemSlots = 0
    for bagID = Enum.BagIndex.Backpack, Constants.InventoryConstants.NumBagSlots do
        local slotsInBag = C_Container.GetContainerNumFreeSlots(bagID)
        local slotsTotal = C_Container.GetContainerNumSlots(bagID)
        freeItemSlots = freeItemSlots + slotsInBag
        totalItemSlots = totalItemSlots + slotsTotal
    end
    local freeReagentSlots = C_Container.GetContainerNumFreeSlots(Enum.BagIndex.ReagentBag)
    local totalReagentSlots = C_Container.GetContainerNumSlots(Enum.BagIndex.ReagentBag)
    local takenItemSlots = totalItemSlots - freeItemSlots
    local takenReagentSlots = totalReagentSlots - freeReagentSlots

    return {
        items = {
            taken = takenItemSlots,
            free = freeItemSlots,
            total = totalItemSlots,
        },
        reagents = {
            taken = takenReagentSlots,
            free = freeReagentSlots,
            total = totalReagentSlots,
        },
    }
end

local function getBankCapacityState(bankTabIds)
    local totalSlots = 0
    local takenSlots = 0
    for index = 1, #(bankTabIds or {}) do
        local tabID = bankTabIds[index]
        local slotCount = C_Container.GetContainerNumSlots(tabID)
        totalSlots = totalSlots + slotCount
        for slotID = 1, slotCount do
            local info = C_Container.GetContainerItemInfo(tabID, slotID)
            if info then
                takenSlots = takenSlots + 1
            end
        end
    end

    return {
        taken = takenSlots,
        free = totalSlots - takenSlots,
        total = totalSlots,
    }
end

AddonNS.GetBagCapacityState = getBagCapacityState
AddonNS.GetBankCapacityState = getBankCapacityState

function AddonNS.Events:BAG_UPDATE(event, bagID)
    if bagID and bagID > Enum.BagIndex.ReagentBag then
        return
    end
    if bagID == nil then
        containerItemInfoCache:InvalidateAll()
    else
        containerItemInfoCache:InvalidateBag(bagID)
    end
    invalidateBagCategorizationCacheVersion()

    if (container.MyBags.updateItemLayoutCalledAtLeastOnce) then -- todo: reading this after a while - what the hell is this :D once i know i have to add here proper comments lol
        local newFreeBagSlots = C_Container.CalculateTotalNumberOfFreeBagSlots()

        if newFreeBagSlots <= freeBagSlots and not lockedUpdates then
            queueContainerUpdateItemLayout();
        end
        lockedUpdates = true;
        RunNextFrame(function()
            lockedUpdates = false; -- and also why is this not in the run next frame above? eh
        end);
        freeBagSlots = newFreeBagSlots;
    end
end

local function updateOnTokenWatchChangedOnNextFrame(event) -- todo: i just copied and modified the function from above - but it needs comments or fixing following the comments I just added there above
    if not container:IsShown() then
        return
    end
    if not lockedUpdates then
        RunNextFrame(function()
            triggerContainerOnTokenWatchChanged();
        end);
    end
    lockedUpdates = true;
    RunNextFrame(function()
        lockedUpdates = false;
    end);
end

function AddonNS.Events:INVENTORY_SEARCH_UPDATE(event, bagID)
    if inventorySearchRefreshQueued then
        return
    end
    inventorySearchRefreshQueued = true
    RunNextFrame(function()
        inventorySearchRefreshQueued = false
        triggerContainerUpdateItemLayout();
    end)
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED,
updateOnTokenWatchChangedOnNextFrame);
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.COLLAPSED_CHANGED, updateOnTokenWatchChangedOnNextFrame);
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, function()
    invalidateBagCategorizationCacheVersion()
end)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.ITEM_MOVED, function()
    containerItemInfoCache:InvalidateAll()
    invalidateBagCategorizationCacheVersion()
end)

AddonNS.Events:RegisterEvent("INVENTORY_SEARCH_UPDATE");

AddonNS.Events:RegisterEvent("BAG_UPDATE");

hooksecurefunc("UpdateContainerFrameAnchors", function()
    if container:IsSearchAnchorLockActive() then
        container:ApplyStoredSearchAnchorLock()
    end
end)

local function refreshSearchAnchorLockState(searchBox)
    local queryEditorLockRequested = AddonNS.BagViewState:IsCategoriesConfigMode() and AddonNS.CategoriesGUI:IsQueryEditorLockRequested()
    local isContainerSearch = isBagFrameAnchorLockSearchBox(searchBox)
    if not isContainerSearch then
        return
    end
    local shouldLock = isContainerSearch and (searchBox:HasFocus() or searchBox:GetText() ~= "" or queryEditorLockRequested)
    if shouldLock then
        bagSearchUnlockPending = false
    elseif container:IsSearchAnchorLockActive() and not bagSearchUnlockPending then
        bagSearchUnlockPending = true
        RunNextFrame(function()
            if bagSearchUnlockPending then
                refreshSearchAnchorLockState(searchBox)
            end
        end)
        return
    end
    local changed = container:SetSearchAnchorLockActive(shouldLock)
    if shouldLock then
        if changed or not container.MyBags.searchLockedTop or not container.MyBags.searchLockedRight then
            container:CaptureSearchAnchorLockPosition()
        end
    else
        bagSearchUnlockPending = false
    end
    if changed and not shouldLock then
        if not searchUnlockReanchorQueued then
            searchUnlockReanchorQueued = true
            RunNextFrame(function()
                searchUnlockReanchorQueued = false
                local queryEditorStillLockRequested = AddonNS.BagViewState:IsCategoriesConfigMode() and AddonNS.CategoriesGUI:IsQueryEditorLockRequested()
                local stillUnlocked = not container:IsSearchAnchorLockActive()
                local stableUnlockState = (BagItemSearchBox:GetText() == "") and (not BagItemSearchBox:HasFocus()) and (not queryEditorStillLockRequested)
                if stillUnlocked and stableUnlockState then
                    UpdateContainerFrameAnchors()
                end
            end)
        end
    end
end

local function refreshSearchQueryState(searchText)
    local nextText = searchText or ""
    if searchQueryState.text == nextText then
        return
    end
    searchQueryState.text = nextText
    searchQueryState.evaluator = AddonNS.QueryCategories:CompileAdHoc(nextText)
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

BagItemSearchBox:HookScript("OnEditFocusGained", function(searchBox)
    refreshSearchAnchorLockState(searchBox)
end)

BagItemSearchBox:HookScript("OnEditFocusLost", function(searchBox)
    refreshSearchAnchorLockState(searchBox)
end)
BankItemSearchBox:HookScript("OnEditFocusGained", function(searchBox)
    refreshSearchAnchorLockState(searchBox)
end)

BankItemSearchBox:HookScript("OnEditFocusLost", function(searchBox)
    refreshSearchAnchorLockState(searchBox)
end)

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, function()
    refreshSearchAnchorLockState(BagItemSearchBox)
end)

local function installSearchBoxWrapper(searchBox)
    if not searchBox then
        return
    end
    if searchBox.MyBagsSearchWrapped then
        return
    end
    local oldOnTextChanged = searchBox:GetScript("OnTextChanged")
    if not oldOnTextChanged then
        return
    end
    searchBox:SetScript("OnTextChanged", function(box, userChanged)
        local text = box:GetText() or ""
        refreshSearchQueryState(text)
        if isBagFrameAnchorLockSearchBox(box) then
            -- Keep anchor lock state in sync before Blizzard's handler mutates layout/anchors.
            refreshSearchAnchorLockState(box)
        end
        oldOnTextChanged(box, userChanged)
        if isBagFrameAnchorLockSearchBox(box) then
            -- Re-assert lock/captured position after the built-in search update path runs.
            refreshSearchAnchorLockState(box)
        end
    end)
    searchBox.MyBagsSearchWrapped = true
end

local function extendSearchBoxMaxLetters(searchBox)
    if not searchBox then
        return
    end
    searchBox:SetMaxLetters(SEARCH_BOX_MAX_LETTERS)
end

extendSearchBoxMaxLetters(BagItemSearchBox)
extendSearchBoxMaxLetters(BankItemSearchBox)

installSearchBoxWrapper(BagItemSearchBox)
installSearchBoxWrapper(BankItemSearchBox)
hooksecurefunc(container, "UpdateSearchResults", function()
    for _, itemButton in container:EnumerateValidItems() do
        local defaultMatch = itemButton:GetMatchesSearch()
        if type(defaultMatch) == "boolean" then
            itemButton._myBagsDefaultSearchMatch = defaultMatch
        end
        setItemButtonSearchOverlayAlpha(itemButton, 0)
    end
end)

container:HookScript("OnHide", function()
    bagSearchUnlockPending = false
    searchUnlockReanchorQueued = false
    container:SetSearchAnchorLockActive(false)
end)
container:HookScript("OnShow", function()
    AddonNS:SetCurrentLayoutScope("bag")
end)

refreshSearchQueryState(BagItemSearchBox:GetText())

function container:GetColumns()
    return AddonNS.Const.ITEMS_PER_ROW * AddonNS.CategoryStore:GetColumnCount("bag")
end

local it = container:EnumerateValidItems()

AddonNS.emptyItemButton = nil
local function newIterator(iteratorContainer, index)
    local arrangedItems = iteratorContainer.MyBags.arrangedItems;
    local positionsInBags = iteratorContainer.MyBags.positionsInBags;
    local itemButton
    index, itemButton = it(iteratorContainer, index);
    if (index == 1) then
        AddonNS.emptyItemButton = nil -- reset itemButom
        bagSearchText = BagItemSearchBox:GetText() or ""
        bagSearchActive = bagSearchText ~= ""
    end
    if (itemButton) then
        -- [[ checking hooks]]
        if (not itemButton.myBagAddonHooked) then
            -- TODO: prolly need to remove this hook when not merged bags are used to not destroy by accident proper categorisations?
            -- todo: this should be done once during these creation steps, not here.

            itemButton:HookScript("OnDragStart", AddonNS.DragAndDrop.itemStartDrag);
            itemButton:HookScript("OnDragStop", AddonNS.DragAndDrop.itemStopDrag);
            itemButton:HookScript("PreClick", AddonNS.DragAndDrop.itemOnClick);
            itemButton:HookScript("OnReceiveDrag", AddonNS.DragAndDrop.itemOnReceiveDrag);
            itemButton.myBagAddonHooked = true;
        end

        itemButton.MyBagsScope = "bag"
        setMyBagsIncludeInSearch(itemButton, false)

        -- [[ CATEGORISATION ]]
        local info = containerItemInfoCache:Get(itemButton:GetBagID(), itemButton:GetID());
        itemButton.ItemCategory = nil;
        if (info) then
            local capturedDefaultMatch = itemButton._myBagsDefaultSearchMatch
            local defaultMatch = true
            if bagSearchActive and type(capturedDefaultMatch) == "boolean" then
                defaultMatch = capturedDefaultMatch
            elseif bagSearchActive then
                defaultMatch = not info.isFiltered
            end
            local includeInSearch = evaluateSearchVisibility(defaultMatch, searchQueryState.evaluator, info, itemButton)
            local category = nil
            if bagSearchActive then
                category = resolveCachedOrComputeBagCategory(itemButton, info)
                AddonNS.SearchCategoryBaseline:Add(arrangedItems, category, itemButton, false, true)
            end
            if includeInSearch then
                setMyBagsIncludeInSearch(itemButton, true)
                itemButton._myBagsItemId = info.itemID
                if not category then
                    category = resolveCachedOrComputeBagCategory(itemButton, info)
                end
                itemButton.ItemCategory = category
                AddonNS.SearchCategoryBaseline:Add(arrangedItems, category, itemButton, true, bagSearchActive)
            elseif itemButton:GetBagID() ~= Enum.BagIndex.ReagentBag then
                AddonNS.emptyItemButton = itemButton;
            end
        elseif itemButton:GetBagID() ~= Enum.BagIndex.ReagentBag then
            AddonNS.emptyItemButton = itemButton;
        end
    else --[[ iterator finished so we can now tackle the list and calcualte the positions of items, as we now have all the items]]
        local itemSize = container.Items[1]:GetHeight() + ITEM_SPACING;
        container.MyBags.rows = 0;
        container.MyBags.height = 0;
        for bagID in pairs(positionsInBags) do
            positionsInBags[bagID] = nil
        end
        container.MyBags.categoryPositions = {};
        local function placeItemsInGrid(categoriesObj, columnStartX)
            local isCategoriesConfigMode = AddonNS.BagViewState:IsCategoriesConfigMode()
            local currentRow = {}
            local itemPlaceholder = AddonNS.itemButtonPlaceholder;
            local currentRowWidth = 0
            local currentRowY = 0
            local rowWithNewCategory = false;
            local currentRowNo = 0;
            local function flushCurrentRow()
                local xOffset = 0
                for _, item in ipairs(currentRow) do
                    if item ~= itemPlaceholder then
                        positionsInBags[item:GetBagID()] = positionsInBags[item:GetBagID()] or {};
                        positionsInBags[item:GetBagID()][item:GetID()] = {
                            id = item:GetID(),
                            x = columnStartX + xOffset,
                            y = currentRowY,
                        };
                    end
                    xOffset = xOffset + itemSize
                end
                currentRow = {}
                currentRowWidth = 0
                currentRowY = currentRowY + itemSize
                rowWithNewCategory = false;
                currentRowNo = currentRowNo + 1;
            end

            for i, categoryObj in ipairs(categoriesObj) do
                local categoryItemsCount = categoryObj.itemsCount or #categoryObj.items;
                local isCategoryCollapsed = isCollapsed(categoryObj.category, "bag");
                local isHeaderOnly = isCategoryCollapsed or categoryObj.itemsCount == 0;
                local categoryRequiresNewLine = isCategoriesConfigMode or isHeaderOnly or categoryObj.category.separateLine;
                local categoryRequiresFullRowWidth = isCategoriesConfigMode or isHeaderOnly;
                local requiredNewLine =
                    categoryRequiresNewLine
                    or #currentRow == 0
                    or #currentRow > 0 and
                    (rowWithNewCategory and currentRowWidth + itemSize * (categoryItemsCount) > AddonNS.Const.ITEMS_PER_ROW * itemSize or not rowWithNewCategory)

                if (i == 1) then
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT;
                elseif requiredNewLine then
                    if (#currentRow > 0) then
                        flushCurrentRow();
                    end
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING;
                end
                local nextCategoryObj = categoriesObj[i + 1]
                local nextCategoryExists = nextCategoryObj ~= nil

                local expandCategoryToRightColumnBoundary = 0
                if not categoryRequiresFullRowWidth and #currentRow + categoryItemsCount < AddonNS.Const.ITEMS_PER_ROW then
                    local shouldExpandToBoundary =
                        (not nextCategoryExists)
                        or isCollapsed(nextCategoryObj.category, "bag")
                        or nextCategoryObj.itemsCount == 0
                        or nextCategoryObj.category.separateLine
                        or #currentRow + categoryItemsCount + #nextCategoryObj.items > AddonNS.Const.ITEMS_PER_ROW
                    if shouldExpandToBoundary then
                        expandCategoryToRightColumnBoundary = AddonNS.Const.ITEMS_PER_ROW - #currentRow - categoryItemsCount
                    end
                end
                local categoryWidthSlots = AddonNS.Const.ITEMS_PER_ROW
                if not categoryRequiresFullRowWidth then
                    categoryWidthSlots = math.min(AddonNS.Const.ITEMS_PER_ROW, categoryItemsCount + expandCategoryToRightColumnBoundary)
                end
                table.insert(container.MyBags.categoryPositions,
                    {
                        category = categoryObj.category,
                        itemsCount = categoryItemsCount,
                        scope = "bag",
                        x = columnStartX + itemSize * #currentRow - ITEM_SPACING / 2,
                        y = currentRowY - AddonNS.Const.CATEGORY_HEIGHT,
                        width = itemSize * categoryWidthSlots,
                        height = AddonNS.Const.CATEGORY_HEIGHT + ((not isHeaderOnly and
                            math.ceil(categoryItemsCount / AddonNS.Const.ITEMS_PER_ROW) *
                            itemSize) or 0),
                    });
                rowWithNewCategory = true;
                local items = categoryObj.items;
                if (not isHeaderOnly) then
                    for j = #items, 1, -1 do
                        local item = items[j];
                        table.insert(currentRow, item)
                        currentRowWidth = currentRowWidth + itemSize
                        if #currentRow >= AddonNS.Const.ITEMS_PER_ROW then
                            flushCurrentRow()
                        end
                    end
                end
            end

            if #currentRow > 0 then
                flushCurrentRow()
            end
            if (container.MyBags.height <= currentRowY) then
                container.MyBags.height = currentRowY;
                container.MyBags.rows = currentRowNo;
            end
            return currentRowY
        end

        -- Calculate positions for each column
        local categoryAssignments = AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems, "bag") -- todo: this object is quite weird. Why is it a local global used among two functions :/


        local columnSize = itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING;
        local columnBottomYByIndex = {}
        for colIndex, categoryObjs in ipairs(categoryAssignments) do
            local columnStartX = (colIndex - 1) * columnSize
            columnBottomYByIndex[colIndex] = placeItemsInGrid(categoryObjs, columnStartX)
        end

        if AddonNS.BagViewState:IsCategoriesConfigMode() then
            local lastColumnIndex = #categoryAssignments
            local columnBottomY = columnBottomYByIndex[lastColumnIndex] or 0
            local addCategoryY = 0
            if columnBottomY > 0 then
                addCategoryY = columnBottomY + AddonNS.Const.COLUMN_SPACING
            end
            local controlHeight = AddonNS.Const.CATEGORY_HEIGHT
            local controlSpacing = AddonNS.Const.COLUMN_SPACING
            table.insert(container.MyBags.categoryPositions, {
                isAddCategoryControl = true,
                x = (lastColumnIndex - 1) * columnSize - ITEM_SPACING / 2,
                y = addCategoryY,
                width = itemSize * AddonNS.Const.ITEMS_PER_ROW,
                height = controlHeight,
            })
            table.insert(container.MyBags.categoryPositions, {
                isExportCategoryControl = true,
                x = (lastColumnIndex - 1) * columnSize - ITEM_SPACING / 2,
                y = addCategoryY + controlHeight + controlSpacing,
                width = itemSize * AddonNS.Const.ITEMS_PER_ROW,
                height = controlHeight,
            })
            table.insert(container.MyBags.categoryPositions, {
                isImportCategoryControl = true,
                x = (lastColumnIndex - 1) * columnSize - ITEM_SPACING / 2,
                y = addCategoryY + (controlHeight + controlSpacing) * 2,
                width = itemSize * AddonNS.Const.ITEMS_PER_ROW,
                height = controlHeight,
            })
            local addControlBottomY = addCategoryY + (controlHeight + controlSpacing) * 2 + controlHeight
            if addControlBottomY > container.MyBags.height then
                container.MyBags.height = addControlBottomY
            end
        end
    end
    return index, itemButton;
end

function AddonNS.newEnumerateValidItems(iteratorContainer)
    return newIterator, iteratorContainer, 0;
end
