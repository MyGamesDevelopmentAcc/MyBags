package.path = package.path .. ";./?.lua;./?/init.lua"

local harness = require("tests.integration.persistence.harness")

local function deep_equal(a, b, seen)
    if a == b then
        return true
    end
    local typeA, typeB = type(a), type(b)
    if typeA ~= typeB then
        return false, string.format("Type mismatch: %s vs %s", typeA, typeB)
    end
    if typeA ~= "table" then
        return false, string.format("Value mismatch: %s vs %s", tostring(a), tostring(b))
    end
    seen = seen or {}
    if seen[a] and seen[a][b] then
        return true
    end
    seen[a] = seen[a] or {}
    seen[a][b] = true
    local visited = {}
    for k, v in pairs(a) do
        local ok, err = deep_equal(v, b[k], seen)
        if not ok then
            return false, string.format("Key %s: %s", tostring(k), err or "mismatch")
        end
        visited[k] = true
    end
    for k in pairs(b) do
        if not visited[k] then
            return false, string.format("Unexpected key in second table: %s", tostring(k))
        end
    end
    return true
end

local function assert_equal(expected, actual, message)
    local ok, err = deep_equal(expected, actual)
    if not ok then
        error((message or "tables differ") .. ": " .. err, 2)
    end
end

local function assert_true(condition, message)
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

local function item_button(bag, slot)
    return {
        GetBagID = function() return bag end,
        GetID = function() return slot end,
    }
end

local function install_item_query_stubs(itemID, options)
    options = options or {}
    _G.ITEM_SPELL_TRIGGER_ONUSE = options.onUsePrefix or "Use:"
    _G.ItemLocation = {
        CreateFromBagAndSlot = function(bagID, slotID)
            return { bagID = bagID, slotID = slotID }
        end,
    }
    _G.C_Item = {
        GetItemInfo = function()
            return "TestItem", nil, nil, 450, 1, nil, nil, nil, nil, nil, 99, options.classID or 3, options.subclassID or 0,
                0, 0, 0, false, options.description or "Test description"
        end,
        GetItemInventoryTypeByID = function()
            return options.inventoryType or 0
        end,
        GetItemSpell = function()
            return options.itemSpellName
        end,
        IsAnimaItemByID = function()
            return options.isAnimaItem == true
        end,
        IsArtifactPowerItem = function()
            return options.isArtifactPowerItem == true
        end,
        IsCorruptedItem = function()
            return options.isCorruptedItem == true
        end,
        IsBoundToAccountUntilEquip = function()
            return options.isWarbound == true
        end,
    }
    _G.C_TransmogCollection = {
        GetItemInfo = function()
            if options.noTransmogSource == true then
                return 0, nil
            end
            return 0, options.transmogSourceID or 1234
        end,
        GetSourceInfo = function()
            return { isCollected = options.isTransmogCollected == true }
        end,
    }
    _G.C_TooltipInfo = {
        GetItemByID = function()
            return {
                lines = options.tooltipLines or {},
            }
        end,
    }
    rawset(_G.C_Container, "GetContainerItemQuestInfo", function()
        return {}
    end)
    rawset(_G.C_Container, "GetContainerItemInfo", function()
        return { itemID = itemID, hyperlink = "item:" .. tostring(itemID) }
    end)
end

local function custom_snapshot(snapshot)
    return snapshot.userCategories or {}
end

local function has_category_entry(assignments, category)
    for _, column in ipairs(assignments or {}) do
        for _, entry in ipairs(column or {}) do
            if entry.category:GetId() == category:GetId() then
                return true
            end
        end
    end
    return false
end

local function raw_by_name(snapshot, name)
    local custom = custom_snapshot(snapshot)
    for rawId, data in pairs(custom.categories or {}) do
        if data.name == name then
            return rawId, data
        end
    end
    return nil
end

local function layout_columns(snapshot)
    local columns = {}
    local layout = snapshot.layout or {}
    for index, column in ipairs(layout.columns or {}) do
        columns[index] = {}
        for _, id in ipairs(column) do
            table.insert(columns[index], id)
        end
    end
    return columns
end

local function count_layout_id(columns, targetId)
    local count = 0
    for _, column in ipairs(columns) do
        for _, id in ipairs(column) do
            if id == targetId then
                count = count + 1
            end
        end
    end
    return count
end

local EXPECTED_TELEPORT_ITEMS = {
    147869, 37863, 63207, 63353, 208066, 217956, 18149, 217930, 41255, 44655, 200613, 110560,
    6948, 140192, 173373, 65274, 46874, 21711, 180817, 234389, 116413, 249699, 250411, 238727,
}

local function getExpectedDefaultQueries(ctx)
    local expected = {}
    for _, category in ipairs(ctx.AddonNS.CustomDefaultImportPayload.categories) do
        expected[category.name] = {
            query = category.query,
            alwaysVisible = category.alwaysVisible,
        }
    end
    return expected
end

local function expected_default_layout(snapshot, configuredColumns)
    local out = {}
    for columnIndex = 1, #configuredColumns do
        out[columnIndex] = {}
        for _, entry in ipairs(configuredColumns[columnIndex]) do
            if entry == "new-singleton" or entry == "unassigned" then
                table.insert(out[columnIndex], entry)
            else
                table.insert(out[columnIndex], "cus-" .. assert(raw_by_name(snapshot, entry)))
            end
        end
    end
    return out
end

run("fresh install seeds defaults", function()
    local ctx = harness.new()
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local expectedDefaultQueries = getExpectedDefaultQueries(ctx)
    assert_true(custom.id == "cus", "custom bucket seeded")
    assert_true(custom.schemaVersion == 2, "custom schema version seeded")
    local defaultsCount = 0
    for name, metadata in pairs(expectedDefaultQueries) do
        local _, data = raw_by_name(snapshot, name)
        assert_true(data ~= nil, "default category exists: " .. name)
        assert_true(data.query == metadata.query, "default query persisted: " .. name)
        if metadata.alwaysVisible == true then
            assert_true(data.alwaysVisible == true, "alwaysVisible persisted: " .. name)
        end
        defaultsCount = defaultsCount + 1
    end
    local persistedCount = 0
    for _ in pairs(custom.categories or {}) do
        persistedCount = persistedCount + 1
    end
    assert_true(persistedCount == defaultsCount, "all persisted custom categories are seeded defaults")
    local _, teleport = raw_by_name(snapshot, "Teleport")
    assert_equal(EXPECTED_TELEPORT_ITEMS, teleport.items, "teleport category seeds manual items")
    assert_true(snapshot.layout.columnCount == #ctx.AddonNS.CustomDefaultLayoutColumns, "layout column count defaults to configured count")
    assert_equal(expected_default_layout(snapshot, ctx.AddonNS.CustomDefaultLayoutColumns), snapshot.layout.columns, "layout columns seeded")
    assert_equal({}, snapshot.layout.collapsed, "collapsed state empty")
    assert_equal({}, snapshot.itemOrder, "item order initialised")
    assert_true(snapshot.categorizers == nil or snapshot.categorizers.cus == nil, "legacy custom bucket removed")
    assert_true(snapshot.categories == nil, "old custom categories bucket removed")
end)

run("built-in default payload remains import-valid", function()
    local ctx = harness.new()
    local payload = ctx.AddonNS.CustomDefaultImportPayload
    local expectedDefaultQueries = getExpectedDefaultQueries(ctx)
    assert_true(type(payload) == "table", "default payload is available")
    local preview = ctx.AddonNS.CustomCategories:PreviewImport(payload)
    local expectedCount = 0
    for _ in pairs(expectedDefaultQueries) do
        expectedCount = expectedCount + 1
    end
    assert_true(#preview.toCreate == expectedCount, "default payload contains expected category count")
end)

run("empty categories reseed defaults and reset layout", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 9,
                categories = {},
            },
            layout = {
                columnCount = 3,
                columns = {
                    { "cus-999", "eq-1" },
                    { "cus-123" },
                    { "unassigned" },
                },
                collapsed = { ["cus-999"] = true },
            },
        },
    })
    ctx:events():fire_game("PLAYER_LOGOUT")
    local snapshot = ctx:snapshot()
    local expectedDefaultQueries = getExpectedDefaultQueries(ctx)
    assert_equal(expected_default_layout(snapshot, ctx.AddonNS.CustomDefaultLayoutColumns), snapshot.layout.columns, "empty custom categories trigger default layout reset")
    assert_equal({}, snapshot.layout.collapsed, "collapsed entries cleared during reseed")
    for name in pairs(expectedDefaultQueries) do
        local _, data = raw_by_name(snapshot, name)
        assert_true(data ~= nil, "reseeded category exists: " .. name)
    end
