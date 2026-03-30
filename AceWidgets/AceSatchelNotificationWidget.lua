local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_SatchelNotification"
local Type, Version = WIDGET_TYPE, 2

local FRAME_WIDTH = 280
local FRAME_HEIGHT = 90
local ROLE_ICON_SIZE = 26
local TITLE_RIGHT_PADDING = 92

local ROLE_ATLASES = {
    Tank = {
        standard = { atlas = "UI-LFG-RoleIcon-Tank" },
        twich = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_Tank", width = 64, height = 74 },
    },
    Healer = {
        standard = { atlas = "UI-LFG-RoleIcon-Healer" },
        twich = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_Healer", width = 64, height = 68 },
    },
    DPS = {
        standard = { atlas = "UI-LFG-RoleIcon-DPS" },
        twich = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_DPS", width = 64, height = 74 },
    },
}

local function GetScaledIconSize(iconDef)
    if type(iconDef) ~= "table" then
        return ROLE_ICON_SIZE, ROLE_ICON_SIZE
    end

    local width = tonumber(iconDef.width) or ROLE_ICON_SIZE
    local height = tonumber(iconDef.height) or ROLE_ICON_SIZE
    if width <= 0 or height <= 0 then
        return ROLE_ICON_SIZE, ROLE_ICON_SIZE
    end

    local scale = ROLE_ICON_SIZE / height
    return math.max(1, math.floor((width * scale) + 0.5)), math.max(1, math.floor((height * scale) + 0.5))
end

local function ApplyRoleIconArt(icon, role, iconType)
    if not icon then
        return false
    end

    local roleDefs = ROLE_ATLASES[role]
    local art = roleDefs and (roleDefs[iconType] or roleDefs.standard) or nil
    if not art then
        icon:Hide()
        return false
    end

    if art.atlas then
        icon:SetAtlas(art.atlas)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
        return true
    end

    if art.texture then
        icon:SetAtlas(nil)
        icon:SetTexture(art.texture)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetSize(GetScaledIconSize(art))
        return true
    end

    icon:Hide()
    return false
end

local function ApplyIgnoreButtonStyle(button)
    if not button then
        return
    end

    button:SetText("|cffe04b4bIgnore|r")
end

local function ShowIgnoreTooltip(button)
    if not button then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:AddLine("Ignore", 1, 1, 1)
    GameTooltip:AddLine(
        "Stops SatchelWatch from notifying you about this entry again until you re-enable it or use Reset Ignored Entries.",
        0.85, 0.85, 0.85, true)
    GameTooltip:Show()
end

