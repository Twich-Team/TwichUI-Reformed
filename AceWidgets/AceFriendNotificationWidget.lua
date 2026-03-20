local AceGUI = LibStub("AceGUI-3.0")
local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)
---@type Tools
local Tools = T.Tools
local Textures = Tools.Textures

local WIDGET_TYPE = "TwichUI_FriendNotification"
local Type, Version = WIDGET_TYPE, 2

local FRAME_WIDTH = 280
local FRAME_HEIGHT = 72
local ICON_SIZE = 32

local STATUS_STYLES = {
    online = {
        title = "ONLINE",
        color = { 0.36, 0.82, 0.47 },
        detail = "Came online",
    },
    offline = {
        title = "OFFLINE",
        color = { 0.87, 0.36, 0.36 },
        detail = "Went offline",
    },
}

local function GetClassColor(classToken)
    local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if classColor then
        return classColor.r, classColor.g, classColor.b
    end

    return 0.82, 0.82, 0.82
end

local function ApplyBoldFont(fontString, size)
    if not fontString then
        return
    end

    local fontPath = fontString:GetFont()
    if fontPath then
        fontString:SetFont(fontPath, size or 15, "OUTLINE")
    end
end

local function ApplyClassIcon(texture, classToken)
    if not texture then
        return
    end

    if Textures and Textures.ApplyClassTexture and Textures:ApplyClassTexture(texture, classToken) then
        return
    end

    texture:SetTexture("Interface\\FriendsFrame\\InformationIcon")
    texture:SetTexCoord(0, 1, 0, 1)
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(0.36, 0.82, 0.47, 1)

    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT", frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    ApplyClassIcon(icon)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -12)
    status:SetJustifyH("RIGHT")
    status:SetText(STATUS_STYLES.online.title)

    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", iconBackdrop, "TOPRIGHT", 10, -2)
    name:SetPoint("TOPRIGHT", status, "TOPLEFT", -8, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText("Unknown Friend")
    ApplyBoldFont(name, 15)

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(true)
    detail:SetText(STATUS_STYLES.online.detail)

    ---@class TwichUI_FriendNotificationWidget : AceGUIWidget
    ---@field frame Frame
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field name FontString
    ---@field status FontString
    ---@field detail FontString
    local widget = {
        type = Type,
        frame = frame,
        accent = accent,
        icon = icon,
        iconBackdrop = iconBackdrop,
        name = name,
        status = status,
        detail = detail,
    }

    local methods = {}

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(FRAME_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetFriendNotification("Unknown Friend", "", nil, true)
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self:SetFriendNotification("Unknown Friend", "", nil, true)
    end

    ---@param displayName string
    ---@param detailText string
    ---@param classToken string|nil
    ---@param isOnline boolean
    ---@param iconStyle string|nil
    function methods:SetFriendNotification(displayName, detailText, classToken, isOnline, iconStyle)
        local statusKey = isOnline and "online" or "offline"
        local statusStyle = STATUS_STYLES[statusKey]
        local r, g, b = GetClassColor(classToken)

        self.name:SetText(displayName or "Unknown Friend")
        self.name:SetTextColor(r, g, b)
        self.detail:SetText(detailText or statusStyle.detail)

        self.status:SetText(statusStyle.title)
        self.status:SetTextColor(unpack(statusStyle.color))

        self.accent:SetColorTexture(statusStyle.color[1], statusStyle.color[2], statusStyle.color[3], 1)

        if self.iconBackdrop and self.iconBackdrop.SetBackdropBorderColor then
            self.iconBackdrop:SetBackdropBorderColor(r, g, b)
        end

        if Textures and Textures.ApplyClassTexture then
            Textures:ApplyClassTexture(self.icon, classToken, iconStyle)
            return
        end

        ApplyClassIcon(self.icon, classToken)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
