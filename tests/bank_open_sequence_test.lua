local addonEnv = {
    Collapsed = { isCollapsed = function() end },
    Const = { ITEM_SPACING = 4 },
}

Enum = {
    PlayerInteractionType = { Banker = 1, CharacterBanker = 2, AccountBanker = 3 },
}
ContainerFrameCombinedBags = {}
ContainerFrameCombinedBagsMixin = {}
BankFrame = {}
hooksecurefunc = function() end
Mixin = function(target, source)
    for key, value in pairs(source) do
        target[key] = value
    end
end

local bagsOpen = false
local executionTainted = true
local bankTypeTainted
local openingSearch
local registeredInteractions = {}
local searchText = "quality = 3"
local events = {}

BankItemSearchBox = {
    GetText = function() return searchText end,
    SetText = function(_, text)
        searchText = text
        table.insert(events, "search:" .. text)
    end,
}

OpenAllBags = function(owner)
    assert(owner == BankFrame, "bank must retain ownership of opened bags")
    if not bagsOpen then
        bagsOpen = true
        executionTainted = true
        table.insert(events, "bags opened")
    end
end

securecallfunction = function(fn, ...)
    local previous = executionTainted
    executionTainted = false
    fn(...)
    executionTainted = previous
end

BankFrame_Open = function()
    -- Model Blizzard's OnShow: opening customized bags can taint the caller
    -- before it writes bankType. The secure call alone cannot prevent this.
    OpenAllBags(BankFrame)
    bankTypeTainted = executionTainted
    openingSearch = searchText
    table.insert(events, "bank opened")
end

RegisterPlayerInteraction = function(interactionType, frameInfo)
    assert(frameInfo.frame == "BankFrame")
    registeredInteractions[interactionType] = frameInfo.showFunc
end

-- Blizzard captures its opener before the addon replaces the global.
for _, interactionType in pairs(Enum.PlayerInteractionType) do
    RegisterPlayerInteraction(interactionType, { frame = "BankFrame", showFunc = BankFrame_Open })
end

assert(loadfile("ContainerFrameMyBagsMixin.lua"))("MyBags", addonEnv)

for name, interactionType in pairs(Enum.PlayerInteractionType) do
    for _, initiallyOpen in ipairs({ false, true }) do
        bagsOpen = initiallyOpen
        executionTainted = true
        bankTypeTainted = nil
        openingSearch = nil
        searchText = "quality = 3"
        events = {}
        registeredInteractions[interactionType]()
        assert(bagsOpen, name .. ": bags should be open")
        assert(bankTypeTainted == false, name .. ": original opener should write bank state without execution taint")
        assert(openingSearch == "", name .. ": bank should initially open without filtering")
        assert(searchText == "quality = 3", name .. ": search should be restored")
        assert(executionTainted, name .. ": secure call should restore its caller's execution context")
        if not initiallyOpen then
            assert(events[1] == "bags opened", name .. ": bags must open before the bank")
        else
            assert(events[1] == "search:", name .. ": already-open bags should not reopen")
        end
    end
end

bagsOpen = false
BankFrame_Open()
assert(bankTypeTainted == false, "direct global opener should use the same sequence")
print("bank_open_sequence_test passed")
