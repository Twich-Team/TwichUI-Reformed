--[[
    Datatext providing quick access to saved transmog outfits.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local C_TransmogOutfitInfo = _G.C_TransmogOutfitInfo
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local InCombatLockdown = _G.InCombatLockdown
local ClearCursor = _G.ClearCursor
local PlaceAction = _G.PlaceAction
local PickupAction = _G.PickupAction
local GetActionInfo = _G.GetActionInfo
local UnitClass = _G.UnitClass
local UIErrorsFrame = _G["UIErrorsFrame"]
local C_Timer = _G.C_Timer

local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
local ConfigurationModule = T:GetModule("Configuration", true)
local ConfigurationOptions = ConfigurationModule and ConfigurationModule["Options"] or nil
local DatatextOptions = ConfigurationOptions and ConfigurationOptions.Datatext or nil

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

---@class TransmogDataText : AceEvent-3.0
---@field definition DatatextDefinition
---@field panel ElvUI_DT_Panel
---@field menuList table|nil
---@field flaggedForRebuild boolean
local TDT = DataTextModule:NewModule("TransmogDataText", "AceEvent-3.0")

local DATATEXT_NAME = "TwichUI: Transmog"
local LABEL = "Transmog"
local PLAYER_CLASS = select(2, UnitClass("player"))
local CLOBBER_SLOT = ((PLAYER_CLASS == "DRUID") and 120 or 108) + 10
local ACCENT_COLOR = { 0.96, 0.78, 0.24 }

local function LogTransmogDebug(message, ...)
    if not (DebugConsole and DebugConsole.Logf) then
        return
    end

    pcall(DebugConsole.Logf, DebugConsole, "datatexts", false, "[transmog] " .. message, ...)
end

local function SortOutfits(left, right)
    local leftName = left and left.name and tostring(left.name):lower() or ""
    local rightName = right and right.name and tostring(right.name):lower() or ""
    if leftName == rightName then
        return (tonumber(left and left.outfitID) or 0) < (tonumber(right and right.outfitID) or 0)
    end

    return leftName < rightName
end

local function GetSavedOutfits()
    if not (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo) then
        return {}
    end

    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
    table.sort(outfits, SortOutfits)
    return outfits
end

local function GetActiveOutfitInfo()
    if not (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID) then
        return nil
    end

    local outfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    if not outfitID or outfitID == 0 then
        return nil
    end

    local outfits = GetSavedOutfits()
    for _, outfitInfo in ipairs(outfits) do
        if tonumber(outfitInfo.outfitID) == tonumber(outfitID) then
            return outfitInfo
        end
    end

    return nil
end

local function GetActiveOutfitID()
    if not (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID) then
        return nil
    end

    return C_TransmogOutfitInfo.GetActiveOutfitID()
end

local function OpenWardrobeCollection()
    local transmogUtil = _G["TransmogUtil"]
    local openCollectionUI = transmogUtil and transmogUtil.OpenCollectionUI
    if openCollectionUI then
        local ok, opened = pcall(openCollectionUI)
        LogTransmogDebug("OpenCollectionUI result ok=%s opened=%s", tostring(ok), tostring(opened))
        return ok and opened
    end

    local loadCollectionsUI = _G["CollectionsJournal_LoadUI"]
    if loadCollectionsUI then
        pcall(loadCollectionsUI)
    end

    local toggleCollectionsJournal = _G["ToggleCollectionsJournal"]
    if toggleCollectionsJournal then
        local ok, err = pcall(toggleCollectionsJournal)
        LogTransmogDebug("ToggleCollectionsJournal result ok=%s err=%s", tostring(ok), tostring(err))
        return ok
    end

    LogTransmogDebug("wardrobe collection could not be opened")
    return false
end

local function ShowOutfitError(message)
    if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage and message then
        UIErrorsFrame:AddExternalErrorMessage(message)
    end
end

local function GetBackdropColors()
    local bgR, bgG, bgB, bgA = 0.06, 0.06, 0.08, 0.98
    local borderR, borderG, borderB = 0.25, 0.25, 0.3
    local elvUI = _G["ElvUI"]
    local E = elvUI and elvUI[1]
    if E and E.media then
        if E.media.backdropcolor then
            bgR = E.media.backdropcolor[1] or bgR
            bgG = E.media.backdropcolor[2] or bgG
            bgB = E.media.backdropcolor[3] or bgB
        elseif E.media.backdropfadecolor then
            bgR = E.media.backdropfadecolor[1] or bgR
            bgG = E.media.backdropfadecolor[2] or bgG
            bgB = E.media.backdropfadecolor[3] or bgB
        end

        if E.media.bordercolor then
            borderR = E.media.bordercolor[1] or borderR
            borderG = E.media.bordercolor[2] or borderG
            borderB = E.media.bordercolor[3] or borderB
        end
    end

    return bgR, bgG, bgB, bgA, borderR, borderG, borderB
end

local function CreateBackdrop(frame)
    if frame.backdropApplied then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local bgR, bgG, bgB, bgA, borderR, borderG, borderB = GetBackdropColors()

    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)

    frame.BackgroundFill = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.BackgroundFill:SetAllPoints(frame)
    frame.BackgroundFill:SetColorTexture(bgR, bgG, bgB, math.min(1, math.max(bgA, 0.96)))

    frame.InnerGlow = frame:CreateTexture(nil, "BORDER")
    frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.InnerGlow:SetColorTexture(borderR, borderG, borderB, 0.08)
    frame.backdropApplied = true
end

local function SkinCloseButton(button)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinCloseButton then
        UI.SkinCloseButton(button)
    end
end

local function SkinScrollBar(scrollFrame)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinTwichScrollBar then
        UI.SkinTwichScrollBar(scrollFrame, ACCENT_COLOR, false)
        return
    end

    if UI and UI.SkinScrollBar then
        UI.SkinScrollBar(scrollFrame, ACCENT_COLOR, true, false)
    end
end

local function SkinButton(button)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinTwichButton then
        UI.SkinTwichButton(button, ACCENT_COLOR)
        return
    end

    if UI and UI.SkinButton then
        UI.SkinButton(button)
    end
end

local function GetOutfitDisplayName(outfitInfo)
    local outfitID = tonumber(outfitInfo and outfitInfo.outfitID) or 0
    local name = outfitInfo and outfitInfo.name
    if type(name) == "string" then
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
    end

    if name and name ~= "" then
        return name
    end

    return "Outfit " .. tostring(outfitID)
end

local function GetPopupDB()
    if not (DatatextOptions and DatatextOptions.GetDatatextDB) then
        return nil
    end

    local db = DatatextOptions:GetDatatextDB("transmog")
    if type(db.popup) ~= "table" then
        db.popup = {}
    end

    return db.popup
end

local function HideAllTooltips()
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end

    local tooltip = DataTextModule and DataTextModule.GetActiveDatatextTooltip and
    DataTextModule:GetActiveDatatextTooltip() or nil
    if tooltip and DataTextModule and DataTextModule.HideDatatextTooltip then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

local function IsCursorOutfit(outfitID, cursorType, cursorID)
    return cursorType == "outfit" and tonumber(cursorID) == tonumber(outfitID)
end

local function IsActionOutfit(outfitID, actionType, actionID)
    return actionType == "outfit" and tonumber(actionID) == tonumber(outfitID)
end

local function PositionPopup(frame, anchor)
    local popupDB = GetPopupDB()
    frame:ClearAllPoints()

    if popupDB and popupDB.userPlaced and popupDB.point and popupDB.relativePoint then
        frame:SetPoint(
            popupDB.point,
            UIParent,
            popupDB.relativePoint,
            tonumber(popupDB.x) or 0,
            tonumber(popupDB.y) or 0
        )
        return
    end

    if anchor and anchor.GetCenter and anchor:GetCenter() then
        frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
        return
    end

    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function SavePopupPosition(frame)
    local popupDB = GetPopupDB()
    if not popupDB then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    popupDB.point = point or "CENTER"
    popupDB.relativePoint = relativePoint or point or "CENTER"
    popupDB.x = tonumber(x) or 0
    popupDB.y = tonumber(y) or 0
    popupDB.userPlaced = true
end

function TDT:HidePopup()
    if self.popup then
        HideAllTooltips()
        self.popup:Hide()
    end
end

function TDT:EnsurePopup()
    if self.popup then
        return self.popup
    end

    local frame = CreateFrame("Frame", "TwichUI_TransmogDatatextPopup", UIParent, "BackdropTemplate")
    frame:SetSize(430, 380)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(40)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(popup)
        popup:StopMovingOrSizing()
        SavePopupPosition(popup)
    end)
    CreateBackdrop(frame)
    frame:Hide()

    local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 1 },
    })
    titleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.98)
    titleBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.35)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePopupPosition(frame)
    end)
    frame.TitleBar = titleBar

    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 0, 0)
    titleAccent:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, 0)
    titleAccent:SetHeight(2)
    titleAccent:SetColorTexture(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.95)

    local titleIcon = titleBar:CreateTexture(nil, "OVERLAY")
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleIcon:SetSize(16, 16)
    titleIcon:SetTexture(629532)
    titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    title:SetPoint("RIGHT", titleBar, "RIGHT", -32, 0)
    title:SetJustifyH("LEFT")
    title:SetText("Saved Outfits")
    title:SetTextColor(1, 0.94, 0.82)

    local closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeButton:SetScript("OnClick", function()
        self:HidePopup()
    end)
    SkinCloseButton(closeButton)
    frame.CloseButton = closeButton

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -42)
    subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -42)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.78, 0.8, 0.86)
    subtitle:SetText("Secure outfit actions using a temporary Blizzard action slot")
    frame.subtitle = subtitle

    local contentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -62)
    contentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    contentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    contentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, 0.98)
    contentInset:SetBackdropBorderColor(borderR, borderG, borderB, 0.45)
    frame.ContentInset = contentInset

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentInset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", contentInset, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentInset, "BOTTOMRIGHT", -20, 8)
    SkinScrollBar(scrollFrame)
    frame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:HookScript("OnSizeChanged", function(scroll)
        local availableWidth = math.max(1, (scroll:GetWidth() or 1) - 8)
        scrollChild:SetWidth(availableWidth)
    end)
    frame.scrollChild = scrollChild
    frame.rows = {}

    self.popup = frame
    return frame
