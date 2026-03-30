---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@type NotificationModule
local NotificationModule = T:GetModule("Notification")

---@class MythicPlusToolsRuntime
local MPT = _G.TwichUIMythicPlusToolsRuntime or {}
_G.TwichUIMythicPlusToolsRuntime = MPT

local AceGUI = LibStub("AceGUI-3.0")
---@type fun(self: table, widgetType: string): any
local CreateWidget = AceGUI.Create
local Masque = LibStub("Masque", true)

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local Lerp = _G.Lerp or function(fromValue, toValue, progress)
    return fromValue + ((toValue - fromValue) * progress)
end
local tinsert = table.insert
local tsort = table.sort
local unpack = table.unpack or _G.unpack

local AuraUtil = _G.AuraUtil
local C_ChallengeMode = _G.C_ChallengeMode
local C_Container = _G.C_Container
local C_AddOns = _G.C_AddOns
local C_MythicPlus = _G.C_MythicPlus
local C_PartyInfo = _G.C_PartyInfo
local C_NamePlate = _G.C_NamePlate
local C_Spell = _G.C_Spell
local C_Scenario = _G.C_Scenario
local C_ScenarioInfo = _G.C_ScenarioInfo
local C_Timer = _G.C_Timer
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local CreateFrame = _G.CreateFrame
local GetInspectSpecialization = _G.GetInspectSpecialization
local GetInstanceInfo = _G.GetInstanceInfo
local GetNumSubgroupMembers = _G.GetNumSubgroupMembers
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetSpellBaseCooldown = _G.GetSpellBaseCooldown
local GetSpellCooldown = _G.GetSpellCooldown
local GetSpellInfo = _G.GetSpellInfo
local GetTime = _G.GetTime
local GetWorldElapsedTime = _G.GetWorldElapsedTime
local InCombatLockdown = _G.InCombatLockdown
local IsInGroup = _G.IsInGroup
local IsInInstance = _G.IsInInstance
local IsAddOnLoaded = _G.IsAddOnLoaded
local LoadAddOn = _G.LoadAddOn or _G.LoadAddon
local NotifyInspect = _G.NotifyInspect
local PlaySoundFile = _G.PlaySoundFile
local RunMacroText = _G.RunMacroText
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitFullName = _G.UnitFullName
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitGUID = _G.UnitGUID
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitName = _G.UnitName
local UnitNameFromGUID = _G.UnitNameFromGUID
local UnitTokenFromGUID = _G.UnitTokenFromGUID
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local LOCALIZED_CLASS_NAMES_MALE = _G.LOCALIZED_CLASS_NAMES_MALE
local hooksecurefunc = _G.hooksecurefunc
local hasanysecretvalues = _G.hasanysecretvalues
local CUSTOM_CLASS_COLORS = rawget(_G, "CUSTOM_CLASS_COLORS")
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS

local LSM = T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)
local Textures = T.Tools and T.Tools.Textures
local Colors = T.Tools and T.Tools.Colors
local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
local FindAuraBySpellID = AuraUtil and (AuraUtil.FindAuraBySpellId or AuraUtil.FindAuraBySpellID)
local AttachTooltipHandlers

local MYTHIC_KEYSTONE_ITEM_IDS = {
    [138019] = true,
    [151086] = true,
    [158923] = true,
    [180653] = true,
}

local IsChallengeModeActive

local READY_COLOR = { 0.32, 0.86, 0.54 }
local ACTIVE_COLOR = { 0.33, 0.65, 0.96 }
local WARNING_COLOR = { 0.93, 0.51, 0.2 }
local ALERT_COLOR = { 0.85, 0.25, 0.25 }
local TIMER_PLUS_THREE_COLOR = { 0.36, 0.86, 0.54, 0.95 }
local TIMER_PLUS_TWO_COLOR = { 0.42, 0.82, 0.98, 0.95 }
local TIMER_PLUS_ONE_COLOR = { 0.95, 0.76, 0.24, 0.95 }
local TIMER_FORCES_COLOR = { 0.82, 0.36, 0.96, 0.95 }
local TIMER_MUTED_TEXT_COLOR = { 0.72, 0.74, 0.8, 1 }
local TIMER_ACTIVE_TEXT_COLOR = { 1, 0.95, 0.86, 1 }
local TIMER_SETTINGS_ICON = "Interface\\Buttons\\UI-OptionsButton"
local DUNGEON_DEATH_NOTIFICATION_ICON = "Interface\\Icons\\achievement_bg_xkills_avgraveyard"
local MUTED_SOUND_VALUE = "__none"
local DEBUG_LOG_LIMIT = 120
local DEBUG_SOURCE_KEY = "mythicplustools"
local RECENT_INTERRUPT_CAST_WINDOW = 0.35
local OBSERVED_INTERRUPT_DEDUPE_WINDOW = 0.08

local INTERRUPT_NAME_LOOKUP = nil

local ROLE_LABELS = {
    TANK = "Tank",
    HEALER = "Healer",
    DAMAGER = "DPS",
    NONE = "Unknown",
}

local ROLE_ORDER = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

local SPEC_INTERRUPT_DATA = {
    [62] = { spellID = 2139, cooldown = 24 },
    [63] = { spellID = 2139, cooldown = 24 },
    [64] = { spellID = 2139, cooldown = 24 },
    [65] = { spellID = 96231, cooldown = 15 },
    [66] = { spellID = 96231, cooldown = 15 },
    [70] = { spellID = 96231, cooldown = 15 },
    [71] = { spellID = 6552, cooldown = 15 },
    [72] = { spellID = 6552, cooldown = 15 },
    [73] = { spellID = 6552, cooldown = 15 },
    [102] = { spellID = 78675, cooldown = 60 },
    [103] = { spellID = 106839, cooldown = 15 },
    [104] = { spellID = 106839, cooldown = 15 },
    [250] = { spellID = 47528, cooldown = 15 },
    [251] = { spellID = 47528, cooldown = 15 },
    [252] = { spellID = 47528, cooldown = 15 },
    [253] = { spellID = 147362, cooldown = 24 },
    [254] = { spellID = 147362, cooldown = 24 },
    [255] = { spellID = 147362, cooldown = 24 },
    [258] = { spellID = 15487, cooldown = 45 },
    [259] = { spellID = 1766, cooldown = 15 },
    [260] = { spellID = 1766, cooldown = 15 },
    [261] = { spellID = 1766, cooldown = 15 },
    [262] = { spellID = 57994, cooldown = 12 },
    [263] = { spellID = 57994, cooldown = 12 },
    [264] = { spellID = 57994, cooldown = 12 },
    [268] = { spellID = 116705, cooldown = 15 },
    [269] = { spellID = 116705, cooldown = 15 },
    [270] = { spellID = 116705, cooldown = 15 },
    [577] = { spellID = 183752, cooldown = 15 },
    [581] = { spellID = 183752, cooldown = 15 },
    [1467] = { spellID = 351338, cooldown = 40 },
    [1468] = { spellID = 351338, cooldown = 40 },
    [1473] = { spellID = 351338, cooldown = 40 },
}

local CLASS_INTERRUPT_DATA = {
    DEATHKNIGHT = { spellID = 47528, cooldown = 15 },
    DEMONHUNTER = { spellID = 183752, cooldown = 15 },
    EVOKER = { spellID = 351338, cooldown = 40 },
    HUNTER = { spellID = 147362, cooldown = 24 },
    MAGE = { spellID = 2139, cooldown = 24 },
    MONK = { spellID = 116705, cooldown = 15 },
    PALADIN = { spellID = 96231, cooldown = 15 },
    ROGUE = { spellID = 1766, cooldown = 15 },
    SHAMAN = { spellID = 57994, cooldown = 12 },
    WARRIOR = { spellID = 6552, cooldown = 15 },
}

local SPEC_WITHOUT_INTERRUPT = {
    [65] = true,
    [105] = true,
    [256] = true,
    [257] = true,
}

local SUPPORTED_INTERRUPT_SPELLS = {}
local INTERRUPT_SPELL_COOLDOWNS = {}
for _, spellData in pairs(SPEC_INTERRUPT_DATA) do
    SUPPORTED_INTERRUPT_SPELLS[spellData.spellID] = true
    INTERRUPT_SPELL_COOLDOWNS[spellData.spellID] = spellData.cooldown
end
for _, spellData in pairs(CLASS_INTERRUPT_DATA) do
    SUPPORTED_INTERRUPT_SPELLS[spellData.spellID] = true
    INTERRUPT_SPELL_COOLDOWNS[spellData.spellID] = spellData.cooldown
end

local function GetOptions()
    return ConfigurationModule.Options.MythicPlusTools
end

local function IsModuleConfiguredEnabled()
    local options = GetOptions()
    return options and options.GetEnabled and options:GetEnabled() or false
end

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function CountTableEntries(value)
    local count = 0
    for _ in pairs(value or {}) do
        count = count + 1
    end
    return count
end

local function HasSecretValues(...)
    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, ...)
        if ok and hasSecret then
            return true
        end
    end

    return false
end

local function IsUsablePlainString(value)
    if type(value) ~= "string" then
        return false
    end

    if HasSecretValues(value) then
        return false
    end

    return true
end

local function SafeStringsEqual(left, right)
    if not IsUsablePlainString(left) or not IsUsablePlainString(right) then
        return false
    end

    local ok, equal = pcall(function()
        return left == right
    end)

    return ok and equal == true
end

local function GetBackdropColors()
    local bgR, bgG, bgB, bgA = 0.06, 0.06, 0.08, 0.98
    local borderR, borderG, borderB = 0.25, 0.25, 0.3
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.media then
        if E.media.backdropcolor then
            bgR, bgG, bgB = unpack(E.media.backdropcolor)
        elseif E.media.backdropfadecolor then
            bgR, bgG, bgB = unpack(E.media.backdropfadecolor)
        end

        if E.media.bordercolor then
            borderR, borderG, borderB = unpack(E.media.bordercolor)
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

local function SetLockButtonTextures(button, isLocked)
    if not button then
        return
    end

    local textureState = isLocked and "Locked" or "Unlocked"
    if button.Icon then
        button.Icon:SetTexture("Interface\\Buttons\\LockButton-" .. textureState .. "-Up")
    end
end

local function GetTrackerFontPath(fontKey)
    if fontKey and fontKey ~= "__default" and LSM and LSM.Fetch then
        local fontPath = LSM:Fetch("font", fontKey)
        if fontPath then
            return fontPath
        end
    end

    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function GetOutlineFlag(value)
    if value == "none" then
        return ""
    end
    if value == "outline" then
        return "OUTLINE"
    end
    if value == "thick" then
        return "THICKOUTLINE"
    end
    return nil
end

local function ApplyFontString(fontString, fontPath, fontSize, outline, red, green, blue, alpha)
    if not fontString then
        return
    end

    fontString:SetFont(fontPath, fontSize, outline)
    if red then
        fontString:SetTextColor(red, green or red, blue or red, alpha or 1)
    end
end

local function SetStatusBarColor(bar, color)
    if not bar or not color then
        return
    end

    bar:SetStatusBarColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function CreateMasqueButtonData(icon, highlight)
    return {
        Icon = icon,
        Highlight = highlight,
        FloatingBG = nil,
        Cooldown = nil,
        Flash = nil,
        Pushed = nil,
        Normal = nil,
        Disabled = nil,
        Checked = nil,
        Border = nil,
        AutoCastable = nil,
        HotKey = nil,
        Count = false,
        Name = nil,
        Duration = false,
        AutoCast = nil,
    }
end

local function GetClassDisplayName(classToken)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken or ""]) or classToken or "Unknown"
end

local function GetClassTooltipIcon(classToken, size)
    if Textures and Textures.GetClassTextureString then
        return Textures:GetClassTextureString(classToken, size or 16, "default")
    end

    return ""
end

local function BuildSpellTooltipTitle(texture, label)
    if texture then
        return ("|T%s:18:18:0:0:64:64:5:59:5:59|t %s"):format(texture, label or "")
    end

    return label or ""
end

local function BuildClassTooltipLine(classTokens, size)
    if type(classTokens) ~= "table" or #classTokens == 0 then
        return nil
    end

    local parts = {}
    for _, classToken in ipairs(classTokens) do
        parts[#parts + 1] = ("%s %s"):format(GetClassTooltipIcon(classToken, size or 14), GetClassDisplayName(classToken))
    end

    return table.concat(parts, "   ")
end

local function TrimText(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

local function GetFullUnitName(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    if type(UnitFullName) == "function" then
        local name, realm = UnitFullName(unit)
        name = TrimText(name)
        realm = TrimText(realm)
        if name ~= "" and realm ~= "" then
            return name .. "-" .. realm
        end
        if name ~= "" then
            return name
        end
    end

    local name = type(UnitName) == "function" and UnitName(unit) or nil
    name = TrimText(name)
    return name ~= "" and name or nil
end

local function GetShortName(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return "Unknown"
    end

    if _G.Ambiguate then
        return _G.Ambiguate(fullName, "short")
    end

    return fullName
end

local function GetClassColor(classToken)
    local colorTable = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
    local color = colorTable and colorTable[classToken or ""] or nil
    if color then
        return color.r or 1, color.g or 1, color.b or 1
    end

    return 1, 1, 1
end

local function BuildColoredName(name, classToken)
    local red, green, blue = GetClassColor(classToken)
    return format("|cff%02x%02x%02x%s|r", floor(red * 255), floor(green * 255), floor(blue * 255), name or "Unknown")
end

local function GetInterruptNameLookup()
    if INTERRUPT_NAME_LOOKUP then
        return INTERRUPT_NAME_LOOKUP
    end

    local lookup = {}
    for spellID in pairs(SUPPORTED_INTERRUPT_SPELLS or {}) do
        local spellName = (C_Spell and type(C_Spell.GetSpellName) == "function" and C_Spell.GetSpellName(spellID)) or
            GetSpellInfo(spellID)
        if type(spellName) == "string" and spellName ~= "" then
            lookup[spellName] = spellID
        end
    end

    INTERRUPT_NAME_LOOKUP = lookup
    return lookup
end

local function ResolveObservedInterruptSpellIDFromArgs(...)
    local count = select("#", ...)
    for index = 1, count do
        local value = select(index, ...)
        -- Secret values: tonumber may return a secret number, and even plain
        -- nil from tonumber can mask a secret arg.  Guard all table accesses.
        if not HasSecretValues(value) then
            local numeric = tonumber(value)
            if numeric and numeric > 0 and SUPPORTED_INTERRUPT_SPELLS[numeric] then
                return numeric
            end
            if IsUsablePlainString(value) then
                local spellID = GetInterruptNameLookup()[value]
                if spellID then
                    return spellID
                end
            end
        end
    end

    return nil
end

local function FormatDuration(seconds, includeTenths)
    seconds = max(0, tonumber(seconds) or 0)
    if includeTenths and seconds < 10 then
        return format("%.1fs", seconds)
    end

    local wholeSeconds = floor(seconds + 0.5)
    local minutes = floor(wholeSeconds / 60)
    local remaining = wholeSeconds % 60
    return format("%02d:%02d", minutes, remaining)
end

local function GetSoundPath(soundKey)
    if not soundKey or soundKey == MUTED_SOUND_VALUE then
        return nil
    end

    return LSM and LSM.Fetch and LSM:Fetch("sound", soundKey) or nil
end

local function PlayConfiguredSound(soundKey)
    local soundPath = GetSoundPath(soundKey)
    if soundPath and type(PlaySoundFile) == "function" then
        PlaySoundFile(soundPath, "Master")
    end
end

function MPT:GetTrackerAppearance()
    -- Return the cached table when it is still valid for this tick.
    if not self.trackerAppearanceDirty then
        return self.trackerAppearanceCache
    end
    self.trackerAppearanceDirty  = false

    local c                      = self.trackerAppearanceCache
    local db                     = self:GetDB()
    local options                = GetOptions()
    local outline                = GetOutlineFlag(db.trackerFontOutline)

    -- Use options getters so that unset values fall back to global theme settings
    -- (globalFont for fonts, statusBarTexture for bar textures).
    local resolvedFont           = options and options:GetTrackerFont() or db.trackerFont
    local resolvedBarTextureName = options and options:GetTrackerBarTexture() or "Blizzard"
    local resolvedStatusFont     = options and options:GetStatusTextFont() or db.statusTextFont
    local resolvedReadyFont      = options and options:GetReadyTextFont() or db.readyTextFont

    c.fontPath                   = GetTrackerFontPath(resolvedFont)
    c.fontSize                   = ClampNumber(db.trackerFontSize, 8, 24, 12)
    c.outline                    = outline
    c.rowGap                     = ClampNumber(db.trackerRowGap, 0, 20, 6)
    c.iconSize                   = ClampNumber(db.trackerIconSize, 14, 32, 18)
    c.barHeight                  = ClampNumber(db.trackerBarHeight, 10, 30, 18)
    c.barTexture                 = (LSM and LSM.Fetch and LSM:Fetch("statusbar", resolvedBarTextureName)) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    c.statusTextFontPath         = GetTrackerFontPath(resolvedStatusFont)
    c.readyTextFontPath          = GetTrackerFontPath(resolvedReadyFont)
    c.showReadyText              = db.showReadyText ~= false
    c.frameVisibilityMode        = db.frameVisibilityMode or "mythicplus"
    c.interruptReadyBarColorMode = db.interruptReadyBarColorMode or "default"
    c.useInterruptClassBarColor  = db.interruptUseClassBarColor ~= false
    c.useInterruptClassFontColor = db.interruptUseClassFontColor ~= false

    -- Update colour sub-tables in place (no new table allocations after first call).
    local stc                    = c.statusTextColor
    stc[1]                       = (db.statusTextColor and db.statusTextColor.r) or 0.96
    stc[2]                       = (db.statusTextColor and db.statusTextColor.g) or 0.93
    stc[3]                       = (db.statusTextColor and db.statusTextColor.b) or 0.86
    stc[4]                       = 1

    local rtc                    = c.readyTextColor
    rtc[1]                       = (db.readyTextColor and db.readyTextColor.r) or READY_COLOR[1]
    rtc[2]                       = (db.readyTextColor and db.readyTextColor.g) or READY_COLOR[2]
    rtc[3]                       = (db.readyTextColor and db.readyTextColor.b) or READY_COLOR[3]
    rtc[4]                       = 1

    local ibc                    = c.interruptBarColor
    ibc[1]                       = (db.interruptBarColor and db.interruptBarColor.r) or 0.33
    ibc[2]                       = (db.interruptBarColor and db.interruptBarColor.g) or 0.65
    ibc[3]                       = (db.interruptBarColor and db.interruptBarColor.b) or 0.96
    ibc[4]                       = 1

    local irbc                   = c.interruptReadyBarColor
    irbc[1]                      = (db.interruptReadyBarColor and db.interruptReadyBarColor.r) or READY_COLOR[1]
    irbc[2]                      = (db.interruptReadyBarColor and db.interruptReadyBarColor.g) or READY_COLOR[2]
    irbc[3]                      = (db.interruptReadyBarColor and db.interruptReadyBarColor.b) or READY_COLOR[3]
    irbc[4]                      = 1

    local ifc                    = c.interruptFontColor
    ifc[1]                       = (db.interruptFontColor and db.interruptFontColor.r) or 0.96
    ifc[2]                       = (db.interruptFontColor and db.interruptFontColor.g) or 0.93
    ifc[3]                       = (db.interruptFontColor and db.interruptFontColor.b) or 0.86
    ifc[4]                       = 1

    c.trackerStyle               = db.trackerStyle or "paneled"

    return c
end

function MPT:GetMythicPlusTimerAppearance()
    local appearance = self:GetTrackerAppearance()
    local db = self:GetDB()
    local options = GetOptions()
    local fontColor = self.trackerAppearanceCache.timerFontColor
    local mutedColor = self.trackerAppearanceCache.timerMutedTextColor
    local customBarColor = self.trackerAppearanceCache.timerBarColor

    appearance.timerFontPath = GetTrackerFontPath(options and options:GetMythicPlusTimerFont() or
        (db.mythicPlusTimerFont or db.trackerFont))
    appearance.timerFontSize = ClampNumber(db.mythicPlusTimerFontSize, 8, 28, appearance.fontSize)
    appearance.timerOutline = GetOutlineFlag(db.mythicPlusTimerFontOutline or db.trackerFontOutline)
    appearance.timerRowGap = ClampNumber(db.mythicPlusTimerRowGap, 0, 30, appearance.rowGap)
    appearance.timerBarHeight = ClampNumber(db.mythicPlusTimerBarHeight, 10, 40, appearance.barHeight)
    local timerBarTextureName = options and options:GetMythicPlusTimerBarTexture()
    appearance.timerBarTexture =
        (timerBarTextureName and LSM and LSM.Fetch and LSM:Fetch("statusbar", timerBarTextureName)) or
        appearance.barTexture
    appearance.timerLayout = db.mythicPlusTimerLayout == "right" and "right" or "left"
    appearance.timerBarColorMode = db.mythicPlusTimerBarColorMode == "custom" and "custom" or "milestone"

    fontColor[1] = (db.mythicPlusTimerFontColor and db.mythicPlusTimerFontColor.r)
        or (db.statusTextColor and db.statusTextColor.r)
        or TIMER_ACTIVE_TEXT_COLOR[1]
    fontColor[2] = (db.mythicPlusTimerFontColor and db.mythicPlusTimerFontColor.g)
        or (db.statusTextColor and db.statusTextColor.g)
        or TIMER_ACTIVE_TEXT_COLOR[2]
    fontColor[3] = (db.mythicPlusTimerFontColor and db.mythicPlusTimerFontColor.b)
        or (db.statusTextColor and db.statusTextColor.b)
        or TIMER_ACTIVE_TEXT_COLOR[3]
    fontColor[4] = 1

    mutedColor[1] = max(0, min(1, fontColor[1] * 0.76))
    mutedColor[2] = max(0, min(1, fontColor[2] * 0.76))
    mutedColor[3] = max(0, min(1, fontColor[3] * 0.76))
    mutedColor[4] = 1

    customBarColor[1] = (db.mythicPlusTimerBarColor and db.mythicPlusTimerBarColor.r) or TIMER_PLUS_TWO_COLOR[1]
    customBarColor[2] = (db.mythicPlusTimerBarColor and db.mythicPlusTimerBarColor.g) or TIMER_PLUS_TWO_COLOR[2]
    customBarColor[3] = (db.mythicPlusTimerBarColor and db.mythicPlusTimerBarColor.b) or TIMER_PLUS_TWO_COLOR[3]
    customBarColor[4] = 0.95

    return appearance
end

function MPT:ApplyTrackerFrameStyle(frame)
    if not frame then
        return
    end

    local appearance = self:GetTrackerAppearance()
    local style = appearance.trackerStyle or "paneled"
    local isBare = style == "bare"

    -- Outer frame backdrop
    if frame.BackgroundFill then
        frame.BackgroundFill:SetShown(not isBare)
    end
    if frame.InnerGlow then
        frame.InnerGlow:SetShown(not isBare)
    end
    if frame.SetBackdropColor then
        if isBare then
            frame:SetBackdropColor(0, 0, 0, 0)
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        else
            local bgR, bgG, bgB, bgA, borderR, borderG, borderB = GetBackdropColors()
            frame:SetBackdropColor(bgR, bgG, bgB, bgA)
            frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)
        end
    end

    -- TitleBar backdrop
    if frame.TitleBar and frame.TitleBar.SetBackdropColor then
        if isBare then
            frame.TitleBar:SetBackdropColor(0, 0, 0, 0)
            frame.TitleBar:SetBackdropBorderColor(0, 0, 0, 0)
        else
            local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()
            frame.TitleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.98)
            frame.TitleBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.35)
        end
    end

    -- TitleAccent (gold top line)
    if frame.TitleAccent then
        frame.TitleAccent:SetShown(not isBare)
    end

    -- ContentInset backdrop
    if frame.ContentInset and frame.ContentInset.SetBackdropColor then
        if isBare then
            frame.ContentInset:SetBackdropColor(0, 0, 0, 0)
            frame.ContentInset:SetBackdropBorderColor(0, 0, 0, 0)
        else
            local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()
            frame.ContentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, 0.98)
            frame.ContentInset:SetBackdropBorderColor(borderR, borderG, borderB, 0.45)
        end
    end
end

function MPT:GetTrackerMetrics()
    local appearance = self:GetTrackerAppearance()
    -- Reuse the metrics cache table so no allocation occurs after the first call.
    local m          = self.trackerMetricsCache
    m.appearance     = appearance
    m.iconSize       = appearance.iconSize
    m.rowGap         = appearance.rowGap
    m.barHeight      = appearance.barHeight
    m.rowHeight      = max(22, max(appearance.iconSize, appearance.barHeight) + 2)
    return m
end

function MPT:ShouldShowTrackerFrames()
    local mode = self:GetTrackerAppearance().frameVisibilityMode
    if self.preview.interrupts then
        return true
    end

    if mode == "always" then
        return true
    end

    if mode == "combat" then
        return InCombatLockdown and InCombatLockdown() or false
    end

    if mode == "group" then
        return IsInGroup and IsInGroup() or false
    end

    if mode == "dungeon" then
        local _, instanceType = GetInstanceInfo()
        return instanceType == "party"
    end

    return IsChallengeModeActive()
end

function MPT:GetStatusTextStyle(state)
    local appearance = self:GetTrackerAppearance()
    if state and state.isReady then
        return appearance.readyTextFontPath, appearance.readyTextColor, appearance.showReadyText
    end

    return appearance.statusTextFontPath, appearance.statusTextColor, true
end

function MPT:GetFrameSizeDefaults(kind)
    if kind == "timer" then
        return {
            width = 420,
            height = 320,
            minWidth = 360,
            minHeight = 250,
            maxWidth = 720,
            maxHeight = 540,
        }
    end

    return {
        width = 350,
        height = 250,
        minWidth = 280,
        minHeight = 180,
        maxWidth = 600,
        maxHeight = 420,
    }
end

function MPT:GetFrameLocked(kind)
    local db = self:GetDB()
    if kind == "timer" then
        if db.mythicPlusTimerLocked == nil then
            return true
        end

        return db.mythicPlusTimerLocked == true
    end

    return db.interruptTrackerLocked == true
end

function MPT:SetFrameLocked(kind, isLocked)
    local db = self:GetDB()
    if kind == "timer" then
        db.mythicPlusTimerLocked = isLocked == true
    else
        db.interruptTrackerLocked = isLocked == true
    end
    self:ApplyFrameLockStates()
end

function MPT:SaveFrameSize(kind, frame)
    if not (frame and frame.GetSize) then
        return
    end

    local defaults = self:GetFrameSizeDefaults(kind)
    local width, height = frame:GetSize()
    local db = self:GetDB()

    db[kind .. "Width"] = ClampNumber(width, defaults.minWidth, defaults.maxWidth, defaults.width)
    db[kind .. "Height"] = ClampNumber(height, defaults.minHeight, defaults.maxHeight, defaults.height)
