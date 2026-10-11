local addonName, AddonNS = ...
local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;

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

AddonNS.gui = AddonNS.gui or {}
AddonNS.gui.categoriesFrames = {};
AddonNS.gui.categoryFrameByCategoryId = {}
local hoveredCategoryFrame = nil
local backgroundFrame = nil
local HINT_TONE_STYLE = {
    unassigned = { 0.35, 0.58, 0.94, 0.24 },
    assign = { 0.20, 0.85, 0.35, 0.30 },
    blocked = { 0.90, 0.24, 0.24, 0.30 },
}
local function applyCategoryHint(frame, hint)
    if not frame.hintOverlay then
        return
    end
    if not hint then
        frame.hintOverlay:Hide()
        return
    end
    local color = HINT_TONE_STYLE[hint.tone]
    frame.hintOverlay:SetBackdropColor(color[1], color[2], color[3], color[4])
    frame.hintOverlay:Show()
end

local hintTextFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
local HINT_TEXT_MIN_HEIGHT = 32
local HINT_TEXT_VERTICAL_GAP = 3
local HINT_TEXT_PADDING = 10
local HINT_TEXT_MAX_WIDTH_MARGIN = 24
hintTextFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
hintTextFrame:SetBackdropColor(0, 0, 0, 0.92)
hintTextFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
hintTextFrame:SetFrameStrata("TOOLTIP")
hintTextFrame:SetFrameLevel(300)
hintTextFrame:EnableMouse(false)
hintTextFrame:SetSize(320, 34)
hintTextFrame:Hide()

hintTextFrame.label = hintTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hintTextFrame.label:SetPoint("TOPLEFT", hintTextFrame, "TOPLEFT", HINT_TEXT_PADDING, -HINT_TEXT_PADDING)
hintTextFrame.label:SetPoint("BOTTOMRIGHT", hintTextFrame, "BOTTOMRIGHT", -HINT_TEXT_PADDING, HINT_TEXT_PADDING)
hintTextFrame.label:SetJustifyH("LEFT")
hintTextFrame.label:SetJustifyV("MIDDLE")
hintTextFrame.label:SetWordWrap(true)
hintTextFrame.label:SetTextColor(1, 1, 1, 1)

local function layoutHintTextFrame(anchorFrame, text)
    local uiScale = UIParent:GetEffectiveScale()
    local anchorScale = anchorFrame:GetEffectiveScale()
    hintTextFrame:SetScale(anchorScale / uiScale)

    local itemSize = AddonNS.container.Items[1]:GetHeight() + ITEM_SPACING
    local columnPixelWidth = itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
    local columnWidth = columnPixelWidth - AddonNS.Const.COLUMN_SPACING
    local offsetX = 0
    local hintWidth = columnWidth
    if not anchorFrame.MyBagsHintAlignToFrame then
        local anchorBackground = anchorFrame.MyBagsHintAnchorFrame or backgroundFrame
        local backgroundLeft = anchorBackground:GetLeft()
        local anchorLeft = anchorFrame:GetLeft()
        local relativeLeft = anchorLeft - backgroundLeft + ITEM_SPACING / 2
        local columnIndex = math.floor(relativeLeft / columnPixelWidth)
        local columnLeft = backgroundLeft + columnIndex * columnPixelWidth - ITEM_SPACING / 2
        offsetX = columnLeft - anchorLeft
    else
        hintWidth = anchorFrame:GetWidth()
    end

    local maxHintWidth = (UIParent:GetWidth() or 0) - HINT_TEXT_MAX_WIDTH_MARGIN
    if maxHintWidth < hintWidth then
        maxHintWidth = hintWidth
    end

    hintTextFrame:SetWidth(maxHintWidth)
    hintTextFrame.label:SetText(text)
    local requiredTextWidth = math.ceil(hintTextFrame.label:GetStringWidth() or 0) + HINT_TEXT_PADDING * 2
    if requiredTextWidth > hintWidth then
        hintWidth = requiredTextWidth
        if hintWidth > maxHintWidth then
            hintWidth = maxHintWidth
        end
    end
    hintTextFrame:SetWidth(hintWidth)

    local textHeight = math.ceil(hintTextFrame.label:GetStringHeight() or 0)
    local frameHeight = textHeight + HINT_TEXT_PADDING * 2
    if frameHeight < HINT_TEXT_MIN_HEIGHT then
        frameHeight = HINT_TEXT_MIN_HEIGHT
    end
    hintTextFrame:SetHeight(frameHeight)

    hintTextFrame:ClearAllPoints()
    hintTextFrame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", offsetX, HINT_TEXT_VERTICAL_GAP)
