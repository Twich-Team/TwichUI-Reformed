local AceGUI = LibStub("AceGUI-3.0")
local TwichRx = _G["TwichRx"]
---@type TwichUI|nil
local T = TwichRx and unpack(TwichRx) or nil
---@type TexturesTool|nil
local Textures = T and T.Tools and T.Tools.Textures or nil

local WIDGET_TYPE = "TwichUI_DungeonTrackingNotification"
local Type, Version = WIDGET_TYPE, 1

local FRAME_WIDTH = 300
local BASE_HEIGHT = 80
local BUTTON_HEIGHT = 22
local BUTTON_WIDTH = 120
local BUTTON_SPACING = 10
local ICON_SIZE = 36
local GROUP_ICON_SIZE = 36
local GROUP_ICON_SPACING = 6
local ROLE_BADGE_SIZE = 16
local TEXT_LEFT_OFFSET = 58
local KEYSTONE_ITEM_ID = 180653
local FALLBACK_KEYSTONE_TEXTURE = "Interface\\Icons\\INV_Misc_ShadowEgg"
local FALLBACK_DUNGEON_TEXTURE = "Interface\\EncounterJournal\\UI-EJ-PortraitIcon-Dungeon"
local FALLBACK_RAID_TEXTURE = "Interface\\EncounterJournal\\UI-EJ-PortraitIcon-Raid"
local HEALER_BADGE_TEXTURE = "Interface\\AddOns\\TwichUI_Redux\\Media\\Textures\\Healer.tga"
local TANK_BADGE_TEXTURE = "Interface\\AddOns\\TwichUI_Redux\\Media\\Textures\\Tank.tga"

local ICON_ATLASES = {
    dungeon = {
        "Dungeon",
        "groupfinder-icon-dungeon",
    },
    raid = {
        "Raid",
        "groupfinder-icon-raid",
    },
}

local STATUS_STYLES = {
    completed = {
        status = "DUNGEON COMPLETE",
        color = { 0.32, 0.86, 0.54 },
    },
    ended = {
        status = "DUNGEON ENDED EARLY",
        color = { 0.93, 0.51, 0.2 },
    },
}

local function ResolveKeystoneTexture()
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local texture = C_Item.GetItemIconByID(KEYSTONE_ITEM_ID)
        if texture then
            return texture
        end
    end

    return FALLBACK_KEYSTONE_TEXTURE
end