end)

run("non-empty categories do not auto-seed defaults or reset layout", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = {
                        name = "KeepMe",
                        query = "itemType = 4",
                        items = {},
                    },
                },
            },
            layout = {
                columnCount = 3,
                columns = {
                    { "cus-1", "eq-1" },
                    {},
                    { "unassigned" },
                },
                collapsed = { ["cus-1"] = true },
            },
        },
    })
    ctx:events():fire_game("PLAYER_LOGOUT")
    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local onlyRawId, onlyData = raw_by_name(snapshot, "KeepMe")
    assert_true(onlyRawId ~= nil and onlyData ~= nil, "existing category preserved")
    local categoryCount = 0
    for _ in pairs(custom.categories or {}) do
        categoryCount = categoryCount + 1
    end
    assert_true(categoryCount == 1, "defaults were not added when categories are non-empty")
    assert_equal({
        { "cus-1", "eq-1" },
        {},
        { "unassigned" },
    }, snapshot.layout.columns, "existing layout preserved")
    assert_equal({ ["cus-1"] = true }, snapshot.layout.collapsed, "collapsed state preserved")
end)

run("import parser accepts plain table payload text without return", function()
    local ctx = harness.new()
    local payload = ctx.AddonNS.CustomCategories:DecodeImportPayload("{ version = 1, categories = {} }")
    assert_true(type(payload) == "table", "decoded payload is table")
    assert_true(payload.version == 1, "decoded version")

    local ok = pcall(function()
        ctx.AddonNS.CustomCategories:DecodeImportPayload("return { version = 1, categories = {} }")
    end)
    assert_true(ok == false, "return-prefixed payload rejected")
end)

run("export payload includes manual item assignments", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("ExportItems")
    ctx.AddonNS.CustomCategories:AssignToCategory(category, 555)
    local payload = ctx.AddonNS.CustomCategories:BuildExportPayload({ category:GetId() })
    assert_true(type(payload.categories) == "table" and #payload.categories == 1, "single category exported")
    assert_equal({ 555 }, payload.categories[1].items, "manual item assignments exported")
end)

run("import is create-only and applies manual assignments from payload", function()
    local ctx = harness.new()
    local localCategory = ctx.AddonNS.CustomCategories:NewCategory("LocalOnly")
    ctx.AddonNS.CustomCategories:AssignToCategory(localCategory, 777)

    local payload = {
        version = 1,
        categories = {
            {
                name = "ImportedA",
                query = "itemType = 4",
                priority = 42,
                alwaysVisible = true,
                items = { 889, 890 },
            },
            {
                name = "ImportedB",
                query = "ilvl >= 400",
                priority = 9,
                alwaysVisible = false,
                items = { 2000 },
            },
        },
    }
    local preview = ctx.AddonNS.CustomCategories:PreviewImport(payload)
    assert_true(#preview.toUpdate == 0, "import no longer updates existing categories")
    assert_true(#preview.toCreate == 2, "import creates all payload categories")
    ctx.AddonNS.CustomCategories:ApplyImportPreview(preview)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local existingRawId, existingData = raw_by_name(snapshot, "ImportedA")
    local newRawId, newData = raw_by_name(snapshot, "ImportedB")
    local localRawId, localData = raw_by_name(snapshot, "LocalOnly")
    assert_true(existingRawId ~= nil, "first imported category created")
    assert_true(newRawId ~= nil, "second imported category created")
    assert_true(localRawId ~= nil, "local category remains")
    assert_true(localData.externalId == nil, "local category keeps no external id")
    assert_true(existingData.query == "itemType = 4", "first imported category query set")
    assert_true(existingData.priority == 42, "first imported category priority set")
    assert_true(existingData.alwaysVisible == true, "first imported category visibility set")
    assert_equal({ 889, 890 }, existingData.items, "manual assignments imported for first category")
    assert_true(newData.query == "ilvl >= 400", "new category query set")
    assert_equal({ 2000 }, newData.items, "new category manual assignments imported")

    assert_true(existingRawId ~= nil and newRawId ~= nil, "created categories persisted")
end)

run("import with duplicate item ids across payload categories fails", function()
    local ctx = harness.new()
    local payload = {
        version = 1,
        categories = {
            {
                name = "ImportOne",
                items = { 5001 },
            },
            {
                name = "ImportTwo",
                items = { 5001 },
            },
        },
    }
    local ok = pcall(function()
        ctx.AddonNS.CustomCategories:PreviewImport(payload)
    end)
    assert_true(ok == false, "duplicate item ids across categories are rejected")
end)

run("script api resize increase keeps layout and adds empty right column", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
    })
    ctx:events():fire_game("PLAYER_LOGOUT")

    local before = layout_columns(ctx:snapshot())
    ctx.AddonNS.QueueContainerUpdateItemLayout = function() end
    ctx.AddonNS.TriggerContainerOnTokenWatchChanged = function() end
    ctx.AddonNS:SetNumColumns(4)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local after = layout_columns(snapshot)
    assert_true(snapshot.layout.columnCount == 4, "column count persisted as 4")
    assert_equal(before[1] or {}, after[1] or {}, "column 1 preserved")
    assert_equal(before[2] or {}, after[2] or {}, "column 2 preserved")
    assert_equal(before[3] or {}, after[3] or {}, "column 3 preserved")
    assert_equal({}, after[4] or {}, "newly added column 4 starts empty")
end)

run("resize decrease appends removed columns to last visible", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 5,
                categories = {
                    ["1"] = { name = "L1", items = {} },
                    ["2"] = { name = "L2", items = {} },
                    ["3"] = { name = "L3", items = {} },
                    ["4"] = { name = "L4", items = {} },
                    ["5"] = { name = "L5", items = {} },
                },
            },
            layout = {
                columnCount = 4,
                columns = {
                    { "cus-1" },
                    { "cus-2" },
                    { "cus-3" },
                    { "cus-4", "cus-5" },
                },
                collapsed = {},
            },
        },
    })

    ctx.AddonNS.Categories:SetColumnCount(3)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_true(snapshot.layout.columnCount == 3, "column count persisted as 3")
    local columns = layout_columns(snapshot)
    assert_equal({ "cus-1" }, columns[1] or {}, "column 1 unchanged")
    assert_equal({ "cus-2" }, columns[2] or {}, "column 2 unchanged")
    assert_equal({ "cus-3", "cus-4", "cus-5" }, columns[3] or {}, "removed columns appended to last visible in order")
    assert_true(columns[4] == nil, "column 4 removed")
