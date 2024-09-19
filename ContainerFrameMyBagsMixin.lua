local addonName, AddonNS = ...


local function extend(f, f2)
    return function(...)
        return f2(f, ...);
    end
end

local ContainerFrameMyBagsMixin = {};

function ContainerFrameMyBagsMixin:MyBagsInit()
    self.MyBags = {};
    self.MyBags.categorizeItems = true;
    self.MyBags.arrangedItems = {};
end

function ContainerFrameMyBagsMixin:UpdateItemLayout(...)
    AddonNS.printDebug("UpdateItemLayout")
    UpdateItemLayoutCalledAtLeastOnce = true;
    self.MyBags.categorizeItems = true;
    return ContainerFrameCombinedBagsMixin.UpdateItemLayout(self, ...);
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

Mixin(ContainerFrameCombinedBags, ContainerFrameMyBagsMixin);
ContainerFrameCombinedBags:MyBagsInit();