end

local function getCategoryHoverText(frame)
    local title = frame.ItemCategory:GetDisplayName() or frame.ItemCategory:GetName() or frame.fs:GetText()
    if frame.ItemCategory.description then
        return title .. "\n" .. frame.ItemCategory.description
    end
    return title
end

local function isHoveringCategoryTitle(frame)
    return InputUtil.IsMouseOver(frame.fs)
end

local function findFocusedCategoryFrame(frame)
    local current = frame
    while current do
        if current.ItemCategory then
            return current
        end
        if not current.GetParent then
            return nil
        end
        current = current:GetParent()
    end
    return nil
end

local function getHoveredCategoryFrameForHints()
    if hoveredCategoryFrame and hoveredCategoryFrame:IsShown() and hoveredCategoryFrame.ItemCategory then
        return hoveredCategoryFrame
    end
    if not AddonNS.DragAndDrop:IsItemDragActive() then
        return nil
    end
    local mouseFoci = GetMouseFoci()
    local focus = mouseFoci and mouseFoci[1] or nil
    return findFocusedCategoryFrame(focus)
end

local function forEachCategoryHintFrame(self, visitor)
    for i = 1, #self.categoriesFrames do
        visitor(self.categoriesFrames[i])
    end
    if AddonNS.BankView and AddonNS.BankView.dropFrames then
        for i = 1, #AddonNS.BankView.dropFrames do
            visitor(AddonNS.BankView.dropFrames[i])
        end
    end
end

function AddonNS.gui:SetHoveredCategoryFrame(frame)
    hoveredCategoryFrame = frame
    self:RefreshCategoryDragHints()
end

function AddonNS.gui:ClearHoveredCategoryFrame(frame)
    if hoveredCategoryFrame == frame then
        hoveredCategoryFrame = nil
    end
    self:RefreshCategoryDragHints()
end

function AddonNS.gui:RefreshCategoryDragHints()
    local hoveredFrame = getHoveredCategoryFrameForHints()
    local hoveredCategoryId = nil
    local hoveredScope = nil
    if hoveredFrame and hoveredFrame.ItemCategory then
        hoveredCategoryId = hoveredFrame.ItemCategory:GetId()
        hoveredScope = hoveredFrame.MyBagsScope
    end
    local shownTextFrame = nil
    local shownText = nil
    forEachCategoryHintFrame(self, function(frame)
        if frame:IsShown() then
            if frame.ItemCategory then
                local isHovered = frame == hoveredFrame
                if not isHovered and hoveredCategoryId and hoveredScope then
                    isHovered = frame.ItemCategory:GetId() == hoveredCategoryId and frame.MyBagsScope == hoveredScope
                end
                local hint = AddonNS.DragAndDrop:GetCategoryDropHint(frame.ItemCategory, isHovered)
                applyCategoryHint(frame, hint)
                if isHovered then
                    shownTextFrame = frame
                    if hint and hint.text then
                        shownText = hint.text
                    elseif isHoveringCategoryTitle(frame) then
                        shownText = getCategoryHoverText(frame)
                    end
                end
            else
                applyCategoryHint(frame, nil)
            end
        end
    end)
    if shownTextFrame and shownText then
        layoutHintTextFrame(shownTextFrame, shownText)
        hintTextFrame:Show()
        return
    end
    hintTextFrame:Hide()
end

--- draggable frame 
local draggableFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
local activeDraggedCategoryName = nil
local activeDragShiftState = nil

draggableFrame:SetSize(320, AddonNS.Const.CATEGORY_HEIGHT * 3.2)
draggableFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
draggableFrame:SetBackdropColor(0, 0, 0, 0.9)
draggableFrame:SetMovable(true)
draggableFrame:SetPoint("CENTER")
draggableFrame:Hide()
draggableFrame:SetFrameStrata("TOOLTIP")
draggableFrame.nameLine = draggableFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
draggableFrame.nameLine:SetPoint("TOPLEFT", draggableFrame, "TOPLEFT", 12, -10)
draggableFrame.nameLine:SetPoint("TOPRIGHT", draggableFrame, "TOPRIGHT", -12, -10)
draggableFrame.nameLine:SetJustifyH("LEFT")
draggableFrame.nameLine:SetWordWrap(false)
draggableFrame.nameLine:SetTextColor(1, 1, 1, 1)
draggableFrame.nameLine:SetFontObject("GameFontHighlight")
draggableFrame.nameLine:SetShadowColor(0, 0, 0, 1)
draggableFrame.nameLine:SetShadowOffset(1, -1)