end

function MPT:ApplyFrameSize(kind, frame)
    if not frame then
        return
    end

    local defaults = self:GetFrameSizeDefaults(kind)
    local db = self:GetDB()
    local width = ClampNumber(db[kind .. "Width"], defaults.minWidth, defaults.maxWidth, defaults.width)
    local height = ClampNumber(db[kind .. "Height"], defaults.minHeight, defaults.maxHeight, defaults.height)

    frame:SetSize(width, height)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(defaults.minWidth, defaults.minHeight, defaults.maxWidth, defaults.maxHeight)
    else
        if frame.SetMinResize then
            frame:SetMinResize(defaults.minWidth, defaults.minHeight)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(defaults.maxWidth, defaults.maxHeight)
        end
    end
end

function MPT:SetFrameHovered(frame, isHovered)
    if not frame then
        return
    end

    frame.controlsHovered = isHovered == true
    self:RefreshFrameControls(frame.kind, frame)
end

function MPT:UpdateFrameHoverState(frame)
    if not frame then
        return
    end

    local isHovered = MouseIsOver(frame) or
        (frame.LockButton and frame.LockButton:IsShown() and MouseIsOver(frame.LockButton)) or
        (frame.SettingsButton and frame.SettingsButton:IsShown() and MouseIsOver(frame.SettingsButton)) or
        (frame.CloseButton and frame.CloseButton:IsShown() and MouseIsOver(frame.CloseButton)) or
        (frame.ResizeHandle and frame.ResizeHandle:IsShown() and MouseIsOver(frame.ResizeHandle)) or false

    if frame.controlsHovered ~= isHovered then
        frame.controlsHovered = isHovered
        self:RefreshFrameControls(frame.kind, frame)
    end
end

function MPT:RefreshFrameControls(kind, frame)
    if not frame then
        return
    end

    local isLocked = self:GetFrameLocked(kind)
    local isHovered = frame.controlsHovered == true

    SetLockButtonTextures(frame.LockButton, isLocked)
    frame:SetMovable(not isLocked)
    frame:SetResizable(not isLocked)

    if isLocked then
        frame:StopMovingOrSizing()
    end

    if frame.ResizeHandle then
        frame.ResizeHandle:EnableMouse(not isLocked)
        frame.ResizeHandle:SetShown(not isLocked)
    end

    if frame.LockButton then
        frame.LockButton:SetShown(isHovered)
    end

    if frame.SettingsButton then
        frame.SettingsButton:SetShown(frame.hasSettingsButton == true and isHovered)
    end

    if frame.CloseButton then
        frame.CloseButton:SetShown(frame.suppressCloseButton ~= true and (not isLocked or isHovered))
    end
end

function MPT:MakeFrameResizable(kind, frame)
    if not frame or frame.resizeInitialized then
        return
    end

    frame.ResizeHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not self:GetFrameLocked(kind) then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)

    frame.ResizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SaveFrameSize(kind, frame)
        self:RefreshTrackerStyling()
    end)

    frame:HookScript("OnSizeChanged", function(sizedFrame)
        if sizedFrame.EmptyText then
            sizedFrame.EmptyText:SetWidth(max(160, (sizedFrame:GetWidth() or 260) - 60))
        end
        if sizedFrame:IsShown() then
            if kind == "interrupt" then
                self:ApplyRowLayout(sizedFrame)
                self:RefreshInterruptFrame()
            elseif kind == "timer" then
                self:RefreshMythicPlusTimerFrame()
            end
        end
    end)

    frame.resizeInitialized = true
end

function MPT:GetMasqueGroup(kind)
    if not Masque then
        return nil
    end

    self.masqueGroups = self.masqueGroups or {}
    if self.masqueGroups[kind] then
        return self.masqueGroups[kind]
    end

    local label = "Mythic+ Interrupts"
    self.masqueGroups[kind] = Masque:Group("TwichUI Reformed", label)
    return self.masqueGroups[kind]
end

function MPT:RegisterRowWithMasque(kind, row)
    local group = self:GetMasqueGroup(kind)
    if not (group and row and row.iconButton and row.icon and not row.masqueRegistered) then
        return
    end

    group:AddButton(row.iconButton, CreateMasqueButtonData(row.icon, row.iconHighlight))
    row.masqueRegistered = true
    if group.ReSkin then
        group:ReSkin()
    end
end

function MPT:GetInterruptBarColor(member)
    local appearance = self:GetTrackerAppearance()
    if appearance.useInterruptClassBarColor and member and member.classToken then
        local red, green, blue = GetClassColor(member.classToken)
        -- Reuse scratch to avoid per-row allocation.
        local s = self._barColorScratch
        s[1] = red; s[2] = green; s[3] = blue; s[4] = 0.95
        return s
    end
    return appearance.interruptBarColor
end

function MPT:GetInterruptReadyBarColor(member)
    local appearance = self:GetTrackerAppearance()
    local mode = appearance.interruptReadyBarColorMode
    if mode == "class" and member and member.classToken then
        local red, green, blue = GetClassColor(member.classToken)
        local s = self._readyBarColorScratch
        s[1] = red; s[2] = green; s[3] = blue; s[4] = 0.95
        return s
    end
    if mode == "static" then
        return appearance.interruptReadyBarColor
    end
    return READY_COLOR
end

function MPT:GetInterruptFontColor(member)
    local appearance = self:GetTrackerAppearance()
    if appearance.useInterruptClassFontColor and member and member.classToken then
        local red, green, blue = GetClassColor(member.classToken)
        local s = self._fontColorScratch
        s[1] = red; s[2] = green; s[3] = blue; s[4] = 1
        return s
    end
    return appearance.interruptFontColor
end

function MPT:RefreshTrackerStyling()
    -- Invalidate the appearance cache so the new global settings (statusBarTexture,
    -- globalFont, etc.) are picked up immediately rather than waiting for the next tick.
    self.trackerAppearanceDirty = true
    self:ApplyFrameLockStates()
    if self.interruptFrame then
        self:ApplyRowLayout(self.interruptFrame)
        self:RefreshInterruptFrame()
    end
    if self.mythicPlusTimerFrame then
        self:RefreshMythicPlusTimerFrame()
    end
end

function MPT:EnsureBarSmoothing()
    if self.barSmoothingInitialized then
        return
    end

    self.barSmoothingInitialized = true
    self.activeSmoothBars = self.activeSmoothBars or {}

    self.barSmoothingFrame = CreateFrame("Frame")
    self.barSmoothingFrame:SetScript("OnUpdate", function(_, elapsed)
        local hasActiveBars = false
        for bar in pairs(self.activeSmoothBars) do
            if bar and bar.GetMinMaxValues and bar.GetValue then
                local minValue, maxValue = bar:GetMinMaxValues()
                local currentValue = bar._smoothValue or bar:GetValue()
                local targetValue = bar._smoothTarget or currentValue
                local range = (maxValue or 0) - (minValue or 0)
                local step = min(1, elapsed * 12)
                local newValue = Lerp(currentValue, targetValue, step)

                if range <= 0 or abs(newValue - targetValue) <= max(0.001, range * 0.001) then
                    newValue = targetValue
                    self.activeSmoothBars[bar] = nil
                else
                    hasActiveBars = true
                end

                if bar.SetValue_ then
                    bar:SetValue_(newValue)
                end
                bar._smoothValue = newValue
            else
                self.activeSmoothBars[bar] = nil
            end
        end

        if not hasActiveBars and not next(self.activeSmoothBars) then
            self.barSmoothingFrame:Hide()
        end
    end)
    self.barSmoothingFrame:Hide()
end

function MPT:EnableTrackerBarSmoothing(bar)
    if not bar or bar.smoothingEnabled then
        return
    end

    local elvuiEngine = _G.ElvUI and _G.ElvUI[1] or nil
    if elvuiEngine and type(elvuiEngine.SetSmoothing) == "function" then
        elvuiEngine:SetSmoothing(bar, true)
        bar.smoothingEnabled = true
        bar.usesElvUISmoothing = true
        return
    end

    self:EnsureBarSmoothing()

    bar.SetValue_ = bar.SetValue
    bar.SetValue = function(smoothingBar, value)
        value = tonumber(value) or 0
        local minValue, maxValue = smoothingBar:GetMinMaxValues()
        value = ClampNumber(value, minValue or 0, maxValue or 1, minValue or 0)

        smoothingBar._smoothValue = smoothingBar._smoothValue or smoothingBar:GetValue()
        smoothingBar._smoothTarget = value
        self.activeSmoothBars[smoothingBar] = true
        self.barSmoothingFrame:Show()
    end

    bar.smoothingEnabled = true
end

function IsChallengeModeActive()
    return C_ChallengeMode and type(C_ChallengeMode.IsChallengeModeActive) == "function" and
        C_ChallengeMode.IsChallengeModeActive() == true
end

local function IsMythicDungeonContext()
    if type(GetInstanceInfo) ~= "function" or type(IsInInstance) ~= "function" then
        return false
    end

    local inInstance = IsInInstance()
    if not inInstance then
        return false
    end

    local _, instanceType, difficultyID = GetInstanceInfo()
    return instanceType == "party" and (difficultyID == 8 or IsChallengeModeActive())
end

local function HasSlottedKeystone()
    if C_ChallengeMode and type(C_ChallengeMode.GetSlottedKeystoneInfo) == "function" then
        local mapID = C_ChallengeMode.GetSlottedKeystoneInfo()
        return type(mapID) == "number" and mapID > 0
    end

    return false
end

local function FormatClock(seconds, alwaysShowHours)
    seconds = max(0, tonumber(seconds) or 0)
    local wholeSeconds = floor(seconds + 0.5)
    local hours = floor(wholeSeconds / 3600)
    local minutes = floor((wholeSeconds % 3600) / 60)
    local remainingSeconds = wholeSeconds % 60

    if hours > 0 or alwaysShowHours then
        return format("%d:%02d:%02d", hours, minutes, remainingSeconds)
    end

    return format("%02d:%02d", minutes, remainingSeconds)
end

local function FormatSignedClock(seconds)
    local numericValue = tonumber(seconds) or 0
    if numericValue < 0 then
        return "-" .. FormatClock(abs(numericValue))
    end

    return FormatClock(numericValue)
end

