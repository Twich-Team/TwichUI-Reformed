---@diagnostic disable: undefined-global, return-type-mismatch
local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

local AceGUI = LibStub("AceGUI-3.0")

-- Visual constants for the gear slot widget
local SLOT_WIDTH = 270
local SLOT_HEIGHT = 44
local ICON_SIZE = 36

local ACEGUI_GEAR_SLOT_TYPE = "TwichUI_GearSlot"

local Type, Version = ACEGUI_GEAR_SLOT_TYPE, 1

local DEFAULT_DETAILS_TEXT = "Select an item..."
local DEFAULT_CARD_TEXT = "Curate your chase piece"
local TEX_COORDS = { 0.08, 0.92, 0.08, 0.92 }

local function GetFallbackFont()
    local font = T.Tools and T.Tools.Text and T.Tools.Text.GetElvUIFont and T.Tools.Text.GetElvUIFont()
    if font then
        return font
    end

    local gameFont = _G.GameFontNormal
    return gameFont and select(1, gameFont:GetFont()) or nil
end

---@return BestInSlotModule
local function GetBISModule()
    return T:GetModule("BestInSlot")
end

local function GetWidgetColors()
    local ThemeModule = T:GetModule("Theme", true)
    local accent = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("accentColor") or { 0.95, 0.76, 0.26 }
    local border = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    local bg = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("backgroundColor") or { 0.06, 0.06, 0.08 }
    return accent, border, bg
end

---Builds the Gear Slot AceGUI Widget.
---@return AceGUIWidget
local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:Hide()

    frame:SetSize(SLOT_WIDTH, SLOT_HEIGHT)

    if not frame.LeftAccent then
        frame.LeftAccent = frame:CreateTexture(nil, "ARTWORK")
        frame.LeftAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.LeftAccent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.LeftAccent:SetWidth(3)
    end

    if not frame.InnerGlow then
        frame.InnerGlow = frame:CreateTexture(nil, "ARTWORK")
        frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end

    local iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconFrame:SetPoint("LEFT", frame, "LEFT", 8, 0)
    iconFrame:SetSize(ICON_SIZE + 8, ICON_SIZE + 8)
    if iconFrame.SetTemplate then
        iconFrame:SetTemplate("Transparent")
    end

    -- icon
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    icon:SetTexCoord(unpack(TEX_COORDS))
    frame.Icon = icon
    frame.IconFrame = iconFrame

    -- icon Border
    frame.IconBorder = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    frame.IconBorder:SetAllPoints(iconFrame)
    if frame.IconBorder.SetTemplate then
        frame.IconBorder:SetTemplate("Transparent")
    end

    -- name
    frame.Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Name:SetPoint("LEFT", iconFrame, "RIGHT", 10, 7)
    frame.Name:SetJustifyH("LEFT")
    frame.Name:SetPoint("RIGHT", frame, "RIGHT", -28, 0)

    -- details
    frame.Details = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Details:SetPoint("TOPLEFT", frame.Name, "BOTTOMLEFT", 0, -3)
    frame.Details:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
    frame.Details:SetText(DEFAULT_DETAILS_TEXT)
    frame.Details:SetTextColor(0.5, 0.5, 0.5)
    frame.Details:SetJustifyH("LEFT")

    frame.Badge = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Badge:SetPoint("BOTTOMLEFT", frame.Name, "TOPLEFT", 0, 4)
    frame.Badge:SetJustifyH("LEFT")
    frame.Badge:SetText("")

    local font = GetFallbackFont()
    if font then
        frame.Name:SetFont(font, 12, "")
        frame.Details:SetFont(font, 10, "")
        frame.Badge:SetFont(font, 9, "OUTLINE")
    end

    -- clear button (red x)
    frame.ClearButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.ClearButton:SetSize(18, 18)
    frame.ClearButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame.ClearButton:SetNormalFontObject("GameFontHighlightSmall")
    frame.ClearButton:SetText("x")
    if frame.ClearButton.SetBackdrop then
        frame.ClearButton:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame.ClearButton:SetBackdropColor(0.18, 0.06, 0.06, 0.95)
        frame.ClearButton:SetBackdropBorderColor(0.92, 0.34, 0.28, 0.5)
    end
    frame.ClearButton:Hide()

    -- checkmark (gear is owned)
    frame.Check = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    frame.Check:SetSize(16, 16)
    frame.Check:SetPoint("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", 2, -2)
    frame.Check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    frame.Check:Hide()

    -- apply the elvui template
    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    do
        local accent, border, bg = GetWidgetColors()
        if frame.SetBackdropColor then
            frame:SetBackdropColor(bg[1] * 0.7, bg[2] * 0.72, bg[3] * 0.8, 0.9)
        end
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(border[1], border[2], border[3], 0.28)
        end
        frame.LeftAccent:SetColorTexture(accent[1], accent[2], accent[3], 0.92)
        frame.InnerGlow:SetColorTexture(0, 0, 0, 0)
        frame.Details:SetTextColor(accent[1], accent[2], accent[3], 0.72)
        frame.Badge:SetTextColor(accent[1], accent[2], accent[3], 0.95)
    end

    frame:SetScript("OnEnter", function(self)
        local accent = GetWidgetColors()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.9)
        end
        if self.InnerGlow then
            self.InnerGlow:SetColorTexture(accent[1], accent[2], accent[3], 0.08)
        end

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
        local _, border = GetWidgetColors()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(border[1], border[2], border[3], 0.28)
        end
        if self.InnerGlow then
            self.InnerGlow:SetColorTexture(0, 0, 0, 0)
        end

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
                self.frame.Badge:SetText("")
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
            self.frame.Name:SetTextColor(0.97, 0.95, 0.89)
            self.frame.Details:SetText(DEFAULT_CARD_TEXT)
            self.frame.Details:SetTextColor(0.64, 0.68, 0.76)
            self.frame.Badge:SetText("OPEN SLOT")
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
                    self.frame.Details:SetTextColor(0.74, 0.78, 0.84)
                else
                    self.frame.Details:SetText("Selected Best in Slot")
                    self.frame.Details:SetTextColor(0.5, 0.8, 1)
                end

                self.frame.Badge:SetText("CURATED")

                -- show the checkmark and instance-specific text if the player owns this item
                if owned then
                    self.frame.Check:Show()
                    self.frame.Badge:SetText("OWNED")
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
