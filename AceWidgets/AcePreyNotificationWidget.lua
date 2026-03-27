local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_PreyNotification"
local Type, Version = WIDGET_TYPE, 1

local FRAME_WIDTH = 300
local BASE_HEIGHT = 84
local BUTTON_HEIGHT = 22
local BUTTON_WIDTH = 124
local BUTTON_SPACING = 10
local ICON_SIZE = 36
local TEXT_LEFT_OFFSET = 58
local FALLBACK_ICON_TEXTURE = "Interface\\AddOns\\TwichUI_Reformed\\Modules\\Chores\\Plumber\\Art\\ExpansionLandingPage\\Icons\\InProgressPrey.png"

local function HideActionTooltip()
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

local function ShowActionTooltip(button)
    if not button or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:AddLine(button.tooltipTitle or "Set Waypoint", 1, 1, 1)
    GameTooltip:AddLine(button.tooltipText or "Place a waypoint for this prey hunt.", 0.85, 0.85, 0.85, true)
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
    accent:SetColorTexture(0.94, 0.46, 0.18, 1)

    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT", frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture(FALLBACK_ICON_TEXTURE)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_LEFT_OFFSET, -10)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.98, 0.68, 0.22)
    status:SetText("PREY READY")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("Prey Hunt")

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(true)
    detail:SetText("A prey hunt is ready to be hunted.")

    local actionButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    actionButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    actionButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    actionButton:SetText("Set Waypoint")
    actionButton:Hide()

    if T and T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(actionButton)
    end

    ---@class TwichUI_PreyNotificationWidget : AceGUIWidget
    ---@field frame Button
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field status FontString
    ---@field title FontString
    ---@field detail FontString
    ---@field actionButton Button
    ---@field actionCallback function|nil
    local widget = {
        type = Type,
        frame = frame,
        accent = accent,
        icon = icon,
        iconBackdrop = iconBackdrop,
        status = status,
        title = title,
        detail = detail,
        actionButton = actionButton,
        actionCallback = nil,
    }

    local methods = {}

    local function UpdateDetailAnchors(self, showButton)
        self.detail:ClearAllPoints()
        self.detail:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
        self.detail:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, 0)

        if showButton then
            self.detail:SetPoint("BOTTOMLEFT", self.actionButton, "TOPLEFT", 0, BUTTON_SPACING)
            self.detail:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, BUTTON_HEIGHT + BUTTON_SPACING + 8)
            self:SetHeight(BASE_HEIGHT + BUTTON_HEIGHT + BUTTON_SPACING + 6)
        else
            self.detail:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", TEXT_LEFT_OFFSET, 10)
            self.detail:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
            self:SetHeight(BASE_HEIGHT)
        end
    end

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(BASE_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetActionCallback(nil)
        self:SetPreyNotification("Prey Hunt", "A prey hunt is ready to be hunted.", "PREY READY", nil, nil)
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self:SetActionCallback(nil)
        self.actionButton:Hide()
        self.title:SetText("")
        self.detail:SetText("")
        self.status:SetText("PREY READY")
        self.icon:SetTexture(FALLBACK_ICON_TEXTURE)
    end

    function methods:SetActionCallback(callback)
        self.actionCallback = callback
        self.actionButton:SetEnabled(callback ~= nil)
        self.actionButton:SetScript("OnClick", function()
            if self.actionCallback then
                self.actionCallback()
            end
        end)
    end

    function methods:SetPreyNotification(titleText, detailText, statusText, atlasName, buttonText)
        self.title:SetText(titleText or "Prey Hunt")
        self.detail:SetText(detailText or "A prey hunt is ready to be hunted.")
        self.status:SetText(statusText or "PREY READY")

        if atlasName and self.icon.SetAtlas and C_Texture and type(C_Texture.GetAtlasInfo) == "function" and C_Texture.GetAtlasInfo(atlasName) then
            self.icon:SetAtlas(atlasName, true)
        else
            self.icon:SetTexture(FALLBACK_ICON_TEXTURE)
            if self.icon.SetTexCoord then
                self.icon:SetTexCoord(0, 1, 0, 1)
            end
        end

        local showButton = self.actionCallback ~= nil
        if showButton then
            self.actionButton:SetText(buttonText or "Set Waypoint")
            self.actionButton.tooltipTitle = "Set Waypoint"
            self.actionButton.tooltipText = "Place a waypoint for this prey hunt."
            self.actionButton:SetScript("OnEnter", ShowActionTooltip)
            self.actionButton:SetScript("OnLeave", HideActionTooltip)
            self.actionButton:Show()
        else
            self.actionButton:Hide()
            self.actionButton:SetScript("OnEnter", nil)
            self.actionButton:SetScript("OnLeave", nil)
        end

        UpdateDetailAnchors(self, showButton)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)