local function GetMythicPlusMapName(mapID)
    if not (C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function") then
        return "Mythic+"
    end

    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if type(name) == "string" and name ~= "" then
        return name
    end

    return "Mythic+"
end

local function NormalizeCheckpointName(value, fallback)
    if type(value) == "string" then
        value = value:match("^%s*(.-)%s*$")
        if value and value ~= "" then
            return value
        end
    end

    return fallback or "Checkpoint"
end

local function BuildDefaultBossCheckpointID(bossIndex)
    return "boss_" .. tostring(tonumber(bossIndex) or 0)
end

local function NormalizeCheckpointID(rawID, fallbackPrefix, fallbackIndex)
    local value = type(rawID) == "string" and rawID:match("^%s*(.-)%s*$") or nil
    if value and value ~= "" then
        return value
    end

    return tostring(fallbackPrefix or "checkpoint") .. "_" .. tostring(tonumber(fallbackIndex) or 0)
end

local function CloneCheckpointEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    return {
        id = entry.id,
        kind = entry.kind,
        bossIndex = entry.bossIndex,
        name = entry.name,
        percent = entry.percent,
        notifyEnabled = entry.notifyEnabled,
    }
end

local function SortCheckpointList(checkpoints)
    tsort(checkpoints, function(left, right)
        local leftPercent = tonumber(left and left.percent) or 0
        local rightPercent = tonumber(right and right.percent) or 0
        if leftPercent ~= rightPercent then
            return leftPercent < rightPercent
        end

        local leftBoss = left and left.kind == "boss"
        local rightBoss = right and right.kind == "boss"
        if leftBoss ~= rightBoss then
            return leftBoss
        end

        local leftBossIndex = tonumber(left and left.bossIndex) or 0
        local rightBossIndex = tonumber(right and right.bossIndex) or 0
        if leftBossIndex ~= rightBossIndex then
            return leftBossIndex < rightBossIndex
        end

        return tostring(left and left.name or "") < tostring(right and right.name or "")
    end)
end

local function GetEncounterJournalFunctions()
    local isLoaded = (type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" and
            C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")) or
        (type(IsAddOnLoaded) == "function" and IsAddOnLoaded("Blizzard_EncounterJournal"))
    if not isLoaded and type(LoadAddOn) == "function" then
        pcall(LoadAddOn, "Blizzard_EncounterJournal")
    end

    if type(_G.EJ_SelectTier) ~= "function" or type(_G.EJ_GetCurrentTier) ~= "function" or
        type(_G.EJ_GetNumTiers) ~= "function" or type(_G.EJ_GetInstanceByIndex) ~= "function" or
        type(_G.EJ_SelectInstance) ~= "function" or type(_G.EJ_GetEncounterInfoByIndex) ~= "function" then
        return nil
    end

    return {
        selectTier = _G.EJ_SelectTier,
        getCurrentTier = _G.EJ_GetCurrentTier,
        getNumTiers = _G.EJ_GetNumTiers,
        getInstanceByIndex = _G.EJ_GetInstanceByIndex,
        selectInstance = _G.EJ_SelectInstance,
        getEncounterInfoByIndex = _G.EJ_GetEncounterInfoByIndex,
    }
end

local function SafeEncounterJournalSelectTier(ej, tierIndex)
    if not ej or type(ej.selectTier) ~= "function" then
        return false
    end

    local numericTier = tonumber(tierIndex)
    if not numericTier or numericTier <= 0 then
        return false
    end

    local ok = pcall(ej.selectTier, numericTier)
    return ok == true
end

local function NormalizeDungeonSearchKey(name)
    local value = type(name) == "string" and string.lower(name) or ""
    value = value:gsub("['`%-]", "")
    value = value:gsub("[^%w]", "")
    return value
end

local function FindBestEncounterJournalInstance(mapName)
    local ej = GetEncounterJournalFunctions()
    if not ej then
        return nil
    end

    local searchKey = NormalizeDungeonSearchKey(mapName)
    if searchKey == "" then
        return nil
    end

    local exactMatch, partialMatch
    local previousTier = ej.getCurrentTier()
    for tierIndex = 1, ej.getNumTiers() do
        if not SafeEncounterJournalSelectTier(ej, tierIndex) then
            break
        end
        local instanceIndex = 1
        while true do
            local instanceID, instanceName = ej.getInstanceByIndex(instanceIndex, true)
            if not instanceID then
                break
            end

            local instanceKey = NormalizeDungeonSearchKey(instanceName)
            if instanceKey == searchKey then
                exactMatch = { tier = tierIndex, id = instanceID, name = instanceName }
                break
            elseif instanceKey ~= "" and (instanceKey:find(searchKey, 1, true) or searchKey:find(instanceKey, 1, true)) then
                partialMatch = partialMatch or { tier = tierIndex, id = instanceID, name = instanceName }
            end

            instanceIndex = instanceIndex + 1
        end

        if exactMatch then
            break
        end
    end

    if previousTier then
        SafeEncounterJournalSelectTier(ej, previousTier)
    end

    return exactMatch or partialMatch
end

function MPT:GetSeasonalDungeonEntries()
    local entries = {}
    if not (C_ChallengeMode and type(C_ChallengeMode.GetMapTable) == "function") then
        return entries
    end

    for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        if type(mapID) == "number" and mapID > 0 then
            entries[#entries + 1] = {
                mapID = mapID,
                name = GetMythicPlusMapName(mapID),
            }
        end
    end

    tsort(entries, function(left, right)
        local leftName = string.lower(tostring(left and left.name or ""))
        local rightName = string.lower(tostring(right and right.name or ""))
        if leftName == rightName then
            return (left and left.mapID or 0) < (right and right.mapID or 0)
        end

        return leftName < rightName
    end)

    return entries
end

function MPT:GetSeasonalDungeonChoices()
    local values = {}
    for _, entry in ipairs(self:GetSeasonalDungeonEntries()) do
        values[entry.mapID] = entry.name
    end
    return values
end

function MPT:GetDefaultDungeonCheckpoints(mapID)
    self.dungeonCheckpointDefaults = self.dungeonCheckpointDefaults or {}
    mapID = tonumber(mapID)
    if not mapID or mapID <= 0 then
        return {}
    end

    if self.dungeonCheckpointDefaults[mapID] then
        local cached = {}
        for _, checkpoint in ipairs(self.dungeonCheckpointDefaults[mapID]) do
            cached[#cached + 1] = CloneCheckpointEntry(checkpoint)
        end
        return cached
    end

    local bossNames = {}
    local instanceInfo = FindBestEncounterJournalInstance(GetMythicPlusMapName(mapID))
    local ej = GetEncounterJournalFunctions()
    if instanceInfo and ej then
        local previousTier = ej.getCurrentTier()
        if SafeEncounterJournalSelectTier(ej, instanceInfo.tier) then
            local selectedOk = pcall(ej.selectInstance, instanceInfo.id)
            if selectedOk then
                local encounterIndex = 1
                while true do
                    local name = ej.getEncounterInfoByIndex(encounterIndex)
                    if not name then
                        break
                    end

                    bossNames[#bossNames + 1] = NormalizeCheckpointName(name, format("Boss %d", encounterIndex))
                    encounterIndex = encounterIndex + 1
                end
            end
        end
        if previousTier then
            SafeEncounterJournalSelectTier(ej, previousTier)
        end
    end

    if #bossNames == 0 then
        for bossIndex = 1, 4 do
            bossNames[#bossNames + 1] = format("Boss %d", bossIndex)
        end
    end

    local defaults = {}
    for bossIndex, bossName in ipairs(bossNames) do
        local percent = bossIndex == #bossNames and 100 or floor(((bossIndex / #bossNames) * 100) + 0.5)
        defaults[#defaults + 1] = {
            id = BuildDefaultBossCheckpointID(bossIndex),
            kind = "boss",
            bossIndex = bossIndex,
            name = bossName,
            percent = percent,
            notifyEnabled = true,
        }
    end

    self.dungeonCheckpointDefaults[mapID] = {}
    for _, checkpoint in ipairs(defaults) do
        self.dungeonCheckpointDefaults[mapID][#self.dungeonCheckpointDefaults[mapID] + 1] = CloneCheckpointEntry(
            checkpoint)
    end

    return defaults
end

function MPT:NormalizeDungeonCheckpointList(checkpoints, mapID)
    local normalized = {}
    local bossFallbacks = self:GetDefaultDungeonCheckpoints(mapID)
    local bossNameByIndex = {}
    for _, entry in ipairs(bossFallbacks) do
        if entry.bossIndex then
            bossNameByIndex[entry.bossIndex] = entry.name
        end
    end

    for index, rawEntry in ipairs(type(checkpoints) == "table" and checkpoints or {}) do
        if type(rawEntry) == "table" then
            local kind = rawEntry.kind == "boss" and "boss" or "custom"
            local bossIndex = kind == "boss" and tonumber(rawEntry.bossIndex) or nil
            local fallbackName = kind == "boss" and bossNameByIndex[bossIndex or index] or
                format("Custom Checkpoint %d", index)
            normalized[#normalized + 1] = {
                id = NormalizeCheckpointID(rawEntry.id, kind, bossIndex or index),
                kind = kind,
                bossIndex = bossIndex,
                name = NormalizeCheckpointName(rawEntry.name, fallbackName),
                percent = ClampNumber(rawEntry.percent, 0, 100, kind == "boss" and 100 or 50),
                notifyEnabled = rawEntry.notifyEnabled ~= false,
            }
        end
    end

    if #normalized == 0 then
        normalized = self:GetDefaultDungeonCheckpoints(mapID)
    end

    SortCheckpointList(normalized)
    return normalized
end

function MPT:GetCheckpointConfigDB()
    local db = self:GetDB()
    if type(db.mythicPlusTimerMinionCheckpoints) ~= "table" then
        db.mythicPlusTimerMinionCheckpoints = {}
    end

    local checkpointDB = db.mythicPlusTimerMinionCheckpoints
    if type(checkpointDB.dungeons) ~= "table" then
        checkpointDB.dungeons = {}
    end

    if type(checkpointDB.selectedMapID) == "string" then
        local numericValue = tonumber(checkpointDB.selectedMapID)
        if numericValue and numericValue > 0 then
            checkpointDB.selectedMapID = numericValue
        else
            local selectedSearchKey = NormalizeDungeonSearchKey(checkpointDB.selectedMapID)
            for _, entry in ipairs(self:GetSeasonalDungeonEntries()) do
                if NormalizeDungeonSearchKey(entry.name) == selectedSearchKey then
                    checkpointDB.selectedMapID = entry.mapID
                    break
                end
            end
        end
    end

    if type(checkpointDB.selectedMapID) ~= "number" or checkpointDB.selectedMapID <= 0 then
        local seasonal = self:GetSeasonalDungeonEntries()
        checkpointDB.selectedMapID = seasonal[1] and seasonal[1].mapID or nil
    end

    return checkpointDB
end

function MPT:GetSelectedCheckpointMapID()
    local checkpointDB = self:GetCheckpointConfigDB()
    return tonumber(checkpointDB.selectedMapID)
end

function MPT:SetSelectedCheckpointMapID(mapID)
    local checkpointDB = self:GetCheckpointConfigDB()
    checkpointDB.selectedMapID = tonumber(mapID) or checkpointDB.selectedMapID
end

function MPT:GetDungeonCheckpointConfig(mapID, createIfMissing)
    local checkpointDB = self:GetCheckpointConfigDB()
    mapID = tonumber(mapID) or self:GetSelectedCheckpointMapID()
    if not mapID or mapID <= 0 then
        return nil
    end

    local mapKey = tostring(mapID)
    local dungeonConfig = checkpointDB.dungeons[mapKey]
    if type(dungeonConfig) ~= "table" then
        local mapSearchKey = NormalizeDungeonSearchKey(GetMythicPlusMapName(mapID))
        for legacyKey, legacyConfig in pairs(checkpointDB.dungeons) do
            if legacyKey ~= mapKey and type(legacyConfig) == "table" then
                local legacyNumeric = tonumber(legacyKey)
                if legacyNumeric == mapID or NormalizeDungeonSearchKey(legacyKey) == mapSearchKey then
                    dungeonConfig = legacyConfig
                    checkpointDB.dungeons[mapKey] = legacyConfig
                    checkpointDB.dungeons[legacyKey] = nil
                    break
                end
            end
        end
    end

    if type(dungeonConfig) ~= "table" and createIfMissing ~= false then
        dungeonConfig = {
            checkpoints = self:GetDefaultDungeonCheckpoints(mapID),
        }
        checkpointDB.dungeons[mapKey] = dungeonConfig
    end

    if type(dungeonConfig) ~= "table" then
        return nil
    end

    dungeonConfig.checkpoints = self:NormalizeDungeonCheckpointList(dungeonConfig.checkpoints, mapID)
    return dungeonConfig
end

function MPT:GetConfiguredDungeonCheckpoints(mapID)
    local dungeonConfig = self:GetDungeonCheckpointConfig(mapID, true)
    if not dungeonConfig then
        return {}
    end

    local checkpoints = {}
    for _, checkpoint in ipairs(dungeonConfig.checkpoints or {}) do
        checkpoints[#checkpoints + 1] = CloneCheckpointEntry(checkpoint)
    end
    return checkpoints
end

function MPT:SetDungeonCheckpointConfig(mapID, checkpoints)
    local dungeonConfig = self:GetDungeonCheckpointConfig(mapID, true)
    if not dungeonConfig then
        return
    end

    dungeonConfig.checkpoints = self:NormalizeDungeonCheckpointList(checkpoints, mapID)
end

function MPT:ResetDungeonCheckpoints(mapID)
    mapID = tonumber(mapID) or self:GetSelectedCheckpointMapID()
    if not mapID then
        return
    end

    local checkpointDB = self:GetCheckpointConfigDB()
    checkpointDB.dungeons[tostring(mapID)] = {
        checkpoints = self:GetDefaultDungeonCheckpoints(mapID),
    }
end

function MPT:AddCustomDungeonCheckpoint(mapID)
    mapID = tonumber(mapID) or self:GetSelectedCheckpointMapID()
    local checkpoints = self:GetConfiguredDungeonCheckpoints(mapID)
    local customCount = 0
    for _, checkpoint in ipairs(checkpoints) do
        if checkpoint.kind == "custom" then
            customCount = customCount + 1
        end
    end

    checkpoints[#checkpoints + 1] = {
        id = NormalizeCheckpointID(nil, "custom", customCount + 1),
        kind = "custom",
        name = format("Custom Checkpoint %d", customCount + 1),
        percent = 50,
        notifyEnabled = true,
    }

    self:SetDungeonCheckpointConfig(mapID, checkpoints)
end

function MPT:UpdateDungeonCheckpoint(mapID, checkpointID, updates)
    mapID = tonumber(mapID) or self:GetSelectedCheckpointMapID()
    local checkpoints = self:GetConfiguredDungeonCheckpoints(mapID)
    for _, checkpoint in ipairs(checkpoints) do
        if checkpoint.id == checkpointID then
            if updates.name ~= nil then
                checkpoint.name = NormalizeCheckpointName(updates.name, checkpoint.name)
            end
            if updates.percent ~= nil then
                local fallbackPercent = checkpoint.kind == "boss" and 100 or checkpoint.percent
                checkpoint.percent = ClampNumber(updates.percent, 0, 100, fallbackPercent)
            end
            if updates.notifyEnabled ~= nil then
                checkpoint.notifyEnabled = updates.notifyEnabled == true
            end
            break
        end
    end

    local bossCount = 0
    for _, checkpoint in ipairs(checkpoints) do
        if checkpoint.kind == "boss" then
            bossCount = bossCount + 1
        end
    end
    for _, checkpoint in ipairs(checkpoints) do
        if checkpoint.kind == "boss" and tonumber(checkpoint.bossIndex) == bossCount then
            checkpoint.percent = 100
        end
    end

    self:SetDungeonCheckpointConfig(mapID, checkpoints)
end

function MPT:RemoveDungeonCheckpoint(mapID, checkpointID)
    mapID = tonumber(mapID) or self:GetSelectedCheckpointMapID()
    local checkpoints = self:GetConfiguredDungeonCheckpoints(mapID)
    for index = #checkpoints, 1, -1 do
        if checkpoints[index].id == checkpointID and checkpoints[index].kind == "custom" then
            table.remove(checkpoints, index)
            break
        end
    end

    self:SetDungeonCheckpointConfig(mapID, checkpoints)
end

local function GetMythicPlusTimeLimits(timeLimit, hasChallengersPeril)
    local fullLimit = max(0, tonumber(timeLimit) or 0)
    if fullLimit <= 0 then
        return 0, 0, 0
    end

    if hasChallengersPeril then
        local adjustedBase = max(0, fullLimit - 90)
        return fullLimit, (adjustedBase * 0.8) + 90, (adjustedBase * 0.6) + 90
    end

    return fullLimit, fullLimit * 0.8, fullLimit * 0.6
end

local function GetMythicPlusTimerBarFractions(timeLimit, hasChallengersPeril)
    local plusOneLimit, plusTwoLimit, plusThreeLimit = GetMythicPlusTimeLimits(timeLimit, hasChallengersPeril)
    if plusOneLimit <= 0 then
        return 0.2, 0.2, 0.6
    end

    local plusOneFraction = ClampNumber((plusOneLimit - plusTwoLimit) / plusOneLimit, 0, 1, 0.2)
    local plusTwoFraction = ClampNumber((plusTwoLimit - plusThreeLimit) / plusOneLimit, 0, 1, 0.2)
    local plusThreeFraction = ClampNumber(plusThreeLimit / plusOneLimit, 0, 1, 0.6)
    return plusOneFraction, plusTwoFraction, plusThreeFraction
end

local function ExtractWeightedProgressCount(criteriaInfo)
    if type(criteriaInfo) ~= "table" then
        return 0
    end

    -- WarpDeplete explicitly uses quantityString rather than quantity for isWeightedProgress
    -- criteria, noting that "the current count contains a percentage sign even though it's
    -- an absolute value" (e.g. "94%" = 94 force points).  In WoW Midnight the quantity
    -- field can be 0 or stale while quantityString is always current, so we prefer it.
    local quantityString = criteriaInfo.quantityString
    if type(quantityString) == "string" and quantityString ~= "" then
        local n = tonumber(quantityString:match("%d+"))
        if n then return n end
    end

    -- Fallback: numeric quantity field (may be 0 or nil on some builds).
    if type(criteriaInfo.quantity) == "number" then
        return criteriaInfo.quantity
    end

    return 0
end

local function GetOwnedKeystoneMapID()
    if C_MythicPlus and type(C_MythicPlus.GetOwnedKeystoneMapID) == "function" then
        local mapID = C_MythicPlus.GetOwnedKeystoneMapID()
        if type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end

    if C_MythicPlus and type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) == "function" then
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        if type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end

    return nil
end

local function GetCurrentInstanceID()
    if type(GetInstanceInfo) ~= "function" then
        return nil
    end

    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    return type(instanceID) == "number" and instanceID > 0 and instanceID or nil
end

local function IsLeaderOrAssistant()
    if type(IsInGroup) ~= "function" then
        return true
    end

    if not IsInGroup() then
        return true
    end

    if type(_G.UnitIsGroupLeader) == "function" and _G.UnitIsGroupLeader("player") then
        return true
    end

    return type(_G.UnitIsGroupAssistant) == "function" and _G.UnitIsGroupAssistant("player") or false
end

local function GetDynamicSpellCooldown(spellID, fallbackCooldown)
    local cooldownSeconds = nil

    if type(GetSpellBaseCooldown) == "function" then
        local baseCooldown = GetSpellBaseCooldown(spellID)
        if type(baseCooldown) == "number" and baseCooldown > 0 then
            cooldownSeconds = baseCooldown / 1000
        end
    end

    return cooldownSeconds or fallbackCooldown or 0
end

local function GetInterruptCooldownForSpell(spellID, fallbackCooldown)
    return GetDynamicSpellCooldown(spellID, INTERRUPT_SPELL_COOLDOWNS[spellID] or fallbackCooldown or 0)
end

local function PlayerKnowsSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    if C_Spell and type(C_Spell.IsSpellKnown) == "function" and C_Spell.IsSpellKnown(spellID) then
        return true
    end

    if _G.C_SpellBook and type(_G.C_SpellBook.IsSpellInSpellBook) == "function" and _G.C_SpellBook.IsSpellInSpellBook(spellID) then
        return true
    end

    return false
end

function MPT:GetDB()
    local options = GetOptions()
    return options and options:GetDB() or {}
end

function MPT:IsFeatureEnabled(featureKey)
    local db = self:GetDB()
    if featureKey == "deathNotifications" then
        return db.deathNotificationEnabled ~= false
    end
    if featureKey == "interruptTracker" then
        return db.interruptTrackerEnabled ~= false
    end
    if featureKey == "mythicPlusTimer" then
        if db.mythicPlusTimerEnabled == nil then
            return true
        end

        return db.mythicPlusTimerEnabled == true
    end
    return false
end

function MPT:EnsureRuntime()
    self.deathWindow = self.deathWindow or {}
    self.interruptMembers = self.interruptMembers or {}
    self.interruptOrder = self.interruptOrder or {}
    self.inspectQueue = self.inspectQueue or {}
    self.pendingHostedEvents = self.pendingHostedEvents or {}
    self.lastHostedEventAt = self.lastHostedEventAt or {}
    self.partyDeathState = self.partyDeathState or {}
    self.lastRosterRefreshAt = self.lastRosterRefreshAt or 0
    self.preview = self.preview or {
        interrupts = false,
        interruptsStartedAt = 0,
        mythicPlusTimer = false,
        mythicPlusTimerStartedAt = 0,
    }
    self.mythicPlusTimerState = self.mythicPlusTimerState or {
        mapID = nil,
        level = nil,
        bossCheckpoints = {},
        forcesCompletionTime = nil,
    }
    self.lastSeenDeaths = self.lastSeenDeaths or {}
    self.lastReadySoundAt = self.lastReadySoundAt or {}
    self.recentPartyCasts = self.recentPartyCasts or {}
    self.lastObservedInterruptAt = self.lastObservedInterruptAt or {}
    self.directEventMode = true

    -- Per-tick scratch tables: allocated once, reused every tick to eliminate
    -- constant GC churn on the hot rendering path.
    self.trackerAppearanceDirty = true
    if not self.trackerAppearanceCache then
        self.trackerAppearanceCache = {
            statusTextColor        = { 0, 0, 0, 1 },
            readyTextColor         = { 0, 0, 0, 1 },
            interruptBarColor      = { 0, 0, 0, 1 },
            interruptReadyBarColor = { 0, 0, 0, 1 },
            interruptFontColor     = { 0, 0, 0, 1 },
            timerFontColor         = { 0, 0, 0, 1 },
            timerMutedTextColor    = { 0, 0, 0, 1 },
            timerBarColor          = { 0, 0, 0, 1 },
        }
    end
    self.trackerMetricsCache     = self.trackerMetricsCache or {}
    self.interruptDisplayScratch = self.interruptDisplayScratch or {}
    self._barColorScratch        = self._barColorScratch or { 0, 0, 0, 0.95 }
    self._readyBarColorScratch   = self._readyBarColorScratch or { 0, 0, 0, 0.95 }
    self._fontColorScratch       = self._fontColorScratch or { 0, 0, 0, 1 }
end

function MPT:OnEnable()
    self:EnsureRuntime()
    self:EnsureFrames()
    self:EnsureEventFrames()
    self:RegisterDirectEvents()
    self:EnsureHooks()
    self:ApplyFrameLockStates()
    self:RefreshModuleState()
    self:LogStartupSnapshot("OnEnable")

    if not self.updateTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
        self.updateTicker = C_Timer.NewTicker(0.1, function()
            self:OnTick()
        end)
    end
end

function MPT:OnDisable()
    self:UnregisterDirectEvents()

    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end

    if self.interruptFrame then
        self.interruptFrame:Hide()
    end

    if self.mythicPlusTimerFrame then
        self.mythicPlusTimerFrame:Hide()
    end
end

function MPT:RefreshModuleState()
    if not IsModuleConfiguredEnabled() then
        if self.interruptFrame then
            self.interruptFrame:Hide()
        end
        if self.mythicPlusTimerFrame then
            self.mythicPlusTimerFrame:Hide()
        end
        return
    end

    self:RefreshAllState()
end

local function SafeDebugString(value)
    if value == nil then
        return "nil"
    end

    if HasSecretValues(value) then
        return "<secret>"
    end

    local valueType = type(value)
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    if valueType == "string" then
        local ok, sanitized = pcall(function()
            return value:gsub("%%", "%%%%")
        end)
        if ok and type(sanitized) == "string" then
            return sanitized
        end
        return "<string>"
    end

    local ok, result = pcall(tostring, value)
    if ok and type(result) == "string" then
        local escapedOk, escaped = pcall(function()
            return result:gsub("%%", "%%%%")
        end)
        if escapedOk and type(escaped) == "string" then
            return escaped
        end
    end

    return "<" .. valueType .. ">"
end

function MPT:IsDebugEnabled()
    local options = GetOptions()
    return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
end

function MPT:LogDebug(message, shouldShow)
    if not DebugConsole or type(DebugConsole.Log) ~= "function" then
        return false
    end

    return DebugConsole:Log(DEBUG_SOURCE_KEY, SafeDebugString(message), shouldShow)
end

function MPT:LogDebugf(shouldShow, messageFormat, ...)
    if not DebugConsole or type(DebugConsole.Logf) ~= "function" then
        return false
    end

    return DebugConsole:Logf(DEBUG_SOURCE_KEY, shouldShow, messageFormat, ...)
end

function MPT:BuildDebugReport()
    self:EnsureRuntime()

    local db = self:GetDB()
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    local lines = {
        "TwichUI Mythic+ Tools Debug",
        format("Timestamp: %s",
            date and type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or format("%.3f", GetTime())),
        "",
        "Runtime",
        format("enabled=%s debugCapture=%s directEvents=%s previewInterrupts=%s",
            tostring(db.enabled == true),
            tostring(self:IsDebugEnabled()),
            tostring(self.directEventsRegistered == true),
            tostring(self.preview and self.preview.interrupts == true)),
        format("deathNotifications=%s interruptTracker=%s started=%s updateTicker=%s",
            tostring(self:IsFeatureEnabled("deathNotifications")),
            tostring(self:IsFeatureEnabled("interruptTracker")),
            tostring(self.started == true),
            tostring(self.updateTicker ~= nil)),
        format("instance=%s type=%s diff=%s instanceID=%s challengeActive=%s",
            SafeDebugString(instanceName),
            SafeDebugString(instanceType),
            SafeDebugString(difficultyID),
            SafeDebugString(instanceID),
            tostring(IsChallengeModeActive())),
        format("interruptMembers=%d queue=%d pendingEvents=%d deathCount=%d",
            CountTableEntries(self.interruptMembers),
            #(self.inspectQueue or {}),
            #(self.pendingHostedEvents or {}),
            tonumber(self.deathCount) or 0),
        "",
        "Recent Log",
    }

    local debugLines = DebugConsole and DebugConsole.GetLines and DebugConsole:GetLines(DEBUG_SOURCE_KEY) or nil
    if debugLines and #debugLines > 0 then
        for _, line in ipairs(debugLines) do
            lines[#lines + 1] = line
        end
    else
        lines[#lines + 1] = "<no log entries yet>"
    end

    return table.concat(lines, "\n")
end

function MPT:LogStartupSnapshot(reason)
    local db = self:GetDB()
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    self:LogDebugf(false,
        "startup=%s enabled=%s challengeActive=%s instance=%s type=%s diff=%s instanceID=%s slotted=%s ownedMap=%s",
        tostring(reason or "unknown"),
        tostring(db.enabled == true),
        tostring(IsChallengeModeActive()),
        tostring(instanceName or "nil"),
        tostring(instanceType or "nil"),
        tostring(difficultyID or "nil"),
        tostring(instanceID or "nil"),
        tostring(HasSlottedKeystone()),
        tostring(GetOwnedKeystoneMapID())
    )
    self:LogDebug("event host=hook/piggyback mode; runtime is plain Lua inside TwichUI", false)
    self:LogDebugf(false,
        "hooks active: DirectEvents=%s TimerTracker=%s ToastsPEW=%s ToastsRoster=%s ElvUIMiscCL=%s ElvUINameplatesCL=%s ElvUINPPostInterrupted=%s",
        tostring(self.directEventsRegistered == true),
        tostring(self.hookedTimerTracker == true),
        tostring(self.hookedToastsPlayerEnteringWorld == true),
        tostring(self.hookedToastsGroupRosterUpdate == true),
        tostring(self.hookedElvUIMiscCombatLog == true),
        tostring(self.hookedElvUINameplatesCombatLog == true),
        tostring(self.hookedElvUINameplatesPostCastInterrupted == true)
    )
end

function MPT:HandleHostedEvent(event, ...)
    self:EnsureRuntime()

    if self.started ~= true then
        local entry = { event, ... }
        entry.n = select("#", event, ...)
        self.pendingHostedEvents[#self.pendingHostedEvents + 1] = entry
        while #self.pendingHostedEvents > 64 do
            table.remove(self.pendingHostedEvents, 1)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        self:LogDebugf(false, "forwarded event=%s", tostring(event))
    end

    local handler = self[event]
    if type(handler) == "function" then
        handler(self, event, ...)
    end
end

function MPT:IsCoreReady()
    return T ~= nil
        and T.db ~= nil
        and T.db.profile ~= nil
        and ConfigurationModule ~= nil
        and type(ConfigurationModule.GetProfileDB) == "function"
end

function MPT:FlushPendingHostedEvents()
    if self.started ~= true or not self.pendingHostedEvents then
        return
    end

    local queuedEvents = self.pendingHostedEvents
    self.pendingHostedEvents = {}

    for _, entry in ipairs(queuedEvents) do
        local event = entry[1]
        local handler = self[event]

        if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
            self:LogDebugf(false, "forwarded event=%s", tostring(event))
        end

        if type(handler) == "function" then
            handler(self, unpack(entry, 1, entry.n))
        end
    end
end

function MPT:EnsureHooks()
    if self.hooksInitialized == true then
        return
    end

    local toastsModule = T.GetModule and T:GetModule("ToastsModule", true) or nil
    if not self.directEventMode and type(hooksecurefunc) == "function" and toastsModule then
        if type(toastsModule.HandlePlayerEnteringWorld) == "function" then
            hooksecurefunc(toastsModule, "HandlePlayerEnteringWorld", function()
                self:HandleHostedEvent("PLAYER_ENTERING_WORLD")
            end)
            self.hookedToastsPlayerEnteringWorld = true
        end

        if type(toastsModule.HandleGroupRosterUpdate) == "function" then
            hooksecurefunc(toastsModule, "HandleGroupRosterUpdate", function()
                self:HandleHostedEvent("GROUP_ROSTER_UPDATE")
            end)
            self.hookedToastsGroupRosterUpdate = true
        end
    end

    local elvuiEngine = _G.ElvUI and _G.ElvUI[1] or nil
    if type(hooksecurefunc) == "function" and elvuiEngine and type(elvuiEngine.GetModule) == "function" then
        local miscModule = elvuiEngine:GetModule("Misc", true)
        if miscModule and type(miscModule.COMBAT_LOG_EVENT_UNFILTERED) == "function" then
            hooksecurefunc(miscModule, "COMBAT_LOG_EVENT_UNFILTERED", function()
                self:HandleHostedEvent("COMBAT_LOG_EVENT_UNFILTERED")
            end)
            self.hookedElvUIMiscCombatLog = true
        end

        local nameplatesModule = elvuiEngine:GetModule("NamePlates", true)
        if not self.directEventMode and nameplatesModule and type(nameplatesModule.COMBAT_LOG_EVENT_UNFILTERED) == "function" then
            hooksecurefunc(nameplatesModule, "COMBAT_LOG_EVENT_UNFILTERED", function()
                self:HandleHostedEvent("COMBAT_LOG_EVENT_UNFILTERED")
            end)
            self.hookedElvUINameplatesCombatLog = true
        end

        if nameplatesModule and type(nameplatesModule.Castbar_PostCastInterrupted) == "function" then
            hooksecurefunc(nameplatesModule, "Castbar_PostCastInterrupted",
                function(castbar, unit, interruptedSpellID, interruptedByGUID)
                    self:HandleObservedInterruptFromCastbar("ElvUINameplates", castbar, unit, interruptedSpellID,
                        interruptedByGUID)
                end)
            self.hookedElvUINameplatesPostCastInterrupted = true
        end

        if nameplatesModule and type(nameplatesModule.StylePlate) == "function" then
            hooksecurefunc(nameplatesModule, "StylePlate", function(_, nameplate)
                self:HookNameplateCastbarInstance(nameplate and nameplate.Castbar)
            end)
            self.hookedElvUINameplatesStylePlate = true
        end

        self:HookExistingNameplateCastbars(nameplatesModule)
    end

    self.hooksInitialized = true
end

function MPT:EnsureEventFrames()
    if not self.runtimeEventFrame then
        -- Only created here on the very first call in non-do-block paths.
        self.runtimeEventFrame = CreateFrame("Frame")
        self.runtimeEventFrame:SetScript("OnEvent", function(_, event, ...)
            MPT:HandleHostedEvent(event, ...)
        end)
    end
    -- The pre-init do block already set the correct OnEvent script.
    -- Do NOT re-call SetScript here: on the C_Timer re-enable path that
    -- would raise ADDON_ACTION_FORBIDDEN for Frame:SetScript().

    -- Skip party/mob frame creation if already done.
    if self.partySpellcastFallbackFrame then
        return
    end

    self.partySpellcastFallbackFrame = CreateFrame("Frame")
    self.partySpellcastFallbackFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if type(unit) ~= "string" or not unit:match("^party%d$") then
            return
        end
        if self.partyWatcherUnitActive and self.partyWatcherUnitActive[unit] then
            return
        end
        local source = event == "UNIT_SPELLCAST_SENT" and "sent" or "succeeded"
        self:HandleObservedPartyCastEvent(unit, unit, source, ...)
    end)

    self.partySpellcastFrames = self.partySpellcastFrames or {}
    self.partyPetSpellcastFrames = self.partyPetSpellcastFrames or {}
    for index = 1, 4 do
        self.partySpellcastFrames[index] = self.partySpellcastFrames[index] or CreateFrame("Frame")
        self.partyPetSpellcastFrames[index] = self.partyPetSpellcastFrames[index] or CreateFrame("Frame")
    end

    self.mobInterruptFrame = self.mobInterruptFrame or CreateFrame("Frame")
    self.mobInterruptFrame:SetScript("OnEvent", function(_, _, unit)
        self:HandleMobInterrupted(unit)
    end)

    self.nameplateWatcherFrame = self.nameplateWatcherFrame or CreateFrame("Frame")
    self.nameplateWatcherFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            self:RegisterNameplateInterruptWatcher(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            self:UnregisterNameplateInterruptWatcher(unit)
        end
    end)
    self.nameplateInterruptFrames = self.nameplateInterruptFrames or {}
end

function MPT:RegisterDirectEvents()
    if not self.runtimeEventFrame then
        self:EnsureEventFrames()
    end

    -- Re-register main events.  On first call they were already registered at
    -- module-load time (untainted), so these are idempotent no-ops that produce
    -- no duplicates.  On re-enable (after UnregisterDirectEvents cleared them)
    -- we are in a clean UI-interaction context so COMBAT_LOG_EVENT_UNFILTERED
    -- is also safe to register here.
    self.runtimeEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.runtimeEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.runtimeEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.runtimeEventFrame:RegisterEvent("INSPECT_READY")
    self.runtimeEventFrame:RegisterEvent("START_PLAYER_COUNTDOWN")
    self.runtimeEventFrame:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
    -- COMBAT_LOG_EVENT_UNFILTERED is restricted in TWW; sourced via ElvUI hook.
    self.runtimeEventFrame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
    -- Enemy forces / objectives: fire immediate re-render whenever Blizzard's
    -- scenario criteria update, rather than waiting for the next 0.1s poll.
    self.runtimeEventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    self.runtimeEventFrame:RegisterEvent("SCENARIO_POI_UPDATE")
    self.runtimeEventFrame:RegisterEvent("CHALLENGE_MODE_START")
    self.runtimeEventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

    self:RegisterPartyWatchers()
    self:RegisterMobInterruptWatchers()
    self.directEventsRegistered = true
end

function MPT:UnregisterDirectEvents()
    if self.runtimeEventFrame then
        self.runtimeEventFrame:UnregisterAllEvents()
    end
    if self.partySpellcastFallbackFrame then
        self.partySpellcastFallbackFrame:UnregisterAllEvents()
    end
    for _, frame in ipairs(self.partySpellcastFrames or {}) do
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
    end
    for _, frame in ipairs(self.partyPetSpellcastFrames or {}) do
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
    end
    if self.mobInterruptFrame then
        self.mobInterruptFrame:UnregisterAllEvents()
    end
    if self.nameplateWatcherFrame then
        self.nameplateWatcherFrame:UnregisterAllEvents()
    end
    for unit, frame in pairs(self.nameplateInterruptFrames or {}) do
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        self.nameplateInterruptFrames[unit] = nil
    end
    self.directEventsRegistered = false
end

function MPT:RegisterPartyWatchers()
    self.partyWatcherUnitActive = {}
    self.partySpellcastFallbackFrame:UnregisterAllEvents()
    self.partySpellcastFallbackFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
    self.partySpellcastFallbackFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    for index = 1, 4 do
        local ownerUnit = "party" .. index
        local petUnit = "partypet" .. index
        local ownerFrame = self.partySpellcastFrames[index]
        local petFrame = self.partyPetSpellcastFrames[index]

        ownerFrame:UnregisterAllEvents()
        ownerFrame:SetScript("OnEvent", nil)
        petFrame:UnregisterAllEvents()
        petFrame:SetScript("OnEvent", nil)

        if UnitExists(ownerUnit) then
            self.partyWatcherUnitActive[ownerUnit] = true
            ownerFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", ownerUnit)
            ownerFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", ownerUnit)
            ownerFrame:SetScript("OnEvent", function(_, event, unit, ...)
                local source = event == "UNIT_SPELLCAST_SENT" and "sent" or "succeeded"
                self:HandleObservedPartyCastEvent(ownerUnit, unit or ownerUnit, source, ...)
            end)
        end

        if UnitExists(petUnit) then
            petFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", petUnit)
            petFrame:SetScript("OnEvent", function(_, _, unit, ...)
                self:HandleObservedPartyCastEvent(ownerUnit, unit or petUnit, "succeeded", ...)
            end)
        end
    end
end

function MPT:RegisterNameplateInterruptWatcher(unit)
    if not (unit and unit:match("^nameplate")) then
        return
    end

    local frame = self.nameplateInterruptFrames[unit]
    if not frame then
        frame = CreateFrame("Frame")
        self.nameplateInterruptFrames[unit] = frame
    end
    frame:UnregisterAllEvents()
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    frame:SetScript("OnEvent", function(_, _, interruptedUnit)
        self:HandleMobInterrupted(interruptedUnit or unit)
    end)
end

function MPT:UnregisterNameplateInterruptWatcher(unit)
    local frame = unit and self.nameplateInterruptFrames and self.nameplateInterruptFrames[unit] or nil
    if frame then
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
    end
end

function MPT:RegisterMobInterruptWatchers()
    self.mobInterruptFrame:UnregisterAllEvents()
    self.mobInterruptFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "mouseover", "focus", "boss1",
        "boss2", "boss3", "boss4", "boss5")

    self.nameplateWatcherFrame:UnregisterAllEvents()
    self.nameplateWatcherFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.nameplateWatcherFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        for _, plateFrame in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local unit = plateFrame and plateFrame.namePlateUnitToken or nil
            if unit then
                self:RegisterNameplateInterruptWatcher(unit)
            end
        end
    end
end

function MPT:EnsureDynamicHooks()
    if self.keystoneFrameHooked == true then
        return
    end

    local keystoneFrame = _G.ChallengesKeystoneFrame
    if keystoneFrame and type(keystoneFrame.HookScript) == "function" then
        keystoneFrame:HookScript("OnShow", function()
            self:LogDebug("hooked event=ChallengesKeystoneFrame.OnShow", false)
            self:TryAutoSlotKeystone()
            self:RefreshKeystoneHelperPanel()
        end)
        keystoneFrame:HookScript("OnHide", function()
            if self.keystoneHelperPanel then
                self.keystoneHelperPanel:Hide()
            end
        end)
        self.keystoneFrameHooked = true
    end
end

function MPT:EnsureFrames()
    self:EnsureInterruptFrame()
    self:EnsureMythicPlusTimerFrame()
end

-- ─── Keystone Helper Panel ───────────────────────────────────────────────────
-- A compact floating panel that attaches to the right of the Blizzard keystone
-- frame whenever a keystone is slotted. Provides a ready-check button, a pull-
-- timer button, and a quick toggle for the auto-start-on-pull-timer setting.

local function GetThemeAccentColor()
    local theme = T:GetModule("Theme", true)
    if theme and theme.GetColor then
        local c = theme:GetColor("accentColor")
        if c then return c[1] or 0.96, c[2] or 0.76, c[3] or 0.24 end
    end
    return 0.96, 0.76, 0.24
end

local function GetGlobalFontPath()
    local theme = T:GetModule("Theme", true)
    local fontKey = theme and theme.Get and theme:Get("globalFont")
    return GetTrackerFontPath(fontKey) -- reuse existing LSM fetch helper
end

function MPT:EnsureKeystoneHelperPanel()
    if self.keystoneHelperPanel then
        return self.keystoneHelperPanel
    end

    -- ── Layout constants ──────────────────────────────────────────────────
    local PAD                                         = 12
    local W                                           = 264
    -- INFO_H must comfortably fit 4–5 wrapped lines of helper text.
    local INFO_H                                      = 68
    local BTN_H                                       = 26
    local ROW_H                                       = 20
    local BTN_W                                       = math.floor((W - 2 * PAD - 6) / 2)

    -- Y offsets from TOPLEFT (negative = downward)
    local titleY                                      = -PAD                  -- -12
    local divY                                        = titleY - 16 - 6       -- -34
    local infoY                                       = divY - 1 - 8          -- -43
    local btnY                                        = infoY - INFO_H - 8    -- -119
    local togY                                        = btnY - BTN_H - 8      -- -153
    local TOTAL_H                                     = -(togY - ROW_H - PAD) --  185

    local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()

    -- ── Frame ─────────────────────────────────────────────────────────────
    local frame                                       = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(W, TOTAL_H)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    CreateBackdrop(frame)

    -- Accent stripe (color applied in Refresh so it follows theme changes)
    local accentStripe = frame:CreateTexture(nil, "ARTWORK")
    accentStripe:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    accentStripe:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    accentStripe:SetHeight(2)
    frame.AccentStripe = accentStripe

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, titleY)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, titleY)
    title:SetJustifyH("LEFT")
    title:SetText("DUNGEON SETUP")
    frame.TitleText = title

    -- Thin separator under title
    local div = frame:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, divY)
    div:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, divY)
    div:SetHeight(1)
    div:SetColorTexture(borderR, borderG, borderB, 0.30)

    -- Info / status text — no SetHeight so text never clips with "..."
    local info = frame:CreateFontString(nil, "OVERLAY")
    info:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, infoY)
    info:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, infoY)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetWordWrap(true)
    info:SetSpacing(1)
    info:SetTextColor(0.75, 0.75, 0.80)
    frame.InfoText = info

    -- ── Action buttons ────────────────────────────────────────────────────
    local btnReady = CreateFrame("Button", nil, frame)
    btnReady:SetSize(BTN_W, BTN_H)
    btnReady:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, btnY)
    local fsReady = btnReady:CreateFontString(nil, "OVERLAY")
    btnReady:SetFontString(fsReady)
    fsReady:SetText("Ready Check")
    frame.ReadyBtn = btnReady
    frame.FSReady  = fsReady

    local btnPull  = CreateFrame("Button", nil, frame)
    btnPull:SetSize(BTN_W, BTN_H)
    btnPull:SetPoint("TOPLEFT", btnReady, "TOPRIGHT", 6, 0)
    local fsPull = btnPull:CreateFontString(nil, "OVERLAY")
    btnPull:SetFontString(fsPull)
    fsPull:SetText("Pull Timer (5s)")
    frame.PullBtn = btnPull
    frame.FSPull  = fsPull

    local UI      = T.Tools and T.Tools.UI
    if UI and UI.SkinTwichButton then
        UI.SkinTwichButton(btnReady)
        UI.SkinTwichButton(btnPull)
    end

    -- ── Auto-start toggle row ─────────────────────────────────────────────
    local toggleRow = CreateFrame("Frame", nil, frame)
    toggleRow:SetHeight(ROW_H)
    toggleRow:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, togY)
    toggleRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, togY)
    frame.ToggleRow = toggleRow

    -- Checkbox border + fill
    local checkBg = CreateFrame("Frame", nil, toggleRow, "BackdropTemplate")
    checkBg:SetSize(13, 13)
    checkBg:SetPoint("LEFT", toggleRow, "LEFT", 0, 0)
    checkBg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    checkBg:SetBackdropColor(bgR, bgG, bgB, 0.95)
    checkBg:SetBackdropBorderColor(borderR, borderG, borderB, 0.70)
    frame.CheckBg = checkBg

    local checkFill = checkBg:CreateTexture(nil, "ARTWORK")
    checkFill:SetPoint("TOPLEFT", checkBg, "TOPLEFT", 1, -1)
    checkFill:SetPoint("BOTTOMRIGHT", checkBg, "BOTTOMRIGHT", -1, 1)
    checkFill:SetColorTexture(0, 0, 0, 0)
    frame.CheckFill = checkFill

    -- Label
    local togLabel = toggleRow:CreateFontString(nil, "OVERLAY")
    togLabel:SetPoint("LEFT", checkBg, "RIGHT", 6, 0)
    togLabel:SetPoint("RIGHT", toggleRow, "RIGHT", 0, 0)
    togLabel:SetJustifyH("LEFT")
    togLabel:SetText("Auto-start when timer ends")
    togLabel:SetTextColor(0.75, 0.75, 0.80)
    frame.ToggleLabel = togLabel

    -- Invisible button covering the toggle row for click handling
    local togBtn = CreateFrame("Button", nil, frame)
    togBtn:SetPoint("TOPLEFT", toggleRow, "TOPLEFT", -2, 2)
    togBtn:SetPoint("BOTTOMRIGHT", toggleRow, "BOTTOMRIGHT", 2, -2)
    local togHL = togBtn:CreateTexture(nil, "HIGHLIGHT")
    togHL:SetAllPoints(togBtn)
    togHL:SetColorTexture(1, 1, 1, 0.05)
    frame.ToggleBtn = togBtn

    -- ── Anchor to right of keystone receptacle frame ──────────────────────
    local ksFrame = _G.ChallengesKeystoneFrame
    if ksFrame then
        frame:SetPoint("LEFT", ksFrame, "RIGHT", 10, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end

    frame:Hide()
    self.keystoneHelperPanel = frame

    -- ── Button handlers ───────────────────────────────────────────────────
    btnReady:SetScript("OnClick", function()
        if type(_G.DoReadyCheck) == "function" then
            _G.DoReadyCheck()
        end
    end)

    btnPull:SetScript("OnClick", function()
        local cp = _G.C_PartyInfo
        if cp and type(cp.DoCountdown) == "function" then
            cp.DoCountdown(5)
        end
    end)

    togBtn:SetScript("OnClick", function()
        local db = MPT:GetDB()
        db.autoStartDungeon = not (db.autoStartDungeon == true)
        MPT:RefreshKeystoneHelperPanel()
    end)

    return frame
end

function MPT:RefreshKeystoneHelperPanel()
    local ksFrame   = _G.ChallengesKeystoneFrame
    local ksVisible = ksFrame and ksFrame.IsShown and ksFrame:IsShown()
    local hasKey    = HasSlottedKeystone()

    -- Only show when the keystone UI is open and a key is actually slotted.
    if not ksVisible or not hasKey then
        if self.keystoneHelperPanel then
            self.keystoneHelperPanel:Hide()
        end
        return
    end

    local panel = self:EnsureKeystoneHelperPanel()
    if not panel then return end

    local db        = self:GetDB()
    local autoStart = db.autoStartDungeon == true
    local isLeader  = IsLeaderOrAssistant()

    -- ── Apply global font to every text element ───────────────────────────
    local fontPath  = GetGlobalFontPath()
    panel.TitleText:SetFont(fontPath, 10, "")
    panel.InfoText:SetFont(fontPath, 11, "")
    panel.ToggleLabel:SetFont(fontPath, 11, "")
    panel.FSReady:SetFont(fontPath, 11, "")
    panel.FSPull:SetFont(fontPath, 11, "")

    -- ── Apply theme accent ────────────────────────────────────────────────
    local aR, aG, aB = GetThemeAccentColor()
    panel.AccentStripe:SetColorTexture(aR, aG, aB, 0.95)
    panel.TitleText:SetTextColor(aR, aG, aB, 0.90)

    -- ── Info text ─────────────────────────────────────────────────────────
    if autoStart then
        panel.InfoText:SetText(
            "Auto-start is |cff" ..
            format("%02x%02x%02x", aR * 255, aG * 255, aB * 255) ..
            "ON|r. The run will begin automatically when a pull timer ends, " ..
            "if your keystone is slotted and you are leader or assist.")
    else
        panel.InfoText:SetText(
            "Auto-start is |cffaa6666OFF|r. Enable the toggle below to " ..
            "automatically start the run when a pull timer ends.")
    end

    -- ── Checkbox visual ───────────────────────────────────────────────────
    local _, _, _, _, borderR, borderG, borderB = GetBackdropColors()
    if autoStart then
        panel.CheckFill:SetColorTexture(aR, aG, aB, 0.90)
        panel.CheckBg:SetBackdropBorderColor(aR, aG, aB, 0.90)
        panel.ToggleLabel:SetTextColor(1.0, 0.94, 0.82)
    else
        panel.CheckFill:SetColorTexture(0, 0, 0, 0)
        panel.CheckBg:SetBackdropBorderColor(borderR, borderG, borderB, 0.70)
        panel.ToggleLabel:SetTextColor(0.75, 0.75, 0.80)
    end

    -- ── Enable/disable action buttons based on group role ─────────────────
    panel.ReadyBtn:SetEnabled(isLeader)
    panel.PullBtn:SetEnabled(isLeader)

    if not panel:IsShown() then
        panel:Show()
    end
end

function MPT:CreateBaseFrame(width, height, titleText, titleIcon)
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:RegisterForDrag("LeftButton")
    CreateBackdrop(frame)

    local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()

    frame.TitleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(32)
    frame.TitleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 1 },
    })
    frame.TitleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.98)
    frame.TitleBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.35)

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "ARTWORK")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 0, 0)
    frame.TitleAccent:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", 0, 0)
    frame.TitleAccent:SetHeight(2)
    frame.TitleAccent:SetColorTexture(0.96, 0.78, 0.24, 0.95)

    frame.TitleIcon = frame.TitleBar:CreateTexture(nil, "OVERLAY")
    frame.TitleIcon:SetPoint("LEFT", frame.TitleBar, "LEFT", 10, 0)
    frame.TitleIcon:SetSize(16, 16)
    frame.TitleIcon:SetTexture(titleIcon)
    frame.TitleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.TitleIcon, "RIGHT", 8, 0)
    frame.Title:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -32, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText(titleText)
    frame.Title:SetTextColor(1, 0.94, 0.82)

    frame.LockButton = CreateFrame("Button", nil, frame)
    frame.LockButton:SetSize(28, 28)
    frame.LockButton:SetHitRectInsets(-6, -6, -6, -6)
    frame.LockButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -28, -2)
    frame.LockButton:SetFrameStrata(frame:GetFrameStrata())
    frame.LockButton:SetFrameLevel((frame:GetFrameLevel() or 1) + 40)
    frame.LockButton.Highlight = frame.LockButton:CreateTexture(nil, "HIGHLIGHT")
    frame.LockButton.Highlight:SetAllPoints(frame.LockButton)
    frame.LockButton.Highlight:SetColorTexture(1, 1, 1, 0.08)
    frame.LockButton.Icon = frame.LockButton:CreateTexture(nil, "ARTWORK")
    frame.LockButton.Icon:SetPoint("CENTER", frame.LockButton, "CENTER", 0, 0)
    frame.LockButton.Icon:SetSize(32, 32)

    frame.SettingsButton = CreateFrame("Button", nil, frame)
    frame.SettingsButton:SetSize(28, 28)
    frame.SettingsButton:SetHitRectInsets(-6, -6, -6, -6)
    frame.SettingsButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -52, -2)
    frame.SettingsButton:SetFrameStrata(frame:GetFrameStrata())
    frame.SettingsButton:SetFrameLevel((frame:GetFrameLevel() or 1) + 40)
    frame.SettingsButton.Highlight = frame.SettingsButton:CreateTexture(nil, "HIGHLIGHT")
    frame.SettingsButton.Highlight:SetAllPoints(frame.SettingsButton)
    frame.SettingsButton.Highlight:SetColorTexture(1, 1, 1, 0.08)
    frame.SettingsButton.Icon = frame.SettingsButton:CreateTexture(nil, "ARTWORK")
    frame.SettingsButton.Icon:SetPoint("CENTER", frame.SettingsButton, "CENTER", 0, 0)
    frame.SettingsButton.Icon:SetSize(18, 18)
    frame.SettingsButton.Icon:SetTexture(TIMER_SETTINGS_ICON)
    frame.SettingsButton.tooltipTitle = "Open Settings"
    frame.SettingsButton.tooltipLines = {
        "Open the Mythic+ timer configuration page.",
    }
    AttachTooltipHandlers(frame.SettingsButton)

    frame.CloseButton = CreateFrame("Button", nil, frame.TitleBar, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -2, 0)
    SkinCloseButton(frame.CloseButton)
    frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)

    frame.ContentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.ContentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.ContentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, 0.98)
    frame.ContentInset:SetBackdropBorderColor(borderR, borderG, borderB, 0.45)

    frame.ContentScroll = CreateFrame("ScrollFrame", nil, frame.ContentInset)
    frame.ContentScroll:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 3, -3)
    frame.ContentScroll:SetPoint("BOTTOMRIGHT", frame.ContentInset, "BOTTOMRIGHT", -3, 3)
    frame.ContentScroll:EnableMouseWheel(true)

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ContentScroll)
    frame.ScrollChild:SetPoint("TOPLEFT", frame.ContentScroll, "TOPLEFT", 0, 0)
    frame.ScrollChild:SetPoint("TOPRIGHT", frame.ContentScroll, "TOPRIGHT", 0, 0)
    frame.ScrollChild:SetHeight(1)
    frame.ContentScroll:SetScrollChild(frame.ScrollChild)

    frame.EmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("CENTER", frame.ContentInset, "CENTER", 0, 0)
    frame.EmptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.EmptyText:Hide()

    frame.ResizeHandle = CreateFrame("Button", nil, frame)
    frame.ResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    frame.ResizeHandle:SetSize(18, 18)
    frame.ResizeGlyph = frame.ResizeHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.ResizeGlyph:SetPoint("CENTER", frame.ResizeHandle, "CENTER", 0, 0)
    frame.ResizeGlyph:SetText("//")
    frame.ResizeGlyph:SetTextColor(1, 0.88, 0.45)
    frame.ResizeHighlight = frame.ResizeHandle:CreateTexture(nil, "HIGHLIGHT")
    frame.ResizeHighlight:SetAllPoints(frame.ResizeHandle)
    frame.ResizeHighlight:SetColorTexture(1, 1, 1, 0.05)

    return frame
