package.path = package.path .. ";./?.lua;./?/init.lua"

_G.EditModeUtil = {
    GetRightActionBarWidth = function()
        return 0
    end,
}

_G.GetScreenWidth = function()
    return 1920
end

_G.GetScreenHeight = function()
    return 1080
end

_G.CONTAINER_OFFSET_Y = 80
_G.RunNextFrame = function(fn)
    fn()
end

_G.ContainerFrameCombinedBags = {
    IsShown = function()
        return false
    end,
    GetWidth = function()
        return 0
    end,
    GetHeight = function()
        return 0
    end,
    GetScale = function(self) return self.scale or 1 end,
    SetScale = function(self, scale) self.scale = scale end,
}

_G.BankFrame = {
    IsShown = function()
        return false
    end,
    GetWidth = function()
        return 0
    end,
    GetHeight = function()
        return 0
    end,
    GetScale = function(self) return self.scale or 1 end,
    SetScale = function(self, scale) self.scale = scale end,
}

local addonEnv = {
    db = {},
    Events = {
        RegisterEvent = function() end,
        OnInitialize = function() end,
    },
    printDebug = function() end,
    _Test = {},
}

assert(loadfile("scaleSettings.lua"))("MyBags", addonEnv)
local chunk = assert(loadfile("FrameParameters.lua"))
chunk("MyBags", addonEnv)

local hooks = assert(addonEnv._Test.FrameParameters, "FrameParameters test hooks should be exposed")
local computeFrameScales = hooks.ComputeFrameScales
local computeWidthScale = hooks.ComputeWidthScale
local computeWidthScaleFromRemaining = hooks.ComputeWidthScaleFromRemaining
local computeHeightScale = hooks.ComputeHeightScale
local clampScale = hooks.ClampScale
local getFrameScale = hooks.GetFrameScale

