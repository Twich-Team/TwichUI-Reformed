local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_MythicPlusAlertNotification"
local Type, Version = WIDGET_TYPE, 1

local FRAME_WIDTH = 300
local FRAME_HEIGHT = 82
local ICON_SIZE = 36
local TEXT_LEFT_OFFSET = 58
local FALLBACK_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:EnableMouse(true)

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(0.85, 0.25, 0.25)

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

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_LEFT_OFFSET, -10)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.85, 0.25, 0.25)
    status:SetText("MYTHIC+ ALERT")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("Player Down")

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    detail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", TEXT_LEFT_OFFSET, 10)
    detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(true)
    detail:SetText("Deaths: 1")

    ---@class TwichUI_MythicPlusAlertNotificationWidget : AceGUIWidget
    ---@field frame Frame
    ---@field accent Texture
    ---@field icon Texture
    ---@field status FontString
    ---@field title FontString
    ---@field detail FontString
    local widget = {
        type = Type,
        frame = frame,
        accent = accent,
        icon = icon,
        status = status,
        title = title,
        detail = detail,
        dismissCallback = nil,
    }

    local methods = {}

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(FRAME_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetAlert("MYTHIC+ ALERT", "Player Down", "Deaths: 1", FALLBACK_ICON, { 0.85, 0.25, 0.25 })
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.dismissCallback = nil
        self.status:SetText("")
        self.title:SetText("")
        self.detail:SetText("")
        self.icon:SetTexture(nil)
    end

    function methods:SetDismissCallback(callback)
        self.dismissCallback = callback
    end

    function methods:Dismiss()
        if self.dismissCallback then
            self.dismissCallback(self)
        end
    end

    function methods:SetAlert(statusText, titleText, detailText, iconTexture, accentColor)
        local color = accentColor or { 0.85, 0.25, 0.25 }
        self.status:SetText(statusText or "MYTHIC+ ALERT")
        self.status:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1)
        self.accent:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1)
        self.title:SetText(titleText or "Alert")
        self.detail:SetText(detailText or "")
        self.icon:SetTexture(iconTexture or FALLBACK_ICON)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)