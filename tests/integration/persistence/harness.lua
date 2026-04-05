-- Integration test harness for SavedVariable persistence.
-- NOTE: GUI files are intentionally not loaded; the persistence suite focuses on
-- SavedVariable mutations and stubs out UI dependencies.

local Harness = {}
Harness.__index = Harness

local function deep_copy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local clone = {}
    seen[value] = clone
    for k, v in pairs(value) do
        clone[deep_copy(k, seen)] = deep_copy(v, seen)
    end
    return clone
end

local function compute_root()
    local source = debug.getinfo(1, "S").source
    source = source:sub(1, 1) == "@" and source:sub(2) or source
    return source:match("^(.*)/tests/integration/persistence/harness%.lua$")
end

local ROOT = compute_root()
assert(ROOT, "Failed to resolve project root from harness path")

local function repo_path(rel)
    return ROOT .. "/" .. rel
end

local function load_chunk(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    return chunk
end

local function make_event_bus(store)
    local lifecycle_order = {}
    local lifecycle_seen = {}

    local function append_lifecycle(fn)
        if not lifecycle_seen[fn] then
            table.insert(lifecycle_order, fn)
            lifecycle_seen[fn] = true
        end
    end

    local bus = {}

    function bus:OnInitialize(fn)
        append_lifecycle(fn)
    end

    function bus:OnDbLoaded(fn)
        append_lifecycle(fn)
    end

    function bus:RegisterEvent(eventName, handler)
        handler = handler or function() end
        local list = store.game[eventName]
        if not list then
            list = {}
            store.game[eventName] = list
        end
        table.insert(list, handler)
    end

    function bus:RegisterCustomEvent(eventName, handler)
        local list = store.custom[eventName]
        if not list then
            list = {}
            store.custom[eventName] = list
        end
        table.insert(list, handler)
    end

    function bus:TriggerCustomEvent(eventName, ...)
        local list = store.custom[eventName]
        if list then
            for _, fn in ipairs(list) do
                fn(eventName, ...)
            end
        end
    end

    store.lifecycle = lifecycle_order

    return bus
end

local function make_libstub(ctx)
    local libs = {}

    libs["MyLibrary_Events"] = {
        embed = function(first, second)
            local target = second or first
            assert(target, "LibStub embed target missing")
            ctx._event_store = ctx._event_store or { game = {}, custom = {} }
            local bus = make_event_bus(ctx._event_store)
            for k, v in pairs(bus) do
                target[k] = v
            end
            target.___harness_store = ctx._event_store
        end,
    }

    libs["MyLibrary_GUI"] = {
        CreateButtonFrame = function()
            return setmetatable({}, {
                __index = function()
                    return function() end
                end,
            })
        end,
    }

    libs["WowList-1.5"] = {
        CreateNew = function()
            local stub = {}
            function stub:SetPoint() end
            function stub:SetMultiSelection() end
            function stub:SetButtonOnMouseDownFunction() end
            function stub:SetButtonOnReceiveDragFunction() end
            function stub:RemoveAll() end
            function stub:AddData() end
            function stub:Sort() end
            function stub:UpdateView() end
            function stub:RegisterCallback() end
            function stub:GetSelected() return nil end
            return stub
        end,
    }

    return function(name, silent)
        local lib = libs[name]
        if not lib and not silent then
            error("LibStub stub missing library: " .. tostring(name))
        end
        return lib
    end
end

local function setup_container_api(ctx)
    ctx._container_slots = {}
    local container = {}

    function container.GetContainerItemInfo(_, bag, slot)
        local bagData = ctx._container_slots[bag]
        if not bagData then
            return nil
        end
        local itemID = bagData[slot]
        if not itemID then
            return nil
        end
        return { itemID = itemID }
    end

    ctx._C_Container = setmetatable({}, {
        __index = container,
        __newindex = function()
            error("C_Container stub is read-only in harness")
        end,
    })

    _G.C_Container = ctx._C_Container
end

local function reset_globals(ctx, savedFixture, legacyFixture)
    _G.dev_MyBagsDB = deep_copy(savedFixture) or {}
    _G.dev_MyBagsDBGlobal = deep_copy(legacyFixture)
    _G.LibStub = make_libstub(ctx)
end

local function load_addon(ctx)
    local addonName = "!dev_MyBags"
    local AddonNS = {}
    ctx.AddonNS = AddonNS

    local function exec(rel)
        load_chunk(repo_path(rel))(addonName, AddonNS)
    end

    exec("categoryStore.lua")
    exec("init.lua")
    exec("tooltipSettings.lua")
    exec("newItemsSettings.lua")
    exec("bagViewState.lua")
    AddonNS.itemButtonPlaceholder = {}

    setup_container_api(ctx)

    exec("collapsed.lua")
    dofile(repo_path("utils/orderedMap.lua"))
    exec("categories.lua")
    exec("itemsOrder.lua")
    exec("categoriesColumnAssignment.lua")
    exec("Categorizers/custom/defaultImportPayload.lua")
    exec("Categorizers/custom.lua")
    exec("Categorizers/custom/query.lua")
    exec("Categorizers/unassigned.lua")

    ctx.AddonNS = AddonNS
end

function Harness.new(opts)
    opts = opts or {}
    local ctx = setmetatable({ options = opts }, Harness)
    reset_globals(ctx, opts.saved, opts.legacy)
    load_addon(ctx)
    ctx:_run_lifecycle()
    return ctx
end

function Harness:_run_lifecycle()
    local store = assert(self.AddonNS.Events.___harness_store, "Event store not initialised")
    for _, fn in ipairs(store.lifecycle or {}) do
        fn()
    end
end

local function fire_handlers(list, eventName, ...)
    if not list then
        return
    end
    for _, handler in ipairs(list) do
        handler(eventName, ...)
    end
end

function Harness:events()
    local store = assert(self.AddonNS.Events.___harness_store, "Event store not initialised")
    return {
        fire_game = function(_, eventName, ...)
            fire_handlers(store.game[eventName], eventName, ...)
        end,
        fire_custom = function(_, eventName, ...)
            self.AddonNS.Events:TriggerCustomEvent(eventName, ...)
        end,
    }
end

function Harness:set_container_item(bag, slot, itemID)
    self._container_slots[bag] = self._container_slots[bag] or {}
    self._container_slots[bag][slot] = itemID
end

function Harness:snapshot()
    return deep_copy(_G.dev_MyBagsDB or {})
end

function Harness:snapshot_subset(keys)
    local snapshot = self:snapshot()
    local subset = {}
    for _, key in ipairs(keys) do
        subset[key] = snapshot[key]
    end
    return subset
end

return {
    new = function(opts)
        return Harness.new(opts)
    end,
}