end)

run("invalid requested column count clamps to supported range", function()
    local ctx = harness.new()
    ctx.AddonNS.Categories:SetColumnCount(1)
    assert_true(ctx:snapshot().layout.columnCount == 3, "count clamps to minimum")
    ctx.AddonNS.Categories:SetColumnCount(99)
    assert_true(ctx:snapshot().layout.columnCount == 8, "count clamps to maximum")
end)

run("bank scopes clamp minimum column count to 5", function()
    local ctx = harness.new()
    ctx.AddonNS.Categories:SetColumnCount(1, "bank-character")
    ctx.AddonNS.Categories:SetColumnCount(1, "bank-account")
    assert_true(ctx.AddonNS.CategoryStore:GetColumnCount("bank-character") == 5, "bank-character clamps to minimum 5")
    assert_true(ctx.AddonNS.CategoryStore:GetColumnCount("bank-account") == 5, "bank-account clamps to minimum 5")
end)

run("column count round trips via saved variables", function()
    local first = harness.new()
    first.AddonNS.Categories:SetColumnCount(8)
    first:events():fire_game("PLAYER_LOGOUT")
    local saved = first:snapshot()

    local second = harness.new({ saved = saved })
    local snapshot = second:snapshot()
    assert_true(snapshot.layout.columnCount == 8, "column count restored from saved variables")
    local columns = layout_columns(snapshot)
    assert_true(#columns == 8, "eight layout columns restored")
end)

run("bank scopes clamp maximum column count to 10", function()
    local ctx = harness.new()
    ctx.AddonNS.Categories:SetColumnCount(99, "bank-character")
    ctx.AddonNS.Categories:SetColumnCount(99, "bank-account")
    assert_true(ctx.AddonNS.CategoryStore:GetColumnCount("bank-character") == 10, "bank-character clamps to maximum 10")
    assert_true(ctx.AddonNS.CategoryStore:GetColumnCount("bank-account") == 10, "bank-account clamps to maximum 10")
end)

run("layout and collapsed state are isolated by scope", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("Scoped")
    local wrappedId = category:GetId()

    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [category] = {},
    }, "bag")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [category] = {},
    }, "bank-character")
    ctx.AddonNS.Categories:SetColumnCount(5, "bank-character")
    ctx.AddonNS.CategoryStore:SetCollapsed(wrappedId, true, "bank-character")
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_true(snapshot.layout.bag ~= nil, "bag scope is persisted")
    assert_true(snapshot.layout["bank-character"] ~= nil, "bank-character scope is persisted")
    assert_true(snapshot.layout["bank-character"].columnCount == 5, "bank-character column count persisted")
    assert_true(snapshot.layout.bag.columnCount ~= snapshot.layout["bank-character"].columnCount, "bag column count remains independent")
    assert_true(snapshot.layout["bank-character"].collapsed[wrappedId] == true, "bank-character collapsed persisted")
    assert_true((snapshot.layout.bag.collapsed or {})[wrappedId] == nil, "bag collapsed map unaffected")
end)

run("bank scopes default to 5 and do not reset persisted values", function()
    local first = harness.new()
    assert_true(first.AddonNS.CategoryStore:GetColumnCount("bank-character") == 5, "bank-character defaults to 5")
    assert_true(first.AddonNS.CategoryStore:GetColumnCount("bank-account") == 5, "bank-account defaults to 5")

    first.AddonNS.Categories:SetColumnCount(6, "bank-character")
    first.AddonNS.Categories:SetColumnCount(6, "bank-account")
    first:events():fire_game("PLAYER_LOGOUT")

    local second = harness.new({ saved = first:snapshot() })
    assert_true(second.AddonNS.CategoryStore:GetColumnCount("bank-character") == 6, "bank-character keeps persisted count")
    assert_true(second.AddonNS.CategoryStore:GetColumnCount("bank-account") == 6, "bank-account keeps persisted count")
end)

run("custom categories persist with namespaced layout", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.CustomCategories:AssignToCategory(catA, 101)
    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 102)
    ctx.AddonNS.QueryCategories:SetQuery(catA, "ilvl >= 400")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(catB, true)
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
    })
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.id == "cus", "custom categorizer id stored")
    local aId, aData = raw_by_name(snapshot, "A")
    local bId, bData = raw_by_name(snapshot, "B")
    assert_true(aId ~= nil and bId ~= nil, "categories persisted")
    assert_equal({ 101 }, aData.items, "A stores assignment")
    assert_equal({ 102 }, bData.items, "B stores assignment")
    assert_true(aData.query == "ilvl >= 400", "query persisted for A")
    assert_true(bData.alwaysVisible == true, "always visible persisted for B")
    local foundCatA = false
    for _, column in ipairs(layout_columns(snapshot)) do
        for _, id in ipairs(column) do
            if id == catA:GetId() then
                foundCatA = true
            end
        end
    end
    assert_true(foundCatA, "layout uses namespaced ids for custom categories")
    assert_true(snapshot.categorizers == nil or snapshot.categorizers.cus == nil, "old custom bucket not persisted")
    assert_true(snapshot.categories == nil, "legacy categories not persisted")
end)

run("new custom category appends to last column when layout already seeded", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
    })

    local catC = ctx.AddonNS.CustomCategories:NewCategory("C")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
        [catC] = {},
    })
    ctx:events():fire_game("PLAYER_LOGOUT")

    local columns = layout_columns(ctx:snapshot())
    local lastColumn = columns[3] or {}
    assert_true(lastColumn[#lastColumn] == catC:GetId(), "new category is appended to last column")
    assert_true(count_layout_id(columns, catC:GetId()) == 1, "new category appears only once in layout")
end)

run("layout load normalizes duplicate category ids across columns", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
            layout = {
                columnCount = 3,
                columns = {
                    { "eq-1", "cus-1" },
                    { "cus-1", "eq-1" },
                    { "unassigned" },
                },
                collapsed = {},
            },
        },
    })
    ctx:events():fire_game("PLAYER_LOGOUT")

    local columns = layout_columns(ctx:snapshot())
    assert_equal({}, columns[1] or {}, "earlier duplicates are removed from prior columns")
    assert_equal({ "cus-1", "eq-1" }, columns[2] or {}, "last occurrences are preserved in later columns")
    assert_equal({ "unassigned" }, columns[3] or {}, "unrelated ids are preserved")
