---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class TooltipModule : AceModule, AceEvent-3.0, AceHook-3.0
local TooltipModule = T:NewModule("Tooltip", "AceEvent-3.0", "AceHook-3.0")

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local GameTooltipStatusBar = _G.GameTooltipStatusBar
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local CUSTOM_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS
local GetGuildInfo = _G.GetGuildInfo
local UnitClass = _G.UnitClass
local UnitIsAFK = _G.UnitIsAFK
local UnitCanAttack = _G.UnitCanAttack
local UnitIsDND = _G.UnitIsDND
local UnitFactionGroup = _G.UnitFactionGroup
local UnitIsFriend = _G.UnitIsFriend
local UnitIsPVP = _G.UnitIsPVP
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsUnit = _G.UnitIsUnit
local InCombatLockdown = _G.InCombatLockdown
local GetInventoryItemAverageItemLevel = _G.GetInventoryItemAverageItemLevel
local GetAverageItemLevel = _G.GetAverageItemLevel
local GetInspectSpecialization = _G.GetInspectSpecialization
local NotifyInspect = _G.NotifyInspect
local ClearInspectPlayer = _G.ClearInspectPlayer
local CanInspect = _G.CanInspect
local UnitGUID = _G.UnitGUID
local GetSpecializationInfoByID = _G.GetSpecializationInfoByID
local BreakUpLargeNumbers = _G.BreakUpLargeNumbers
local C_PlayerInfo = _G.C_PlayerInfo
local C_PaperDollInfo = _G.C_PaperDollInfo
local C_Item = _G.C_Item
local C_Timer = _G.C_Timer
local C_TransmogCollection = _G.C_TransmogCollection
local Enum = _G.Enum
local TooltipDataProcessor = _G.TooltipDataProcessor
local LE_ITEM_CLASS_WEAPON = _G.LE_ITEM_CLASS_WEAPON or 2
local LE_ITEM_CLASS_ARMOR = _G.LE_ITEM_CLASS_ARMOR or 4
local math_max = math.max
local math_floor = math.floor
local math_min = math.min
local ipairs = ipairs
local pairs = pairs
local string_format = string.format
local table_concat = table.concat
local table_insert = table.insert
local tostring = tostring

local DEBUG_SOURCE_KEY = "tooltip"
local NAME_CLASS_ICON_SIZE = 18
local ENRICHMENT_RETRY_DELAYS = { 0.15, 0.45, 0.90 }
local MAX_NAMEPLATE_UNITS = 40
local MAX_PARTY_MEMBERS = 4
local MAX_RAID_MEMBERS = 40

local FACTION_ICONS = {
    Horde = "|TInterface\\TargetingFrame\\UI-PVP-Horde:14:14:0:0|t",
    Alliance = "|TInterface\\TargetingFrame\\UI-PVP-Alliance:14:14:0:0|t",
}

local MANAGED_TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "EmbeddedItemTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "WorldMapTooltip",
}

local ANCHORABLE_TOOLTIP_NAMES = {
    GameTooltip = true,
}

local THEME_KEYS = {
    primaryColor = true,
    backgroundColor = true,
    borderColor = true,
    textColor = true,
    backgroundAlpha = true,
    borderAlpha = true,
    statusBarTexture = true,
    globalFont = true,
    classIconStyle = true,
}

