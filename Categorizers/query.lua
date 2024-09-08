local addonName, AddonNS = ...
AddonNS = AddonNS or {}
local QueryCategorizer = {};
AddonNS.QueryCategories = {}

AddonNS.Categories:RegisterCategorizer("Query", QueryCategorizer, false);
local name = ITEM_QUALITY_COLORS[Enum.ItemQuality.Poor].hex .. "Junk";
function QueryCategorizer:GetConstantCategories()
    return { name }
end

local ValueType = {
    STRING = 1,
    NUMBER = 2,
    BOOL = 3,
    -- ITEM_QUALITY = 4,
}

function trim(text)
    return text:match("^%s*(.-)%s*$")
end

local OpEnum = { AND = 1, OR = 2, NOT = 3 };

function prepare(query)
    query = string.gsub(query, "%(", " ( ")
    query = string.gsub(query, "%)", " ) ")
    query = string.gsub(query, "([%=%!%~%<%>]+)", " %1 ")
    query = string.gsub(query, " ~= ", " != ")
    query = string.gsub(query, " <> ", " != ")
    query = string.gsub(query, " [Aa][Nn][Dd] ", " AND ")
    query = string.gsub(query, " [Aa][Nn][Dd] ", " AND ")
    query = string.gsub(query, " [Nn][Oo][Tt] ", " NOT ")
    query = string.gsub(query, " [Oo][Rr] ", " OR ")
    query = string.gsub(query, "%s%s+", " ")
    return query;
end

-- -- print(prepare("()and<=(asd)"))
local function toboolean(text)
    return text == "true" and true or false
end
local Comparators = {
    [ValueType.STRING] = {
        ["="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    -- print(retriver, itemInfo, value)
                    -- print(retriver(itemInfo))
                    return retriver(itemInfo):match(value);
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return not retriver(itemInfo):match(value);
                end
            end,
        },
    },
    [ValueType.NUMBER] = {
        ["="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return retriver(itemInfo) == tonumber(value);
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return retriver(itemInfo) ~= tonumber(value);
                end
            end,
        },
        [">"] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return retriver(itemInfo) > tonumber(value);
                end
            end,
        },
        [">="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return retriver(itemInfo) >= tonumber(value);
                end
            end,
        },

        ["<"] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return retriver(itemInfo) < tonumber(value);
                end
            end,
        },
        ["<="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return retriver(itemInfo) <= tonumber(value);
                end
            end,
        },
    },
    [ValueType.BOOL] = {
        ["="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return toboolean(value) == retriver(itemInfo);
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    return toboolean(value) ~= retriver(itemInfo);
                end
            end,
        },
    },

}


local Retrivers = {
    stackCount = {
        type = ValueType.NUMBER
    },
    expansionID = {
        type = ValueType.NUMBER
    },
    quality = {
        type = ValueType.NUMBER
    },
    isReadable = {
        type = ValueType.BOOL
    },
    hasLoot = {
        type = ValueType.BOOL
    },
    hasNoValue = {
        type = ValueType.BOOL
    },
    itemID = {
        type = ValueType.NUMBER
    },
    isBound = {
        type = ValueType.BOOL
    },
    itemName = {
        type = ValueType.STRING
    },
    ilvl = {
        type = ValueType.NUMBER
    },
    itemMinLevel = {
        type = ValueType.NUMBER
    },
    itemType = {
        type = ValueType.NUMBER
    },
    itemSubType = {
        type = ValueType.NUMBER
    },
    inventoryType = {
        type = ValueType.NUMBER
    },
    sellPrice = {
        type = ValueType.NUMBER
    },
    isCraftingReagent = {
        type = ValueType.BOOL
    },
    isQuestItem = {
        type = ValueType.BOOL
    },
    questID = {
        type = ValueType.NUMBER
    },
    isQuestItemActive = {
        type = ValueType.BOOL
    },
    bindType = {
        type = ValueType.NUMBER
    },
}

