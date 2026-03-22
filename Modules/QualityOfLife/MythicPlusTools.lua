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
local C_MythicPlus = _G.C_MythicPlus
local C_PartyInfo = _G.C_PartyInfo
local C_NamePlate = _G.C_NamePlate
local C_Spell = _G.C_Spell
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
local InCombatLockdown = _G.InCombatLockdown
local IsInGroup = _G.IsInGroup
local IsInInstance = _G.IsInInstance
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
local FindAuraBySpellID = AuraUtil and (AuraUtil.FindAuraBySpellId or AuraUtil.FindAuraBySpellID)

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
local MUTED_SOUND_VALUE = "__none"
local DEBUG_LOG_LIMIT = 120
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
    local outline                = GetOutlineFlag(db.trackerFontOutline)

    c.fontPath                   = GetTrackerFontPath(db.trackerFont)
    c.fontSize                   = ClampNumber(db.trackerFontSize, 8, 24, 12)
    c.outline                    = outline
    c.rowGap                     = ClampNumber(db.trackerRowGap, 0, 20, 6)
    c.iconSize                   = ClampNumber(db.trackerIconSize, 14, 32, 18)
    c.barHeight                  = ClampNumber(db.trackerBarHeight, 10, 30, 18)
    c.barTexture                 = (db.trackerBarTexture and LSM and LSM.Fetch and LSM:Fetch("statusbar", db.trackerBarTexture)) or
        (LSM and LSM.Fetch and LSM:Fetch("statusbar", "Blizzard")) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    c.statusTextFontPath         = GetTrackerFontPath(db.statusTextFont)
    c.readyTextFontPath          = GetTrackerFontPath(db.readyTextFont)
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
    return db.interruptTrackerLocked == true
end

function MPT:SetFrameLocked(kind, isLocked)
    local db = self:GetDB()
    db.interruptTrackerLocked = isLocked == true
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

    if frame.CloseButton then
        frame.CloseButton:SetShown(not isLocked or isHovered)
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
            self:ApplyRowLayout(sizedFrame)
            self:RefreshInterruptFrame()
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
    self.masqueGroups[kind] = Masque:Group("TwichUI Redux", label)
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
    self:ApplyFrameLockStates()
    if self.interruptFrame then
        self:ApplyRowLayout(self.interruptFrame)
        self:RefreshInterruptFrame()
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

local function GetOwnedKeystoneMapID()
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
    return false
end

function MPT:EnsureRuntime()
    self.deathWindow = self.deathWindow or {}
    self.interruptMembers = self.interruptMembers or {}
    self.interruptOrder = self.interruptOrder or {}
    self.inspectQueue = self.inspectQueue or {}
    self.pendingHostedEvents = self.pendingHostedEvents or {}
    self.debugLines = self.debugLines or {}
    self.lastHostedEventAt = self.lastHostedEventAt or {}
    self.partyDeathState = self.partyDeathState or {}
    self.lastRosterRefreshAt = self.lastRosterRefreshAt or 0
    self.preview = self.preview or {
        interrupts = false,
        interruptsStartedAt = 0,
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
    self:EnsureDebugFrame()
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
end

function MPT:RefreshModuleState()
    if not IsModuleConfiguredEnabled() then
        if self.interruptFrame then
            self.interruptFrame:Hide()
        end
        return
    end

    self:RefreshAllState()
end

function MPT:EnsureDebugFrame()
    if self.debugFrame then
        return self.debugFrame
    end

    local frame = CreateFrame("Frame", "TwichUIMythicPlusToolsDebugFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(760, 360)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
    frame.title:SetText("TwichUI Mythic+ Tools Debug")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -28)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(700)
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)

    scroll:SetScrollChild(editBox)

    frame.scroll = scroll
    frame.editBox = editBox
    self.debugFrame = frame
    return frame
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

function MPT:RefreshDebugFrame()
    if not self.debugFrame then
        return
    end

    local safeLines = {}
    for index, line in ipairs(self.debugLines or {}) do
        safeLines[index] = SafeDebugString(line)
    end

    local text = table.concat(safeLines, "\n")
    self.debugFrame.editBox:SetText(text)
    self.debugFrame.editBox:SetCursorPosition(0)
    self.debugFrame.scroll:SetVerticalScroll(0)
