local addonEnv = {
    db = {},
}

local newItemsSettingsChunk = assert(loadfile("newItemsSettings.lua"))
newItemsSettingsChunk("MyBags", addonEnv)

local function assertTrue(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

assertTrue(addonEnv.NewItemsSettings:IsEnabled(), "new items categorizer defaults to enabled")

addonEnv.NewItemsSettings:SetEnabled(false)
assertTrue(not addonEnv.NewItemsSettings:IsEnabled(), "new items categorizer can be disabled")
assertTrue(addonEnv.db.settings.newItemsCategorizerEnabled == false, "disabled state persisted")

addonEnv.NewItemsSettings:SetEnabled(true)
assertTrue(addonEnv.NewItemsSettings:IsEnabled(), "new items categorizer can be re-enabled")
assertTrue(addonEnv.db.settings == nil, "enabled state prunes persisted settings root")

addonEnv.db.settings = { newItemsCategorizerEnabled = "broken_value" }
assertTrue(addonEnv.NewItemsSettings:IsEnabled(), "invalid persisted value normalizes to enabled")

print("✓ new items settings persistence")
