local addonName, AddonNS = ...

AddonNS.DragAndDrop = {};
AddonNS.gui = AddonNS.gui or {}
AddonNS.gui.RefreshCategoryDragHints = AddonNS.gui.RefreshCategoryDragHints or function()
end
local toggleCollapsed = AddonNS.Collapsed.toggleCollapsed;

local pickedItemID = nil;
local pickedItemCategory = nil;
local pickedItemButton = nil;
local pickedScope = "bag";
local isCategoryDragActive = false;
local container = AddonNS.container;

local recentAt = 0
local TTL = 0.10 -- 100 ms
local cachedInfoType, cachedItemID, cachedItemLink;
local HINT_TEXT_UNASSIGNED = "|cff64a9ffRemove category assignment|r\nDrop here to remove manual category assignment"
local HINT_TEXT_BLOCKED = "|cffff4a4aCannot assign here.|r\nDynamic / protected category"

local function getCachedCursorInfo()
    local now = GetTime();
    if (now - recentAt > TTL) then
        cachedInfoType, cachedItemID, cachedItemLink = GetCursorInfo();
        recentAt = now;
    end
    return cachedInfoType, cachedItemID, cachedItemLink;
end

local function getScopeByBagId(bagId)
    if bagId == nil then
        return "bag"
    end
    if bagId >= Enum.BagIndex.CharacterBankTab_1 and bagId <= Enum.BagIndex.CharacterBankTab_6 then
        return "bank-character"
    end
    if bagId >= Enum.BagIndex.AccountBankTab_1 and bagId <= Enum.BagIndex.AccountBankTab_5 then
        return "bank-account"
    end
    return "bag"
end

local function getScopeFromButton(button)
    local frame = button
    while frame do
        if frame.MyBagsScope then
            return frame.MyBagsScope
        end
        if not frame.GetParent then
            break
        end
        frame = frame:GetParent()
    end
    if button and button.GetBagID then
        return getScopeByBagId(button:GetBagID())
    end
    return pickedScope or "bag"
end

local function isSameScopeTransfer(targetScope)
    return (pickedScope or "bag") == (targetScope or "bag")
end

local function normalizeCrossScopeItemDrag(targetScope)
    if pickedItemButton and not isSameScopeTransfer(targetScope) then
        pickedItemButton = nil
    end
end

local function queueRefreshForScope(scope)
    if scope == "bag" then
        AddonNS.QueueContainerUpdateItemLayout()
        return
    end
    if AddonNS.BankView and AddonNS.BankView.QueueRefresh then
        AddonNS.BankView:QueueRefresh(scope)
    end
end

local function triggerRefreshForScope(scope)
    if scope == "bag" then
        AddonNS.TriggerContainerOnTokenWatchChanged()
        return
    end
    if AddonNS.BankView and AddonNS.BankView.QueueRefresh then
        AddonNS.BankView:QueueRefresh(scope)
    end
end

local function hasActiveItemDrag()
    local infoType = getCachedCursorInfo()
    return infoType == "item" or infoType == "merchant"
end

function AddonNS.DragAndDrop:GetDraggedItemID()
    local infoType, itemID = getCachedCursorInfo()
    if infoType == "merchant" then
        return GetMerchantItemID(itemID)
    end
    if infoType == "item" then
        return itemID
    end
end

function AddonNS.DragAndDrop:IsItemDragActive()
    return hasActiveItemDrag()
end

function AddonNS.DragAndDrop:IsCategoryDragActive()
    return isCategoryDragActive
end

function AddonNS.DragAndDrop:GetCategoryDropHint(category, isHovered)
    if not hasActiveItemDrag() then
        return nil
    end
    if not isHovered then
        return nil
    end
    local categoryId = category:GetId()
    if categoryId == "unassigned" then
        return {
            tone = "unassigned",
            text = HINT_TEXT_UNASSIGNED,
        }
    end
    if category:IsProtected() then
        return {
            tone = "blocked",
            text = HINT_TEXT_BLOCKED,
        }
    end
    return {
        tone = "assign",
        text = "|cff57c67aAssign|r to " .. category:GetName(),
    }
