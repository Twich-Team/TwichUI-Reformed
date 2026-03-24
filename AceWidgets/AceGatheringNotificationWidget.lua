---@diagnostic disable: undefined-field
--[[
    AceGUI widget for Gathering item loot notifications.
    Shows: item icon, item link, quantity, item value, bag total, bag value, price source label.
]]
local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = TwichRx and unpack(TwichRx) or nil

local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_GatheringNotification"
local Type, Version = WIDGET_TYPE, 2

local FRAME_WIDTH  = 360
local FRAME_HEIGHT = 98
local ICON_SIZE    = 44
local TEXT_LEFT    = 62
local ACCENT_COLOR = { 0.2, 0.75, 0.3, 1 }
local HIGH_VALUE_ACCENT_COLOR = { 1.0, 0.76, 0.28, 1 }

local GOLD_COLOR   = "|cffffd24a"
local SILVER_COLOR = "|cffd7e0ea"
local COPPER_COLOR = "|cffd08a43"

local format = string.format

local function FormatCopperValue(copper)
    if not copper or copper <= 0 then return "|cffaaaaaa0g|r" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return format("%s%dg|r %s%ds|r %s%dc|r", GOLD_COLOR, g, SILVER_COLOR, s, COPPER_COLOR, c)
    elseif s > 0 then
        return format("%s%ds|r %s%dc|r", SILVER_COLOR, s, COPPER_COLOR, c)
    else
        return format("%s%dc|r", COPPER_COLOR, c)
    end
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:EnableMouse(true)
    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    -- Left accent bar
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(unpack(ACCENT_COLOR))

    -- Icon backdrop
    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT",  frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture("Interface\\Icons\\inv_misc_herb_flamecap")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Status label (top-left, e.g. "ITEM GATHERED")
    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT",  frame, "TOPLEFT", TEXT_LEFT, -8)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -106, -8)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.2, 0.75, 0.3, 1)
    status:SetText("ITEM GATHERED")

    -- Item link + quantity (large, shows quality color via item link)
    local itemLine = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLine:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    itemLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -106, 0)
    itemLine:SetJustifyH("LEFT")
    itemLine:SetWordWrap(false)
    itemLine:SetText("Unknown Item x1")

    -- Item value (loot batch value)
    local lootValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lootValue:SetPoint("TOPLEFT",  itemLine, "BOTTOMLEFT", 0, -4)
    lootValue:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -106, 0)
    lootValue:SetJustifyH("LEFT")
    lootValue:SetWordWrap(false)
    lootValue:SetText("Value: 0g")

    -- Bag total line
    local bagLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bagLine:SetPoint("TOPLEFT",  lootValue, "BOTTOMLEFT", 0, -2)
    bagLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -106, 0)
    bagLine:SetJustifyH("LEFT")
    bagLine:SetWordWrap(false)
    bagLine:SetTextColor(0.75, 0.75, 0.75, 1)
    bagLine:SetText("Bags: 0 (0g)")

    local priceSourceBg = frame:CreateTexture(nil, "BACKGROUND")
    priceSourceBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    priceSourceBg:SetSize(88, 20)
    priceSourceBg:SetColorTexture(0, 0, 0, 0.35)

    local priceSource = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceSource:SetPoint("CENTER", priceSourceBg, "CENTER", 0, 0)
    priceSource:SetWidth(80)
    priceSource:SetJustifyH("CENTER")
    priceSource:SetJustifyV("TOP")
    priceSource:SetWordWrap(false)
    priceSource:SetTextColor(0.75, 0.75, 0.75, 1)
    priceSource:SetText("DBMarket")

    ---@class TwichUI_GatheringNotificationWidget : AceGUIWidget
    local widget = {
        type           = Type,
        frame          = frame,
        accent         = accent,
        icon           = icon,
        iconBackdrop   = iconBackdrop,
        status         = status,
        itemLine       = itemLine,
        lootValue      = lootValue,
        bagLine        = bagLine,
        priceSource    = priceSource,
        priceSourceBg  = priceSourceBg,
        dismissCallback = nil,
    }

    local methods = {}

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(FRAME_HEIGHT)
        if self.SetFullWidth then self:SetFullWidth(true) end
        self.status:SetText("ITEM GATHERED")
        self.status:SetTextColor(unpack(ACCENT_COLOR))
        self.accent:SetColorTexture(unpack(ACCENT_COLOR))
        self.itemLine:SetText("Unknown Item x1")
        self.lootValue:SetText("Value: 0g")
        self.bagLine:SetText("Bags: 0 (0g)")
        self.priceSource:SetText("--")
        self.icon:SetTexture("Interface\\Icons\\inv_misc_herb_flamecap")
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.dismissCallback = nil
    end

    ---@param data {itemLink: string, quantity: number, itemValue: number, batchValue: number|nil, bagCount: number, bagValue: number, priceSource: string, iconTexture: number|string, isHighValue: boolean|nil}
    function methods:SetGatherData(data)
        if not data then return end

        local itemLink = data.itemLink or "Unknown Item"
        local qty      = data.quantity or 1
        local price    = data.itemValue or 0
        local batchValue = data.batchValue or (price * qty)
        local bagCount = data.bagCount or 0
        local bagValue = data.bagValue or 0
        local src      = data.priceSource or "--"
        local isHighValue = data.isHighValue == true

        if isHighValue then
            self.status:SetText("HIGH VALUE FIND")
            self.status:SetTextColor(unpack(HIGH_VALUE_ACCENT_COLOR))
            self.accent:SetColorTexture(unpack(HIGH_VALUE_ACCENT_COLOR))
        else
            self.status:SetText("ITEM GATHERED")
            self.status:SetTextColor(unpack(ACCENT_COLOR))
            self.accent:SetColorTexture(unpack(ACCENT_COLOR))
        end

        -- Icon
        if data.iconTexture then
            self.icon:SetTexture(data.iconTexture)
            self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        -- Item line: link + qty
        local qtyText = qty > 1 and (" |cffaaaaaa×%d|r"):format(qty) or ""
        self.itemLine:SetText(itemLink .. qtyText)

        -- Loot value
        self.lootValue:SetText("Looted: " .. FormatCopperValue(batchValue))

        -- Bag total
        self.bagLine:SetText(("Bags: %d (%s)"):format(bagCount, FormatCopperValue(bagValue)))

        -- Price source
        self.priceSource:SetText(src)
    end

    function methods:SetDismissCallback(fn)
        self.dismissCallback = fn
    end

    for name, method in pairs(methods) do
        widget[name] = method
    end

    frame:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and widget.dismissCallback then
            widget.dismissCallback()
        end
    end)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