draggableFrame.hintLine = draggableFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
draggableFrame.hintLine:SetPoint("TOPLEFT", draggableFrame.nameLine, "BOTTOMLEFT", 0, -4)
draggableFrame.hintLine:SetPoint("TOPRIGHT", draggableFrame, "TOPRIGHT", -12, -4)
draggableFrame.hintLine:SetJustifyH("LEFT")
draggableFrame.hintLine:SetWordWrap(true)
draggableFrame.hintLine:SetShadowColor(0, 0, 0, 1)
draggableFrame.hintLine:SetShadowOffset(1, -1)

local function refreshDragTooltipText()
    if not activeDraggedCategoryName then
        return
    end
    local categoryNameText = activeDraggedCategoryName .. "|r"
    local shiftDown = IsShiftKeyDown()
    if activeDragShiftState ~= shiftDown then
        activeDragShiftState = shiftDown
        if shiftDown then
            draggableFrame.hintLine:SetText("|cff72f272Moving |r" ..
                categoryNameText .. "|cff72f272 and all categories below it|r")
        else
            draggableFrame.hintLine:SetText("|cff72f272Hold Shift:|r|cffc8c8c8 to move |r" ..
                categoryNameText .. "|cffc8c8c8 and all categories below it|r")
        end
    end
    draggableFrame.nameLine:SetText(activeDraggedCategoryName)
end

function draggableFrame:StartDragging()
    self:SetScript("OnUpdate",
        function()
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
            refreshDragTooltipText()
        end);
end

function draggableFrame:StopDragging()
    self:SetScript("OnUpdate", nil);
    activeDraggedCategoryName = nil
    activeDragShiftState = nil
end

function AddonNS.gui.StartCategoryDragVisual(_, categoryName)
    activeDraggedCategoryName = categoryName or "Unassigned"
    refreshDragTooltipText()
    draggableFrame:Show()
    draggableFrame:StartDragging()
end

function AddonNS.gui.StopCategoryDragVisual(_)
    draggableFrame:Hide()
    draggableFrame:StopDragging()
end

backgroundFrame = CreateFrame("Frame", nil, AddonNS.container, "BackdropTemplate")     -- todo: does it need to be some frame with bg, or pure frame would sufficie? I think I was testing it and it didnt work for some reason.
backgroundFrame.MyBagsScope = "bag"
backgroundFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
backgroundFrame:SetBackdropColor(0, 1, 0, 0)
backgroundFrame:EnableMouse(true)

AddonNS.CategoryBackground:Install(backgroundFrame, {
    GetCategoryFrames = function()
        return AddonNS.gui.categoriesFrames
    end,
    GetCategoryFrame = function(category)
        return AddonNS.gui.categoryFrameByCategoryId[category:GetId()]
    end,
    ResolveDropColumn = function(relativeX, scope, width)
        return AddonNS.CategoryBackground:ResolveBagColumn(relativeX, scope, width)
    end,
})

backgroundFrame:SetPoint("BOTTOMRIGHT", AddonNS.container.MoneyFrame, "TOPRIGHT", 0, 0)
backgroundFrame.myBagAddonHooked = true;

local BAG_CAPACITY_LABEL_FORMAT = "%d / %d  Reagents %d / %d"
local freeSlotCountOverlay = CreateFrame("Frame", nil, AddonNS.container)
freeSlotCountOverlay:SetAllPoints(AddonNS.container.MoneyFrame)
freeSlotCountOverlay:SetFrameLevel(AddonNS.container.MoneyFrame:GetFrameLevel() + 10)
freeSlotCountOverlay:EnableMouse(true)

local freeSlotCountLabel = freeSlotCountOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
freeSlotCountLabel:SetPoint("LEFT", freeSlotCountOverlay, "LEFT", 6, 0)
freeSlotCountLabel:SetJustifyH("LEFT")
freeSlotCountLabel:SetTextColor(1, 0.82, 0.2, 1)

function AddonNS.gui.RefreshFreeSlotCountLabel(_)
    local state = AddonNS.GetBagCapacityState()
    freeSlotCountLabel:SetText(BAG_CAPACITY_LABEL_FORMAT:format(
        state.items.taken,
        state.items.total,
        state.reagents.taken,
        state.reagents.total
    ))