local function ApplyAtlasOrTexture(texture, atlasCandidates, fallbackTexture)
    if texture.SetAtlas and C_Texture and type(C_Texture.GetAtlasInfo) == "function" and type(atlasCandidates) == "table" then
        for _, atlasName in ipairs(atlasCandidates) do
            if atlasName and C_Texture.GetAtlasInfo(atlasName) then
                texture:SetAtlas(atlasName)
                return
            end
        end
    end

    texture:SetTexture(fallbackTexture)
    if texture.SetTexCoord then
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, BASE_HEIGHT)
    frame:EnableMouse(true)

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(unpack(STATUS_STYLES.completed.color))

    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT", frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture(FALLBACK_DUNGEON_TEXTURE)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_LEFT_OFFSET, -10)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    status:SetJustifyH("LEFT")
    status:SetTextColor(unpack(STATUS_STYLES.completed.color))
    status:SetText(STATUS_STYLES.completed.status)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("Unknown Dungeon")

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(true)
    detail:SetText("Completed in 00:00.")

    local groupIcons = {}
    for index = 1, 5 do
        local groupIcon = CreateFrame("Frame", nil, frame)
        groupIcon:SetSize(GROUP_ICON_SIZE, GROUP_ICON_SIZE)
        if index == 1 then
            groupIcon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
        else
            groupIcon:SetPoint("RIGHT", groupIcons[index - 1], "LEFT", -GROUP_ICON_SPACING, 0)
        end

        local classTexture = groupIcon:CreateTexture(nil, "OVERLAY")
        classTexture:SetAllPoints(groupIcon)

        local roleBadge = groupIcon:CreateTexture(nil, "ARTWORK")
        roleBadge:SetSize(ROLE_BADGE_SIZE, ROLE_BADGE_SIZE)
        roleBadge:SetPoint("BOTTOMRIGHT", groupIcon, "BOTTOMRIGHT", 2, -2)
        roleBadge:Hide()

        groupIcon.classTexture = classTexture
        groupIcon.roleBadge = roleBadge
        groupIcon:Hide()
        groupIcons[index] = groupIcon
    end

    local actionButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    actionButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    actionButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    actionButton:SetText("Leave Group")
    actionButton:Hide()

    if T and T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(actionButton)
    end

    ---@class TwichUI_DungeonTrackingNotificationWidget : AceGUIWidget
    ---@field frame Frame
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field status FontString
    ---@field title FontString
    ---@field detail FontString
    ---@field groupIcons Frame[]
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
        groupIcons = groupIcons,
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

        self:SetNotification("completed", "Unknown Dungeon", "Completed in 00:00.", "dungeon", false)
        self:SetActionCallback(nil)
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self:SetActionCallback(nil)
        self.actionButton:Hide()
        self.title:SetText("")
        self.detail:SetText("")
        for _, groupIcon in ipairs(self.groupIcons) do
            if groupIcon.classTexture then
                groupIcon.classTexture:SetTexture(nil)
            end
            if groupIcon.roleBadge then
                groupIcon.roleBadge:SetTexture(nil)
                groupIcon.roleBadge:Hide()
            end
            groupIcon:Hide()
        end
    end

    function methods:Dismiss()
        local onMouseDown = self.frame and self.frame.GetScript and self.frame:GetScript("OnMouseDown") or nil
        if onMouseDown then
            onMouseDown(self.frame, "RightButton")
            return
        end

        if self.frame then
            self.frame:Hide()
        end
    end

    ---@param callback function|nil
    function methods:SetActionCallback(callback)
        self.actionCallback = callback
    end

    local function ApplyRoleBadge(groupIcon, role)
        if not groupIcon or not groupIcon.roleBadge then
            return
        end

        if role == "HEALER" then
            groupIcon.roleBadge:SetTexture(HEALER_BADGE_TEXTURE)
            groupIcon.roleBadge:Show()
            return
        end

        if role == "TANK" then
            groupIcon.roleBadge:SetTexture(TANK_BADGE_TEXTURE)
            groupIcon.roleBadge:Show()
            return
        end

        groupIcon.roleBadge:SetTexture(nil)
        groupIcon.roleBadge:Hide()
    end

    ---@param groupMembers table[]|nil
    ---@param iconStyle string|nil
    function methods:SetGroupMakeup(groupMembers, iconStyle)
        local shown = 0

        for _, groupIcon in ipairs(self.groupIcons) do
            if groupIcon.classTexture then
                groupIcon.classTexture:SetTexture(nil)
            end
            if groupIcon.roleBadge then
                groupIcon.roleBadge:SetTexture(nil)
                groupIcon.roleBadge:Hide()
            end
            groupIcon:Hide()
        end

        if type(groupMembers) ~= "table" or not Textures or type(Textures.ApplyClassTexture) ~= "function" then
            self.status:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -10)
            return
        end

        for _, groupMember in ipairs(groupMembers) do
            local groupIcon = self.groupIcons[shown + 1]
            if not groupIcon then
                break
            end

            local classToken = type(groupMember) == "table" and groupMember.classToken or groupMember
            local role = type(groupMember) == "table" and groupMember.role or nil

            if Textures:ApplyClassTexture(groupIcon.classTexture, classToken, iconStyle) then
                shown = shown + 1
                ApplyRoleBadge(groupIcon, role)
                groupIcon:Show()
            end
        end

        if shown > 0 then
            self.status:SetPoint("TOPRIGHT", self.groupIcons[shown], "TOPLEFT", -8, 0)
        else
            self.status:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -10)
        end
    end

    ---@param state "completed"|"ended"|nil
    ---@param titleText string|nil
    ---@param detailText string|nil
    ---@param iconKind "dungeon"|"raid"|"keystone"|nil
    ---@param showButton boolean|nil
    ---@param groupMembers table[]|nil
    ---@param iconStyle string|nil
    function methods:SetNotification(state, titleText, detailText, iconKind, showButton, groupMembers, iconStyle)
        local style = STATUS_STYLES[state or "completed"] or STATUS_STYLES.completed

        self.status:SetText(style.status)
        self.status:SetTextColor(unpack(style.color))
        self.accent:SetColorTexture(unpack(style.color))
        self.title:SetText(titleText or "Unknown Dungeon")
        self.detail:SetText(detailText or "")

        iconKind = iconKind or "dungeon"
        if iconKind == "keystone" then
            self.icon:SetTexture(ResolveKeystoneTexture())
            if self.icon.SetTexCoord then
                self.icon:SetTexCoord(0, 1, 0, 1)
            end
        elseif iconKind == "raid" then
            ApplyAtlasOrTexture(self.icon, ICON_ATLASES.raid, FALLBACK_RAID_TEXTURE)
        else
            ApplyAtlasOrTexture(self.icon, ICON_ATLASES.dungeon, FALLBACK_DUNGEON_TEXTURE)
        end

        if self.iconBackdrop and self.iconBackdrop.SetBackdropBorderColor then
            self.iconBackdrop:SetBackdropBorderColor(style.color[1], style.color[2], style.color[3], 1)
        end

        self.status:ClearAllPoints()
        self.status:SetPoint("TOPLEFT", self.frame, "TOPLEFT", TEXT_LEFT_OFFSET, -10)
        self:SetGroupMakeup(groupMembers, iconStyle)

        showButton = showButton == true
        if showButton then
            self.actionButton:Show()
        else
            self.actionButton:Hide()
        end

        UpdateDetailAnchors(self, showButton)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    actionButton:SetScript("OnClick", function()
        if widget.actionCallback then
            widget.actionCallback(widget)
        end
    end)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