local function RoundPixel(value)
    return math_floor((tonumber(value) or 0) + 0.5)
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3, result4, result5 = pcall(func, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3, result4, result5
end

local function SafeBooleanValue(value)
    return value and true or false
end

local function SafeBooleanCall(func, ...)
    return SafeBooleanValue(SafeCall(func, ...))
end

local function SafeUnitIsPlayer(unit)
    return SafeBooleanCall(UnitIsPlayer, unit)
end

local function SafeUnitClass(unit)
    return SafeCall(UnitClass, unit)
end

local function SafeUnitFactionGroup(unit)
    return SafeCall(UnitFactionGroup, unit)
end

local function SafeUnitIsUnit(unit, otherUnit)
    return SafeBooleanCall(UnitIsUnit, unit, otherUnit)
end

local function SafeUnitCanAttack(attacker, unit)
    return SafeBooleanCall(UnitCanAttack, attacker, unit)
end

local function SafeUnitIsFriend(unit, otherUnit)
    return SafeBooleanCall(UnitIsFriend, unit, otherUnit)
end

local function SafeTooltipUnit(frame)
    if not frame or type(frame.GetUnit) ~= "function" then
        return nil
    end

    local _, unit = SafeCall(frame.GetUnit, frame)
    return unit
end

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function GetThemeColor(key, fallback)
    local theme = GetThemeModule()
    local getColor = theme and theme["GetColor"] or nil
    if theme and type(getColor) == "function" then
        local color = getColor(theme, key)
        if type(color) == "table" then
            return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
        end
    end

    return fallback[1], fallback[2], fallback[3]
end

local function GetThemeValue(key, fallback)
    local theme = GetThemeModule()
    local getValue = theme and theme["Get"] or nil
    if theme and type(getValue) == "function" then
        local value = getValue(theme, key)
        if value ~= nil then
            return value
        end
    end

    return fallback
end

local function ResolveFontPath()
    local path = STANDARD_TEXT_FONT
    local theme = GetThemeModule()
    local LSM = T.Libs and T.Libs.LSM
    local getValue = theme and theme["Get"] or nil
    if theme and LSM and type(getValue) == "function" then
        local fontKey = getValue(theme, "globalFont")
        if fontKey and fontKey ~= "" and fontKey ~= "__default" then
            local ok, fetched = pcall(LSM.Fetch, LSM, "font", fontKey)
            if ok and type(fetched) == "string" and fetched ~= "" then
                path = fetched
            end
        end
    end
    return path
end

local function ResolveStatusBarTexture()
    local theme = GetThemeModule()
    local LSM = T.Libs and T.Libs.LSM
    local getValue = theme and theme["Get"] or nil
    if theme and LSM and type(getValue) == "function" then
        local textureKey = getValue(theme, "statusBarTexture")
        if textureKey and textureKey ~= "" then
            local ok, fetched = pcall(LSM.Fetch, LSM, "statusbar", textureKey)
            if ok and type(fetched) == "string" and fetched ~= "" then
                return fetched
            end
        end
    end
end

local function GetOptions()
    local configurationModule = T:GetModule("Configuration") --[[@as any]]
    return configurationModule and configurationModule.Options and configurationModule.Options.Tooltip or nil
end

local function GetTexturesTool()
    return T.Tools and T.Tools.Textures or nil
end

local function GetDebugConsole()
    return T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil
end

local function SafeDebugString(value)
    if value == nil then
        return "nil"
    end

    return tostring(value)
end

local function NormalizeColorByte(value)
    local numeric = tonumber(value) or 1
    if numeric < 0 then
        numeric = 0
    elseif numeric > 1 then
        numeric = 1
    end

    return math_floor((numeric * 255) + 0.5)
end

local function ColorizeText(text, red, green, blue)
    if not text or text == "" then
        return ""
    end

    return string_format("|cff%02x%02x%02x%s|r", NormalizeColorByte(red), NormalizeColorByte(green),
        NormalizeColorByte(blue), text)
end

local function CountTextureMarkup(text)
    if type(text) ~= "string" or text == "" then
        return 0
    end

    local count = 0
    for _ in text:gmatch("|T") do
        count = count + 1
    end

    return count
end

local function StripTooltipMarkup(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end

    local stripped = text
    stripped = stripped:gsub("|T.-|t", "")
    stripped = stripped:gsub("|c%x%x%x%x%x%x%x%x", "")
    stripped = stripped:gsub("|r", "")
    stripped = stripped:gsub("|H.-|h(.-)|h", "%1")
    stripped = stripped:gsub("|A.-|a", "")
    return stripped
end

local function TrimTooltipText(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end

    return text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " ")
end

local function RemovePlainSubstring(text, target)
    if type(text) ~= "string" or text == "" or type(target) ~= "string" or target == "" then
        return text or ""
    end

    local result = text
    local startIndex, endIndex = result:find(target, 1, true)
    while startIndex do
        result = result:sub(1, startIndex - 1) .. result:sub(endIndex + 1)
        startIndex, endIndex = result:find(target, 1, true)
    end

    return result
end

local function IsPlayerStatLineText(text)
    local stripped = StripTooltipMarkup(text)
    if type(stripped) ~= "string" or stripped == "" then
        return false
    end

    return stripped:find("iLvl ", 1, true) == 1
        or stripped:find("[AFK]", 1, true) ~= nil
        or stripped:find("[DND]", 1, true) ~= nil
        or stripped:find("[PVP]", 1, true) ~= nil
end

local function SafeUnitExists(unit)
    return SafeBooleanCall(_G.UnitExists, unit)
end

local function EstimateTooltipTextWidth(text)
    local stripped = StripTooltipMarkup(text)
    if stripped == "" then
        return 0
    end

    local glyphCount = #stripped
    local wideCount = 0
    for char in stripped:gmatch(".") do
        if char:match("[%u%W]") then
            wideCount = wideCount + 1
        end
    end

    return (glyphCount * 6) + (wideCount * 2)
end

function TooltipModule:GetManagedFrames()
    if self.managedFrames then
        return self.managedFrames
    end

    self.managedFrames = {}
    for _, name in ipairs(MANAGED_TOOLTIP_NAMES) do
        local frame = _G[name]
        if frame then
            self.managedFrames[#self.managedFrames + 1] = frame
        end
    end

    return self.managedFrames
end

function TooltipModule:CreateAnchor()
    if self.anchor then
        return self.anchor
    end

    local anchor = CreateFrame("Frame", "TwichUITooltipAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(220, 26)
    anchor:SetFrameStrata("TOOLTIP")
    anchor:SetClampedToScreen(true)
    anchor:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    anchor.Accent = anchor:CreateTexture(nil, "BORDER")
    anchor.Accent:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
    anchor.Accent:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 1, 1)
    anchor.Accent:SetWidth(4)

    anchor.Glow = anchor:CreateTexture(nil, "BACKGROUND")
    anchor.Glow:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
    anchor.Glow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, 1)

    anchor.Label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.Label:SetPoint("LEFT", anchor, "LEFT", 12, 0)
    anchor.Label:SetPoint("RIGHT", anchor, "RIGHT", -12, 0)
    anchor.Label:SetJustifyH("LEFT")
    anchor.Label:SetText("Tooltip Anchor")

    self.anchor = anchor
    self:ApplyAnchorTheme()
    self:ApplyAnchorPosition()
    self:UpdateAnchorVisibility()
    return anchor
end

function TooltipModule:ApplyAnchorTheme()
    if not self.anchor then
        return
    end

    local backgroundR, backgroundG, backgroundB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    local textR, textG, textB = GetThemeColor("textColor", { 1.00, 0.95, 0.85 })
    local backgroundAlpha = tonumber(GetThemeValue("backgroundAlpha", 0.94)) or 0.94
    local borderAlpha = tonumber(GetThemeValue("borderAlpha", 0.85)) or 0.85

    self.anchor:SetBackdropColor(backgroundR, backgroundG, backgroundB, math_max(0.60, backgroundAlpha))
    self.anchor:SetBackdropBorderColor(borderR, borderG, borderB, math_max(0.80, borderAlpha))
    self.anchor.Accent:SetColorTexture(accentR, accentG, accentB, 0.95)
    self.anchor.Glow:SetColorTexture(accentR, accentG, accentB, 0.10)
    self.anchor.Label:SetTextColor(textR, textG, textB, 0.96)
    self.anchor.Label:SetFont(ResolveFontPath(), 11, "")
end

function TooltipModule:ApplyAnchorPosition()
    local anchor = self:CreateAnchor()
    local options = GetOptions()
    local x = options and options.GetAnchorX and options:GetAnchorX() or 1050
    local y = options and options.GetAnchorY and options:GetAnchorY() or 260
    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function TooltipModule:UpdateAnchorVisibility()
    if not self.anchor then
        return
    end

    local options = GetOptions()
    local showAnchor = false
    if options and options:GetEnabled() then
        local anchorMode = options:GetAnchorMode()
        local locked = options:GetAnchorLocked()
        local moversActive = _G.TwichMoverModule and _G.TwichMoverModule._active == true
        showAnchor = moversActive or (anchorMode == "fixed" and not locked)
    end

    if showAnchor then
        self.anchor:Show()
    else
        self.anchor:Hide()
    end
end

function TooltipModule:StoreOriginalFont(fontString)
    if not fontString or fontString.__tuiTooltipOriginalFont then
        return
    end

    local path, size, flags = fontString:GetFont()
    local shadowX, shadowY = fontString:GetShadowOffset()
    fontString.__tuiTooltipOriginalFont = {
        path = path,
        size = size,
        flags = flags,
        shadowX = shadowX,
        shadowY = shadowY,
    }
end

function TooltipModule:RestoreFont(fontString)
    if not fontString or not fontString.__tuiTooltipOriginalFont then
        return
    end

    local original = fontString.__tuiTooltipOriginalFont
    fontString:SetFont(original.path or STANDARD_TEXT_FONT, original.size or 12, original.flags or "")
    fontString:SetShadowOffset(original.shadowX or 0, original.shadowY or 0)
end

function TooltipModule:GetClassColor(classToken)
    local colorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local classColor = colorTable and colorTable[classToken or ""]
    if classColor then
        return classColor.r or 1, classColor.g or 1, classColor.b or 1
    end
end

function TooltipModule:IsFrameObject(frame)
    return frame and type(frame.GetObjectType) == "function" and type(frame.HookScript) == "function"
end

function TooltipModule:HasScript(frame, scriptName)
    if not self:IsFrameObject(frame) or type(frame.GetScript) ~= "function" then
        return false
    end

    local ok, script = pcall(frame.GetScript, frame, scriptName)
    return ok and script ~= nil
end

function TooltipModule:GetTooltipLine(frame, index, side)
    if not frame or type(frame.GetName) ~= "function" then
        return nil
    end

    local name = frame:GetName()
    if not name then
        return nil
    end

    return _G[string.format("%sText%s%d", name, side or "Left", index)]
end

function TooltipModule:TooltipHasLine(frame, text)
    if not frame or type(text) ~= "string" or text == "" then
        return false
    end

    local lines = frame.NumLines and frame:NumLines() or 0
    for index = 1, lines do
        local left = self:GetTooltipLine(frame, index, "Left")
        if left and left.GetText and left:GetText() == text then
            return true
        end

        local right = self:GetTooltipLine(frame, index, "Right")
        if right and right.GetText and right:GetText() == text then
            return true
        end
    end

    return false
end

function TooltipModule:FindTooltipLineIndex(frame, predicate)
    if not frame or type(predicate) ~= "function" then
        return nil, nil
    end

    local lines = frame.NumLines and frame:NumLines() or 0
    for index = 1, lines do
        local left = self:GetTooltipLine(frame, index, "Left")
        local text = left and left.GetText and left:GetText() or nil
        if predicate(text, index) then
            return index, left
        end
    end

    return nil, nil
end

function TooltipModule:SetTooltipLeftText(frame, index, text, red, green, blue)
    local line = self:GetTooltipLine(frame, index, "Left")
    if not line or not line.SetText or type(text) ~= "string" or text == "" then
        return false
    end

    line:SetText(text)
    if red and green and blue and line.SetTextColor then
        line:SetTextColor(red, green, blue)
    end

    return true
end

function TooltipModule:ClearTooltipLine(frame, index)
    local leftLine = self:GetTooltipLine(frame, index, "Left")
    if leftLine and leftLine.SetText then
        leftLine:SetText("")
    end

    local rightLine = self:GetTooltipLine(frame, index, "Right")
    if rightLine and rightLine.SetText then
        rightLine:SetText("")
    end
end

function TooltipModule:HasTexturePrefix(text)
    return type(text) == "string" and text:find("|T", 1, true) ~= nil
end

function TooltipModule:AppendUniqueSuffix(text, suffix, separator)
    if type(text) ~= "string" or text == "" or type(suffix) ~= "string" or suffix == "" then
        return text
    end

    if text:find(suffix, 1, true) then
        return text
    end

    return text .. (separator or " ") .. suffix
end

function TooltipModule:FormatNumber(value)
    if type(value) ~= "number" then
        return tostring(value or "")
    end

    if type(BreakUpLargeNumbers) == "function" then
        return BreakUpLargeNumbers(math_floor(value + 0.5))
    end

    return tostring(math_floor(value + 0.5))
end

function TooltipModule:IsDebugEnabled()
    local options = GetOptions()
    return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
end

function TooltipModule:LogDebugf(shouldShow, messageFormat, ...)
    local console = GetDebugConsole()
    if not console or type(console.Logf) ~= "function" or not self:IsDebugEnabled() then
        return false
    end

    return console:Logf(DEBUG_SOURCE_KEY, shouldShow, messageFormat, ...)
end

function TooltipModule:GetMythicPlusSummary(unit)
    if not unit or not C_PlayerInfo or type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) ~= "function" then
        return nil, nil
    end

    local lookupTokens = { unit }
    if unit ~= "mouseover" then
        lookupTokens[#lookupTokens + 1] = "mouseover"
    end

    for _, token in ipairs(lookupTokens) do
        local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, token)
        if ok and type(summary) == "table" then
            return summary, token
        end
    end

    return nil, nil
end

function TooltipModule:GetOverallMythicScore(summary, unit)
    if type(summary) == "table" and type(summary.currentSeasonScore) == "number" and summary.currentSeasonScore > 0 then
        return summary.currentSeasonScore
    end

    if unit and SafeUnitIsUnit(unit, "player") and C_ChallengeMode and type(C_ChallengeMode.GetOverallDungeonScore) == "function" then
        local overallScore = SafeCall(C_ChallengeMode.GetOverallDungeonScore)
        if type(overallScore) == "number" and overallScore > 0 then
            return overallScore
        end
    end

    return nil
end

function TooltipModule:BuildPlayerDetailState(unit)
    local state = {
        unit = unit,
        isPlayer = unit and SafeUnitIsPlayer(unit) or false,
        statusBadges = {},
    }

    if not state.isPlayer then
        return state
    end

    state.guid = SafeCall(UnitGUID, unit)
    state.className, state.classToken = SafeUnitClass(unit)
    state.factionName = SafeUnitFactionGroup(unit)

    local specID = SafeCall(GetInspectSpecialization, unit)
    if specID and specID > 0 then
        local _, specName, _, _, roleName = GetSpecializationInfoByID(specID)
        state.specID = specID
        state.specName = specName
        state.roleName = roleName == "DAMAGER" and "DPS" or roleName
    end

    local guildName, guildRankName = SafeCall(GetGuildInfo, unit)
    if guildName ~= nil or guildRankName ~= nil then
        state.guildName = guildName
        state.guildRankName = guildRankName
    end

    local summary, summaryToken = self:GetMythicPlusSummary(unit)
    state.mythicSummary = summary
    state.mythicSummaryToken = summaryToken
    state.mythicScore = self:GetOverallMythicScore(summary, unit)
    state.itemLevel = self:GetPlayerEquippedItemLevel(unit)
    state.classIconMarkup = self:GetClassIconMarkup(state.classToken, 14)
    state.nameClassIconMarkup = self:GetClassIconMarkup(state.classToken, NAME_CLASS_ICON_SIZE)
    state.hasClassIconMarkup = type(state.classIconMarkup) == "string" and state.classIconMarkup ~= ""

    if state.guid then
        self.mythicScoreCache = self.mythicScoreCache or {}
        if type(state.mythicScore) == "number" and state.mythicScore > 0 then
            self.mythicScoreCache[state.guid] = state.mythicScore
        else
            local cachedScore = self.mythicScoreCache[state.guid]
            if type(cachedScore) == "number" and cachedScore > 0 then
                state.mythicScore = cachedScore
            end
        end
    end

    if SafeBooleanCall(UnitIsAFK, unit) then
        table_insert(state.statusBadges, ColorizeText("[AFK]", 1.00, 0.48, 0.48))
    end
    if SafeBooleanCall(UnitIsDND, unit) then
        table_insert(state.statusBadges, ColorizeText("[DND]", 1.00, 0.75, 0.28))
    end
    if SafeBooleanCall(UnitIsPVP, unit) then
        table_insert(state.statusBadges, ColorizeText("[PVP]", 0.88, 0.34, 0.42))
    end

    return state
end

function TooltipModule:GetCachedPlayerDetailState(frame)
    if not frame then
        return nil
    end

    local state = frame.__tuiTooltipPlayerState
    if type(state) ~= "table" or not state.isPlayer then
        return nil
    end

    return state
end

function TooltipModule:SetCachedPlayerDetailState(frame, state)
    if not frame then
        return
    end

    if type(state) == "table" and state.isPlayer then
        frame.__tuiTooltipPlayerState = state
    else
        frame.__tuiTooltipPlayerState = nil
    end
end

function TooltipModule:GetMythicScoreColor(score)
    if type(score) ~= "number" then
        return 0.65, 0.65, 0.65
    elseif score >= 3000 then
        return 1.00, 0.50, 0.00
    elseif score >= 2500 then
        return 0.85, 0.40, 1.00
    elseif score >= 2000 then
        return 0.20, 0.75, 1.00
    elseif score >= 1500 then
        return 0.40, 1.00, 0.40
    end

    return 0.65, 0.65, 0.65
end

function TooltipModule:GetResolvedClassIconStyle()
    local options = GetOptions()
    local style = options and options.GetClassIconStyle and options:GetClassIconStyle() or "global"
    if style and style ~= "global" then
        return style
    end

    local theme = GetThemeModule()
    if theme and type(theme.Get) == "function" then
        return theme:Get("classIconStyle") or "default"
    end

    return "default"
end

function TooltipModule:GetClassIconMarkup(classToken, size)
    local options = GetOptions()
    if not options or not options:GetShowClassIcon() then
        return nil
    end

    local textures = GetTexturesTool()
    if not textures or type(textures.GetClassTextureString) ~= "function" then
        return nil
    end

    return textures:GetClassTextureString(classToken, size or 14, self:GetResolvedClassIconStyle())
end

function TooltipModule:GetPlayerEquippedItemLevel(unit)
    if unit and SafeUnitIsUnit(unit, "player") then
        if type(GetInventoryItemAverageItemLevel) == "function" then
            local _, equipped = GetInventoryItemAverageItemLevel()
            if type(equipped) == "number" and equipped > 0 then
                return equipped
            end
        end

        if type(GetAverageItemLevel) == "function" then
            local _, equipped = GetAverageItemLevel()
            if type(equipped) == "number" and equipped > 0 then
                return equipped
            end
        end
    end

    local guid = unit and UnitGUID and UnitGUID(unit) or nil
    local cachedInspect = guid and self.inspectItemLevelCache and self.inspectItemLevelCache[guid] or nil
    if type(cachedInspect) == "number" and cachedInspect > 0 then
        return cachedInspect
    end

    if C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" and unit then
        local inspectUnit = guid and
        (self:GetInspectableUnitToken(unit, guid) or self:ResolveUnitTokenForGUID(unit, guid)) or unit
        local equipped = inspectUnit and SafeCall(C_PaperDollInfo.GetInspectItemLevel, inspectUnit) or nil
        if type(equipped) == "number" and equipped > 0 then
            if guid then
                self.inspectItemLevelCache = self.inspectItemLevelCache or {}
                self.inspectItemLevelCache[guid] = equipped
            end
            return equipped
        end
    end

    return nil
end

function TooltipModule:DoesUnitMatchGUID(unit, guid)
    if not unit or not guid or not SafeUnitExists(unit) or type(UnitGUID) ~= "function" then
        return false
    end

    return SafeCall(UnitGUID, unit) == guid
end

function TooltipModule:ResolveUnitTokenForGUID(preferredUnit, guid)
    if not guid then
        return nil
    end

    local staticCandidates = { "mouseover", "target", "focus" }
    for _, candidate in ipairs(staticCandidates) do
        if self:DoesUnitMatchGUID(candidate, guid) then
            return candidate
        end
    end

    for index = 1, MAX_PARTY_MEMBERS do
        local candidate = "party" .. index
        if self:DoesUnitMatchGUID(candidate, guid) then
            return candidate
        end
    end

    for index = 1, MAX_RAID_MEMBERS do
        local candidate = "raid" .. index
        if self:DoesUnitMatchGUID(candidate, guid) then
            return candidate
        end
    end

    if preferredUnit and self:DoesUnitMatchGUID(preferredUnit, guid) then
        return preferredUnit
    end

    for index = 1, MAX_NAMEPLATE_UNITS do
        local candidate = "nameplate" .. index
        if self:DoesUnitMatchGUID(candidate, guid) then
            return candidate
        end
    end

    return nil
end

function TooltipModule:GetInspectableUnitToken(unit, guid)
    local inspectUnit = self:ResolveUnitTokenForGUID(unit, guid)
    if not inspectUnit then
        return nil
    end

    local canInspect = SafeCall(CanInspect, inspectUnit, false)
    if canInspect == nil then
        canInspect = SafeCall(CanInspect, inspectUnit)
    end

    if canInspect then
        return inspectUnit
    end

    return nil
end

function TooltipModule:RequestInspectData(unit)
    if not unit or SafeUnitIsUnit(unit, "player") then
        return
    end

    if type(CanInspect) ~= "function" or type(NotifyInspect) ~= "function" or type(UnitGUID) ~= "function" then
        return
    end

    local guid = UnitGUID(unit)
    if not guid or (self.inspectItemLevelCache and self.inspectItemLevelCache[guid]) then
        return
    end

    if self.pendingInspectGUID == guid then
        return
    end

    local inspectUnit = self:GetInspectableUnitToken(unit, guid)
    if not inspectUnit then
        return
    end

    self.pendingInspectGUID = guid
    self.pendingInspectUnit = unit
    self.pendingInspectToken = inspectUnit
    SafeCall(NotifyInspect, inspectUnit)
end

function TooltipModule:INSPECT_READY(_, guid)
    if not guid then
        return
    end

    if self.pendingInspectGUID ~= guid then
        return
    end

    local unit = self:ResolveUnitTokenForGUID(self.pendingInspectUnit or self.pendingInspectToken, guid)
    local itemLevel = unit and C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" and
        SafeCall(C_PaperDollInfo.GetInspectItemLevel, unit) or nil

    if (type(itemLevel) ~= "number" or itemLevel <= 0) and GameTooltip and GameTooltip:IsShown() then
        local tooltipUnit = SafeTooltipUnit(GameTooltip)
        if self:DoesUnitMatchGUID(tooltipUnit, guid) and C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" then
            itemLevel = SafeCall(C_PaperDollInfo.GetInspectItemLevel, tooltipUnit)
            unit = tooltipUnit or unit
        end
    end

    if type(itemLevel) == "number" and itemLevel > 0 then
        self.inspectItemLevelCache = self.inspectItemLevelCache or {}
        self.inspectItemLevelCache[guid] = itemLevel
    end

    self.pendingInspectGUID = nil
    self.pendingInspectUnit = nil
    self.pendingInspectToken = nil
    if type(ClearInspectPlayer) == "function" then
        SafeCall(ClearInspectPlayer)
    end

    if GameTooltip and GameTooltip:IsShown() then
        local unitOnTooltip = SafeTooltipUnit(GameTooltip)
        if unitOnTooltip and UnitGUID and UnitGUID(unitOnTooltip) == guid then
            self:ScheduleStyleFrame(GameTooltip, "inspect-ready")
        end
    end
end

function TooltipModule:PlayFadeIn(frame)
    local options = GetOptions()
    if not frame or not options or not options:GetEnableFadeIn() then
        return
    end

    if frame.__tuiTooltipFadePlayed == true then
        frame:SetAlpha(1)
        return
    end

    if type(frame.CreateAnimationGroup) ~= "function" then
        return
    end

    local animation = frame.TwichUITooltipFadeIn
    if not animation then
        animation = frame:CreateAnimationGroup()
        local alpha = animation:CreateAnimation("Alpha")
        alpha:SetOrder(1)
        animation._alpha = alpha
        animation:SetScript("OnFinished", function(owner)
            owner:GetParent():SetAlpha(1)
        end)
        animation:SetScript("OnStop", function(owner)
            owner:GetParent():SetAlpha(1)
        end)
        frame.TwichUITooltipFadeIn = animation
    end

    animation:Stop()
    animation._alpha:SetDuration(0.12)
    animation._alpha:SetFromAlpha(0)
    animation._alpha:SetToAlpha(1)
    frame.__tuiTooltipFadePlayed = true
    frame:SetAlpha(0)
    animation:Play()
end

function TooltipModule:ApplyItemBorder(frame)
    local options = GetOptions()
    if not options or not options:GetUseItemQualityBorder() or not frame or type(frame.GetItem) ~= "function" or not C_Item then
        return
    end

    local _, itemLink = frame:GetItem()
    if not itemLink then
        return
    end

    local _, _, quality = C_Item.GetItemInfo(itemLink)
    local qualityColor = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if not qualityColor then
        return
    end

    local chrome = self:EnsureFrameChrome(frame)
    self:SetChromeBorderColor(chrome, qualityColor.r or 1, qualityColor.g or 1, qualityColor.b or 1, 0.72)
    chrome.Accent:SetColorTexture(qualityColor.r or 1, qualityColor.g or 1, qualityColor.b or 1,
        options:GetShowAccent() and 0.95 or 0)
    chrome.Glow:SetColorTexture(qualityColor.r or 1, qualityColor.g or 1, qualityColor.b or 1,
        options:GetShowAccent() and 0.10 or 0)
end

function TooltipModule:AppendItemAppearance(frame)
    local options = GetOptions()
    if not options or not options:GetShowTransmogStatus() or not frame or type(frame.GetItem) ~= "function" or not C_Item or not C_TransmogCollection or type(C_TransmogCollection.PlayerHasTransmogByItemInfo) ~= "function" then
        return
    end

    local _, itemLink = frame:GetItem()
    if not itemLink then
        return
    end

    local itemID, _, _, itemEquipLoc, _, itemClassID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID or not itemClassID then
        return
    end

    if itemClassID ~= LE_ITEM_CLASS_WEAPON and itemClassID ~= LE_ITEM_CLASS_ARMOR then
        return
    end

    if itemEquipLoc == "INVTYPE_TRINKET" or itemEquipLoc == "INVTYPE_FINGER" or itemEquipLoc == "INVTYPE_NECK" then
        return
    end

    if self:TooltipHasLine(frame, "Appearance: Collected") or self:TooltipHasLine(frame, "Appearance: Not Collected") then
        return
    end

    local ok, collected = pcall(C_TransmogCollection.PlayerHasTransmogByItemInfo, itemID)
    if not ok or collected == nil then
        return
    end

    frame:AddLine(" ")
    if SafeBooleanValue(collected) then
        frame:AddLine("Appearance: Collected", 0.42, 0.89, 0.63)
    else
        frame:AddLine("Appearance: Not Collected", 0.96, 0.74, 0.22)
    end
end

function TooltipModule:AppendPlayerDetailState(frame, state)
    local options = GetOptions()
    if not options or not options:GetShowPlayerDetails() or not frame or type(state) ~= "table" or not state.isPlayer then
        return
    end

    self.lastPlayerDetailState = state

    local classColorR, classColorG, classColorB = self:GetClassColor(state.classToken)

    if options:GetShowGuildRank() and state.guildName and state.guildRankName and state.guildRankName ~= "" then
        local guildIndex, guildLine = self:FindTooltipLineIndex(frame, function(text)
            return text == state.guildName
        end)
        if guildIndex and guildLine then
            local guildText = guildLine:GetText() or state.guildName
            guildText = self:AppendUniqueSuffix(guildText, "(" .. state.guildRankName .. ")", " ")
            self:SetTooltipLeftText(frame, guildIndex, guildText, 0.66, 0.70, 0.76)
        end
    end

    if state.className and state.className ~= "" then
        local classIndex, classLine = self:FindTooltipLineIndex(frame, function(text)
            return type(text) == "string" and (text:find(state.className, 1, true) ~= nil
                or (state.specName and text:find(state.specName, 1, true) ~= nil))
        end)
        if classIndex and classLine then
            local classText = TrimTooltipText(classLine:GetText() or "")
            classText = classText:gsub("^|T.-|t%s*", "")
            classText = TrimTooltipText(RemovePlainSubstring(classText, state.className))

            if state.specName and state.specName ~= "" and classText == "" then
                classText = state.specName
            end

            if state.roleName and state.roleName ~= "" and classText ~= "" and not classText:find(state.roleName, 1, true) then
                classText = classText .. "  |cff556070•|r  " .. ColorizeText(state.roleName, 0.72, 0.78, 0.90)
            end

            if classText ~= "" then
                self:SetTooltipLeftText(frame, classIndex, classText, classColorR or 0.76, classColorG or 0.78,
                    classColorB or 0.84)
            else
                self:ClearTooltipLine(frame, classIndex)
            end
        end
    end

    if state.factionName and state.factionName ~= "" then
        local factionIndex, factionLine = self:FindTooltipLineIndex(frame, function(text)
            if type(text) ~= "string" or text == "" then
                return false
            end

            return text:find(state.factionName, 1, true) ~= nil
        end)
        if factionIndex and factionLine then
            if options.GetShowFaction and options:GetShowFaction() then
                local factionText = state.factionName
                local factionIcon = options:GetShowFactionIcon() and FACTION_ICONS[state.factionName] or nil
                if factionIcon and not self:HasTexturePrefix(factionLine:GetText()) then
                    factionText = factionIcon .. " " .. factionText
                elseif factionLine:GetText() and self:HasTexturePrefix(factionLine:GetText()) then
                    factionText = factionLine:GetText()
                end
                self:SetTooltipLeftText(frame, factionIndex, factionText, 0.76, 0.78, 0.84)
            else
                self:ClearTooltipLine(frame, factionIndex)
            end
        end
    end

    local levelIndex, levelLine = self:FindTooltipLineIndex(frame, function(text)
        return type(text) == "string" and text:find("Level ", 1, true) ~= nil
    end)

    local mythicIndex = self:FindTooltipLineIndex(frame, function(text)
        local stripped = StripTooltipMarkup(text)
        return type(stripped) == "string" and stripped:find("M+ ", 1, true) == 1
    end)
    local statIndex, statLine = self:FindTooltipLineIndex(frame, function(text)
        return IsPlayerStatLineText(text)
    end)

    local statParts = {}
    if options:GetShowItemLevel() and type(state.itemLevel) == "number" and state.itemLevel > 0 then
        table_insert(statParts, ColorizeText(string_format("iLvl %.1f", state.itemLevel), 0.96, 0.76, 0.24))
    end

    if #state.statusBadges > 0 then
        for _, badge in ipairs(state.statusBadges) do
            table_insert(statParts, badge)
        end
    end

    local statSuffix = table_concat(statParts, "  |cff556070•|r  ")
    if #statParts > 0 and levelIndex and levelLine then
        local baseLevelText = levelLine:GetText() or ""
        baseLevelText = baseLevelText:gsub("%s+|cff556070•|r%s+.-$", "")
        self:SetTooltipLeftText(frame, levelIndex, baseLevelText .. "  |cff556070•|r  " .. statSuffix, 0.82, 0.84, 0.90)
        if statIndex and statIndex ~= levelIndex then
            self:ClearTooltipLine(frame, statIndex)
        end
    elseif #statParts > 0 then
        if statIndex and statLine then
            self:SetTooltipLeftText(frame, statIndex, statSuffix, 0.82, 0.84, 0.90)
        else
            frame:AddLine(statSuffix, 0.82, 0.84, 0.90)
        end
    elseif levelIndex and levelLine then
        local baseLevelText = levelLine:GetText() or ""
        baseLevelText = baseLevelText:gsub("%s+|cff556070•|r%s+.-$", "")
        self:SetTooltipLeftText(frame, levelIndex, baseLevelText, 0.82, 0.84, 0.90)
        if statIndex and statIndex ~= levelIndex then
            self:ClearTooltipLine(frame, statIndex)
        end
    elseif statIndex then
        self:ClearTooltipLine(frame, statIndex)
    end

    if options:GetShowMythicScore() and type(state.mythicScore) == "number" and state.mythicScore > 0 then
        local red, green, blue = self:GetMythicScoreColor(state.mythicScore)
        local mythicText = "M+ " .. self:FormatNumber(state.mythicScore)
        if mythicIndex then
            self:SetTooltipLeftText(frame, mythicIndex, mythicText, red, green, blue)
        else
            frame:AddLine(mythicText, red, green, blue)
        end
    elseif mythicIndex then
        self:ClearTooltipLine(frame, mythicIndex)
    end
end

function TooltipModule:AppendPlayerDetails(frame, unit)
    if not unit or not SafeUnitIsPlayer(unit) then
        return
    end

    local state = self:BuildPlayerDetailState(unit)
    self:SetCachedPlayerDetailState(frame, state)
    self:AppendPlayerDetailState(frame, state)
end

function TooltipModule:NeedsPlayerDataRefresh(state)
    if type(state) ~= "table" or not state.isPlayer then
        return false
    end

    return state.itemLevel == nil or not (type(state.mythicScore) == "number" and state.mythicScore > 0)
end

function TooltipModule:SchedulePlayerDataRefresh(frame, state, reason)
    if not frame or frame ~= GameTooltip or not self:NeedsPlayerDataRefresh(state) then
        return
    end

    if not (C_Timer and type(C_Timer.After) == "function") then
        return
    end

    local guid = state.guid
    local ticket = (frame.__tuiTooltipDataRetryTicket or 0) + 1
    frame.__tuiTooltipDataRetryTicket = ticket

    for index, delaySeconds in ipairs(ENRICHMENT_RETRY_DELAYS) do
        C_Timer.After(delaySeconds, function()
            if frame.__tuiTooltipDataRetryTicket ~= ticket then
                return
            end

            if not (frame.IsShown and frame:IsShown()) then
                return
            end

            local unit = SafeTooltipUnit(frame)
            if not unit or not SafeUnitIsPlayer(unit) then
                return
            end

            local currentGUID = SafeCall(UnitGUID, unit)
            if guid and currentGUID and guid ~= currentGUID then
                return
            end

            self:RequestInspectData(unit)
            self:SetCachedPlayerDetailState(frame, nil)
            self:StyleFrame(frame)

            local refreshedState = self:GetCachedPlayerDetailState(frame)
            self:LogDebugf(false,
                "tooltip enrichment retry frame=%s reason=%s pass=%d guid=%s itemLevel=%s mythicScore=%s",
                SafeDebugString(frame.GetName and frame:GetName() or "<unnamed>"),
                SafeDebugString(reason),
                index,
                SafeDebugString(currentGUID),
                SafeDebugString(refreshedState and refreshedState.itemLevel),
                SafeDebugString(refreshedState and refreshedState.mythicScore))

            if refreshedState and not self:NeedsPlayerDataRefresh(refreshedState) then
                frame.__tuiTooltipDataRetryTicket = nil
            end
        end)
    end
end

function TooltipModule:ApplyUnitIdentity(frame)
    local options = GetOptions()
    if not options or frame ~= GameTooltip then
        return
    end

    local unit = SafeTooltipUnit(GameTooltip)
    local state = nil

    if unit and SafeUnitIsPlayer(unit) then
        state = self:BuildPlayerDetailState(unit)
        self:SetCachedPlayerDetailState(frame, state)
    else
        state = self:GetCachedPlayerDetailState(frame)
    end

    if not state then
        return
    end

    self:AppendPlayerDetailState(frame, state)

    local title = self:GetTooltipLine(frame, 1, "Left")
    if title then
        local titleText = title:GetText() or ""
        local nameIconMarkup = state.nameClassIconMarkup or state.classIconMarkup
        if nameIconMarkup and nameIconMarkup ~= "" and titleText ~= "" and not self:HasTexturePrefix(titleText) then
            self:SetTooltipLeftText(frame, 1, nameIconMarkup .. " " .. titleText)
        end
    end

    if not options:GetUsePlayerClassColors() then
        return
    end

    local red, green, blue = self:GetClassColor(state.classToken)
    if not red then
        return
    end

    if title then
        title:SetTextColor(red, green, blue)
    end

    local chrome = self:EnsureFrameChrome(frame)
    self:SetChromeBorderColor(chrome, red, green, blue, 0.72)
    chrome.Accent:SetColorTexture(red, green, blue, options:GetShowAccent() and 0.95 or 0)
    chrome.Glow:SetColorTexture(red, green, blue, options:GetShowAccent() and 0.10 or 0)
end

function TooltipModule:EnsureFrameChrome(frame)
    if frame.TwichUITooltipChrome then
        return frame.TwichUITooltipChrome
    end

    local chrome = CreateFrame("Frame", nil, frame)
    chrome:SetFrameStrata(frame:GetFrameStrata())
    chrome:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))

    chrome.Background = chrome:CreateTexture(nil, "BACKGROUND")
    chrome.Background:SetAllPoints()
    chrome.Background:SetTexture("Interface\\Buttons\\WHITE8X8")

    chrome.BorderTop = chrome:CreateTexture(nil, "BORDER")
    chrome.BorderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    chrome.BorderTop:SetPoint("TOPLEFT", chrome, "TOPLEFT", 0, 0)
    chrome.BorderTop:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", 0, 0)
    chrome.BorderTop:SetHeight(1)

    chrome.BorderBottom = chrome:CreateTexture(nil, "BORDER")
    chrome.BorderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    chrome.BorderBottom:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 0, 0)
    chrome.BorderBottom:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", 0, 0)
    chrome.BorderBottom:SetHeight(1)

    chrome.BorderLeft = chrome:CreateTexture(nil, "BORDER")
    chrome.BorderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    chrome.BorderLeft:SetPoint("TOPLEFT", chrome, "TOPLEFT", 0, 0)
    chrome.BorderLeft:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 0, 0)
    chrome.BorderLeft:SetWidth(1)

    chrome.BorderRight = chrome:CreateTexture(nil, "BORDER")
    chrome.BorderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    chrome.BorderRight:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", 0, 0)
    chrome.BorderRight:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", 0, 0)
    chrome.BorderRight:SetWidth(1)

    chrome.Accent = chrome:CreateTexture(nil, "BORDER")
    chrome.Accent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.Accent:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -1, -1)
    chrome.Accent:SetHeight(2)

    chrome.Glow = chrome:CreateTexture(nil, "BACKGROUND")
    chrome.Glow:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.Glow:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -1, 1)

    chrome.Shine = chrome:CreateTexture(nil, "ARTWORK")
    chrome.Shine:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.Shine:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -1, -1)
    chrome.Shine:SetHeight(20)
    chrome.Shine:SetColorTexture(1, 1, 1, 0)

    frame.TwichUITooltipChrome = chrome
    frame:HookScript("OnSizeChanged", function(owner)
        if owner.TwichUITooltipChrome then
            owner.TwichUITooltipChrome:SetFrameLevel(math_max(0, owner:GetFrameLevel() - 1))
            owner.TwichUITooltipChrome:ClearAllPoints()
            owner.TwichUITooltipChrome:SetPoint("TOPLEFT", owner, "TOPLEFT", -4, 4)
            owner.TwichUITooltipChrome:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 4, -4)
        end
    end)

    return chrome