end

function MPT:CreateTrackerBar(parent)
    local barBackdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    barBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    barBackdrop:SetBackdropColor(0.03, 0.03, 0.04, 0.85)
    barBackdrop:SetBackdropBorderColor(0.24, 0.24, 0.29, 0.8)

    local bar = CreateFrame("StatusBar", nil, barBackdrop)
    bar:SetPoint("TOPLEFT", barBackdrop, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", barBackdrop, "BOTTOMRIGHT", -1, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetValue(1)
    local statusBarTexture = bar:GetStatusBarTexture()
    if not statusBarTexture then
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        statusBarTexture = bar:GetStatusBarTexture()
    end
    if statusBarTexture and statusBarTexture.SetHorizTile then
        statusBarTexture:SetHorizTile(false)
    end

    local background = bar:CreateTexture(nil, "BACKGROUND")
    if background then
        background:SetAllPoints(bar)
        background:SetColorTexture(1, 1, 1, 0.08)
    end

    self:EnableTrackerBarSmoothing(bar)

    return barBackdrop, bar
end

function MPT:CreateRowIconButton(parent, kind)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(18, 18)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.08)

    button.Icon = icon
    button.Highlight = highlight

    return button, icon, highlight
end

function MPT:ApplyRowLayout(frame)
    if not frame or not frame.rowOrder then
        return
    end

    local metrics = self:GetTrackerMetrics()
    local rowOffsetY = -2
    local visibleCount = 0
    local rowParent = frame.ScrollChild or frame.ContentInset

    for _, row in ipairs(frame.rowOrder) do
        if row:IsShown() then
            local yOffset = rowOffsetY - (visibleCount * (metrics.rowHeight + metrics.rowGap))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rowParent, "TOPLEFT", 4, yOffset)
            row:SetPoint("TOPRIGHT", rowParent, "TOPRIGHT", -4, yOffset)
            row:SetHeight(metrics.rowHeight)
            visibleCount = visibleCount + 1
        else
            row:ClearAllPoints()
        end

        if row.barBackdrop then
            row.barBackdrop:ClearAllPoints()
            row.barBackdrop:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.barBackdrop:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.barBackdrop:SetPoint("CENTER", row, "CENTER", 0, 0)
            row.barBackdrop:SetHeight(metrics.barHeight)
        end

        if row.iconButton then
            row.iconButton:SetSize(metrics.iconSize, metrics.iconSize)
            row.iconButton:ClearAllPoints()
            row.iconButton:SetPoint("LEFT", row.content, "LEFT", 6, 0)
        end

        if row.label then
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row.iconButton or row.content, row.iconButton and "RIGHT" or "LEFT",
                row.iconButton and 6 or 6, 0)
        end

        if row.name then
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row.iconButton or row.content, row.iconButton and "RIGHT" or "LEFT",
                row.iconButton and 6 or 6, 0)
        end

        if row.value then
            row.value:ClearAllPoints()
            row.value:SetPoint("RIGHT", row.content, "RIGHT", -6, 0)
        end

        if row.timer then
            row.timer:ClearAllPoints()
            row.timer:SetPoint("RIGHT", row.content, "RIGHT", -6, 0)
        end
    end

    if frame.ScrollChild then
        local totalHeight = 0
        if visibleCount > 0 then
            totalHeight = (visibleCount * metrics.rowHeight) + ((visibleCount - 1) * metrics.rowGap) + 4
        end
        frame.ScrollChild:SetHeight(max(1, totalHeight))
    end

    self:UpdateFrameScrollState(frame)

    local masqueGroup = frame.kind and self:GetMasqueGroup(frame.kind) or nil
    if masqueGroup and masqueGroup.ReSkin then
        masqueGroup:ReSkin()
    end
end

function MPT:UpdateFrameScrollState(frame)
    if not (frame and frame.ContentScroll and frame.ScrollChild) then
        return
    end

    local metrics = self:GetTrackerMetrics()
    local viewportHeight = frame.ContentScroll:GetHeight() or 0
    local contentHeight = frame.ScrollChild:GetHeight() or 0
    local maxScroll = max(0, contentHeight - viewportHeight)
    local currentScroll = frame.ContentScroll:GetVerticalScroll() or 0

    frame.ScrollChild:SetWidth(max(1, frame.ContentScroll:GetWidth() or 1))

    if currentScroll > maxScroll then
        frame.ContentScroll:SetVerticalScroll(maxScroll)
    elseif maxScroll <= 0 then
        frame.ContentScroll:SetVerticalScroll(0)
    end

    frame.canScrollVertically = maxScroll > 0
    frame.scrollStep = max(18, metrics.rowHeight + metrics.rowGap)
end

function MPT:HandleFrameMouseWheel(frame, delta)
    if not (frame and frame.ContentScroll and frame.canScrollVertically) then
        return
    end

    local viewportHeight = frame.ContentScroll:GetHeight() or 0
    local contentHeight = frame.ScrollChild and frame.ScrollChild:GetHeight() or 0
    local maxScroll = max(0, contentHeight - viewportHeight)
    local currentScroll = frame.ContentScroll:GetVerticalScroll() or 0
    local step = frame.scrollStep or 24
    local nextScroll = ClampNumber(currentScroll - (delta * step), 0, maxScroll, 0)
    frame.ContentScroll:SetVerticalScroll(nextScroll)
end

function MPT:InitializeFrameControls(kind, frame)
    if not frame or frame.controlsInitialized then
        return
    end

    frame.kind = kind
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    frame.LockButton:SetScript("OnClick", function()
        self:SetFrameLocked(kind, not self:GetFrameLocked(kind))
    end)

    if frame.SettingsButton then
        frame.SettingsButton:SetScript("OnClick", function()
            self:OpenTimerSettings()
        end)
    end

    frame:HookScript("OnEnter", function(widget)
        self:SetFrameHovered(widget, true)
    end)
    frame:HookScript("OnLeave", function(widget)
        self:SetFrameHovered(widget, MouseIsOver(widget))
    end)
    frame:HookScript("OnUpdate", function(widget)
        self:UpdateFrameHoverState(widget)
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(widget, delta)
        self:HandleFrameMouseWheel(widget, delta)
    end)
    if frame.ContentScroll then
        frame.ContentScroll:SetScript("OnMouseWheel", function(_, delta)
            self:HandleFrameMouseWheel(frame, delta)
        end)
    end

    self:MakeFrameResizable(kind, frame)
    self:RefreshFrameControls(kind, frame)
    frame.controlsInitialized = true
end

function MPT:EnsureInterruptFrame()
    if self.interruptFrame then
        return self.interruptFrame
    end

    local frame = self:CreateBaseFrame(350, 250, "Interrupt Tracker", 132337)
    frame:SetPoint("CENTER", UIParent, "CENTER", 260, -40)

    frame.EmptyText:SetText("No supported interrupts are available in this group.")

    local rows = {}
    local rowOrder = {}
    for index = 1, 5 do
        local row = CreateFrame("Frame", nil, frame.ScrollChild)
        row:EnableMouse(true)

        row.barBackdrop, row.bar = self:CreateTrackerBar(row)
        row.barBackdrop:SetAllPoints(row)

        row.content = CreateFrame("Frame", nil, row)
        row.content:SetAllPoints(row)
        row.content:SetFrameLevel((row.barBackdrop:GetFrameLevel() or row:GetFrameLevel()) + 5)

        row.iconButton, row.icon, row.iconHighlight = self:CreateRowIconButton(row.content, "interrupt")

        row.name = row.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("MIDDLE")

        row.timer = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.timer:SetJustifyH("RIGHT")
        row.timer:SetJustifyV("MIDDLE")

        row.detail = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.detail:SetJustifyH("LEFT")
        row.detail:Hide()

        row:SetScript("OnEnter", function(tooltipRow)
            self:ShowInterruptRowTooltip(tooltipRow)
        end)
        row:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        row.iconButton:SetScript("OnEnter", function()
            self:ShowInterruptRowTooltip(row)
        end)
        row.iconButton:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        rows[index] = row
        rowOrder[index] = row
        self:RegisterRowWithMasque("interrupt", row)
    end

    frame.rows = rows
    frame.rowOrder = rowOrder
    frame:SetScript("OnDragStart", function(widget)
        if self:GetFrameLocked("interrupt") then
            return
        end
        widget:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(widget)
        widget:StopMovingOrSizing()
        self:PersistFramePosition("interrupt", widget)
    end)

    self:ApplyFrameSize("interrupt", frame)
    self:ApplyRowLayout(frame)
    self:InitializeFrameControls("interrupt", frame)
    self.interruptFrame = frame
    self:RestoreFramePosition("interrupt", frame, 260, -40)
    return frame
end

function MPT:ResetMythicPlusTimerTracking()
    self.mythicPlusTimerState = self.mythicPlusTimerState or {}
    self.mythicPlusTimerState.mapID = nil
    self.mythicPlusTimerState.level = nil
    self.mythicPlusTimerState.forcesCompletionTime = nil
    self.mythicPlusTimerState.lastNotificationState = nil
    self.mythicPlusTimerState.lastKnownForceCount = nil
    self.mythicPlusTimerState.bossCheckpoints = self.mythicPlusTimerState.bossCheckpoints or {}
    self.mythicPlusTimerState.customCheckpoints = self.mythicPlusTimerState.customCheckpoints or {}

    for key in pairs(self.mythicPlusTimerState.bossCheckpoints) do
        self.mythicPlusTimerState.bossCheckpoints[key] = nil
    end
    for key in pairs(self.mythicPlusTimerState.customCheckpoints) do
        self.mythicPlusTimerState.customCheckpoints[key] = nil
    end
end

function MPT:OpenTimerSettings()
    local ui = ConfigurationModule and ConfigurationModule.StandaloneUI
    if ui and ui.Show then
        ui:Show("Mythic+ Tools")
    end
end

function MPT:GetMythicPlusTimerScale()
    local db = self:GetDB()
    return ClampNumber(db.mythicPlusTimerScale, 0.7, 1.5, 1)
end

local function PlayAnimationGroup(group)
    if not group then
        return
    end

    if group.Stop then
        group:Stop()
    end
    if group.Play then
        group:Play()
    end
end

local function EnsureAlphaPulse(target, key, peakAlpha, fadeInDuration, fadeOutDuration)
    if not target then
        return nil
    end

    if target[key] then
        return target[key]
    end

    local group = target:CreateAnimationGroup()
    local alphaIn = group:CreateAnimation("Alpha")
    alphaIn:SetTarget(target)
    alphaIn:SetFromAlpha(1)
    alphaIn:SetToAlpha(peakAlpha or 0.35)
    alphaIn:SetDuration(fadeInDuration or 0.08)
    alphaIn:SetOrder(1)

    local alphaOut = group:CreateAnimation("Alpha")
    alphaOut:SetTarget(target)
    alphaOut:SetFromAlpha(peakAlpha or 0.35)
    alphaOut:SetToAlpha(1)
    alphaOut:SetDuration(fadeOutDuration or 0.3)
    alphaOut:SetOrder(2)

    target[key] = group
    return group
end

local function EnsureTranslationPulse(target, key, offsetX, offsetY, outDuration, returnDuration)
    if not target then
        return nil
    end

    if target[key] then
        return target[key]
    end

    local group = target:CreateAnimationGroup()
    local moveOut = group:CreateAnimation("Translation")
    moveOut:SetTarget(target)
    moveOut:SetOffset(offsetX or 0, offsetY or 0)
    moveOut:SetDuration(outDuration or 0.12)
    moveOut:SetSmoothing("OUT")
    moveOut:SetOrder(1)

    local moveBack = group:CreateAnimation("Translation")
    moveBack:SetTarget(target)
    moveBack:SetOffset(-(offsetX or 0), -(offsetY or 0))
    moveBack:SetDuration(returnDuration or 0.24)
    moveBack:SetSmoothing("IN")
    moveBack:SetOrder(2)

    target[key] = group
    return group
end

local function EnsureFontColorBloom(target, key, flashColor, holdDuration)
    if not target then
        return nil
    end

    if target[key] then
        return target[key]
    end

    local group = target:CreateAnimationGroup()
    local hold = group:CreateAnimation("Alpha")
    hold:SetTarget(target)
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(holdDuration or 0.24)
    hold:SetOrder(1)

    group:SetScript("OnPlay", function(animationGroup)
        local red, green, blue, alpha = target:GetTextColor()
        animationGroup.restoreColor = { red or 1, green or 1, blue or 1, alpha or 1 }
        target:SetTextColor(flashColor[1] or 1, flashColor[2] or 1, flashColor[3] or 1, flashColor[4] or 1)
    end)

    group:SetScript("OnFinished", function(animationGroup)
        local restore = animationGroup.restoreColor or { 1, 1, 1, 1 }
        target:SetTextColor(restore[1], restore[2], restore[3], restore[4])
    end)

    target[key] = group
    return group
end

function AttachTooltipHandlers(region)
    if not region or region.twichUITooltipBound then
        return
    end

    if region.EnableMouse then
        region:EnableMouse(true)
    end

    if region.SetScript then
        region:SetScript("OnEnter", function(widget)
            if not GameTooltip then
                return
            end

            local provider = widget.tooltipProvider
            local title, lines
            if type(provider) == "function" then
                title, lines = provider(widget)
            else
                title = widget.tooltipTitle
                lines = widget.tooltipLines
            end

            if type(title) ~= "string" or title == "" then
                return
            end

            GameTooltip:SetOwner(widget, "ANCHOR_CURSOR")
            GameTooltip:AddLine(title, 1, 1, 1)
            if type(lines) == "table" then
                for _, line in ipairs(lines) do
                    if type(line) == "string" and line ~= "" then
                        GameTooltip:AddLine(line, 0.84, 0.84, 0.84, true)
                    end
                end
            elseif type(lines) == "string" and lines ~= "" then
                GameTooltip:AddLine(lines, 0.84, 0.84, 0.84, true)
            end
            GameTooltip:Show()
        end)
        region:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)
    end

    region.twichUITooltipBound = true
end

local function SetTooltipData(region, title, lines)
    if not region then
        return
    end

    ---@diagnostic disable-next-line: inject-field
    region.tooltipTitle = title
    ---@diagnostic disable-next-line: inject-field
    region.tooltipLines = lines
end

