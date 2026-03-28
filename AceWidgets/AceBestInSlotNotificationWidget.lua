local AceGUI = LibStub("AceGUI-3.0")
local TwichRx = _G["TwichRx"]
---@type TwichUI|nil
local T = TwichRx and unpack(TwichRx) or nil

local WIDGET_TYPE = "TwichUI_BISNotification"
local Type, Version = WIDGET_TYPE, 1

local FRAME_WIDTH  = 300
local BASE_HEIGHT  = 68
local DETAIL_EXTRA = 16
local ICON_SIZE    = 36
local TEXT_LEFT_OFFSET = 58

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local EVENT_STYLES = {
    received        = { status = "BEST IN SLOT — ACQUIRED",      color = { 0.32, 0.86, 0.54 } },
    available_roll  = { status = "BEST IN SLOT — AVAILABLE TO ROLL", color = { 0.96, 0.76, 0.24 } },
    available_vault = { status = "BEST IN SLOT — IN YOUR VAULT",  color = { 0.96, 0.76, 0.24 } },
    -- legacy fallback
    available       = { status = "BEST IN SLOT — AVAILABLE",     color = { 0.96, 0.76, 0.24 } },
}
local DEFAULT_STYLE = EVENT_STYLES.received

local function GetEventStyle(eventType)
    return EVENT_STYLES[eventType] or DEFAULT_STYLE
end

-- ---------------------------------------------------------------------------

local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, BASE_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    -- Left accent bar
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(unpack(DEFAULT_STYLE.color))

    -- Icon container
    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT", frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture(FALLBACK_ICON)

    -- Status label (e.g. "BEST IN SLOT")
    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT",  frame, "TOPLEFT",  TEXT_LEFT_OFFSET, -10)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    status:SetJustifyH("LEFT")
    status:SetTextColor(unpack(DEFAULT_STYLE.color))
    status:SetText(DEFAULT_STYLE.status)

    -- Item name
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT",  status, "BOTTOMLEFT",  0, -2)
    title:SetPoint("TOPRIGHT", frame,  "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("")

    -- Optional secondary line (upgrade path, source, etc.)
    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT",  title, "BOTTOMLEFT",  0, -4)
    detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(true)
    detail:SetTextColor(0.58, 0.64, 0.72)
    detail:SetText("")
    detail:Hide()

    -- ---------------------------------------------------------------------------

    ---@class TwichUI_BISNotificationWidget : AceGUIWidget
    ---@field frame Button
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field status FontString
    ---@field title FontString
    ---@field detail FontString
    ---@field dismissCallback function|nil
    local widget = {
        type         = Type,
        frame        = frame,
        accent       = accent,
        icon         = icon,
        iconBackdrop = iconBackdrop,
        status       = status,
        title        = title,
        detail       = detail,
        dismissCallback = nil,
    }

    local methods = {}

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(BASE_HEIGHT)
        -- Stretch to fill whatever container width is configured.
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end
        self.dismissCallback = nil
        frame.__bisItemLink  = nil
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.dismissCallback = nil
        frame.__bisItemLink  = nil
        self.title:SetText("")
        self.title:SetTextColor(1, 1, 1)
        self.detail:SetText("")
        self.detail:Hide()
        self.icon:SetTexture(FALLBACK_ICON)
        self.status:SetText(DEFAULT_STYLE.status)
        self.status:SetTextColor(unpack(DEFAULT_STYLE.color))
        self.accent:SetColorTexture(unpack(DEFAULT_STYLE.color))
    end

    function methods:SetDismissCallback(callback)
        self.dismissCallback = callback
    end

    ---Set the notification content.
    ---@param itemLink string|nil  Full item hyperlink. May arrive nil if data not yet cached.
    ---@param detailText string|nil  Optional gray sub-line (e.g. upgrade track info).
    ---@param eventType string|nil  "received" | "available"
    function methods:SetBISNotification(itemLink, detailText, eventType)
        local style = GetEventStyle(eventType)
        self.accent:SetColorTexture(style.color[1], style.color[2], style.color[3])
        self.status:SetTextColor(style.color[1], style.color[2], style.color[3])
        self.status:SetText(style.status)

        -- Detail line
        if detailText and detailText ~= "" then
            self.detail:SetText(detailText)
            self.detail:Show()
            self:SetHeight(BASE_HEIGHT + DETAIL_EXTRA)
        else
            self.detail:SetText("")
            self.detail:Hide()
            self:SetHeight(BASE_HEIGHT)
        end

        -- Store link for tooltip
        frame.__bisItemLink = itemLink

        if not itemLink then
            self.title:SetText("Best in Slot Item")
            self.title:SetTextColor(1, 1, 1)
            self.icon:SetTexture(FALLBACK_ICON)
            return
        end

        -- Capture self in local for closures
        local self_ = self

        local function ApplyItemInfo()
            local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture =
                C_Item.GetItemInfo(itemLink)
            if not itemName then return false end

            self_.title:SetText(itemName)

            if itemTexture then
                self_.icon:SetTexture(itemTexture)
            end

            if itemQuality then
                local r, g, b = C_Item.GetItemQualityColor(itemQuality)
                self_.title:SetTextColor(r, g, b)
                self_.accent:SetColorTexture(r, g, b)
                self_.status:SetTextColor(r, g, b)
            else
                self_.title:SetTextColor(1, 1, 1)
            end

            return true
        end

        -- Try immediately; if item data isn't cached yet, wait for it.
        if not ApplyItemInfo() then
            self.title:SetText("...")
            self.title:SetTextColor(0.7, 0.7, 0.7)
            if _G.Item and type(_G.Item.CreateFromItemLink) == "function" then
                local itemObj = _G.Item:CreateFromItemLink(itemLink)
                if itemObj then
                    itemObj:ContinueOnItemLoad(function()
                        -- Guard against widget recycling between now and callback.
                        if frame.__bisItemLink == itemLink then
                            ApplyItemInfo()
                        end
                    end)
                end
            end
        end
    end

    -- Tooltip on hover (Frame.lua will wrap these via oldOnEnter / oldOnLeave)
    frame:SetScript("OnEnter", function(self)
        local link = self.__bisItemLink
        if not link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.obj = widget

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
