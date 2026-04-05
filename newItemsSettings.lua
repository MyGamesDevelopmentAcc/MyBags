local addonName, AddonNS = ...

local function getSettingsRoot()
    local db = AddonNS.db
    if type(db) ~= "table" then
        error("NewItemsSettings missing db")
    end
    if type(db.settings) ~= "table" then
        return nil
    end
    return db.settings
end

local function pruneEmptySettingsRoot()
    local db = AddonNS.db
    if type(db) ~= "table" then
        error("NewItemsSettings missing db")
    end
    if type(db.settings) ~= "table" then
        return
    end
    if next(db.settings) == nil then
        db.settings = nil
    end
end

AddonNS.NewItemsSettings = {}

function AddonNS.NewItemsSettings:IsEnabled()
    local settings = getSettingsRoot()
    if not settings then
        return true
    end
    local value = settings.newItemsCategorizerEnabled
    if type(value) ~= "boolean" then
        return true
    end
    return value
end

function AddonNS.NewItemsSettings:SetEnabled(enabled)
    if enabled then
        local settings = getSettingsRoot()
        if settings then
            settings.newItemsCategorizerEnabled = nil
        end
        pruneEmptySettingsRoot()
        return true
    end
    AddonNS.db.settings = AddonNS.db.settings or {}
    AddonNS.db.settings.newItemsCategorizerEnabled = false
    return false
end
