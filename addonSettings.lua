local addonName, AddonNS = ...

local TOOLTIP_MODE_SETTINGS_VARIABLE = "MYBAGS_TOOLTIP_MODE"
local NEW_ITEMS_CATEGORIZER_SETTINGS_VARIABLE = "MYBAGS_NEW_ITEMS_CATEGORIZER_ENABLED"
local MAXIMUM_SCALE_SETTINGS_VARIABLE = "MYBAGS_MAXIMUM_SCALE"
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
    ScrollUtil.AddInitializedFrameCallback(SettingsPanel.CategoryList.ScrollBox, function(_, button, initializer)
        if initializer.data.category == category then
            button.Label:SetText("|cffff2459My|r|cffffffffBags|r")
        end
    end, category)


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
    local function getMaximumScalePercent()
        return AddonNS.ScaleSettings:GetMaximumScale() * 100
    end

    local function setMaximumScalePercent(value)
        AddonNS.ScaleSettings:SetMaximumScale(value / 100)
        AddonNS.ApplyContainerFrameScale()
        AddonNS.ApplyBankFrameScale()
    end

    local scaleSetting = Settings.RegisterProxySetting(
        category,
        MAXIMUM_SCALE_SETTINGS_VARIABLE,
        Settings.VarType.Number,
        "Maximum bag and bank scale",
        AddonNS.ScaleSettings.DEFAULT_MAXIMUM_SCALE * 100,
        getMaximumScalePercent,
        setMaximumScalePercent
    )
    local scaleOptions = Settings.CreateSliderOptions(AddonNS.ScaleSettings.MINIMUM_SCALE * 100, 100, 5)
    scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return string.format("%.0f%%", value)
    end)
    Settings.CreateSlider(category, scaleSetting, scaleOptions,
        "Limit the size of bags, bank, and Warbank. They can still shrink automatically to fit the screen.")

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