end

function TooltipModule:SetChromeBackgroundColor(chrome, red, green, blue, alpha)
    if not chrome or not chrome.Background then
        return
    end

    chrome.Background:SetColorTexture(red or 0, green or 0, blue or 0, alpha or 1)
end

function TooltipModule:SetChromeBorderColor(chrome, red, green, blue, alpha)
    if not chrome then
        return
    end

    local textures = {
        chrome.BorderTop,
        chrome.BorderBottom,
        chrome.BorderLeft,
        chrome.BorderRight,
    }

    for _, texture in ipairs(textures) do
        if texture then
            texture:SetColorTexture(red or 0, green or 0, blue or 0, alpha or 1)
        end
    end
end

function TooltipModule:ApplyChrome(frame)
    if not frame then
        return
    end

    local chrome = self:EnsureFrameChrome(frame)
    local backgroundR, backgroundG, backgroundB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    local backgroundAlpha = tonumber(GetThemeValue("backgroundAlpha", 0.94)) or 0.94
    local borderAlpha = tonumber(GetThemeValue("borderAlpha", 0.85)) or 0.85
    local options = GetOptions()

    chrome:ClearAllPoints()
    chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    self:SetChromeBackgroundColor(chrome, backgroundR, backgroundG, backgroundB, math_max(0.72, backgroundAlpha))
    self:SetChromeBorderColor(chrome, borderR, borderG, borderB, math_max(0.78, borderAlpha))
    chrome.Accent:SetColorTexture(accentR, accentG, accentB, options and options:GetShowAccent() and 0.95 or 0)
    chrome.Glow:SetColorTexture(accentR, accentG, accentB, options and options:GetShowAccent() and 0.09 or 0)
    chrome.Shine:SetAlpha(0)
    chrome:SetShown(frame:IsShown())