end

local function resolveCategory(category)
    if not category then
        return nil
    end
    if type(category) == "table" then
        return category
    end
    return AddonNS.CategoryStore:Get(category)
end

local function getCategoryId(category)
    if type(category) == "table" and category.GetId then
        return category:GetId()
    end
    return category and category.id or nil
end

local function canTriggerItemMove(sourceCategory, targetCategory)
    if targetCategory and targetCategory:IsProtected() then
        return false
    end
    return true
end

local function triggerItemMoved(itemID, targetedItemID, sourceCategory, targetCategory, pickedItemButton, targetItemButton)
    local source = resolveCategory(sourceCategory)
    local target = resolveCategory(targetCategory)
    if not canTriggerItemMove(source, target) then
        return
    end
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.ITEM_MOVED, itemID, targetedItemID, source, target,
        pickedItemButton,
        targetItemButton, AddonNS.ItemInsertionPreview:GetInsertionSide(targetItemButton));
end

function AddonNS.DragAndDrop.cleanUp()
    AddonNS.ItemInsertionPreview:Hide()
    pickedItemButton = nil;
    pickedItemID = nil
    pickedItemCategory = nil;
    pickedScope = "bag"
    isCategoryDragActive = false;
    recentAt = 0
    cachedInfoType, cachedItemID, cachedItemLink = nil, nil, nil
    AddonNS.gui:RefreshCategoryDragHints()
end

--[[
unknown item -> item
- assign new category to item
- refresh gear (buttons) ItemCategories
- change button order

item -> item
- assign new category to item
- refresh gear (buttons) ItemCategories
- change button order

item -> category
- assign new category to item

category -> item
- change category order

category -> category
- change category order

]]

hooksecurefunc(C_Container, "SplitContainerItem",
    function(bag, slot, amount) -- to force placement onto an emptyItemButton
        pickedItemButton = nil;
    end)

local function getItemIdFromButton(buttonItem)
    local info = buttonItem and buttonItem.GetBagID and
        C_Container.GetContainerItemInfo(buttonItem:GetBagID(), buttonItem:GetID());
    return info and info.itemID
end

function AddonNS.DragAndDrop.itemOnClick(self, button)
    if button == "LeftButton" then
        local infoType, itemID = getCachedCursorInfo()
        if (infoType) then
            local targetScope = getScopeFromButton(self)
            normalizeCrossScopeItemDrag(targetScope)
            if (pickedItemButton and itemID ~= getItemIdFromButton(self)) then
                ClearCursor(); -- [faster movement feature] see INFO in itemOnReceiveDrag function
            end
            AddonNS.DragAndDrop.itemOnReceiveDrag(self)
        else
            AddonNS.DragAndDrop.itemStartDrag(self);
        end
    end
end

local function getHoveredHookedFrame(targetedItemID)
    local mouseFoci = GetMouseFoci()
    local f = mouseFoci[1]
    if f and (f.myBagAddonHooked or f.ItemCategory) then
        local hoveredItemID = getItemIdFromButton(f)
        if hoveredItemID then
            if hoveredItemID == targetedItemID then
                return nil
            end
            return f
        end
        return f
    end
    return nil
end

function AddonNS.DragAndDrop.itemStopDrag(self)                 -- its only here to refresh cursor as we are hooking to onreceiveddrag and that means that cursor is cleared by the time it arrives to our code. Hence we will Cache it and use that instead.
    getCachedCursorInfo()                                       -- this is here to cache the value even when it would be removed by Blizzard code
    local hoveredFrame = getHoveredHookedFrame(getItemIdFromButton(self))
    if hoveredFrame then
        normalizeCrossScopeItemDrag(getScopeFromButton(hoveredFrame))
    end
    if hoveredFrame and pickedItemButton then -- [faster movement feature]
        ClearCursor();                                          -- see INFO in itemOnReceiveDrag function
    end
    AddonNS.gui:RefreshCategoryDragHints()