end

freeSlotCountOverlay:SetScript("OnEnter", function(self)
    local state = AddonNS.GetBagCapacityState()
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Bag capacity")
    GameTooltip:AddLine(
        "You are using " .. state.items.taken .. " regular bag slots out of " .. state.items.total ..
        " (" .. state.items.free .. " available).",
        1, 1, 1, true
    )
    GameTooltip:AddLine(
        "You are using " .. state.reagents.taken .. " reagent bag slots out of " .. state.reagents.total ..
        " (" .. state.reagents.free .. " available).",
        1, 1, 1, true
    )
    GameTooltip:Show()
end)

freeSlotCountOverlay:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

AddonNS.container:HookScript("OnShow", function()
    AddonNS.gui:RefreshFreeSlotCountLabel()
end)

AddonNS.Events:RegisterEvent("BAG_UPDATE", function()
    if AddonNS.container:IsShown() then
        AddonNS.gui:RefreshFreeSlotCountLabel()
    end
end)

local function getColumnPixelWidth()
    local itemSize = AddonNS.container.Items[1]:GetHeight() + ITEM_SPACING
    return itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
end

local bagResizeController = AddonNS.ResizeHandle:Create({
    parentFrame = AddonNS.container,
    previewParent = backgroundFrame,
    anchor = {
        point = "BOTTOMLEFT",
        relativeTo = AddonNS.container,
        relativePoint = "BOTTOMLEFT",
        x = 2,
        y = 2,
    },
    rotationDegrees = 270,
    GetColumnPixelWidth = getColumnPixelWidth,
    GetCurrentColumns = function()
        return AddonNS.CategoryStore:GetColumnCount("bag")
    end,
    GetWidth = function()
        return AddonNS.container:GetWidth()
    end,
    GetHeight = function()
        return AddonNS.container:GetHeight()
    end,
    SetWidth = function(width)
        AddonNS.container:SetWidth(width)
    end,
    SetHeight = function(height)
        AddonNS.container:SetHeight(height)
    end,
    CalculateDesiredWidth = function(startWidth, deltaX)
        return startWidth - deltaX
    end,
    ApplyTargetColumns = function(target)
        AddonNS:SetNumColumns(target, "bag")
    end,
    OnCancel = function()
        AddonNS.QueueContainerUpdateItemLayout()
    end,
    ShouldShow = function()
        return AddonNS.container:IsShown() and not InCombatLockdown()
    end,
    IsDisabled = InCombatLockdown,
})

local function refreshResizeHandle()
    bagResizeController:Refresh()
end

AddonNS.container:HookScript("OnShow", refreshResizeHandle)
AddonNS.container:HookScript("OnHide", function()
    bagResizeController:Stop()
    refreshResizeHandle()
end)

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, refreshResizeHandle)
AddonNS.Events:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    bagResizeController:Stop()
    refreshResizeHandle()
end)
AddonNS.Events:RegisterEvent("PLAYER_REGEN_ENABLED", refreshResizeHandle)


function AddonNS.gui.RegenerateCategories(_, yFrameOffset, categoriesGUIInfo)
    local moneyFrame = AddonNS.container.MoneyFrame
    AddonNS.gui.categoryFrameByCategoryId = {}
    backgroundFrame:SetPoint("TOPLEFT", moneyFrame, "TOPLEFT", 0, yFrameOffset)
    for index, categoryPosition in ipairs(categoriesGUIInfo) do
        local frame = AddonNS.gui.categoriesFrames[index]
        if not frame then
            frame = AddonNS.CategoryFrame:Create(backgroundFrame)
            AddonNS.gui.categoriesFrames[index] = frame
        end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", backgroundFrame, "TOPLEFT", categoryPosition.x, -categoryPosition.y)
        frame:SetSize(categoryPosition.width, categoryPosition.blockHeight)
        frame.MyBagsContainerRef = AddonNS.container
        frame.MyBagsHintAnchorFrame = backgroundFrame
        frame.MyBagsHintAlignToFrame = true
        AddonNS.CategoryFrame:Configure(frame, categoryPosition, "bag")
        if frame.ItemCategory then
            AddonNS.gui.categoryFrameByCategoryId[frame.ItemCategory:GetId()] = frame
        end
    end
    for index = #categoriesGUIInfo + 1, #AddonNS.gui.categoriesFrames do
        AddonNS.gui.categoriesFrames[index]:Hide()
    end
    AddonNS.gui:RefreshCategoryDragHints()
end