end

function TooltipModule:SuppressDefaultBackdrop(frame)
    if not frame then
        return
    end

    if frame.GetBackdropColor and not frame.__tuiTooltipOriginalBackdropColor then
        local r, g, b, a = frame:GetBackdropColor()
        frame.__tuiTooltipOriginalBackdropColor = { r, g, b, a }
    end
    if frame.GetBackdropBorderColor and not frame.__tuiTooltipOriginalBorderColor then
        local r, g, b, a = frame:GetBackdropBorderColor()
        frame.__tuiTooltipOriginalBorderColor = { r, g, b, a }
    end
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    if frame.NineSlice then
        if frame.__tuiTooltipOriginalNineSliceAlpha == nil and frame.NineSlice.GetAlpha then
            frame.__tuiTooltipOriginalNineSliceAlpha = frame.NineSlice:GetAlpha()
        end
        frame.NineSlice:SetAlpha(0)
    end
end

function TooltipModule:RestoreDefaultBackdrop(frame)
    if not frame then
        return
    end

    if frame.SetBackdropColor and frame.__tuiTooltipOriginalBackdropColor then
        local color = frame.__tuiTooltipOriginalBackdropColor
        frame:SetBackdropColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
    end
    if frame.SetBackdropBorderColor and frame.__tuiTooltipOriginalBorderColor then
        local color = frame.__tuiTooltipOriginalBorderColor
        frame:SetBackdropBorderColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
    end
    if frame.NineSlice and frame.__tuiTooltipOriginalNineSliceAlpha ~= nil then
        frame.NineSlice:SetAlpha(frame.__tuiTooltipOriginalNineSliceAlpha)
    end
