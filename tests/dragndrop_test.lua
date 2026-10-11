local collapsedCalls = 0
local selectedCategoryId = nil
local categoriesConfigMode = false
local configModeClickCalls = 0
local shiftDown = false
local cursorInfoType = nil
local cursorItemId = nil
local currentTime = 1
local cursorX = 0
local cursorY = 0
local lastEvent = nil
local clearCursorCalls = 0
local pickupCalls = 0
local emptyButtonClickCalls = 0
local lastEmptyButtonClicked = nil

_G.C_Container = {
    GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        if bagID == 0 and slotID == 2 then
            return { itemID = 3003 }
        end
        if bagID == Enum.BagIndex.CharacterBankTab_1 and slotID == 1 then
            return { itemID = 2002 }
        end
        return nil
    end,
    PickupContainerItem = function(bagID, slotID)
        pickupCalls = pickupCalls + 1
    end,
}
_G.hooksecurefunc = function() end
_G.GetTime = function() return currentTime end
_G.GetCursorInfo = function() return cursorInfoType, cursorItemId, nil end
_G.IsShiftKeyDown = function() return shiftDown end
_G.RunNextFrame = function(fn) fn() end
_G.GetCursorPosition = function() return cursorX, cursorY end
_G.GetMouseFoci = function()
    return {}
end
_G.ClearCursor = function()
    clearCursorCalls = clearCursorCalls + 1
end
_G.ContainerFrameItemButton_OnClick = function(button, mouseButton)
    emptyButtonClickCalls = emptyButtonClickCalls + 1
    lastEmptyButtonClicked = button
end
_G.Enum = {
    BagIndex = {
        CharacterBankTab_1 = 100,
        CharacterBankTab_6 = 105,
        AccountBankTab_1 = 106,
        AccountBankTab_5 = 110,
    },
}

local addonEnv = {
    container = {
        EnumerateValidItems = function()
            return function()
                return nil
            end
        end,
    },
    CategoryStore = {
        GetColumnCount = function()
            return 3
        end,
    },
    Collapsed = {
        toggleCollapsed = function()
            collapsedCalls = collapsedCalls + 1
        end,
    },
    BagViewState = {
        IsCategoriesConfigMode = function()
            return categoriesConfigMode
        end,
    },
    CategoriesGUI = {
        SelectCategoryById = function(_, categoryId)
            selectedCategoryId = categoryId
        end,
    },
    Categories = {
        GetLastCategoryInColumn = function(_, _, scope)
            return {
                GetId = function()
                    return "target-" .. tostring(scope)
                end,
                IsProtected = function()
                    return false
                end,
            }
        end,
    },
    TriggerContainerOnTokenWatchChanged = function() end,
    printDebug = function() end,
    Const = {
        Events = {
            ITEM_MOVED = "ITEM_MOVED",
            CATEGORY_MOVED = "CATEGORY_MOVED",
            CATEGORY_MOVED_TO_COLUMN = "CATEGORY_MOVED_TO_COLUMN",
        },
    },
    Events = {
        TriggerCustomEvent = function(_, eventName, ...)
            lastEvent = {
                name = eventName,
                args = { ... },
            }
        end,
    },
    QueueContainerUpdateItemLayout = function() end,
}

assert(loadfile("categoryBackground.lua"))("MyBags", addonEnv)

local dragAndDropChunk = assert(loadfile("dragndrop.lua"))
dragAndDropChunk("MyBags", addonEnv)