function MPT:ApplyMythicPlusTimerStyle(frame)
    if not frame then
        return
    end

    local appearance = self:GetMythicPlusTimerAppearance()
    local style = self:GetDB().mythicPlusTimerStyle or "framed"
    local isTransparent = style == "transparent"
    local showHeader = not isTransparent and self:GetDB().mythicPlusTimerShowHeader ~= false
    local bgR, bgG, bgB, bgA, borderR, borderG, borderB = GetBackdropColors()

    frame:SetScale(self:GetMythicPlusTimerScale())

    if frame.BackgroundFill then
        frame.BackgroundFill:SetShown(not isTransparent)
    end
    if frame.InnerGlow then
        frame.InnerGlow:SetShown(not isTransparent)
    end

    if frame.SetBackdropColor then
        if isTransparent then
            frame:SetBackdropColor(0, 0, 0, 0)
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        else
            frame:SetBackdropColor(bgR, bgG, bgB, bgA)
            frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)
        end
    end

    if frame.TitleBar and frame.TitleBar.SetBackdropColor then
        frame.TitleBar:SetShown(showHeader)
        if isTransparent then
            frame.TitleBar:SetBackdropColor(0, 0, 0, 0)
            frame.TitleBar:SetBackdropBorderColor(0, 0, 0, 0)
        else
            frame.TitleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.98)
            frame.TitleBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.35)
        end
    end

    if frame.TitleAccent then
        frame.TitleAccent:SetShown(showHeader)
    end

    if frame.TitleIcon then
        frame.TitleIcon:SetShown(showHeader)
    end

    if frame.Title then
        frame.Title:SetShown(showHeader)
    end

    if frame.ContentInset and frame.ContentInset.SetBackdropColor then
        frame.ContentInset:ClearAllPoints()
        if isTransparent or not showHeader then
            frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
            frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        else
            frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
            frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        end

        if isTransparent then
            frame.ContentInset:SetBackdropColor(0, 0, 0, 0)
            frame.ContentInset:SetBackdropBorderColor(0, 0, 0, 0)
        else
            frame.ContentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, 0.98)
            frame.ContentInset:SetBackdropBorderColor(borderR, borderG, borderB, 0.45)
        end
    end

    if frame.KeyText then
        frame.KeyText:SetJustifyH(appearance.timerLayout == "right" and "RIGHT" or "LEFT")
    end
end

function MPT:CreateMythicPlusTimerBarRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.barBackdrop, row.bar = self:CreateTrackerBar(row)
    row.barBackdrop:SetAllPoints(row)

    row.content = CreateFrame("Frame", nil, row)
    row.content:SetAllPoints(row)
    row.content:SetFrameLevel((row.barBackdrop:GetFrameLevel() or row:GetFrameLevel()) + 5)

    row.label = row.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetJustifyH("LEFT")
    row.label:SetJustifyV("MIDDLE")

    row.value = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetJustifyH("RIGHT")
    row.value:SetJustifyV("MIDDLE")

    row.detail = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetJustifyH("LEFT")
    row.detail:SetJustifyV("MIDDLE")

    row.Markers = {}
    row.MarkerData = {}

    return row
end

function MPT:UpdateMythicPlusTimerForceMarkers(row)
    if not (row and row.barBackdrop) then
        return
    end

    row.Markers = row.Markers or {}
    local markerData = type(row.MarkerData) == "table" and row.MarkerData or {}
    local availableWidth = max(1, (row.barBackdrop:GetWidth() or 0) - 2)
    local barHeight = max(1, row.barBackdrop:GetHeight() or 1)

    for index, markerState in ipairs(markerData) do
        local marker = row.Markers[index]
        if not marker then
            marker = CreateFrame("Frame", nil, row.barBackdrop)
            marker:SetSize(10, barHeight + 12)
            marker:SetFrameLevel((row.barBackdrop:GetFrameLevel() or row:GetFrameLevel()) + 6)

            marker.Line = marker:CreateTexture(nil, "OVERLAY")
            marker.Line:SetPoint("TOP", marker, "TOP", 0, 0)
            marker.Line:SetPoint("BOTTOM", marker, "BOTTOM", 0, 0)
            marker.Line:SetWidth(3)

            marker.Dot = marker:CreateTexture(nil, "OVERLAY")
            marker.Dot:SetPoint("TOP", marker.Line, "TOP", 0, 0)
            marker.Dot:SetSize(8, 8)

            row.Markers[index] = marker
        end

        local percent = ClampNumber(markerState.percent, 0, 100, 0)
        local offsetX = floor(availableWidth * (percent / 100))
        local color = markerState.failedTarget and { 0.94, 0.34, 0.34, 1 } or
            markerState.completed and { 0.34, 0.92, 0.62, 1 } or
            (markerState.kind == "custom" and { 0.42, 0.82, 0.98, 1 } or { 0.96, 0.78, 0.24, 1 })

        marker:SetHeight(barHeight + 12)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", row.barBackdrop, "LEFT", 1 + offsetX, 0)
        marker.Line:SetColorTexture(color[1], color[2], color[3], 1)
        marker.Dot:SetColorTexture(color[1], color[2], color[3], 1)
        marker:Show()
    end

    for index = #markerData + 1, #row.Markers do
        row.Markers[index]:Hide()
    end
end

local function FormatCheckpointPercentText(percent)
    local resolvedPercent = tonumber(percent) or 0
    if abs(resolvedPercent - floor(resolvedPercent + 0.5)) < 0.01 then
        return string.format("%d%%", floor(resolvedPercent + 0.5))
    end

    return string.format("%.1f%%", resolvedPercent)
end

function MPT:CreateMythicPlusTimerMilestoneRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.content = CreateFrame("Frame", nil, row)
    row.content:SetAllPoints(row)
    row.Segments = {}

    for _, key in ipairs({ "plusOne", "plusTwo", "plusThree" }) do
        local segment = CreateFrame("Frame", nil, row.content)
        segment.backdrop, segment.bar = self:CreateTrackerBar(segment)
        segment.backdrop:SetAllPoints(segment)
        AttachTooltipHandlers(segment)
        segment.content = CreateFrame("Frame", nil, segment)
        segment.content:SetAllPoints(segment)
        segment.content:SetFrameLevel((segment.backdrop:GetFrameLevel() or segment:GetFrameLevel()) + 5)

        segment.Label = segment.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        segment.Label:SetJustifyH("LEFT")
        segment.Label:SetJustifyV("TOP")

        segment.Value = segment.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        segment.Value:SetJustifyH("CENTER")
        segment.Value:SetJustifyV("MIDDLE")

        segment.Flash = segment:CreateTexture(nil, "OVERLAY")
        segment.Flash:SetAllPoints(segment.backdrop)
        segment.Flash:SetAlpha(0)
        segment.Flash:SetBlendMode("ADD")

        segment.Chaser = segment:CreateTexture(nil, "OVERLAY")
        segment.Chaser:SetPoint("TOP", segment.backdrop, "TOP", 0, 0)
        segment.Chaser:SetPoint("BOTTOM", segment.backdrop, "BOTTOM", 0, 0)
        segment.Chaser:SetWidth(28)
        segment.Chaser:SetAlpha(0)
        segment.Chaser:SetBlendMode("ADD")

        segment.FlashAnimation = segment:CreateAnimationGroup()
        local flashIn = segment.FlashAnimation:CreateAnimation("Alpha")
        flashIn:SetTarget(segment.Flash)
        flashIn:SetFromAlpha(0)
        flashIn:SetToAlpha(0.34)
        flashIn:SetDuration(0.14)
        flashIn:SetOrder(1)

        local flashOut = segment.FlashAnimation:CreateAnimation("Alpha")
        flashOut:SetTarget(segment.Flash)
        flashOut:SetFromAlpha(0.34)
        flashOut:SetToAlpha(0)
        flashOut:SetDuration(0.5)
        flashOut:SetOrder(2)

        segment.ChaserAnimation = segment:CreateAnimationGroup()
        local chaserIn = segment.ChaserAnimation:CreateAnimation("Alpha")
        chaserIn:SetTarget(segment.Chaser)
        chaserIn:SetFromAlpha(0)
        chaserIn:SetToAlpha(0.65)
        chaserIn:SetDuration(0.08)
        chaserIn:SetOrder(1)

        local chaserMove = segment.ChaserAnimation:CreateAnimation("Translation")
        chaserMove:SetTarget(segment.Chaser)
        chaserMove:SetOffset(60, 0)
        chaserMove:SetDuration(0.48)
        chaserMove:SetSmoothing("OUT")
        chaserMove:SetOrder(2)

        local chaserOut = segment.ChaserAnimation:CreateAnimation("Alpha")
        chaserOut:SetTarget(segment.Chaser)
        chaserOut:SetFromAlpha(0.65)
        chaserOut:SetToAlpha(0)
        chaserOut:SetDuration(0.18)
        chaserOut:SetOrder(3)

        row.Segments[key] = segment
    end

    return row
end

function MPT:EnsureMythicPlusTimerAnimationSurfaces(frame)
    if not frame or frame.timerAnimationsInitialized then
        return
    end

    frame.timerAnimationsInitialized = true
end

function MPT:PlayMythicPlusTimerBossAnimation(completedIndex)
    local frame = self:EnsureMythicPlusTimerFrame()
    self:EnsureMythicPlusTimerAnimationSurfaces(frame)
    local flashColor = { 1, 0.86, 0.42, 1 }
    local completedColor = { 0.34, 0.92, 0.62, 1 }

    local resolvedIndex = tonumber(completedIndex)
    if not resolvedIndex or resolvedIndex <= 0 then
        for index = #frame.CheckpointRows, 1, -1 do
            local row = frame.CheckpointRows[index]
            if row and row:IsShown() and row.Name and row.Name:GetText() and row.Name:GetText() ~= "" then
                resolvedIndex = index
                break
            end
        end
    end

    local row = resolvedIndex and frame.CheckpointRows and frame.CheckpointRows[resolvedIndex]
    if row then
        PlayAnimationGroup(EnsureAlphaPulse(row.Name, "BossPulseAnimation", 0.28, 0.07, 0.34))
        PlayAnimationGroup(EnsureAlphaPulse(row.Percent, "BossPulseAnimation", 0.28, 0.07, 0.34))
        PlayAnimationGroup(EnsureAlphaPulse(row.Time, "BossPulseAnimation", 0.28, 0.07, 0.34))
        PlayAnimationGroup(EnsureTranslationPulse(row.Name, "BossSlideAnimation", 10, 0, 0.11, 0.24))
        PlayAnimationGroup(EnsureTranslationPulse(row.Percent, "BossSlideAnimation", -6, 0, 0.11, 0.24))
        PlayAnimationGroup(EnsureTranslationPulse(row.Time, "BossSlideAnimation", -10, 0, 0.11, 0.24))
        PlayAnimationGroup(EnsureFontColorBloom(row.Name, "BossColorBloom", flashColor, 0.22))
        PlayAnimationGroup(EnsureFontColorBloom(row.Percent, "BossColorBloom", flashColor, 0.22))
        PlayAnimationGroup(EnsureFontColorBloom(row.Time, "BossColorBloom", flashColor, 0.22))
        row.Name:SetTextColor(completedColor[1], completedColor[2], completedColor[3], completedColor[4])
        row.Percent:SetTextColor(completedColor[1], completedColor[2], completedColor[3], completedColor[4])
        row.Time:SetTextColor(completedColor[1], completedColor[2], completedColor[3], completedColor[4])
    end

    PlayAnimationGroup(EnsureAlphaPulse(frame.CheckpointHeader, "BossPulseAnimation", 0.35, 0.07, 0.28))
    PlayAnimationGroup(EnsureAlphaPulse(frame.ElapsedText, "BossPulseAnimation", 0.35, 0.07, 0.28))
    PlayAnimationGroup(EnsureTranslationPulse(frame.ElapsedText, "BossSlideAnimation", 0, -4, 0.1, 0.22))
    PlayAnimationGroup(EnsureFontColorBloom(frame.CheckpointHeader, "BossColorBloom", flashColor, 0.18))
end

function MPT:PlayMythicPlusTimerUpgradeAnimation(segmentKey)
    local frame = self:EnsureMythicPlusTimerFrame()
    self:EnsureMythicPlusTimerAnimationSurfaces(frame)

    local segment = frame.MilestoneRow and frame.MilestoneRow.Segments and
        frame.MilestoneRow.Segments[segmentKey or "plusOne"]
    if segment and segment.Flash then
        local color = segment.barColor or TIMER_PLUS_ONE_COLOR
        segment.Flash:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, 1)
        PlayAnimationGroup(segment.FlashAnimation)
        if segment.Chaser then
            segment.Chaser:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, 1)
            PlayAnimationGroup(segment.ChaserAnimation)
        end
        PlayAnimationGroup(EnsureAlphaPulse(segment.Label, "UpgradePulseAnimation", 0.25, 0.08, 0.28))
        PlayAnimationGroup(EnsureAlphaPulse(segment.Value, "UpgradePulseAnimation", 0.25, 0.08, 0.28))
    end

    PlayAnimationGroup(EnsureAlphaPulse(frame.KeyText, "UpgradePulseAnimation", 0.35, 0.08, 0.28))
end

function MPT:EnsureMythicPlusTimerFrame()
    if self.mythicPlusTimerFrame then
        return self.mythicPlusTimerFrame
    end

    local frame = self:CreateBaseFrame(420, 320, "Mythic+ Timer", 236686)
    frame:SetPoint("CENTER", UIParent, "CENTER", -260, -40)
    frame.suppressCloseButton = true
    frame.hasSettingsButton = true
    frame.EmptyText:SetText("No active Mythic+ run detected.")

    frame.KeyText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.KeyText:SetJustifyH("LEFT")
    AttachTooltipHandlers(frame.KeyText)

    frame.AffixText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.AffixText:SetJustifyH("LEFT")
    AttachTooltipHandlers(frame.AffixText)

    frame.ElapsedText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.ElapsedText:SetJustifyH("LEFT")
    AttachTooltipHandlers(frame.ElapsedText)

    frame.DeathText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.DeathText:SetJustifyH("LEFT")
    AttachTooltipHandlers(frame.DeathText)

    frame.BarsHeader = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.BarsHeader:SetJustifyH("LEFT")
    frame.BarsHeader:SetText("Milestones")
    AttachTooltipHandlers(frame.BarsHeader)

    frame.MilestoneRow = self:CreateMythicPlusTimerMilestoneRow(frame.ScrollChild)
    AttachTooltipHandlers(frame.MilestoneRow)
    frame.ForcesRow = self:CreateMythicPlusTimerBarRow(frame.ScrollChild)
    AttachTooltipHandlers(frame.ForcesRow)

    frame.CheckpointHeader = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.CheckpointHeader:SetJustifyH("LEFT")
    frame.CheckpointHeader:SetText("Checkpoints")
    AttachTooltipHandlers(frame.CheckpointHeader)

    frame.CheckpointRows = {}
    for index = 1, 8 do
        local row = CreateFrame("Frame", nil, frame.ScrollChild)
        row:SetHeight(18)

        row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Name:SetJustifyH("LEFT")
        row.Name:SetPoint("LEFT", row, "LEFT", 0, 0)

        row.Percent = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Percent:SetJustifyH("RIGHT")

        row.Time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Time:SetJustifyH("RIGHT")
        row.Time:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        AttachTooltipHandlers(row)

        frame.CheckpointRows[index] = row
    end

    frame:SetScript("OnDragStart", function(widget)
        if self:GetFrameLocked("timer") then
            return
        end
        widget:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(widget)
        widget:StopMovingOrSizing()
        self:PersistFramePosition("timer", widget)
    end)

    self:ApplyFrameSize("timer", frame)
    self:InitializeFrameControls("timer", frame)
    self:RestoreFramePosition("timer", frame, -260, -40)
    self:EnsureMythicPlusTimerAnimationSurfaces(frame)

    self.mythicPlusTimerFrame = frame
    return frame
end