end

function TooltipModule:ApplyFonts(frame)
    local options = GetOptions()
    if not options or not frame or type(frame.GetName) ~= "function" then
        return
    end

    local name = frame:GetName()
    if not name then
        return
    end

    local fontPath = ResolveFontPath()
    local headerSize = options:GetHeaderFontSize()
    local bodySize = options:GetBodyFontSize()
    local lines = frame:NumLines() or 0
    for index = 1, lines do
        local left = _G[name .. "TextLeft" .. index]
        local right = _G[name .. "TextRight" .. index]

        if left then
            self:StoreOriginalFont(left)
            left:SetFont(fontPath, index == 1 and headerSize or bodySize, "")
            left:SetShadowOffset(1, -1)
        end

        if right then
            self:StoreOriginalFont(right)
            right:SetFont(fontPath, bodySize, "")
            right:SetShadowOffset(1, -1)
        end
    end
end

function TooltipModule:GetDesiredTooltipWidth(frame)
    if not frame or type(frame.GetName) ~= "function" then
        return nil
    end

    local name = frame:GetName()
    if not name then
        return nil
    end

    local maxLineWidth = 0
    local lines = frame.NumLines and frame:NumLines() or 0
    for index = 1, lines do
        local left = _G[name .. "TextLeft" .. index]
        local right = _G[name .. "TextRight" .. index]
        local leftText = left and left.GetText and left:GetText() or nil
        local rightText = right and right.GetText and right:GetText() or nil
        local leftWidth = EstimateTooltipTextWidth(leftText)
        local rightWidth = EstimateTooltipTextWidth(rightText)
        leftWidth = leftWidth + (CountTextureMarkup(leftText) * 16)
        rightWidth = rightWidth + (CountTextureMarkup(rightText) * 16)
        local totalWidth = leftWidth + rightWidth
        if rightWidth > 0 then
            totalWidth = totalWidth + 24
        end
        maxLineWidth = math_max(maxLineWidth, totalWidth)
    end

    return math_max(160, RoundPixel(maxLineWidth + 32))
end

function TooltipModule:ShouldForceTooltipWidth(frame)
    if not frame then
        return false
    end

    if frame.GetItem then
        local _, itemLink = frame:GetItem()
        if itemLink then
            return false
        end
    end

    local unit = SafeTooltipUnit(frame)
    if unit and SafeUnitIsPlayer(unit) then
        return true
    end

    return self:GetCachedPlayerDetailState(frame) ~= nil
end

function TooltipModule:RefreshTooltipWidth(frame)
    if not frame then
        return
    end

    if not self:ShouldForceTooltipWidth(frame) then
        if frame.SetMinimumWidth then
            frame:SetMinimumWidth(0)
        end
        return
    end

    local desiredWidth = self:GetDesiredTooltipWidth(frame)
    if not desiredWidth then
        return
    end

    if type(frame.SetMinimumWidth) == "function" then
        frame:SetMinimumWidth(desiredWidth)
    end

    if type(frame.SetWidth) == "function" then
        frame:SetWidth(desiredWidth)
    end
end

function TooltipModule:RestoreFonts(frame)
    if not frame or type(frame.GetName) ~= "function" then
        return
    end

    local name = frame:GetName()
    if not name then
        return
    end

    for index = 1, 40 do
        self:RestoreFont(_G[name .. "TextLeft" .. index])
        self:RestoreFont(_G[name .. "TextRight" .. index])
    end
end