local function assertTrue(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

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

local function category(id, opts)
    local value = {
        GetId = function()
            return id
        end,
        IsProtected = function()
            return false
        end,
        OnLeftClickConfigMode = function()
            if opts and opts.configModeHandler then
                configModeClickCalls = configModeClickCalls + 1
                selectedCategoryId = id
            end
        end,
    }
    return value
end

local function resetDragTestState()
    shiftDown = false
    cursorInfoType = nil
    cursorItemId = nil
    currentTime = currentTime + 1
    lastEvent = nil
    clearCursorCalls = 0
    pickupCalls = 0
    emptyButtonClickCalls = 0
    lastEmptyButtonClicked = nil
    addonEnv.emptyItemButton = nil
    _G.BankPanel = nil
end

local function hintCategory(id, isProtected)
    return {
        GetId = function()
            return id
        end,
        GetName = function()
            return id
        end,
        IsProtected = function()
            return isProtected == true
        end,
    }
end

local function frameForColumn(columnIndex)
    local width = 300
    local sectionWidth = width / 3
    cursorX = (columnIndex - 1) * sectionWidth + sectionWidth / 2
    cursorY = 50
    return {
        MyBagsResolveDropColumn = function(relativeX, scope, width)
            return addonEnv.CategoryBackground:ResolveBagColumn(relativeX, scope, width)
        end,
        GetEffectiveScale = function()
            return 1
        end,
        GetLeft = function()
            return 0
        end,
        GetBottom = function()
            return 0
        end,
        GetWidth = function()
            return width
        end,
        GetHeight = function()
            return 100
        end,
    }
end

run("category mouse-up during category drag moves instead of collapsing", function()
    resetDragTestState()
    local source, target = category("cus-source"), category("cus-target")
    addonEnv.DragAndDrop.categoryStartDrag({ ItemCategory = source, MyBagsScope = "bag" })
    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = target, MyBagsScope = "bag" }, "LeftButton")
    assertEqual(lastEvent.name, "CATEGORY_MOVED", "category drag should move to hovered category")
    assertEqual(lastEvent.args[2], "cus-target")
    assertEqual(collapsedCalls, 0, "dropping a category must not collapse target")
end)

run("shared item hook registration delivers category drops once", function()
    resetDragTestState()
    local UI = assert(loadfile("tests/helpers/ui.lua"))()
    local frame = UI.CreateFrame()
    frame.ItemCategory, frame.MyBagsScope = category("cus-target"), "bag"
    assertTrue(addonEnv.DragAndDrop:HookItemButton(frame), "first registration installs item hooks")
    assertEqual(addonEnv.DragAndDrop:HookItemButton(frame), false, "repeated registration reuses hooks")
    assertEqual(#frame.hooks.OnReceiveDrag, 1, "one drop must have one handler")
    addonEnv.DragAndDrop.categoryStartDrag({ ItemCategory = category("cus-source"), MyBagsScope = "bag" })
    frame:Fire("OnReceiveDrag")
    assertEqual(lastEvent.name, "CATEGORY_MOVED")
    assertEqual(lastEvent.args[2], "cus-target", "item surface retains category drop behavior")
end)

run("config mode custom category click collapses and does not select", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    configModeClickCalls = 0
    categoriesConfigMode = true

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("cus-11", { configModeHandler = true }) }, "LeftButton")

    assertTrue(collapsedCalls == 1, "collapse should be triggered in config mode")
    assertTrue(configModeClickCalls == 0, "config mode hook should not be called")
    assertTrue(selectedCategoryId == nil, "config mode click should not select in config GUI")
end)

run("config mode non-custom category click collapses", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    configModeClickCalls = 0
    categoriesConfigMode = true

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("unassigned") }, "LeftButton")

    assertTrue(collapsedCalls == 1, "non-custom category should collapse in config mode")
    assertTrue(configModeClickCalls == 0, "category without config mode hook should do nothing")
    assertTrue(selectedCategoryId == nil, "config mode click should not select in config GUI")
end)

run("normal mode category click still toggles collapse", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    configModeClickCalls = 0
    categoriesConfigMode = false

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("cus-11", { configModeHandler = true }) }, "LeftButton")

    assertTrue(collapsedCalls == 1, "collapse should be triggered in normal mode")
    assertTrue(configModeClickCalls == 0, "normal mode should not call config mode hook")
    assertTrue(selectedCategoryId == nil, "normal mode click should not select in config GUI")
end)

run("category drop emits CATEGORY_MOVED with moveTail when shift is held", function()
    resetDragTestState()
    shiftDown = true
    addonEnv.DragAndDrop.categoryStartDrag({ ItemCategory = category("cus-11") })
    addonEnv.DragAndDrop.categoryOnReceiveDrag({ ItemCategory = category("cus-22") })

    assertTrue(lastEvent ~= nil, "event should be emitted")
    assertEqual(lastEvent.name, "CATEGORY_MOVED", "should emit category moved event")
    assertEqual(lastEvent.args[1], "cus-11", "picked category id")
    assertEqual(lastEvent.args[2], "cus-22", "target category id")
    assertEqual(lastEvent.args[3], true, "moveTail should be true when shift is held")
end)

