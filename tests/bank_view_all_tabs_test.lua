local fetchedBankType = nil

_G.Enum = {
    BankType = {
        Character = 1,
        Account = 2,
    },
}

_G.C_Bank = {
    FetchPurchasedBankTabData = function(bankType)
        fetchedBankType = bankType
        return {
            { ID = 41, name = "Fetched A" },
            { ID = 42, name = "Fetched B" },
        }
    end,
    CanPurchaseBankTab = function()
        return true
    end,
    HasMaxBankTabs = function()
        return false
    end,
}

_G.C_Container = {
    GetContainerNumSlots = function(tabID)
        if tabID == 10 then
            return 2
        end
        if tabID == 20 then
            return 1
        end
        if tabID == 30 then
            return 2
        end
        return 0
    end,
    GetContainerItemInfo = function(tabID, slotID)
        if tabID == 10 and slotID == 1 then
            return { itemID = 1001 }
        end
        if tabID == 30 and slotID == 2 then
            return { itemID = 1002 }
        end
        return nil
    end,
}

_G.CreateFrame = function()
    return {}
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
    SetNumColumns = function() end,
    GetBankCapacityState = function(tabIds)
        local total = 0
        local taken = 0
        for index = 1, #(tabIds or {}) do
            local tabID = tabIds[index]
            local slots = C_Container.GetContainerNumSlots(tabID)
            total = total + slots
            for slotID = 1, slots do
                if C_Container.GetContainerItemInfo(tabID, slotID) then
                    taken = taken + 1
                end
            end
        end
        return {
            taken = taken,
            free = total - taken,
            total = total,
        }
    end,
    printDebug = function() end,
    BagViewState = {
        IsCategoriesConfigMode = function()
            return false
        end,
    },
    Collapsed = {
        isCollapsed = function()
            return false
        end,
    },
}

local baselineChunk = assert(loadfile("utils/searchCategoryBaseline.lua"))
baselineChunk("MyBags", addonEnv)

