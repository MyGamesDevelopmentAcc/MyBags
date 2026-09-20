_G.CreateFramePool = function()
    local pool = {
        activeObjects = {},
    }

    function pool:Acquire()
        local object = {}
        self.activeObjects[object] = true
        return object
    end

    function pool:ReleaseAll()
        self.activeObjects = {}
    end

    function pool:EnumerateActive()
        return next, self.activeObjects, nil
    end

    return pool
end

local addonEnv = {
    Const = {
        ITEM_SPACING = 4,
        CATEGORY_HEIGHT = 20,
        ITEMS_PER_ROW = 4,
        COLUMN_SPACING = 12,
        Events = {
            COLLAPSED_CHANGED = "COLLAPSED_CHANGED",
            CATEGORIZER_CATEGORIES_UPDATED = "CATEGORIZER_CATEGORIES_UPDATED",
        },
    },
    Events = {
        OnInitialize = function() end,
    },
    ContainerItemInfoCache = {
        Get = function(_, bagID, slotID)
            return C_Container.GetContainerItemInfo(bagID, slotID)
        end,
        InvalidateBag = function() end,
        InvalidateAll = function() end,
    },
    CustomCategories = {
        GetItemQueryPayload = function(_, itemID)
            return { itemID = itemID, itemType = itemID }
        end,
    },
    QueryCategories = {
        EvaluateSearchUnion = function(_, defaultMatch, evaluator, payload)
            if defaultMatch then
                return true, false
            end
            local queryMatch = evaluator(payload)
            return queryMatch, queryMatch
        end,
        CompileAdHoc = function(_, queryText)
            if queryText == "itemType = 42" then
                return function(payload)
                    return payload.itemType == 42
                end
            end
            return nil
        end,
    },
    printDebug = function() end,
}

local baselineChunk = assert(loadfile("utils/searchCategoryBaseline.lua"))
baselineChunk("MyBags", addonEnv)

_G.C_Container = {
    GetContainerItemInfo = function(bagID, slotID)
        if bagID == 1 and slotID == 1 then
            return { itemID = 42, isFiltered = true }
        end
        if bagID == 1 and slotID == 2 then
            return { itemID = 9, isFiltered = true }
        end
        return nil
    end,
}

local bankViewChunk = assert(loadfile("bankView.lua"))
bankViewChunk("MyBags", addonEnv)
local hooks = assert(addonEnv.BankViewTestHooks, "BankViewTestHooks should be exposed")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function run(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        print("✓ " .. name)
    else
        print("✗ " .. name)
        error(err)
    end
end

run("evaluateSearchVisibility keeps default matches without query flag", function()
    local includeInSearch, queryMatch = hooks.EvaluateSearchVisibility(true, function() return true end, { itemID = 7 }, {})
    assertEqual(includeInSearch, true, "default match should be included")
    assertEqual(queryMatch, false, "default match should not mark query match")
end)

run("evaluateSearchVisibility includes query-only matches", function()
    local includeInSearch, queryMatch = hooks.EvaluateSearchVisibility(false, function(payload)
        return payload.itemType == 42
    end, { itemID = 42 }, {})
    assertEqual(includeInSearch, true, "query-only match should be included")
    assertEqual(queryMatch, true, "query-only match should mark query match")
end)

run("evaluateSearchVisibility excludes when default and query both fail", function()
    local includeInSearch, queryMatch = hooks.EvaluateSearchVisibility(false, function() return false end, { itemID = 9 }, {})
    assertEqual(includeInSearch, false, "item should be excluded when no branch matches")
    assertEqual(queryMatch, false, "query match should be false when evaluator fails")
end)

run("resolveIncludeInSearch keeps default matches when search is inactive", function()
    local itemButton = {}
    local includeInSearch, queryMatch = hooks.ResolveIncludeInSearch(itemButton, { itemID = 7, isFiltered = true }, false, nil)
    assertEqual(includeInSearch, true, "item should default-match when search is inactive")
    assertEqual(queryMatch, false, "there is no query match without an active search")
end)

run("resolveIncludeInSearch honors a cached default search match", function()
    local itemButton = { _myBagsDefaultSearchMatch = false }
    local includeInSearch = hooks.ResolveIncludeInSearch(itemButton, { itemID = 9, isFiltered = false }, true, nil)
    assertEqual(includeInSearch, false, "cached default match should be used instead of recomputing from isFiltered")
end)

run("resolveIncludeInSearch falls back to isFiltered when no cached default match exists", function()
    local itemButton = {}
    local includeInSearch = hooks.ResolveIncludeInSearch(itemButton, { itemID = 9, isFiltered = true }, true, nil)
    assertEqual(includeInSearch, false, "filtered item without a cached default should not default-match")
end)

run("resolveIncludeInSearch includes query-union matches for a filtered item", function()
    local itemButton = { _myBagsDefaultSearchMatch = false }
    local evaluator = addonEnv.QueryCategories:CompileAdHoc("itemType = 42")
    local includeInSearch, queryMatch = hooks.ResolveIncludeInSearch(itemButton, { itemID = 42, itemType = 42, isFiltered = true }, true, evaluator)
    assertEqual(includeInSearch, true, "query-only match should be included")
    assertEqual(queryMatch, true, "query-only match should mark query match")
end)

run("resolveIncludeInSearch excludes a filtered item that fails the query", function()
    local itemButton = { _myBagsDefaultSearchMatch = false }
    local evaluator = addonEnv.QueryCategories:CompileAdHoc("itemType = 42")
    local includeInSearch = hooks.ResolveIncludeInSearch(itemButton, { itemID = 9, itemType = 9, isFiltered = true }, true, evaluator)
    assertEqual(includeInSearch, false, "item that fails both default and query should be excluded")
end)
