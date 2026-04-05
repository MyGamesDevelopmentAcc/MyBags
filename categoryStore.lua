local addonName, AddonNS = ...

-- CategoryStore manages wrapper categories and shared layout state.
-- Raw categories are owned by categorizers; this store wraps them with
-- namespaced IDs and keeps layout/collapsed/itemOrder in a common place.

local CategoryStore = {}
CategoryStore.__index = CategoryStore

local UNASSIGNED_ID = "unassigned"
local SINGLETON_SUFFIX = "singleton"
local DEFAULT_LAYOUT_SCOPE = "bag"
local BANK_CHARACTER_SCOPE = "bank-character"
local BANK_ACCOUNT_SCOPE = "bank-account"
local BANK_MIN_NUM_COLUMNS = 5
local BANK_MAX_NUM_COLUMNS = 10

local function defaultIsProtected()
    return false
end

local function defaultGetDisplayName(self)
    return self:GetName()
end

local function defaultOnRightClick()
    return false
end

local function defaultOnLeftClickConfigMode()
    return false
end

local function defaultIsVisibleInScope()
    return true
end

local function defaultNoop()
end

local function compute_wrapper_ids(categorizerId, rawId)
    if categorizerId == UNASSIGNED_ID then
        return UNASSIGNED_ID, UNASSIGNED_ID .. "::" .. (rawId or "")
    end
    local normalizedRaw = rawId
    if normalizedRaw == "" then
        normalizedRaw = SINGLETON_SUFFIX
    end
    local wrapperId = categorizerId .. "-" .. normalizedRaw
    local rawKey = categorizerId .. "::" .. normalizedRaw
    return wrapperId, rawKey
end

local function default_raw_methods(raw)
    -- Provide safe defaults for wrapper-facing methods so internal callers can
    -- always use strict direct calls.
    raw.IsProtected = raw.IsProtected or defaultIsProtected
    raw.GetDisplayName = raw.GetDisplayName or defaultGetDisplayName
    raw.OnRightClick = raw.OnRightClick or defaultOnRightClick
    raw.OnLeftClickConfigMode = raw.OnLeftClickConfigMode or defaultOnLeftClickConfigMode
    raw.IsVisibleInScope = raw.IsVisibleInScope or defaultIsVisibleInScope
    raw.OnItemAssigned = raw.OnItemAssigned or defaultNoop
    raw.OnItemUnassigned = raw.OnItemUnassigned or defaultNoop
    return raw
end

local function wrap_category(store, categorizerId, rawCategory)
    if not rawCategory or not rawCategory.GetId then
        return nil
    end
    default_raw_methods(rawCategory)
    local rawId = rawCategory:GetId() or ""
    local wrapperId, rawKey = compute_wrapper_ids(categorizerId, rawId)
    local existing = store._wrappersByRaw[rawKey]
    if existing then
        -- Update mutable fields in place to reuse the same wrapper object.
        existing._raw = rawCategory
        existing.name = rawCategory:GetName()
        return existing
    end
    local wrapper = {
        _raw = rawCategory,
        _categorizerId = categorizerId,
        _rawKey = rawKey,
        id = wrapperId,
        name = rawCategory:GetName(),
    }
    function wrapper:GetId()
        return self.id
    end
    function wrapper:GetName()
        return self._raw:GetName()
    end
    function wrapper:GetDisplayName(itemsCount)
        return self._raw:GetDisplayName(itemsCount)
    end
    function wrapper:IsProtected()
        return self._raw:IsProtected()
    end
    function wrapper:OnRightClick(...)
        return self._raw:OnRightClick(...)
    end
    function wrapper:OnLeftClickConfigMode(...)
        return self._raw:OnLeftClickConfigMode(...)
    end
    function wrapper:IsVisibleInScope(scope)
        return self._raw:IsVisibleInScope(scope)
    end
    function wrapper:OnItemAssigned(itemId, context)
        self._raw:OnItemAssigned(itemId, context)
    end
    function wrapper:OnItemUnassigned(itemId, context)
        self._raw:OnItemUnassigned(itemId, context)
    end
    store._wrappersByRaw[rawKey] = wrapper
    if wrapperId == UNASSIGNED_ID then
        store._unassigned = wrapper
    end
    return wrapper