end)

run("set layout columns normalizes globally deduplicated ids", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
            layout = {
                columnCount = 3,
                columns = { {}, {}, {} },
                collapsed = {},
            },
        },
    })
    ctx.AddonNS.CategoryStore:SetLayoutColumns({
        { "eq-7", "cus-2" },
        { "cus-2", "eq-7", "new-singleton" },
        {},
    }, "bag")

    local columns = layout_columns(ctx:snapshot())
    assert_equal({}, columns[1] or {}, "earlier duplicate entries are pruned from prior columns")
    assert_equal({ "cus-2", "eq-7", "new-singleton" }, columns[2] or {},
        "later column keeps the surviving duplicate ids and unique entries")
end)

run("empty layout bootstrap keeps round-robin placement for new categories", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
            layout = {
                columnCount = 3,
                columns = { {}, {}, {} },
                collapsed = {},
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
    })
    ctx:events():fire_game("PLAYER_LOGOUT")

    local columns = layout_columns(ctx:snapshot())
    assert_true((columns[1] or {})[1] == catA:GetId(), "first unmatched category stays in first column on empty bootstrap")
    assert_true((columns[2] or {})[1] == catB:GetId(), "second unmatched category stays in second column on empty bootstrap")
    assert_true(count_layout_id(columns, catA:GetId()) == 1, "first category appears only once")
    assert_true(count_layout_id(columns, catB:GetId()) == 1, "second category appears only once")
end)

run("layout arrangement matches persisted ids even after wrapper refresh", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local category = ctx.AddonNS.CustomCategories:NewCategory("Refreshable")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [category] = {},
    })

    local staleWrapper = category
    ctx.AddonNS.CustomCategories:RenameCategory(category, "RefreshableRenamed")

    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [staleWrapper] = {},
    })
    ctx:events():fire_game("PLAYER_LOGOUT")

    local columns = layout_columns(ctx:snapshot())
    assert_true(count_layout_id(columns, staleWrapper:GetId()) == 1,
        "stale wrapper refresh does not duplicate category id in layout")
end)

run("layout arrangement merges item lists for refreshed wrappers with the same id", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local category = ctx.AddonNS.CustomCategories:NewCategory("RefreshableItems")
    local staleWrapper = category
    local freshWrapper = {
        GetId = function()
            return staleWrapper:GetId()
        end,
        GetName = function()
            return staleWrapper:GetName()
        end,
    }

    local assignments = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [staleWrapper] = {
            { _myBagsItemId = 1002 },
        },
        [freshWrapper] = {
            { _myBagsItemId = 1001 },
        },
    })

    local found = nil
    for _, column in ipairs(assignments) do
        for _, entry in ipairs(column) do
            if entry.category:GetId() == staleWrapper:GetId() then
                found = entry
            end
        end
    end

    assert_true(found ~= nil, "category with refreshed wrapper remains in arranged output")
    assert_true(found.itemsCount == 2, "items from stale and refreshed wrappers are merged by id")
end)

run("custom category priority persists only for non-default overrides", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    local rawA = catA:GetId():match("^[^%-]+%-(.+)$")
    local rawB = catB:GetId():match("^[^%-]+%-(.+)$")

    ctx.AddonNS.CustomCategories:SetPriority(catA, 40)
    ctx.AddonNS.CustomCategories:SetPriority(catB, tonumber(rawB))
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.categories[rawA].priority == 40, "non-default custom priority persisted")
    assert_true(custom.categories[rawB].priority == nil, "default-equal priority omitted from saved variables")

    local restored = harness.new({ saved = snapshot })
    assert_true(restored.AddonNS.CustomCategories:GetEffectivePriority("cus-" .. rawA) == 40,
        "restored effective priority keeps explicit override")
    assert_true(restored.AddonNS.CustomCategories:GetEffectivePriority("cus-" .. rawB) == tonumber(rawB),
        "missing stored priority defaults to raw numeric id")
end)

run("custom query matching uses priority order and manual assignment precedence", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")

    ctx.AddonNS.QueryCategories:SetQuery(catA, "itemType = 3")
    ctx.AddonNS.QueryCategories:SetQuery(catB, "itemType = 3")
    ctx.AddonNS.CustomCategories:SetPriority(catA, 100)
    ctx.AddonNS.CustomCategories:SetPriority(catB, 10)

    install_item_query_stubs(2001)

    local button = item_button(0, 1)
    local matches = ctx.AddonNS.Categories:GetMatches(2001, button)
    assert_true(matches[1]:GetId() == catA:GetId(), "higher priority query category matches first")
    assert_true(matches[2]:GetId() == catB:GetId(), "lower priority query category matches second")

    ctx.AddonNS.CustomCategories:SetPriority(catA, 5)
    ctx.AddonNS.CustomCategories:SetPriority(catB, 5)
    local tieMatches = ctx.AddonNS.Categories:GetMatches(2001, button)
    assert_true(tieMatches[1]:GetId() == catA:GetId(), "priority ties prefer alphabetical category name")

    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 2001)
    local manualMatches = ctx.AddonNS.Categories:GetMatches(2001, button)
    assert_true(manualMatches[1]:GetId() == catB:GetId(), "manual assignment takes precedence over query ordering")
    assert_true(manualMatches[2]:GetId() == catA:GetId(),
        "default match list keeps unique category ids")

    local diagnosticMatches = ctx.AddonNS.Categories:GetMatches(2001, button, { allowDuplicateCategoryIds = true })
    assert_true(diagnosticMatches[1]:GetId() == catB:GetId(), "diagnostic list keeps manual assignment first")
    assert_true(diagnosticMatches[2]:GetId() == catA:GetId(), "diagnostic list keeps query ordering by priority")
    assert_true(diagnosticMatches[3]:GetId() == catB:GetId(),
        "diagnostic list includes same category twice when manual and query both match")
end)