function MPT:BuildMythicPlusTimerPreviewState()
    local plusOneLimit, plusTwoLimit, plusThreeLimit = GetMythicPlusTimeLimits(33 * 60, false)
    local plusOneFraction, plusTwoFraction, plusThreeFraction = GetMythicPlusTimerBarFractions(33 * 60, false)
    local mapID = self:GetSelectedCheckpointMapID()
    local mapName = (type(mapID) == "number" and mapID > 0 and GetMythicPlusMapName(mapID)) or "The Stonevault"
    local configuredCheckpoints = self:GetConfiguredDungeonCheckpoints(mapID)
    local previewCheckpointRows = {}
    local previewTimes = { "[04:26]", "[09:41]", "[14:18]", "Pending", "Pending", "Pending", "Pending", "Pending" }
    local previewForceMarkers = {}
    local completedForcesPercent = 94

    if #configuredCheckpoints > 0 then
        local lastCompletedPercent = 0
        for index, checkpoint in ipairs(configuredCheckpoints) do
            if index <= 2 then
                lastCompletedPercent = max(lastCompletedPercent, tonumber(checkpoint.percent) or 0)
            end
        end
        completedForcesPercent = ClampNumber(lastCompletedPercent > 0 and max(lastCompletedPercent, 35) or 94, 0, 100, 94)
    end

    for index, checkpoint in ipairs(configuredCheckpoints) do
        local completed = (tonumber(checkpoint.percent) or 0) <= completedForcesPercent
        previewCheckpointRows[#previewCheckpointRows + 1] = {
            id = checkpoint.id,
            name = tostring(checkpoint.name or ("Checkpoint " .. index)),
            time = checkpoint.kind == "boss" and
                (completed and (previewTimes[#previewCheckpointRows + 1] or "[18:42]") or "Pending") or
                "",
            completed = completed,
            percent = tonumber(checkpoint.percent) or 0,
            kind = checkpoint.kind,
            notifyEnabled = checkpoint.notifyEnabled ~= false,
        }
        previewForceMarkers[#previewForceMarkers + 1] = {
            name = tostring(checkpoint.name or ("Checkpoint " .. index)),
            percent = tonumber(checkpoint.percent) or 0,
            completed = completed,
            kind = checkpoint.kind,
        }
    end

    if #previewCheckpointRows == 0 then
        previewCheckpointRows = {
            { id = "boss_1",   name = "E.D.N.A.",            time = "[04:26]", completed = true,  percent = 25,  kind = "boss",   notifyEnabled = true },
            { id = "boss_2",   name = "Skarmorak",           time = "[09:41]", completed = true,  percent = 52,  kind = "boss",   notifyEnabled = true },
            { id = "custom_1", name = "South Hall Clear",    time = "",        completed = true,  percent = 74,  kind = "custom", notifyEnabled = true },
            { id = "boss_3",   name = "Master Machinists",   time = "Pending", completed = false, percent = 88,  kind = "boss",   notifyEnabled = true },
            { id = "boss_4",   name = "Void Speaker Eirich", time = "Pending", completed = false, percent = 100, kind = "boss",   notifyEnabled = true },
        }
        previewForceMarkers = {
            { name = "E.D.N.A.",            percent = 25,  completed = true,  kind = "boss" },
            { name = "Skarmorak",           percent = 52,  completed = true,  kind = "boss" },
            { name = "South Hall Clear",    percent = 74,  completed = true,  kind = "custom" },
            { name = "Master Machinists",   percent = 88,  completed = false, kind = "boss" },
            { name = "Void Speaker Eirich", percent = 100, completed = false, kind = "boss" },
        }
    end

    local completedCheckpointCount = 0
    for _, checkpoint in ipairs(previewCheckpointRows) do
        if checkpoint.completed then
            completedCheckpointCount = completedCheckpointCount + 1
        end
    end

    return {
        active = true,
        mapName = mapName,
        keyText = "+12 " .. mapName,
        affixText = "Tyrannical • Challenger's Peril • Volcanic",
        elapsedText = "18:42 / 33:00",
        deathText = "Deaths 4  |  +20s",
        milestoneBar = {
            segments = {
                { key = "plusOne",   label = "+1", widthFraction = plusOneFraction,   timeLimit = plusOneLimit,   nextLimit = plusTwoLimit,   value = "",      progress = 0,    color = TIMER_PLUS_ONE_COLOR },
                { key = "plusTwo",   label = "+2", widthFraction = plusTwoFraction,   timeLimit = plusTwoLimit,   nextLimit = plusThreeLimit, value = "",      progress = 0,    color = TIMER_PLUS_TWO_COLOR },
                { key = "plusThree", label = "+3", widthFraction = plusThreeFraction, timeLimit = plusThreeLimit, nextLimit = 0,              value = "01:06", progress = 0.94, color = TIMER_PLUS_THREE_COLOR },
            },
        },
        forcesBar = {
            label = "Forces",
            detail = string.format("%d / 100 enemy forces", completedForcesPercent),
            value = string.format("%.1f%%", completedForcesPercent),
            progress = completedForcesPercent / 100,
            color = TIMER_FORCES_COLOR,
        },
        forceMarkers = previewForceMarkers,
        checkpoints = previewCheckpointRows,
        completedCheckpointCount = completedCheckpointCount,
        currentUpgradeTier = 3,
    }
end

function MPT:BuildActiveMythicPlusTimerState()
    if not IsChallengeModeActive() then
        self:ResetMythicPlusTimerTracking()
        return nil
    end

    local mapID = C_ChallengeMode and type(C_ChallengeMode.GetActiveChallengeMapID) == "function" and
        C_ChallengeMode.GetActiveChallengeMapID() or nil
    if type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end

    local level = 0
    local affixIDs = nil
    if C_ChallengeMode and type(C_ChallengeMode.GetActiveKeystoneInfo) == "function" then
        local keystoneInfo = { C_ChallengeMode.GetActiveKeystoneInfo() }
        level = tonumber(keystoneInfo[1]) or 0
        if type(keystoneInfo[2]) == "table" then
            affixIDs = keystoneInfo[2]
        else
            affixIDs = {}
            for index = 2, #keystoneInfo do
                if type(keystoneInfo[index]) == "number" then
                    affixIDs[#affixIDs + 1] = keystoneInfo[index]
                end
            end
        end
    end

    self.mythicPlusTimerState = self.mythicPlusTimerState or {
        mapID = nil,
        level = nil,
        bossCheckpoints = {},
        customCheckpoints = {},
        forcesCompletionTime = nil,
    }

    if self.mythicPlusTimerState.mapID ~= mapID or self.mythicPlusTimerState.level ~= level then
        self:ResetMythicPlusTimerTracking()
        self.mythicPlusTimerState.mapID = mapID
        self.mythicPlusTimerState.level = level
    end

    local elapsed = type(GetWorldElapsedTime) == "function" and select(2, GetWorldElapsedTime(1)) or 0
    local deathCount = 0
    local deathTimeLost = 0
    if C_ChallengeMode and type(C_ChallengeMode.GetDeathCount) == "function" then
        local deathInfo = { C_ChallengeMode.GetDeathCount() }
        deathCount = tonumber(deathInfo[1]) or 0
        deathTimeLost = tonumber(deathInfo[2]) or 0
    end

    local mapName, _, timeLimit
    if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
        mapName, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    end
    mapName = type(mapName) == "string" and mapName or GetMythicPlusMapName(mapID)
    timeLimit = tonumber(timeLimit) or 0

    local affixNames = {}
    local hasChallengersPeril = false
    for _, affixID in ipairs(type(affixIDs) == "table" and affixIDs or {}) do
        if affixID == 152 then
            hasChallengersPeril = true
        end
        if type(C_ChallengeMode.GetAffixInfo) == "function" then
            local affixName = C_ChallengeMode.GetAffixInfo(affixID)
            if type(affixName) == "string" and affixName ~= "" then
                affixNames[#affixNames + 1] = affixName
            end
        end
    end

    local plusOneLimit, plusTwoLimit, plusThreeLimit = GetMythicPlusTimeLimits(timeLimit, hasChallengersPeril)
    local plusOneFraction, plusTwoFraction, plusThreeFraction = GetMythicPlusTimerBarFractions(timeLimit,
        hasChallengersPeril)
    local milestoneSegments = {
        {
            key = "plusOne",
            label = "+1",
            widthFraction = plusOneFraction,
            timeLimit = plusOneLimit,
            nextLimit = plusTwoLimit,
            value = elapsed > plusTwoLimit and FormatSignedClock(plusOneLimit - elapsed) or "",
            progress = plusOneLimit > plusTwoLimit and
                ClampNumber((elapsed - plusTwoLimit) / (plusOneLimit - plusTwoLimit), 0, 1, 0) or 0,
            color = TIMER_PLUS_ONE_COLOR,
        },
        {
            key = "plusTwo",
            label = "+2",
            widthFraction = plusTwoFraction,
            timeLimit = plusTwoLimit,
            nextLimit = plusThreeLimit,
            value = elapsed > plusThreeLimit and elapsed <= plusTwoLimit and FormatClock(plusTwoLimit - elapsed) or "",
            progress = plusTwoLimit > plusThreeLimit and
                ClampNumber((elapsed - plusThreeLimit) / (plusTwoLimit - plusThreeLimit), 0, 1, 0) or 0,
            color = TIMER_PLUS_TWO_COLOR,
        },
        {
            key = "plusThree",
            label = "+3",
            widthFraction = plusThreeFraction,
            timeLimit = plusThreeLimit,
            nextLimit = 0,
            value = elapsed <= plusThreeLimit and FormatClock(plusThreeLimit - elapsed) or "",
            progress = plusThreeLimit > 0 and ClampNumber(elapsed / plusThreeLimit, 0, 1, 0) or 0,
            color = TIMER_PLUS_THREE_COLOR,
        },
    }

    local bossCheckpoints = {}
    local completedCheckpointCount = 0
    local totalCount = 0
    local currentCount = 0
    -- Iterate the same range WarpDeplete does: criteria can live at indices
    -- beyond what GetStepInfo()'s numCriteria reports in some dungeons (e.g.
    -- Tazavesh multi-wing).  Hard-capping at 10 ensures we always find the
    -- isWeightedProgress forces criterion even if numCriteria is wrong.
    local stepCount = C_Scenario and type(C_Scenario.GetStepInfo) == "function" and select(3, C_Scenario.GetStepInfo()) or
        0
    for index = 1, max(10, tonumber(stepCount) or 0) do
        local info = C_ScenarioInfo and type(C_ScenarioInfo.GetCriteriaInfo) == "function" and
            C_ScenarioInfo.GetCriteriaInfo(index)
        if type(info) == "table" then
            if info.isWeightedProgress and type(info.totalQuantity) == "number" and info.totalQuantity > 0 then
                totalCount = info.totalQuantity
                currentCount = ExtractWeightedProgressCount(info)
                -- Monotonically-increasing protection: the API can briefly report 0
                -- right before CHALLENGE_MODE_COMPLETED fires (WarpDeplete note).
                -- Never let the displayed count go backwards once we've seen a higher
                -- value during this run.
                local lastKnown = tonumber(self.mythicPlusTimerState.lastKnownForceCount) or 0
                if currentCount < lastKnown then
                    currentCount = lastKnown
                else
                    self.mythicPlusTimerState.lastKnownForceCount = currentCount
                end
                if currentCount >= totalCount and not self.mythicPlusTimerState.forcesCompletionTime then
                    self.mythicPlusTimerState.forcesCompletionTime = max(0, elapsed - (tonumber(info.elapsed) or 0))
                end
            else
                local key = format("%d:%s", index, tostring(info.description or "Boss"))
                if info.completed and self.mythicPlusTimerState.bossCheckpoints[key] == nil then
                    self.mythicPlusTimerState.bossCheckpoints[key] = {
                        time = max(0, elapsed - (tonumber(info.elapsed) or 0)),
                    }
                end
                if info.completed then
                    completedCheckpointCount = completedCheckpointCount + 1
                end

                bossCheckpoints[#bossCheckpoints + 1] = {
                    key = key,
                    name = tostring(info.description or ("Boss " .. index)),
                    time = info.completed and
                        ("[" .. FormatClock((type(self.mythicPlusTimerState.bossCheckpoints[key]) == "table" and
                            self.mythicPlusTimerState.bossCheckpoints[key].time) or 0) .. "]") or "Pending",
                    completed = info.completed == true,
                }
            end
        end
    end

    local configuredCheckpoints = self:GetConfiguredDungeonCheckpoints(mapID)
    local forceMarkers = {}
    local checkpoints = bossCheckpoints
    local progressPercent = totalCount > 0 and ClampNumber((currentCount / totalCount) * 100, 0, 100, 0) or 0

    self.mythicPlusTimerState.customCheckpoints = self.mythicPlusTimerState.customCheckpoints or {}

    if #configuredCheckpoints > 0 then
        checkpoints = {}
        completedCheckpointCount = 0
        local bossIndex = 0

        for _, checkpoint in ipairs(configuredCheckpoints) do
            local rowState = {
                id = checkpoint.id,
                name = tostring(checkpoint.name or "Checkpoint"),
                time = checkpoint.kind == "boss" and "Pending" or "",
                completed = false,
                percent = tonumber(checkpoint.percent) or 0,
                kind = checkpoint.kind,
                notifyEnabled = checkpoint.notifyEnabled ~= false,
                failedTarget = false,
            }

            if checkpoint.kind == "boss" then
                bossIndex = bossIndex + 1
                local bossState = bossCheckpoints[bossIndex]
                if bossState then
                    local storedBossState = type(self.mythicPlusTimerState.bossCheckpoints[bossState.key]) == "table" and
                        self.mythicPlusTimerState.bossCheckpoints[bossState.key] or nil
                    if storedBossState and storedBossState.forcePercent == nil then
                        storedBossState.forcePercent = progressPercent
                    end
                    rowState.time = bossState.time
                    rowState.completed = bossState.completed == true
                    rowState.failedTarget = rowState.completed and storedBossState and
                        (tonumber(storedBossState.forcePercent) or 0) < rowState.percent
                elseif totalCount > 0 and progressPercent >= rowState.percent then
                    rowState.time = "Pending"
                end
            else
                if totalCount > 0 and progressPercent >= rowState.percent then
                    rowState.completed = true
                end
            end

            if rowState.completed then
                completedCheckpointCount = completedCheckpointCount + 1
            end

            checkpoints[#checkpoints + 1] = rowState
            forceMarkers[#forceMarkers + 1] = {
                name = rowState.name,
                percent = rowState.percent,
                completed = rowState.completed,
                kind = rowState.kind,
                failedTarget = rowState.failedTarget,
            }
        end
    end

    local forcesBar = {
        label = "Forces",
        detail = totalCount > 0 and format("%d / %d enemy forces", currentCount, totalCount) or
            "Enemy forces unavailable",
        value = totalCount > 0 and format("%.1f%%", min(100, (currentCount / totalCount) * 100)) or "--",
        progress = totalCount > 0 and ClampNumber(currentCount / totalCount, 0, 1, 0) or 0,
        color = TIMER_FORCES_COLOR,
    }

    local currentUpgradeTier = 0
    if elapsed <= plusThreeLimit then
        currentUpgradeTier = 3
    elseif elapsed <= plusTwoLimit then
        currentUpgradeTier = 2
    elseif elapsed <= plusOneLimit then
        currentUpgradeTier = 1
    end

    return {
        active = true,
        mapName = mapName,
        keyText = format("+%d %s", level, mapName),
        affixText = #affixNames > 0 and table.concat(affixNames, " • ") or "Affixes unavailable",
        elapsedText = FormatClock(elapsed) .. " / " .. FormatClock(timeLimit),
        deathText = format("Deaths %d  |  +%ss", deathCount or 0, tostring(deathTimeLost or 0)),
        milestoneBar = {
            segments = milestoneSegments,
        },
        forcesBar = forcesBar,
        forceMarkers = forceMarkers,
        checkpoints = checkpoints,
        completedCheckpointCount = completedCheckpointCount,
        currentUpgradeTier = currentUpgradeTier,
        plusThreeExpired = plusThreeLimit > 0 and elapsed > plusThreeLimit,
        plusTwoExpired = plusTwoLimit > 0 and elapsed > plusTwoLimit,
        plusOneExpired = plusOneLimit > 0 and elapsed > plusOneLimit,
        forcesCompleted = totalCount > 0 and currentCount >= totalCount,
    }
end

function MPT:BuildMythicPlusTimerNotification(kind, state, checkpoint)
    local mapName = state and state.mapName or "the current key"
    if kind == "plusThree" then
        return {
            status = "MYTHIC+ TIMER",
            title = "+3 Timer Ended",
            detail = format("%s is no longer on pace for a +3.", mapName),
            icon = 236686,
            color = TIMER_PLUS_THREE_COLOR,
        }
    elseif kind == "plusTwo" then
        return {
            status = "MYTHIC+ TIMER",
            title = "+2 Timer Ended",
            detail = format("%s is no longer on pace for a +2.", mapName),
            icon = 236686,
            color = TIMER_PLUS_TWO_COLOR,
        }
    elseif kind == "plusOne" then
        return {
            status = "MYTHIC+ TIMER",
            title = "+1 Timer Ended",
            detail = format("%s key has been depleted.", mapName),
            icon = 236686,
            color = TIMER_PLUS_ONE_COLOR,
        }
    elseif kind == "checkpoint" then
        local checkpointName = checkpoint and checkpoint.name or "Boss Checkpoint"
        local checkpointTime = checkpoint and checkpoint.time or "Pending"
        local checkpointPercent = checkpoint and checkpoint.percent and FormatCheckpointPercentText(checkpoint.percent) or
            nil
        local detail
        if checkpoint and checkpoint.kind == "custom" then
            detail = format("Checkpoint reached at %s forces in %s.", tostring(checkpointPercent or "--"), mapName)
        else
            detail = format("Checkpoint completed at %s in %s.", tostring(checkpointTime), mapName)
        end
        return {
            status = "MYTHIC+ TIMER",
            title = tostring(checkpointName),
            detail = detail,
            icon = 236686,
            color = { 0.34, 0.92, 0.62, 1 },
        }
    end

    return {
        status = "MYTHIC+ TIMER",
        title = "Forces Complete",
        detail = format("Enemy forces are complete in %s.", mapName),
        icon = 132349,
        color = TIMER_FORCES_COLOR,
    }
end

function MPT:SendMythicPlusTimerNotification(kind, state, checkpoint)
    local notification = self:BuildMythicPlusTimerNotification(kind, state, checkpoint)
    ---@type TwichUI_MythicPlusAlertNotificationWidget
    local widget = CreateWidget(AceGUI, "TwichUI_MythicPlusAlertNotification")
    widget:SetAlert(notification.status, notification.title, notification.detail, notification.icon, notification.color)

    if NotificationModule and type(NotificationModule.TWICH_NOTIFICATION) == "function" then
        local db = self:GetDB()
        local soundKey = kind == "checkpoint" and db.mythicPlusCheckpointNotificationSound or
            db.mythicPlusTimerNotificationSound
        if soundKey == MUTED_SOUND_VALUE then
            soundKey = nil
        elseif soundKey == nil then
            soundKey = "TwichUI Alert 1"
        end

        NotificationModule:TWICH_NOTIFICATION("TWICH_NOTIFICATION", widget, {
            soundKey = soundKey,
            displayDuration = kind == "checkpoint" and
                (db.mythicPlusCheckpointNotificationDisplayTime or 8) or
                (db.mythicPlusTimerNotificationDisplayTime or 8),
        })
    end
end

function MPT:HandleMythicPlusTimerNotifications(state)
    if not state or self.preview.mythicPlusTimer then
        return
    end

    self.mythicPlusTimerState = self.mythicPlusTimerState or {}
    local previous = self.mythicPlusTimerState.lastNotificationState
    local current = {
        plusThreeExpired = state.plusThreeExpired == true,
        plusTwoExpired = state.plusTwoExpired == true,
        plusOneExpired = state.plusOneExpired == true,
        forcesCompleted = state.forcesCompleted == true,
        checkpointStates = {},
    }

    for _, checkpoint in ipairs(state.checkpoints or {}) do
        current.checkpointStates[tostring(checkpoint.id or checkpoint.name or "checkpoint")] = checkpoint.completed ==
            true
    end

    if previous then
        local db = self:GetDB()
        if db.mythicPlusTimerNotifyPlusThreeExpired ~= false and current.plusThreeExpired and not previous.plusThreeExpired then
            self:SendMythicPlusTimerNotification("plusThree", state)
        end
        if db.mythicPlusTimerNotifyPlusTwoExpired ~= false and current.plusTwoExpired and not previous.plusTwoExpired then
            self:SendMythicPlusTimerNotification("plusTwo", state)
        end
        if db.mythicPlusTimerNotifyPlusOneExpired ~= false and current.plusOneExpired and not previous.plusOneExpired then
            self:SendMythicPlusTimerNotification("plusOne", state)
        end
        if db.mythicPlusTimerNotifyForcesComplete ~= false and current.forcesCompleted and not previous.forcesCompleted then
            self:SendMythicPlusTimerNotification("forces", state)
        end
        if db.mythicPlusTimerNotifyCheckpointComplete ~= false then
            for _, checkpoint in ipairs(state.checkpoints or {}) do
                local checkpointKey = tostring(checkpoint.id or checkpoint.name or "checkpoint")
                local wasCompleted = previous.checkpointStates and previous.checkpointStates[checkpointKey] == true
                if checkpoint.completed and not wasCompleted and checkpoint.notifyEnabled ~= false then
                    self:SendMythicPlusTimerNotification("checkpoint", state, checkpoint)
                    break
                end
            end
        end
    end

    self.mythicPlusTimerState.lastNotificationState = current
end

function MPT:HandleMythicPlusTimerStateAnimations(state)
    if not state or self.preview.mythicPlusTimer then
        return
    end

    self.mythicPlusTimerState = self.mythicPlusTimerState or {}

    local previousUpgradeTier = tonumber(self.mythicPlusTimerState.lastUpgradeTier)
    local previousCheckpointStates = self.mythicPlusTimerState.lastCheckpointStates or {}
    local newlyCompletedCheckpointIndex = nil

    for index, checkpoint in ipairs(state.checkpoints or {}) do
        local checkpointKey = tostring(checkpoint.id or checkpoint.name or index)
        if checkpoint.completed and previousCheckpointStates[checkpointKey] ~= true then
            newlyCompletedCheckpointIndex = index
            break
        end
    end

    if newlyCompletedCheckpointIndex then
        self:PlayMythicPlusTimerBossAnimation(newlyCompletedCheckpointIndex)
    end

    if previousUpgradeTier and tonumber(state.currentUpgradeTier) and state.currentUpgradeTier ~= previousUpgradeTier then
        local segmentKeyByTier = {
            [3] = "plusThree",
            [2] = "plusTwo",
            [1] = "plusOne",
            [0] = "plusOne",
        }
        self:PlayMythicPlusTimerUpgradeAnimation(segmentKeyByTier[state.currentUpgradeTier] or "plusOne")
    end

    self.mythicPlusTimerState.lastCheckpointCount = tonumber(state.completedCheckpointCount) or 0
    self.mythicPlusTimerState.lastUpgradeTier = tonumber(state.currentUpgradeTier) or 0
    self.mythicPlusTimerState.lastCheckpointStates = {}
    for index, checkpoint in ipairs(state.checkpoints or {}) do
        local checkpointKey = tostring(checkpoint.id or checkpoint.name or index)
        self.mythicPlusTimerState.lastCheckpointStates[checkpointKey] = checkpoint.completed == true
    end
end

function MPT:HandleMythicPlusTimerStateAnimations_LegacyPlaceholder()
end

-- The modern handler above replaces the old count-based version.
do
    local _ = MPT.HandleMythicPlusTimerStateAnimations_LegacyPlaceholder
end

function MPT:RefreshMythicPlusTimerFrame()
    local frame = self:EnsureMythicPlusTimerFrame()
    local appearance = self:GetMythicPlusTimerAppearance()
    local state = self.preview.mythicPlusTimer and self:BuildMythicPlusTimerPreviewState() or
        self:BuildActiveMythicPlusTimerState()
    local shouldShow = self.preview.mythicPlusTimer or
        (IsModuleConfiguredEnabled() and self:IsFeatureEnabled("mythicPlusTimer") and state and self:ShouldShowTrackerFrames())

    if not shouldShow or not state then
        frame:Hide()
        return
    end

    frame:Show()
    frame.EmptyText:Hide()
    self:ApplyMythicPlusTimerStyle(frame)

    frame.KeyText:SetText(state.keyText or state.mapName or "Mythic+")
    frame.AffixText:SetText(state.affixText or "")
    frame.ElapsedText:SetText(state.elapsedText or "")
    frame.DeathText:SetText(state.deathText or "")
    SetTooltipData(frame.KeyText, "Keystone", {
        "Current keystone level and dungeon.",
        tostring(state.keyText or state.mapName or "Mythic+"),
    })
    SetTooltipData(frame.AffixText, "Affixes", {
        "Weekly affixes active for this run.",
        tostring(state.affixText or "Affixes unavailable"),
    })
    SetTooltipData(frame.ElapsedText, "Timer", {
        "Elapsed run time versus the base dungeon timer.",
        tostring(state.elapsedText or ""),
    })
    SetTooltipData(frame.DeathText, "Deaths", {
        "Party deaths and the total time penalty added to the run.",
        tostring(state.deathText or ""),
    })
    SetTooltipData(frame.BarsHeader, "Milestones", {
        "Upgrade timer windows.",
        "These bars now start full and drain as each upgrade window expires.",
    })
    frame.MilestoneRow.tooltipTitle = "Upgrade Timers"
    frame.MilestoneRow.tooltipLines = {
        "Track the remaining time for +3, +2, and +1 upgrade windows.",
        "Each segment drains toward zero as its window closes.",
    }

    for _, key in ipairs({ "plusOne", "plusTwo", "plusThree" }) do
        local segment = frame.MilestoneRow.Segments[key]
        segment.widthFraction = 0
        segment.Label:SetText("")
        segment.Value:SetText("")
        segment.bar:SetStatusBarTexture(appearance.timerBarTexture)
        segment.bar:SetMinMaxValues(0, 1)
        segment.bar:SetValue(0)
        segment.tooltipProvider = function(widget)
            return widget.tooltipTitle, widget.tooltipLines
        end
    end

    for _, segmentState in ipairs((state.milestoneBar and state.milestoneBar.segments) or {}) do
        local segment = frame.MilestoneRow.Segments[segmentState.key]
        if segment then
            segment.widthFraction = tonumber(segmentState.widthFraction) or 0
            segment.Label:SetText(segmentState.label or "")
            segment.Value:SetText(segmentState.value or "")
            segment.bar:SetValue(1 - ClampNumber(segmentState.progress, 0, 1, 0))
            segment.barColor = appearance.timerBarColorMode == "custom" and appearance.timerBarColor or
                (segmentState.color or ACTIVE_COLOR)
            SetStatusBarColor(segment.bar, segment.barColor)
            local progress = ClampNumber(segmentState.progress, 0, 1, 0)
            local detailLine = ""
            if progress <= 0 then
                detailLine = "This window is still fully available."
            elseif progress >= 1 then
                detailLine = "This window has expired."
            elseif segmentState.value and segmentState.value ~= "" then
                detailLine = "Time left: " .. tostring(segmentState.value)
            else
                detailLine = "This window is currently draining."
            end
            segment.tooltipTitle = tostring(segmentState.label or "Milestone") .. " Window"
            segment.tooltipLines = {
                "Remaining time in this upgrade range.",
                detailLine,
            }
            if segment.Flash then
                segment.Flash:SetColorTexture(segment.barColor[1] or 1, segment.barColor[2] or 1,
                    segment.barColor[3] or 1, 1)
            end
        end
    end

    frame.ForcesRow:Show()
    frame.ForcesRow.label:SetText(state.forcesBar and state.forcesBar.label or "")
    frame.ForcesRow.value:SetText(state.forcesBar and state.forcesBar.value or "")
    frame.ForcesRow.detail:SetText(state.forcesBar and state.forcesBar.detail or "")
    frame.ForcesRow.MarkerData = state.forceMarkers or {}
    frame.ForcesRow.tooltipTitle = "Enemy Forces"
    frame.ForcesRow.tooltipLines = {
        "Enemy forces required to complete the dungeon.",
        tostring(state.forcesBar and state.forcesBar.detail or "Enemy forces unavailable"),
    }
    frame.ForcesRow.bar:SetStatusBarTexture(appearance.timerBarTexture)
    frame.ForcesRow.bar:SetMinMaxValues(0, 1)
    frame.ForcesRow.bar:SetValue(ClampNumber(state.forcesBar and state.forcesBar.progress or 0, 0, 1, 0))
    SetStatusBarColor(frame.ForcesRow.bar,
        appearance.timerBarColorMode == "custom" and appearance.timerBarColor or
        ((state.forcesBar and state.forcesBar.color) or TIMER_FORCES_COLOR))

    local showBossCheckpoints = self:GetDB().mythicPlusTimerShowBossCheckpoints ~= false
    frame.CheckpointHeader:SetText("Checkpoints")
    frame.CheckpointHeader:SetShown(showBossCheckpoints)
    SetTooltipData(frame.CheckpointHeader, "Checkpoints", {
        "Configured boss and custom checkpoints for the current run.",
        "Completed checkpoints show the configured percent and any boss completion time.",
    })

    for _, row in ipairs(frame.CheckpointRows) do
        row.Name:SetText("")
        row.Percent:SetText("")
        row.Time:SetText("")
        row.IsCompleted = false
        row.FailedTarget = false
        row.tooltipTitle = nil
        row.tooltipLines = nil
    end

    local visibleCheckpointCount = 0
    for index, rowState in ipairs(state.checkpoints or {}) do
        local row = frame.CheckpointRows[index]
        if row and showBossCheckpoints then
            row.Name:SetText(rowState.name or "")
            row.Percent:SetText(FormatCheckpointPercentText(rowState.percent))
            row.Time:SetText(rowState.kind == "boss" and (rowState.time or "Pending") or "")
            row.IsCompleted = rowState.completed == true
            row.FailedTarget = rowState.failedTarget == true
            row.tooltipTitle = tostring(rowState.name or "Checkpoint")
            row.tooltipLines = {
                "Target forces: " .. FormatCheckpointPercentText(rowState.percent),
                rowState.kind == "boss" and
                (row.IsCompleted and ("Boss defeated at " .. tostring(rowState.time or "unknown time") .. ".") or "Boss not defeated yet.") or
                (row.IsCompleted and "Custom checkpoint completed." or "Custom checkpoint not reached yet."),
            }
            if row.FailedTarget then
                row.tooltipLines[#row.tooltipLines + 1] =
                "Boss was defeated before the configured forces target was reached."
            end
            visibleCheckpointCount = visibleCheckpointCount + 1
        end
    end

    self:LayoutMythicPlusTimerFrame(frame, showBossCheckpoints and visibleCheckpointCount or 0)
    self:UpdateMythicPlusTimerForceMarkers(frame.ForcesRow)
    self:HandleMythicPlusTimerNotifications(state)
    self:HandleMythicPlusTimerStateAnimations(state)
end

function MPT:LayoutMythicPlusTimerFrame(frame, checkpointCount)
    if not frame then
        return
    end

    local appearance = self:GetMythicPlusTimerAppearance()
    local alignRight = appearance.timerLayout == "right"

    if frame.ScrollChild and frame.ContentScroll then
        frame.ScrollChild:SetWidth(max(1, frame.ContentScroll:GetWidth() or 1))
    end

    local outline = appearance.timerOutline
    local yOffset = -8

    local function anchorFontString(fontString, height)
        fontString:ClearAllPoints()
        fontString:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 8, yOffset)
        fontString:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", -8, yOffset)
        fontString:SetJustifyH(alignRight and "RIGHT" or "LEFT")
        yOffset = yOffset - height
    end

    anchorFontString(frame.KeyText, appearance.timerFontSize + 8)
    anchorFontString(frame.AffixText, appearance.timerFontSize + 4)
    yOffset = yOffset - 4
    anchorFontString(frame.ElapsedText, appearance.timerFontSize + 6)
    anchorFontString(frame.DeathText, appearance.timerFontSize + 4)
    yOffset = yOffset - 6

    frame.BarsHeader:ClearAllPoints()
    frame.BarsHeader:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 8, yOffset)
    frame.BarsHeader:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", -8, yOffset)
    frame.BarsHeader:SetJustifyH("LEFT")
    yOffset = yOffset - (appearance.timerFontSize + 6)

    local milestoneRowHeight = max(26, appearance.timerBarHeight + 12)
    frame.MilestoneRow:ClearAllPoints()
    frame.MilestoneRow:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 8, yOffset)
    frame.MilestoneRow:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", -8, yOffset)
    frame.MilestoneRow:SetHeight(milestoneRowHeight)
    yOffset = yOffset - (milestoneRowHeight + appearance.timerRowGap)

    local forcesRow = frame.ForcesRow
    local rowHeight = max(20, appearance.timerBarHeight + 10)
    forcesRow:ClearAllPoints()
    forcesRow:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 8, yOffset)
    forcesRow:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", -8, yOffset)
    forcesRow:SetHeight(rowHeight)
    forcesRow.barBackdrop:SetHeight(appearance.timerBarHeight + 2)
    forcesRow.barBackdrop:ClearAllPoints()
    forcesRow.barBackdrop:SetPoint("LEFT", forcesRow, "LEFT", 0, 0)
    forcesRow.barBackdrop:SetPoint("RIGHT", forcesRow, "RIGHT", 0, 0)
    forcesRow.barBackdrop:SetPoint("CENTER", forcesRow, "CENTER", 0, 0)
    forcesRow.label:ClearAllPoints()
    forcesRow.label:SetJustifyH("LEFT")
    forcesRow.label:SetPoint("LEFT", forcesRow.content, "LEFT", 8, 7)
    forcesRow.value:ClearAllPoints()
    forcesRow.value:SetJustifyH("RIGHT")
    forcesRow.value:SetPoint("RIGHT", forcesRow.content, "RIGHT", -8, 0)
    forcesRow.detail:ClearAllPoints()
    forcesRow.detail:SetJustifyH("LEFT")
    forcesRow.detail:SetPoint("LEFT", forcesRow.content, "LEFT", 8, -7)
    forcesRow.detail:SetPoint("RIGHT", forcesRow.content, "RIGHT", -50, -7)
    yOffset = yOffset - (rowHeight + appearance.timerRowGap)

    local availableWidth = max(120, (frame.ScrollChild:GetWidth() or 280) - 16)
    local xOffset = 0
    for _, key in ipairs({ "plusOne", "plusTwo", "plusThree" }) do
        local segment = frame.MilestoneRow.Segments[key]
        local fraction = segment.widthFraction or 0
        local segmentWidth = key == "plusThree" and max(24, availableWidth - xOffset) or
            max(24, floor(availableWidth * fraction))
        segment:ClearAllPoints()
        segment:SetPoint("TOPLEFT", frame.MilestoneRow, "TOPLEFT", xOffset, 0)
        segment:SetWidth(segmentWidth)
        segment:SetHeight(milestoneRowHeight)
        segment.backdrop:SetAllPoints(segment)
        segment.Label:ClearAllPoints()
        segment.Label:SetPoint("TOPLEFT", segment.content, "TOPLEFT", 6, -4)
        segment.Value:ClearAllPoints()
        segment.Value:SetPoint("CENTER", segment.content, "CENTER", 0, -4)
        xOffset = xOffset + segmentWidth + (key ~= "plusThree" and 2 or 0)
    end

    yOffset = yOffset - 2
    frame.CheckpointHeader:ClearAllPoints()
    frame.CheckpointHeader:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 8, yOffset)
    frame.CheckpointHeader:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", -8, yOffset)
    frame.CheckpointHeader:SetJustifyH("LEFT")
    yOffset = yOffset - (appearance.timerFontSize + 6)

    for index, row in ipairs(frame.CheckpointRows) do
        if index <= checkpointCount then
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 8, yOffset)
            row:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", -8, yOffset)
            row.Name:ClearAllPoints()
            row.Percent:ClearAllPoints()
            row.Time:ClearAllPoints()
            row.Name:SetJustifyH("LEFT")
            row.Name:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.Name:SetPoint("RIGHT", row.Percent, "LEFT", -10, 0)
            row.Percent:SetJustifyH("RIGHT")
            row.Percent:SetPoint("RIGHT", row.Time, "LEFT", -12, 0)
            row.Percent:SetWidth(54)
            row.Time:SetJustifyH("RIGHT")
            row.Time:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.Time:SetWidth(74)
            yOffset = yOffset - 18
        else
            row:Hide()
        end
    end

    frame.ScrollChild:SetHeight(max(1, abs(yOffset) + 12))
    self:UpdateFrameScrollState(frame)

    ApplyFontString(frame.Title, appearance.timerFontPath, appearance.timerFontSize + 2, outline,
        appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)
    ApplyFontString(frame.KeyText, appearance.timerFontPath, appearance.timerFontSize + 4, outline,
        appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)
    ApplyFontString(frame.AffixText, appearance.timerFontPath, max(10, appearance.timerFontSize - 1), outline,
        appearance.timerMutedTextColor[1], appearance.timerMutedTextColor[2], appearance.timerMutedTextColor[3], 1)
    ApplyFontString(frame.ElapsedText, appearance.timerFontPath, appearance.timerFontSize + 2, outline,
        appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)
    ApplyFontString(frame.DeathText, appearance.timerFontPath, appearance.timerFontSize, outline, 0.96, 0.36, 0.36, 1)
    ApplyFontString(frame.BarsHeader, appearance.timerFontPath, appearance.timerFontSize, outline,
        appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)
    ApplyFontString(frame.CheckpointHeader, appearance.timerFontPath, appearance.timerFontSize, outline,
        appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)

    ApplyFontString(forcesRow.label, appearance.timerFontPath, appearance.timerFontSize, outline,
        appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)
    ApplyFontString(forcesRow.value, appearance.timerFontPath, appearance.timerFontSize, outline,
        appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)
    ApplyFontString(forcesRow.detail, appearance.timerFontPath, max(10, appearance.timerFontSize - 2), outline,
        appearance.timerMutedTextColor[1], appearance.timerMutedTextColor[2], appearance.timerMutedTextColor[3], 1)

    for _, key in ipairs({ "plusOne", "plusTwo", "plusThree" }) do
        local segment = frame.MilestoneRow.Segments[key]
        ApplyFontString(segment.Label, appearance.timerFontPath, max(9, appearance.timerFontSize - 2), outline,
            appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1)
        ApplyFontString(segment.Value, appearance.timerFontPath, max(10, appearance.timerFontSize - 1), outline, 1, 1, 1,
            1)
    end

    for _, row in ipairs(frame.CheckpointRows) do
        local nameColor = row.IsCompleted and { 0.34, 0.92, 0.62, 1 } or
            { appearance.timerFontColor[1], appearance.timerFontColor[2], appearance.timerFontColor[3], 1 }
        local percentColor = row.FailedTarget and { 0.94, 0.34, 0.34, 1 } or
            row.IsCompleted and { 0.34, 0.92, 0.62, 1 } or { 0.96, 0.78, 0.24, 1 }
        local timeColor = row.IsCompleted and { 0.34, 0.92, 0.62, 1 } or
            { appearance.timerMutedTextColor[1], appearance.timerMutedTextColor[2], appearance.timerMutedTextColor[3], 1 }
        ApplyFontString(row.Name, appearance.timerFontPath, max(10, appearance.timerFontSize - 1), outline, nameColor[1],
            nameColor[2], nameColor[3], nameColor[4])
        ApplyFontString(row.Percent, appearance.timerFontPath, max(10, appearance.timerFontSize - 1), outline,
            percentColor[1], percentColor[2], percentColor[3], percentColor[4])
        ApplyFontString(row.Time, appearance.timerFontPath, max(10, appearance.timerFontSize - 1), outline, timeColor[1],
            timeColor[2], timeColor[3], timeColor[4])
    end