end

function CategoryStore:new()
    local instance = setmetatable({
        db = nil,
        _wrappersById = {},
        _wrappersByName = {},
        _wrappersByRaw = {},
        _wrappersByCategorizer = {},
        _unassigned = nil,
    }, CategoryStore)
    return instance
end

local function ensure_db(self)
    if not self.db then
        self:LoadOrBootstrap({})
    end
end

local function defaultColumnCount(scope)
    if scope == BANK_CHARACTER_SCOPE or scope == BANK_ACCOUNT_SCOPE then
        return BANK_MIN_NUM_COLUMNS
    end
    return AddonNS.Const.DEFAULT_NUM_COLUMNS
end

local function minColumnCount(scope)
    if scope == BANK_CHARACTER_SCOPE or scope == BANK_ACCOUNT_SCOPE then
        return BANK_MIN_NUM_COLUMNS
    end
    return AddonNS.Const.MIN_NUM_COLUMNS
end

local function maxColumnCount(scope)
    if scope == BANK_CHARACTER_SCOPE or scope == BANK_ACCOUNT_SCOPE then
        return BANK_MAX_NUM_COLUMNS
    end
    return AddonNS.Const.MAX_NUM_COLUMNS
end

local function sanitizeColumnCount(count, scope)
    local numeric = tonumber(count) or defaultColumnCount(scope)
    numeric = math.floor(numeric)
    local minCount = minColumnCount(scope)
    if numeric < minCount then
        return minCount
    end
    local maxCount = maxColumnCount(scope)
    if numeric > maxCount then
        return maxCount
    end
    return numeric
end

local function ensure_layout_shape(layout)
    layout.columns = layout.columns or {}
    layout.collapsed = layout.collapsed or {}
end

local function normalize_layout_scope(scope)
    if scope == nil or scope == "" then
        return DEFAULT_LAYOUT_SCOPE
    end
    return scope
end

local function migrate_legacy_layout_root_to_scopes(layout)
    if layout.columnCount == nil and layout.columns == nil and layout.collapsed == nil then
        return
    end
    if layout[DEFAULT_LAYOUT_SCOPE] then
        layout.columnCount = nil
        layout.columns = nil
        layout.collapsed = nil
        return
    end
    layout[DEFAULT_LAYOUT_SCOPE] = {
        columnCount = layout.columnCount,
        columns = layout.columns,
        collapsed = layout.collapsed,
    }
    layout.columnCount = nil
    layout.columns = nil
    layout.collapsed = nil
end

local function sync_legacy_layout_root(layoutRoot)
    local bagLayout = layoutRoot[DEFAULT_LAYOUT_SCOPE]
    if not bagLayout then
        layoutRoot.columnCount = nil
        layoutRoot.columns = nil
        layoutRoot.collapsed = nil
        return
    end
    layoutRoot.columnCount = bagLayout.columnCount
    layoutRoot.columns = bagLayout.columns
    layoutRoot.collapsed = bagLayout.collapsed
end

local normalize_columns_to_count
local dedupe_columns_globally

local function get_scope_layout(layoutRoot, scope)
    local normalizedScope = normalize_layout_scope(scope)
    layoutRoot[normalizedScope] = layoutRoot[normalizedScope] or {}
    local scopedLayout = layoutRoot[normalizedScope]
    ensure_layout_shape(scopedLayout)
    scopedLayout.columnCount = sanitizeColumnCount(scopedLayout.columnCount, normalizedScope)
    scopedLayout.columns = normalize_columns_to_count(scopedLayout.columns, scopedLayout.columnCount)
    return scopedLayout
