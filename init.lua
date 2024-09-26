local addonName, AddonNS = ...

--@debug@
GLOBAL_MyBags = AddonNS;
--@end-debug@

-- events
AddonNS.Events = {};
LibStub("MyLibrary_Events").embed(AddonNS.Events);
AddonNS.Events.ITEM_MOVED = "MYBAGS_ITEM_MOVED";
AddonNS.Events.ITEM_CATEGORY_CHANGED = "MYBAGS_ITEM_CATEGORY_CHANGED";
AddonNS.Events.CATEGORY_MOVED = "MYBAGS_CATEGORY_MOVED"
AddonNS.Events.CATEGORY_MOVED_TO_COLUMN = "MYBAGS_CATEGORY_MOVED_TO_COLUMN"
AddonNS.Events.CUSTOM_CATEGORY_RENAMED = "MYBAGS_CUSTOM_CATEGORY_RENAMED";
AddonNS.Events.CUSTOM_CATEGORY_DELETED = "MYBAGS_CUSTOM_CATEGORY_DELETED";

-- DB
--@debug@
local dbName = "dev_MyBagsDB"
local globalDbName = "dev_MyBagsDBGlobal"
--@end-debug@
--[===[@non-debug@
local dbName = "MyBagsDB"
local globalDbName = "MyBagsDBGlobal";
--@end-non-debug@]===]

AddonNS.db = {};
AddonNS.init = function()
    _G[globalDbName] = _G[globalDbName] or _G[dbName] or {};
    AddonNS.db = _G[globalDbName];
    -- _G[dbName] = nil; -- we shouldnt nil it. If one has accessed the game on their alt it might overwrite their main config. It is better to leave it as is, so in worst case scenario one could still copy it manually from their main character.
end

AddonNS.Events:OnDbLoaded(AddonNS.init)

function AddonNS.printDebug(...)
    -- print(...)
end

AddonNS.Const ={
    ITEMS_PER_ROW = 4, -- Maximum items per row
    NUM_COLUMNS = 3, -- Number of columns
    ORIGINAL_SPACING = 5,
    COLUMN_SPACING = 2,
    CATEGORY_HEIGHT = 20,
    MAX_ROWS = 18,
}
AddonNS.Const.NUM_ITEM_COLUMNS = AddonNS.Const.ITEMS_PER_ROW * AddonNS.Const.NUM_COLUMNS
AddonNS.Const.ITEM_SPACING= AddonNS.Const.ORIGINAL_SPACING
AddonNS.Const.MAX_ITEMS_PER_COLUMN = AddonNS.Const.MAX_ROWS * AddonNS.Const.ITEMS_PER_ROW;


--@debug@
function GLOBAL_MyBagsExtra()
    return { arrangedItems, positionsInBags,
        categoryPositions }
end

function GLOBAL_MyBagsEnableDebug()
    AddonNS.printDebug = function(...) print(...) end
end

-- AddonNS.printDebug = function(...) print(...) end
--@end-debug@