end

function MPT:TestMythicPlusTimerNotification(kind)
    local state = self:BuildMythicPlusTimerPreviewState()
    if kind == "checkpoint" then
        local checkpoint = state and state.checkpoints and state.checkpoints[1] or nil
        self:SendMythicPlusTimerNotification("checkpoint", state, checkpoint)
        return
    end

    self:SendMythicPlusTimerNotification(kind or "plusThree", state)
end

function MPT:DebugMythicPlusTimerBossAnimation()
    self:SetMythicPlusTimerPreviewEnabled(true)
    self:RefreshMythicPlusTimerFrame()
    local previewState = self:BuildMythicPlusTimerPreviewState()
    self:PlayMythicPlusTimerBossAnimation(previewState and previewState.completedCheckpointCount or 1)
end

function MPT:DebugMythicPlusTimerUpgradeAnimation()
    self:SetMythicPlusTimerPreviewEnabled(true)
    self:RefreshMythicPlusTimerFrame()
    self.debugMythicPlusTimerUpgradeIndex = ((tonumber(self.debugMythicPlusTimerUpgradeIndex) or 0) % 3) + 1
    local keys = { "plusOne", "plusTwo", "plusThree" }
    self:PlayMythicPlusTimerUpgradeAnimation(keys[self.debugMythicPlusTimerUpgradeIndex])
end

function MPT:ResetMythicPlusTimerPosition()
    local db = self:GetDB()
    db.timerX = -260
    db.timerY = -40
    if self.mythicPlusTimerFrame then
        self:RestoreFramePosition("timer", self.mythicPlusTimerFrame, -260, -40)
    end
end

function MPT:PersistFramePosition(kind, frame)
    local db = self:GetDB()
    if not frame then
        return
    end

    local centerX, centerY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not centerX or not centerY or not parentX or not parentY then
        return
    end

    local x = floor((centerX - parentX) + 0.5)
    local y = floor((centerY - parentY) + 0.5)
    if kind == "timer" then
        db.timerX = x
        db.timerY = y
    else
        db.interruptX = x
        db.interruptY = y
    end
end

function MPT:RestoreFramePosition(kind, frame, fallbackX, fallbackY)
    local db = self:GetDB()
    local x, y
    if kind == "timer" then
        x = db.timerX
        y = db.timerY
    else
        x = db.interruptX
        y = db.interruptY
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(x) or fallbackX, tonumber(y) or fallbackY)
end

function MPT:ApplyFrameLockStates()
    if self.interruptFrame then
        self.interruptFrame:EnableMouse(true)
        self:RefreshFrameControls("interrupt", self.interruptFrame)
    end

    if self.mythicPlusTimerFrame then
        self.mythicPlusTimerFrame:EnableMouse(true)
        self:RefreshFrameControls("timer", self.mythicPlusTimerFrame)
    end
end

function MPT:ResetInterruptTrackerPosition()
    local db = self:GetDB()
    db.interruptX = 260
    db.interruptY = -40
    if self.interruptFrame then
        self:RestoreFramePosition("interrupt", self.interruptFrame, 260, -40)
    end
end

function MPT:SetInterruptPreviewEnabled(enabled)
    self:EnsureRuntime()
    self.preview.interrupts = enabled == true
    self.preview.interruptsStartedAt = GetTime()
    self:RefreshInterruptRoster()
    self:RefreshInterruptFrame()
end

function MPT:SetMythicPlusTimerPreviewEnabled(enabled)
    self:EnsureRuntime()
    self.preview.mythicPlusTimer = enabled == true
    self.preview.mythicPlusTimerStartedAt = GetTime()
    self:RefreshMythicPlusTimerFrame()
end

function MPT:RefreshAllState()
    self:RefreshInterruptRoster()
    self:RefreshInterruptFrame()
    self:RefreshMythicPlusTimerFrame()
end

function MPT:PLAYER_ENTERING_WORLD()
    self:RegisterPartyWatchers()
    self:RegisterMobInterruptWatchers()
    self:RefreshAllState()
end

function MPT:GROUP_ROSTER_UPDATE()
    self:RegisterPartyWatchers()
    self:RefreshInterruptRoster()
    self:RefreshInterruptFrame()
end

function MPT:PLAYER_SPECIALIZATION_CHANGED(_, unit)
    if unit == "player" then
        self:RefreshInterruptRoster()
        self:RefreshInterruptFrame()
    end
end

function MPT:CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN()
    self:TryAutoSlotKeystone()
end

-- Scenario criteria changed: re-render the forces/objectives bar immediately
-- rather than waiting for the next 0.1s tick.  This is how WarpDeplete stays
-- up-to-date without relying on COMBAT_LOG (which is restricted in Midnight).
function MPT:SCENARIO_CRITERIA_UPDATE()
    if IsChallengeModeActive() and self.mythicPlusTimerFrame then
        self:RefreshMythicPlusTimerFrame()
    end
end

function MPT:SCENARIO_POI_UPDATE()
    if IsChallengeModeActive() and self.mythicPlusTimerFrame then
        self:RefreshMythicPlusTimerFrame()
    end
end

function MPT:CHALLENGE_MODE_START()
    -- Reset per-run tracking state so a new run starts clean.
    self:ResetMythicPlusTimerTracking()
    self:RefreshMythicPlusTimerFrame()
end

function MPT:CHALLENGE_MODE_COMPLETED()
    self:RefreshMythicPlusTimerFrame()
end

local function ResolveCountdownDuration(...)
    local duration = nil
    for index = 1, select("#", ...) do
        local rawValue = select(index, ...)
        local value = tonumber(rawValue)
        if value and value >= 1 and value <= 60 then
            duration = max(duration or 0, value)
        end
    end

    return duration
end

function MPT:START_PLAYER_COUNTDOWN(...)
    local duration = ResolveCountdownDuration(...)
    if not duration or duration < 1 or duration > 60 then
        return
    end

    self:LogDebugf(false, "external pull timer started duration=%s", tostring(duration))

    if self:GetDB().autoStartDungeon ~= true then
        return
    end

    if IsChallengeModeActive() or not HasSlottedKeystone() or not IsLeaderOrAssistant() then
        return
    end

    self.pendingStartTimerDuration = duration
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(duration, function()
            if self.pendingStartTimerDuration ~= duration then
                return
            end
            self.pendingStartTimerDuration = nil
            self:TryStartChallengeMode()
        end)
    end
end

function MPT:CANCEL_PLAYER_COUNTDOWN()
    if self.pendingStartTimerDuration then
        self:LogDebug("external pull timer cancelled", false)
    end
    self.pendingStartTimerDuration = nil
end

function MPT:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
    if not subEvent then
        return
    end

    if subEvent == "SPELL_INTERRUPT" or subEvent == "SPELL_CAST_SUCCESS" then
        if self:IsSourceInCurrentParty(sourceGUID, sourceName) or subEvent == "SPELL_INTERRUPT" then
            self:LogDebugf(false,
                "combatlog event=%s source=%s guid=%s spellID=%s dest=%s destGUID=%s",
                tostring(subEvent),
                tostring(sourceName),
                tostring(sourceGUID),
                tostring(spellID),
                tostring(destName),
                tostring(destGUID)
            )
        end
        self:HandlePossibleInterrupt(subEvent, sourceGUID, sourceName, spellID)
        return
    end

    if subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED" then
        self:HandleUnitDeath(destGUID, destName)
    end
end

function MPT:HandleObservedPartyCastEvent(ownerUnit, castUnit, source, ...)
    if not (ownerUnit and UnitExists(ownerUnit)) then
        return false
    end

    local ownerName = GetFullUnitName(ownerUnit)
    if not ownerName then
        return false
    end

    local member = self:EnsureInterruptMemberForUnit(ownerUnit, ownerName)
    if not member then
        return false
    end

    local now = GetTime()
    local observedSpellID = ResolveObservedInterruptSpellIDFromArgs(...)
    if source == "sent" then
        self:RecordRecentPartyCast(member, observedSpellID, source)
        return observedSpellID ~= nil
    end

    if observedSpellID and SUPPORTED_INTERRUPT_SPELLS[observedSpellID] then
        self:RecordRecentPartyCast(member, observedSpellID, source)
        self:ApplyInterruptToMember(member, "SPELL_CAST_SUCCESS", ownerName, observedSpellID, true)
        return true
    end

    self:RecordRecentPartyCast(member, observedSpellID, source)
    return false
end

function MPT:HandleMobInterrupted(interruptedUnit)
    local now = GetTime()
    if self:IsDuplicateObservedInterrupt(interruptedUnit, now) then
        self:LogDebugf(false, "interrupt dedupe unit-event unit=%s", SafeDebugString(interruptedUnit))
        return false
    end

    local member, record = self:GetRecentPartyCastMember(now, 1.0)
    if not member then
        self:LogDebugf(false, "interrupt drop event=UNIT_SPELLCAST_INTERRUPTED unit=%s reason=no-recent-cast",
            SafeDebugString(interruptedUnit))
        return false
    end

    self:LogDebugf(false,
        "interrupt correlate unit-event unit=%s member=%s age=%.3f spellID=%s",
        SafeDebugString(interruptedUnit),
        tostring(member.name),
        now - (tonumber(record and record.at) or now),
        tostring(record and record.spellID)
    )

    if tonumber(member.readyAt) and member.readyAt > now then
        self:ClearRecentPartyCast(member.name)
        return true
    end

    self:ClearRecentPartyCast(member.name)
    return self:ApplyInterruptToMember(member, "SPELL_INTERRUPT", member.name, nil, false)
end

function MPT:INSPECT_READY(_, guid)
    if not guid or not self.activeInspectUnit or not UnitExists(self.activeInspectUnit) then
        return
    end

    if UnitGUID(self.activeInspectUnit) ~= guid then
        return
    end

    local member = self.interruptMembers[self.activeInspectName or ""]
    local specID = type(GetInspectSpecialization) == "function" and GetInspectSpecialization(self.activeInspectUnit) or
        nil
    if member and type(specID) == "number" and specID > 0 then
        member.specID = specID
        self:ApplyInterruptSpellData(member)
    end

    self.activeInspectUnit = nil
    self.activeInspectName = nil
    if _G.ClearInspectPlayer then
        _G.ClearInspectPlayer()
    end

    self:ProcessInspectQueue()
    self:RefreshInterruptFrame()
end

function MPT:TryResolvePendingInspect()
    if not self.activeInspectUnit or not UnitExists(self.activeInspectUnit) then
        return
    end

    local member = self.interruptMembers[self.activeInspectName or ""]
    local specID = type(GetInspectSpecialization) == "function" and GetInspectSpecialization(self.activeInspectUnit) or
        nil
    if member and type(specID) == "number" and specID > 0 then
        member.specID = specID
        self:ApplyInterruptSpellData(member)
        self:LogDebugf(false, "inspect resolved member=%s specID=%d", tostring(member.name), specID)
        self.activeInspectUnit = nil
        self.activeInspectName = nil
        self.activeInspectRequestedAt = nil
        if _G.ClearInspectPlayer then
            _G.ClearInspectPlayer()
        end
        self:ProcessInspectQueue()
        self:RefreshInterruptFrame()
        return
    end

    if self.activeInspectRequestedAt and (GetTime() - self.activeInspectRequestedAt) >= 2 then
        self:LogDebugf(false, "inspect timeout member=%s", tostring(self.activeInspectName))
        self.activeInspectUnit = nil
        self.activeInspectName = nil
        self.activeInspectRequestedAt = nil
        if _G.ClearInspectPlayer then
            _G.ClearInspectPlayer()
        end
        self:ProcessInspectQueue()
    end
end

function MPT:TryAutoSlotKeystone()
    if self:GetDB().autoSlotKeystone == false then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local challengesFrame = _G.ChallengesKeystoneFrame
    if not (challengesFrame and challengesFrame.IsShown and challengesFrame:IsShown()) then
        return
    end

    local ownedMapID = GetOwnedKeystoneMapID()
    local instanceID = GetCurrentInstanceID()
    if ownedMapID and instanceID and ownedMapID ~= instanceID then
        return
    end

    if HasSlottedKeystone() then
        return
    end

    if not (C_ChallengeMode and type(C_ChallengeMode.SlotKeystone) == "function") then
        return
    end

    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" or type(C_Container.PickupContainerItem) ~= "function" then
        return
    end

    local maxBag = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
    for bagIndex = _G.BACKPACK_CONTAINER or 0, maxBag do
        local numSlots = C_Container.GetContainerNumSlots(bagIndex)
        for slotIndex = 1, tonumber(numSlots) or 0 do
            local itemID = C_Container.GetContainerItemID(bagIndex, slotIndex)
            local itemLink = C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bagIndex, slotIndex) or
                nil
            local isKeystone = MYTHIC_KEYSTONE_ITEM_IDS[itemID or 0] == true or
                (type(itemLink) == "string" and itemLink:find("|Hkeystone:", 1, true) ~= nil)
            if isKeystone then
                self:LogDebugf(false, "attempting keystone pickup bag=%d slot=%d", bagIndex, slotIndex)
                C_Container.PickupContainerItem(bagIndex, slotIndex)
                C_ChallengeMode.SlotKeystone()
                if HasSlottedKeystone() then
                    self:LogDebug("keystone auto-slot succeeded via PickupContainerItem()+SlotKeystone()", false)
                else
                    self:LogDebug("keystone auto-slot pickup attempt did not slot immediately", false)
                end
                return
            end
        end
    end
end

function MPT:TryStartChallengeMode()
    if self:GetDB().autoStartDungeon ~= true then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if IsChallengeModeActive() or not HasSlottedKeystone() or not IsLeaderOrAssistant() then
        return
    end

    if C_ChallengeMode and type(C_ChallengeMode.StartChallengeMode) == "function" then
        self:LogDebug("attempting challenge start", false)
        C_ChallengeMode.StartChallengeMode()
    end
end

function MPT:GetPlayerSpecID()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return nil
    end

    local specializationIndex = GetSpecialization()
    if not specializationIndex then
        return nil
    end

    local specID = GetSpecializationInfo(specializationIndex)
    return type(specID) == "number" and specID > 0 and specID or nil
end

function MPT:ApplyInterruptSpellData(member)
    if not member then
        return
    end

    if member.specID and SPEC_WITHOUT_INTERRUPT[member.specID] then
        member.spellID = nil
        member.cooldown = nil
        member.spellIcon = nil
        return
    end

    local spellData = member.specID and SPEC_INTERRUPT_DATA[member.specID] or nil
    if not spellData then
        spellData = CLASS_INTERRUPT_DATA[member.classToken or ""]
    end

    if not spellData then
        if member.learnedFromCombatLog and member.spellID and SUPPORTED_INTERRUPT_SPELLS[member.spellID] then
            member.cooldown = GetInterruptCooldownForSpell(member.spellID, member.cooldown)
            member.spellIcon = C_Spell and type(C_Spell.GetSpellTexture) == "function" and
                C_Spell.GetSpellTexture(member.spellID) or
                member.spellIcon or select(3, GetSpellInfo(member.spellID))
            return
        end

        member.spellID = nil
        member.cooldown = nil
        member.spellIcon = nil
        return
    end

    if member.unit == "player" and not PlayerKnowsSpell(spellData.spellID) then
        member.spellID = nil
        member.cooldown = nil
        member.spellIcon = nil
        return
    end

    member.spellID = spellData.spellID
    member.cooldown = spellData.cooldown
    member.spellIcon = C_Spell and type(C_Spell.GetSpellTexture) == "function" and
        C_Spell.GetSpellTexture(spellData.spellID) or
        select(3, GetSpellInfo(spellData.spellID))
    member.learnedFromCombatLog = nil
end

function MPT:NeedsInspectForMember(member)
    if not member or member.unit == "player" then
        return false
    end

    if member.specID and member.specID > 0 then
        return false
    end

    return member.classToken == "DRUID" or member.classToken == "PRIEST"
end

function MPT:QueueInspect(member)
    if not member or not member.unit or not UnitExists(member.unit) or type(NotifyInspect) ~= "function" then
        return
    end

    for _, queuedName in ipairs(self.inspectQueue) do
        if queuedName == member.name then
            return
        end
    end

    tinsert(self.inspectQueue, member.name)
end

function MPT:ProcessInspectQueue()
    if self.activeInspectUnit or InCombatLockdown and InCombatLockdown() then
        return
    end

    while #self.inspectQueue > 0 do
        local name = table.remove(self.inspectQueue, 1)
        local member = self.interruptMembers[name or ""]
        if member and member.unit and UnitExists(member.unit) then
            self.activeInspectUnit = member.unit
            self.activeInspectName = member.name
            self.activeInspectRequestedAt = GetTime()
            self:LogDebugf(false, "inspect request unit=%s member=%s", tostring(member.unit), tostring(member.name))
            NotifyInspect(member.unit)
            return
        end
    end
end

function MPT:PollDeathState()
    if not IsChallengeModeActive() then
        self.partyDeathState = {}
        return
    end

    for _, member in pairs(self.interruptMembers or {}) do
        if member.unit and UnitExists(member.unit) then
            local dead = UnitIsDeadOrGhost(member.unit) == true
            local deathKey = member.guid or member.name
            local wasDead = self.partyDeathState[deathKey] == true
            if dead and not wasDead then
                self.partyDeathState[deathKey] = true
                self:HandleUnitDeath(member.guid, GetShortName(member.name))
            elseif not dead and wasDead then
                self.partyDeathState[deathKey] = false
            end
        end
    end
end

function MPT:PollPlayerSpecChanges(now)
    if (now - (self.lastRosterRefreshAt or 0)) < 1.0 then
        return
    end

    self.lastRosterRefreshAt = now
    local playerName = GetFullUnitName("player")
    local playerMember = playerName and self.interruptMembers[playerName] or nil
    local currentSpecID = self:GetPlayerSpecID()
    if playerMember and currentSpecID and playerMember.specID ~= currentSpecID then
        self:LogDebugf(false, "player spec refresh old=%s new=%s", tostring(playerMember.specID), tostring(currentSpecID))
        self:RefreshInterruptRoster()
        self:RefreshInterruptFrame()
    end
end

