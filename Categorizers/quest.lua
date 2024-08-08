local addonName, AddonNS = ...

local QuestCategorizer = {};

AddonNS.Categories:RegisterCategorizer("Quest", QuestCategorizer, false);


function QuestCategorizer:Categorize(itemID, itemButton)

    local questInfo = C_Container.GetContainerItemQuestInfo(itemButton:GetBagID(), itemButton:GetID());
    local isQuestItem = questInfo.isQuestItem;
    local questID = questInfo.questID;
    local isActive = questInfo.isActive;
    return isQuestItem and ITEM_QUALITY_COLORS[Enum.ItemQuality.Common].hex.."Quest";
end

