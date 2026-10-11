local revision = 1
local Categories = { old = {}, new = {} }
local AddonNS = {
    Categories = {
        Categorize = function(_, itemID)
            return revision == 1 and Categories.old or Categories.new
        end,
    },
    CustomCategories = {
        GetItemQueryPayload = function(_, itemID, button, info)
            assert(info.itemID == itemID)
            return { itemID = itemID, scope = button.MyBagsScope }
        end,
    },
    QueryCategories = {
        EvaluateSearchUnion = function(_, defaultMatch, evaluator, payload)
            local queryMatch = evaluator(payload)
            return defaultMatch or queryMatch, queryMatch
        end,
    },
}
assert(loadfile("containerSearch.lua"))("MyBags", AddonNS)
local Search = AddonNS.ContainerSearch
local button = { GetBagID = function() return 0 end, GetID = function() return 1 end }
local info = { itemID = 42, stackCount = 2, quality = 1, hyperlink = "item:42", isFiltered = true }
for _, scope in ipairs({ "bag", "bank-character", "bank-account" }) do
    button.MyBagsScope = scope
    button._myBagsCategoryCacheKey = nil
    revision = 1
    assert(Search:ResolveCategory(button, info, scope, 1) == Categories.old)
    revision = 2
    assert(Search:ResolveCategory(button, info, scope, 1) == Categories.old, "unchanged cache input must reuse category")
    assert(Search:ResolveCategory(button, info, scope, 2) == Categories.new, "version must invalidate cache")
    revision = 1
    assert(Search:ResolveCategory(button, info, scope .. "-changed", 2) == Categories.old, "scope must invalidate cache")
    revision = 2
    info.stackCount = info.stackCount + 1
    assert(Search:ResolveCategory(button, info, scope .. "-changed", 2) == Categories.new, "item changes invalidate cache")
    button._myBagsDefaultSearchMatch = nil
    assert(Search:ResolveIncludeInSearch(button, info, false, nil), "inactive search includes filtered items")
    assert(not Search:ResolveIncludeInSearch(button, info, true, nil), "filtered items without a query are excluded")
    local included, queryMatch = Search:ResolveIncludeInSearch(button, info, true, function(payload)
        return payload.itemID == 42 and payload.scope == scope
    end)
    assert(included and queryMatch, "query-only match uses item payload and scope")
    button._myBagsDefaultSearchMatch = true
    included, queryMatch = Search:ResolveIncludeInSearch(button, info, true, function() error("default match should skip query") end)
    assert(included and not queryMatch)
    button._myBagsDefaultSearchMatch = false
    info.isFiltered = false
    assert(not Search:ResolveIncludeInSearch(button, info, true, nil), "captured default match takes precedence")
    info.isFiltered = true
end
local ok = pcall(function() Search:ResolveCategory({}, info, "bag", 1) end)
assert(not ok, "invalid internal item-button contract must fail")
print("container_search_test passed")
