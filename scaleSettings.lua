local addonName, AddonNS = ...

local MINIMUM_SCALE = 0.05
local DEFAULT_MAXIMUM_SCALE = 1
local maximumScale = DEFAULT_MAXIMUM_SCALE

AddonNS.ScaleSettings = {
    MINIMUM_SCALE = MINIMUM_SCALE,
    DEFAULT_MAXIMUM_SCALE = DEFAULT_MAXIMUM_SCALE,
}

local function loadSettings()
    local settings = AddonNS.db.settings
    local value = type(settings) == "table" and settings.maximumScale or nil
    -- SavedVariables are external input; invalid values restore the default.
    if type(value) == "number" and value >= MINIMUM_SCALE and value <= DEFAULT_MAXIMUM_SCALE then
        maximumScale = value
    else
        maximumScale = DEFAULT_MAXIMUM_SCALE
    end
end

local function saveSettings()
    local db = AddonNS.db
    if maximumScale == DEFAULT_MAXIMUM_SCALE then
        if type(db.settings) == "table" then
            db.settings.maximumScale = nil
            if next(db.settings) == nil then
                db.settings = nil
            end
        else
            db.settings = nil
        end
    else
        if type(db.settings) ~= "table" then
            db.settings = {}
        end
        db.settings.maximumScale = maximumScale
    end
end

function AddonNS.ScaleSettings:GetMaximumScale()
    return maximumScale
end

function AddonNS.ScaleSettings:SetMaximumScale(scale)
    assert(scale >= MINIMUM_SCALE and scale <= DEFAULT_MAXIMUM_SCALE, "Maximum scale is outside supported bounds")
    maximumScale = scale
end

AddonNS.Events:OnInitialize(loadSettings)
AddonNS.Events:RegisterEvent("PLAYER_LOGOUT", saveSettings)