run("custom query matching supports new payload attributes", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })

    local animaCategory = ctx.AddonNS.CustomCategories:NewCategory("Anima")
    local descriptionCategory = ctx.AddonNS.CustomCategories:NewCategory("Description")
    local transmogCategory = ctx.AddonNS.CustomCategories:NewCategory("Transmog")
    local warboundCategory = ctx.AddonNS.CustomCategories:NewCategory("WarboundFlag")
    ctx.AddonNS.QueryCategories:SetQuery(animaCategory, "isAnimaItem = true")
    ctx.AddonNS.QueryCategories:SetQuery(descriptionCategory, "description = \"special relic\"")
    ctx.AddonNS.QueryCategories:SetQuery(transmogCategory, "isTransmogCollected = true")
    ctx.AddonNS.QueryCategories:SetQuery(warboundCategory, "isWarbound = true")
    ctx.AddonNS.CustomCategories:SetPriority(animaCategory, 300)
    ctx.AddonNS.CustomCategories:SetPriority(descriptionCategory, 200)
    ctx.AddonNS.CustomCategories:SetPriority(transmogCategory, 100)
    ctx.AddonNS.CustomCategories:SetPriority(warboundCategory, 50)

    install_item_query_stubs(2201, {
        isAnimaItem = true,
        isArtifactPowerItem = false,
        isCorruptedItem = false,
        isTransmogCollected = true,
        isWarbound = true,
        itemSpellName = "Vault Recall",
        tooltipLines = {
            { leftText = "Flavor line" },
            { leftText = "Use: Open a special relic from an old vault" },
        },
        description = "special relic from an old vault",
    })
    local button = item_button(0, 1)
    local category = ctx.AddonNS.Categories:Categorize(2201, button)
    assert_true(category:GetId() == animaCategory:GetId(), "anima boolean query field is evaluated from payload")

    local matches = ctx.AddonNS.Categories:GetMatches(2201, button)
    assert_true(matches[1]:GetId() == animaCategory:GetId(), "priority keeps anima match first")
    assert_true(matches[2]:GetId() == descriptionCategory:GetId(), "description string query field matches payload")
    assert_true(matches[3]:GetId() == transmogCategory:GetId(), "transmog boolean query field matches payload")
    assert_true(matches[4]:GetId() == warboundCategory:GetId(), "warbound boolean query field matches payload")

    ctx.AddonNS.QueryCategories:SetQuery(animaCategory, "isCorruptedItem = true")
    local noCorruptCategory = ctx.AddonNS.Categories:Categorize(2201, button)
    assert_true(noCorruptCategory:GetId() == descriptionCategory:GetId(),
        "isCorruptedItem false value prevents corrupted-only category match")

    ctx.AddonNS.QueryCategories:SetQuery(animaCategory, "isArtifactPowerItem = true")
    local noArtifactCategory = ctx.AddonNS.Categories:Categorize(2201, button)
    assert_true(noArtifactCategory:GetId() == descriptionCategory:GetId(),
        "isArtifactPowerItem false value prevents artifact-only category match")

    install_item_query_stubs(2202, {
        isAnimaItem = false,
        isArtifactPowerItem = false,
        isCorruptedItem = false,
        noTransmogSource = true,
        isWarbound = false,
        description = "special relic from an old vault",
    })
    local nilTransmogCategory = ctx.AddonNS.Categories:Categorize(2202, item_button(0, 1))
    assert_true(nilTransmogCategory:GetId() == descriptionCategory:GetId(),
        "isTransmogCollected is nil when source info is missing so true/false transmog queries do not match")
end)

run("custom query matching supports onUseDescription tooltip attribute", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })

    local onUseCategory = ctx.AddonNS.CustomCategories:NewCategory("OnUse")
    ctx.AddonNS.QueryCategories:SetQuery(onUseCategory, "onUseDescription = \"hidden vault\"")
    ctx.AddonNS.CustomCategories:SetPriority(onUseCategory, 200)

    install_item_query_stubs(2204, {
        itemSpellName = "Vault Recall",
        tooltipLines = {
            { leftText = "Use: Teleports the caster to a hidden vault" },
        },
    })
    local category = ctx.AddonNS.Categories:Categorize(2204, item_button(0, 1))
    assert_true(category:GetId() == onUseCategory:GetId(),
        "onUseDescription query matches localized tooltip text after the Use prefix")

    install_item_query_stubs(2205, {
        itemSpellName = nil,
        tooltipLines = {
            { leftText = "Use: Teleports the caster to a hidden vault" },
        },
    })
    local noSpellPayload = ctx.AddonNS.CustomCategories:GetItemQueryPayload(2205, item_button(0, 1))
    assert_true(noSpellPayload.onUseDescription == nil,
        "onUseDescription stays unset when the item has no on-use spell gate")
end)

run("manual assign to first query-match category via item-move is ignored", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")

    ctx.AddonNS.QueryCategories:SetQuery(catA, "itemType = 3")
    ctx.AddonNS.CustomCategories:SetPriority(catA, 100)
    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 2001)

    install_item_query_stubs(2001)

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.ITEM_MOVED, 2001, nil, catB, catA, item_button(0, 1), nil)

    assert_true(ctx.AddonNS.CustomCategories:IsManuallyAssignedToCategory(2001, catA) == false,
        "manual assignment to first query-match category is ignored")
    assert_true(ctx.AddonNS.CustomCategories:IsManuallyAssignedToCategory(2001, catB) == false,
        "source manual assignment is cleared by move flow")
    local category = ctx.AddonNS.Categories:Categorize(2001, item_button(0, 1))
    assert_true(category:GetId() == catA:GetId(), "item still resolves to target category via query")
end)

run("manual assign is not ignored when global winner is not target category", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.QueryCategories:SetQuery(catA, "itemType = 3")
    ctx.AddonNS.CustomCategories:SetPriority(catA, 100)
    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 2001)

    install_item_query_stubs(2001)

    local originalCategorize = ctx.AddonNS.Categories.Categorize
    ctx.AddonNS.Categories.Categorize = function()
        return catB
    end
    ctx:events():fire_custom(ctx.AddonNS.Const.Events.ITEM_MOVED, 2001, nil, catB, catA, item_button(0, 1), nil)
    ctx.AddonNS.Categories.Categorize = originalCategorize

    assert_true(ctx.AddonNS.CustomCategories:IsManuallyAssignedToCategory(2001, catA) == true,
        "manual assignment is kept when global winner would otherwise be different")
    local category = ctx.AddonNS.Categories:Categorize(2001, item_button(0, 1))
    assert_true(category:GetId() == catA:GetId(), "manual assignment overrides external categorizer winner")
end)

run("always visible empty category stays empty in arranged output", function()
    local ctx = harness.new()
    local always = ctx.AddonNS.CustomCategories:NewCategory("Always")
    local other = ctx.AddonNS.CustomCategories:NewCategory("Other")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(always, true)
    local assignments = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [other] = { item_button(0, 1) },
    })

    local alwaysEntry = nil
    for _, column in ipairs(assignments) do
        for _, entry in ipairs(column) do
            if entry.category:GetId() == always:GetId() then
                alwaysEntry = entry
            end
        end
    end
    assert_true(alwaysEntry ~= nil, "always visible category is included in assignments")
    assert_true(alwaysEntry.itemsCount == 0, "always visible empty category keeps zero item count")
    assert_equal({}, alwaysEntry.items, "always visible empty category has no placeholder items")
end)

