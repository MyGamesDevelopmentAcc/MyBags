local addonName, AddonNS = ...

AddonNS.ContainerSearch = {}

function AddonNS.ContainerSearch:EvaluateVisibility(defaultMatch, searchEvaluator, itemInfo, itemButton)
    local includeInSearch = defaultMatch
    local queryMatch = false
    if not defaultMatch and searchEvaluator then
        local payload = AddonNS.CustomCategories:GetItemQueryPayload(itemInfo.itemID, itemButton, itemInfo)
        includeInSearch, queryMatch = AddonNS.QueryCategories:EvaluateSearchUnion(defaultMatch, searchEvaluator, payload)
    end
    return includeInSearch, queryMatch
end

function AddonNS.ContainerSearch:ResolveIncludeInSearch(itemButton, itemInfo, searchActive, searchEvaluator)
    local cachedDefaultMatch = itemButton._myBagsDefaultSearchMatch
    local defaultMatch = true
    if searchActive and type(cachedDefaultMatch) == "boolean" then
        defaultMatch = cachedDefaultMatch
    elseif searchActive then
        defaultMatch = not itemInfo.isFiltered
    end
    return self:EvaluateVisibility(defaultMatch, searchEvaluator, itemInfo, itemButton)
end

local function buildCategoryCacheKey(itemButton, itemInfo, scope, categorizationVersion)
    return table.concat({
        tostring(itemButton:GetBagID()),
        tostring(itemButton:GetID()),
        tostring(itemInfo.itemID),
        tostring(itemInfo.stackCount),
        tostring(itemInfo.quality),
        tostring(itemInfo.hyperlink),
        tostring(scope),
        tostring(categorizationVersion),
    }, ":")
end

function AddonNS.ContainerSearch:ResolveCategory(itemButton, itemInfo, scope, categorizationVersion)
    local cacheKey = buildCategoryCacheKey(itemButton, itemInfo, scope, categorizationVersion)
    if itemButton._myBagsCategoryCacheKey == cacheKey and itemButton._myBagsCategoryCacheValue then
        return itemButton._myBagsCategoryCacheValue
    end
    local category = AddonNS.Categories:Categorize(itemInfo.itemID, itemButton)
    itemButton._myBagsCategoryCacheKey = cacheKey
    itemButton._myBagsCategoryCacheValue = category
    return category
end