end

function TDT:EnsurePopupRow(index)
    local popup = self:EnsurePopup()
    local row = popup.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, popup.scrollChild, "SecureActionButtonTemplate")
    row:SetHeight(42)
    row:SetPoint("LEFT", popup.scrollChild, "LEFT", 0, 0)
    row:SetPoint("RIGHT", popup.scrollChild, "RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp")
    row:EnableMouse(true)
    row:SetAttribute("action", CLOBBER_SLOT)
    row:SetAttribute("useOnKeyDown", false)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(1, 1, 1, 0.025)

    row.inner = row:CreateTexture(nil, "BORDER")
    row.inner:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    row.inner:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    row.inner:SetColorTexture(1, 1, 1, 0.015)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(0.96, 0.78, 0.24, 0.08)

    row.divider = row:CreateTexture(nil, "BORDER")
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 0)
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 0)
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(1, 1, 1, 0.04)

    row.activeGlow = row:CreateTexture(nil, "ARTWORK")
    row.activeGlow:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.activeGlow:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.activeGlow:SetWidth(3)
    row.activeGlow:SetColorTexture(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.85)

    row.iconBackdrop = row:CreateTexture(nil, "BORDER")
    row.iconBackdrop:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.iconBackdrop:SetSize(34, 34)
    row.iconBackdrop:SetColorTexture(0, 0, 0, 0.24)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("CENTER", row.iconBackdrop, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetMaxLines(1)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.status:SetWidth(64)
    row.status:SetJustifyH("RIGHT")
    row.status:SetTextColor(0.86, 0.82, 0.72)

    row.UpdateLayout = function(self, showStatus)
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", self.iconBackdrop, "RIGHT", 12, 0)
        if showStatus then
            self.label:SetPoint("RIGHT", self.status, "LEFT", -8, 0)
        else
            self.label:SetPoint("RIGHT", self, "RIGHT", -10, 0)
        end
    end

    row:UpdateLayout(true)

    row:SetScript("OnEnter", function(self)
        if not self.outfitInfo or not GameTooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(GetOutfitDisplayName(self.outfitInfo), 1, 1, 1, 1, true)
        if self.isActive then
            GameTooltip:AddLine("Active outfit", 0.4, 1, 0.6)
        else
            GameTooltip:AddLine("Click to equip", 0.8, 0.82, 0.9)
        end
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    row:SetScript("PreClick", function(self)
        local outfitID = tonumber(self:GetAttribute("outfit-id"))
        self.__twichuiClobberState = nil
        self:SetAttribute("type", nil)

        if InCombatLockdown and InCombatLockdown() then
            ShowOutfitError(ERR_NOT_IN_COMBAT)
            return
        end

        if not outfitID then
            return
        end

        if not (C_TransmogOutfitInfo and C_TransmogOutfitInfo.PickupOutfit) then
            LogTransmogDebug("pickup api unavailable outfitID=%s", tostring(outfitID))
            return
        end

        ClearCursor()
        C_TransmogOutfitInfo.PickupOutfit(outfitID)

        if not IsCursorOutfit(outfitID, GetCursorInfo()) then
            ClearCursor()
            LogTransmogDebug("pickup failed outfitID=%s", tostring(outfitID))
            return
        end

        self.__twichuiClobberState = GetActionInfo(CLOBBER_SLOT) == nil
        PlaceAction(CLOBBER_SLOT)

        if IsActionOutfit(outfitID, GetActionInfo(CLOBBER_SLOT)) then
            self:SetAttribute("type", "action")
            LogTransmogDebug("prepared secure action outfitID=%s slot=%s", tostring(outfitID), tostring(CLOBBER_SLOT))
        else
            self.__twichuiClobberState = nil
            ClearCursor()
            LogTransmogDebug("place action failed outfitID=%s slot=%s", tostring(outfitID), tostring(CLOBBER_SLOT))
        end
    end)

    row:SetScript("PostClick", function(self)
        local clobberState = self.__twichuiClobberState
        if clobberState == nil then
            self:SetAttribute("type", nil)
            return
        end

        if not (InCombatLockdown and InCombatLockdown()) then
            if clobberState then
                ClearCursor()
                PickupAction(CLOBBER_SLOT)
                ClearCursor()
            else
                PlaceAction(CLOBBER_SLOT)
                ClearCursor()
            end
        end

        self:SetAttribute("type", nil)
        self.__twichuiClobberState = nil
        LogTransmogDebug("secure click complete outfitID=%s", tostring(self:GetAttribute("outfit-id")))

        if self.ownerModule then
            self.ownerModule:HidePopup()
        end
        if C_Timer and C_Timer.After and self.ownerModule then
            C_Timer.After(0, function()
                if self.ownerModule then
                    self.ownerModule.flaggedForRebuild = true
                    self.ownerModule:RefreshPopup()
                end
            end)
        end
    end)

    row.ownerModule = self
    popup.rows[index] = row
    return row
end

function TDT:RefreshPopup()
    local popup = self.popup
    if not popup then
        return
    end

    local outfits = GetSavedOutfits()
    local activeOutfitID = GetActiveOutfitID()
    local contentHeight = 0

    for index, outfitInfo in ipairs(outfits) do
        local row = self:EnsurePopupRow(index)
        local outfitID = tonumber(outfitInfo.outfitID) or 0
        local isActive = tonumber(activeOutfitID) == outfitID
        local outfitName = GetOutfitDisplayName(outfitInfo)

        row.outfitInfo = outfitInfo
        row.isActive = isActive
        row:SetAttribute("outfit-id", outfitID)
        row.icon:SetTexture(outfitInfo.icon)
        row.label:SetText(outfitName)
        row.label:SetTextColor(isActive and 0.98 or 0.94, isActive and 0.98 or 0.96, isActive and 0.78 or 0.98)
        row.status:SetText(isActive and "Active" or "Ready")
        row.status:SetTextColor(isActive and 0.38 or 0.68, isActive and 0.95 or 0.72, isActive and 0.56 or 0.78)
        row.activeGlow:SetShown(isActive)
        row:UpdateLayout(true)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 0, -contentHeight)
        row:SetPoint("RIGHT", popup.scrollChild, "RIGHT", 0, 0)
        row:Show()

        contentHeight = contentHeight + row:GetHeight() + 6
    end

    for index = #outfits + 1, #popup.rows do
        popup.rows[index]:Hide()
        popup.rows[index].outfitInfo = nil
        popup.rows[index].isActive = nil
        popup.rows[index]:SetAttribute("outfit-id", nil)
    end

    if #outfits == 0 then
        popup.subtitle:SetText("No saved outfits available")
    else
        popup.subtitle:SetText("Secure saved outfit actions")
    end

    popup.scrollChild:SetHeight(math.max(1, contentHeight))
end

function TDT:TogglePopup(anchor)
    local popup = self:EnsurePopup()
    if popup:IsShown() then
        self:HidePopup()
        return
    end

    HideAllTooltips()
    PositionPopup(popup, anchor)
    self:RefreshPopup()
    popup:Show()
end

function TDT:Refresh()
    if not self.panel then
        return
    end

    local red, green, blue = DataTextModule:GetElvUIValueColor()
    self.panel.text:SetText(T.Tools.Text.ColorRGB(red, green, blue, LABEL))
end

function TDT:OnEvent(panel, event)
    if not self.panel then
        self.panel = panel
    end

    if event ~= DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE then
        local activeOutfit = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID and
            C_TransmogOutfitInfo.GetActiveOutfitID() or nil
        local viewedOutfit = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID and
            C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID() or nil
        LogTransmogDebug("event=%s active=%s viewed=%s", tostring(event), tostring(activeOutfit), tostring(viewedOutfit))
    end

    if event == DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE then
        self:Refresh()
        return
    end

    self.flaggedForRebuild = true
    if self.popup and self.popup:IsShown() then
        self:RefreshPopup()
    end
    self:Refresh()
end

function TDT:OnClick(panel, button)
    self.panel = panel or self.panel
    HideAllTooltips()

    if button == "RightButton" then
        OpenWardrobeCollection()
        return
    end

    self:TogglePopup(panel)
end

function TDT:OnEnter(panel)
    self.panel = panel or self.panel
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    tooltip:ClearLines()

    local activeOutfit = GetActiveOutfitInfo()
    if activeOutfit then
        tooltip:AddLine("Active Outfit: " .. GetOutfitDisplayName(activeOutfit))
        tooltip:AddLine(" ")
    end

    tooltip:AddLine("Click to open secure outfit popup")
    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Right-click to open the Blizzard wardrobe collection."))
    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY,
        "Popup buttons use a temporary secure action slot to equip outfits."))

    DataTextModule:ShowDatatextTooltip(tooltip)
end

function TDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function TDT:OnInitialize()
    self.definition = {
        name = DATATEXT_NAME,
        prettyName = "Transmog",
        events = {
            DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE,
            "TRANSMOG_OUTFITS_CHANGED",
            "TRANSMOG_DISPLAYED_OUTFIT_CHANGED",
            "TRANSMOGRIFY_OPEN",
            "TRANSMOGRIFY_CLOSE",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end

function TDT:OnEnable()
    self.flaggedForRebuild = true
end
