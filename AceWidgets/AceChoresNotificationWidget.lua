local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_ChoresNotification"
local Type, Version = WIDGET_TYPE, 1

local FRAME_WIDTH = 300
local BASE_HEIGHT = 70
local ICON_SIZE = 36
local TEXT_LEFT_OFFSET = 58
local MAX_LINES = 4

local NOTIFICATION_STYLES = {
    available = {
        status = "CHORES READY",
        color = { 0.33, 0.65, 0.96 },
        icon = "Interface\\Icons\\inv_scroll_11",
        singularTitle = "1 Chore Available",
        pluralTitle = "%d Chores Available",
    },
    completed = {
        status = "CHORES COMPLETE",
        color = { 0.32, 0.86, 0.54 },
        icon = "Interface\\Icons\\achievement_reputation_01",
        singularTitle = "1 Chore Completed",
        pluralTitle = "%d Chores Completed",
    },
}

local function GetStyle(kind)
    return NOTIFICATION_STYLES[kind] or NOTIFICATION_STYLES.available
end

local function BuildOverflowLine(count)
    return ("|cff7f8c8d+ %d more|r"):format(count)
end

local function BuildPreviewLine(iconMarkup, label, detail)
    local coloredLabel = ("|cff72c7ff%s|r"):format(label or "Chores")
    return ("%s%s |cff7f8c8d-|r %s"):format(iconMarkup or "", coloredLabel, detail or "Preview")
end

local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, BASE_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(unpack(NOTIFICATION_STYLES.available.color))

    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT", frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture(NOTIFICATION_STYLES.available.icon)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_LEFT_OFFSET, -10)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    status:SetJustifyH("LEFT")
    status:SetTextColor(unpack(NOTIFICATION_STYLES.available.color))
    status:SetText(NOTIFICATION_STYLES.available.status)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("1 Chore Available")

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(true)
    detail:SetText("")
    detail:SetTextColor(0.58, 0.64, 0.72)
    detail:Hide()

    local lines = {}
    local previousLine = title
    for index = 1, MAX_LINES do
        local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, index == 1 and -6 or -3)
        line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        line:SetText("")
        line:Hide()
        lines[index] = line
        previousLine = line
    end

    ---@class TwichUI_ChoresNotificationWidget : AceGUIWidget
    ---@field frame Button
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field status FontString
    ---@field title FontString
    ---@field detail FontString
    ---@field lines FontString[]
    local widget = {
        type = Type,
        frame = frame,
        accent = accent,
        icon = icon,
        iconBackdrop = iconBackdrop,
        status = status,
        title = title,
        detail = detail,
        lines = lines,
    }

    local methods = {}

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(BASE_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetChoresNotification("available", {
            BuildPreviewLine("|TInterface\\Icons\\inv_misc_map08:14:14:0:0|t ", "Delver's Call", "Open the tooltip"),
        })
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.title:SetText("")
        self.detail:SetText("")
        for _, line in ipairs(self.lines) do
            line:SetText("")
            line:Hide()
        end
    end

    ---@param kind string|nil
    ---@param entries string[]|nil
    function methods:SetChoresNotification(kind, entries)
        local style = GetStyle(kind)
        local count = type(entries) == "table" and #entries or 0
        local visibleLines = {}

        self.icon:SetTexture(style.icon)
        self.status:SetText(style.status)
        self.status:SetTextColor(unpack(style.color))
        self.accent:SetColorTexture(unpack(style.color))

        if count == 1 then
            self.title:SetText(style.singularTitle)
        else
            self.title:SetText((style.pluralTitle):format(math.max(count, 0)))
        end

        self.detail:SetText("")
        self.detail:Hide()

        if type(entries) == "table" then
            for index = 1, math.min(count, MAX_LINES) do
                visibleLines[index] = entries[index]
            end
        end

        if count > MAX_LINES then
            visibleLines[MAX_LINES] = BuildOverflowLine(count - (MAX_LINES - 1))
        end

        for index, line in ipairs(self.lines) do
            local text = visibleLines[index]
            if text and text ~= "" then
                line:SetText(text)
                line:Show()
            else
                line:SetText("")
                line:Hide()
            end
        end

        local shownCount = math.min(count, MAX_LINES)
        if count > MAX_LINES then
            shownCount = MAX_LINES
        end

        self:SetHeight(BASE_HEIGHT + shownCount * 15)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