end

function AddonNS.DragAndDrop.itemStartDrag(self)
    AddonNS.DragAndDrop.cleanUp()
    isCategoryDragActive = false;
    pickedScope = getScopeFromButton(self)
    local itemID = getItemIdFromButton(self)
    if (itemID) then
        pickedItemButton = self;
        pickedItemID = itemID;
        pickedItemCategory = self.ItemCategory;
    end
    AddonNS.gui:RefreshCategoryDragHints()
end

function AddonNS.DragAndDrop.itemOnReceiveDrag(self)
    local targetItemCategory = self.ItemCategory;
    local targetScope = getScopeFromButton(self)
    normalizeCrossScopeItemDrag(targetScope)

    local infoType, itemID = getCachedCursorInfo()
    if (infoType == "merchant") then
        itemID = GetMerchantItemID(itemID)
        infoType = "item";
    end

    if (infoType == "item") then
        local info = C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID());
        local targetedItemID = info and info.itemID or nil;
        if (pickedItemButton) then
            if (itemID ~= pickedItemID) then -- i think this is here to prevent some weird situation when pickeditembutton is not cleared, but now I am going to extend it with check for faster movement feature
                AddonNS.DragAndDrop.cleanUp()
            end
            if itemID ~= getItemIdFromButton(self) then
                --[[ INFO: this magic here is because in AddonNS.DragAndDrop.itemStopDrag we added cleraring curosor,
        so then main game uses PickupContainerItem which pickups item on which drag ends,
        so this function here is to put that item back... :D but because of that the movement of items
        between slots is much faster as it does not require a sync to a server, as the item physicially
        does not move, we change only the location of itembuttons hence it is super quick ]]
                C_Container.PickupContainerItem(self:GetBagID(), self:GetID()) -- [faster movement feature]
            end
        end
        triggerItemMoved(itemID, targetedItemID, pickedItemCategory, targetItemCategory, pickedItemButton, self);
    elseif pickedItemCategory then -- category frame
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED,
            getCategoryId(pickedItemCategory), getCategoryId(targetItemCategory), nil, targetScope);
    end
    queueRefreshForScope(targetScope);
    AddonNS.DragAndDrop.cleanUp()
end

function AddonNS.DragAndDrop.categoryStartDrag(self)
    AddonNS.DragAndDrop.cleanUp()
    pickedItemCategory = self.ItemCategory;
    pickedScope = getScopeFromButton(self)
    isCategoryDragActive = true;
    AddonNS.gui:RefreshCategoryDragHints()
end

function AddonNS.DragAndDrop.categoryOnMouseUp(self, button)
    local infoType = getCachedCursorInfo()
    if infoType or isCategoryDragActive then
        if button == "LeftButton" then
            AddonNS.DragAndDrop.categoryOnReceiveDrag(self)
        end
    else
        local refreshView = false
        if button == "LeftButton" then
            toggleCollapsed(self.ItemCategory, getScopeFromButton(self));
        elseif button == "RightButton" then
            local category = self.ItemCategory
            local categoryContainer = self.MyBagsContainerRef or container
            if category and category.OnRightClick then
                refreshView = category:OnRightClick(categoryContainer)
            end
        end

        if (refreshView) then
            queueRefreshForScope(getScopeFromButton(self));
        end
    end
end

