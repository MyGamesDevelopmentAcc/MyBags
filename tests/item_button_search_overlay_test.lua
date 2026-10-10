local addonEnv = {}

ItemButtonUtil = {
    ItemContextMatchResult = {
        Match = 1,
        Mismatch = 2,
        DoesNotApply = 3,
    },
}

_G.hooksecurefunc = function(object, methodName, hook)
    local original = object[methodName]
    object[methodName] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
    object.hookCount = (object.hookCount or 0) + 1
end

local overlayChunk = assert(loadfile("utils/itemButtonSearchOverlay.lua"))
overlayChunk("MyBags", addonEnv)

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

local function newTexture()
    local texture = { alpha = nil }
    function texture:SetAlpha(alpha)
        self.alpha = alpha
    end
    function texture:SetShown(shown)
        self.shown = shown
    end
    return texture
end

local function newItemButton(contextMatchResult)
    local button = {
        ItemContextOverlay = newTexture(),
        searchOverlay = newTexture(),
        itemContextMatchResult = contextMatchResult,
        matchesSearch = true,
    }
    function button:UpdateItemContextOverlay()
        local mismatch = self.itemContextMatchResult == ItemButtonUtil.ItemContextMatchResult.Mismatch
        self.ItemContextOverlay:SetShown(not self.matchesSearch or mismatch)
    end
    function button:UpdateItemContextMatching(result)
        self.itemContextMatchResult = result
        self:UpdateItemContextOverlay()
    end
    return button
end

run("included item with no context hides both overlays", function()
    local itemButton = newItemButton(nil)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "context overlay alpha")
    assertEqual(itemButton.searchOverlay.alpha, 0, "search overlay alpha")
    assertEqual(itemButton._myBagsIncludeInSearch, true, "include state")
end)

run("included item with matching context hides overlay", function()
    local itemButton = newItemButton(ItemButtonUtil.ItemContextMatchResult.Match)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "context overlay alpha")
end)

run("included item with context mismatch keeps overlay visible", function()
    local itemButton = newItemButton(ItemButtonUtil.ItemContextMatchResult.Mismatch)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    assertEqual(itemButton.ItemContextOverlay.alpha, 1, "context overlay alpha")
    assertEqual(itemButton.searchOverlay.alpha, 1, "search overlay alpha")
    assertEqual(itemButton._myBagsIncludeInSearch, true, "include state")
end)

run("excluded item keeps overlay visible regardless of context", function()
    local itemButton = newItemButton(ItemButtonUtil.ItemContextMatchResult.Match)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, false)
    assertEqual(itemButton.ItemContextOverlay.alpha, 1, "context overlay alpha")
    assertEqual(itemButton._myBagsIncludeInSearch, false, "include state")
end)

run("button without legacy searchOverlay is handled", function()
    local itemButton = newItemButton(nil)
    itemButton.searchOverlay = nil
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "context overlay alpha")
end)

run("reapply after context change restores darkening for included item", function()
    local itemButton = newItemButton(ItemButtonUtil.ItemContextMatchResult.DoesNotApply)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "before context change")

    itemButton.itemContextMatchResult = ItemButtonUtil.ItemContextMatchResult.Mismatch
    addonEnv.ItemButtonSearchOverlay:Reapply(itemButton)
    assertEqual(itemButton.ItemContextOverlay.alpha, 1, "after context change")

    itemButton.itemContextMatchResult = ItemButtonUtil.ItemContextMatchResult.DoesNotApply
    addonEnv.ItemButtonSearchOverlay:Reapply(itemButton)
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "after context cleared")
end)

run("direct button context refresh darkens already-open bags and clears on close", function()
    local itemButton = newItemButton(ItemButtonUtil.ItemContextMatchResult.DoesNotApply)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    itemButton:UpdateItemContextMatching(ItemButtonUtil.ItemContextMatchResult.Mismatch)
    assertEqual(itemButton.ItemContextOverlay.alpha, 1, "bank context should restore alpha")
    assertEqual(itemButton.ItemContextOverlay.shown, true, "ineligible item should be visible and darkened")
    itemButton:UpdateItemContextMatching(ItemButtonUtil.ItemContextMatchResult.DoesNotApply)
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "closing bank should clear darkening")
    assertEqual(itemButton.ItemContextOverlay.shown, false, "Blizzard should hide cleared context")
end)

run("query match stays undimmed through Blizzard search refresh", function()
    local itemButton = newItemButton(ItemButtonUtil.ItemContextMatchResult.DoesNotApply)
    itemButton.matchesSearch = false
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    itemButton:UpdateItemContextOverlay()
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "query-only match should stay undimmed")
    assertEqual(itemButton.matchesSearch, false, "Blizzard search state must remain untouched")
    itemButton:UpdateItemContextMatching(ItemButtonUtil.ItemContextMatchResult.Mismatch)
    assertEqual(itemButton.ItemContextOverlay.alpha, 1, "bank eligibility must override query match")
end)

run("repeated Apply installs one hook and uses current inclusion state", function()
    local itemButton = newItemButton(ItemButtonUtil.ItemContextMatchResult.Match)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, false)
    itemButton:UpdateItemContextOverlay()
    assertEqual(itemButton.ItemContextOverlay.alpha, 1, "excluded state should be preserved")
    assertEqual(itemButton.hookCount, 1, "button should have exactly one hook")
    addonEnv.ItemButtonSearchOverlay:Apply(itemButton, true)
    itemButton:UpdateItemContextOverlay()
    assertEqual(itemButton.ItemContextOverlay.alpha, 0, "new inclusion should be preserved")
end)

print("item_button_search_overlay_test passed")