local function genericRetriverFunction(name)
    return function(itemInfo)
        -- print("genericRetriverFunction", itemInfo)
        -- print("genericRetriverFunction2", itemInfo[name])
        -- print(itemInfo[name])
        return itemInfo[name]
    end
end
for key, value in pairs(Retrivers) do
    if (not value.func) then
        value.func = genericRetriverFunction(key);
    end
end


local function GetRetiver(name, comparison, value)
    local retriver = Retrivers[name];
    if (not retriver) then
        -- print("Error GetRetiver:" .. name .. ":");
    end
    local func = Retrivers[name].func;
    local valueType = Retrivers[name].type;

    -- local func = function(itemInfo)
    -- if not itemInfo.retrived[name] then
    -- itemInfo.retrived[name] = func(itemInfo);
    -- end
    -- return itemInfo.retrived[name];
    -- end
    -- print(comparison)
    return Comparators[valueType][comparison].createNew(func, value);
end


local alwaysFalse = function() end
local space = ""
function evaluateLeaf(leafQuery)
    leafQuery = trim(leafQuery);
    -- print("evalLeaf:", leafQuery);
    local name, comparison, value = leafQuery:match("^(%S+) (%S+) (%S+)$")
    if (not name) then
        -- print("Error evaluateLeaf", leafQuery);
        return alwaysFalse
    else
        return GetRetiver(name, comparison, value);
    end
end

local function pumpUp()
    space = space .. "_ "
end
local function pumpDown()
    space = space:sub(3);
