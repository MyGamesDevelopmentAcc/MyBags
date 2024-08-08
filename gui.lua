local addonName, AddonNS = ...

local GS = LibStub("MyLibrary_GUI");
local test = {

    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },

}
local unselectedDarkBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    tile = true,
    tileSize = 32,
    edgeSize = 20,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }
}
local protectedCategoryBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    tile = true,
    tileSize = 32,
    edgeSize = 20,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }
}
local unprotectedCategoryBackdrop = {
    bgFile = "Interface\\Buttons\\UI-Listbox-Highlight",
    tile = false,
    tileSize = 32,
    edgeSize = 20,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }
}

AddonNS.gui = {}
AddonNS.gui.categoriesFrames = {};


--- draggable frame 
local draggableFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

draggableFrame:SetSize(160, AddonNS.CATEGORY_HEIGHT * 2)
draggableFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
draggableFrame:SetBackdropColor(0, 0, 1, .5)
draggableFrame:SetMovable(true)
draggableFrame:SetPoint("CENTER")
draggableFrame:Hide()
draggableFrame.textFrame = draggableFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
draggableFrame.textFrame:SetAllPoints();
draggableFrame.textFrame:SetWordWrap(false);
draggableFrame:SetFrameStrata("TOOLTIP")
function draggableFrame:SetText(text) draggableFrame.textFrame:SetText(text) end

function draggableFrame:StartDragging()
    self:SetScript("OnUpdate",
        function()
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end);
end

function draggableFrame:StopDragging()
    self:SetScript("OnUpdate", nil);
end

local backgroundFrame = nil;
backgroundFrame = CreateFrame("Frame", nil, AddonNS.container, "BackdropTemplate")     -- todo: does it need to be some frame with bg, or pure frame would sufficie? I think I was testing it and it didnt work for some reason.
backgroundFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
backgroundFrame:SetBackdropColor(0, 1, 0, 0)
backgroundFrame:EnableMouse(true)
backgroundFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.backgroundOnReceiveDrag)

backgroundFrame:SetPoint("BOTTOMRIGHT", AddonNS.container.MoneyFrame, "TOPRIGHT", 0, 0)


function AddonNS.gui:RegenerateCategories(yFrameOffset, categoriesGUIInfo)
    local moneyFrame = AddonNS.container.MoneyFrame;
    AddonNS.printDebug("money frame:", moneyFrame, AddonNS.container.MoneyFrame)
    backgroundFrame:SetPoint("TOPLEFT", moneyFrame, "TOPLEFT", 0, yFrameOffset)
    for i = 1, #categoriesGUIInfo, 1 do
        local categoryGUIInfo = categoriesGUIInfo[i];
        if not AddonNS.gui.categoriesFrames[i] then
            local f = CreateFrame("Frame", nil, backgroundFrame, "BackdropTemplate")


            f:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
            f:SetBackdropColor(1, 0, 0, 0)
            local fs = f:CreateFontString(nil, "ARTWORK", "GameFontNormal");
            fs:SetPoint("TOPLEFT", f, "TOPLEFT", AddonNS.ITEM_SPACING / 2, -AddonNS.ITEM_SPACING / 2)
            fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -AddonNS.ITEM_SPACING / 2, -AddonNS.ITEM_SPACING / 2)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetWordWrap(false);

            f.bg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
            f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -AddonNS.CATEGORY_HEIGHT + AddonNS.COLUMN_SPACING / 2)
            f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, AddonNS.COLUMN_SPACING / 2)
            f.bg:Hide();
            AddonNS.gui.categoriesFrames[i] = f;
            function f:SetText(text) fs:SetText(text) end

            f:EnableMouse(true)
            f:SetScript("OnEnter",
                function(self)
                    -- local infoType, itemID, itemLink = GetCursorInfo()
                    -- if infoType == "item" then
                    --     if self.ItemCategory.protected then
                    --         self:SetBackdrop(protectedCategoryBackdrop)
                    --     else
                    --         self:SetBackdrop(unprotectedCategoryBackdrop)
                    --     end
                    -- end
                    -- self:SetBackdropColor(0, 0, 0, .5)
                    GameTooltip:SetOwner(self);
                    --GameTooltip_SetTitle(GameTooltip, BAG_CLEANUP_BAGS, HIGHLIGHT_FONT_COLOR);
                    GameTooltip_AddNormalLine(GameTooltip, self.fs:GetText());
                    GameTooltip:Show();
                end)
            f:SetScript("OnLeave",
                function(self)
                    -- self:SetBackdrop(test)
                    -- self:SetBackdropColor(0, 0, 1, .5)
                    GameTooltip_Hide()
                end)

            f:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
            f:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)


            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", function(self, button)
                -- adjustDraggableFramePositionToMouse()
                draggableFrame:SetText(self.ItemCategory.name or "Unassigned");
                -- draggableFrame:SetWidth(self:GetWidth());
                draggableFrame:Show()
                draggableFrame:StartDragging()
                AddonNS.DragAndDrop.categoryStartDrag(self);
                AddonNS.printDebug("OnDragStart", button)
            end)
            f:SetScript("OnDragStop", function(self)
                draggableFrame:Hide()
                draggableFrame:StopDragging()
                AddonNS.printDebug("OnDragStop")
            end)
            f.fs = fs;
        end

        local f = AddonNS.gui.categoriesFrames[i];
        f.ItemCategory = categoryGUIInfo.category;
        f:SetPoint("TOPLEFT", backgroundFrame, "TOPLEFT", categoryGUIInfo.x, -categoryGUIInfo.y)
        -- if categoryGUIInfo.last then
        --     f:SetPoint("BOTTOM", relativeTo, "TOP", 0, 0)
        -- end
        -- AddonNS.printDebug(categories[i], pos[i].x, pos[i].y)
        f:SetWidth(categoryGUIInfo.width)
        -- fs.fs:SetWidth(categoryGUIInfo.width)
        f:SetHeight(categoryGUIInfo.height)
        f:SetText(categoryGUIInfo.category.name or "Unassigned");
        f:Show()
        -- f:Raise();
    end
    -- backgroundFrame:Lower();
    for i = #categoriesGUIInfo + 1, #AddonNS.gui.categoriesFrames, 1 do
        AddonNS.gui.categoriesFrames[i]:Hide();
    end
end