function AddonNS.DragAndDrop.categoryOnReceiveDrag(self)
    local targetItemCategory = self.ItemCategory;
    local targetScope = getScopeFromButton(self)

    local infoType, itemID = getCachedCursorInfo()
    if (infoType == "merchant") then
        itemID = GetMerchantItemID(itemID)
        infoType = "item";
    end
    if (infoType == "item") then
        normalizeCrossScopeItemDrag(targetScope)
        if (pickedItemButton and itemID ~= pickedItemID) then
            AddonNS.DragAndDrop.cleanUp()
        end
        if not pickedItemButton then
            local emptyItemButton = AddonNS.emptyItemButton
            if emptyItemButton then
                ContainerFrameItemButton_OnClick(emptyItemButton, "LeftButton")
            end
        end
        triggerItemMoved(itemID, nil, pickedItemCategory, targetItemCategory, pickedItemButton, nil);
        ClearCursor();
        queueRefreshForScope(targetScope);
    elseif isCategoryDragActive and pickedItemCategory and (pickedItemCategory ~= targetItemCategory) then -- category frame
        local moveTail = IsShiftKeyDown()
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED,
            getCategoryId(pickedItemCategory), getCategoryId(targetItemCategory), moveTail, targetScope);
        RunNextFrame(function() -- todo: maybe these actually should be triggered at the point where action is processed... hmm
            triggerRefreshForScope(targetScope);
            -- container:UpdateContainerFrameAnchors();
        end);
    end

    AddonNS.DragAndDrop.cleanUp()
end

function AddonNS.DragAndDrop.backgroundOnReceiveDrag(self, mouseButtonName)
    if mouseButtonName and mouseButtonName ~= "LeftButton" then
        return
    end
    local scope = getScopeFromButton(self)
    local columnNo = AddonNS.CategoryBackground:GetDropColumn(self, scope, self.MyBagsResolveDropColumn)
    if (columnNo) then
        local infoType, itemID = getCachedCursorInfo()
        if (infoType == "merchant") then
            itemID = GetMerchantItemID(itemID)
            infoType = "item";
        end
        if (infoType == "item") then
            local scope = getScopeFromButton(self)
            normalizeCrossScopeItemDrag(scope)
            if (pickedItemButton and itemID ~= pickedItemID) then
                AddonNS.DragAndDrop.cleanUp()
            end
            if not pickedItemButton then
                local emptyItemButton = AddonNS.emptyItemButton
                if emptyItemButton then
                    ContainerFrameItemButton_OnClick(emptyItemButton, "LeftButton")
                end
            end
            local targetCategory = AddonNS.Categories:GetLastCategoryInColumn(columnNo, scope);
            triggerItemMoved(itemID, nil, pickedItemCategory, targetCategory, pickedItemButton, nil);
            ClearCursor();
            queueRefreshForScope(scope);
        elseif isCategoryDragActive and pickedItemCategory then -- category frame
            local moveTail = IsShiftKeyDown()
            local scope = getScopeFromButton(self)
            AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN,
                getCategoryId(pickedItemCategory), columnNo, moveTail, scope);
            -- ClearCursor();
            RunNextFrame(function()
                triggerRefreshForScope(scope);
            end);
        end
        AddonNS.DragAndDrop.cleanUp()
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnMouseUp(targetCategoryId, button)
    if button == "LeftButton" then
        AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetCategoryId)
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetCategoryId)
    if (pickedItemButton) then -- button
        local infoType, itemID = getCachedCursorInfo()
        if infoType == "item" and itemID == pickedItemID then
            local targetCategory = AddonNS.CategoryStore:Get(targetCategoryId)
            triggerItemMoved(itemID, nil, pickedItemCategory, targetCategory, pickedItemButton, nil);
            ClearCursor();
            queueRefreshForScope(pickedScope);
        end
    end

    AddonNS.DragAndDrop.cleanUp()
end

function AddonNS.DragAndDrop:HookItemButton(itemButton)
    if itemButton.myBagAddonHooked then
        return false
    end
    itemButton:HookScript("OnDragStart", self.itemStartDrag)
    itemButton:HookScript("OnDragStop", self.itemStopDrag)
    itemButton:HookScript("PreClick", self.itemOnClick)
    itemButton:HookScript("OnReceiveDrag", self.itemOnReceiveDrag)
    itemButton.myBagAddonHooked = true
    return true
end