local bankViewChunk = assert(loadfile("bankView.lua"))
bankViewChunk("MyBags", addonEnv)
local hooks = assert(addonEnv.BankViewTestHooks, "BankViewTestHooks should be exposed")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTrue(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
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

local function makeCategory(id)
    return {
        id = id,
        GetId = function(self)
            return self.id
        end,
    }
end

local function makeItems(prefix, count)
    local items = {}
    for index = 1, count do
        items[index] = { id = prefix .. "-" .. tostring(index) }
    end
    return items
end

local function extractCategoryPositions(categoryPositions)
    local list = {}
    for index = 1, #categoryPositions do
        local position = categoryPositions[index]
        if position.category then
            table.insert(list, position)
        end
    end
    return list
end

run("getPurchasedTabIdsForActiveType prefers panel cached data", function()
    fetchedBankType = nil
    local panel = {
        purchasedBankTabData = {
            { ID = 11, name = "First" },
            { ID = 12, name = "Second" },
        },
        GetActiveBankType = function()
            return Enum.BankType.Character
        end,
    }

    local tabIds, tabData = hooks.GetPurchasedTabIdsForActiveType(panel)
    assertEqual(#tabIds, 2, "two tab IDs should be returned")
    assertEqual(tabIds[1], 11, "first tab ID")
    assertEqual(tabIds[2], 12, "second tab ID")
    assertEqual(#tabData, 2, "tab data should mirror panel cache")
    assertEqual(fetchedBankType, nil, "FetchPurchasedBankTabData should not be used when panel cache is present")
end)

run("getPurchasedTabIdsForActiveType fetches data when panel cache is missing", function()
    local panel = {
        purchasedBankTabData = nil,
        GetActiveBankType = function()
            return Enum.BankType.Account
        end,
    }

    local tabIds = hooks.GetPurchasedTabIdsForActiveType(panel)
    assertEqual(#tabIds, 2, "fetched tab IDs should be returned")
    assertEqual(tabIds[1], 41, "first fetched tab ID")
    assertEqual(tabIds[2], 42, "second fetched tab ID")
    assertEqual(fetchedBankType, Enum.BankType.Account, "FetchPurchasedBankTabData should use panel active type")
end)

run("BuildVisibleTabIds returns a fast lookup set", function()
    local visible = hooks.BuildVisibleTabIds({ 3, 7, 11 })
    assertTrue(visible[3] == true, "tab 3 should be visible")
    assertTrue(visible[7] == true, "tab 7 should be visible")
    assertTrue(visible[11] == true, "tab 11 should be visible")
    assertTrue(visible[1] == nil, "other tabs should not be marked visible")
end)

run("ShouldRefreshForBagUpdate refreshes for nil and visible tab IDs only", function()
    local visible = hooks.BuildVisibleTabIds({ 6, 9 })
    assertTrue(hooks.ShouldRefreshForBagUpdate(visible, nil), "nil bagID should refresh")
    assertTrue(hooks.ShouldRefreshForBagUpdate(visible, 6), "visible tab should refresh")
    assertTrue(not hooks.ShouldRefreshForBagUpdate(visible, 5), "non-visible tab should not refresh")
end)

run("GenerateAllTabItemButtons creates buttons for all slots from all tabs", function()
    local inits = {}
    local acquireCount = 0
    local releaseCount = 0
    local panel = {
        itemButtonPool = {
            ReleaseAll = function()
                releaseCount = releaseCount + 1
            end,
            Acquire = function()
                acquireCount = acquireCount + 1
                return {
                    Init = function(_, bankType, tabID, slotID)
                        table.insert(inits, { bankType = bankType, tabID = tabID, slotID = slotID })
                    end,
                    Show = function() end,
                }
            end,
        },
    }

    hooks.GenerateAllTabItemButtons(panel, Enum.BankType.Character, { 10, 20 })
    assertEqual(releaseCount, 1, "pool should be reset once")
    assertEqual(acquireCount, 3, "should acquire one button per slot across all tabs")
    assertEqual(inits[1].tabID, 10, "first init tabID")
    assertEqual(inits[1].slotID, 1, "first init slot")
    assertEqual(inits[2].slotID, 2, "second init slot in first tab")
    assertEqual(inits[3].tabID, 20, "third init tabID")
    assertEqual(inits[3].slotID, 1, "first slot in second tab")
    assertEqual(inits[3].bankType, Enum.BankType.Character, "active bank type should be forwarded")
end)

run("BuildItemButtonsSignature includes bank type and per-tab slot counts", function()
    local signature = hooks.BuildItemButtonsSignature(Enum.BankType.Character, { 10, 20 })
    assertEqual(signature, "1|10:2|20:1", "signature should include active type and tab:slot pairs")
end)

run("HasAnyActiveItemButtons reports whether enumeration has entries", function()
    local emptyPanel = {
        EnumerateValidItems = function()
            return function()
                return nil
            end
        end,
    }
    local populatedPanel = {
        EnumerateValidItems = function()
            local done = false
            return function()
                if done then
                    return nil
                end
                done = true
                return {}
            end
        end,
    }
    assertTrue(not hooks.HasAnyActiveItemButtons(emptyPanel), "empty enumeration should report false")
    assertTrue(hooks.HasAnyActiveItemButtons(populatedPanel), "non-empty enumeration should report true")
end)

run("CountActiveItemButtons counts all enumerated buttons", function()
    local panel = {
        EnumerateValidItems = function()
            local index = 0
            return function()
                index = index + 1
                if index <= 3 then
                    return {}
                end
                return nil
            end
        end,
    }
    assertEqual(hooks.CountActiveItemButtons(panel), 3, "active button count should match enumeration size")
end)

run("CountExpectedButtonsForTabs sums slots across all tabs", function()
    assertEqual(hooks.CountExpectedButtonsForTabs({ 10, 20 }), 3, "expected buttons should sum all visible tab slots")
end)

run("ShouldShowPurchaseTabButton is true only when purchase is possible", function()
    C_Bank.CanPurchaseBankTab = function()
        return true
    end
    C_Bank.HasMaxBankTabs = function()
        return false
    end
    assertTrue(hooks.ShouldShowPurchaseTabButton(Enum.BankType.Character), "button should be visible when purchase is available")

    C_Bank.HasMaxBankTabs = function()
        return true
    end
    assertTrue(not hooks.ShouldShowPurchaseTabButton(Enum.BankType.Character), "button should be hidden when max tabs reached")
end)

run("ApplyBankScopeColumnCount updates only provided bank scope", function()
    local calls = {}
    addonEnv.SetNumColumns = function(selfRef, target, scope)
        table.insert(calls, { selfRef = selfRef, target = target, scope = scope })
    end

    hooks.ApplyBankScopeColumnCount(6, "bank-account")

    assertEqual(#calls, 1, "scope apply should update one scope")
    assertTrue(calls[1].selfRef == addonEnv, "method call should preserve AddonNS receiver")
    assertEqual(calls[1].target, 6, "call target")
    assertEqual(calls[1].scope, "bank-account", "provided scope should be used")
end)

run("ResolveTargetPanelSize uses locked size when search lock is active", function()
    local width, height = hooks.ResolveTargetPanelSize(740, 520, 700, 480, true)
    assertEqual(width, 700, "locked width should win while filtering")
    assertEqual(height, 480, "locked height should win while filtering")

    width, height = hooks.ResolveTargetPanelSize(740, 520, 700, 480, false)
    assertEqual(width, 740, "computed width should be used without lock")
    assertEqual(height, 520, "computed height should be used without lock")
end)

run("CalculateScaledDepositButtonWidth uses 70 percent width", function()
    assertEqual(hooks.CalculateScaledDepositButtonWidth(100), 70, "100 width should scale to 70")
    assertEqual(hooks.CalculateScaledDepositButtonWidth(87), 61, "width should round to nearest integer")
end)

run("ShouldShowBankResizeHandle stays visible during filtering preconditions", function()
    assertTrue(hooks.ShouldShowBankResizeHandle(true, true, false), "handle should show while frame and panel are visible out of combat")
    assertTrue(not hooks.ShouldShowBankResizeHandle(false, true, false), "handle should hide when bank frame is hidden")
    assertTrue(not hooks.ShouldShowBankResizeHandle(true, false, false), "handle should hide when panel is hidden")
    assertTrue(not hooks.ShouldShowBankResizeHandle(true, true, true), "handle should hide in combat")
end)

run("ShouldRetryForMissingItemData retries only when data is missing", function()
    assertTrue(hooks.ShouldRetryForMissingItemData(true, false, 0), "retry should occur while data is not ready")
    assertTrue(hooks.ShouldRetryForMissingItemData(true, false, 5), "retry should continue before max attempts")
    assertTrue(not hooks.ShouldRetryForMissingItemData(true, false, 6), "retry should stop at max attempts")
    assertTrue(not hooks.ShouldRetryForMissingItemData(true, true, 0), "do not retry when data exists")
    assertTrue(not hooks.ShouldRetryForMissingItemData(false, false, 0), "do not retry when there are no buttons")
end)

run("SearchCategoryBaseline keeps header category visible under search even without matching items", function()
    local catA = { id = "cat-a" }
    local item = { id = "item-a" }
    local arrangedItems = {}

    local inserted = addonEnv.SearchCategoryBaseline:Add(arrangedItems, catA, item, false, true)
    assertTrue(inserted == false, "non-matching item should not be inserted")
    assertTrue(arrangedItems[catA] ~= nil, "category should still be seeded under active search")
    assertEqual(#arrangedItems[catA], 0, "seeded category should be empty when item does not match")

    inserted = addonEnv.SearchCategoryBaseline:Add(arrangedItems, catA, item, true, true)
    assertTrue(inserted == true, "matching item should be inserted")
    assertEqual(#arrangedItems[catA], 1, "seeded category should contain matching item")
end)

run("PlaceItemsAndBuildHeaders packs small categories on the same row in normal mode", function()
    addonEnv.BagViewState.IsCategoriesConfigMode = function()
        return false
    end
    addonEnv.Collapsed.isCollapsed = function()
        return false
    end

    local catA = makeCategory("cus-a")
    local catB = makeCategory("cus-b")
    local aItems = makeItems("a", 2)
    local bItems = makeItems("b", 1)
    local assignments = {
        {
            { category = catA, items = aItems, itemsCount = #aItems },
            { category = catB, items = bItems, itemsCount = #bItems },
        },
    }

    local positions, categoryPositions = hooks.PlaceItemsAndBuildHeaders("bank-character", nil, assignments, 10)
    local placedCategories = extractCategoryPositions(categoryPositions)
    assertEqual(#placedCategories, 2, "two categories should be placed")
    assertEqual(placedCategories[1].y, placedCategories[2].y, "categories should share the same row header")
    assertTrue(placedCategories[2].x > placedCategories[1].x, "second category should start to the right")
    assertTrue(positions[aItems[1]].y == positions[bItems[1]].y, "items should be placed on the same row")
end)

run("PlaceItemsAndBuildHeaders starts a new row when the next category would overflow", function()
    addonEnv.BagViewState.IsCategoriesConfigMode = function()
        return false
    end
    addonEnv.Collapsed.isCollapsed = function()
        return false
    end

    local catA = makeCategory("cus-overflow-a")
    local catB = makeCategory("cus-overflow-b")
    local aItems = makeItems("oa", 3)
    local bItems = makeItems("ob", 2)
    local assignments = {
        {
            { category = catA, items = aItems, itemsCount = #aItems },
            { category = catB, items = bItems, itemsCount = #bItems },
        },
    }

    local _, categoryPositions = hooks.PlaceItemsAndBuildHeaders("bank-account", nil, assignments, 10)
    local placedCategories = extractCategoryPositions(categoryPositions)
    assertEqual(#placedCategories, 2, "two categories should be placed")
    assertTrue(placedCategories[2].y > placedCategories[1].y, "second category should move to a lower row")
    assertEqual(placedCategories[2].x, placedCategories[1].x, "new row category should restart at column left")
end)

run("PlaceItemsAndBuildHeaders keeps categories full-width and separated in config mode", function()
    addonEnv.BagViewState.IsCategoriesConfigMode = function()
        return true
    end
    addonEnv.Collapsed.isCollapsed = function()
        return false
    end

    local catA = makeCategory("cus-edit-a")
    local catB = makeCategory("cus-edit-b")
    local aItems = makeItems("ea", 2)
    local bItems = makeItems("eb", 1)
    local assignments = {
        {
            { category = catA, items = aItems, itemsCount = #aItems },
            { category = catB, items = bItems, itemsCount = #bItems },
        },
    }

    local _, categoryPositions = hooks.PlaceItemsAndBuildHeaders("bank-character", nil, assignments, 10)
    local placedCategories = extractCategoryPositions(categoryPositions)
    assertEqual(#placedCategories, 2, "two categories should be placed")
    assertTrue(placedCategories[2].y > placedCategories[1].y, "config mode should separate categories by rows")
    assertEqual(placedCategories[1].width, 40, "config mode category width should span full row")
    assertEqual(placedCategories[2].width, 40, "config mode category width should span full row")
end)

run("PlaceItemsAndBuildHeaders keeps collapsed headers full-width and row-isolated", function()
    addonEnv.BagViewState.IsCategoriesConfigMode = function()
        return false
    end

    local collapsedById = {
        ["cus-collapsed"] = true,
        ["cus-live"] = false,
    }
    addonEnv.Collapsed.isCollapsed = function(category)
        return collapsedById[category:GetId()] == true
    end

    local collapsedCategory = makeCategory("cus-collapsed")
    local liveCategory = makeCategory("cus-live")
    local collapsedItems = makeItems("ca", 2)
    local liveItems = makeItems("cb", 1)
    local assignments = {
        {
            { category = collapsedCategory, items = collapsedItems, itemsCount = #collapsedItems },
            { category = liveCategory, items = liveItems, itemsCount = #liveItems },
        },
    }

    local _, categoryPositions = hooks.PlaceItemsAndBuildHeaders("bank-character", nil, assignments, 10)
    local placedCategories = extractCategoryPositions(categoryPositions)
    assertEqual(#placedCategories, 2, "two categories should be placed")
    assertEqual(placedCategories[1].width, 40, "collapsed header should use full-width row")
    assertEqual(placedCategories[1].blockHeight, 20, "collapsed header block height should only include header")
    assertTrue(placedCategories[2].y > placedCategories[1].y, "next category should start on a separate row")
end)

run("GetBackgroundHintFrame resolves hovered category drop frame by hit-test", function()
    local view = {
        dropFrames = {
            {
                id = "drop-11",
                MyBagsScope = "bank-character",
                ItemCategory = {},
                IsShown = function() return true end,
                GetLeft = function() return 120 end,
                GetRight = function() return 220 end,
                GetBottom = function() return 90 end,
                GetTop = function() return 190 end,
            },
            {
                id = "drop-12",
                MyBagsScope = "bank-character",
                ItemCategory = {},
                IsShown = function() return true end,
                GetLeft = function() return 240 end,
                GetRight = function() return 320 end,
                GetBottom = function() return 90 end,
                GetTop = function() return 190 end,
            },
        },
    }
    local frame = {
        GetEffectiveScale = function() return 1 end,
        GetLeft = function() return 100 end,
        GetBottom = function() return 50 end,
        GetWidth = function() return 400 end,
        GetHeight = function() return 200 end,
    }

    local oldGetCursorPosition = _G.GetCursorPosition
    _G.GetCursorPosition = function()
        return 180, 140
    end

    local hintFrame = hooks.GetBackgroundHintFrame(view, frame, "bank-character")
    _G.GetCursorPosition = oldGetCursorPosition

    assertTrue(hintFrame.id == "drop-11", "mapped drop frame should be returned")
end)

run("GetBackgroundColumnFallbackHintFrame resolves last category in hovered column", function()
    addonEnv.Categories = {
        GetLastCategoryInColumn = function(_, columnNo, scope)
            if columnNo == 2 and scope == "bank-character" then
                return {
                    GetId = function()
                        return "cus-22"
                    end,
                }
            end
            return nil
        end,
    }

    local view = {
        ResolveDropColumn = function()
            return 2
        end,
        dropFrameByCategoryId = {
            ["cus-22"] = { id = "drop-22" },
        },
    }
    local frame = {
        GetEffectiveScale = function() return 1 end,
        GetLeft = function() return 100 end,
        GetBottom = function() return 50 end,
        GetWidth = function() return 400 end,
        GetHeight = function() return 200 end,
    }

    local oldGetCursorPosition = _G.GetCursorPosition
    _G.GetCursorPosition = function()
        return 280, 140
    end

    local hintFrame = hooks.GetBackgroundColumnFallbackHintFrame(view, frame, "bank-character")
    _G.GetCursorPosition = oldGetCursorPosition

    assertTrue(hintFrame.id == "drop-22", "fallback should map to last category drop frame in column")
end)

run("GetBankCapacityState returns taken free and total slot counts", function()
    local state = hooks.GetBankCapacityState({ 10, 30 })
    assertEqual(state.taken, 2, "two slots should be taken")
    assertEqual(state.total, 4, "total slots should include all tabs")
    assertEqual(state.free, 2, "remaining slots should be computed")
end)

local function makeSetIterator(values)
    local set = {}
    for index = 1, #values do
        set[values[index]] = true
    end
    return next, set, nil
end

local function collectMerged(firstValues, secondValues)
    local iter1, state1, init1 = makeSetIterator(firstValues)
    local iter2, state2, init2 = makeSetIterator(secondValues)
    local iterator = hooks.MergeIterators(iter1, state1, init1, iter2, state2, init2)

    local seenCounts = {}
    local order = {}
    for value in iterator do
        seenCounts[value] = (seenCounts[value] or 0) + 1
        table.insert(order, value)
    end
    return seenCounts, order
end

run("MergeIterators yields every value from both iterators exactly once", function()
    local first = { "bank-1", "bank-2", "bank-3" }
    local second = { "all-tabs-1", "all-tabs-2" }
    local seenCounts, order = collectMerged(first, second)

    assertEqual(#order, #first + #second, "merged iteration should visit each button once")
    for index = 1, #first do
        assertEqual(seenCounts[first[index]], 1, "first iterator value " .. first[index] .. " should appear once")
    end
    for index = 1, #second do
        assertEqual(seenCounts[second[index]], 1, "second iterator value " .. second[index] .. " should appear once")
    end
end)

run("MergeIterators does not repeat the first value of the second iterator", function()
    local seenCounts, order = collectMerged({}, { "all-tabs-1", "all-tabs-2" })

    assertEqual(#order, 2, "only the second iterator values should be visited")
    assertEqual(seenCounts["all-tabs-1"], 1, "first value of the second iterator should not be repeated")
    assertEqual(seenCounts["all-tabs-2"], 1, "second value of the second iterator should be visited")
end)

run("MergeIterators handles an empty second iterator", function()
    local seenCounts, order = collectMerged({ "bank-1" }, {})

    assertEqual(#order, 1, "only the first iterator values should be visited")
    assertEqual(seenCounts["bank-1"], 1, "first iterator value should be visited once")
end)