end

normalize_columns_to_count = function(columns, targetCount)
    columns = columns or {}
    for columnIndex = 1, targetCount do
        columns[columnIndex] = columns[columnIndex] or {}
    end
    if #columns > targetCount then
        local lastVisible = columns[targetCount]
        for columnIndex = targetCount + 1, #columns do
            for _, categoryId in ipairs(columns[columnIndex] or {}) do
                table.insert(lastVisible, categoryId)
            end
            columns[columnIndex] = nil
        end
    end
    dedupe_columns_globally(columns, targetCount)
    return columns
end

dedupe_columns_globally = function(columns, targetCount)
    local seen = {}
    for columnIndex = targetCount, 1, -1 do
        local column = columns[columnIndex] or {}
        local writeIndex = #column
        for readIndex = #column, 1, -1 do
            local id = column[readIndex]
            if not seen[id] then
                seen[id] = true
                column[writeIndex] = id
                writeIndex = writeIndex - 1
            end
        end
        for idx = 1, writeIndex do
            column[idx] = nil
        end
        columns[columnIndex] = column
    end
end

function CategoryStore:LoadOrBootstrap(db, legacyDb)
    self.db = db or {}
    self.db.categorizers = self.db.categorizers or {}
    self.db.itemOrder = self.db.itemOrder or {}
    self.db.layout = self.db.layout or {}
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    get_scope_layout(self.db.layout, DEFAULT_LAYOUT_SCOPE)
    sync_legacy_layout_root(self.db.layout)
    self:_migrateFromLegacy(legacyDb)
    self:_migrateFromOldDb()
    get_scope_layout(self.db.layout, DEFAULT_LAYOUT_SCOPE)
    sync_legacy_layout_root(self.db.layout)
    self:_normalizeUnassignedLayout()
    sync_legacy_layout_root(self.db.layout)
    return self
end

local function normalize_legacy_array(source)
    local out = {}
    for _, v in ipairs(source or {}) do
        table.insert(out, v)
    end
    return out
end

local function has_layout_or_item_order_data(db)
    if not db then
        return false
    end
    local layout = db.layout or {}
    local bagLayout = layout[DEFAULT_LAYOUT_SCOPE] or layout
    local columns = bagLayout.columns or {}
    for index = 1, #columns do
        if #(columns[index] or {}) > 0 then
            return true
        end
    end
    local collapsed = bagLayout.collapsed or {}
    for _, flag in pairs(collapsed) do
        if flag then
            return true
        end
    end
    return #(db.itemOrder or {}) > 0
end

function CategoryStore:_migrateFromLegacy(legacyDb)
    if not legacyDb then
        return
    end
    -- Shared migration only: keep item order/layout in this module.
    if has_layout_or_item_order_data(self.db) then
        return
    end

    -- Layout: preserve legacy layout values as-is. Custom category specific ID/name
    -- conversion is handled by CustomCategories migration.
    local legacyColumns = legacyDb.categoriesColumnAssignments or {}
    local bagLayout = get_scope_layout(self.db.layout, DEFAULT_LAYOUT_SCOPE)
    bagLayout.columnCount = sanitizeColumnCount(bagLayout.columnCount)
    bagLayout.columns = bagLayout.columns or {}
    for columnIndex = 1, bagLayout.columnCount do
        bagLayout.columns[columnIndex] = {}
        local sourceColumn = legacyColumns[columnIndex] or {}
        for _, id in ipairs(sourceColumn) do
            table.insert(bagLayout.columns[columnIndex], id)
        end
    end

    -- Collapsed: preserve raw legacy keys. Custom conversion is handled elsewhere.
    local legacyCollapsed = legacyDb.collapsedCategories or {}
    bagLayout.collapsed = bagLayout.collapsed or {}
    for id, flag in pairs(legacyCollapsed) do
        if flag then
            bagLayout.collapsed[id] = true
        end
    end

    -- Item order is shared state and stays here.
    self.db.itemOrder = normalize_legacy_array(legacyDb.itemOrder or {})