function MPT:BuildInterruptRoster()
    local roster = {}
    local partySize = type(GetNumSubgroupMembers) == "function" and GetNumSubgroupMembers() or 0
    local units = { "player" }
    for index = 1, partySize do
        units[#units + 1] = "party" .. index
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = GetFullUnitName(unit)
            local _, classToken = UnitClass(unit)
            if name then
                local member = self.interruptMembers[name] or {
                    name = name,
                    unit = unit,
                    role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE",
                    classToken = classToken,
                    readyAt = 0,
                    count = 0,
                }
                member.unit = unit
                member.role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or member.role or "NONE"
                member.classToken = classToken or member.classToken
                member.guid = UnitGUID(unit)
                if unit == "player" then
                    member.specID = self:GetPlayerSpecID()
                end
                self:ApplyInterruptSpellData(member)
                roster[name] = member
            end
        end
    end

    self.interruptMembers = roster
    self.interruptOrder = {}
    for name, member in pairs(roster) do
        if member.spellID then
            tinsert(self.interruptOrder, name)
            if self:NeedsInspectForMember(member) then
                self:QueueInspect(member)
            end
        end
    end

    tsort(self.interruptOrder, function(leftName, rightName)
        local left = roster[leftName]
        local right = roster[rightName]
        local leftOrder = ROLE_ORDER[left and left.role or "NONE"] or 99
        local rightOrder = ROLE_ORDER[right and right.role or "NONE"] or 99
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end

        return GetShortName(leftName) < GetShortName(rightName)
    end)

    self:ProcessInspectQueue()
end

function MPT:RefreshInterruptRoster()
    self:BuildInterruptRoster()
end

function MPT:ResolvePartyUnitBySource(sourceGUID, sourceName)
    local partySize = type(GetNumSubgroupMembers) == "function" and GetNumSubgroupMembers() or 0
    local units = { "player" }
    for index = 1, partySize do
        units[#units + 1] = "party" .. index
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local unitGUID = UnitGUID(unit)
            if SafeStringsEqual(sourceGUID, unitGUID) then
                self:LogDebugf(false, "interrupt resolve unit=%s via=guid source=%s guid=%s", tostring(unit),
                    tostring(sourceName),
                    tostring(sourceGUID))
                return unit
            end

            local fullName = GetFullUnitName(unit)
            local shortName = fullName and GetShortName(fullName) or nil
            local rawName = type(UnitName) == "function" and UnitName(unit) or nil
            if SafeStringsEqual(sourceName, fullName) or SafeStringsEqual(sourceName, shortName) or SafeStringsEqual(sourceName, rawName) then
                self:LogDebugf(false, "interrupt resolve unit=%s via=name source=%s guid=%s", tostring(unit),
                    tostring(sourceName),
                    tostring(sourceGUID))
                return unit
            end
        end
    end

    if sourceGUID or sourceName then
        self:LogDebugf(false, "interrupt resolve failed source=%s guid=%s", tostring(sourceName), tostring(sourceGUID))
    end

    return nil
end

function MPT:EnsureInterruptMemberForUnit(unit, fallbackName)
    if not (unit and UnitExists(unit)) then
        return nil
    end

    local name = GetFullUnitName(unit) or fallbackName
    if not name then
        return nil
    end

    local member = self.interruptMembers[name]
    if not member then
        local guid = UnitGUID(unit)
        for _, existingMember in pairs(self.interruptMembers or {}) do
            if (guid and existingMember.guid == guid) or existingMember.name == name or GetShortName(existingMember.name) == name then
                member = existingMember
                break
            end
        end
    end

    local _, classToken = UnitClass(unit)
    if not member then
        member = {
            name = name,
            unit = unit,
            role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE",
            classToken = classToken,
            readyAt = 0,
            count = 0,
        }
        self.interruptMembers[name] = member
    end

    member.name = name
    member.unit = unit
    member.guid = UnitGUID(unit)
    member.role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or member.role or "NONE"
    member.classToken = classToken or member.classToken
    if unit == "player" then
        member.specID = self:GetPlayerSpecID()
    end

    return member
end

function MPT:IsSourceInCurrentParty(sourceGUID, sourceName)
    if not sourceGUID and not sourceName then
        return false
    end

    for _, member in pairs(self.interruptMembers or {}) do
        if SafeStringsEqual(sourceGUID, member.guid) then
            return true
        end
        if SafeStringsEqual(sourceName, member.name) then
            return true
        end
        if SafeStringsEqual(sourceName, GetShortName(member.name)) then
            return true
        end
    end

    return false
end

function MPT:GetMemberBySource(sourceGUID, sourceName)
    for _, member in pairs(self.interruptMembers or {}) do
        if SafeStringsEqual(sourceGUID, member.guid) then
            self:LogDebug(
                format("interrupt member match=%s via=guid guid=%s", tostring(member.name), tostring(sourceGUID)), false)
            return member
        end
    end

    for _, member in pairs(self.interruptMembers or {}) do
        if SafeStringsEqual(sourceName, member.name) or SafeStringsEqual(sourceName, GetShortName(member.name)) then
            self:LogDebug(
                format("interrupt member match=%s via=name source=%s", tostring(member.name), tostring(sourceName)),
                false)
            return member
        end
    end

    local unit = self:ResolvePartyUnitBySource(sourceGUID, sourceName)
    if unit then
        local member = self:EnsureInterruptMemberForUnit(unit, sourceName)
        self:LogDebug(
            format("interrupt member match=%s via=unit unit=%s", tostring(member and member.name), tostring(unit)), false)
        return member
    end

    return nil
end

function MPT:RecordRecentPartyCast(member, spellID, source)
    if not (member and member.name) then
        return
    end

    self.recentPartyCasts[member.name] = {
        name = member.name,
        spellID = tonumber(spellID) or 0,
        at = GetTime(),
        source = source,
    }
end

function MPT:ClearRecentPartyCast(name)
    if name then
        self.recentPartyCasts[name] = nil
    end
end

function MPT:GetRecentPartyCastMember(now, maxAge)
    local bestMember = nil
    local bestRecord = nil
    local bestAge = tonumber(maxAge) or RECENT_INTERRUPT_CAST_WINDOW

    for name, record in pairs(self.recentPartyCasts or {}) do
        local recordAt = tonumber(record and record.at) or 0
        local age = now - recordAt
        if age < 0 or age > bestAge then
            self.recentPartyCasts[name] = nil
        elseif not bestRecord or recordAt > (tonumber(bestRecord.at) or 0) then
            bestMember = self.interruptMembers and self.interruptMembers[name] or nil
            bestRecord = record
        end
    end

    return bestMember, bestRecord
end

function MPT:ApplyInterruptToMember(member, subEvent, sourceName, spellID, isSupportedInterruptSpell)
    if subEvent == "SPELL_INTERRUPT" and not isSupportedInterruptSpell and not member.spellID then
        self:LogDebugf(false, "interrupt ignored member=%s spellID=%s reason=no tracked spell", tostring(member.name),
            tostring(spellID))
        return false
    end

    local now = GetTime()
    local trackedSpellID = isSupportedInterruptSpell and spellID or member.spellID
    local cooldown = GetInterruptCooldownForSpell(trackedSpellID, member.cooldown)

    self:LogDebugf(false,
        "interrupt apply event=%s member=%s source=%s rawSpellID=%s trackedSpellID=%s cooldown=%.1f readyAt=%.1f supported=%s",
        tostring(subEvent),
        tostring(member.name),
        tostring(sourceName),
        tostring(spellID),
        tostring(trackedSpellID),
        tonumber(cooldown) or 0,
        now + cooldown,
        tostring(isSupportedInterruptSpell)
    )

    -- If this is a recognised interrupt spell that differs from the member's
    -- registered primary, track it as a separate secondary cooldown instead
    -- of overwriting the primary.
    if isSupportedInterruptSpell and member.spellID and member.spellID ~= spellID then
        local ss = member.secondSpell
        if not ss then
            ss = {}
            member.secondSpell = ss
        end
        local sCooldown      = GetInterruptCooldownForSpell(spellID, ss.cooldown)
        ss.spellID           = spellID
        ss.cooldown          = sCooldown
        ss.readyAt           = now + sCooldown
        ss.count             = (ss.count or 0) + 1
        ss.lastCastAt        = now
        ss.spellIcon         = C_Spell and type(C_Spell.GetSpellTexture) == "function"
            and C_Spell.GetSpellTexture(spellID) or ss.spellIcon
        local alreadyTracked = false
        for _, trackedName in ipairs(self.interruptOrder or {}) do
            if trackedName == member.name then
                alreadyTracked = true
                break
            end
        end
        if not alreadyTracked then
            tinsert(self.interruptOrder, member.name)
        end
        self:RefreshInterruptFrame()
        return true
    end

    if isSupportedInterruptSpell then
        member.spellID = spellID
    end
    member.readyAt = now + cooldown
    member.count = (member.count or 0) + 1
    member.lastCastAt = now
    member.learnedFromCombatLog = member.learnedFromCombatLog or isSupportedInterruptSpell
    if isSupportedInterruptSpell then
        member.spellIcon = C_Spell and type(C_Spell.GetSpellTexture) == "function" and C_Spell.GetSpellTexture(spellID) or
            member.spellIcon
    end

    local alreadyTracked = false
    for _, trackedName in ipairs(self.interruptOrder or {}) do
        if trackedName == member.name then
            alreadyTracked = true
            break
        end
    end
    if not alreadyTracked then
        tinsert(self.interruptOrder, member.name)
    end

    self:RefreshInterruptFrame()
    return true
end

function MPT:HookNameplateCastbarInstance(castbar)
    if not castbar or castbar.TwichUIObservedInterruptHook == true then
        return false
    end

    local original = castbar.PostCastInterrupted
    if type(original) ~= "function" then
        return false
    end

    castbar.PostCastInterrupted = function(frameSelf, unit, interruptedSpellID, interruptedByGUID, ...)
        original(frameSelf, unit, interruptedSpellID, interruptedByGUID, ...)
        self:HandleObservedInterruptFromCastbar("ElvUINameplatesInstance", frameSelf, unit, interruptedSpellID,
            interruptedByGUID)
    end
    castbar.TwichUIObservedInterruptHook = true
    return true
end

function MPT:HookExistingNameplateCastbars(nameplatesModule)
    local hookedAny = false

    if nameplatesModule and type(nameplatesModule.PlateGUID) == "table" then
        for _, plate in pairs(nameplatesModule.PlateGUID) do
            if self:HookNameplateCastbarInstance(plate and plate.Castbar) then
                hookedAny = true
            end
        end
    end

    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local plates = C_NamePlate.GetNamePlates()
        for _, plateFrame in ipairs(plates or {}) do
            local castbar = plateFrame and
                ((plateFrame.UnitFrame and plateFrame.UnitFrame.Castbar) or plateFrame.Castbar) or nil
            if self:HookNameplateCastbarInstance(castbar) then
                hookedAny = true
            end
        end
    end

    if hookedAny then
        self.hookedElvUINameplatesInstances = true
    end
end

function MPT:GetInferredInterruptMember(now)
    local bestMember = nil
    local bestPriority = math.huge
    local bestLastCastAt = math.huge
    local bestReadyAt = math.huge

    for _, member in pairs(self.interruptMembers or {}) do
        if member.spellID and member.unit and UnitExists(member.unit) and not UnitIsDeadOrGhost(member.unit) then
            local readyAt = tonumber(member.readyAt) or 0
            if readyAt <= (now + 0.25) then
                local priority = member.unit == "player" and 2 or 1
                local lastCastAt = tonumber(member.lastCastAt) or 0
                if not bestMember
                    or priority < bestPriority
                    or (priority == bestPriority and lastCastAt < bestLastCastAt)
                    or (priority == bestPriority and lastCastAt == bestLastCastAt and readyAt < bestReadyAt) then
                    bestMember = member
                    bestPriority = priority
                    bestLastCastAt = lastCastAt
                    bestReadyAt = readyAt
                end
            end
        end
    end

    return bestMember
end

function MPT:GetSingleReadyInterruptMember(now)
    local foundMember = nil
    local foundCount = 0

    for _, member in pairs(self.interruptMembers or {}) do
        if member.spellID and member.unit and UnitExists(member.unit) and not UnitIsDeadOrGhost(member.unit) then
            local readyAt = tonumber(member.readyAt) or 0
            if readyAt <= (now + 0.25) then
                foundCount = foundCount + 1
                foundMember = member
                if foundCount > 1 then
                    return nil, foundCount
                end
            end
        end
    end

    return foundMember, foundCount
end

function MPT:IsDuplicateObservedInterrupt(interruptedUnit, now)
    local key = IsUsablePlainString(interruptedUnit) and interruptedUnit or "<opaque>"
    local lastAt = tonumber(self.lastObservedInterruptAt[key]) or 0
    if lastAt > 0 and (now - lastAt) <= OBSERVED_INTERRUPT_DEDUPE_WINDOW then
        return true
    end

    self.lastObservedInterruptAt[key] = now
    return false
end

function MPT:GetRecentInterruptCaster(now, maxAge)
    local bestMember = nil
    local bestLastCastAt = 0
    local ageLimit = tonumber(maxAge) or 1.0

    for _, member in pairs(self.interruptMembers or {}) do
        local lastCastAt = tonumber(member and member.lastCastAt) or 0
        if member and member.spellID and lastCastAt > 0 and (now - lastCastAt) <= ageLimit then
            if lastCastAt > bestLastCastAt then
                bestMember = member
                bestLastCastAt = lastCastAt
            end
        end
    end

    return bestMember, bestLastCastAt
end

function MPT:HandleObservedInterruptFromCastbar(host, castbar, interruptedUnit, interruptedSpellID, interruptedByGUID)
    if not interruptedByGUID then
        return
    end

    local now = GetTime()
    if self:IsDuplicateObservedInterrupt(interruptedUnit, now) then
        self:LogDebugf(false,
            "interrupt dedupe host=%s unit=%s",
            SafeDebugString(host),
            SafeDebugString(interruptedUnit)
        )
        return
    end

    local sourceUnit = nil
    local rawToken = nil
    if type(UnitTokenFromGUID) == "function" then
        local ok, token = pcall(UnitTokenFromGUID, interruptedByGUID)
        if ok then
            rawToken = token
        end
        if ok and IsUsablePlainString(token) and UnitExists(token) then
            sourceUnit = token
        end
    end

    local sourceName = sourceUnit and GetFullUnitName(sourceUnit) or nil
    local castbarText = castbar and castbar.Text and type(castbar.Text.GetText) == "function" and castbar.Text:GetText() or
        nil
    if not sourceName and type(castbarText) == "string" and IsUsablePlainString(castbarText) then
        local bracketedName = castbarText:match("%[([^%]]+)%]%s*$")
        if IsUsablePlainString(bracketedName) then
            sourceName = bracketedName
        end
    end

    self:LogDebugf(false,
        "observed interrupt host=%s unit=%s interruptedSpellID=%s sourceGUID=%s rawToken=%s sourceUnit=%s source=%s text=%s",
        SafeDebugString(host),
        SafeDebugString(interruptedUnit),
        SafeDebugString(interruptedSpellID),
        SafeDebugString(interruptedByGUID),
        SafeDebugString(rawToken),
        SafeDebugString(sourceUnit),
        SafeDebugString(sourceName),
        SafeDebugString(castbarText)
    )

    local member = sourceUnit and self:EnsureInterruptMemberForUnit(sourceUnit, sourceName) or
        self:GetMemberBySource(nil, sourceName)
    local resolutionMethod = sourceUnit and "source-unit" or (sourceName and "castbar-text" or nil)
    if not member then
        local recentMember, recentRecord = self:GetRecentPartyCastMember(now, RECENT_INTERRUPT_CAST_WINDOW)
        if recentMember and recentRecord then
            member = recentMember
            resolutionMethod = "recent-cast"
            sourceName = sourceName or recentMember.name
            self:LogDebugf(false,
                "interrupt correlate recent member=%s age=%.3f spellID=%s",
                tostring(recentMember.name),
                now - (tonumber(recentRecord.at) or now),
                tostring(recentRecord.spellID)
            )
        end
    end

    if not member then
        local singleReadyMember, readyCount = self:GetSingleReadyInterruptMember(now)
        if singleReadyMember then
            member = singleReadyMember
            resolutionMethod = "single-ready"
            sourceName = sourceName or singleReadyMember.name
        else
            self:LogDebugf(false,
                "interrupt opaque drop reason=ambiguous-ready readyCount=%s",
                tostring(readyCount or 0)
            )
        end
    end

    if not member then
        self:LogDebugf(false,
            "interrupt drop event=SPELL_INTERRUPT unit=%s source=%s reason=no-member",
            SafeDebugString(sourceUnit),
            SafeDebugString(sourceName)
        )
        return
    end

    self:LogDebugf(false,
        "interrupt member match=%s via=%s unit=%s source=%s",
        tostring(member.name),
        tostring(resolutionMethod or "unknown"),
        SafeDebugString(sourceUnit),
        SafeDebugString(sourceName)
    )

    if resolutionMethod == "recent-cast" and tonumber(member.readyAt) and member.readyAt > now then
        self:ClearRecentPartyCast(member.name)
        self:LogDebugf(false,
            "interrupt confirm member=%s via=recent-cast existingReadyAt=%.1f",
            tostring(member.name),
            tonumber(member.readyAt) or 0
        )
        return
    end

    self:ClearRecentPartyCast(member.name)
    self:ApplyInterruptToMember(member, "SPELL_INTERRUPT", sourceName, nil, false)
end

function MPT:HandlePossibleInterrupt(subEvent, sourceGUID, sourceName, spellID)
    local isSupportedInterruptSpell = SUPPORTED_INTERRUPT_SPELLS[spellID or 0] == true

    local member = self:GetMemberBySource(sourceGUID, sourceName)
    if subEvent == "SPELL_CAST_SUCCESS" and member then
        self:RecordRecentPartyCast(member, spellID, "combatlog_success")
    end

    if subEvent ~= "SPELL_INTERRUPT" and not isSupportedInterruptSpell then
        return
    end

    if not member then
        self:LogDebug(
            format("interrupt drop event=%s source=%s guid=%s spellID=%s reason=no-member", tostring(subEvent),
                tostring(sourceName), tostring(sourceGUID), tostring(spellID)), false)
        return
    end

    self:ApplyInterruptToMember(member, subEvent, sourceName, spellID, isSupportedInterruptSpell)
end

function MPT:ShouldSuppressWipeSpam(now)
    if self:GetDB().suppressWipeSpam == false then
        return false
    end

    local recent = {}
    for _, timestamp in ipairs(self.deathWindow) do
        if now - timestamp <= 4 then
            recent[#recent + 1] = timestamp
        end
    end
    self.deathWindow = recent

    local trackedCount = 0
    for _ in pairs(self.interruptMembers or {}) do
        trackedCount = trackedCount + 1
    end

    return #recent >= max(3, trackedCount - 1)
end

function MPT:ShouldNotifyDeath(member)
    if not member then
        return false
    end

    local db = self:GetDB()
    if db.deathNotificationEnabled == false then
        return false
    end

    if member.unit == "player" then
        return db.notifySelfDeaths == true
    end

    if member.role == "TANK" then
        return db.notifyTankDeaths ~= false
    end
    if member.role == "HEALER" then
        return db.notifyHealerDeaths ~= false
    end
    return db.notifyDPSDeaths ~= false
end

function MPT:HandleUnitDeath(destGUID, destName)
    if not IsChallengeModeActive() then
        return
    end

    local member = self:GetMemberBySource(destGUID, destName)
    if not member then
        return
    end

    local now = GetTime()
    local dedupeKey = member.guid or member.name
    if self.lastSeenDeaths[dedupeKey] and now - self.lastSeenDeaths[dedupeKey] < 0.5 then
        return
    end
    self.lastSeenDeaths[dedupeKey] = now

    self.deathCount = (self.deathCount or 0) + 1
    tinsert(self.deathWindow, now)
    if self:ShouldSuppressWipeSpam(now) then
        self:LogDebugf(false, "death suppressed name=%s total=%d", tostring(destName), self.deathCount)
        return
    end

    if self:ShouldNotifyDeath(member) then
        self:SendDeathNotification(member, self.deathCount)
    end
end

function MPT:BuildDeathNotification(member, totalDeaths)
    local roleLabel = ROLE_LABELS[member.role or "NONE"] or ROLE_LABELS.NONE
    local title = BuildColoredName(GetShortName(member.name), member.classToken)
    local detail = format("%s down. Total deaths: %d", roleLabel, totalDeaths or 0)
    return {
        status = "MYTHIC+ DEATH",
        title = title,
        detail = detail,
        icon = DUNGEON_DEATH_NOTIFICATION_ICON,
        color = ALERT_COLOR,
    }
end

function MPT:SendDeathNotification(member, totalDeaths)
    local notification = self:BuildDeathNotification(member, totalDeaths)
    ---@type TwichUI_MythicPlusAlertNotificationWidget
    local widget = CreateWidget(AceGUI, "TwichUI_MythicPlusAlertNotification")
    widget:SetAlert(notification.status, notification.title, notification.detail, notification.icon, notification.color)

    self:LogDebugf(false, "death notification name=%s total=%d", tostring(member.name), tonumber(totalDeaths) or 0)

    if NotificationModule and type(NotificationModule.TWICH_NOTIFICATION) == "function" then
        NotificationModule:TWICH_NOTIFICATION("TWICH_NOTIFICATION", widget, {
            soundKey = self:GetDB().deathNotificationSound,
            displayDuration = self:GetDB().deathNotificationDisplayTime or 8,
        })
    end
end

function MPT:TestDeathNotification()
    local member = {
        name = GetFullUnitName("player") or "Player",
        classToken = select(2, UnitClass("player")),
        role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "DAMAGER",
        unit = "player",
    }
    self:SendDeathNotification(member, (self.deathCount or 0) + 1)
end

if DebugConsole and DebugConsole.RegisterSource then
    DebugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
        title = "Mythic+ Tools",
        order = 30,
        aliases = { "mythicplus", "mythic", "mpt", "keystone" },
        maxLines = DEBUG_LOG_LIMIT,
        isEnabled = function()
            local options = GetOptions()
            return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
        end,
        buildReport = function()
            return MPT:BuildDebugReport()
        end,
    })
end

function MPT:GetInterruptRowState(member, now)
    -- Reuse a per-member scratch table so no allocation occurs after the first
    -- call per member.  The table is always fully written before it is read.
    local state = member._stateScratch
    if not state then
        state = {}
        member._stateScratch = state
    end

    if self.preview.interrupts then
        local index = member.previewIndex or 1
        local elapsed = now - (self.preview.interruptsStartedAt or now)
        local base = (index - 1) * 3
        local cycle = (elapsed + base) % 18
        local remaining = max(0, 12 - cycle)
        if remaining <= 0 then
            state.valueText = "Ready"
            state.color     = READY_COLOR
            state.progress  = 1
            state.priority  = 1
            state.remaining = 0
            state.isReady   = true
            return state
        end
        state.valueText = FormatDuration(remaining, true)
        state.color     = ACTIVE_COLOR
        state.progress  = 1 - (remaining / 12)
        state.priority  = 3
        state.remaining = remaining
        state.isReady   = nil
        return state
    end

    if member.unit and UnitExists(member.unit) and UnitIsDeadOrGhost(member.unit) then
        state.valueText = "Dead"
        state.color     = ALERT_COLOR
        state.progress  = 0
        state.priority  = 2
        state.remaining = 0
        state.isReady   = false
        return state
    end

    local remaining = max(0, (member.readyAt or 0) - now)
    if remaining <= 0 then
        local readySound = self:GetDB().interruptReadySound
        if readySound and readySound ~= MUTED_SOUND_VALUE then
            local readyKey = member.name .. ":" .. tostring(member.spellID or 0)
            local lastPlayedAt = self.lastReadySoundAt[readyKey] or 0
            if member.lastCastAt and lastPlayedAt < member.lastCastAt then
                self.lastReadySoundAt[readyKey] = now
                PlayConfiguredSound(readySound)
            end
        end
        state.valueText = "Ready"
        state.color     = READY_COLOR
        state.progress  = 1
        state.priority  = 1
        state.remaining = 0
        state.isReady   = true
        return state
    end

    local totalCooldown = max(1, member.cooldown or remaining)
    state.valueText     = FormatDuration(remaining, true)
    state.color         = ACTIVE_COLOR
    state.progress      = 1 - (remaining / totalCooldown)
    state.priority      = 3
    state.remaining     = remaining
    state.isReady       = nil
    return state
end

function MPT:ShowInterruptRowTooltip(row)
    if not (row and row.member and row.member.spellID and GameTooltip) then
        return
    end

    local member = row.member
    local spellName = (C_Spell and type(C_Spell.GetSpellName) == "function" and C_Spell.GetSpellName(member.spellID)) or
        GetSpellInfo(member.spellID) or "Interrupt"
    local classIcon = GetClassTooltipIcon(member.classToken, 16)
    local className = GetClassDisplayName(member.classToken)
    local shortName = GetShortName(member.name)
    local red, green, blue = GetClassColor(member.classToken)

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(BuildSpellTooltipTitle(member.spellIcon, spellName), 1, 0.94, 0.82)
    GameTooltip:AddLine(classIcon .. " " .. className, red, green, blue)
    GameTooltip:AddDoubleLine("Player", BuildColoredName(shortName, member.classToken), 0.74, 0.78, 0.84, 1, 1, 1)
    GameTooltip:Show()
end

function MPT:GetPreviewInterruptMembers()
    local members = {
        { name = "Tankmate",  classToken = "PALADIN", role = "TANK",    count = 5, spellID = 96231, spellIcon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(96231) or nil, previewIndex = 1 },
        { name = "Healmate",  classToken = "SHAMAN",  role = "HEALER",  count = 3, spellID = 57994, spellIcon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(57994) or nil, previewIndex = 2 },
        { name = "Kickmage",  classToken = "MAGE",    role = "DAMAGER", count = 7, spellID = 2139,  spellIcon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(2139) or nil,  previewIndex = 3 },
        { name = "Roguemate", classToken = "ROGUE",   role = "DAMAGER", count = 4, spellID = 1766,  spellIcon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(1766) or nil,  previewIndex = 4 },
        { name = "Beamdruid", classToken = "DRUID",   role = "DAMAGER", count = 2, spellID = 78675, spellIcon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(78675) or nil, previewIndex = 5 },
    }
    return members
end

-- Refreshes (or creates) a stable secondary-slot proxy that presents the
-- member's second interrupt spell to the display pipeline without allocating
-- a new table each frame.
local function RefreshSecondSlot(member)
    local slot = member._secondSlot
    if not slot then
        slot = {}
        member._secondSlot = slot
    end
    local ss        = member.secondSpell
    slot.name       = member.name
    slot.classToken = member.classToken
    slot.role       = member.role
    slot.unit       = member.unit
    slot.guid       = member.guid
    slot.spellID    = ss.spellID
    slot.cooldown   = ss.cooldown
    slot.readyAt    = ss.readyAt or 0
    slot.spellIcon  = ss.spellIcon
    slot.count      = ss.count or 0
    slot.lastCastAt = ss.lastCastAt
    return slot
end

function MPT:GetInterruptDisplayMembers(now)
    -- Reuse the scratch list table to avoid allocation every 100 ms.
    local members = wipe(self.interruptDisplayScratch)
    if self.preview.interrupts then
        local previewList = self:GetPreviewInterruptMembers()
        for i = 1, #previewList do
            members[i] = previewList[i]
        end
    else
        local idx = 1
        for _, name in ipairs(self.interruptOrder or {}) do
            local member = self.interruptMembers[name]
            if member and member.spellID then
                members[idx] = member
                idx = idx + 1
                -- If this member has a second tracked interrupt, inject a
                -- proxy row for it so it sorts and renders independently.
                if member.secondSpell and member.secondSpell.spellID then
                    members[idx] = RefreshSecondSlot(member)
                    idx = idx + 1
                end
            end
        end
    end

    -- Pre-compute sort keys so that the tsort comparator does not call
    -- GetInterruptRowState O(N log N) times, each allocating a table.
    for _, member in ipairs(members) do
        local state           = self:GetInterruptRowState(member, now)
        member._sortPriority  = state.priority
        member._sortRemaining = state.remaining or 0
    end

    tsort(members, function(left, right)
        if left._sortPriority ~= right._sortPriority then
            return left._sortPriority < right._sortPriority
        end
        if left._sortPriority == 3 and abs(left._sortRemaining - right._sortRemaining) > 0.05 then
            return left._sortRemaining < right._sortRemaining
        end
        local leftRole  = ROLE_ORDER[left.role or "NONE"] or 99
        local rightRole = ROLE_ORDER[right.role or "NONE"] or 99
        if leftRole ~= rightRole then
            return leftRole < rightRole
        end
        return GetShortName(left.name) < GetShortName(right.name)
    end)

    -- Remove temp fields so they do not linger on persistent member tables.
    for _, member in ipairs(members) do
        member._sortPriority  = nil
        member._sortRemaining = nil
    end

    return members
end

function MPT:ApplyInterruptRowState(row, member, state)
    local appearance = self:GetTrackerAppearance()
    local nameColor = self:GetInterruptFontColor(member)
    local statusFontPath, statusColor, shouldShowText = self:GetStatusTextStyle(state)

    row.icon:SetTexture(member.spellIcon)
    row.icon:SetShown(member.spellIcon ~= nil)
    row.name:SetText(GetShortName(member.name))
    row.timer:SetText(shouldShowText and (state.valueText or "") or "")
    row.detail:SetText("")
    row.detail:Hide()
    row.member = member

    ApplyFontString(row.name, appearance.fontPath, appearance.fontSize, appearance.outline,
        nameColor[1], nameColor[2], nameColor[3], 1)
    ApplyFontString(row.timer, statusFontPath, appearance.fontSize + 1, appearance.outline,
        statusColor[1], statusColor[2], statusColor[3], 1)
    ApplyFontString(row.detail, appearance.fontPath, max(10, appearance.fontSize - 2), appearance.outline,
        0.78, 0.78, 0.8, 1)

    row.bar:SetStatusBarTexture(appearance.barTexture)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(ClampNumber(state.progress, 0, 1, 0))

    local barColor = state.color
    if state.priority == 3 then
        barColor = self:GetInterruptBarColor(member)
    elseif state.isReady then
        barColor = self:GetInterruptReadyBarColor(member)
    end
    SetStatusBarColor(row.bar, barColor)
end

function MPT:RefreshInterruptFrame()
    local frame = self:EnsureInterruptFrame()
    local showFrame = (IsModuleConfiguredEnabled() and self:ShouldShowTrackerFrames() and self:IsFeatureEnabled("interruptTracker")) or
        self.preview.interrupts
    if not showFrame then
        frame:Hide()
        return
    end

    frame:Show()
    self:ApplyTrackerFrameStyle(frame)
    local appearance = self:GetTrackerAppearance()
    ApplyFontString(frame.Title, appearance.fontPath, appearance.fontSize + 2, appearance.outline, 1, 0.94, 0.82, 1)

    local now = GetTime()
    local members = self:GetInterruptDisplayMembers(now)
    frame.EmptyText:SetShown(#members == 0)

    for index, row in ipairs(frame.rows) do
        local member = members[index]
        if member then
            local state = self:GetInterruptRowState(member, now)
            self:ApplyInterruptRowState(row, member, state)
            row:Show()
        else
            row.icon:SetTexture(nil)
            row.icon:Hide()
            row.name:SetText("")
            row.timer:SetText("")
            row.detail:SetText("")
            row.detail:Hide()
            row.member = nil
            row:Hide()
        end
    end

    self:ApplyRowLayout(frame)
end

function MPT:OnTick()
    -- Invalidate the appearance cache so settings changes are reflected within
    -- one tick while still paying the refresh cost at most once per tick.
    self.trackerAppearanceDirty = true

    local now = GetTime()
    self:EnsureDynamicHooks()
    self:TryResolvePendingInspect()
    self:PollPlayerSpecChanges(now)
    self:PollDeathState()

    if IsModuleConfiguredEnabled() and self:GetDB().autoSlotKeystone ~= false then
        self:TryAutoSlotKeystone()
    end

    if self.interruptFrame and self.interruptFrame:IsShown() then
        self:RefreshInterruptFrame()
    end

    if self.preview.mythicPlusTimer or IsChallengeModeActive() or (self.mythicPlusTimerFrame and self.mythicPlusTimerFrame:IsShown()) then
        self:RefreshMythicPlusTimerFrame()
    end

    -- Keep the keystone setup helper panel in sync while the receptacle UI is open.
    local ksFrame = _G.ChallengesKeystoneFrame
    if ksFrame and ksFrame.IsShown and ksFrame:IsShown() then
        self:RefreshKeystoneHelperPanel()
    end

    if not IsChallengeModeActive() then
        self.deathCount = 0
    end
end

function MPT:Initialize()
    if self.initialized == true then
        return true
    end

    if not self:IsCoreReady() then
        return false
    end

    self.initialized = true
    self.started = false
    self:OnEnable()
    self.started = true

    self:FlushPendingHostedEvents()
    return true
end

function MPT:ScheduleInitialization()
    if self.initialized == true or self.initializationScheduled == true then
        return
    end

    self.initializationScheduled = true

    local function step()
        if self:Initialize() then
            return
        end

        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.1, step)
        end
    end

    step()
end

-- Pre-create the main runtime event frame and register all general events at
-- file-load time.  This is the only context guaranteed to be 100% untainted.
-- COMBAT_LOG_EVENT_UNFILTERED in particular raises ADDON_ACTION_FORBIDDEN when
-- registered from inside a C_Timer.After callback; doing it here avoids that.
do
    local preInitFrame = CreateFrame("Frame")
    preInitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    preInitFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    preInitFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    preInitFrame:RegisterEvent("INSPECT_READY")
    preInitFrame:RegisterEvent("START_PLAYER_COUNTDOWN")
    preInitFrame:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
    -- COMBAT_LOG_EVENT_UNFILTERED is restricted in TWW for custom addon frames;
    -- it is sourced via the ElvUI Misc module hook instead.
    preInitFrame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
    preInitFrame:SetScript("OnEvent", function(_, event, ...)
        -- Route through HandleHostedEvent which safely queues events before
        -- the module is fully started and dispatches them afterwards.
        MPT:HandleHostedEvent(event, ...)
    end)
    MPT.runtimeEventFrame = preInitFrame
end

MPT:ScheduleInitialization()