function TooltipModule:StyleStatusBar()
    local options = GetOptions()
    if not options or not GameTooltipStatusBar then
        return
    end

    if not options:GetShowHealthBar() then
        GameTooltipStatusBar:Hide()
        GameTooltipStatusBar:SetAlpha(0)
        if GameTooltipStatusBar.TwichUIBackdrop then
            GameTooltipStatusBar.TwichUIBackdrop:Hide()
        end
        return
    end

    GameTooltipStatusBar:SetAlpha(1)

    if not GameTooltipStatusBar.TwichUIBackdrop then
        local backdrop = CreateFrame("Frame", nil, GameTooltipStatusBar, "BackdropTemplate")
        backdrop:SetFrameLevel(math_max(0, GameTooltipStatusBar:GetFrameLevel() - 1))
        backdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        backdrop:SetPoint("TOPLEFT", GameTooltipStatusBar, "TOPLEFT", -1, 1)
        backdrop:SetPoint("BOTTOMRIGHT", GameTooltipStatusBar, "BOTTOMRIGHT", 1, -1)
        GameTooltipStatusBar.TwichUIBackdrop = backdrop
    end

    if not GameTooltipStatusBar.__tuiTooltipOriginalTexture and GameTooltipStatusBar.GetStatusBarTexture then
        GameTooltipStatusBar.__tuiTooltipOriginalTexture = GameTooltipStatusBar:GetStatusBarTexture()
    end
    if not GameTooltipStatusBar.__tuiTooltipOriginalHeight then
        GameTooltipStatusBar.__tuiTooltipOriginalHeight = GameTooltipStatusBar:GetHeight()
    end

    local texturePath = ResolveStatusBarTexture()
    if texturePath then
        GameTooltipStatusBar:SetStatusBarTexture(texturePath)
    end

    GameTooltipStatusBar:SetHeight(options:GetStatusBarHeight())

    local backgroundR, backgroundG, backgroundB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    GameTooltipStatusBar.TwichUIBackdrop:SetBackdropColor(backgroundR, backgroundG, backgroundB, 0.90)
    GameTooltipStatusBar.TwichUIBackdrop:SetBackdropBorderColor(borderR, borderG, borderB, 0.85)
    if GameTooltipStatusBar:IsShown() then
        GameTooltipStatusBar.TwichUIBackdrop:Show()
    end

    local unit = SafeTooltipUnit(GameTooltip)
    if unit and SafeUnitIsPlayer(unit) then
        local _, classToken = SafeUnitClass(unit)
        local colorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local classColor = colorTable and colorTable[classToken or ""]
        if classColor then
            GameTooltipStatusBar:SetStatusBarColor(classColor.r or 1, classColor.g or 1, classColor.b or 1)
            return
        end
    end

    if unit and SafeUnitCanAttack("player", unit) then
        GameTooltipStatusBar:SetStatusBarColor(0.88, 0.26, 0.30)
    elseif unit and SafeUnitIsFriend(unit, "player") then
        GameTooltipStatusBar:SetStatusBarColor(0.24, 0.80, 0.54)
    else
        GameTooltipStatusBar:SetStatusBarColor(accentR, accentG, accentB)
    end
end

function TooltipModule:RestoreStatusBar()
    if not GameTooltipStatusBar then
        return
    end

    GameTooltipStatusBar:SetAlpha(1)
    if GameTooltipStatusBar.TwichUIBackdrop then
        GameTooltipStatusBar.TwichUIBackdrop:Hide()
    end
    if GameTooltipStatusBar.__tuiTooltipOriginalTexture then
        GameTooltipStatusBar:SetStatusBarTexture(GameTooltipStatusBar.__tuiTooltipOriginalTexture)
    end
    if GameTooltipStatusBar.__tuiTooltipOriginalHeight then
        GameTooltipStatusBar:SetHeight(GameTooltipStatusBar.__tuiTooltipOriginalHeight)
    end
end

function TooltipModule:ApplyAnchorMode(frame, owner)
    local options = GetOptions()
    if not options or not options:GetEnabled() or not frame or not ANCHORABLE_TOOLTIP_NAMES[frame:GetName() or ""] then
        return
    end

    local anchorMode = options:GetAnchorMode()
    if anchorMode == "default" then
        return
    end
    if self.anchorGuard then
        return
    end

    self.anchorGuard = true
    if anchorMode == "cursor" then
        frame:SetOwner(UIParent, "ANCHOR_CURSOR", options:GetCursorOffsetX(), options:GetCursorOffsetY())
    elseif anchorMode == "fixed" then
        local anchor = self:CreateAnchor()
        frame:SetOwner(UIParent, "ANCHOR_NONE")
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 12)
    end
    self.anchorGuard = nil
end

function TooltipModule:OnDefaultTooltipAnchor(frame, owner)
    if frame ~= GameTooltip then
        return
    end

    local options = GetOptions()
    if not options or not options:GetEnabled() then
        return
    end

    local anchorMode = options:GetAnchorMode()
    if anchorMode == "default" or self.anchorGuard then
        return
    end

    self.anchorGuard = true
    if anchorMode == "cursor" then
        frame:SetOwner(owner or UIParent, "ANCHOR_CURSOR", options:GetCursorOffsetX(), options:GetCursorOffsetY())
    elseif anchorMode == "fixed" then
        local anchor = self:CreateAnchor()
        frame:SetOwner(UIParent, "ANCHOR_NONE")
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 12)
    end
    self.anchorGuard = nil
end

function TooltipModule:ApplyScale(frame)
    local options = GetOptions()
    if not options or not frame then
        return
    end

    if frame.__tuiTooltipOriginalScale == nil and frame.GetScale then
        frame.__tuiTooltipOriginalScale = frame:GetScale()
    end
    frame:SetScale(options:GetScale())
end

function TooltipModule:StyleFrame(frame)
    local options = GetOptions()
    if not options or not options:GetEnabled() or not frame then
        return
    end

    if options:GetHideInCombat() and InCombatLockdown() then
        if frame.Hide then
            frame:Hide()
        end
        return
    end

    self:SuppressDefaultBackdrop(frame)
    self:ApplyChrome(frame)
    self:ApplyScale(frame)
    self:ApplyFonts(frame)
    self:ApplyItemBorder(frame)
    self:AppendItemAppearance(frame)
    self:ApplyUnitIdentity(frame)
    self:RefreshTooltipWidth(frame)
    if frame == GameTooltip then
        self:StyleStatusBar()
    end
    self:PlayFadeIn(frame)
end

function TooltipModule:RestoreFrame(frame)
    if not frame then
        return
    end

    self:RestoreDefaultBackdrop(frame)
    self:RestoreFonts(frame)
    if frame.TwichUITooltipChrome then
        frame.TwichUITooltipChrome:Hide()
    end
    if frame.__tuiTooltipOriginalScale ~= nil then
        frame:SetScale(frame.__tuiTooltipOriginalScale)
    end
end

function TooltipModule:RegisterManagedFrame(frame)
    if not frame or self.registeredFrames[frame] then
        return
    end

    self.registeredFrames[frame] = true
    if frame ~= GameTooltip then
        self:SecureHook(frame, "SetOwner", "OnTooltipSetOwner")
    end
    if self:HasScript(frame, "OnShow") then
        self:SecureHookScript(frame, "OnShow", "OnTooltipShow")
    end
    if self:HasScript(frame, "OnHide") then
        self:SecureHookScript(frame, "OnHide", "OnTooltipHide")
    end
    if self:HasScript(frame, "OnTooltipSetUnit") then
        self:SecureHookScript(frame, "OnTooltipSetUnit", "OnTooltipSetUnit")
    end
end

function TooltipModule:RefreshAllTooltips()
    self:ApplyAnchorPosition()
    self:ApplyAnchorTheme()
    self:UpdateAnchorVisibility()

    for _, frame in ipairs(self:GetManagedFrames()) do
        if frame:IsShown() then
            self:StyleFrame(frame)
            if frame == GameTooltip then
                self:OnDefaultTooltipAnchor(frame, frame:GetOwner())
            else
                self:ApplyAnchorMode(frame, frame:GetOwner())
            end
        elseif frame.TwichUITooltipChrome then
            frame.TwichUITooltipChrome:Hide()
        end
    end
end

function TooltipModule:RefreshAnchor()
    self:ApplyAnchorPosition()
    self:ApplyAnchorTheme()
    self:UpdateAnchorVisibility()
    if GameTooltip and GameTooltip:IsShown() then
        self:OnDefaultTooltipAnchor(GameTooltip, GameTooltip:GetOwner())
    end
end

function TooltipModule:ScheduleStyleFrame(frame, reason)
    if not frame then
        return
    end

    local ticket = (frame.__tuiTooltipStyleTicket or 0) + 1
    frame.__tuiTooltipStyleTicket = ticket

    local function ApplyScheduledStyle(pass)
        if frame.__tuiTooltipStyleTicket ~= ticket then
            return
        end

        if frame.IsShown and frame:IsShown() then
            self:StyleFrame(frame)
            self:LogDebugf(false, "tooltip scheduled style frame=%s reason=%s pass=%s lines=%s width=%.0f height=%.0f",
                SafeDebugString(frame.GetName and frame:GetName() or "<unnamed>"),
                SafeDebugString(reason),
                SafeDebugString(pass),
                SafeDebugString(frame.NumLines and frame:NumLines() or nil),
                frame.GetWidth and frame:GetWidth() or 0,
                frame.GetHeight and frame:GetHeight() or 0)
        end
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function() ApplyScheduledStyle(1) end)
        C_Timer.After(0.03, function() ApplyScheduledStyle(2) end)
        C_Timer.After(0.08, function() ApplyScheduledStyle(3) end)
    else
        ApplyScheduledStyle(1)
    end
end