run("categories config mode scope-disabled visibility is gated by runtime checkbox state", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.CustomCategories:SetVisibleInScope(catB, "bag", false)

    local before = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({})
    assert_true(not has_category_entry(before, catA), "custom category A hidden by default when empty")
    assert_true(not has_category_entry(before, catB), "custom category B hidden by default when empty")

    ctx.AddonNS.BagViewState:SetMode("categories_config")
    assert_true(not ctx.AddonNS.BagViewState:ShouldShowScopeDisabledInConfigMode(), "checkbox runtime flag defaults to off")
    local during = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({})
    assert_true(has_category_entry(during, catA), "custom category A visible while categories GUI mode enabled")
    assert_true(not has_category_entry(during, catB), "scope-disabled custom category B stays hidden while checkbox is off")

    ctx.AddonNS.BagViewState:SetShowScopeDisabledInConfigMode(true)
    local duringWithScopeDisabled = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({})
    assert_true(has_category_entry(duringWithScopeDisabled, catA), "custom category A remains visible while categories GUI mode enabled")
    assert_true(has_category_entry(duringWithScopeDisabled, catB), "scope-disabled custom category B is visible when checkbox is on")

    ctx.AddonNS.BagViewState:SetMode("normal")
    local after = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({})
    assert_true(not has_category_entry(after, catA), "custom category A hidden again after categories GUI mode disabled")
    assert_true(not has_category_entry(after, catB), "custom category B hidden again after categories GUI mode disabled")

    ctx:events():fire_game("PLAYER_LOGOUT")
    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local rawA = catA:GetId():match("^[^%-]+%-(.+)$")
    local rawB = catB:GetId():match("^[^%-]+%-(.+)$")
    assert_true(custom.categories[rawA].alwaysVisible ~= true, "A alwaysVisible remains not persisted as enabled")
    assert_true(custom.categories[rawB].alwaysVisible ~= true, "B alwaysVisible remains not persisted as enabled")

    local reloaded = harness.new({ saved = snapshot })
    assert_true(not reloaded.AddonNS.BagViewState:ShouldShowScopeDisabledInConfigMode(), "checkbox runtime flag is not persisted across sessions")
end)

run("tooltip mode defaults to default when missing or invalid", function()
    local ctx = harness.new()
    assert_true(ctx.AddonNS.TooltipSettings:GetMode() == ctx.AddonNS.TooltipSettings.MODE_DEFAULT, "missing mode defaults to default")

    local invalid = harness.new({
        saved = {
            settings = {
                tooltipMode = "invalid_mode",
            },
        },
    })
    assert_true(invalid.AddonNS.TooltipSettings:GetMode() == invalid.AddonNS.TooltipSettings.MODE_DEFAULT,
        "invalid persisted mode normalizes to default")
end)

run("tooltip mode persists across reload and prunes default value", function()
    local ctx = harness.new()
    ctx.AddonNS.TooltipSettings:SetMode(ctx.AddonNS.TooltipSettings.MODE_SHIFT_ONLY)
    assert_true(ctx.AddonNS.TooltipSettings:GetMode() == ctx.AddonNS.TooltipSettings.MODE_SHIFT_ONLY, "mode set to shift_only")
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_true(snapshot.settings ~= nil, "settings table persisted")
    assert_true(snapshot.settings.tooltipMode == "shift_only", "shift_only mode persisted")

    local reloaded = harness.new({ saved = snapshot })
    assert_true(reloaded.AddonNS.TooltipSettings:GetMode() == reloaded.AddonNS.TooltipSettings.MODE_SHIFT_ONLY,
        "shift_only mode survives reload")

    reloaded.AddonNS.TooltipSettings:SetMode(reloaded.AddonNS.TooltipSettings.MODE_DEFAULT)
    reloaded:events():fire_game("PLAYER_LOGOUT")
    local defaultSnapshot = reloaded:snapshot()
    if defaultSnapshot.settings ~= nil then
        assert_true(defaultSnapshot.settings.tooltipMode == nil, "default mode prunes persisted key")
    end
end)

run("new items categorizer defaults to enabled when missing or invalid", function()
    local ctx = harness.new()
    assert_true(ctx.AddonNS.NewItemsSettings:IsEnabled(), "missing new items setting defaults to enabled")

    local invalid = harness.new({
        saved = {
            settings = {
                newItemsCategorizerEnabled = "invalid_value",
            },
        },
    })
    assert_true(invalid.AddonNS.NewItemsSettings:IsEnabled(), "invalid persisted new items setting normalizes to enabled")
end)

run("new items categorizer persists across reload and prunes enabled value", function()
    local ctx = harness.new()
    ctx.AddonNS.NewItemsSettings:SetEnabled(false)
    assert_true(not ctx.AddonNS.NewItemsSettings:IsEnabled(), "new items categorizer disabled")
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_true(snapshot.settings ~= nil, "settings table persisted")
    assert_true(snapshot.settings.newItemsCategorizerEnabled == false, "disabled new items categorizer persisted")

    local reloaded = harness.new({ saved = snapshot })
    assert_true(not reloaded.AddonNS.NewItemsSettings:IsEnabled(), "disabled new items categorizer survives reload")

    reloaded.AddonNS.NewItemsSettings:SetEnabled(true)
    reloaded:events():fire_game("PLAYER_LOGOUT")
    local enabledSnapshot = reloaded:snapshot()
    if enabledSnapshot.settings ~= nil then
        assert_true(enabledSnapshot.settings.newItemsCategorizerEnabled == nil,
            "enabled new items categorizer prunes persisted key")
    end
end)

run("selected custom category prefix clears when selection is cleared", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("Selected")
    local selectedCategoryId = nil
    ctx.AddonNS.CategoriesGUI = {
        GetSelectedCategoryId = function()
            return selectedCategoryId
        end,
    }

    ctx.AddonNS.BagViewState:SetMode("categories_config")
    selectedCategoryId = category:GetId()
    local selectedLabel = category:GetDisplayName(0)
    assert_true(string.find(selectedLabel, ">>", 1, true) ~= nil, "selected custom category gets prefix")

    selectedCategoryId = nil
    local clearedLabel = category:GetDisplayName(0)
    assert_true(string.find(clearedLabel, ">>", 1, true) == nil, "prefix removed after selection is cleared")
end)

run("item move reassigns through hooks and respects protected target", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.CustomCategories:AssignToCategory(catA, 101)
    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 102)
    ctx.AddonNS.db.itemOrder[1] = 101
    ctx.AddonNS.db.itemOrder[2] = 102

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.ITEM_MOVED, 101, 102, catA, catB, item_button(0, 1), item_button(0, 2))
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local aData = custom.categories[catA:GetId():match("^[^%-]+%-(.+)$")]
    local bData = custom.categories[catB:GetId():match("^[^%-]+%-(.+)$")]
    assert_equal({}, aData.items, "source cleared after move")
    assert_equal({ 102, 101 }, bData.items, "target has both items after move")

    -- Protected target should block move.
    local ctx2 = harness.new()
    local prot = ctx2.AddonNS.CustomCategories:NewCategory("Prot", { protected = true })
    local src = ctx2.AddonNS.CustomCategories:NewCategory("Src")
    ctx2.AddonNS.CustomCategories:AssignToCategory(src, 201)
    ctx2.AddonNS.db.itemOrder[1] = 201
    ctx2:events():fire_custom(ctx2.AddonNS.Const.Events.ITEM_MOVED, 201, nil, src, prot, item_button(0, 1), nil)
    ctx2:events():fire_game("PLAYER_LOGOUT")
    local snap2 = ctx2:snapshot()
    local custom2 = custom_snapshot(snap2)
    local srcData = custom2.categories[src:GetId():match("^[^%-]+%-(.+)$")]
    local protData = custom2.categories[prot:GetId():match("^[^%-]+%-(.+)$")]
    assert_equal({ 201 }, srcData.items, "protected target prevents reassignment")
    assert_equal({}, protData.items, "protected target stays empty")
end)