run("category drop emits CATEGORY_MOVED with moveTail false when shift is not held", function()
    resetDragTestState()
    shiftDown = false
    addonEnv.DragAndDrop.categoryStartDrag({ ItemCategory = category("cus-11") })
    addonEnv.DragAndDrop.categoryOnReceiveDrag({ ItemCategory = category("cus-22") })

    assertTrue(lastEvent ~= nil, "event should be emitted")
    assertEqual(lastEvent.name, "CATEGORY_MOVED", "should emit category moved event")
    assertEqual(lastEvent.args[3], false, "moveTail should be false when shift is not held")
end)

run("background drop emits CATEGORY_MOVED_TO_COLUMN with moveTail when shift is held", function()
    resetDragTestState()
    shiftDown = true
    addonEnv.DragAndDrop.categoryStartDrag({ ItemCategory = category("cus-11") })
    addonEnv.DragAndDrop.backgroundOnReceiveDrag(frameForColumn(2))

    assertTrue(lastEvent ~= nil, "event should be emitted")
    assertEqual(lastEvent.name, "CATEGORY_MOVED_TO_COLUMN", "should emit category moved to column event")
    assertEqual(lastEvent.args[1], "cus-11", "picked category id")
    assertEqual(lastEvent.args[2], 2, "target column index")
    assertEqual(lastEvent.args[3], true, "moveTail should be true when shift is held")
end)

run("background drop emits CATEGORY_MOVED_TO_COLUMN with moveTail false when shift is not held", function()
    resetDragTestState()
    shiftDown = false
    addonEnv.DragAndDrop.categoryStartDrag({ ItemCategory = category("cus-11") })
    addonEnv.DragAndDrop.backgroundOnReceiveDrag(frameForColumn(2))

    assertTrue(lastEvent ~= nil, "event should be emitted")
    assertEqual(lastEvent.name, "CATEGORY_MOVED_TO_COLUMN", "should emit category moved to column event")
    assertEqual(lastEvent.args[3], false, "moveTail should be false when shift is not held")
end)

run("background right-click does not trigger category move during drag", function()
    resetDragTestState()
    addonEnv.DragAndDrop.categoryStartDrag({ ItemCategory = category("cus-11") })
    addonEnv.DragAndDrop.backgroundOnReceiveDrag(frameForColumn(2), "RightButton")

    assertTrue(lastEvent == nil, "right-click should not emit category move event")
end)

run("GetCategoryDropHint returns nil when no drag item is active", function()
    resetDragTestState()
    cursorInfoType = nil
    local hint = addonEnv.DragAndDrop:GetCategoryDropHint(hintCategory("cus-1", false), false)
    assertTrue(hint == nil, "hint should be hidden without item drag")
end)

run("GetCategoryDropHint hides unassigned when not hovered", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001
    local hint = addonEnv.DragAndDrop:GetCategoryDropHint(hintCategory("unassigned", false), false)
    assertTrue(hint == nil, "unassigned should be hidden when not hovered")
end)

run("GetCategoryDropHint returns unassigned hint when hovered", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001
    local hint = addonEnv.DragAndDrop:GetCategoryDropHint(hintCategory("unassigned", false), true)
    assertTrue(hint ~= nil, "hint should be shown for hovered unassigned")
    assertEqual(hint.tone, "unassigned", "tone should describe unassigned action")
end)

run("GetCategoryDropHint returns blocked tone when hovered protected", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1002
    local hint = addonEnv.DragAndDrop:GetCategoryDropHint(hintCategory("eq-5", true), true)
    assertTrue(hint ~= nil, "hint should be shown")
    assertEqual(hint.tone, "blocked", "protected category should be blocked")
end)

run("GetCategoryDropHint returns assign tone when hovered assignable", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1003
    local hint = addonEnv.DragAndDrop:GetCategoryDropHint(hintCategory("cus-2", false), true)
    assertTrue(hint ~= nil, "hint should be shown")
    assertEqual(hint.tone, "assign", "assignable hovered category should be assign tone")
    assertEqual(hint.text, "|cff57c67aAssign|r to cus-2", "assign tone should include target category name")
end)

