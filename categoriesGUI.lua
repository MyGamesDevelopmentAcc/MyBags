local addonName, AddonNS = ...
local GS = LibStub("MyLibrary_GUI");

--- @type WowList
local WowList = LibStub("WowList-1.5");
AddonNS.CategoriesGUI = AddonNS.CategoriesGUI or {}

function AddonNS.CategoriesGUI:IsQueryEditorFocused()
    return false
end

function AddonNS.CategoriesGUI:ToggleQueryHelpFrame()
    error("CategoriesGUI not initialized")
end

function AddonNS.CategoriesGUI:HideQueryHelpFrame()
    error("CategoriesGUI not initialized")
end

function AddonNS.createGUI()
    local container = AddonNS.container;
    local selectedCategoryId = nil
    local queryEditorFocused = false
    local BAG_SCOPE = "bag"
    local BANK_SCOPE = "bank-character"
    local WARBANK_SCOPE = "bank-account"
    local QUERY_HELP_SIDE_LEFT = "left"
    local QUERY_HELP_SIDE_RIGHT = "right"
    local QUERY_HELP_OFFSET_X = 8
    local QUERY_HELP_TOOLTIP_TEXT = "Open query syntax and priority help"

    local isHelpPlateLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_HelpPlate")
    if not isHelpPlateLoaded then
        local isLoaded, reason
        if C_AddOns and C_AddOns.LoadAddOn then
            isLoaded, reason = C_AddOns.LoadAddOn("Blizzard_HelpPlate")
        else
            isLoaded, reason = LoadAddOn("Blizzard_HelpPlate")
        end
        assert(isLoaded, "Failed to load Blizzard_HelpPlate: " .. tostring(reason))
    end
    local queryHelpText = assert(AddonNS.QueryHelpDocs and AddonNS.QueryHelpDocs.text,
        "MyBags query help docs not loaded. Run: lua tools/generate_query_help.lua")

    local exportFrame
    local importFrame
    local containerFrame = CreateFrame("Frame", addonName .. "_CategoryEditorFrame", UIParent, "DefaultPanelFlatTemplate")
    containerFrame:SetSize(520, 360)
    containerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    containerFrame:SetFrameStrata("DIALOG")
    containerFrame:EnableMouse(true)
    containerFrame:SetMovable(true)
    containerFrame:SetClampedToScreen(true)
    containerFrame:RegisterForDrag("LeftButton")
    containerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    containerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    containerFrame:Hide()

    local requestCloseCategoryEditor = function(afterClose)
        containerFrame:Hide()
        if afterClose then
            afterClose()
        end
    end
    local closeButton = CreateFrame("Button", nil, containerFrame, "UIPanelCloseButtonDefaultAnchors")
    closeButton:SetScript("OnClick", function()
        requestCloseCategoryEditor()
    end)

    local panelTitle = containerFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    panelTitle:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 32, -8)
    panelTitle:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -32, -8)
    panelTitle:SetJustifyH("CENTER")
    panelTitle:SetText("Category: (none)")

    local function createQueryHelpFrame()
        local frame = GS:CreateButtonFrame(addonName .. "_queryHelp", 520, 620, true)
        frame:SetPoint("TOPLEFT", containerFrame, "TOPRIGHT", 8, 0)
        frame:EnableMouse(true)
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -8)
        title:SetText("Query Help")

        local searchEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        searchEditBox:SetAutoFocus(false)
        searchEditBox:SetSize(220, 20)
        searchEditBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -10)

        local searchPrevButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        searchPrevButton:SetSize(44, 20)
        searchPrevButton:SetPoint("LEFT", searchEditBox, "RIGHT", 6, 0)
        searchPrevButton:SetText("Prev")

        local searchNextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        searchNextButton:SetSize(44, 20)
        searchNextButton:SetPoint("LEFT", searchPrevButton, "RIGHT", 4, 0)
        searchNextButton:SetText("Next")

        local searchStatus = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        searchStatus:SetPoint("LEFT", searchNextButton, "RIGHT", 8, 0)
        searchStatus:SetJustifyH("LEFT")
        searchStatus:SetText("")

        local helpScrollFrame = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        helpScrollFrame.hideCharCount = true
        helpScrollFrame:SetPoint("TOPLEFT", searchEditBox, "BOTTOMLEFT", 0, -8)
        helpScrollFrame:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -10, 8)

        local lineStarts = {}
        local matches = {}
        local selectedMatchIndex = 0

        local function buildLineStarts(text)
            local starts = { 1 }
            local cursor = 1
            while true do
                local _, lineEnd = string.find(text, "\n", cursor, true)
                if not lineEnd then
                    break
                end
                table.insert(starts, lineEnd + 1)
                cursor = lineEnd + 1
            end
            return starts
        end

        local function collectMatches(text, query)
            local foundMatches = {}
            if query == "" then
                return foundMatches
            end
            local searchFrom = 1
            while true do
                local startIndex, endIndex = string.find(text, query, searchFrom, true)
                if not startIndex then
                    break
                end
                table.insert(foundMatches, {
                    startIndex = startIndex,
                    endIndex = endIndex,
                })
                searchFrom = startIndex + 1
            end
            return foundMatches
        end

        local function findLineIndexForChar(charIndex)
            for index = #lineStarts, 1, -1 do
                if charIndex >= lineStarts[index] then
                    return index
                end
            end
            return 1
        end

        local function scrollToMatch(match)
            local lineIndex = findLineIndexForChar(match.startIndex)
            local _, fontHeight = helpScrollFrame.EditBox:GetFont()
            local lineHeight = fontHeight or 12
            local targetScroll = (lineIndex - 1) * lineHeight
            local maxScroll = math.max(0, helpScrollFrame.EditBox:GetHeight() - helpScrollFrame:GetHeight())
            if targetScroll > maxScroll then
                targetScroll = maxScroll
            end
            helpScrollFrame:SetVerticalScroll(targetScroll)
            helpScrollFrame.EditBox:HighlightText(match.startIndex - 1, match.endIndex)
        end

        local function refreshSearchStatus()
            if #matches == 0 then
                if searchEditBox:GetText() == "" then
                    searchStatus:SetText("")
                else
                    searchStatus:SetText("No matches")
                end
                return
            end
            searchStatus:SetText(selectedMatchIndex .. "/" .. #matches)
        end

        local function runSearch(resetSelection)
            local query = string.lower(searchEditBox:GetText() or "")
            local searchableText = string.lower(queryHelpText)
            matches = collectMatches(searchableText, query)
            if #matches == 0 then
                selectedMatchIndex = 0
                helpScrollFrame.EditBox:HighlightText(0, 0)
                refreshSearchStatus()
                return
            end

            if resetSelection or selectedMatchIndex <= 0 or selectedMatchIndex > #matches then
                selectedMatchIndex = 1
            end
            scrollToMatch(matches[selectedMatchIndex])
            refreshSearchStatus()
        end

        local function stepSearch(offset)
            if #matches == 0 then
                runSearch(true)
                return
            end
            selectedMatchIndex = selectedMatchIndex + offset
            if selectedMatchIndex < 1 then
                selectedMatchIndex = #matches
            elseif selectedMatchIndex > #matches then
                selectedMatchIndex = 1
            end
            scrollToMatch(matches[selectedMatchIndex])
            refreshSearchStatus()
        end

        local helpLoaded = false
        helpScrollFrame:SetScript("OnShow", function()
            if not helpLoaded then
                helpLoaded = true
                InputScrollFrame_OnLoad(helpScrollFrame)
                helpScrollFrame.EditBox:SetFontObject(GameFontHighlightSmall)
                helpScrollFrame.EditBox:SetAutoFocus(false)
            end
            helpScrollFrame.EditBox:SetText(queryHelpText)
            helpScrollFrame.EditBox:SetCursorPosition(0)
            helpScrollFrame.EditBox:HighlightText(0, 0)
            lineStarts = buildLineStarts(queryHelpText)
            runSearch(true)
            if (searchEditBox:GetText() or "") == "" then
                helpScrollFrame.EditBox:SetCursorPosition(0)
                helpScrollFrame.EditBox:HighlightText(0, 0)
                helpScrollFrame:SetVerticalScroll(0)
            end
        end)
        searchEditBox:SetScript("OnTextChanged", function(_, userInput)
            if not userInput then
                return
            end
            runSearch(true)
        end)
        searchEditBox:SetScript("OnEnterPressed", function()
            stepSearch(1)
        end)
        searchEditBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        searchPrevButton:SetScript("OnClick", function()
            stepSearch(-1)
        end)
        searchNextButton:SetScript("OnClick", function()
            stepSearch(1)
        end)

        return frame
    end

    local queryHelpFrame = createQueryHelpFrame()
    local queryHelpAnchorFrame = nil
    local queryHelpPreferredSide = nil

    local function applyQueryHelpAnchor(anchorFrame, preferredSide)
        queryHelpFrame:ClearAllPoints()
        if preferredSide == QUERY_HELP_SIDE_LEFT then
            queryHelpFrame:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -QUERY_HELP_OFFSET_X, 0)
            return
        end
        queryHelpFrame:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", QUERY_HELP_OFFSET_X, 0)
    end

    local function shouldCenterQueryHelpFrame()
        local left = queryHelpFrame:GetLeft()
        local right = queryHelpFrame:GetRight()
        if not left or not right then
            return false
        end
        local screenLeft = UIParent:GetLeft() or 0
        local screenRight = UIParent:GetRight() or GetScreenWidth()
        return left < screenLeft or right > screenRight
    end

    local function showQueryHelpFrame(anchorFrame, preferredSide)
        applyQueryHelpAnchor(anchorFrame, preferredSide)
        queryHelpFrame:Show()
        if shouldCenterQueryHelpFrame() then
            queryHelpFrame:ClearAllPoints()
            queryHelpFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        queryHelpAnchorFrame = anchorFrame
        queryHelpPreferredSide = preferredSide
    end

    local function hideQueryHelpFrame()
        queryHelpFrame:Hide()
        queryHelpAnchorFrame = nil
        queryHelpPreferredSide = nil
    end

    local function toggleQueryHelpFrame(anchorFrame, preferredSide)
        if queryHelpFrame:IsShown() and queryHelpAnchorFrame == anchorFrame and queryHelpPreferredSide == preferredSide then
            hideQueryHelpFrame()
            return
        end
        showQueryHelpFrame(anchorFrame, preferredSide)
    end

    function AddonNS.CategoriesGUI:RequestExitEditMode()
        requestCloseCategoryEditor(function()
            AddonNS.BagViewState:SetMode("normal")
        end)
    end

    local bagControls = AddonNS.ContainerControls:Create(container, container, BagItemSearchBox, container, QUERY_HELP_SIDE_LEFT)
    local settingsButton = bagControls.editButton
    local bagSearchHelpButton = bagControls.helpButton
    local bagSearchScopeDisabledCheckbox = bagControls.scopeDisabledCheckbox
    settingsButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", -9, -34)

    local function updateTopRightButtons()
        if container:IsShown() and BagItemAutoSortButton:GetParent() == container then
            BagItemAutoSortButton:Hide()
            settingsButton:Show()
            settingsButton:ClearAllPoints()
            settingsButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", -9, -38)
        end
        bagControls:Refresh()
        if container:IsShown() and BagItemSearchBox:IsShown() and BagItemSearchBox:GetParent() == container then
            bagSearchHelpButton:Show()
            return
        end
        bagSearchHelpButton:Hide()
        bagSearchScopeDisabledCheckbox:Hide()
    end

    container:HookScript("OnShow", updateTopRightButtons)
    hooksecurefunc(container, "UpdateSearchBox", updateTopRightButtons)
    container:HookScript("OnHide", function()
        AddonNS.BagViewState:SetMode("normal")
        containerFrame:Hide()
        hideQueryHelpFrame()
        bagSearchHelpButton:Hide()
        bagSearchScopeDisabledCheckbox:Hide()
        if exportFrame then
            exportFrame:Hide()
        end
        if importFrame then
            importFrame:Hide()
        end
        StaticPopup_Hide("CREATE_CATEGORY_CONFIRM")
        StaticPopup_Hide("DELETE_CATEGORY_CONFIRM")
        StaticPopup_Hide("IMPORT_CATEGORIES_CONFIRM")
        StaticPopup_Hide("CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM")
    end)
    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, function()
        updateTopRightButtons()
    end)
    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.SCOPE_DISABLED_CONFIG_VISIBILITY_CHANGED, function()
        updateTopRightButtons()
        AddonNS.QueueContainerUpdateItemLayout()
    end)
    updateTopRightButtons()

    local function getSelectedCategory()
        if not selectedCategoryId then
            return nil
        end
        return AddonNS.CategoryStore:Get(selectedCategoryId)
    end

    local function getSelectedCategoryId()
        return selectedCategoryId
    end

    local function resolveValidSelectedCategoryId(categoryId)
        if not categoryId then
            return nil
        end
        local category = AddonNS.CategoryStore:Get(categoryId)
        if not category then
            return nil
        end
        local customCategories = AddonNS.CustomCategories:GetCategories()
        if customCategories[category:GetId()] == nil then
            return nil
        end
        return category:GetId()
    end

    local selectedCategoryBaseline = nil
    local suspendControlHandlers = false
    local cancelNameCommitOnFocusLost = false

    local editorContent = CreateFrame("Frame", nil, containerFrame, "InsetFrameTemplate3")
    editorContent:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 12, -34)
    editorContent:SetPoint("BOTTOMRIGHT", containerFrame, "BOTTOMRIGHT", -12, 12)

    local selectedCategoryTitle = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    selectedCategoryTitle:SetPoint("TOPLEFT", editorContent, "TOPLEFT", 12, -10)
    selectedCategoryTitle:SetPoint("TOPRIGHT", editorContent, "TOPRIGHT", -12, -10)
    selectedCategoryTitle:SetJustifyH("LEFT")
    selectedCategoryTitle:SetText("|cffffd34fCategory:|r |cffbbbbbb(none)|r")

    local function collectSortedCustomCategories()
        local entries = {}
        for _, category in pairs(AddonNS.CustomCategories:GetCategories()) do
            table.insert(entries, category)
        end
        table.sort(entries, function(left, right)
            local leftName = left:GetName() or ""
            local rightName = right:GetName() or ""
            leftName = string.lower(leftName)
            rightName = string.lower(rightName)
            if leftName == rightName then
                return left.id < right.id
            end
            return leftName < rightName
        end)
        return entries
    end

    local function createExportFrame()
        local frame = GS:CreateButtonFrame(addonName .. "_exportCategories", 500, 560, true)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:EnableMouse(true)
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -8)
        title:SetText("Export Categories")

        local exportList = WowList:CreateNew(addonName .. "_exportList", {
            height = 180,
            rows = 8,
            columns = {
                {
                    name = "Name",
                    width = 458,
                    displayFunction = function(cellData, rowData)
                        return rowData.name, { 1, 1, 1, 1 }
                    end,
                },
            },
        }, frame)
        exportList:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        exportList:SetMultiSelection(true)

        local outputScroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        outputScroll.hideCharCount = true
        outputScroll:SetPoint("TOPLEFT", exportList, "BOTTOMLEFT", 0, -8)
        outputScroll:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -10, 36)
        local outputLoaded = false
        outputScroll:SetScript("OnShow", function()
            if not outputLoaded then
                outputLoaded = true
                InputScrollFrame_OnLoad(outputScroll)
            end
        end)
        outputScroll.EditBox:SetFontObject(NumberFont_Shadow_Tiny)
        outputScroll.EditBox:SetAutoFocus(false)

        local function refreshExportList()
            exportList:RemoveAll()
            for _, category in ipairs(collectSortedCustomCategories()) do
                exportList:AddData({
                    id = category:GetId(),
                    name = category:GetName() or "",
                })
            end
            exportList:UpdateView()
            outputScroll.EditBox:SetText("")
        end

        local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        exportButton:SetSize(130, 20)
        exportButton:SetPoint("BOTTOMLEFT", frame.Inset, "BOTTOMLEFT", 4, 8)
        exportButton:SetText("Generate Export")
        exportButton:SetScript("OnClick", function()
            local selectedRows = exportList:GetSelected() or {}
            local selectedCategoryIds = {}
            for _, row in ipairs(selectedRows) do
                table.insert(selectedCategoryIds, row.id)
            end
            local payload = AddonNS.CustomCategories:BuildExportPayload(selectedCategoryIds)
            outputScroll.EditBox:SetText(AddonNS.CustomCategories:EncodeExportPayload(payload))
            outputScroll.EditBox:HighlightText(0)
            outputScroll.EditBox:SetFocus()
        end)

        local exportCloseButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        exportCloseButton:SetSize(80, 20)
        exportCloseButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
        exportCloseButton:SetText("Close")
        exportCloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame:SetScript("OnShow", refreshExportList)
        return frame
    end

    local function createImportFrame()
        local frame = GS:CreateButtonFrame(addonName .. "_importCategories", 520, 560, true)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:EnableMouse(true)
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -8)
        title:SetText("Import Categories")

        local inputScroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        inputScroll.hideCharCount = true
        inputScroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        inputScroll:SetPoint("TOPRIGHT", frame.Inset, "TOPRIGHT", -10, -36)
        inputScroll:SetHeight(330)
        local inputLoaded = false
        inputScroll:SetScript("OnShow", function()
            if not inputLoaded then
                inputLoaded = true
                InputScrollFrame_OnLoad(inputScroll)
            end
        end)
        inputScroll.EditBox:SetFontObject(NumberFont_Shadow_Tiny)
        inputScroll.EditBox:SetAutoFocus(false)

        local previewScroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        previewScroll.hideCharCount = true
        previewScroll:SetPoint("TOPLEFT", inputScroll, "BOTTOMLEFT", 0, -8)
        previewScroll:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -10, 36)
        local previewLoaded = false
        previewScroll:SetScript("OnShow", function()
            if not previewLoaded then
                previewLoaded = true
                InputScrollFrame_OnLoad(previewScroll)
            end
        end)
        previewScroll.EditBox:SetFontObject(NumberFont_Shadow_Tiny)
        previewScroll.EditBox:SetAutoFocus(false)
        previewScroll.EditBox:EnableMouse(false)
        previewScroll.EditBox:SetScript("OnEditFocusGained", function(self)
            self:ClearFocus()
        end)

        local function setPreviewText(value)
            previewScroll.EditBox:SetText(value or "")
            previewScroll:SetVerticalScroll(0)
        end

        local importPreview = nil
        local analyzeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        analyzeButton:SetSize(120, 20)
        analyzeButton:SetPoint("BOTTOMLEFT", frame.Inset, "BOTTOMLEFT", 4, 8)
        analyzeButton:SetText("Analyze Import")

        local applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        applyButton:SetSize(110, 20)
        applyButton:SetPoint("LEFT", analyzeButton, "RIGHT", 8, 0)
        applyButton:SetText("Apply Import")
        applyButton:Disable()

        local importCloseButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        importCloseButton:SetSize(80, 20)
        importCloseButton:SetPoint("LEFT", applyButton, "RIGHT", 8, 0)
        importCloseButton:SetText("Close")
        importCloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        analyzeButton:SetScript("OnClick", function()
            importPreview = nil
            applyButton:Disable()
            local ok, previewOrErr = pcall(function()
                return AddonNS.CustomCategories:PreviewImport(inputScroll.EditBox:GetText())
            end)
            if not ok then
                setPreviewText("Import error: " .. tostring(previewOrErr))
                return
            end
            importPreview = previewOrErr
            local createCount = #importPreview.toCreate
            local lines = { string.format("Ready to import (%d categories):", createCount) }
            for _, entry in ipairs(importPreview.toCreate) do
                lines[#lines + 1] = "• " .. tostring(entry.name or "(unnamed)")
            end
            setPreviewText(table.concat(lines, "\n"))
            applyButton:Enable()
        end)

        applyButton:SetScript("OnClick", function()
            if not importPreview then
                return
            end
            local dialog = StaticPopup_Show("IMPORT_CATEGORIES_CONFIRM", tostring(#importPreview.toCreate))
            if dialog then
                dialog.data = importPreview
            end
        end)

        frame:SetScript("OnShow", function()
            setPreviewText("")
            importPreview = nil
            applyButton:Disable()
        end)

        return frame
    end


    local function toggleExportFrame()
        if not exportFrame then
            exportFrame = createExportFrame()
        end
        if exportFrame:IsShown() then
            exportFrame:Hide()
            return
        end
        exportFrame:Show()
    end

    local function toggleImportFrame()
        if not importFrame then
            importFrame = createImportFrame()
        end
        if importFrame:IsShown() then
            importFrame:Hide()
            return
        end
        importFrame:Show()
    end

    local nameLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", selectedCategoryTitle, "BOTTOMLEFT", 0, -16)
    nameLabel:SetText("Name")
    nameLabel:EnableMouse(true)

    local nameEditBox = CreateFrame("EditBox", nil, editorContent, "InputBoxTemplate")
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetMaxLetters(64)
    nameEditBox:SetSize(340, 20)
    nameEditBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 4, -6)

    local alwaysShowCheckbox = CreateFrame("CheckButton", nil, editorContent, "ChatConfigCheckButtonTemplate")
    alwaysShowCheckbox:SetPoint("TOPLEFT", nameEditBox, "BOTTOMLEFT", -2, -10)
    alwaysShowCheckbox:SetSize(30, 30)
    alwaysShowCheckbox.Text:SetText("Always show")
    alwaysShowCheckbox.tooltip =
    "Enabling this will make this category always visible, even when no items currently associated with it."

    local visibleInLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibleInLabel:SetPoint("LEFT", alwaysShowCheckbox.Text, "RIGHT", 18, 0)
    visibleInLabel:SetText("Used in")
    visibleInLabel:EnableMouse(true)

    local visibleBagsCheckbox = CreateFrame("CheckButton", nil, editorContent, "ChatConfigCheckButtonTemplate")
    visibleBagsCheckbox:SetPoint("LEFT", visibleInLabel, "RIGHT", 8, 0)
    visibleBagsCheckbox:SetSize(30, 30)
    visibleBagsCheckbox:SetHitRectInsets(7, 7, 7, 7)
    visibleBagsCheckbox.Text:SetText("")
    visibleBagsCheckbox.Text:Hide()

    local visibleBagsLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibleBagsLabel:SetPoint("LEFT", visibleBagsCheckbox, "RIGHT", 2, 0)
    visibleBagsLabel:SetText("Bags")
    visibleBagsLabel:EnableMouse(false)

    local visibleBankCheckbox = CreateFrame("CheckButton", nil, editorContent, "ChatConfigCheckButtonTemplate")
    visibleBankCheckbox:SetPoint("LEFT", visibleBagsLabel, "RIGHT", 14, 0)
    visibleBankCheckbox:SetSize(30, 30)
    visibleBankCheckbox:SetHitRectInsets(7, 7, 7, 7)
    visibleBankCheckbox.Text:SetText("")
    visibleBankCheckbox.Text:Hide()

    local visibleBankLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibleBankLabel:SetPoint("LEFT", visibleBankCheckbox, "RIGHT", 2, 0)
    visibleBankLabel:SetText("Bank")
    visibleBankLabel:EnableMouse(false)

    local visibleWarbankCheckbox = CreateFrame("CheckButton", nil, editorContent, "ChatConfigCheckButtonTemplate")
    visibleWarbankCheckbox:SetPoint("LEFT", visibleBankLabel, "RIGHT", 14, 0)
    visibleWarbankCheckbox:SetSize(30, 30)
    visibleWarbankCheckbox:SetHitRectInsets(7, 7, 7, 7)
    visibleWarbankCheckbox.Text:SetText("")
    visibleWarbankCheckbox.Text:Hide()

    local visibleWarbankLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibleWarbankLabel:SetPoint("LEFT", visibleWarbankCheckbox, "RIGHT", 2, 0)
    visibleWarbankLabel:SetText("Warbank")
    visibleWarbankLabel:EnableMouse(false)

    local priorityLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    priorityLabel:SetPoint("TOPLEFT", alwaysShowCheckbox, "BOTTOMLEFT", 2, -14)
    priorityLabel:SetText("Priority")
    priorityLabel:EnableMouse(true)

    local priorityEditBox = CreateFrame("EditBox", nil, editorContent, "InputBoxTemplate")
    priorityEditBox:SetAutoFocus(false)
    priorityEditBox:SetNumeric(true)
    priorityEditBox:SetMaxLetters(9)
    priorityEditBox:SetSize(120, 20)
    priorityEditBox:SetPoint("TOPLEFT", priorityLabel, "BOTTOMLEFT", 4, -6)

    local queryLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    queryLabel:SetPoint("TOPLEFT", priorityEditBox, "BOTTOMLEFT", -4, -18)
    queryLabel:SetText("Query")
    queryLabel:EnableMouse(true)

    local queryEditBox = CreateFrame("EditBox", nil, editorContent, "SearchBoxTemplate")
    queryEditBox:SetSize(420, 26)
    queryEditBox:SetPoint("TOPLEFT", queryLabel, "BOTTOMLEFT", 0, -6)
    queryEditBox:SetAutoFocus(false)
    queryEditBox:SetMaxLetters(255)
    queryEditBox.instructionText = "Query expression"
    queryEditBox.Instructions:SetText(queryEditBox.instructionText)

    local queryValidationBorder = CreateFrame("Frame", nil, editorContent, "BackdropTemplate")
    queryValidationBorder:SetPoint("TOPLEFT", queryEditBox, "TOPLEFT", -3, 3)
    queryValidationBorder:SetPoint("BOTTOMRIGHT", queryEditBox, "BOTTOMRIGHT", 3, -3)
    queryValidationBorder:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    queryValidationBorder:SetBackdropColor(0.2, 0.05, 0.05, 0.45)
    queryValidationBorder:SetBackdropBorderColor(1, 0.18, 0.18, 1)
    queryValidationBorder:EnableMouse(false)
    queryValidationBorder:Hide()

    local queryValidationText = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    queryValidationText:SetPoint("TOPLEFT", queryEditBox, "BOTTOMLEFT", 0, -4)
    queryValidationText:SetPoint("TOPRIGHT", queryEditBox, "BOTTOMRIGHT", 0, -4)
    queryValidationText:SetJustifyH("LEFT")
    queryValidationText:SetTextColor(1, 0.25, 0.25, 1)
    queryValidationText:SetText("")

    local helpButton = CreateFrame("Button", nil, editorContent, "MainHelpPlateButton")
    helpButton:SetPoint("LEFT", queryEditBox, "RIGHT", 2, 0)
    helpButton:SetSize(64, 64)
    helpButton:SetScale(0.45)
    helpButton.mainHelpPlateButtonTooltipText = QUERY_HELP_TOOLTIP_TEXT
    helpButton:SetScript("OnClick", function()
        toggleQueryHelpFrame(containerFrame, QUERY_HELP_SIDE_RIGHT)
    end)

    local saveButton = CreateFrame("Button", nil, editorContent, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 22)
    saveButton:SetPoint("BOTTOMRIGHT", editorContent, "BOTTOMRIGHT", -14, 14)
    saveButton:SetText("Save")

    local revertButton = CreateFrame("Button", nil, editorContent, "UIPanelButtonTemplate")
    revertButton:SetSize(160, 22)
    revertButton:SetPoint("RIGHT", saveButton, "LEFT", -8, 0)
    revertButton:SetText("Revert Changes")

    local function normalizeCategoryState(category)
        local scopeVisibility = AddonNS.CustomCategories:GetScopeVisibility(category)
        return {
            name = category:GetName() or "",
            query = AddonNS.CustomCategories:GetQuery(category),
            priority = AddonNS.CustomCategories:GetEffectivePriority(category),
            alwaysShow = AddonNS.CategorShowAlways:ShouldAlwaysShow(category) == true,
            scopeVisibility = {
                [BAG_SCOPE] = scopeVisibility[BAG_SCOPE] == true,
                [BANK_SCOPE] = scopeVisibility[BANK_SCOPE] == true,
                [WARBANK_SCOPE] = scopeVisibility[WARBANK_SCOPE] == true,
            },
        }
    end

    local function categoryStateEquals(left, right)
        return left
            and right
            and left.name == right.name
            and left.query == right.query
            and left.priority == right.priority
            and left.alwaysShow == right.alwaysShow
            and left.scopeVisibility[BAG_SCOPE] == right.scopeVisibility[BAG_SCOPE]
            and left.scopeVisibility[BANK_SCOPE] == right.scopeVisibility[BANK_SCOPE]
            and left.scopeVisibility[WARBANK_SCOPE] == right.scopeVisibility[WARBANK_SCOPE]
    end

    local function getActiveContainerSearchBox()
        if BankFrame and BankFrame:IsShown() and BankItemSearchBox then
            return BankItemSearchBox
        end
        return BagItemSearchBox
    end

    local function applyQueryTextToActiveSearch(queryText, searchBox)
        queryText = queryText or ""
        local targetSearchBox = searchBox or getActiveContainerSearchBox()
        if not targetSearchBox then
            return
        end
        if targetSearchBox:GetText() ~= queryText then
            targetSearchBox:SetText(queryText)
            return
        end
    end

    local function showAnchorTooltip(owner, title, text)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end

    local function getQueryValidationError(queryText)
        local normalizedQueryText = queryText or ""
        if normalizedQueryText == "" then
            return nil
        end
        local isValid = AddonNS.QueryCategories:CompileAdHoc(normalizedQueryText) ~= nil
        if isValid then
            return nil
        end
        return "Invalid query syntax. Check Query Help."
    end

    local function refreshQueryValidationState(queryText)
        local message = getQueryValidationError(queryText)
        if message then
            queryValidationBorder:Show()
            queryValidationText:SetText(message)
            queryEditBox:SetTextColor(1, 0.45, 0.45)
            return false
        end
        queryValidationBorder:Hide()
        queryValidationText:SetText("")
        queryEditBox:SetTextColor(1, 1, 1)
        return true
    end

    local function readDraftState()
        local rawPriority = priorityEditBox:GetText()
        return {
            name = nameEditBox:GetText() or "",
            query = queryEditBox:GetText() or "",
            priority = rawPriority ~= "" and tonumber(rawPriority) or nil,
            alwaysShow = alwaysShowCheckbox:GetChecked() == true,
            scopeVisibility = {
                [BAG_SCOPE] = visibleBagsCheckbox:GetChecked() == true,
                [BANK_SCOPE] = visibleBankCheckbox:GetChecked() == true,
                [WARBANK_SCOPE] = visibleWarbankCheckbox:GetChecked() == true,
            },
        }
    end

    local function hasPendingChanges()
        local category = getSelectedCategory()
        if not category or not selectedCategoryBaseline then
            return false
        end
        return not categoryStateEquals(readDraftState(), selectedCategoryBaseline)
    end

    local function refreshActionButtonsState()
        local category = getSelectedCategory()
        if not category then
            revertButton:Disable()
            saveButton:Disable()
            return
        end
        if hasPendingChanges() then
            revertButton:Enable()
            saveButton:Enable()
            return
        end
        revertButton:Disable()
        saveButton:Disable()
    end

    local function applyStateToControls(state)
        suspendControlHandlers = true
        nameEditBox:SetText(state.name)
        queryEditBox:SetText(state.query)
        priorityEditBox:SetText(tostring(state.priority))
        alwaysShowCheckbox:SetChecked(state.alwaysShow)
        visibleBagsCheckbox:SetChecked(state.scopeVisibility[BAG_SCOPE] == true)
        visibleBankCheckbox:SetChecked(state.scopeVisibility[BANK_SCOPE] == true)
        visibleWarbankCheckbox:SetChecked(state.scopeVisibility[WARBANK_SCOPE] == true)
        suspendControlHandlers = false
        refreshQueryValidationState(state.query)
        refreshActionButtonsState()
    end

    local function saveSelectedCategoryDraft()
        local category = getSelectedCategory()
        if not category then
            return false
        end
        local draftState = readDraftState()
        local queryValidationError = getQueryValidationError(draftState.query)
        if queryValidationError then
            refreshQueryValidationState(draftState.query)
            queryValidationText:SetText("Cannot save: " .. queryValidationError)
            return false
        end
        local currentState = normalizeCategoryState(category)
        if draftState.name == "" then
            draftState.name = currentState.name
        end
        local changed = false
        if draftState.name ~= currentState.name then
            AddonNS.CustomCategories:RenameCategory(category, draftState.name)
            changed = true
        end
        if draftState.query ~= currentState.query then
            AddonNS.CustomCategories:SetQuery(category, draftState.query)
            changed = true
        end
        if draftState.priority ~= currentState.priority then
            AddonNS.CustomCategories:SetPriority(category, draftState.priority)
            changed = true
        end
        if draftState.alwaysShow ~= currentState.alwaysShow then
            AddonNS.CategorShowAlways:SetAlwaysShow(category, draftState.alwaysShow)
            changed = true
        end
        if draftState.scopeVisibility[BAG_SCOPE] ~= currentState.scopeVisibility[BAG_SCOPE] then
            AddonNS.CustomCategories:SetVisibleInScope(category, BAG_SCOPE, draftState.scopeVisibility[BAG_SCOPE])
            changed = true
        end
        if draftState.scopeVisibility[BANK_SCOPE] ~= currentState.scopeVisibility[BANK_SCOPE] then
            AddonNS.CustomCategories:SetVisibleInScope(category, BANK_SCOPE, draftState.scopeVisibility[BANK_SCOPE])
            changed = true
        end
        if draftState.scopeVisibility[WARBANK_SCOPE] ~= currentState.scopeVisibility[WARBANK_SCOPE] then
            AddonNS.CustomCategories:SetVisibleInScope(category, WARBANK_SCOPE, draftState.scopeVisibility[WARBANK_SCOPE])
            changed = true
        end
        if changed then
            AddonNS.QueueContainerUpdateItemLayout()
        end
        selectedCategoryBaseline = normalizeCategoryState(category)
        local savedName = selectedCategoryBaseline.name or "(unnamed)"
        panelTitle:SetText(savedName)
        selectedCategoryTitle:SetText("|cffffd34fCategory:|r " .. savedName)
        applyStateToControls(selectedCategoryBaseline)
        return true
    end

    local skipUnsavedClosePrompt = false
    local pendingCloseAfterSave = nil
    local pendingCloseDiscard = nil

    local function closeCategoryEditorNow(afterClose)
        skipUnsavedClosePrompt = true
        containerFrame:Hide()
        skipUnsavedClosePrompt = false
        if afterClose then
            afterClose()
        end
    end

    requestCloseCategoryEditor = function(afterClose)
        if skipUnsavedClosePrompt or not containerFrame:IsShown() then
            closeCategoryEditorNow(afterClose)
            return
        end
        if hasPendingChanges() then
            pendingCloseAfterSave = afterClose
            pendingCloseDiscard = afterClose
            StaticPopup_Show("CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM")
            return
        end
        closeCategoryEditorNow(afterClose)
    end

    nameEditBox:SetScript("OnEnterPressed", function(self)
        cancelNameCommitOnFocusLost = false
        self:ClearFocus()
    end)
    nameEditBox:SetScript("OnEditFocusLost", function()
        if cancelNameCommitOnFocusLost then
            cancelNameCommitOnFocusLost = false
        end
    end)
    nameEditBox:SetScript("OnEscapePressed", function(self)
        cancelNameCommitOnFocusLost = true
        local baselineState = selectedCategoryBaseline
        if baselineState then
            suspendControlHandlers = true
            self:SetText(baselineState.name)
            suspendControlHandlers = false
        end
        self:ClearFocus()
    end)
    nameEditBox:HookScript("OnTextChanged", function(self, userInput)
        if userInput and not suspendControlHandlers then
            refreshActionButtonsState()
        end
    end)
    local function showNameTooltip(owner)
        showAnchorTooltip(owner, "Category Name", "Display name used for this category header.")
    end
    nameLabel:SetScript("OnEnter", function(self)
        showNameTooltip(self)
    end)
    nameLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    nameEditBox:SetScript("OnEnter", function(self)
        showNameTooltip(self)
    end)
    nameEditBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    alwaysShowCheckbox:SetScript("OnClick", function(self)
        if suspendControlHandlers then
            return
        end
        refreshActionButtonsState()
    end)

    local function onScopeVisibilityCheckboxClick()
        if suspendControlHandlers then
            return
        end
        refreshActionButtonsState()
    end
    visibleBagsCheckbox:SetScript("OnClick", onScopeVisibilityCheckboxClick)
    visibleBankCheckbox:SetScript("OnClick", onScopeVisibilityCheckboxClick)
    visibleWarbankCheckbox:SetScript("OnClick", onScopeVisibilityCheckboxClick)

    local function showScopeVisibilityTooltip(owner, scopeLabel)
        showAnchorTooltip(
            owner,
            "Used in " .. scopeLabel,
            "When disabled, this category is not considered for categorization or display in " .. scopeLabel .. "."
        )
    end
    visibleInLabel:SetScript("OnEnter", function(self)
        showScopeVisibilityTooltip(self, "this container type")
    end)
    visibleInLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    visibleBagsCheckbox:SetScript("OnEnter", function(self)
        showScopeVisibilityTooltip(self, "Bags")
    end)
    visibleBagsCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    visibleBankCheckbox:SetScript("OnEnter", function(self)
        showScopeVisibilityTooltip(self, "Bank")
    end)
    visibleBankCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    visibleWarbankCheckbox:SetScript("OnEnter", function(self)
        showScopeVisibilityTooltip(self, "Warbank")
    end)
    visibleWarbankCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    priorityEditBox:SetScript("OnTextChanged", function(self, userInput)
        if suspendControlHandlers or not userInput then
            return
        end
        refreshActionButtonsState()
    end)
    local function showPriorityTooltip(owner)
        showAnchorTooltip(owner, "Priority",
            "Used when multiple query categories match the same item that is not manually assigned. The item is categorized under the highest-priority matching category. Ties are resolved alphabetically.")
    end
    priorityLabel:SetScript("OnEnter", function(self)
        showPriorityTooltip(self)
    end)
    priorityLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    priorityEditBox:SetScript("OnEnter", function(self)
        showPriorityTooltip(self)
    end)
    priorityEditBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local mirroredSearchBox = nil

    queryEditBox:HookScript("OnEditFocusGained", function(self)
        queryEditorFocused = true
        mirroredSearchBox = getActiveContainerSearchBox()
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, true)
        applyQueryTextToActiveSearch(self:GetText(), mirroredSearchBox)
    end)
    queryEditBox:HookScript("OnEditFocusLost", function()
        local queryText = queryEditBox:GetText() or ""
        local targetSearchBox = mirroredSearchBox or getActiveContainerSearchBox()
        if targetSearchBox and targetSearchBox:GetText() == queryText then
            applyQueryTextToActiveSearch("", targetSearchBox)
        end
        mirroredSearchBox = nil
        queryEditorFocused = false
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, false)
    end)
    queryEditBox:HookScript("OnTextChanged", function(self, userInput)
        if suspendControlHandlers then
            return
        end
        refreshQueryValidationState(self:GetText())
        if userInput then
            if not mirroredSearchBox then
                mirroredSearchBox = getActiveContainerSearchBox()
            end
            applyQueryTextToActiveSearch(self:GetText(), mirroredSearchBox)
            refreshActionButtonsState()
        end
    end)
    queryLabel:SetScript("OnEnter", function(self)
        showAnchorTooltip(self, "Query", "Rules used to automatically match items to this category.")
    end)
    queryLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    saveButton:SetScript("OnClick", function()
        saveSelectedCategoryDraft()
    end)

    revertButton:SetScript("OnClick", function()
        if not selectedCategoryBaseline then
            return
        end
        applyStateToControls(selectedCategoryBaseline)
    end)

    local function refreshSelectedCategoryControls()
        local category = getSelectedCategory()
        suspendControlHandlers = true
        if category then
            local categoryName = category:GetName() or "(unnamed)"
            panelTitle:SetText(categoryName)
            selectedCategoryTitle:SetText("|cffffd34fCategory:|r " .. categoryName)
            nameEditBox:Enable()
            alwaysShowCheckbox:Enable()
            visibleBagsCheckbox:Enable()
            visibleBankCheckbox:Enable()
            visibleWarbankCheckbox:Enable()
            priorityEditBox:Enable()
            queryEditBox:Enable()
            local state = normalizeCategoryState(category)
            applyStateToControls(state)
            return
        end

        panelTitle:SetText("Category Editor")
        selectedCategoryTitle:SetText("|cffffd34fCategory:|r |cffbbbbbb(none)|r")
        nameEditBox:SetText("")
        alwaysShowCheckbox:SetChecked(false)
        visibleBagsCheckbox:SetChecked(false)
        visibleBankCheckbox:SetChecked(false)
        visibleWarbankCheckbox:SetChecked(false)
        queryEditBox:SetText("")
        priorityEditBox:SetText("")
        refreshQueryValidationState("")
        nameEditBox:Disable()
        alwaysShowCheckbox:Disable()
        visibleBagsCheckbox:Disable()
        visibleBankCheckbox:Disable()
        visibleWarbankCheckbox:Disable()
        priorityEditBox:Disable()
        queryEditBox:Disable()
        suspendControlHandlers = false
        refreshActionButtonsState()
    end

    local function setSelectedCategoryById(categoryId)
        local resolvedId = resolveValidSelectedCategoryId(categoryId)
        if selectedCategoryId == resolvedId then
            refreshSelectedCategoryControls()
            return
        end
        selectedCategoryId = resolvedId
        local category = getSelectedCategory()
        if category then
            selectedCategoryBaseline = normalizeCategoryState(category)
        else
            selectedCategoryBaseline = nil
        end
        refreshSelectedCategoryControls()
        AddonNS.QueueContainerUpdateItemLayout()
    end

    containerFrame:SetScript("OnShow", function()
        setSelectedCategoryById(selectedCategoryId)
    end)

    containerFrame:SetScript("OnHide", function()
        selectedCategoryId = nil
        selectedCategoryBaseline = nil
        refreshSelectedCategoryControls()
        queryEditorFocused = false
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, false)
        AddonNS.QueueContainerUpdateItemLayout()
    end)

    refreshSelectedCategoryControls()







    -- popup definition
    StaticPopupDialogs["CREATE_CATEGORY_CONFIRM"] = {
        text = "Enter the name of the new category:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self)
            local categoryName = self:GetEditBox():GetText()
            if categoryName and categoryName ~= "" then
                local category = AddonNS.CustomCategories:NewCategory(categoryName)
                if category and containerFrame:IsShown() then
                    setSelectedCategoryById(category:GetId())
                end
            end
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
        EditBoxOnEnterPressed = function(self)
            self:GetParent():GetButton1():Click();
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide();
            ClearCursor();
        end
    }
    StaticPopupDialogs["CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM"] = {
        text = "If you exit now you will lose any unsaved changes.\nHow would you like to proceed?",
        button1 = "Save and Exit",
        button2 = "Exit",
        OnAccept = function()
            local didSave = saveSelectedCategoryDraft()
            if not didSave then
                return
            end
            local callback = pendingCloseAfterSave
            pendingCloseAfterSave = nil
            pendingCloseDiscard = nil
            closeCategoryEditorNow(callback)
        end,
        OnCancel = function()
            local callback = pendingCloseDiscard
            pendingCloseAfterSave = nil
            pendingCloseDiscard = nil
            closeCategoryEditorNow(callback)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
    StaticPopupDialogs["DELETE_CATEGORY_CONFIRM"] = {
        text = "Please confirm you want to remove \"%s\" category.",
        button1 = "Confirm deletion",
        button2 = "Cancel",
        OnAccept = function(self, data)
            local deletedCategoryId = data and data.GetId and data:GetId() or nil
            AddonNS.CustomCategories:DeleteCategory(data);
            if deletedCategoryId and getSelectedCategoryId() == deletedCategoryId then
                setSelectedCategoryById(nil)
            else
                refreshSelectedCategoryControls()
                AddonNS.QueueContainerUpdateItemLayout();
            end
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
    }
    StaticPopupDialogs["IMPORT_CATEGORIES_CONFIRM"] = {
        text = "Import will create %s categories. Continue?",
        button1 = "Apply Import",
        button2 = "Cancel",
        OnAccept = function(self, data)
            local preview = data or self.data
            local ok = pcall(function()
                AddonNS.CustomCategories:ApplyImportPreview(preview)
            end)
            if not ok then
                return
            end
            refreshSelectedCategoryControls()
            AddonNS.QueueContainerUpdateItemLayout()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    function AddonNS.CategoriesGUI:SelectCategoryById(categoryId)
        if not containerFrame:IsShown() then
            containerFrame:Show()
        end
        setSelectedCategoryById(categoryId)
    end

    function AddonNS.CategoriesGUI:ClearSelection()
        setSelectedCategoryById(nil)
    end

    function AddonNS.CategoriesGUI:IsShown()
        return containerFrame:IsShown()
    end

    function AddonNS.CategoriesGUI:GetSelectedCategoryId()
        return getSelectedCategoryId()
    end

    function AddonNS.CategoriesGUI:ToggleExportFrame()
        toggleExportFrame()
    end

    function AddonNS.CategoriesGUI:ToggleImportFrame()
        toggleImportFrame()
    end

    function AddonNS.CategoriesGUI:ToggleQueryHelpFrame(anchorFrame, preferredSide)
        toggleQueryHelpFrame(anchorFrame, preferredSide)
    end

    function AddonNS.CategoriesGUI:HideQueryHelpFrame()
        hideQueryHelpFrame()
    end

    function AddonNS.CategoriesGUI:IsQueryEditorFocused()
        return queryEditorFocused
    end

    function AddonNS.CategoriesGUI:IsQueryEditorLockRequested()
        if queryEditorFocused then
            return true
        end
        if not containerFrame:IsShown() then
            return false
        end
        return (queryEditBox:GetText() or "") ~= ""
    end
end

AddonNS.createGUI()