run("clearing inputs removes stored data", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("Solo")
    ctx.AddonNS.CustomCategories:AssignToCategory(category, 555)
    ctx.AddonNS.QueryCategories:SetQuery(category, "isQuestItem = true")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(category, true)

    ctx.AddonNS.CustomCategories:AssignToCategory(nil, 555)
    ctx.AddonNS.QueryCategories:SetQuery(category, "")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(category, false)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local rawId = category:GetId():match("^[^%-]+%-(.+)$")
    local entry = custom.categories[rawId]
    assert_true(#(entry.items or {}) == 0, "manual assignments cleared")
    assert_true(entry.query == nil, "query cleared")
    assert_true(entry.alwaysVisible == nil, "always visible flag cleared")
end)

run("custom category query updates compiled cache via direct API", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("Compiled")

    ctx.AddonNS.CustomCategories:SetQuery(category, "ilvl >= 400")
    local compiled = ctx.AddonNS.QueryCategories:GetCompiled(category)
    assert_true(type(compiled) == "function", "compiled query exists after direct set")
    assert_true(compiled({ ilvl = 420 }) == true, "compiled query matches satisfying payload")
    assert_true(compiled({ ilvl = 399 }) == false, "compiled query rejects non-satisfying payload")

    ctx.AddonNS.CustomCategories:SetQuery(category, "")
    assert_true(ctx.AddonNS.QueryCategories:GetCompiled(category) == nil, "compiled query removed after clearing")
end)

run("category rename accepts wrapped category id and preserves assignments", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("BeforeRename")
    local wrappedId = category:GetId()
    local rawId = wrappedId:match("^[^%-]+%-(.+)$")
    ctx.AddonNS.CustomCategories:AssignToCategory(category, 555)

    ctx.AddonNS.CustomCategories:RenameCategory(wrappedId, "AfterRename")
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local entry = custom.categories[rawId]
    assert_true(entry ~= nil, "renamed category still exists")
    assert_true(entry.name == "AfterRename", "wrapped-id rename updates persisted name")
    assert_equal({ 555 }, entry.items, "rename keeps existing item assignments")
end)

run("category move events use category ids for reorder and column move", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
    })
    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, catB:GetId(), 1)

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED, catA:GetId(), catB:GetId(), false)
    ctx:events():fire_game("PLAYER_LOGOUT")
    local columnsAfterReorder = layout_columns(ctx:snapshot())
    local firstColumn = columnsAfterReorder[1] or {}
    assert_true(firstColumn[1] == catB:GetId(), "reorder places target category first in column")
    assert_true(firstColumn[2] == catA:GetId(), "reorder places moved category after target")

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED, catB:GetId(), catA:GetId(), false)
    ctx:events():fire_game("PLAYER_LOGOUT")
    local columnsAfterReverseReorder = layout_columns(ctx:snapshot())
    local firstColumnAfterReverse = columnsAfterReverseReorder[1] or {}
    assert_true(firstColumnAfterReverse[1] == catA:GetId(), "reverse reorder moves dragged category before target")
    assert_true(firstColumnAfterReverse[2] == catB:GetId(), "reverse reorder keeps both categories ordered")

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, catA:GetId(), 2, false)
    ctx:events():fire_game("PLAYER_LOGOUT")
    local columnsAfterMove = layout_columns(ctx:snapshot())
    local column1 = columnsAfterMove[1] or {}
    local column2 = columnsAfterMove[2] or {}
    assert_true(column1[1] == catB:GetId(), "column 1 keeps target category after move")
    assert_true(column2[#column2] == catA:GetId(), "column 2 receives moved category")
end)

run("shift category move reorders source tail block and preserves relative order", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    local catC = ctx.AddonNS.CustomCategories:NewCategory("C")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
        [catC] = {},
    })

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, catB:GetId(), 1, false)
    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, catC:GetId(), 1, false)
    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED, catB:GetId(), catA:GetId(), true)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local columnsAfterShiftReorder = layout_columns(ctx:snapshot())
    local firstColumn = columnsAfterShiftReorder[1] or {}
    assert_true(firstColumn[1] == catB:GetId(), "shift reorder puts dragged category at target anchor")
    assert_true(firstColumn[2] == catC:GetId(), "shift reorder keeps tail relative order")
    assert_true(firstColumn[3] == catA:GetId(), "shift reorder keeps target after moved tail block")
end)

run("shift background move sends source tail block to destination column", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    local catC = ctx.AddonNS.CustomCategories:NewCategory("C")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
        [catB] = {},
        [catC] = {},
    })

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, catB:GetId(), 1, false)
    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, catC:GetId(), 1, false)
    ctx:events():fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, catB:GetId(), 2, true)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local columnsAfterShiftColumnMove = layout_columns(ctx:snapshot())
    local firstColumn = columnsAfterShiftColumnMove[1] or {}
    local secondColumn = columnsAfterShiftColumnMove[2] or {}
    assert_true(firstColumn[1] == catA:GetId(), "source column keeps categories above dragged one")
    assert_true(secondColumn[#secondColumn - 1] == catB:GetId(), "destination receives dragged category")
    assert_true(secondColumn[#secondColumn] == catC:GetId(),
        "destination appends moved tail in original relative order")
end)

run("category delete removes layout entry via category id event", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("DeleteMe")
    ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({
        [catA] = {},
    })

    ctx.AddonNS.CustomCategories:DeleteCategory(catA)
    ctx:events():fire_game("PLAYER_LOGOUT")
    local columns = layout_columns(ctx:snapshot())
    for _, column in ipairs(columns) do
        for _, id in ipairs(column or {}) do
            assert_true(id ~= catA:GetId(), "deleted category removed from all columns")
        end
    end
end)

run("category delete accepts wrapped category id", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("DeleteByWrappedId")
    local wrappedId = catA:GetId()
    local rawId = wrappedId:match("^[^%-]+%-(.+)$")
    ctx.AddonNS.CustomCategories:DeleteCategory(wrappedId)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.categories[rawId] == nil, "category deleted when using wrapped id")
end)

run("migrates from db.categorizers.cus to userCategories", function()
    local ctx = harness.new({
        saved = {
            categorizers = {
                cus = {
                    id = "cus",
                    name = "Custom",
                    nextId = 7,
                    categories = {
                        ["5"] = {
                            name = "MigratedA",
                            items = { 111 },
                            query = "ilvl >= 400",
                            alwaysVisible = true,
                        },
                    },
                },
            },
            layout = {
                columns = { { "cus-5" }, {}, {} },
                collapsed = { ["cus-5"] = true },
            },
            itemOrder = { 111 },
        },
    })

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.nextId == 7, "nextId migrated from categorizers.cus")
    assert_true(custom.categories["5"].name == "MigratedA", "category migrated from categorizers.cus")
    assert_equal({ 111 }, custom.categories["5"].items, "items migrated from categorizers.cus")
    assert_true(snapshot.categorizers == nil or snapshot.categorizers.cus == nil, "source custom bucket removed")
end)