run("GetCategoryDropHint hides protected category when not hovered", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1004
    local hint = addonEnv.DragAndDrop:GetCategoryDropHint(hintCategory("eq-8", true), false)
    assertTrue(hint == nil, "non-hovered protected category should stay neutral")
end)

run("GetCategoryDropHint treats merchant cursor as active item drag", function()
    resetDragTestState()
    cursorInfoType = "merchant"
    cursorItemId = 2
    local hint = addonEnv.DragAndDrop:GetCategoryDropHint(hintCategory("cus-3", false), true)
    assertTrue(hint ~= nil, "merchant item drag should show hint")
    assertEqual(hint.tone, "assign", "merchant drag over assignable category should assign")
end)

run("itemStopDrag clears cursor for same-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    _G.GetMouseFoci = function()
        return {
            {
                myBagAddonHooked = true,
                GetBagID = function()
                    return 0
                end,
                GetID = function()
                    return 2
                end,
            },
        }
    end

    local bagButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }

    addonEnv.DragAndDrop.itemStartDrag(bagButton)
    addonEnv.DragAndDrop.itemStopDrag(bagButton)

    assertEqual(clearCursorCalls, 1, "same-scope stop drag should clear cursor")
end)

run("itemStopDrag does not clear cursor for cross-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    _G.GetMouseFoci = function()
        return {
            {
                myBagAddonHooked = true,
                GetBagID = function()
                    return Enum.BagIndex.CharacterBankTab_1
                end,
                GetID = function()
                    return 1
                end,
            },
        }
    end

    local bagButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }

    addonEnv.DragAndDrop.itemStartDrag(bagButton)
    addonEnv.DragAndDrop.itemStopDrag(bagButton)

    assertEqual(clearCursorCalls, 0, "cross-scope stop drag should keep cursor")
end)

