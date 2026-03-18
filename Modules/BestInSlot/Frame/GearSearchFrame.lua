local E = unpack(ElvUI)
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

local AceGUI = LibStub("AceGUI-3.0")

--- @type BestInSlotFrame
local BISFrame = BIS.Frame

---@class GearSearchFrame
---@field Buttons table<string, AceGUIWidget>
---@field ItemWidgetCache table<integer, AceGUIWidget>|nil
---@field Selected BisItem|nil
---@field SlotData SlotData|nil
---@field ItemGroup AceGUIWidget|nil
---@field SelectedItemWidget AceGUIWidget|nil
---@field FilteredItems table<string, integer[]>|nil
---@field Create fun(self: GearSearchFrame, container: AceGUIWidget, slotData: SlotData)
---@field CreateSourceFrame fun(self: GearSearchFrame, container: AceGUIWidget)
---@field PopulateItems fun(self: GearSearchFrame, instance: string)
---@field Select fun(self: GearSearchFrame, itemID: integer)
---@field Filter fun(self: GearSearchFrame)
---@class GearSearchFrame
---@field Buttons table<String, AceGUIWidget>
---@field ItemWidgetCache table<integer, AceGUIWidget>
---@field Selected BisItem|nil
local Tab = BISFrame.Tabs.GearSearch or {}
BISFrame.Tabs.GearSearch = Tab
Tab.Buttons = {}

---@type table<string, table<integer, boolean>>
local EQUIP_TO_SLOTS = {
    INVTYPE_HEAD           = { [1] = true },
    INVTYPE_NECK           = { [2] = true },
    INVTYPE_SHOULDER       = { [3] = true },
    INVTYPE_CLOAK          = { [15] = true },
    INVTYPE_CHEST          = { [5] = true },
    INVTYPE_ROBE           = { [5] = true },
    INVTYPE_WRIST          = { [9] = true },
    INVTYPE_HAND           = { [10] = true },
    INVTYPE_WAIST          = { [6] = true },
    INVTYPE_LEGS           = { [7] = true },
    INVTYPE_FEET           = { [8] = true },

    INVTYPE_FINGER         = { [11] = true, [12] = true },
    INVTYPE_TRINKET        = { [13] = true, [14] = true },

    -- Weapons
    INVTYPE_WEAPON         = { [16] = true, [17] = true }, -- 1H that can go in either hand
    INVTYPE_WEAPONMAINHAND = { [16] = true },
    INVTYPE_WEAPONOFFHAND  = { [17] = true },
    INVTYPE_2HWEAPON       = { [16] = true },
    INVTYPE_RANGED         = { [16] = true },
    INVTYPE_RANGEDRIGHT    = { [16] = true },
    INVTYPE_THROWN         = { [16] = true },
    INVTYPE_SHIELD         = { [17] = true },
    INVTYPE_HOLDABLE       = { [17] = true }, -- off-hand frills
}

---Check if an item can be equipped in a given character slot.
---@param itemID integer|nil
---@param slotID integer|nil
---@return boolean fits
local function ItemFitsSlot(itemID, slotID)
    if not itemID or not slotID then return false end

    local _, _, _, itemEquipLoc = C_Item.GetItemInfoInstant(itemID)
    if not itemEquipLoc or itemEquipLoc == "" then return false end

    local allowedSlots = EQUIP_TO_SLOTS[itemEquipLoc]
    if not allowedSlots then return false end

    return not not allowedSlots[slotID]
end

---Populate the item list for a specific content source (instance).
---@param instance string
function Tab:PopulateItems(instance)
    if not self.ItemGroup then return end
    self.ItemGroup:ReleaseChildren()
    self.ItemGroupParent:SetTitle("Items")

    local items = (self.FilteredItems and self.FilteredItems[instance]) or {}

    for _, itemID in ipairs(items) do
        -- ensure only items for the selected slot show up
        local itemWidget = AceGUI:Create("TwichUI_Item")
        itemWidget:SetItem(itemID)

        -- capture the current itemID so each widget has its own stable callback
        local thisItemID = itemID
        itemWidget:ClickCallback(function()
            self:Select(thisItemID)
        end)
        self.ItemGroup:AddChild(itemWidget)
    end
end

