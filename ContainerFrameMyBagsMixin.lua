local addonName, AddonNS = ...


local function extend(f, f2)
    return function(...)
        return f2(f, ...);
    end
end

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;

local ContainerFrameMyBagsMixin = {};

function ContainerFrameMyBagsMixin:MyBagsInit()
    self.MyBags = {};
    self.MyBags.categorizeItems = true;
    self.MyBags.arrangedItems = {};
    self.MyBags.positionsInBags = {};
    self.MyBags.categoryPositions = {};
    self.MyBags.rows = 0;
    self.MyBags.height = 0;
    self.MyBags.updateItemLayoutCalledAtLeastOnce = false
end

function ContainerFrameMyBagsMixin:UpdateItemLayout()
    AddonNS.printDebug("UpdateItemLayout")
    self.MyBags.updateItemLayoutCalledAtLeastOnce = true;
    self.MyBags.categorizeItems = true;
    local itemButtons = {}
    for i, itemButton in self:EnumerateValidItems() do -- todo: can refactor this to single loop once I stop using enumerate to assign positions in bags. Otherwsie I have to run over this function first before putting items into proper places
        table.insert(itemButtons, itemButton);
    end
    local yFrameOffset = self:CalculateHeight() - self:GetPaddingHeight() -
        self:CalculateExtraHeight() + ITEM_SPACING + self:CalculateHeightForCategoriesTitles();

    local anchor = self:GetInitialItemAnchor();

    local _, relativeTo = anchor:Get();
    anchor:Set("TOPLEFT", relativeTo, "TOPLEFT", 0, 0);
    local point, relativeTo, relativePoint, x, y = anchor:Get();
    AddonNS.printDebug("Anchor", x, y)

    self:UpdateFrameSize();
    for i, itemButton in ipairs(itemButtons) do
        if (itemButton.ItemCategory and not itemButton.ItemCategory.folded) then
            local newXOffset = self.MyBags.positionsInBags[itemButton:GetBagID()][itemButton:GetID()].x;
            local newYOffset = -self.MyBags.positionsInBags[itemButton:GetBagID()][itemButton:GetID()].y + yFrameOffset;
            itemButton:ClearAllPoints();
            itemButton:SetPoint(point, relativeTo, relativePoint, x + newXOffset, y + newYOffset);
            itemButton:Show();
        else
            itemButton:Hide();
        end
    end

    AddonNS.gui:RegenerateCategories(yFrameOffset, self.MyBags.categoryPositions);


end

function ContainerFrameMyBagsMixin:EnumerateValidItems()
    if self.MyBags.categorizeItems then
        AddonNS.printDebug("EnumerateValidItems override used")
        self.MyBags.categorizeItems = false;
        self.MyBags.arrangedItems = {}
        return AddonNS.newEnumerateValidItems(self);
    end
    AddonNS.printDebug("EnumerateValidItems default used")
    return ContainerFrameCombinedBagsMixin.EnumerateValidItems(self);
end

function ContainerFrameMyBagsMixin:UpdateItemSlots(...)
    AddonNS.printDebug("UpdateItemSlots")
    ContainerFrameCombinedBagsMixin.UpdateItemSlots(self, ...);

    local bagSize = ContainerFrame_GetContainerNumSlots(Enum.BagIndex.ReagentBag);
    for i = 1, bagSize do
        local itemButton = self:AcquireNewItemButton();
        local slotID = bagSize - i + 1;
        itemButton:Initialize(Enum.BagIndex.ReagentBag, slotID);
    end
end;

-- need to overwrite this as it is used during enumeration of items in the bags so otherwise it would not incorporate reagentsContainer
function ContainerFrameMyBagsMixin:SetBagSize()
    self.size = 0;
    for i = 0, Enum.BagIndex.ReagentBag, 1 do
        self.size = self.size + ContainerFrame_GetContainerNumSlots(i);
    end
end

function ContainerFrameMyBagsMixin:MatchesBagID(id) -- override to include reagent bags
    return id >= Enum.BagIndex.Backpack and id <= Enum.BagIndex.ReagentBag;
end

function ContainerFrameMyBagsMixin:CalculateHeightForCategoriesTitles()
    return self.MyBags.height - self.MyBags.rows * (self.Items[1]:GetHeight() + ITEM_SPACING);
end

function ContainerFrameMyBagsMixin:CalculateExtraHeight()
    return self:CalculateHeightForCategoriesTitles() + ContainerFrameCombinedBagsMixin.CalculateExtraHeight(self);
end

function ContainerFrameMyBagsMixin:CalculateWidth()
    return ContainerFrameCombinedBagsMixin.CalculateWidth(self) +
        (AddonNS.Const.NUM_COLUMNS - 1) * AddonNS.Const.COLUMN_SPACING -
        self:GetColumns() * (AddonNS.Const.ORIGINAL_SPACING - ITEM_SPACING);
end

function ContainerFrameMyBagsMixin:GetRows()
    return self.MyBags.rows;
end

Mixin(ContainerFrameCombinedBags, ContainerFrameMyBagsMixin);
ContainerFrameCombinedBags:MyBagsInit();
