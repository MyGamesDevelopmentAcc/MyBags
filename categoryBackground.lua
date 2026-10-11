local addonName, AddonNS = ...

AddonNS.CategoryBackground = {}

local function getCursorPositionForFrame(frame)
    local cursorX, cursorY = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    return cursorX / scale, cursorY / scale
end

function AddonNS.CategoryBackground:GetHintFrame(frame, categoryFrames, scope)
    local cursorX, cursorY = getCursorPositionForFrame(frame)
    for _, categoryFrame in ipairs(categoryFrames) do
        if categoryFrame:IsShown() and categoryFrame.MyBagsScope == scope and categoryFrame.ItemCategory then
            local left, right = categoryFrame:GetLeft(), categoryFrame:GetRight()
            local bottom, top = categoryFrame:GetBottom(), categoryFrame:GetTop()
            if left and right and bottom and top and
                cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top then
                return categoryFrame
            end
        end
    end
end

function AddonNS.CategoryBackground:GetDropColumn(frame, scope, resolveColumn)
    local cursorX, cursorY = getCursorPositionForFrame(frame)
    local relativeX = cursorX - frame:GetLeft()
    local relativeY = cursorY - frame:GetBottom()
    local width, height = frame:GetWidth(), frame:GetHeight()
    if relativeX < 0 or relativeX > width or relativeY < 0 or relativeY > height then
        return nil
    end
    return resolveColumn(relativeX, scope, width)
end

function AddonNS.CategoryBackground:ResolveBagColumn(relativeX, scope, width)
    local columnCount = AddonNS.CategoryStore:GetColumnCount(scope)
    return math.max(1, math.min(columnCount, math.floor(relativeX * columnCount / width) + 1))
end

function AddonNS.CategoryBackground:GetColumnHintFrame(frame, scope, resolveColumn, getCategoryFrame)
    local column = self:GetDropColumn(frame, scope, resolveColumn)
    if not column then
        return nil
    end
    local category = AddonNS.Categories:GetLastCategoryInColumn(column, scope)
    return getCategoryFrame(category)
end

function AddonNS.CategoryBackground:ReceiveCategoryMouseUp(frame, button)
    if button == "LeftButton" and
        (AddonNS.DragAndDrop:IsItemDragActive() or AddonNS.DragAndDrop:IsCategoryDragActive()) then
        AddonNS.DragAndDrop.categoryOnReceiveDrag(frame)
    end
end

function AddonNS.CategoryBackground:Install(frame, options)
    frame.MyBagsResolveDropColumn = options.ResolveDropColumn
    local function refreshHover()
        if not AddonNS.DragAndDrop:IsItemDragActive() and not AddonNS.DragAndDrop:IsCategoryDragActive() then
            AddonNS.gui:ClearHoveredCategoryFrame(frame)
            return
        end
        local scope = frame.MyBagsScope
        local hintFrame = self:GetHintFrame(frame, options.GetCategoryFrames(), scope)
        if not hintFrame then
            hintFrame = self:GetColumnHintFrame(frame, scope, options.ResolveDropColumn, options.GetCategoryFrame)
        end
        if hintFrame and hintFrame:IsShown() then
            AddonNS.gui:SetHoveredCategoryFrame(hintFrame)
        else
            AddonNS.gui:ClearHoveredCategoryFrame(frame)
        end
    end

    local function handleDrop(_, button)
        if button and button ~= "LeftButton" then
            return
        end
        if AddonNS.DragAndDrop:IsItemDragActive() or AddonNS.DragAndDrop:IsCategoryDragActive() then
            local hintFrame = self:GetHintFrame(frame, options.GetCategoryFrames(), frame.MyBagsScope)
            if hintFrame then
                AddonNS.DragAndDrop.categoryOnReceiveDrag(hintFrame)
                return
            end
        end
        AddonNS.DragAndDrop.backgroundOnReceiveDrag(frame, button)
    end

    local function clearHover()
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end
    frame:SetScript("OnEnter", refreshHover)
    frame:SetScript("OnUpdate", refreshHover)
    frame:SetScript("OnLeave", clearHover)
    frame:HookScript("OnHide", clearHover)
    frame:SetScript("OnReceiveDrag", handleDrop)
    frame:SetScript("OnMouseUp", handleDrop)
    frame.myBagAddonHooked = true
end
