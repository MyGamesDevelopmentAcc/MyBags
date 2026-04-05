local removedBag = nil
local removedSlot = nil
local triggeredEventName = nil
local triggeredEventCategorizer = nil

C_NewItems = {
  RemoveNewItem = function(bagID, slotIndex)
    removedBag = bagID
    removedSlot = slotIndex
  end,
  IsNewItem = function()
    return true
  end,
  ClearAll = function() end,
}

local registeredCategorizer = nil
local addonEnv = {
  NewItemsSettings = {
    IsEnabled = function()
      return true
    end,
  },
  Const = {
    Events = {
      CATEGORIZER_CATEGORIES_UPDATED = "CATEGORIZER_CATEGORIES_UPDATED",
    },
  },
  Categories = {
    RegisterCategorizer = function(_, _, categorizer)
      registeredCategorizer = categorizer
    end,
  },
  Events = {
    RegisterEvent = function() end,
    TriggerCustomEvent = function(_, eventName, categorizer)
      triggeredEventName = eventName
      triggeredEventCategorizer = categorizer
    end,
  },
  printDebug = function() end,
}

local chunk = assert(loadfile("Categorizers/new.lua"))
chunk("MyBags", addonEnv)

local list = registeredCategorizer:ListCategories()
assert(#list == 1, "new categorizer exposes one category")
local newCategory = list[1]
assert(newCategory ~= nil, "new category exists")

local fakeButton = {
  GetBagID = function() return 2 end,
  GetID = function() return 11 end,
}

local categorized = registeredCategorizer:Categorize(19019, fakeButton)
assert(categorized == newCategory, "Categorize returns new category when enabled and Blizzard marks item new")

addonEnv.NewItemsSettings.IsEnabled = function()
  return false
end
local disabledCategorized = registeredCategorizer:Categorize(19019, fakeButton)
assert(disabledCategorized == nil, "Categorize returns nil when new categorizer is disabled")

addonEnv.NewItemsSettings.IsEnabled = function()
  return true
end
newCategory:OnItemUnassigned(19019, {
  pickedItemButton = fakeButton,
})

assert(removedBag == 2, "OnItemUnassigned uses context button bag id")
assert(removedSlot == 11, "OnItemUnassigned uses context button slot index")

local refreshed = registeredCategorizer:OnRightClick()
assert(refreshed == true, "OnRightClick reports refresh required")
assert(triggeredEventName == addonEnv.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, "OnRightClick triggers categorizer updated event")
assert(triggeredEventCategorizer == registeredCategorizer, "OnRightClick passes New categorizer as event payload")