end
local function evaluate(query)
    -- print("eval:", query)

    query = trim(query);

    local andFunctions;
    local orFunctions = {};
    local orFunction = function(itemInfo)
        -- print(space .. "orFunctionsCount", #orFunctions)
        if (#orFunctions == 0) then return false; end

        for _, v in ipairs(orFunctions) do
            -- print(space .. "<OR>", v)
            pumpUp()
            local val = v(itemInfo);
            pumpDown()
            -- print(space .. "</OR>", v, val)
            if val then
                return true
            end
        end
        return false
    end
    local function newAndFunction()
        local localAndFunctions = {};
        andFunctions = localAndFunctions;
        local andFunction = function(itemInfo)
            -- print(space .. "andFunctionsCount", #andFunctions)
            for _, v in ipairs(localAndFunctions) do
                -- print(space .. "<AND>", v)
                pumpUp()
                local val = v(itemInfo);
                pumpDown()
                -- print(space .. "</AND>", v, val)
                if not val then return false end
            end
            if (#localAndFunctions == 0) then return false; end
            return true;
        end;
        table.insert(orFunctions, andFunction);
    end
    newAndFunction()

    local tokenString
    local nextOp = OpEnum.AND

    while (#query > 0) do
        query = trim(query);
        -- print("--", nextOp)
        tokenString = query:match("^%b()");
        -- -- print("ts", tokenString)
        if (tokenString) then
            local subQuery = tokenString:sub(2, -2)
            local func = evaluate(subQuery)
            local notFunc;
            if (nextOp) then
                if nextOp == OpEnum.NOT then
                    notFunc = function(itemInfo) return not func(itemInfo) end
                end
                -- print("adding bound", func)
                table.insert(andFunctions, notFunc or func);
            else
                -- print("error ()");
            end
            nextOp = nil;
        end
        if (not tokenString) then
            tokenString = query:match("^AND ");

            if (tokenString) then
                if (not nextOp) then
                    -- print("AND")
                    nextOp = OpEnum.AND;
                else
                    -- print("Error AND")
                end
            end
        end
        if (not tokenString) then
            tokenString = query:match("^OR ");
            if (tokenString) then
                if (not nextOp) then
                    -- print("OR")
                    nextOp = OpEnum.AND;
                    newAndFunction()
                else
                    -- print("Error OR")
                end
            end
        end
        if (not tokenString) then
            tokenString = query:match("^NOT ");

            if (tokenString) then
                if (nextOp == OpEnum.AND) then
                    -- print("NOT")
                    nextOp = OpEnum.NOT;
                else
                    -- print("Error NOT")
                end
            end
        end

        if (not tokenString) then
            tokenString = query:match("(.*) AND ") or query:match("(.*) OR ") or query:match("(.*) NOT ") or query:match("(.*)");
            if (tokenString) then
                local func = evaluateLeaf(tokenString)
                local notFunc;
                if (nextOp) then
                    if nextOp == OpEnum.NOT then
                        notFunc = function(itemInfo) return not func(itemInfo) end
                    end
                    -- print("adding leaf", func)
                    table.insert(andFunctions, notFunc or func);
                else
                    -- print("error REST", nextOp);
                end
                nextOp = nil;
            end
        end
        if (not tokenString) then
            -- print("Error, uncaught situation: ", query)
            return;
        end
        query = trim(query:sub(#tokenString + 1));
        tokenString = nil;
    end
    return orFunction;
end

local queryCategories = {
    ["CraftingReagent"] = "isCraftingReagent = true",
    ["Recipes"] = "itemType = 9"
}

local queryFunctions = {
}

function QueryCategorizer:Categorize(itemID, itemButton)
    local itemInfo = C_Container
        .GetContainerItemInfo(itemButton:GetBagID(), itemButton:GetID())

    local inventoryType = C_Item
        .GetItemInventoryTypeByID(itemID); -- https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInventoryType

    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent =
        C_Item.GetItemInfo(itemInfo.hyperlink)
    local questInfo = C_Container
        .GetContainerItemQuestInfo(itemButton:GetBagID(), itemButton:GetID());
    local isQuestItem = questInfo
        .isQuestItem;
    local questID = questInfo
        .questID;
    local isActive = questInfo
        .isActive;

    local allItemInfo = {
        stackCount = itemInfo.stackCount,


        quality = itemInfo.quality,

        isReadable = itemInfo.isReadable,

        hasLoot = itemInfo.hasLoot,

        hasNoValue = itemInfo.hasNoValue,

        itemID = itemInfo.itemID,

        isBound = itemInfo.isBound,

        itemName = itemInfo.itemName,

        ilvl = itemLevel
        ,
        itemMinLevel = itemMinLevel
        ,
        itemType = classID
        ,
        itemSubType = subclassID
        ,
        inventoryType = inventoryType
        ,
        sellPrice = sellPrice
        ,
        isCraftingReagent = isCraftingReagent
        ,
        isQuestItem = isQuestItem
        ,
        questID = questID
        ,
        isQuestItemActive = isActive
        ,
        bindType = bindType,
        expansionID = expansionID,

    }

    for categoryName, func in pairs(queryFunctions) do
        -- print("start check", categoryName)
        if (func(allItemInfo)) then
            return categoryName
        end
    end



    -- return itemInfo.quality == Enum.ItemQuality.Poor and name;
end

function AddonNS.QueryCategories:GetQuery(categoryName)
    return queryCategories[categoryName] or "";
end

function AddonNS.QueryCategories:SetQuery(categoryName, query)
    queryCategories[categoryName] = query;
    queryFunctions[categoryName] = evaluate(prepare(query));
end

function AddonNS.QueryCategories:OnInitialize()
    AddonNS.db.queryCategories = AddonNS.db.queryCategories or queryCategories;
    queryCategories = AddonNS.db.queryCategories;

    for key, value in pairs(queryCategories) do
        print("tutaj", key, valye)
        queryFunctions[key] = evaluate(prepare(value));
    end
end


local function test()
    local query = "isCraftingReagent = false or isCraftingReagent = true" -- AND (itemType = 'weapon' AND ilvl >= 20)

    -- local query = " (type = 'weapon' AND level >= 20) OR (name = 'Epic')"
    local prepareed = prepare(query);
    print(prepareed)
    local func = evaluate(prepareed);
    local testItem = {
        itemName = "Epic",
        isCraftingReagent = true,
        itemType = 3,
        ilvl = 120
    }
    print("Lets go!")
    print(func(testItem))
end

-- test()

AddonNS.Events:OnInitialize(AddonNS.QueryCategories.OnInitialize)
