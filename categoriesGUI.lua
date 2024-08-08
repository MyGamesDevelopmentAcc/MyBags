local addonName, AddonNS = ...
local GS = LibStub("MyLibrary_GUI");

--- @type WowList
local WowList = LibStub("WowList-1.5");

function AddonNS.createGUI()
    local container = AddonNS.container;

    local containerFrame = GS:CreateButtonFrame(addonName, 360, 500);
    containerFrame:SetPoint("TOPRIGHT", container, "TOPLEFT", 0, -30);
    containerFrame:EnableMouse(true)
    containerFrame:Hide();

    local editButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    
    editButton:SetPoint("TOPRIGHT",  BagItemAutoSortButton, "TOPLEFT", -4, 0);

    editButton:SetSize(60, 23)
    editButton:SetText("Edit")

    editButton:SetScript("OnClick", function(self, button)
        if containerFrame:IsShown() then containerFrame:Hide() else containerFrame:Show() end
    end)

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
    newButton:SetPoint("BOTTOMLEFT", containerFrame,
        "BOTTOMLEFT", 10, 4);

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


    renameButton:Disable()
    deleteButton:Disable()
    list:RegisterCallback("SelectionChanged", function()
        if list:GetSelected() then
            renameButton:Enable()
            deleteButton:Enable()
        else
            renameButton:Disable()
            deleteButton:Disable()
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
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
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
            self.editBox:SetText(list:GetSelected()[1][1])
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
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
            if list:GetSelected() then
                renameButton:Enable()
                deleteButton:Enable()
            else
                renameButton:Disable()
                deleteButton:Disable()
            end
        end,
        OnShow = function(self, data)
            self.editBox:SetText(list:GetSelected()[1][1])
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
    }
end

AddonNS.createGUI()