--- Overtakes the item group to add a configuration UI for a custom item.
function Tab:ShowCustomItemConfig()
    if not self.ItemGroup then return end
    self.ItemGroup:ReleaseChildren()
    self.ItemGroupParent:SetTitle("Custom Item Configuration")

    local font = T.Tools.Text.GetElvUIFont()

    -- title
    local label = AceGUI:Create("Label")
    label:SetText(T.Tools.Text.Color(T.Tools.Colors.PRIMARY, "Add a Custom Item"))
    label:SetFullWidth(true)
    label:SetFont(font, 14, "")
    self.ItemGroup:AddChild(label)

    -- vertical spacer between the title and the search group
    local titleSpacer = AceGUI:Create("Label")
    titleSpacer:SetText(" ")
    titleSpacer:SetFullWidth(true)
    titleSpacer:SetHeight(6)
    self.ItemGroup:AddChild(titleSpacer)

    -- item search group
    local itemSearchGroup = AceGUI:Create("InlineGroup")
    itemSearchGroup:SetTitle("Item Search")
    itemSearchGroup:SetFullWidth(true)
    itemSearchGroup:SetLayout("List")
    self.ItemGroup:AddChild(itemSearchGroup)

    -- description
    local desc = AceGUI:Create("Label")
    desc:SetText(
        "Any item in the game can be added. Use the box below to enter an item's name, WowHead link, or ID (most reliable).")
    desc:SetFullWidth(true)
    desc:SetFont(font, 12, "")
    itemSearchGroup:AddChild(desc)

    -- input box
    local input = AceGUI:Create("EditBox")
    input:SetLabel("Item Name, WowHead Link, or ID:")
    input:SetFocus()
    input:SetFullWidth(true)
    itemSearchGroup:AddChild(input)

    -- feedback spacer
    local feedbackSpacer = AceGUI:Create("Label")
    feedbackSpacer:SetText(" ")
    feedbackSpacer:SetFullWidth(true)
    feedbackSpacer:SetHeight(2)
    itemSearchGroup:AddChild(feedbackSpacer)

    -- feedback label
    local feedback = AceGUI:Create("Label")
    feedback:SetText("")
    feedback:SetFullWidth(true)
    feedback:SetFont(font, 12, "")
    feedback:SetHeight(10)
    itemSearchGroup:AddChild(feedback)

    -- source entry
    local sourceGroup = AceGUI:Create("InlineGroup")
    sourceGroup:SetTitle("Source")
    sourceGroup:SetFullWidth(true)
    sourceGroup:SetLayout("List")
    self.ItemGroup:AddChild(sourceGroup)
    local sourceLabel = AceGUI:Create("Label")
    sourceLabel:SetText(
        "You can optionally set the source of the item, which will appear in the gear tracker underneath the item.")
    sourceLabel:SetFullWidth(true)
    sourceLabel:SetFont(font, 12, "")
    sourceGroup:AddChild(sourceLabel)

    local sourceInput = AceGUI:Create("EditBox")
    sourceInput:SetLabel("Item Source:")
    sourceInput:SetFullWidth(true)
    sourceInput:SetText(self.Selected and self.Selected.sourceInstance or "Custom")
    sourceInput:SetCallback("OnEnterPressed", function(_, _, rawText)
        local text = tostring(rawText or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if not self.Selected then
            self.Selected = { slotID = self.SlotData.slotID, itemID = nil, sourceInstance = nil }
        end
        self.Selected.sourceInstance = text

        -- persist to DB
        if self.Selected and self.Selected.itemID then
            local db = BIS:GetBestInSlotItemDB()
            db[self.SlotData.slotID] = self.Selected
        end
    end)
    sourceGroup:AddChild(sourceInput)

    local function SetFeedbackMessage(message, isError, isWarn)
        if isError then
            feedback:SetText(T.Tools.Text.Color(T.Tools.Colors.RED, message))
        elseif isWarn then
            feedback:SetText(T.Tools.Text.Color(T.Tools.Colors.WARNING, message))
        else
            feedback:SetText(T.Tools.Text.Color(T.Tools.Colors.PRIMARY, message))
        end
        itemSearchGroup:DoLayout()
    end

    -- When the player presses Enter in the custom item box, resolve the text
    -- into an item ID, validate it against the current slot, and save it as
    -- the selected Best-in-Slot item.
    input:SetCallback("OnEnterPressed", function(_, _, rawText)
        local text = tostring(rawText or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then
            SetFeedbackMessage("Please enter an item ID, WowHead link, or item name.", true)
            return
        end

        -- Try to extract an itemID from common WowHead link formats first.
        local itemID
        local fromLink = text:match("item=(%d+)")
        if fromLink then
            itemID = tonumber(fromLink)
        else
            -- Pure numeric input => item ID.
            local numeric = tonumber(text)
            if numeric then
                itemID = numeric
            else
                -- Fallback: treat as an item name and resolve via GetItemInfo.
                local _, itemLink = C_Item.GetItemInfo(text)
                if itemLink then
                    local idFromLink = itemLink:match("item:(%d+)")
                    if idFromLink then
                        itemID = tonumber(idFromLink)
                    end
                end
            end
        end

        if not itemID then
            SetFeedbackMessage("Could not resolve an item from: " .. text, true)
            return
        end

        if not self.SlotData or not self.SlotData.slotID then
            SetFeedbackMessage("Unable to assign a custom item: missing slot data.", true)
            return
        end

        -- Ensure the item is appropriate for this slot.
        if not ItemFitsSlot(itemID, self.SlotData.slotID) then
            SetFeedbackMessage("That item does not fit the " .. (self.SlotData.name or "selected") .. " slot.", false,
                true)
            return
        end

        -- Persist selection in the Best-in-Slot DB.
        local selected = self.Selected or { slotID = self.SlotData.slotID, sourceInstance = nil, itemID = nil }
        selected.itemID = itemID
        selected.sourceInstance = "Custom"
        self.Selected = selected

        local db = BIS:GetBestInSlotItemDB()
        db[self.SlotData.slotID] = selected

        -- Update the SelectedItemWidget display if present.
        if self.SelectedItemWidget and self.SelectedItemWidget.SetItem then
            self.SelectedItemWidget:SetItem(itemID)
        end

        -- Provide user feedback and clear the box.
        local name, link = C_Item.GetItemInfo(itemID) -- preload item info
        -- we do not always immediately get a link
        if link then
            SetFeedbackMessage("Custom Best in Slot item set to " .. link, false)
        else
            SetFeedbackMessage("Custom Best in Slot item set.", false)
        end
        input:SetText("")
    end)
end

---Create the left-hand source (instance) list.
---@param container AceGUIWidget
function Tab:CreateSourceFrame(container)
    local function CreateSourceButton(instanceName)
        local button = AceGUI:Create("Button")
        button:SetText(instanceName)
        button:SetWidth(175)
        button:SetCallback("OnClick", function()
            if not self.Selected then return end
            self:PopulateItems(instanceName)
            self.Selected.sourceInstance = instanceName
        end)
        return button
    end

    local cache = BIS.GetItemCache() or {}
    local instanceLoot = cache.InstanceLoot or {}

    -- collect and sort instance names
    local instanceNames = {}
    for instanceName in pairs(instanceLoot) do
        table.insert(instanceNames, instanceName)
    end
    table.sort(instanceNames)

    -- create buttons in alpha order
    for _, instanceName in ipairs(instanceNames) do
        local button = CreateSourceButton(instanceName)
        container:AddChild(button)
        self.Buttons[instanceName] = button
    end

    -- add a small spacer at the bottom so the last button doesnt clip
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetHeight(1)
    container:AddChild(spacer)
end

---Persist and visually update the currently selected Best-in-Slot item.
---@param itemID integer
function Tab:Select(itemID)
    -- update selected data first, then refresh the visual widget with the new item
    if not self.Selected or not self.SlotData then return end

    self.Selected.itemID = itemID
    BIS:GetBestInSlotItemDB()[self.SlotData.slotID] = self.Selected

    if self.SelectedItemWidget then
        self.SelectedItemWidget:SetItem(itemID)
    end
end

---Build the Gear Search UI inside the provided container.
---@param container AceGUIWidget
---@param slotData SlotData
function Tab:Create(container, slotData)
    self.Selected = BIS:GetBestInSlotItemDB()[slotData.slotID] or
        { itemID = nil, slotID = slotData.slotID, sourceInstance = nil }
    self.SlotData = slotData

    container:SetLayout("Fill")

    local rootGroup = AceGUI:Create("SimpleGroup")
    rootGroup:SetFullWidth(true)
    rootGroup:SetFullHeight(true)
    rootGroup:SetLayout("List")
    container:AddChild(rootGroup)

    -- header
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Fill")
    rootGroup:AddChild(headerGroup)
    local headerLabel = AceGUI:Create("Label")
    headerLabel:SetText("Select Best in Slot item for " ..
        (slotData and slotData.name or "Unknown Slot") .. ". Item level does not matter.")
    headerLabel:SetFullWidth(true)

    local font = T.Tools.Text.GetElvUIFont()
    headerLabel:SetFont(font, 12, "OUTLINE")
    headerGroup:AddChild(headerLabel)

    -- central content area between header and footer
    local contentGroup = AceGUI:Create("SimpleGroup")
    contentGroup:SetFullWidth(true)
    contentGroup:SetFullHeight(true)
    contentGroup:SetLayout("Fill")
    rootGroup:AddChild(contentGroup)

    -- Row group that contains the two columns side by side
    local rowGroup = AceGUI:Create("SimpleGroup")
    rowGroup:SetFullWidth(true)
    rowGroup:SetFullHeight(true)
    rowGroup:SetLayout("Flow")
    contentGroup:AddChild(rowGroup)

    -- Left column
    local sourceGroup = AceGUI:Create("InlineGroup")
    sourceGroup:SetTitle("Source")
    sourceGroup:SetFullWidth(false)
    sourceGroup:SetFullHeight(true)
    sourceGroup:SetLayout("Fill")
    rowGroup:AddChild(sourceGroup)

    local leftScroll = AceGUI:Create("ScrollFrame")
    leftScroll:SetFullWidth(true)
    leftScroll:SetFullHeight(true)
    sourceGroup:AddChild(leftScroll)
    self:CreateSourceFrame(leftScroll)

    -- Right column
    local itemGroup = AceGUI:Create("InlineGroup")
    itemGroup:SetTitle("Items")
    itemGroup:SetFullWidth(false)
    itemGroup:SetFullHeight(true)
    itemGroup:SetLayout("Fill")
    self.ItemGroupParent = itemGroup
    rowGroup:AddChild(itemGroup)

    local rightScroll = AceGUI:Create("ScrollFrame")
    rightScroll:SetFullWidth(true)
    rightScroll:SetFullHeight(true)
    itemGroup:AddChild(rightScroll)
    self.ItemGroup = rightScroll


    -- footer group pinned to the bottom of the tab
    local footerGroup = AceGUI:Create("SimpleGroup")
    footerGroup:SetFullWidth(true)
    -- we'll position children manually
    footerGroup:SetLayout("None")
    footerGroup:SetHeight(45)
    rootGroup:AddChild(footerGroup)

    -- back button
    local backButton = AceGUI:Create("Button")
    backButton:SetText("Back")
    backButton:SetFullWidth(false)
    backButton:SetWidth(100)
    backButton:SetCallback("OnClick", function()
        -- Restore the regular gear selector view inside
        -- this same tab container.
        BISFrame:SelectGroup(container, nil, "gearSelector")
    end)
    footerGroup:AddChild(backButton)

    -- custom item button
    local customItemButton = AceGUI:Create("Button")
    customItemButton:SetText(T.Tools.Text.Color(T.Tools.Colors.PRIMARY, "Custom Item"))
    customItemButton:SetFullWidth(false)
    customItemButton:SetWidth(120)
    customItemButton:SetCallback("OnClick", function()
        self:ShowCustomItemConfig()
    end)
    footerGroup:AddChild(customItemButton)

    -- selected container (will be sized/positioned in ResizeFooter)
    local selectedContainer = AceGUI:Create("SimpleGroup")
    selectedContainer:SetFullWidth(false)
    selectedContainer:SetLayout("None")
    footerGroup:AddChild(selectedContainer)

    local selectedLabel = AceGUI:Create("Label")
    selectedLabel:SetText("Selected Item:  ")
    selectedLabel:SetFullWidth(false)
    selectedLabel:SetJustifyH("RIGHT")
    selectedContainer:AddChild(selectedLabel)

    self.SelectedItemWidget = AceGUI:Create("TwichUI_Item")
    self.SelectedItemWidget:SetItem(self.Selected.itemID)
    self.SelectedItemWidget:SetFullWidth(false)
    self.SelectedItemWidget:SetWidth(240)
    -- Selected item display should not change selection when clicked; ensure it has no-op click
    if self.SelectedItemWidget.ClickCallback then
        self.SelectedItemWidget:ClickCallback(function() end)
    end
    selectedContainer:AddChild(self.SelectedItemWidget)

    local frame = container.content or container.frame
    local isResizing = false

    local function ResizeContent()
        if not (frame and frame:IsShown()) then return end

        -- Vertically: make the central content area fill the space between
        -- header and footer.
        local totalH = frame:GetHeight() or 0
        local headerH = headerGroup.frame:GetHeight() or 0
        local footerH = footerGroup.frame:GetHeight() or 0
        local newH = totalH - headerH - footerH
        if newH > 0 then
            contentGroup.frame:SetHeight(newH)
            rowGroup.frame:SetHeight(newH)
            sourceGroup.frame:SetHeight(newH)
            itemGroup.frame:SetHeight(newH)
        end

        -- Horizontally: left column fixed to fit its button text contents,
        -- right column fills remaining space in the row.
        local rowW = rowGroup.frame:GetWidth() or 0
        if rowW > 0 then
            -- measure widest text in the source column buttons (inside leftScroll)
            local maxTextWidth = 0
            for _, child in ipairs(leftScroll.children or {}) do
                if child.text and child.text.GetStringWidth then
                    local w = child.text:GetStringWidth()
                    if w > maxTextWidth then
                        maxTextWidth = w
                    end
                end
            end

            -- add ample padding for button borders (ca 20px) + scrollbar/frame padding (ca 25px)
            local leftW = maxTextWidth + 40

            -- Clamp so we don't take over the whole screen if text is weirdly long
            local maxLeft = rowW * 0.4
            if leftW > maxLeft then
                leftW = maxLeft
            end

            -- Minimum width to avoid collapse
            if leftW < 100 then leftW = 100 end

            if leftW > 0 and rowW > leftW + 10 then
                sourceGroup.frame:SetWidth(leftW)
                -- subtract left width and a small margin for the Flow layout gap
                itemGroup.frame:SetWidth(rowW - leftW)
            end
        end
    end

    local function ResizeFooter()
        if not (footerGroup and footerGroup.frame and footerGroup.frame:IsShown()) then return end

        local footerFrame = footerGroup.frame
        local totalW = footerFrame:GetWidth() or 0
        local backW = backButton.frame:GetWidth() or 0
        local customW = (customItemButton and customItemButton.frame and customItemButton.frame:GetWidth()) or 0
        local gap = 8

        -- position back button on the left
        backButton.frame:ClearAllPoints()
        backButton.frame:SetPoint("LEFT", footerFrame, "LEFT", 0, 0)

        -- position custom item button just to the right of Back
        if customItemButton and customItemButton.frame then
            customItemButton.frame:ClearAllPoints()
            customItemButton.frame:SetPoint("LEFT", backButton.frame, "RIGHT", gap, 0)
        end

        -- selected container fills remaining space to the right
        local containerW = totalW - backW - customW - (2 * gap)
        if containerW < 0 then containerW = 0 end

        local scFrame = selectedContainer.frame
        scFrame:ClearAllPoints()
        scFrame:SetWidth(containerW)

        -- Anchor the selected container to the buttons instead of the footer
        -- frame itself to avoid circular anchor dependencies.
        if customItemButton and customItemButton.frame then
            scFrame:SetPoint("LEFT", customItemButton.frame, "RIGHT", gap, 0)
        else
            scFrame:SetPoint("LEFT", backButton.frame, "RIGHT", gap, 0)
        end

        -- inside the selected container, right-align the item widget
        local itemFrame = self.SelectedItemWidget and self.SelectedItemWidget.frame
        local labelFrame = selectedLabel and selectedLabel.frame
        if itemFrame and labelFrame then
            itemFrame:ClearAllPoints()
            itemFrame:SetPoint("RIGHT", scFrame, "RIGHT", 0, 0)

            labelFrame:ClearAllPoints()
            labelFrame:SetPoint("RIGHT", itemFrame, "LEFT", -4, 0)
        end
    end

    -- Hook into size changes, but protect against recursive calls from
    -- SetHeight/SetWidth by using a simple reentrancy guard.
    if frame and frame.HookScript then
        frame:HookScript("OnSizeChanged", function()
            if isResizing then return end
            isResizing = true
            ResizeContent()
            ResizeFooter()
            isResizing = false
        end)
    end

    self:Filter()
    ResizeContent()
    ResizeFooter()
end

---Filter all cached items down to those valid for the current slot,
---and enable/disable instance buttons accordingly.
function Tab:Filter()
    if not self.SlotData then return end

    -- start by assuming all buttons are enabled; we'll disable those without matches
    for _, button in pairs(self.Buttons) do
        if button and button.SetDisabled then
            button:SetDisabled(false)
        end
    end

    local filteredItems = {}
    local cache = BIS.GetItemCache() or {}
    local items = cache.InstanceLoot or {}

    for instance, itemList in pairs(items) do
        local hasItemsForSlot = false

        filteredItems[instance] = filteredItems[instance] or {}

        for _, itemID in ipairs(itemList) do
            if ItemFitsSlot(itemID, self.SlotData.slotID) then
                hasItemsForSlot = true
                table.insert(filteredItems[instance], itemID)
            end
        end

        local button = self.Buttons[instance]
        if button and button.SetDisabled and not hasItemsForSlot then
            button:SetDisabled(true)
        end
    end

    self.FilteredItems = filteredItems
end
