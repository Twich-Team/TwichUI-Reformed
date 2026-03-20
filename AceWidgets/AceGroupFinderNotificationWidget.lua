local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_GroupFinderNotification"
local Type, Version = WIDGET_TYPE, 1

local FRAME_WIDTH = 300
local FRAME_HEIGHT = 80
local ICON_SIZE = 36
local TEXT_LEFT_OFFSET = 58
local GROUP_FINDER_ICON_TEXTURE = "Interface\\Icons\\inv_misc_groupneedmore"

local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(0.44, 0.72, 1, 1)

    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT", frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture(GROUP_FINDER_ICON_TEXTURE)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_LEFT_OFFSET, -10)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.44, 0.72, 1)
    status:SetText("GROUP FINDER")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("Unknown Activity")

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(true)
    detail:SetText("Accepted into a premade group.")

    ---@class TwichUI_GroupFinderNotificationWidget : AceGUIWidget
    ---@field frame Button
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field status FontString
    ---@field title FontString
    ---@field detail FontString
    local widget = {
        type = Type,
        frame = frame,
        accent = accent,
        icon = icon,
        iconBackdrop = iconBackdrop,
        status = status,
        title = title,
        detail = detail,
    }

    local methods = {}

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(FRAME_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetGroupFinderNotification("Unknown Activity", nil)
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.title:SetText("")
        self.detail:SetText("")
    end

    ---@param activityName string|nil
    ---@param listingName string|nil
    function methods:SetGroupFinderNotification(activityName, listingName)
        activityName = type(activityName) == "string" and activityName ~= "" and activityName or "Unknown Activity"
        listingName = type(listingName) == "string" and listingName ~= "" and listingName or nil

        self.title:SetText(activityName)

        if listingName and listingName ~= activityName then
            self.detail:SetText(("Accepted into %s."):format(listingName))
        else
            self.detail:SetText("Accepted into a premade group.")
        end
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)