local function assertEqual(expected, actual, message)
    if expected ~= actual then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTrue(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
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

run("ClampScale clamps to [0.05, 1]", function()
    assertEqual(0.05, clampScale(-1), "negative values should clamp to minimum")
    assertEqual(0.05, clampScale(0), "zero should clamp to minimum")
    assertEqual(0.7, clampScale(0.7), "in-range values should be unchanged")
    assertEqual(1, clampScale(2), "values above one should clamp")
end)

run("bag-only uses width and bag-height constraints", function()
    local bagScale, bankScale = computeFrameScales(
        1920, 1080, 100,
        true, 1000, 800,
        false, 0, 0
    )
    assertEqual(1, bagScale, "bag scale should fit at full scale for this geometry")
    assertEqual(1, bankScale, "hidden bank uses neutral scale")
end)

run("bank-only uses width and bank-height constraints", function()
    local bagScale, bankScale = computeFrameScales(
        1920, 1080, 100,
        false, 0, 0,
        true, 900, 700
    )
    assertEqual(1, bagScale, "hidden bag uses neutral scale")
    assertEqual(1, bankScale, "bank scale should fit at full scale for this geometry")
end)

run("both visible uses shared width but per-frame height constraints", function()
    local bagScale, bankScale = computeFrameScales(
        1920, 1080, 100,
        true, 1200, 900,
        true, 1000, 800
    )
    assertTrue(bagScale >= 0.05 and bagScale <= 1, "bag scale should stay within configured bounds")
    assertTrue(bankScale >= 0.05 and bankScale <= 1, "bank scale should stay within configured bounds")
    assertEqual(0.81, math.floor(bagScale * 100 + 0.5) / 100, "bag scale should be width-limited")
    assertEqual(0.81, math.floor(bankScale * 100 + 0.5) / 100, "bank scale should be width-limited")
end)

run("extreme combined width clamps both frames to minimum", function()
    local bagScale, bankScale = computeFrameScales(
        1920, 1080, 100,
        true, 50000, 900,
        true, 40000, 900
    )
    assertEqual(0.05, bagScale, "bag scale should clamp to minimum")
    assertEqual(0.05, bankScale, "bank scale should clamp to minimum")
end)

run("ComputeWidthScale uses combined visible widths only", function()
    local scale = computeWidthScale(
        1920,
        100,
        true,
        1000,
        true,
        1000
    )
    assertEqual(0.89, math.floor(scale * 100 + 0.5) / 100, "width scale should use combined visible width budget")
end)

run("ComputeWidthScaleFromRemaining reclaims width from height-limited other frame", function()
    local scale = computeWidthScaleFromRemaining(
        1772,
        true,
        1000,
        true,
        1000,
        0.34
    )
    assertEqual(1.43, math.floor(scale * 100 + 0.5) / 100, "remaining-width scale should increase when other frame occupies less width")
end)

run("ComputeHeightScale returns neutral 1 for hidden and ratio for visible", function()
    assertEqual(1, computeHeightScale(false, 100, 1000), "hidden frame should be neutral")
    assertEqual(0.5, computeHeightScale(true, 500, 1000), "visible frame should use ratio")
end)

run("height-limited bank allows bags to reclaim width in second pass", function()
    local bagScale, bankScale = computeFrameScales(
        1920, 1080, 100,
        true, 1000, 900,
        true, 1000, 3000
    )
    assertEqual(1, bagScale, "bag should reclaim width to full scale")
    assertEqual(0.34, math.floor(bankScale * 100 + 0.5) / 100, "bank remains height-limited")
end)

run("GetFrameScale keeps locked bag scale while search anchor lock is active", function()
    local originalShown = ContainerFrameCombinedBags.IsShown
    local originalWidth = ContainerFrameCombinedBags.GetWidth
    local originalHeight = ContainerFrameCombinedBags.GetHeight
    local originalIsSearchAnchorLockActive = ContainerFrameCombinedBags.IsSearchAnchorLockActive
    local originalGetSearchAnchorLockedScale = ContainerFrameCombinedBags.GetSearchAnchorLockedScale

    ContainerFrameCombinedBags.IsShown = function()
        return true
    end
    ContainerFrameCombinedBags.GetWidth = function()
        return 50000
    end
    ContainerFrameCombinedBags.GetHeight = function()
        return 900
    end
    ContainerFrameCombinedBags.IsSearchAnchorLockActive = function()
        return true
    end
    ContainerFrameCombinedBags.GetSearchAnchorLockedScale = function()
        return 0.77
    end

    assertEqual(0.77, getFrameScale(ContainerFrameCombinedBags), "locked bag scale should override recomputed scale")

    ContainerFrameCombinedBags.IsShown = originalShown
    ContainerFrameCombinedBags.GetWidth = originalWidth
    ContainerFrameCombinedBags.GetHeight = originalHeight
    ContainerFrameCombinedBags.IsSearchAnchorLockActive = originalIsSearchAnchorLockActive
    ContainerFrameCombinedBags.GetSearchAnchorLockedScale = originalGetSearchAnchorLockedScale
end)

run("maximum scale caps growth while keeping automatic shrink", function()
    addonEnv.ScaleSettings:SetMaximumScale(0.75)
    local bagScale, bankScale = computeFrameScales(1920, 1080, 100,
        true, 1000, 800, true, 800, 700)
    assertEqual(0.75, bagScale, "bags cannot grow beyond selected maximum")
    assertEqual(0.75, bankScale, "banks share selected maximum")
    bagScale, bankScale = computeFrameScales(1920, 1080, 100,
        true, 1000, 2000, true, 800, 700)
    assertEqual(0.5, bagScale, "screen-fit constraint can shrink bags below maximum")
    assertEqual(0.75, bankScale, "bank still respects maximum")
    addonEnv.ScaleSettings:SetMaximumScale(1)
end)

run("maximum scale also caps captured search scale", function()
    addonEnv.ScaleSettings:SetMaximumScale(0.65)
    ContainerFrameCombinedBags.IsSearchAnchorLockActive = function() return true end
    ContainerFrameCombinedBags.GetSearchAnchorLockedScale = function() return 0.9 end
    assertEqual(0.65, getFrameScale(ContainerFrameCombinedBags))
    ContainerFrameCombinedBags.GetSearchAnchorLockedScale = function() return 0.5 end
    assertEqual(0.5, getFrameScale(ContainerFrameCombinedBags), "smaller locked scale stays stable")
    ContainerFrameCombinedBags.IsSearchAnchorLockActive = nil
    ContainerFrameCombinedBags.GetSearchAnchorLockedScale = nil
    addonEnv.ScaleSettings:SetMaximumScale(1)
end)

run("options slider updates the actual bag and bank frame scales", function()
    local registeredSettings, slider = {}, nil
    local addonCategory, initializeMenuRow
    Settings = {
        VarType = { String = "string", Boolean = "boolean", Number = "number" },
        RegisterVerticalLayoutCategory = function(name)
            addonCategory = { GetName = function() return name end, SetShouldSortAlphabetically = function() end }
            return addonCategory
        end,
        RegisterProxySetting = function(_, variable, kind, name, default, getter, setter)
            local setting = { kind = kind, name = name, default = default, getter = getter, setter = setter }
            registeredSettings[variable] = setting
            return setting
        end,
        CreateDropdown = function() end,
        CreateCheckbox = function() end,
        CreateSliderOptions = function(minimum, maximum, step)
            return { minimum = minimum, maximum = maximum, step = step,
                SetLabelFormatter = function(self, _, formatter) self.formatter = formatter end }
        end,
        CreateSlider = function(_, setting, options) slider = { setting = setting, options = options } end,
        RegisterAddOnCategory = function() end,
    }
    MinimalSliderWithSteppersMixin = { Label = { Right = "right" } }
    C_AddOns = { IsAddOnLoaded = function() return true end }
    assert(loadfile("tooltipSettings.lua"))("MyBags", addonEnv)
    assert(loadfile("newItemsSettings.lua"))("MyBags", addonEnv)
    SettingsPanel = { CategoryList = { ScrollBox = {} } }
    ScrollUtil = {
        AddInitializedFrameCallback = function(scrollBox, callback, owner)
            assert(scrollBox == SettingsPanel.CategoryList.ScrollBox)
            initializeMenuRow = function(button, initializer) callback(owner, button, initializer) end
        end,
    }
    assert(loadfile("addonSettings.lua"))("MyBags", addonEnv)
    local categories = {
        { GetName = function() return "Zebra" end },
        addonCategory,
        { GetName = function() return "Alpha" end },
    }
    table.sort(categories, function(a, b) return a:GetName() < b:GetName() end)
    assertEqual(addonCategory, categories[2], "plain category name keeps alphabetical position")
    local label = { SetText = function(self, text) self.text = text end }
    local row = { Label = label }
    initializeMenuRow(row, { data = { category = addonCategory } })
    assertEqual("|cffff2459My|r|cffffffffBags|r", label.text, "menu label retains addon colours")
    label:SetText("Zebra")
    initializeMenuRow(row, { data = { category = categories[3] } })
    assertEqual("Zebra", label.text, "reused menu row leaves other addon names unchanged")
    label:SetText("AddOns")
    initializeMenuRow(row, { data = { label = "AddOns" } })
    assertEqual("AddOns", label.text, "section headers remain unchanged")

    assertEqual("number", slider.setting.kind)
    assertEqual(100, slider.setting.default)
    assertEqual(5, slider.options.minimum)
    assertEqual(100, slider.options.maximum)
    assertEqual("75%", slider.options.formatter(75))
    slider.setting.setter(75)
    assertEqual(75, slider.setting.getter(), "setting uses percentages")
    assertEqual(0.75, ContainerFrameCombinedBags:GetScale(), "open bags update through real override")
    assertEqual(0.75, BankFrame:GetScale(), "bank update uses the same cap")
    slider.setting.setter(100)
    assertEqual(1, ContainerFrameCombinedBags:GetScale(), "reset restores default scale")
end)