run("migrates from old db.categories and converts cat layout ids", function()
    local ctx = harness.new({
        saved = {
            categories = {
                ["cat-9"] = {
                    id = "cat-9",
                    name = "LegacyCat",
                    items = { 909 },
                    query = "itemType = 3",
                    alwaysVisible = true,
                },
            },
            layout = {
                columns = { { "cat-9" }, {}, {} },
                collapsed = { ["cat-9"] = true },
            },
        },
    })

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.categories["9"].name == "LegacyCat", "old db.categories migrated")
    assert_equal({ 909 }, custom.categories["9"].items, "old db.items migrated")
    assert_equal({ { "cus-9" }, {}, {} }, layout_columns(snapshot), "cat- layout ids converted to cus-")
    assert_true(snapshot.layout.collapsed["cus-9"] == true, "collapsed cat- id converted to cus-")
    assert_true(snapshot.categories == nil, "old categories source removed")
end)

run("migrates from legacy global and maps layout names", function()
    local ctx = harness.new({
        legacy = {
            customCategories = {
                LegacyOne = { 1001, 1002 },
            },
            queryCategories = {
                LegacyOne = "ilvl >= 200",
            },
            categoriesToAlwaysShow = {
                LegacyOne = true,
            },
            categoriesColumnAssignments = {
                { "LegacyOne" },
                {},
                {},
            },
            collapsedCategories = {
                LegacyOne = true,
            },
            itemOrder = { 1001, 1002 },
        },
    })

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local rawId, data = raw_by_name(snapshot, "LegacyOne")
    assert_true(rawId ~= nil, "legacy global category migrated")
    assert_equal({ 1001, 1002 }, data.items, "legacy global items migrated")
    assert_true(data.query == "ilvl >= 200", "legacy global query migrated")
    assert_true(data.alwaysVisible == true, "legacy global always visible migrated")
    assert_equal({ { "cus-" .. rawId }, {}, {} }, layout_columns(snapshot), "legacy layout names converted to cus ids")
    assert_true(snapshot.layout.collapsed["cus-" .. rawId] == true, "legacy collapsed names converted to cus ids")
    assert_equal({ 1001, 1002 }, snapshot.itemOrder, "legacy item order migrated")
end)

run("custom category scope visibility defaults to enabled and persists false-only overrides", function()
    local first = harness.new()
    local category = first.AddonNS.CustomCategories:NewCategory("ScopedVisibility")
    local visibilityDefault = first.AddonNS.CustomCategories:GetScopeVisibility(category)
    assert_true(visibilityDefault.bag == true, "bag scope enabled by default")
    assert_true(visibilityDefault["bank-character"] == true, "bank-character scope enabled by default")
    assert_true(visibilityDefault["bank-account"] == true, "bank-account scope enabled by default")

    first.AddonNS.CustomCategories:SetVisibleInScope(category, "bank-account", false)
    first:events():fire_game("PLAYER_LOGOUT")
    local firstSnapshot = first:snapshot()
    local rawId, rawData = raw_by_name(firstSnapshot, "ScopedVisibility")
    assert_true(rawId ~= nil, "scoped category persisted")
    assert_true(rawData.scopes["bank-account"] == false, "disabled bank-account override persisted")
    assert_true(rawData.scopes["bag"] == nil, "enabled bag scope is not redundantly persisted")
    assert_true(rawData.scopes["bank-character"] == nil, "enabled bank-character scope is not redundantly persisted")

    local second = harness.new({ saved = firstSnapshot })
    local secondRawId, _ = raw_by_name(second:snapshot(), "ScopedVisibility")
    local secondCategory = second.AddonNS.Categories:GetCategoryById("cus-" .. secondRawId)
    local visibilityAfterReload = second.AddonNS.CustomCategories:GetScopeVisibility(secondCategory)
    assert_true(visibilityAfterReload.bag == true, "bag scope remains enabled after reload")
    assert_true(visibilityAfterReload["bank-character"] == true, "bank-character remains enabled after reload")
    assert_true(visibilityAfterReload["bank-account"] == false, "bank-account remains disabled after reload")
end)

run("scope-disabled custom category is skipped in Categorize and filtered in GetMatches by default", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("ScopedMatch")
    ctx.AddonNS.CustomCategories:AssignToCategory(category, 991)
    ctx.AddonNS.CustomCategories:SetVisibleInScope(category, "bank-character", false)

    local bagCategory = ctx.AddonNS.Categories:Categorize(991, { MyBagsScope = "bag" })
    assert_true(bagCategory:GetId() == category:GetId(), "bag scope keeps manual assignment category")

    local bankCategory = ctx.AddonNS.Categories:Categorize(991, { MyBagsScope = "bank-character" })
    assert_true(bankCategory:GetId() == "unassigned", "bank-character scope ignores disabled assignment and falls back")

    local bankMatchesDefault = ctx.AddonNS.Categories:GetMatches(991, nil, {
        scope = "bank-character",
    })
    local foundDisabledInDefaultMatches = false
    for _, match in ipairs(bankMatchesDefault) do
        if match:GetId() == category:GetId() then
            foundDisabledInDefaultMatches = true
        end
    end
    assert_true(not foundDisabledInDefaultMatches, "default matches filter scope-disabled categories")

    local bankMatchesWithDisabled = ctx.AddonNS.Categories:GetMatches(991, nil, {
        scope = "bank-character",
        includeScopeDisabled = true,
    })
    local foundDisabledInDiagnosticMatches = false
    for _, match in ipairs(bankMatchesWithDisabled) do
        if match:GetId() == category:GetId() then
            foundDisabledInDiagnosticMatches = true
        end
    end
    assert_true(foundDisabledInDiagnosticMatches, "diagnostic matches include scope-disabled categories")
end)

run("scope-disabled custom query winner falls through to next visible query match", function()
    local ctx = harness.new({
        saved = {
            userCategories = {
                schemaVersion = 2,
                id = "cus",
                name = "Custom",
                nextId = 1,
                categories = {
                    ["1"] = { name = "KeepSeedOff", items = {} },
                },
            },
        },
    })
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.QueryCategories:SetQuery(catA, "itemType = 3")
    ctx.AddonNS.QueryCategories:SetQuery(catB, "itemType = 3")
    ctx.AddonNS.CustomCategories:SetPriority(catA, 100)
    ctx.AddonNS.CustomCategories:SetPriority(catB, 10)
    ctx.AddonNS.CustomCategories:SetVisibleInScope(catA, "bag", false)

    install_item_query_stubs(1991)

    local button = item_button(0, 1)
    button.MyBagsScope = "bag"
    local category = ctx.AddonNS.Categories:Categorize(1991, button)
    assert_true(category:GetId() == catB:GetId(), "categorize skips disabled top query category and keeps scanning")
end)

run("always visible custom category obeys scope visibility", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("AlwaysScoped")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(category, true)
    ctx.AddonNS.CustomCategories:SetVisibleInScope(category, "bank-character", false)

    local bagAssignments = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({}, "bag")
    assert_true(has_category_entry(bagAssignments, category), "always visible category appears in enabled bag scope")

    local bankAssignments = ctx.AddonNS.Categories:ArrangeCategoriesIntoColumns({}, "bank-character")
    assert_true(not has_category_entry(bankAssignments, category), "always visible category is hidden in disabled bank scope")
end)

print("All integration scenarios completed.")
