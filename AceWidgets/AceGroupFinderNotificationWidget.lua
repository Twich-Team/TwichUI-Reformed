local AceGUI = LibStub("AceGUI-3.0")
local TwichRx = _G["TwichRx"]
---@type TwichUI|nil
local T = TwichRx and unpack(TwichRx) or nil

local WIDGET_TYPE = "TwichUI_GroupFinderNotification"
local Type, Version = WIDGET_TYPE, 2

local FRAME_WIDTH = 300
local BASE_HEIGHT = 80
local BUTTON_HEIGHT = 22
local BUTTON_WIDTH = 116
local BUTTON_SPACING = 10
local SUBTITLE_SPACING = 2
local ICON_SIZE = 36
local TEXT_LEFT_OFFSET = 58
local GROUP_FINDER_ICON_TEXTURE = "Interface\\Icons\\inv_misc_groupneedmore"

local function HideButtonTooltip()
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

local function ShowButtonTooltip(button)
    if not button or not GameTooltip or not button.tooltipTitle then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:AddLine(button.tooltipTitle, 1, 1, 1)
    if button.tooltipText then
        GameTooltip:AddLine(button.tooltipText, 0.85, 0.85, 0.85, true)
    end
    GameTooltip:Show()
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

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -SUBTITLE_SPACING)
    subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.42, 0.9, 0.6)
    subtitle:SetText("Teleport Ready")
    subtitle:Hide()

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

    local teleportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    teleportButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    teleportButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    teleportButton:RegisterForClicks("AnyUp", "AnyDown")
    teleportButton:SetText("Teleport")
    teleportButton:Hide()

    local browseButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    browseButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    browseButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    browseButton:SetText("Open Teleports")
    browseButton:Hide()

    if T and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(teleportButton)
        T.Tools.UI.SkinTwichButton(browseButton)
    end

    ---@class TwichUI_GroupFinderNotificationWidget : AceGUIWidget
    ---@field frame Button
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field status FontString
    ---@field subtitle FontString
    ---@field title FontString
    ---@field detail FontString
    ---@field teleportButton Button
    ---@field browseButton Button
    ---@field openTeleportCallback function|nil
    local widget = {
        type = Type,
        frame = frame,
        accent = accent,
        icon = icon,
        iconBackdrop = iconBackdrop,
        status = status,
        subtitle = subtitle,
        title = title,
        detail = detail,
        teleportButton = teleportButton,
        browseButton = browseButton,
        openTeleportCallback = nil,
    }

    local methods = {}

    local function GetActiveButton(self)
        if self.teleportButton:IsShown() then
            return self.teleportButton
        end

        if self.browseButton:IsShown() then
            return self.browseButton
        end

        return nil
    end

    local function UpdateTextAnchors(self)
        self.title:ClearAllPoints()

        if self.subtitle:IsShown() then
            self.title:SetPoint("TOPLEFT", self.subtitle, "BOTTOMLEFT", 0, -2)
            self.title:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, 0)
        else
            self.title:SetPoint("TOPLEFT", self.status, "BOTTOMLEFT", 0, -2)
            self.title:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -2)
        end
    end

    local function UpdateDetailAnchors(self)
        local activeButton = GetActiveButton(self)

        self.detail:ClearAllPoints()
        self.detail:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
        self.detail:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, 0)

        if activeButton then
            self.detail:SetPoint("BOTTOMLEFT", activeButton, "TOPLEFT", 0, BUTTON_SPACING)
            self.detail:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, BUTTON_HEIGHT + BUTTON_SPACING + 8)
            self:SetHeight(BASE_HEIGHT + BUTTON_HEIGHT + BUTTON_SPACING + 6)
        else
            self.detail:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", TEXT_LEFT_OFFSET, 10)
            self.detail:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
            self:SetHeight(BASE_HEIGHT)
        end
    end

    local function ResetTeleportButton(button)
        button:Hide()
        button.tooltipTitle = nil
        button.tooltipText = nil
        button:SetScript("OnEnter", nil)
        button:SetScript("OnLeave", nil)
    end

    local function ClearTeleportAction(self)
        if not InCombatLockdown() then
            self.teleportButton:SetAttribute("type", nil)
            self.teleportButton:SetAttribute("spell", nil)
        end

        ResetTeleportButton(self.teleportButton)
        ResetTeleportButton(self.browseButton)
        self.subtitle:Hide()
        self.subtitle:SetText("")
        self.openTeleportCallback = nil
    end

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(BASE_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetGroupFinderNotification("Unknown Activity", nil, nil, nil)
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        ClearTeleportAction(self)
        self.subtitle:SetText("")
        self.title:SetText("")
        self.detail:SetText("")
    end

    ---@param activityName string|nil
    ---@param listingName string|nil
    ---@param teleportInfo table|nil
    ---@param openTeleportCallback function|nil
    function methods:SetGroupFinderNotification(activityName, listingName, teleportInfo, openTeleportCallback)
        activityName = type(activityName) == "string" and activityName ~= "" and activityName or "Unknown Activity"
        listingName = type(listingName) == "string" and listingName ~= "" and listingName or nil

        ClearTeleportAction(self)

        self.title:SetText(activityName)

        if listingName and listingName ~= activityName then
            self.detail:SetText(("Accepted into %s."):format(listingName))
        else
            self.detail:SetText("Accepted into a premade group.")
        end

        if teleportInfo and teleportInfo.known then
            if teleportInfo.spellID and not InCombatLockdown() then
                self.teleportButton:SetAttribute("type", "spell")
                self.teleportButton:SetAttribute("spell", teleportInfo.spellID)
                self.teleportButton.tooltipTitle = teleportInfo.label or "Teleport"
                self.teleportButton.tooltipText = "Click to cast this unlocked teleport."
                self.teleportButton:SetScript("OnEnter", ShowButtonTooltip)
                self.teleportButton:SetScript("OnLeave", HideButtonTooltip)
                self.teleportButton:Show()
                self.subtitle:SetText("Teleport Ready")
                self.subtitle:Show()
            elseif type(openTeleportCallback) == "function" then
                self.openTeleportCallback = openTeleportCallback
                self.browseButton.tooltipTitle = teleportInfo.label or "Teleports"
                self.browseButton.tooltipText = "Click to open the Teleports browser for this destination."
                self.browseButton:SetScript("OnClick", function()
                    if self.openTeleportCallback then
                        self.openTeleportCallback(self.frame)
                    end
                end)
                self.browseButton:SetScript("OnEnter", ShowButtonTooltip)
                self.browseButton:SetScript("OnLeave", HideButtonTooltip)
                self.browseButton:Show()
                self.subtitle:SetText("Teleport Available")
                self.subtitle:Show()
            end
        end

        UpdateTextAnchors(self)
        UpdateDetailAnchors(self)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
