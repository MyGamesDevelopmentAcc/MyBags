local addonName, AddonNS = ...
local GS = LibStub("MyLibrary_GUI");

--- @type WowList
local WowList = LibStub("WowList-1.5");

function AddonNS.createGUI()
    local container = AddonNS.container;

    local containerFrame = GS:CreateButtonFrame(addonName, 360, 580, true);
    containerFrame:SetPoint("TOPRIGHT", container, "TOPLEFT", 0, -30);
    containerFrame:EnableMouse(true)
    containerFrame:Hide();

    local editButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")

    editButton:SetPoint("TOPRIGHT", BagItemAutoSortButton, "TOPLEFT", -4, 0);

    editButton:SetSize(60, 23)
    editButton:SetText("Edit")

    editButton:SetScript("OnClick", function(self, button)
        if containerFrame:IsShown() then containerFrame:Hide() else containerFrame:Show() end
    end)
    containerFrame.Inset:SetPoint("BOTTOMRIGHT", -6, 106)
    containerFrame.categoriesContainer = CreateFrame("Frame", addonName .. "-reagentsContainer", containerFrame)
    local categoriesContainter = containerFrame.categoriesContainer;
    categoriesContainter:SetPoint("TOPLEFT", 16, -65)
    categoriesContainter:SetPoint("BOTTOMRIGHT")

    local list
    do
        categoriesContainter.list = WowList:CreateNew(addonName .. "_categoriesList",

            {
                height = 400, -- Height of the entire list frame
                rows = 20,    -- Number of rows to display
                columns = {
                    {
                        name = "Name",
                        width = 230,
                        sortFunction = function(a, b) return string.lower(a) < string.lower(b) end,
                        displayFunction = function(cellData, rowData, columnIndex, rowIndex)
                            return cellData, { 1, 1, 1, 1 } -- White color
                        end
                    },
                    {
                        name = "Show",
                        width = 90,
                        displayFunction = function(cellData, rowData, columnIndex, rowIndex)
                            return "With items", { 1, 1, 0, 1 } -- Yellow color
                        end,
                    }
                }
            }, categoriesContainter);

        list = categoriesContainter.list;
        list:SetPoint('TOPLEFT', categoriesContainter, 'TOPLEFT', 0, 0);
        list:SetMultiSelection(false);
        list:SetButtonOnMouseDownFunction(
            function(rowData, button)
                AddonNS.DragAndDrop.customCategoryGUIOnMouseUp(rowData[1], button)
            end, true)

        list:SetButtonOnReceiveDragFunction(
            function(rowData)
                AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(rowData[1])
            end)
    end


    function list:RefreshList()
        list:RemoveAll()
        local categories = AddonNS.CustomCategories:GetCategories()
        for key, value in pairs(categories) do
            list:AddData({ key })
        end

        -- workaround start
        local queryCategories = AddonNS.QueryCategories:GetCategories() -- todo: remove this once query is merged with custom.
        for key, value in pairs(queryCategories) do
            if not categories[key] then
                list:AddData({ key })
            end
        end
        -- workaround end

        list:Sort(1, function(a, b)
            return string.lower(a) < string.lower(b)
        end)
        list:UpdateView()
    end

    containerFrame:SetScript("OnShow", function()
        list:RefreshList()
    end)

    -- new button
    local newButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    newButton:SetPoint("TOPLEFT", containerFrame.Inset,
        "BOTTOMLEFT", 0, -6);

    newButton:SetSize(60, 20)
    newButton:SetText("New")

    newButton:SetScript("OnClick", function(self)
        StaticPopup_Show("CREATE_CATEGORY_CONFIRM");
    end)

    --- [[ save button]]
    local renameButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    renameButton:SetPoint("TOPLEFT", newButton, "TOPRIGHT", 5, 0);

    renameButton:SetSize(60, 20)
    renameButton:SetText("Rename")

    renameButton:SetScript("OnClick", function(self, button)
        local data = list:GetSelected()
        local dialog = StaticPopup_Show("RENAME_CATEGORY_CONFIRM", data[1][1]);
        if (dialog) then
            dialog.data = data[1][1];
        end
    end)

    --- [[ delete button]]
    local deleteButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    deleteButton:SetPoint("TOPLEFT", renameButton, "TOPRIGHT", 5, 0);

    deleteButton:SetSize(60, 20)
    deleteButton:SetText("Delete")

    deleteButton:SetScript("OnClick", function(self, button)
        local data = list:GetSelected()
        local dialog = StaticPopup_Show("DELETE_CATEGORY_CONFIRM", data[1][1]);
        if (dialog) then
            dialog.data = data[1][1];
        end
    end)



    local function getSelectedCategoryName()
        return list:GetSelected()[1][1];
    end


    --- [[always show checkbox]]
    -- Create a new frame
    local alwaysShowCheckbox = CreateFrame("CheckButton", nil, containerFrame, "ChatConfigCheckButtonTemplate")

    -- Set the position of the checkbox (parent, anchor, relative to, x offset, y offset)
    alwaysShowCheckbox:SetPoint("LEFT", deleteButton, "RIGHT", 5, 0);

    -- Set the size of the checkbox
    alwaysShowCheckbox:SetSize(30, 30)

    -- Set the label for the checkbox (text next to the checkbox)
    alwaysShowCheckbox.Text:SetText("Always show")

    -- Tooltip for the checkbox
    alwaysShowCheckbox.tooltip =
    "Enabling this will make this category always visible, even when no items currently associated with it."

    -- Function to run when the checkbox is clicked
    alwaysShowCheckbox:SetScript("OnClick", function(self)
        AddonNS.CategorShowAlways:SetAlwaysShow(getSelectedCategoryName(), self:GetChecked())
        RunNextFrame(function()
            container:UpdateItemLayout();
        end);
    end)



    -- [[ GUI - textScrollFrame]]
    --  local function createEditBox(frame, posX, posY, height)
    local textScrollFrame = CreateFrame("ScrollFrame", nil, containerFrame, "InputScrollFrameTemplate")
    textScrollFrame.hideCharCount = true;
    -- textScrollFrame:SetHeight(height)
    textScrollFrame:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 6, -10);
    textScrollFrame:SetPoint("BOTTOMRIGHT", containerFrame, "BOTTOMRIGHT", -10, 30);
    -- textScrollFrame:SetPoint("RIGHT", containerFrame, "RIGHT", -posX, posY);
    -- textScrollFrame:SetPoint("LEFT", containerFrame, "LEFT", -posX, posY);
    local textScrollFrameLoaded = false;

    textScrollFrame:SetScript("OnShow", function()
        if not textScrollFrameLoaded then
            textScrollFrameLoaded = true;
            InputScrollFrame_OnLoad(textScrollFrame);
        end
    end)
    textScrollFrame.EditBox:SetFontObject(NumberFont_Shadow_Tiny)

    containerFrame.textScrollFrame = textScrollFrame
    -- end
    -- containerFrame.textScrollFrame = createEditBox(containerFrame, 25, -60, 60)


    --- [[ saveQueryButton button]]
    local saveQueryButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    saveQueryButton:SetPoint("TOP", containerFrame.textScrollFrame, "BOTTOM", 0, -5);

    saveQueryButton:SetSize(100, 20)
    saveQueryButton:SetText("Save Query")

    saveQueryButton:SetScript("OnClick", function(self, button)
        AddonNS.QueryCategories:SetQuery(getSelectedCategoryName(), containerFrame.textScrollFrame.EditBox:GetText())
        RunNextFrame(function()
            container:UpdateItemLayout();
        end);
    end)


    renameButton:Disable()
    deleteButton:Disable()
    alwaysShowCheckbox:Disable()
    saveQueryButton:Disable()
    list:RegisterCallback("SelectionChanged", function()
        if list:GetSelected() then
            renameButton:Enable()
            alwaysShowCheckbox:Enable()
            alwaysShowCheckbox:SetChecked(AddonNS.CategorShowAlways:ShouldAlwaysShow(getSelectedCategoryName()))
            deleteButton:Enable()
            saveQueryButton:Enable()
            local query = AddonNS.QueryCategories:GetQuery(getSelectedCategoryName())

            containerFrame.textScrollFrame.EditBox:SetText(query);
        else
            alwaysShowCheckbox:SetChecked(false)
            alwaysShowCheckbox:Disable()
            renameButton:Disable()
            deleteButton:Disable()
            saveQueryButton:Disable()
            containerFrame.textScrollFrame.EditBox:SetText("");
        end
    end)







    -- popup definition
    StaticPopupDialogs["CREATE_CATEGORY_CONFIRM"] = {
        text = "Enter the name of the new category:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self)
            local categoryName = self.editBox:GetText()
            if categoryName and categoryName ~= "" then
                AddonNS.CustomCategories:NewCategory(categoryName);
                list:RefreshList();
            else
                AddonNS.printDebug("Please enter a category name.")
            end
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
        EditBoxOnEnterPressed = function(self)
            self:GetParent().button1:Click();
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide();
            ClearCursor();
        end
    }
    StaticPopupDialogs["RENAME_CATEGORY_CONFIRM"] = {
        text = "Enter the new name for \"%s\" category:",
        button1 = "Rename",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self, data)
            local categoryName = self.editBox:GetText()
            if categoryName and categoryName ~= "" then
                AddonNS.printDebug("Category renamed: ", data, categoryName)
                AddonNS.CustomCategories:RenameCategory(data, categoryName);
                -- Add your category creation logic here
                RunNextFrame(function()
                    container:UpdateItemLayout();
                end);
                list:RefreshList();
            else
                AddonNS.printDebug("Please enter a category name.")
            end
        end,
        OnShow = function(self, data)
            self.editBox:SetText(getSelectedCategoryName())
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
        EditBoxOnEnterPressed = function(self)
            self:GetParent().button1:Click();
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide();
            ClearCursor();
        end
    }
    StaticPopupDialogs["DELETE_CATEGORY_CONFIRM"] = {
        text = "Please confirm you want to remove \"%s\" category.",
        button1 = "Confirm deletion",
        button2 = "Cancel",
        OnAccept = function(self, data)
            AddonNS.printDebug("Category deleted: ", data)
            AddonNS.CustomCategories:DeleteCategory(data);
            RunNextFrame(function()
                container:UpdateItemLayout();
            end);
            list:RefreshList();
            if list:GetSelected() then -- todo this is a duplicated code
                renameButton:Enable()
                alwaysShowCheckbox:Enable()
                alwaysShowCheckbox:SetChecked(AddonNS.CategorShowAlways:ShouldAlwaysShow(getSelectedCategoryName()))
                deleteButton:Enable()
                local query = AddonNS.QueryCategories:GetQuery(getSelectedCategoryName())
                containerFrame.textScrollFrame.EditBox:SetText(query);
            else
                alwaysShowCheckbox:SetChecked(false)
                alwaysShowCheckbox:Enable()
                renameButton:Disable()
                deleteButton:Disable()
            end
        end,
        OnShow = function(self, data)
            self.editBox:SetText(getSelectedCategoryName())
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
    }
end

AddonNS.createGUI()