function TooltipModule:BuildFrameDebugReport(frame)
    if not frame then
        return "Frame: unavailable"
    end

    local lines = {}
    local frameName = frame.GetName and frame:GetName() or "<unnamed>"
    local owner = frame.GetOwner and frame:GetOwner() or nil
    local ownerName = owner and owner.GetName and owner:GetName() or SafeDebugString(owner)
    table_insert(lines, string_format("Frame: %s", SafeDebugString(frameName)))
    table_insert(lines, string_format("Shown: %s  Scale: %s  Size: %.0fx%.0f  Lines: %s",
        SafeDebugString(frame.IsShown and frame:IsShown() or nil),
        SafeDebugString(frame.GetScale and frame:GetScale() or nil),
        frame.GetWidth and frame:GetWidth() or 0,
        frame.GetHeight and frame:GetHeight() or 0,
        SafeDebugString(frame.NumLines and frame:NumLines() or nil)))
    table_insert(lines, string_format("Owner: %s", SafeDebugString(ownerName)))

    if frame.GetUnit then
        local _, unit = frame:GetUnit()
        table_insert(lines, string_format("Unit: %s", SafeDebugString(unit)))
    end

    local cachedState = self:GetCachedPlayerDetailState(frame)
    if cachedState then
        table_insert(lines, string_format("Cached Player State: class=%s faction=%s score=%s icon=%s",
            SafeDebugString(cachedState.classToken),
            SafeDebugString(cachedState.factionName),
            SafeDebugString(cachedState.mythicScore),
            SafeDebugString(cachedState.hasClassIconMarkup)))
    end

    if frame.GetItem then
        local itemName, itemLink = frame:GetItem()
        if itemName or itemLink then
            table_insert(lines, string_format("Item: %s  Link: %s", SafeDebugString(itemName), SafeDebugString(itemLink)))
        end
    end

    local maxLines = math_min(frame.NumLines and frame:NumLines() or 0, 8)
    if maxLines > 0 then
        table_insert(lines, "Tooltip Text:")
        for index = 1, maxLines do
            local left = self:GetTooltipLine(frame, index, "Left")
            local right = self:GetTooltipLine(frame, index, "Right")
            local leftText = left and left.GetText and left:GetText() or ""
            local rightText = right and right.GetText and right:GetText() or ""
            table_insert(lines,
                string_format("  %02d. L=%s | R=%s", index, SafeDebugString(leftText), SafeDebugString(rightText)))
        end
    end

    return table_concat(lines, "\n")
end

function TooltipModule:GetDebugSummaryLine()
    local options = GetOptions()
    local state = self.lastPlayerDetailState or {}
    return string_format(
        "Enabled: %s  |  Capture: %s  |  Anchor: %s  |  Last Unit: %s  |  Last M+: %s  |  Class Icon: %s",
        options and SafeDebugString(options:GetEnabled()) or "nil",
        options and SafeDebugString(options.GetDebugEnabled and options:GetDebugEnabled()) or "nil",
        options and SafeDebugString(options:GetAnchorMode()) or "nil",
        SafeDebugString(state.unit),
        SafeDebugString(type(state.mythicScore) == "number" and self:FormatNumber(state.mythicScore) or nil),
        SafeDebugString(state.hasClassIconMarkup))
end

function TooltipModule:BuildDebugReport()
    local options = GetOptions()
    local lines = {
        "TwichUI Tooltip Debug Report",
        string_format("moduleEnabled=%s", SafeDebugString(options and options:GetEnabled())),
        string_format("debugEnabled=%s",
            SafeDebugString(options and options.GetDebugEnabled and options:GetDebugEnabled())),
        string_format("anchorMode=%s anchorLocked=%s cursorOffset=(%s,%s)",
            SafeDebugString(options and options:GetAnchorMode()),
            SafeDebugString(options and options:GetAnchorLocked()),
            SafeDebugString(options and options:GetCursorOffsetX()),
            SafeDebugString(options and options:GetCursorOffsetY())),
        string_format("scale=%s headerFont=%s bodyFont=%s accent=%s classTint=%s classIcon=%s healthBar=%s",
            SafeDebugString(options and options:GetScale()),
            SafeDebugString(options and options:GetHeaderFontSize()),
            SafeDebugString(options and options:GetBodyFontSize()),
            SafeDebugString(options and options:GetShowAccent()),
            SafeDebugString(options and options:GetUsePlayerClassColors()),
            SafeDebugString(options and options:GetShowClassIcon()),
            SafeDebugString(options and options:GetShowHealthBar())),
        string_format(
            "content: playerDetails=%s faction=%s factionIcon=%s guildRank=%s mythicScore=%s itemLevel=%s transmog=%s",
            SafeDebugString(options and options:GetShowPlayerDetails()),
            SafeDebugString(options and options.GetShowFaction and options:GetShowFaction()),
            SafeDebugString(options and options:GetShowFactionIcon()),
            SafeDebugString(options and options:GetShowGuildRank()),
            SafeDebugString(options and options:GetShowMythicScore()),
            SafeDebugString(options and options:GetShowItemLevel()),
            SafeDebugString(options and options:GetShowTransmogStatus())),
        "",
        "Last Player Detail State",
    }

    local state = self.lastPlayerDetailState or {}
    table_insert(lines, string_format("unit=%s class=%s classToken=%s faction=%s spec=%s role=%s",
        SafeDebugString(state.unit), SafeDebugString(state.className), SafeDebugString(state.classToken),
        SafeDebugString(state.factionName), SafeDebugString(state.specName), SafeDebugString(state.roleName)))
    table_insert(lines, string_format("guild=%s guildRank=%s itemLevel=%s mythicScore=%s summaryToken=%s",
        SafeDebugString(state.guildName), SafeDebugString(state.guildRankName), SafeDebugString(state.itemLevel),
        SafeDebugString(state.mythicScore), SafeDebugString(state.mythicSummaryToken)))
    table_insert(lines, string_format("badges=%s hasClassIconMarkup=%s classIconMarkup=%s",
        SafeDebugString(state.statusBadges and table_concat(state.statusBadges, " ") or nil),
        SafeDebugString(state.hasClassIconMarkup),
        SafeDebugString(state.classIconMarkup)))
    table_insert(lines, "")
    table_insert(lines, self:BuildFrameDebugReport(GameTooltip))

    return table_concat(lines, "\n")
end

function TooltipModule:RegisterTooltipDataCallbacks()
    if self.tooltipDataCallbacksRegistered == true then
        return
    end

    local tooltipDataType = Enum and Enum.TooltipDataType or nil
    if not (TooltipDataProcessor and tooltipDataType and type(TooltipDataProcessor.AddTooltipPostCall) == "function") then
        return
    end

    TooltipDataProcessor.AddTooltipPostCall(tooltipDataType.Unit, function(tooltip)
        if tooltip ~= GameTooltip then
            return
        end

        self:SetCachedPlayerDetailState(tooltip, nil)
        self:LogDebugf(false, "tooltip data postcall invalidated cached player state")

        self:ScheduleStyleFrame(tooltip, "tooltip-data-unit")
    end)

    self.tooltipDataCallbacksRegistered = true
end

function TooltipModule:CaptureDebugSnapshot(shouldShow)
    local console = GetDebugConsole()
    if not console or type(console.Log) ~= "function" then
        return false
    end

    console:Log(DEBUG_SOURCE_KEY, self:BuildDebugReport(), shouldShow == true)
    return true
end