end

function CategoryStore:_migrateFromOldDb()
    -- Legacy custom category schema migration is owned by CustomCategories.
    -- Shared state migration remains in this module.
    self.db.itemOrder = normalize_legacy_array(self.db.itemOrder or {})
end

local function normalize_unassigned_id(id)
    if not id then
        return nil
    end
    if id == UNASSIGNED_ID then
        return UNASSIGNED_ID
    end
    if id:match("^[^%-]+%-unassigned$") then
        return UNASSIGNED_ID
    end
    return id
end

function CategoryStore:_normalizeUnassignedLayout()
    self.db.layout = self.db.layout or {}
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    for scope, scopedLayout in pairs(self.db.layout) do
        if type(scopedLayout) == "table" and scope ~= "columns" and scope ~= "collapsed" then
            local normalizedLayout = get_scope_layout(self.db.layout, scope)
            for columnIndex = 1, #normalizedLayout.columns do
                local column = normalizedLayout.columns[columnIndex]
                local seen = {}
                for idx = #column, 1, -1 do
                    local normalized = normalize_unassigned_id(column[idx])
                    column[idx] = normalized
                    if normalized == UNASSIGNED_ID then
                        if seen[UNASSIGNED_ID] then
                            table.remove(column, idx)
                        else
                            seen[UNASSIGNED_ID] = true
                        end
                    end
                end
            end
            local collapsed = normalizedLayout.collapsed or {}
            local normalizedCollapsed = {}
            for id, flag in pairs(collapsed) do
                if flag then
                    local normalized = normalize_unassigned_id(id)
                    if normalized then
                        normalizedCollapsed[normalized] = true
                    end
                end
            end
            normalizedLayout.collapsed = normalizedCollapsed
        end
    end
    sync_legacy_layout_root(self.db.layout)
end

function CategoryStore:GetCategorizerDb(categorizerId)
    ensure_db(self)
    self.db.categorizers[categorizerId] = self.db.categorizers[categorizerId] or { id = categorizerId, categories = {} }
    local entry = self.db.categorizers[categorizerId]
    entry.id = entry.id or categorizerId
    entry.categories = entry.categories or {}
    return entry
end

function CategoryStore:ResetWrappers()
    self._wrappersById = {}
    self._wrappersByName = {}
    self._wrappersByRaw = {}
    self._wrappersByCategorizer = {}
    self._unassigned = nil
end

function CategoryStore:RefreshCategorizer(categorizerId, rawCategories)
    -- Drop existing wrappers for this categorizer.
    local existing = self._wrappersByCategorizer[categorizerId]
    if existing then
        for _, wrapper in ipairs(existing) do
            self._wrappersById[wrapper.id] = nil
            local name = wrapper:GetName()
            if name and self._wrappersByName[name] then
                self._wrappersByName[name][wrapper.id] = nil
            end
            local rawKey = wrapper._rawKey
            if not rawKey then
                local rawId = wrapper:GetId():match("^[^%-]+%-(.+)$")
                if rawId then
                    rawKey = wrapper._categorizerId .. "::" .. rawId
                end
            end
            if rawKey then
                self._wrappersByRaw[rawKey] = nil
            end
        end
    end
    if categorizerId == UNASSIGNED_ID then
        self._unassigned = nil
    end
    local list = {}
    rawCategories = rawCategories or {}
    for index = 1, #rawCategories do
        local wrapper = wrap_category(self, categorizerId, rawCategories[index])
        if wrapper then
            table.insert(list, wrapper)
            self._wrappersById[wrapper.id] = wrapper
            local name = wrapper:GetName()
            if name then
                self._wrappersByName[name] = self._wrappersByName[name] or {}
                self._wrappersByName[name][wrapper.id] = wrapper
            end
        end
    end
    self._wrappersByCategorizer[categorizerId] = list
    return list