---@return AceGUIWidget
local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -TITLE_RIGHT_PADDING, -10)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.82, 0)
    title:SetText("Satchel Available")

    local dungeonText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dungeonText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    dungeonText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -2)
    dungeonText:SetJustifyH("LEFT")
    dungeonText:SetWordWrap(true)
    do
        local font, _, flags = dungeonText:GetFont()
        if font then
            dungeonText:SetFont(font, 14, flags)
        end
    end

    local groupText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    groupText:SetPoint("TOPRIGHT", dungeonText, "BOTTOMRIGHT", 0, -2)
    groupText:SetJustifyH("RIGHT")
    groupText:SetText("")

    local progressFrame = CreateFrame("Frame", nil, frame)
    progressFrame:SetPoint("TOPLEFT", dungeonText, "BOTTOMLEFT", 0, -4)
    progressFrame:SetPoint("TOPRIGHT", dungeonText, "BOTTOMRIGHT", 0, -4)
    progressFrame:SetHeight(14)
    progressFrame:EnableMouse(false)

    local progressText = progressFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    progressText:SetAllPoints(progressFrame)
    progressText:SetJustifyH("LEFT")
    progressText:SetText("")

    local roleIcons = {}
    for index = 1, 3 do
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
        if index == 1 then
            icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
        else
            icon:SetPoint("RIGHT", roleIcons[index - 1], "LEFT", -6, 0)
        end
        icon:Hide()
        roleIcons[index] = icon
    end

    local queueButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    queueButton:SetSize(112, 22)
    queueButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 6)
    queueButton:SetText("Queue")
    T.Tools.UI.SkinTwichButton(queueButton)

    local ignoreButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ignoreButton:SetSize(132, 22)
    ignoreButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
    ApplyIgnoreButtonStyle(ignoreButton)
    T.Tools.UI.SkinTwichButton(ignoreButton)
    ApplyIgnoreButtonStyle(ignoreButton)
    ignoreButton:SetScript("OnEnter", function(self)
        ShowIgnoreTooltip(self)
    end)
    ignoreButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ---@class TwichUI_SatchelNotificationWidget : AceGUIWidget
    ---@field title FontString
    ---@field dungeonText FontString
    ---@field groupText FontString
    ---@field progressFrame Frame
    ---@field progressText FontString
    ---@field roleIcons Texture[]
    ---@field queueButton Button
    ---@field ignoreButton Button
    local widget = {
        type = Type,
        frame = frame,
        title = title,
        dungeonText = dungeonText,
        groupText = groupText,
        progressFrame = progressFrame,
        progressText = progressText,
        roleIcons = roleIcons,
        queueButton = queueButton,
        ignoreButton = ignoreButton,
    }

    local methods = {}

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(FRAME_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end
        ApplyIgnoreButtonStyle(self.ignoreButton)
        self.frame.tooltipEncounterData = nil
        self.iconType = "standard"
        self:SetNotification("", {}, "")
        self:SetEncounterProgress(nil)
        self:SetClickCallback(nil)
        self:SetQueueCallback(nil)
        self:SetIgnoreCallback(nil)
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.frame.tooltipEncounterData = nil
        self:SetNotification("", {}, "")
        self:SetEncounterProgress(nil)
        self:SetClickCallback(nil)
        self:SetQueueCallback(nil)
        self:SetIgnoreCallback(nil)
    end

    function methods:SetRoleIconType(iconType)
        self.iconType = iconType == "twich" and "twich" or "standard"
    end

    ---@param dungeonName string
    ---@param roles string[]
    ---@param groupLabel string
    function methods:SetNotification(dungeonName, roles, groupLabel)
        self.dungeonText:SetText(dungeonName or "")
        self.groupText:SetText("")

        local shown = 0
        for _, icon in ipairs(self.roleIcons) do
            icon:Hide()
            icon:SetAtlas(nil)
            icon:SetTexture(nil)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
        end

        for index = #(roles or {}), 1, -1 do
            shown = shown + 1
            local icon = self.roleIcons[shown]
            if not icon then
                break
            end

            if ApplyRoleIconArt(icon, roles[index], self.iconType) then
                icon:Show()
            end
        end
    end

    ---@param progress table|nil
    function methods:SetEncounterProgress(progress)
        if not progress or type(progress.numEncounters) ~= "number" or progress.numEncounters <= 0 then
            self.progressText:SetText("")
            self.frame.tooltipEncounterData = nil
            self.progressFrame:Hide()
            return
        end

        local numCompleted = type(progress.numCompleted) == "number" and progress.numCompleted or 0
        self.progressText:SetText(("%d/%d encounters completed"):format(numCompleted, progress.numEncounters))
        self.frame.tooltipEncounterData = progress.encounters
        self.progressFrame:Show()
    end

    ---@param callback fun(button: string)|nil
    function methods:SetClickCallback(callback)
        self.clickCallback = callback

        self.frame:SetScript("OnClick", function(_, button)
            if self.clickCallback then
                self.clickCallback(button)
            end
        end)
    end

    ---@param callback fun()|nil
    function methods:SetQueueCallback(callback)
        self.queueCallback = callback
        self.queueButton:SetEnabled(callback ~= nil)
        self.queueButton:SetScript("OnClick", function()
            if self.queueCallback then
                self.queueCallback()
            end
        end)
    end

    ---@param callback fun()|nil
    function methods:SetIgnoreCallback(callback)
        self.ignoreCallback = callback
        self.ignoreButton:SetEnabled(callback ~= nil)
        self.ignoreButton:SetScript("OnClick", function()
            if self.ignoreCallback then
                self.ignoreCallback()
            end
        end)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
