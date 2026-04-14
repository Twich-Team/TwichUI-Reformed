---@diagnostic disable: undefined-global, undefined-field, return-type-mismatch
local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

local AceGUI = LibStub("AceGUI-3.0")

-- Visual constants for the Best-in-Slot item widget
local WIDGET_HEIGHT = 40
local WIDGET_WIDTH = 200
local ICON_SIZE = 32

local ACEGUI_ITEM_TYPE = "TwichUI_Item"

local Type, Version = ACEGUI_ITEM_TYPE, 1

local NO_ITEM_TEXT = "No Item"
local EMPTY_ICON = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function GetFallbackFont()
    local font = T.Tools and T.Tools.Text and T.Tools.Text.GetElvUIFont and T.Tools.Text.GetElvUIFont()
    if font then
        return font
    end

    local gameFont = _G.GameFontNormal
    return gameFont and select(1, gameFont:GetFont()) or nil
end

local function GetWidgetColors()
    local ThemeModule = T:GetModule("Theme", true)
    local accent = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("accentColor") or { 0.95, 0.76, 0.26 }
    local border = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    local bg = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("backgroundColor") or { 0.06, 0.06, 0.08 }
    return accent, border, bg
end

---Builds a simple AceGUI widget for displaying an item in lists.
---@return AceGUIWidget
local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:Hide()

    frame:SetSize(WIDGET_WIDTH, WIDGET_HEIGHT)
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
        local _, border, bg = GetWidgetColors()
        if frame.SetBackdropColor then
            frame:SetBackdropColor(bg[1] * 0.7, bg[2] * 0.72, bg[3] * 0.8, 0.9)
        end
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(border[1], border[2], border[3], 0.28)
        end
    end

    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    if not frame.TopAccent then
        frame.TopAccent = frame:CreateTexture(nil, "ARTWORK")
        frame.TopAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TopAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.TopAccent:SetHeight(2)
    end

    if not frame.InnerGlow then
        frame.InnerGlow = frame:CreateTexture(nil, "ARTWORK")
        frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end

    if not frame.BottomShade then
        frame.BottomShade = frame:CreateTexture(nil, "BACKGROUND")
        frame.BottomShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.BottomShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end

    -- icon
    local iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconFrame:SetPoint("LEFT", frame, "LEFT", 6, 0)
    iconFrame:SetSize(ICON_SIZE + 6, ICON_SIZE + 6)
    if iconFrame.SetTemplate then
        iconFrame:SetTemplate("Transparent")
    end

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- icon border for empty slots
    local iconBorder = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    iconBorder:SetAllPoints(iconFrame)
    if iconBorder.SetTemplate then
        iconBorder:SetTemplate("Transparent")
    end
    iconBorder:Hide()

    -- item name text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", iconFrame, "RIGHT", 10, 6)
    text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -3)
    detail:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(false)

    local font = GetFallbackFont()
    if font then
        text:SetFont(font, 12, "")
        detail:SetFont(font, 10, "")
    end

    detail:SetTextColor(0.64, 0.68, 0.76)


    ---@class TwichUI_ItemWidget : AceGUIWidget
    ---@field icon Texture
    ---@field iconFrame Frame
    ---@field iconBorder Frame
    ---@field text FontString
    ---@field detail FontString
    ---@field itemID integer|nil
    ---@field itemLink string|nil
    local widget = {}
    widget.type = Type
    widget.frame = frame
    widget.icon = icon
    widget.iconFrame = iconFrame
    widget.iconBorder = iconBorder
    widget.text = text
    widget.detail = detail
    widget.itemID = nil
    widget.itemLink = nil
    frame.obj = widget

    local methods = {}

    ---Called when AceGUI acquires this widget for (re)use.
    function methods:OnAcquire()
        self:SetWidth(WIDGET_WIDTH)
        self:SetHeight(WIDGET_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetItem(nil)
    end

    ---Called when the widget is released back to the pool.
    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.itemID = nil
        self.itemLink = nil
        if self.icon then
            self.icon:SetTexture(EMPTY_ICON)
        end
        if self.iconBorder then
            self.iconBorder:Hide()
        end
        if self.text then
            self.text:SetText("")
            self.text:SetTextColor(1, 1, 1)
        end
        if self.detail then
            self.detail:SetText("")
            self.detail:SetTextColor(0.64, 0.68, 0.76)
        end
        self.frame:SetScript("OnClick", nil)
    end

    ---Register a click callback invoked when the widget's frame is clicked.
    ---@param func fun()
    function methods:ClickCallback(func)
        if not func then
            self.frame:SetScript("OnClick", nil)
            return
        end

        self.frame:SetScript("OnClick", function()
            func()
        end)
    end

    ---Populate the widget to represent the given item.
    ---Accepts either an itemID (number) or an item link (string).
    ---@param item integer|string|nil
    function methods:SetItem(item)
        local itemID, itemLink

        if type(item) == "number" then
            itemID = item
        elseif type(item) == "string" then
            itemLink = item
            local idFromLink = item:match("item:(%d+)")
            if idFromLink then
                itemID = tonumber(idFromLink)
            end
        end

        self.itemID = itemID
        self.itemLink = itemLink

        if not itemID and not itemLink then
            if self.icon then
                self.icon:SetTexture(EMPTY_ICON)
            end

            if self.iconBorder then
                self.iconBorder:SetBackdropBorderColor(0.38, 0.42, 0.52, 0.65)
                self.iconBorder:Show()
            end

            if self.text then
                self.text:SetText(NO_ITEM_TEXT)
                self.text:SetTextColor(0.96, 0.94, 0.88)
            end

            if self.detail then
                self.detail:SetText("Choose from the source list or add a custom piece.")
                self.detail:SetTextColor(0.64, 0.68, 0.76)
            end
            return
        end

        local function ApplyItemInfo()
            local source = self.itemLink or self.itemID
            if not source then return end

            local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(source)
            if not itemName then return end


            if self.icon then
                self.icon:SetTexture(itemTexture)
            end

            if self.iconBorder then
                self.iconBorder:Hide()
            end

            if self.text then
                local r, g, b = 1, 1, 1
                if itemQuality then
                    r, g, b = C_Item.GetItemQualityColor(itemQuality)
                end
                self.text:SetText(itemName)
                self.text:SetTextColor(r, g, b)
            end

            if self.detail then
                local itemTypeName, itemSubTypeName, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID or source)
                local detailText = equipLoc and equipLoc ~= "" and (_G[equipLoc] or itemSubTypeName or itemTypeName) or
                itemSubTypeName or itemTypeName
                self.detail:SetText(detailText or "Best in Slot candidate")
                self.detail:SetTextColor(0.64, 0.68, 0.76)
            end
        end

        -- Try immediate info first.
        ApplyItemInfo()

        -- If not yet cached, ensure we update when it becomes available.
        local source = self.itemLink or self.itemID
        if source and Item then
            if type(source) == "string" and Item.CreateFromItemLink and not C_Item.GetItemInfo(source) then
                local itemObj = Item:CreateFromItemLink(source)
                itemObj:ContinueOnItemLoad(function()
                    if self.itemLink == itemLink and self.itemID == itemID then
                        ApplyItemInfo()
                    end
                end)
            elseif type(source) == "number" and Item.CreateFromItemID and not C_Item.GetItemInfo(source) then
                local itemObj = Item:CreateFromItemID(source)
                itemObj:ContinueOnItemLoad(function()
                    if self.itemLink == itemLink and self.itemID == itemID then
                        ApplyItemInfo()
                    end
                end)
            end
        end
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    frame:SetScript("OnEnter", function(self)
        local accent = GetWidgetColors()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.9)
        end
        if self.InnerGlow then
            self.InnerGlow:SetColorTexture(accent[1], accent[2], accent[3], 0.1)
        end
        local obj = self.obj
        if not obj or (not obj.itemID and not obj.itemLink) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if obj.itemLink then
            GameTooltip:SetHyperlink(obj.itemLink)
        elseif obj.itemID then
            GameTooltip:SetItemByID(obj.itemID)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local _, border = GetWidgetColors()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(border[1], border[2], border[3], 0.28)
        end
        if self.InnerGlow then
            self.InnerGlow:SetColorTexture(0, 0, 0, 0)
        end
    end)

    do
        local accent, _, bg = GetWidgetColors()
        frame.TopAccent:SetColorTexture(accent[1], accent[2], accent[3], 0.92)
        frame.InnerGlow:SetColorTexture(0, 0, 0, 0)
        frame.BottomShade:SetColorTexture(bg[1] * 0.45, bg[2] * 0.48, bg[3] * 0.56, 0.5)
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