end

function CategoryStore:GetWrapperForRaw(categorizerId, rawCategory)
    local rawId = rawCategory and rawCategory.GetId and rawCategory:GetId()
    if not rawId then
        return nil
    end
    local wrapperId = compute_wrapper_ids(categorizerId, rawId)
    local existing = self._wrappersById[wrapperId]
    if existing then
        return existing
    end
    local wrapper = wrap_category(self, categorizerId, rawCategory)
    if not wrapper then
        return nil
    end
    self._wrappersById[wrapper.id] = wrapper
    local name = wrapper:GetName()
    if name then
        self._wrappersByName[name] = self._wrappersByName[name] or {}
        self._wrappersByName[name][wrapper.id] = wrapper
    end
    self._wrappersByCategorizer[categorizerId] = self._wrappersByCategorizer[categorizerId] or {}
    table.insert(self._wrappersByCategorizer[categorizerId], wrapper)
    return wrapper
end

function CategoryStore:Get(id)
    if not id then
        return nil
    end
    if id == UNASSIGNED_ID then
        return self._unassigned
    end
    return self._wrappersById[id]
end

function CategoryStore:GetByName(name)
    -- Names are not globally unique in this model; return nil to avoid ambiguity.
    if not name then
        return nil
    end
    local map = self._wrappersByName[name]
    if not map then
        return nil
    end
    for _, wrapper in pairs(map) do
        return wrapper
    end
    return nil
end

function CategoryStore:GetByCategorizer(categorizerId)
    return self._wrappersByCategorizer[categorizerId] or {}
end

function CategoryStore:GetLayoutColumns(scope)
    ensure_db(self)
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    return get_scope_layout(self.db.layout, scope).columns
end

function CategoryStore:SetLayoutColumns(columns, scope)
    ensure_db(self)
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    local scopedLayout = get_scope_layout(self.db.layout, scope)
    scopedLayout.columns = columns
    self:EnsureLayoutColumnsCount(scope)
    sync_legacy_layout_root(self.db.layout)
end

function CategoryStore:EnsureLayoutColumnsCount(scope)
    ensure_db(self)
    self.db.layout = self.db.layout or {}
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    get_scope_layout(self.db.layout, scope)
    sync_legacy_layout_root(self.db.layout)
end

function CategoryStore:GetColumnCount(scope)
    ensure_db(self)
    self:EnsureLayoutColumnsCount(scope)
    return get_scope_layout(self.db.layout, scope).columnCount
end

function CategoryStore:SetColumnCount(count, scope)
    ensure_db(self)
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    local normalizedScope = normalize_layout_scope(scope)
    local scopedLayout = get_scope_layout(self.db.layout, normalizedScope)
    scopedLayout.columnCount = sanitizeColumnCount(count, normalizedScope)
    self:EnsureLayoutColumnsCount(scope)
    sync_legacy_layout_root(self.db.layout)
end

function CategoryStore:SetCollapsed(id, collapsed, scope)
    ensure_db(self)
    if not id then
        return
    end
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    local scopedLayout = get_scope_layout(self.db.layout, scope)
    if collapsed then
        scopedLayout.collapsed[id] = true
    else
        scopedLayout.collapsed[id] = nil
    end
    sync_legacy_layout_root(self.db.layout)
end

function CategoryStore:IsCollapsed(id, scope)
    ensure_db(self)
    migrate_legacy_layout_root_to_scopes(self.db.layout)
    local scopedLayout = get_scope_layout(self.db.layout, scope)
    return scopedLayout.collapsed[id] or false
end

function CategoryStore:GetUnassigned()
    if not self._unassigned then
        error("Unassigned categorizer not registered")
    end
    return self._unassigned
end

AddonNS.CategoryStore = CategoryStore:new()
