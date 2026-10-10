local addonName, AddonNS = ...

AddonNS.ItemButtonSearchOverlay = {}

-- Blizzard drives ItemContextOverlay for two independent reasons (see
-- ItemButtonMixin:UpdateItemContextOverlay): the item does not match the
-- search box, or the item does not fit the current item context (for example
-- non-warbound items while the Warbank tab is open). MyBags widens the search
-- result set beyond Blizzard's, so it suppresses the overlay for items it
-- considers matched, but a context mismatch must keep its darkening.
--
-- Widen search results through texture alpha so Blizzard retains ownership
-- of the search and context fields it updates during its own refreshes.
local function isItemContextMismatch(itemButton)
    return itemButton.itemContextMatchResult == ItemButtonUtil.ItemContextMatchResult.Mismatch
end

function AddonNS.ItemButtonSearchOverlay:Apply(itemButton, includeInSearch)
    itemButton._myBagsIncludeInSearch = includeInSearch
    if not itemButton._myBagsSearchOverlayHooked then
        hooksecurefunc(itemButton, "UpdateItemContextOverlay", function()
            self:Reapply(itemButton)
        end)
        itemButton._myBagsSearchOverlayHooked = true
    end
    local alpha = 1
    if includeInSearch and not isItemContextMismatch(itemButton) then
        alpha = 0
    end
    if itemButton.searchOverlay then
        itemButton.searchOverlay:SetAlpha(alpha)
    end
    itemButton.ItemContextOverlay:SetAlpha(alpha)
end

-- Item buttons receive context changes directly, including when bags were
-- already open. Run after Blizzard updates the texture and its shown state.
function AddonNS.ItemButtonSearchOverlay:Reapply(itemButton)
    self:Apply(itemButton, itemButton._myBagsIncludeInSearch)
end