function TooltipModule:ShowPreview()
    local options = GetOptions()
    if not options or not options:GetEnabled() or not GameTooltip then
        return
    end

    local owner = UIParent
    local anchorMode = options:GetAnchorMode()
    if anchorMode == "cursor" then
        GameTooltip:SetOwner(owner, "ANCHOR_CURSOR", options:GetCursorOffsetX(), options:GetCursorOffsetY())
    elseif anchorMode == "fixed" then
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMLEFT", self:CreateAnchor(), "TOPLEFT", 0, 12)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("CENTER", UIParent, "CENTER", 220, 60)
    end

    GameTooltip:ClearLines()
    GameTooltip:AddLine("TwichUI Tooltip")
    GameTooltip:AddLine("Premium chrome, theme-aware surfaces, and controlled anchor behavior.", 0.82, 0.84, 0.90, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Anchor Mode", anchorMode:gsub("^%l", string.upper), 0.96, 0.76, 0.24, 1, 1, 1)
    GameTooltip:AddDoubleLine("Scale", string.format("%.2f", options:GetScale()), 0.72, 0.74, 0.80, 1, 1, 1)
    GameTooltip:AddDoubleLine("Health Bar", options:GetShowHealthBar() and "Enabled" or "Hidden", 0.72, 0.74, 0.80, 1, 1,
        1)
    GameTooltip:Show()
    self:StyleFrame(GameTooltip)
end

function TooltipModule:OnTooltipSetOwner(frame, owner)
    self:ApplyAnchorMode(frame, owner)
end

function TooltipModule:OnTooltipShow(frame)
    if frame then
        frame.__tuiTooltipFadePlayed = nil
    end

    if frame == GameTooltip then
        self:ScheduleStyleFrame(frame, "show")
    else
        self:StyleFrame(frame)
        self:ApplyAnchorMode(frame, frame:GetOwner())
    end

    local frameName = frame and frame.GetName and frame:GetName() or "<unnamed>"
    local unit = nil
    if frame and frame.GetUnit then
        local _, foundUnit = frame:GetUnit()
        unit = foundUnit
    end
    local itemName = frame and frame.GetItem and frame:GetItem() or nil
    self:LogDebugf(false, "tooltip show frame=%s unit=%s item=%s lines=%s width=%.0f height=%.0f",
        SafeDebugString(frameName), SafeDebugString(unit), SafeDebugString(itemName),
        SafeDebugString(frame and frame.NumLines and frame:NumLines() or nil),
        frame and frame.GetWidth and frame:GetWidth() or 0,
        frame and frame.GetHeight and frame:GetHeight() or 0)
end

function TooltipModule:OnTooltipHide(frame)
    if frame then
        frame.__tuiTooltipStyleTicket = nil
        frame.__tuiTooltipDataRetryTicket = nil
        frame.__tuiTooltipPlayerState = nil
        frame.__tuiTooltipFadePlayed = nil
        if frame.SetMinimumWidth then
            frame:SetMinimumWidth(0)
        end
    end
    if frame and frame.TwichUITooltipFadeIn then
        frame.TwichUITooltipFadeIn:Stop()
        frame:SetAlpha(1)
    end
    if frame and frame.TwichUITooltipChrome then
        frame.TwichUITooltipChrome:Hide()
    end
    if frame == GameTooltip and GameTooltipStatusBar and GameTooltipStatusBar.TwichUIBackdrop then
        GameTooltipStatusBar.TwichUIBackdrop:Hide()
    end
end

function TooltipModule:OnTooltipSetUnit(frame)
    if frame == GameTooltip then
        local _, unit = frame:GetUnit()
        local state = unit and self:BuildPlayerDetailState(unit) or nil
        if state and state.isPlayer then
            self:RequestInspectData(unit)
            self.lastPlayerDetailState = state
            self:SetCachedPlayerDetailState(frame, state)
            self:SchedulePlayerDataRefresh(frame, state, "unit")
            self:LogDebugf(false,
                "tooltip unit frame=%s unit=%s class=%s spec=%s faction=%s score=%s itemLevel=%s summaryToken=%s",
                SafeDebugString(frame:GetName()),
                SafeDebugString(unit),
                SafeDebugString(state.classToken),
                SafeDebugString(state.specName),
                SafeDebugString(state.factionName),
                SafeDebugString(state.mythicScore),
                SafeDebugString(state.itemLevel),
                SafeDebugString(state.mythicSummaryToken))
        elseif unit then
            self:SetCachedPlayerDetailState(frame, nil)
            self:LogDebugf(false, "tooltip unit frame=%s unit=%s nonPlayer=%s",
                SafeDebugString(frame:GetName()), SafeDebugString(unit), SafeDebugString(state and not state.isPlayer))
        end

        self:ScheduleStyleFrame(frame, "unit")
    end
end

function TooltipModule:OnCombatStarted()
    local options = GetOptions()
    if not options or not options:GetHideInCombat() then
        return
    end

    for _, frame in ipairs(self:GetManagedFrames()) do
        if frame and frame.Hide then
            frame:Hide()
        end
    end
end

function TooltipModule:OnCombatEnded()
    self:UpdateAnchorVisibility()
end

function TooltipModule:OnThemeChanged(key)
    if key ~= nil and not THEME_KEYS[key] then
        return
    end

    self:RefreshAllTooltips()
end

function TooltipModule:BuildDesignerExtras()
    local options = GetOptions()
    if not options then
        return {}
    end

    return {
        {
            type = "section",
            tab = "Layout",
            label = "Anchor Behavior",
        },
        {
            label = "Anchor Mode",
            type = "select",
            tab = "Layout",
            values = {
                default = "Default",
                cursor = "Cursor",
                fixed = "Fixed Anchor",
            },
            valuesOrder = { "default", "cursor", "fixed" },
            get = function()
                return options:GetAnchorMode()
            end,
            set = function(value)
                options:SetAnchorMode(nil, value)
            end,
        },
        {
            label = "Tooltip Scale",
            type = "range",
            tab = "Layout",
            min = 0.8,
            max = 1.4,
            step = 0.01,
            get = function()
                return options:GetScale()
            end,
            set = function(value)
                options:SetScale(nil, value)
            end,
        },
        {
            label = "Cursor Offset X",
            type = "range",
            tab = "Layout",
            min = -40,
            max = 120,
            step = 1,
            hidden = function()
                return options:GetAnchorMode() ~= "cursor"
            end,
            get = function()
                return options:GetCursorOffsetX()
            end,
            set = function(value)
                options:SetCursorOffsetX(nil, value)
            end,
        },
        {
            label = "Cursor Offset Y",
            type = "range",
            tab = "Layout",
            min = -60,
            max = 80,
            step = 1,
            hidden = function()
                return options:GetAnchorMode() ~= "cursor"
            end,
            get = function()
                return options:GetCursorOffsetY()
            end,
            set = function(value)
                options:SetCursorOffsetY(nil, value)
            end,
        },
        {
            type = "section",
            tab = "Style",
            label = "Chrome",
        },
        {
            label = "Accent Trim",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetShowAccent()
            end,
            set = function(value)
                options:SetShowAccent(nil, value)
            end,
        },
        {
            label = "Class Tint Players",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetUsePlayerClassColors()
            end,
            set = function(value)
                options:SetUsePlayerClassColors(nil, value)
            end,
        },
        {
            label = "Class Icons",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetShowClassIcon()
            end,
            set = function(value)
                options:SetShowClassIcon(nil, value)
            end,
        },
        {
            label = "Class Icon Style",
            type = "select",
            tab = "Style",
            values = {
                global = "Global Appearance",
                default = "Default",
                fabled = "Fabled",
                pixel = "Pixel",
            },
            valuesOrder = { "global", "default", "fabled", "pixel" },
            hidden = function()
                return not options:GetShowClassIcon()
            end,
            get = function()
                return options:GetClassIconStyle()
            end,
            set = function(value)
                options:SetClassIconStyle(nil, value)
            end,
        },
        {
            label = "Hide In Combat",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetHideInCombat()
            end,
            set = function(value)
                options:SetHideInCombat(nil, value)
            end,
        },
        {
            label = "Fade In",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetEnableFadeIn()
            end,
            set = function(value)
                options:SetEnableFadeIn(nil, value)
            end,
        },
        {
            label = "Health Bar",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetShowHealthBar()
            end,
            set = function(value)
                options:SetShowHealthBar(nil, value)
            end,
        },
        {
            label = "Bar Height",
            type = "range",
            tab = "Style",
            min = 5,
            max = 16,
            step = 1,
            get = function()
                return options:GetStatusBarHeight()
            end,
            set = function(value)
                options:SetStatusBarHeight(nil, value)
            end,
        },
        {
            type = "section",
            tab = "Content",
            label = "Enrichment",
        },
        {
            label = "Player Details",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowPlayerDetails()
            end,
            set = function(value)
                options:SetShowPlayerDetails(nil, value)
            end,
        },
        {
            label = "Show Faction",
            type = "toggle",
            tab = "Content",
            hidden = function()
                return not options:GetShowPlayerDetails()
            end,
            get = function()
                return options:GetShowFaction()
            end,
            set = function(value)
                options:SetShowFaction(nil, value)
            end,
        },
        {
            label = "Faction Icon",
            type = "toggle",
            tab = "Content",
            hidden = function()
                return not options:GetShowPlayerDetails() or not options:GetShowFaction()
            end,
            get = function()
                return options:GetShowFactionIcon()
            end,
            set = function(value)
                options:SetShowFactionIcon(nil, value)
            end,
        },
        {
            label = "Guild Rank",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowGuildRank()
            end,
            set = function(value)
                options:SetShowGuildRank(nil, value)
            end,
        },
        {
            label = "Mythic+ Score",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowMythicScore()
            end,
            set = function(value)
                options:SetShowMythicScore(nil, value)
            end,
        },
        {
            label = "Show Item Level",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowItemLevel()
            end,
            set = function(value)
                options:SetShowItemLevel(nil, value)
            end,
        },
        {
            label = "Transmog Status",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowTransmogStatus()
            end,
            set = function(value)
                options:SetShowTransmogStatus(nil, value)
            end,
        },
        {
            label = "Item Quality Border",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetUseItemQualityBorder()
            end,
            set = function(value)
                options:SetUseItemQualityBorder(nil, value)
            end,
        },
    }
end

function TooltipModule:OnEnable()
    self.registeredFrames = self.registeredFrames or {}
    self.inspectItemLevelCache = self.inspectItemLevelCache or {}
    self.mythicScoreCache = self.mythicScoreCache or {}
    self:CreateAnchor()
    self:RegisterTooltipDataCallbacks()
    for _, frame in ipairs(self:GetManagedFrames()) do
        self:RegisterManagedFrame(frame)
    end

    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStarted")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
    self:RegisterEvent("INSPECT_READY")

    local debugConsole = GetDebugConsole()
    if debugConsole and debugConsole.RegisterSource then
        debugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
            title = "Tooltips",
            order = 55,
            aliases = { "tooltips", "tt" },
            maxLines = 80,
            isEnabled = function()
                return self:IsDebugEnabled()
            end,
            buildReport = function()
                return self:BuildDebugReport()
            end,
        })
    end

    self:SecureHook("GameTooltip_SetDefaultAnchor", "OnDefaultTooltipAnchor")
    if GameTooltipStatusBar and self:HasScript(GameTooltipStatusBar, "OnShow") then
        self:SecureHookScript(GameTooltipStatusBar, "OnShow", "OnStatusBarShow")
    end
    local moversModule = _G.TwichMoverModule
    if moversModule and type(moversModule.RegisterMover) == "function" then
        moversModule:RegisterMover("UI_tooltip_anchor", {
            label = "Tooltip Anchor",
            category = "Interface",
            headerToggle = {
                label = "Enabled",
                get = function()
                    local options = GetOptions()
                    return options and options:GetEnabled() or false
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetEnabled(nil, value)
                    end
                end,
            },
            headerAction = {
                label = "Preview",
                accent = { 0.95, 0.77, 0.28 },
                func = function()
                    self:ShowPreview()
                end,
                disabled = function()
                    local options = GetOptions()
                    return not options or not options:GetEnabled()
                end,
            },
            getFrame = function()
                return self:CreateAnchor()
            end,
            getX = function()
                local options = GetOptions()
                return options and options:GetAnchorX() or 1050
            end,
            getY = function()
                local options = GetOptions()
                return options and options:GetAnchorY() or 260
            end,
            getW = function()
                return 220
            end,
            getH = function()
                return 26
            end,
            setPos = function(x, y)
                local options = GetOptions()
                if options then
                    options:SetAnchorPosition(RoundPixel(x), RoundPixel(y))
                end
            end,
            isEnabled = function()
                local options = GetOptions()
                return options and options:GetEnabled() or false
            end,
            extras = self:BuildDesignerExtras(),
        })
    end

    self:RefreshAllTooltips()
end

function TooltipModule:OnDisable()
    self:UnregisterMessage("TWICH_THEME_CHANGED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("INSPECT_READY")
    self.pendingInspectGUID = nil
    self.pendingInspectUnit = nil
    self.pendingInspectToken = nil
    if type(ClearInspectPlayer) == "function" then
        SafeCall(ClearInspectPlayer)
    end
    self:UnhookAll()
    if _G.TwichMoverModule and type(_G.TwichMoverModule.UnregisterMover) == "function" then
        _G.TwichMoverModule:UnregisterMover("UI_tooltip_anchor")
    end
    for _, frame in ipairs(self:GetManagedFrames()) do
        self:RestoreFrame(frame)
    end
    self:RestoreStatusBar()
    if self.anchor then
        self.anchor:Hide()
    end
end

function TooltipModule:OnStatusBarShow()
    local options = GetOptions()
    if options and not options:GetShowHealthBar() and GameTooltipStatusBar then
        GameTooltipStatusBar:Hide()
        GameTooltipStatusBar:SetAlpha(0)
    end
end
