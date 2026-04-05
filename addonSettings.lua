local addonName, AddonNS = ...

local TOOLTIP_MODE_SETTINGS_VARIABLE = "MYBAGS_TOOLTIP_MODE"
local NEW_ITEMS_CATEGORIZER_SETTINGS_VARIABLE = "MYBAGS_NEW_ITEMS_CATEGORIZER_ENABLED"
local registered = false

local function registerAddonSettings()
    if registered then
        return
    end
    if not Settings then
        return
    end
    if not AddonNS.TooltipSettings then
        error("TooltipSettings missing")
    end
    if not AddonNS.NewItemsSettings then
        error("NewItemsSettings missing")
    end

    local category = Settings.RegisterVerticalLayoutCategory("MyBags")
    category:SetShouldSortAlphabetically(true)

    local function getValue()
        return AddonNS.TooltipSettings:GetMode()
    end

    local function setValue(value)
        AddonNS.TooltipSettings:SetMode(value)
    end

    local setting = Settings.RegisterProxySetting(
        category,
        TOOLTIP_MODE_SETTINGS_VARIABLE,
        Settings.VarType.String,
        "Item Tooltip Mode",
        AddonNS.TooltipSettings.MODE_DEFAULT,
        getValue,
        setValue
    )

    local function getOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(AddonNS.TooltipSettings.MODE_DEFAULT, "Default (show hint; details on Shift)")
        container:Add(AddonNS.TooltipSettings.MODE_SHIFT_ONLY, "Hide hint; details only on Shift")
        container:Add(AddonNS.TooltipSettings.MODE_DISABLED, "Disable MyBags tooltip additions")
        return container:GetData()
    end

    Settings.CreateDropdown(category, setting, getOptions, "Control MyBags item tooltip additions.")

    local function getNewItemsCategorizerEnabled()
        return AddonNS.NewItemsSettings:IsEnabled()
    end

    local function setNewItemsCategorizerEnabled(value)
        AddonNS.NewItemsSettings:SetEnabled(value)
    end

    local newItemsSetting = Settings.RegisterProxySetting(
        category,
        NEW_ITEMS_CATEGORIZER_SETTINGS_VARIABLE,
        Settings.VarType.Boolean,
        "Enable New Items categorizer",
        true,
        getNewItemsCategorizerEnabled,
        setNewItemsCategorizerEnabled
    )

    Settings.CreateCheckbox(category, newItemsSetting,
        "Disable this to stop the built-in New Items category from matching items.")
    Settings.RegisterAddOnCategory(category)
    registered = true
end

function AddonNS.Events:ADDON_LOADED(eventName, loadedAddonName)
    if loadedAddonName == "Blizzard_Settings" then
        registerAddonSettings()
    end
end

AddonNS.Events:RegisterEvent("ADDON_LOADED")

if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Settings") then
    registerAddonSettings()
end
