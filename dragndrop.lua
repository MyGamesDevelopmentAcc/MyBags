local addonName, AddonNS = ...

AddonNS.DragAndDrop = {};


local rows = 0;
local height = 0;
local pickedItemID = nil;
local pickedItemCategory = nil;
local pickedItemButton = nil;
local container = AddonNS.container;




--[[
item -> item
- assign new category to item
- refresh gear (buttons) ItemCategories
- change button order

item -> category
- assign new category to item

category -> item
- change category order

category -> category
- change category order

]]
function AddonNS.DragAndDrop.itemOnClick(self, button)
    AddonNS.printDebug("itemOnClick")
    if button == "LeftButton" then
        local infoType, itemID, itemLink = GetCursorInfo()
        AddonNS.printDebug(pickedItemButton, infoType, itemID, itemLink)
        if (pickedItemButton and infoType) then
            AddonNS.DragAndDrop.itemOnReceiveDrag(self)
            AddonNS.DragAndDrop.cleanUp()
        else
            AddonNS.DragAndDrop.itemStartDrag(self);
        end
    end
end

function AddonNS.DragAndDrop.itemStartDrag(self)
    AddonNS.DragAndDrop.cleanUp()
    AddonNS.printDebug("itemStartDrag")
    local info = C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID());
    if (info) then
        -- if (CursorHasItem()) then
        pickedItemButton = self;
        pickedItemID = info.itemID
        pickedItemCategory = self.ItemCategory;
        -- end
    end
end

function AddonNS.DragAndDrop.itemOnReceiveDrag(self)
    AddonNS.printDebug("itemOnReceiveDrag")
    if not self.ItemCategory then AddonNS.printDebug("no item category error") end -- todo: this check seem redudant?

    local targetItemCategory = self.ItemCategory;

    AddonNS.printDebug("1")
    if (pickedItemButton) then                             
        local infoType, itemID, itemLink = GetCursorInfo()
        AddonNS.printDebug("2", infoType, itemID, pickedItemID)
        if infoType == "item" and itemID == pickedItemID then
            AddonNS.printDebug("3")
            local info = C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID());
            local targetedItemID = info and info.itemID or nil;
            AddonNS.Events:TriggerCustomEvent(AddonNS.Events.ITEM_MOVED, pickedItemID, targetedItemID,
                pickedItemCategory, targetItemCategory, pickedItemButton, self);
        end
    elseif pickedItemCategory then -- category frame
        AddonNS.Events:TriggerCustomEvent(AddonNS.Events.CATEGORY_MOVED,
            pickedItemCategory, targetItemCategory);
        RunNextFrame(function()
            container:UpdateItemLayout();
        end);
    end
    AddonNS.DragAndDrop.cleanUp()
end

function AddonNS.DragAndDrop.categoryOnMouseUp(self, button)
    AddonNS.printDebug("categoryOnMouseUp")
    if button == "LeftButton" then
        AddonNS.DragAndDrop.categoryOnReceiveDrag(self)
    end
end

function AddonNS.DragAndDrop.categoryStartDrag(self)
    AddonNS.DragAndDrop.cleanUp()
    AddonNS.printDebug("categoryStartDrag")
    pickedItemCategory = self.ItemCategory;

    AddonNS.printDebug("categoryStartDrag", pickedItemCategory)
end

function AddonNS.DragAndDrop.cleanUp()
    AddonNS.printDebug("cleanUp")
    pickedItemButton = nil;
    pickedItemID = nil
    pickedItemCategory = nil;
end

function AddonNS.DragAndDrop.categoryOnReceiveDrag(self)
    AddonNS.printDebug("categoryOnReceiveDrag")

    local targetItemCategory = self.ItemCategory;

    AddonNS.printDebug("categoryOnReceiveDrag", pickedItemCategory, targetItemCategory)

    if (pickedItemButton) then -- button
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" and itemID == pickedItemID then
            AddonNS.CustomCategories:AssignToCategory(self.ItemCategory, itemID)
            ClearCursor();
            RunNextFrame(function()
                container:UpdateItemLayout();
            end);
        end
    elseif pickedItemCategory and (pickedItemCategory ~= targetItemCategor) then -- category frame

        AddonNS.printDebug("sending CATEGORY_MOVED", AddonNS.Events.CATEGORY_MOVED)
        AddonNS.Events:TriggerCustomEvent(AddonNS.Events.CATEGORY_MOVED,
            pickedItemCategory, targetItemCategory);
        RunNextFrame(function() -- todo: maybe these actually should be triggered at the point where action is processed... hmm
            container:OnTokenWatchChanged();
            -- container:UpdateContainerFrameAnchors();
        end);
    end

    AddonNS.DragAndDrop.cleanUp()
end

local function GetMouseSectionRelativeToFrame(frame)
    -- Get the cursor position in screen coordinates
    local cursorX, cursorY = GetCursorPosition()

    -- Get the frame's scale (useful if the frame or UI is scaled)
    local scale = frame:GetEffectiveScale()

    -- Convert cursor coordinates to UI scale
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    -- Get frame position and dimensions
    local frameLeft = frame:GetLeft()
    local frameBottom = frame:GetBottom()
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()

    -- Calculate the relative position within the frame
    local relativeX = cursorX - frameLeft
    local relativeY = cursorY - frameBottom

    -- Ensure the coordinates are within the frame boundaries
    if relativeX < 0 or relativeX > frameWidth or relativeY < 0 or relativeY > frameHeight then
        return nil -- Cursor is outside the frame
    end

    -- Determine which section (column) the mouse is in
    local sectionWidth = frameWidth / 3
    local section

    if relativeX <= sectionWidth then
        section = 1
    elseif relativeX <= sectionWidth * 2 then
        section = 2
    else
        section = 3
    end

    return section
end



function AddonNS.DragAndDrop.backgroundOnReceiveDrag(self)
    AddonNS.printDebug("backgroundOnReceiveDrag")
    local column = GetMouseSectionRelativeToFrame(self)
    AddonNS.printDebug(column)
    if (column) then
        AddonNS.printDebug("categoryOnReceiveDrag", pickedItemCategory)

        if not pickedItemButton and pickedItemCategory then -- category frame
            AddonNS.printDebug("sending CATEGORY_MOVED_TO_COLUMN", AddonNS.Events.CATEGORY_MOVED)
            AddonNS.Events:TriggerCustomEvent(AddonNS.Events.CATEGORY_MOVED_TO_COLUMN,
                pickedItemCategory, column);
            -- ClearCursor();
            RunNextFrame(function()
                container:OnTokenWatchChanged();
            end);
        end
        AddonNS.DragAndDrop.cleanUp()
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnMouseUp(targetItemCategoryName, button)
    AddonNS.printDebug("customCategoryGUIOnMouseUp", button)
    if button == "LeftButton" then
        AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetItemCategoryName)
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetItemCategoryName)
   

    AddonNS.printDebug("customCategoryGUIOnReceiveDrag", pickedItemCategory, targetItemCategoryName)

    if (pickedItemButton) then -- button
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" and itemID == pickedItemID then
            local cat = AddonNS.Categories:GetCategoryByName(targetItemCategoryName);
            if cat then 
            AddonNS.CustomCategories:AssignToCategory(cat, itemID)
            else 
                AddonNS.CustomCategories:AssignToCategoryByName(targetItemCategoryName, itemID)
            end
            ClearCursor();
            RunNextFrame(function()
                container:UpdateItemLayout();
            end);
        end
    end

    AddonNS.DragAndDrop.cleanUp()
end