end

function MPT:ShowDebugFrame()
    local frame = self:EnsureDebugFrame()
    self:RefreshDebugFrame()
    frame.editBox:HighlightText()
    frame:Show()
end

function MPT:LogDebug(message, shouldShow)
    self:EnsureRuntime()

    local prefix = date and type(date) == "function" and date("%H:%M:%S") or format("%.3f", GetTime())
    self.debugLines[#self.debugLines + 1] = "[" .. SafeDebugString(prefix) .. "] " .. SafeDebugString(message)
    while #self.debugLines > DEBUG_LOG_LIMIT do
        table.remove(self.debugLines, 1)
    end

    self:RefreshDebugFrame()
    if shouldShow == true then
        self:ShowDebugFrame()
    end
end

function MPT:LogStartupSnapshot(reason)
    local db = self:GetDB()
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    self:LogDebug(format(
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
    ), false)
    self:LogDebug("event host=hook/piggyback mode; runtime is plain Lua inside TwichUI", false)
    self:LogDebug(format(
        "hooks active: DirectEvents=%s TimerTracker=%s ToastsPEW=%s ToastsRoster=%s ElvUIMiscCL=%s ElvUINameplatesCL=%s ElvUINPPostInterrupted=%s",
        tostring(self.directEventsRegistered == true),
        tostring(self.hookedTimerTracker == true),
        tostring(self.hookedToastsPlayerEnteringWorld == true),
        tostring(self.hookedToastsGroupRosterUpdate == true),
        tostring(self.hookedElvUIMiscCombatLog == true),
        tostring(self.hookedElvUINameplatesCombatLog == true),
        tostring(self.hookedElvUINameplatesPostCastInterrupted == true)
    ), false)
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
        self:LogDebug(format("forwarded event=%s", tostring(event)), false)
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
            self:LogDebug(format("forwarded event=%s", tostring(event)), false)
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

    if type(hooksecurefunc) == "function" and type(_G.TimerTracker_StartTimerOfType) == "function" then
        hooksecurefunc("TimerTracker_StartTimerOfType", function(...)
            self:HandleTimerTrackerStart(...)
        end)
        self.hookedTimerTracker = true
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
    -- COMBAT_LOG_EVENT_UNFILTERED is restricted in TWW; sourced via ElvUI hook.
    self.runtimeEventFrame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")

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
        end)
        self.keystoneFrameHooked = true
    end
end

function MPT:HandleTimerTrackerStart(...)
    local args = { ... }
    local timerType = args[1]
    local timeSeconds = args[2]
    local totalTime = args[3]

    self:LogDebug(
    format("hooked timer start type=%s time=%s total=%s", tostring(timerType), tostring(timeSeconds), tostring(totalTime)),
        false)
    self:START_TIMER("START_TIMER", timerType, timeSeconds, totalTime)
end

function MPT:EnsureFrames()
    self:EnsureInterruptFrame()
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
    db.interruptX = x
    db.interruptY = y
end

function MPT:RestoreFramePosition(kind, frame, fallbackX, fallbackY)
    local db = self:GetDB()
    local x = db.interruptX
    local y = db.interruptY
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(x) or fallbackX, tonumber(y) or fallbackY)
end

function MPT:ApplyFrameLockStates()
    if self.interruptFrame then
        self.interruptFrame:EnableMouse(true)
        self:RefreshFrameControls("interrupt", self.interruptFrame)
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

function MPT:RefreshAllState()
    self:RefreshInterruptRoster()
    self:RefreshInterruptFrame()
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

function MPT:START_TIMER(_, timerType, timeSeconds, totalTime)
    local duration = tonumber(totalTime) or tonumber(timeSeconds)
    if not duration or duration < 1 or duration > 60 then
        return
    end

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