run("itemOnReceiveDrag replays pickup for same-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    local sourceButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }
    local targetButton = {
        ItemCategory = category("cus-22"),
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 2
        end,
    }

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        if bagID == 0 and slotID == 2 then
            return { itemID = 3003 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(sourceButton)
    addonEnv.DragAndDrop.itemOnReceiveDrag(targetButton)

    assertEqual(pickupCalls, 1, "same-scope receive drag should replay pickup")
end)

run("itemOnReceiveDrag does not replay pickup for cross-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    local sourceButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }
    local targetButton = {
        ItemCategory = category("cus-22"),
        GetBagID = function()
            return Enum.BagIndex.CharacterBankTab_1
        end,
        GetID = function()
            return 1
        end,
    }

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        if bagID == Enum.BagIndex.CharacterBankTab_1 and slotID == 1 then
            return { itemID = 3003 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(sourceButton)
    addonEnv.DragAndDrop.itemOnReceiveDrag(targetButton)

    assertEqual(pickupCalls, 0, "cross-scope receive drag should not replay pickup")
end)

run("itemOnClick does not apply fast-path for cross-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    local sourceButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }
    local targetButton = {
        ItemCategory = category("cus-22"),
        GetBagID = function()
            return Enum.BagIndex.CharacterBankTab_1
        end,
        GetID = function()
            return 1
        end,
    }

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        if bagID == Enum.BagIndex.CharacterBankTab_1 and slotID == 1 then
            return { itemID = 3003 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(sourceButton)
    addonEnv.DragAndDrop.itemOnClick(targetButton, "LeftButton")

    assertEqual(clearCursorCalls, 0, "cross-scope click should not clear cursor")
    assertEqual(pickupCalls, 0, "cross-scope click should not replay pickup")
end)

run("itemStopDrag uses parent scoped frame to detect cross-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    _G.GetMouseFoci = function()
        local parentScopeFrame = {
            MyBagsScope = "bank-character",
            GetParent = function()
                return nil
            end,
        }
        return {
            {
                myBagAddonHooked = true,
                GetBagID = function()
                    return nil
                end,
                GetID = function()
                    return nil
                end,
                GetParent = function()
                    return parentScopeFrame
                end,
            },
        }
    end

    local bagButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(bagButton)
    addonEnv.DragAndDrop.itemStopDrag(bagButton)

    assertEqual(clearCursorCalls, 0, "parent-scoped cross-scope hover should not clear cursor")
end)

run("categoryOnReceiveDrag places item into available empty slot for cross-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    local sourceButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }
    local targetEmptyButton = { id = "bank-empty" }
    addonEnv.emptyItemButton = targetEmptyButton

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(sourceButton)
    addonEnv.DragAndDrop.categoryOnReceiveDrag({
        ItemCategory = category("cus-22"),
        MyBagsScope = "bank-character",
    })

    assertEqual(emptyButtonClickCalls, 1, "cross-scope category drop should use available empty slot")
    assertTrue(lastEmptyButtonClicked == targetEmptyButton, "should click available empty button")
end)

run("backgroundOnReceiveDrag places item into available empty slot for cross-scope transfer", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001
    cursorX = 50
    cursorY = 50

    local sourceButton = {
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }
    local targetEmptyButton = { id = "bank-empty-2" }
    addonEnv.emptyItemButton = targetEmptyButton

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(sourceButton)
    addonEnv.DragAndDrop.backgroundOnReceiveDrag({
        MyBagsResolveDropColumn = function(relativeX, scope, width)
            return math.floor(relativeX * 3 / width) + 1
        end,
        MyBagsScope = "bank-character",
        GetEffectiveScale = function()
            return 1
        end,
        GetLeft = function()
            return 0
        end,
        GetBottom = function()
            return 0
        end,
        GetWidth = function()
            return 300
        end,
        GetHeight = function()
            return 100
        end,
    }, "LeftButton")

    assertEqual(emptyButtonClickCalls, 1, "cross-scope background drop should use available empty slot")
    assertTrue(lastEmptyButtonClicked == targetEmptyButton, "should click available empty button")
end)

run("categoryOnReceiveDrag emits non-item-target move anchor", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001

    local sourceButton = {
        ItemCategory = category("cus-11"),
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }
    local targetItemA = {
        ItemCategory = category("cus-22"),
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 2
        end,
    }
    local targetItemB = {
        ItemCategory = category("cus-22"),
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 3
        end,
    }
    addonEnv.container = {
        EnumerateValidItems = function()
            return ipairs({ sourceButton, targetItemA, targetItemB })
        end,
    }

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        if bagID == 0 and slotID == 2 then
            return { itemID = 3003 }
        end
        if bagID == 0 and slotID == 3 then
            return { itemID = 4004 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(sourceButton)
    addonEnv.DragAndDrop.categoryOnReceiveDrag({
        ItemCategory = category("cus-22"),
        MyBagsScope = "bag",
    })

    assertEqual(lastEvent.name, "ITEM_MOVED", "category assignment should emit item move")
    assertEqual(lastEvent.args[2], nil, "category assignment should not target a hovered item")
end)

run("backgroundOnReceiveDrag emits non-item-target move anchor", function()
    resetDragTestState()
    cursorInfoType = "item"
    cursorItemId = 1001
    cursorX = 50
    cursorY = 50

    local sourceButton = {
        ItemCategory = category("cus-11"),
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 1
        end,
    }
    local targetItemA = {
        ItemCategory = category("target-bag"),
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 2
        end,
    }
    local targetItemB = {
        ItemCategory = category("target-bag"),
        GetBagID = function()
            return 0
        end,
        GetID = function()
            return 3
        end,
    }
    addonEnv.container = {
        EnumerateValidItems = function()
            return ipairs({ sourceButton, targetItemA, targetItemB })
        end,
    }

    _G.C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return { itemID = 1001 }
        end
        if bagID == 0 and slotID == 2 then
            return { itemID = 3003 }
        end
        if bagID == 0 and slotID == 3 then
            return { itemID = 5005 }
        end
        return nil
    end

    addonEnv.DragAndDrop.itemStartDrag(sourceButton)
    addonEnv.DragAndDrop.backgroundOnReceiveDrag(frameForColumn(1), "LeftButton")

    assertEqual(lastEvent.name, "ITEM_MOVED", "background assignment should emit item move")
    assertEqual(lastEvent.args[2], nil, "background assignment should not target a hovered item")
end)
