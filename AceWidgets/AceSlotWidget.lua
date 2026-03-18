local E = unpack(ElvUI)
local T = unpack(TwichRx)

local AceGUI = LibStub("AceGUI-3.0")

-- Visual constants for the gear slot widget
local SLOT_WIDTH = 270
local SLOT_HEIGHT = 44
local ICON_SIZE = 36

local ACEGUI_GEAR_SLOT_TYPE = "TwichUI_GearSlot"

local Type, Version = ACEGUI_GEAR_SLOT_TYPE, 1

local DEFAULT_DETAILS_TEXT = "Select an item..."

---@return BestInSlotModule
local function GetBISModule()
    return T:GetModule("BestInSlot")
end

---Builds the Gear Slot AceGUI Widget.
---@return AceGUIWidget
local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()

    frame:SetSize(SLOT_WIDTH, SLOT_HEIGHT)

    -- icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", frame, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(unpack(E.TexCoords))
    frame.Icon = icon

    -- icon Border
    frame.IconBorder = frame:CreateTexture(nil, "OVERLAY")
    frame.IconBorder:SetAllPoints(frame.Icon)
    frame.IconBorder:SetColorTexture(0, 0, 0, 0)

    -- name
    frame.Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Name:SetPoint("LEFT", frame.Icon, "RIGHT", 8, 3)
    frame.Name:SetJustifyH("LEFT")

    -- details
    frame.Details = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Details:SetPoint("BOTTOMLEFT", frame.Icon, "BOTTOMRIGHT", 8, 0)
    frame.Details:SetText(DEFAULT_DETAILS_TEXT)
    frame.Details:SetTextColor(0.5, 0.5, 0.5)
    frame.Details:SetJustifyH("LEFT")

    -- clear button (red x)
    frame.ClearButton = CreateFrame("Button", nil, frame)
    frame.ClearButton:SetSize(16, 16)
    frame.ClearButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame.ClearButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    frame.ClearButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
    frame.ClearButton:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
    frame.ClearButton:Hide()

    -- checkmark (gear is owned)
    frame.Check = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    frame.Check:SetSize(16, 16)
    frame.Check:SetPoint("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", 2, -2)
    frame.Check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    frame.Check:Hide()

    -- apply the elvui template
    frame:SetTemplate("Transparent")

    frame:SetScript("OnEnter", function(self)
        -- change border to elvui value color
        self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))

        -- show tooltip if this slot has a selected item
        local obj = self.obj
        if not obj or not obj.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        local BIS = GetBISModule()
        if BIS and BIS.ItemScanner and BIS.ItemScanner.PlayerOwnsItem then
            local owned, _, _, link = BIS.ItemScanner.PlayerOwnsItem(obj.itemID)
            if owned and link then
                GameTooltip:SetHyperlink(link)
            else
                GameTooltip:SetItemByID(obj.itemID)
            end
        else
            GameTooltip:SetItemByID(obj.itemID)
        end

        GameTooltip:Show()
        self.ClearButton:Show()
    end)

    frame:SetScript("OnLeave", function(self)
        -- hide tooltip and change border color back to the default
        GameTooltip:Hide()
        self:SetBackdropBorderColor(unpack(E.media.bordercolor))

        if not self.ClearButton:IsMouseOver() then
            self.ClearButton:Hide()
        end
    end)

    frame:SetScript("OnClick", function(self)
        -- When a slot is clicked, replace the current tab
        -- contents with the gear search view.
        local BIS = GetBISModule()
        if not BIS or not BIS.Frame or not BIS.Frame.Tabs or not BIS.Frame.Tabs.GearSearch then
            return
        end

        local BISFrame = BIS.Frame
        local container = self.RootContainer or (self.obj and self.obj.RootContainer)
        local slotData = self.SlotData or (self.obj and self.obj.SlotData)
        if not container or not slotData then
            return
        end

        container:ReleaseChildren()
        BISFrame.Tabs.GearSearch:Create(container, slotData)
    end)

    -- clear button scripts (independent of slot data)
    frame.ClearButton:SetScript("OnClick", function(self)
        local button = self:GetParent()

        -- clear the stored best-in-slot selection for this slot
        local BIS = GetBISModule()
        if BIS and button.slotID then
            local db = BIS.GetBestInSlotItemDB and BIS.GetBestInSlotItemDB()
            if db then
                db[button.slotID] = nil
            end
        end

        -- hide the clear button and any tooltip
        self:Hide()
        GameTooltip:Hide()
        if button.Check then
            button.Check:Hide()
        end

        -- refresh the slot display using the widget instance
        if button.obj and button.SlotData and button.obj.SetSlotData then
            button.obj:SetSlotData(button.SlotData)
        end
    end)

    frame.ClearButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear Slot", 1, 1, 1)
        GameTooltip:Show()
    end)

    frame.ClearButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not self:GetParent():IsMouseOver() then
            self:Hide()
        end
    end)

    local widget = {}
    widget.type = Type
    widget.frame = frame
    frame.obj = widget

    local methods = {}

    ---Called when AceGUI acquires this widget for (re)use.
    function methods:OnAcquire()
        self:SetWidth(SLOT_WIDTH)
        self:SetHeight(SLOT_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        -- reset per-use state when AceGUI reuses this widget
        self.itemID = nil
        if self.frame and self.frame.Check then
            self.frame.Check:Hide()
        end
    end

    ---Called when the widget is released back to the pool.
    function methods:OnRelease()
        self:SetSlotData(nil)
        self.RootContainer = nil
        self.SlotData = nil
        self.frame:ClearAllPoints()
        self.frame:Hide()
        if self.frame and self.frame.Check then
            self.frame.Check:Hide()
        end
    end

    ---Assign the root container AceGUI widget that hosts this slot.
    ---@param container AceGUIWidget
    function methods:SetRootContainer(container)
        -- store on both the widget and the underlying frame so
        -- the OnClick script (which receives the frame as self)
        -- can find it reliably
        self.RootContainer = container
        if self.frame then
            self.frame.RootContainer = container
        end
    end

    ---Populate/reset the slot display based on the provided data.
    ---@param slotData SlotData|nil
    function methods:SetSlotData(slotData)
        if not slotData then
            if self.frame then
                self.frame.slotID = nil
                self.frame.slotName = nil
                self.frame.defaultTexture = nil
                self.frame.Icon:SetTexture(nil)
                self.frame.Name:SetText(nil)
                self.frame.Name:SetTextColor(1, 1, 1)
                self.frame.Details:SetText(DEFAULT_DETAILS_TEXT)
                self.frame.Details:SetTextColor(0.5, 0.5, 0.5)
            end
            self.itemID = nil
            if self.frame.Check then
                self.frame.Check:Hide()
            end
            return
        end

        if not self.frame then
            return
        end

        self.frame.slotID = slotData.slotID
        self.frame.slotName = slotData.name

        -- look itself up to see if something is selected
        ---@type BestInSlotModule
        local BIS = T:GetModule("BestInSlot")
        local db = BIS.GetBestInSlotItemDB()
        local itemData = db and db[slotData.slotID]

        -- No selected item: show the base slot icon & name
        if not itemData or not itemData.itemID then
            self.frame.defaultTexture = slotData.texture
            self.frame.Icon:SetTexture(slotData.texture)
            self.frame.Icon:SetDesaturated(false)
            self.frame.Name:SetText(slotData.name)
            self.frame.Name:SetTextColor(1, 1, 1)
            self.frame.Details:SetText(DEFAULT_DETAILS_TEXT)
            self.frame.Details:SetTextColor(0.5, 0.5, 0.5)
            self.itemID = nil
            if self.frame.Check then
                self.frame.Check:Hide()
            end
        else
            --- an item is selected for this slot; populate similar to AceItemWidget
            local itemID = itemData.itemID
            self.itemID = itemID

            local function ApplyItemInfo()
                -- Prefer the exact owned instance (equipped or in bags) if available
                local owned, equipped, ilvl, link = false, false, nil, nil
                if BIS.ItemScanner and BIS.ItemScanner.PlayerOwnsItem then
                    owned, equipped, ilvl, link = BIS.ItemScanner.PlayerOwnsItem(itemID)
                end
                local infoToken = link or itemID

                local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(infoToken)
                if not itemName then return end

                self.frame.Icon:SetTexture(itemTexture or slotData.texture)
                self.frame.Icon:SetDesaturated(false)

                local r, g, b = 1, 1, 1
                if itemQuality then
                    r, g, b = C_Item.GetItemQualityColor(itemQuality)
                end
                self.frame.Name:SetText(itemName)
                self.frame.Name:SetTextColor(r, g, b)

                if itemData.sourceInstance then
                    self.frame.Details:SetText(itemData.sourceInstance)
                    self.frame.Details:SetTextColor(0.8, 0.8, 0.8)
                else
                    self.frame.Details:SetText("Selected Best in Slot")
                    self.frame.Details:SetTextColor(0.5, 0.8, 1)
                end

                -- show the checkmark and instance-specific text if the player owns this item
                if owned then
                    self.frame.Check:Show()
                    if ilvl then
                        if equipped then
                            self.frame.Details:SetText("iLvl: " .. ilvl .. " (Equipped)")
                        else
                            self.frame.Details:SetText("iLvl: " .. ilvl .. " (In Bags)")
                        end
                        self.frame.Details:SetTextColor(0, 1, 0) -- color it green
                    end
                else
                    self.frame.Check:Hide()
                end
            end

            -- Try immediate info first
            ApplyItemInfo()

            -- If not yet cached, ensure we update when it becomes available
            if not C_Item.GetItemInfo(itemID) and Item and Item.CreateFromItemID then
                local item = Item:CreateFromItemID(itemID)
                item:ContinueOnItemLoad(function()
                    if self.itemID == itemID then
                        ApplyItemInfo()
                    end
                end)
            end
        end

        self.SlotData = slotData
        if self.frame then
            self.frame.SlotData = slotData
        end
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