function MPT:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
    if not subEvent then
        return
    end

    if subEvent == "SPELL_INTERRUPT" or subEvent == "SPELL_CAST_SUCCESS" then
        if self:IsSourceInCurrentParty(sourceGUID, sourceName) or subEvent == "SPELL_INTERRUPT" then
            self:LogDebug(format(
                "combatlog event=%s source=%s guid=%s spellID=%s dest=%s destGUID=%s",
                tostring(subEvent),
                tostring(sourceName),
                tostring(sourceGUID),
                tostring(spellID),
                tostring(destName),
                tostring(destGUID)
            ), false)
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
        self:LogDebug(format("interrupt dedupe unit-event unit=%s", SafeDebugString(interruptedUnit)), false)
        return false
    end

    local member, record = self:GetRecentPartyCastMember(now, 1.0)
    if not member then
        self:LogDebug(
        format("interrupt drop event=UNIT_SPELLCAST_INTERRUPTED unit=%s reason=no-recent-cast",
            SafeDebugString(interruptedUnit)), false)
        return false
    end

    self:LogDebug(format(
        "interrupt correlate unit-event unit=%s member=%s age=%.3f spellID=%s",
        SafeDebugString(interruptedUnit),
        tostring(member.name),
        now - (tonumber(record and record.at) or now),
        tostring(record and record.spellID)
    ), false)

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
        self:LogDebug(format("inspect resolved member=%s specID=%d", tostring(member.name), specID), false)
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
        self:LogDebug(format("inspect timeout member=%s", tostring(self.activeInspectName)), false)
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

    if C_ChallengeMode and type(C_ChallengeMode.SlotKeystone) == "function" then
        self:LogDebug("attempting keystone auto-slot", false)
        C_ChallengeMode.SlotKeystone()
        if HasSlottedKeystone() then
            self:LogDebug("keystone auto-slot succeeded via SlotKeystone()", false)
            return
        end
    end

    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" then
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
            if isKeystone and type(C_Container.UseContainerItem) == "function" then
                self:LogDebug(format("attempting keystone bag use bag=%d slot=%d", bagIndex, slotIndex), false)
                C_Container.UseContainerItem(bagIndex, slotIndex)
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0.1, function()
                        if not HasSlottedKeystone() and C_ChallengeMode and type(C_ChallengeMode.SlotKeystone) == "function" then
                            C_ChallengeMode.SlotKeystone()
                        end
                    end)
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

function MPT:TestPullTimer()
    if not HasSlottedKeystone() then
        return false
    end

    if type(RunMacroText) == "function" then
        RunMacroText("/cd 10")
    elseif C_PartyInfo and type(C_PartyInfo.DoCountdown) == "function" then
        C_PartyInfo.DoCountdown(10)
    end

    return true
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
            self:LogDebug(format("inspect request unit=%s member=%s", tostring(member.unit), tostring(member.name)),
                false)
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
        self:LogDebug(
        format("player spec refresh old=%s new=%s", tostring(playerMember.specID), tostring(currentSpecID)), false)
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
                self:LogDebug(
                format("interrupt resolve unit=%s via=guid source=%s guid=%s", tostring(unit), tostring(sourceName),
                    tostring(sourceGUID)), false)
                return unit
            end

            local fullName = GetFullUnitName(unit)
            local shortName = fullName and GetShortName(fullName) or nil
            local rawName = type(UnitName) == "function" and UnitName(unit) or nil
            if SafeStringsEqual(sourceName, fullName) or SafeStringsEqual(sourceName, shortName) or SafeStringsEqual(sourceName, rawName) then
                self:LogDebug(
                format("interrupt resolve unit=%s via=name source=%s guid=%s", tostring(unit), tostring(sourceName),
                    tostring(sourceGUID)), false)
                return unit
            end
        end
    end

    if sourceGUID or sourceName then
        self:LogDebug(format("interrupt resolve failed source=%s guid=%s", tostring(sourceName), tostring(sourceGUID)),
            false)
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
            format("interrupt member match=%s via=name source=%s", tostring(member.name), tostring(sourceName)), false)
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
        self:LogDebug(
        format("interrupt ignored member=%s spellID=%s reason=no tracked spell", tostring(member.name), tostring(spellID)),
            false)
        return false
    end

    local now = GetTime()
    local trackedSpellID = isSupportedInterruptSpell and spellID or member.spellID
    local cooldown = GetInterruptCooldownForSpell(trackedSpellID, member.cooldown)

    self:LogDebug(format(
        "interrupt apply event=%s member=%s source=%s rawSpellID=%s trackedSpellID=%s cooldown=%.1f readyAt=%.1f supported=%s",
        tostring(subEvent),
        tostring(member.name),
        tostring(sourceName),
        tostring(spellID),
        tostring(trackedSpellID),
        tonumber(cooldown) or 0,
        now + cooldown,
        tostring(isSupportedInterruptSpell)
    ), false)

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
        self:LogDebug(format(
            "interrupt dedupe host=%s unit=%s",
            SafeDebugString(host),
            SafeDebugString(interruptedUnit)
        ), false)
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

    self:LogDebug(format(
        "observed interrupt host=%s unit=%s interruptedSpellID=%s sourceGUID=%s rawToken=%s sourceUnit=%s source=%s text=%s",
        SafeDebugString(host),
        SafeDebugString(interruptedUnit),
        SafeDebugString(interruptedSpellID),
        SafeDebugString(interruptedByGUID),
        SafeDebugString(rawToken),
        SafeDebugString(sourceUnit),
        SafeDebugString(sourceName),
        SafeDebugString(castbarText)
    ), false)

    local member = sourceUnit and self:EnsureInterruptMemberForUnit(sourceUnit, sourceName) or
    self:GetMemberBySource(nil, sourceName)
    local resolutionMethod = sourceUnit and "source-unit" or (sourceName and "castbar-text" or nil)
    if not member then
        local recentMember, recentRecord = self:GetRecentPartyCastMember(now, RECENT_INTERRUPT_CAST_WINDOW)
        if recentMember and recentRecord then
            member = recentMember
            resolutionMethod = "recent-cast"
            sourceName = sourceName or recentMember.name
            self:LogDebug(format(
                "interrupt correlate recent member=%s age=%.3f spellID=%s",
                tostring(recentMember.name),
                now - (tonumber(recentRecord.at) or now),
                tostring(recentRecord.spellID)
            ), false)
        end
    end

    if not member then
        local singleReadyMember, readyCount = self:GetSingleReadyInterruptMember(now)
        if singleReadyMember then
            member = singleReadyMember
            resolutionMethod = "single-ready"
            sourceName = sourceName or singleReadyMember.name
        else
            self:LogDebug(format(
                "interrupt opaque drop reason=ambiguous-ready readyCount=%s",
                tostring(readyCount or 0)
            ), false)
        end
    end

    if not member then
        self:LogDebug(format(
            "interrupt drop event=SPELL_INTERRUPT unit=%s source=%s reason=no-member",
            SafeDebugString(sourceUnit),
            SafeDebugString(sourceName)
        ), false)
        return
    end

    self:LogDebug(format(
        "interrupt member match=%s via=%s unit=%s source=%s",
        tostring(member.name),
        tostring(resolutionMethod or "unknown"),
        SafeDebugString(sourceUnit),
        SafeDebugString(sourceName)
    ), false)

    if resolutionMethod == "recent-cast" and tonumber(member.readyAt) and member.readyAt > now then
        self:ClearRecentPartyCast(member.name)
        self:LogDebug(format(
            "interrupt confirm member=%s via=recent-cast existingReadyAt=%.1f",
            tostring(member.name),
            tonumber(member.readyAt) or 0
        ), false)
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
        self:LogDebug(format("death suppressed name=%s total=%d", tostring(destName), self.deathCount), false)
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
    local iconTexture = member.spellIcon or "Interface\\RaidFrame\\ReadyCheck-NotReady"
    return {
        status = "MYTHIC+ DEATH",
        title = title,
        detail = detail,
        icon = iconTexture,
        color = ALERT_COLOR,
    }
end

function MPT:SendDeathNotification(member, totalDeaths)
    local notification = self:BuildDeathNotification(member, totalDeaths)
    ---@type TwichUI_MythicPlusAlertNotificationWidget
    local widget = CreateWidget(AceGUI, "TwichUI_MythicPlusAlertNotification")
    widget:SetAlert(notification.status, notification.title, notification.detail, notification.icon, notification.color)

    self:LogDebug(format("death notification name=%s total=%d", tostring(member.name), tonumber(totalDeaths) or 0), false)

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
        spellIcon = "Interface\\RaidFrame\\ReadyCheck-NotReady",
        unit = "player",
    }
    self:SendDeathNotification(member, (self.deathCount or 0) + 1)
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
