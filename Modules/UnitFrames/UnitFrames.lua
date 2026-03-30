---@diagnostic disable: undefined-field, undefined-global
--[[
    TwichUI Unit Frames (oUF)

    Provides standalone unit frames for player/target/focus/pet/ToT,
    castbar, party/raid/tank headers, and boss frames.

    This module is intentionally independent from ElvUI unitframe internals.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class UnitFramesModule : AceModule, AceEvent-3.0
local UnitFrames = T:NewModule("UnitFrames", "AceEvent-3.0")

local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UIParent = _G.UIParent
local UnitExists = _G.UnitExists
local UnitClass = _G.UnitClass
local UnitIsPlayer = _G.UnitIsPlayer
local UnitPowerType = _G.UnitPowerType
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local StatusBarInterpolation = (_G.Enum and _G.Enum.StatusBarInterpolation) or _G.StatusBarInterpolation
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local C_UnitAuras = _G.C_UnitAuras
local issecretvalue = _G.issecretvalue or function() return false end
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local StatusBarTimerDirection = (_G.Enum and _G.Enum.StatusBarTimerDirection) or nil

-- Gradient compat: SetGradient (9.0+) or SetGradientAlpha (legacy).
-- For VERTICAL: arg1/2 = bottom color, arg3/4 = top color.
-- For HORIZONTAL: arg1/2 = left color, arg3/4 = right color.
local function SetGradientCompat(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    if tex.SetGradient and _G.CreateColor then
        tex:SetGradient(orient, _G.CreateColor(r1, g1, b1, a1), _G.CreateColor(r2, g2, b2, a2))
    elseif tex.SetGradientAlpha then
        tex:SetGradientAlpha(orient, r1, g1, b1, a1, r2, g2, b2, a2)
    else
        tex:SetVertexColor(r1, g1, b1, math.max(a1, a2))
    end
end

-- Lightweight debug helper — only writes when the UF source is enabled in the console.
local function UFDebug(msg)
    local dc = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if dc and dc.Log then dc:Log("unitframes", msg, false) end
end

local function ReadAuraNumber(value)
    if value == nil then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "number" then return value end

    local okTonumber, numericValue = pcall(tonumber, value)
    if okTonumber and type(numericValue) == "number" then
        return numericValue
    end

    local okAdd, coercedValue = pcall(function()
        return value + 0
    end)
    if okAdd and type(coercedValue) == "number" then
        return coercedValue
    end

    return nil
end

local function SafeAuraDebugValue(value, fallback)
    if value == nil then return fallback or "nil" end
    if issecretvalue and issecretvalue(value) then return "<secret>" end

    local okString, stringValue = pcall(tostring, value)
    if okString and type(stringValue) == "string" then
        return stringValue
    end

    return fallback or "<unprintable>"
end

local function SafeColorDebugValue(color)
    if type(color) ~= "table" then
        return "nil"
    end

    local r = color[1] or color.r
    local g = color[2] or color.g
    local b = color[3] or color.b
    local a = color[4] or color.a or color.alpha

    return string.format(
        "%.3f,%.3f,%.3f,%.3f",
        tonumber(r) or -1,
        tonumber(g) or -1,
        tonumber(b) or -1,
        tonumber(a) or -1
    )
end

local function BuildAuraTimingDebugKey(contextKey, unit, auraData, reason)
    return table.concat({
        SafeAuraDebugValue(contextKey, "unknown"),
        SafeAuraDebugValue(unit, "nil"),
        SafeAuraDebugValue(auraData and auraData.auraInstanceID, "nil"),
        SafeAuraDebugValue(auraData and auraData.spellId, "nil"),
        SafeAuraDebugValue(reason, "unknown"),
    }, ":")
end

function UnitFrames:LogAuraTimingOnce(contextKey, unit, auraData, reason, detail)
    self._auraTimingDebugSeen = self._auraTimingDebugSeen or {}
    local key = BuildAuraTimingDebugKey(contextKey, unit, auraData, reason)
    if self._auraTimingDebugSeen[key] then return end
    self._auraTimingDebugSeen[key] = true

    UFDebug(string.format(
        "AuraTiming: context=%s unit=%s spellId=%s auraInstanceID=%s reason=%s %s",
        SafeAuraDebugValue(contextKey, "unknown"),
        SafeAuraDebugValue(unit, "nil"),
        SafeAuraDebugValue(auraData and auraData.spellId, "nil"),
        SafeAuraDebugValue(auraData and auraData.auraInstanceID, "nil"),
        SafeAuraDebugValue(reason, "unknown"),
        SafeAuraDebugValue(detail or "", "")
    ))
end

function UnitFrames:ResolveAuraTiming(unit, auraData, contextKey)
    local timing = {
        duration = ReadAuraNumber(auraData and auraData.duration) or 0,
        expirationTime = ReadAuraNumber(auraData and auraData.expirationTime) or 0,
        applications = ReadAuraNumber(auraData and auraData.applications) or 0,
        durationObject = nil,
    }

    if unit and auraData and auraData.auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDuration then
        local okDurationObject, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraData.auraInstanceID)
        if okDurationObject and durationObject then
            timing.durationObject = durationObject
            if timing.duration <= 0 or timing.expirationTime <= 0 then
                self:LogAuraTimingOnce(
                    contextKey,
                    unit,
                    auraData,
                    "duration-object-fallback",
                    string.format("numericDuration=%s numericExpiration=%s", tostring(timing.duration),
                        tostring(timing.expirationTime))
                )
            end
        elseif (timing.duration <= 0 or timing.expirationTime <= 0) and auraData.duration ~= nil then
            self:LogAuraTimingOnce(
                contextKey,
                unit,
                auraData,
                "timer-unavailable",
                string.format("durationType=%s expirationType=%s", type(auraData.duration), type(auraData.expirationTime))
            )
        end
    end

    return timing
end

function UnitFrames:GetAuraRemainingTime(durationObject, expirationTime, duration)
    if durationObject and durationObject.GetRemainingDuration then
        local okRemaining, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
        if okRemaining and type(remaining) == "number" and not (issecretvalue and issecretvalue(remaining)) then
            return math_max(0, remaining)
        end
    end

    if expirationTime and expirationTime > 0 and duration and duration > 0 then
        return math_max(0, expirationTime - GetTime())
    end

    return 0
end

function UnitFrames:ShouldUseAuraTimerFill(durationObject, expirationTime, duration)
    if durationObject and durationObject.GetRemainingDuration then
        local okRemaining, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
        if okRemaining and remaining ~= nil then
            if issecretvalue and issecretvalue(remaining) then
                return true
            end

            if type(remaining) == "number" and remaining > 0 then
                return true
            end
        end
    end

    return expirationTime and expirationTime > 0 and duration and duration > 0
end

function UnitFrames:UpdateAuraRemainingText(fs, durationObject, expirationTime, duration)
    if not fs then return false end

    if durationObject and durationObject.GetRemainingDuration then
        local okRemaining, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
        if okRemaining and remaining ~= nil then
            if issecretvalue and issecretvalue(remaining) then
                fs:SetFormattedText("%.1f", remaining)
                return true
            end

            if type(remaining) == "number" then
                remaining = math_max(0, remaining)
                if remaining <= 0 then
                    fs:SetText("")
                    return false
                end
                fs:SetText(self:FormatAuraRemainingTime(remaining))
                return true
            end
        end
    end

    local remaining = self:GetAuraRemainingTime(nil, expirationTime, duration)
    if remaining <= 0 then
        fs:SetText("")
        return false
    end

    fs:SetText(self:FormatAuraRemainingTime(remaining))
    return true
end

function UnitFrames:FormatAuraRemainingTime(remaining)
    if not remaining or remaining <= 0 then return "" end
    if remaining > 60 then
        return math.floor(remaining / 60) .. "m"
    elseif remaining > 10 then
        return string.format("%d", math.floor(remaining + 0.5))
    end
    return string.format("%.1f", remaining)
end

-- Returns the power bar fill colour for a unit's current power type.
-- Checks db.powerTypeColors overrides first, then falls back to PowerBarColor.
local function GetPowerTypeColor(unit, db)
    if not unit then return nil end
    local powerType, powerToken = UnitPowerType(unit)
    -- Check user overrides stored by token (e.g. db.powerTypeColors.MANA = {r,g,b,1})
    if db and type(db.powerTypeColors) == "table" then
        local ov = (powerToken and db.powerTypeColors[powerToken])
            or (powerType ~= nil and db.powerTypeColors[tostring(powerType)])
        if ov and type(ov[1]) == "number" then
            return { ov[1], ov[2], ov[3], ov[4] or 1 }
        end
    end
    local pbc = _G.PowerBarColor
    if not pbc then return nil end
    local c = (powerToken and pbc[powerToken]) or (powerType ~= nil and pbc[powerType])
    if c and type(c.r) == "number" then
        return { c.r, c.g, c.b, 1 }
    end
    return nil
end

local STYLE_NAME = "TwichUI_Reformed_UnitFrames"

UnitFrames.styleRegistered = false
UnitFrames.frames = {}
UnitFrames.headers = {}
UnitFrames.previewFrames = {}
UnitFrames.movers = {}
UnitFrames._castbarState = nil

local PREVIEW_SINGLE_UNITS = {
    { key = "player",       label = "Player" },
    { key = "target",       label = "Target" },
    { key = "targettarget", label = "Target of Target" },
    { key = "focus",        label = "Focus" },
    { key = "pet",          label = "Pet" },
}

-- Realistic class distribution used in test mode preview frames.
local PREVIEW_CLASS_TOKENS = {
    "WARRIOR", "MAGE", "PRIEST", "DEATHKNIGHT", "DRUID",
    "PALADIN", "ROGUE", "HUNTER", "WARLOCK", "SHAMAN",
    "MONK", "DEMONHUNTER", "EVOKER",
}
-- Per-slot mock class for single unit previews (player/pet omitted; palette
-- handles player via UnitClass("player") directly; pet has no player class).
local PREVIEW_MOCK_CLASSES = {
    target       = "WARRIOR",
    targettarget = "MAGE",
    focus        = "DEATHKNIGHT",
}

local function GetOUF()
    -- Embedded oUF in this addon lives on the addon namespace table (Engine),
    -- while some external layouts expose a global oUF. Support both.
    if TwichRx and type(TwichRx) == "table" and type(TwichRx.oUF) == "table" then
        return TwichRx.oUF
    end

    if type(_G.oUF) == "table" then
        return _G.oUF
    end

    -- Compatibility fallback for ElvUI environments.
    if type(_G.ElvUF) == "table" then
        return _G.ElvUF
    end

    return nil
end

local function Clamp(value, minimum, maximum)
    local numeric = tonumber(value)
    if numeric == nil then
        return minimum
    end

    local oUF = GetOUF()
    if oUF and type(oUF.CanAccessValue) == "function" then
        local ok, canAccess = pcall(oUF.CanAccessValue, oUF, numeric)
        if ok and canAccess == false then
            return minimum
        end
    end

    local okLess, isLess = pcall(function()
        return numeric < minimum
    end)
    if not okLess then
        return minimum
    end

    if isLess then
        return minimum
    end

    local okGreater, isGreater = pcall(function()
        return numeric > maximum
    end)
    if not okGreater then
        return maximum
    end

    if isGreater then
        return maximum
    end

    return numeric
end

local function ResolveFrameUnit(frame)
    if type(frame) ~= "table" then
        return nil
    end

    return frame:GetAttribute("unit") or frame.unit
end

local function CopyColor(color, fallback)
    local source = type(color) == "table" and color or fallback or { 1, 1, 1, 1 }
    return {
        source[1] or 1,
        source[2] or 1,
        source[3] or 1,
        source[4] or 1,
    }
end

local function NormalizeColor(color, fallback)
    if type(color) == "table" then
        if type(color[1]) == "number" or type(color[2]) == "number" or type(color[3]) == "number" then
            return CopyColor(color, fallback)
        end

        if type(color.r) == "number" or type(color.g) == "number" or type(color.b) == "number" then
            return {
                color.r or 1,
                color.g or 1,
                color.b or 1,
                color.a or color.alpha or 1,
            }
        end
    end

    if fallback == nil then
        return nil
    end

    return CopyColor(fallback)
end

local function ApplyStatusBarVisualColor(bar, color, fallbackAlpha)
    if not bar or not bar.SetStatusBarColor then
        return
    end

    local resolved = NormalizeColor(color, { 1, 1, 1, fallbackAlpha or 1 })
    if not resolved then
        resolved = { 1, 1, 1, fallbackAlpha or 1 }
    end

    local alpha = resolved[4]
    if type(alpha) ~= "number" then
        alpha = fallbackAlpha or 1
    end

    bar:SetStatusBarColor(resolved[1] or 1, resolved[2] or 1, resolved[3] or 1, alpha)

    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil
    if texture and texture.SetVertexColor then
        texture:SetVertexColor(resolved[1] or 1, resolved[2] or 1, resolved[3] or 1, alpha)
    end
end

local function BuildAuraAppearanceDebugKey(unit, data)
    return table.concat({
        SafeAuraDebugValue(unit, "nil"),
        SafeAuraDebugValue(data and data.auraInstanceID, "nil"),
        SafeAuraDebugValue(data and data.spellId, "nil"),
    }, ":")
end

function UnitFrames:LogAuraAppearanceOnce(unit, data, appearance, isUsingDurationObjectFill, texturePath)
    self._auraAppearanceDebugSeen = self._auraAppearanceDebugSeen or {}
    local key = BuildAuraAppearanceDebugKey(unit, data)
    if self._auraAppearanceDebugSeen[key] then return end
    self._auraAppearanceDebugSeen[key] = true

    UFDebug(string.format(
        "AuraAppearance: unit=%s spellId=%s auraInstanceID=%s harmful=%s timerFill=%s texture=%s fill=%s background=%s border=%s text=%s",
        SafeAuraDebugValue(unit, "nil"),
        SafeAuraDebugValue(data and data.spellId, "nil"),
        SafeAuraDebugValue(data and data.auraInstanceID, "nil"),
        tostring(data and data.isHarmfulAura == true),
        tostring(isUsingDurationObjectFill == true),
        SafeAuraDebugValue(texturePath, "nil"),
        SafeColorDebugValue(appearance and appearance.fillColor),
        SafeColorDebugValue(appearance and appearance.backgroundColor),
        SafeColorDebugValue(appearance and appearance.borderColor),
        SafeColorDebugValue(appearance and appearance.textColor)
    ))
end

local ApplyStandaloneCastbarTextAnchors

local ROLE_ATLAS = {
    TANK    = "UI-LFG-RoleIcon-Tank-Micro-Raid",
    HEALER  = "UI-LFG-RoleIcon-Healer-Micro-Raid",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-Raid",
}

local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"

local ROLE_TEX_COORDS = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

local TWICH_ROLE_TEXTURES = {
    TANK = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_Tank", width = 64, height = 74 },
    HEALER = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_Healer", width = 64, height = 68 },
    DAMAGER = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_DPS", width = 64, height = 74 },
}

local function GetRoleIconArt(iconType, role)
    if iconType == "twich" then
        return TWICH_ROLE_TEXTURES[role]
    end

    if ROLE_ATLAS[role] then
        return {
            atlas = ROLE_ATLAS[role],
            width = 1,
            height = 1,
        }
    end

    if ROLE_TEX_COORDS[role] then
        return {
            texture = ROLE_ICON_TEXTURE,
            texCoord = ROLE_TEX_COORDS[role],
            width = 19,
            height = 19,
        }
    end
end

local function GetScaledRoleIconSize(size, art)
    local boundedSize = Clamp(size or 18, 8, 40)
    if type(art) ~= "table" or art.atlas then
        return boundedSize, boundedSize
    end

    local width = tonumber(art.width) or boundedSize
    local height = tonumber(art.height) or boundedSize
    if width <= 0 or height <= 0 then
        return boundedSize, boundedSize
    end

    local scale = boundedSize / math_max(width, height)
    return math_max(1, width * scale), math_max(1, height * scale)
end

local INFO_BAR_TEXT_DEFAULTS = {
    { tag = "[name]",     justify = "LEFT",   fontSize = 9, useClassColor = false },
    { tag = "[perhp<$%]", justify = "CENTER", fontSize = 9, useClassColor = false },
    { tag = "",           justify = "RIGHT",  fontSize = 9, useClassColor = false },
}

local function GetLSMTexture(name)
    local LSM = T.Libs and T.Libs.LSM
    if not LSM or type(LSM.Fetch) ~= "function" then
        return "Interface\\TARGETINGFRAME\\UI-StatusBar"
    end

    local ok, texture = pcall(LSM.Fetch, LSM, "statusbar", name)
    if ok and type(texture) == "string" and texture ~= "" then
        return texture
    end

    return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function GetThemeColor(key, fallback)
    local theme = GetThemeModule()
    if not theme or type(theme.GetColor) ~= "function" then
        return CopyColor(fallback)
    end

    local color = theme:GetColor(key)
    if type(color) ~= "table" then
        return CopyColor(fallback)
    end

    return CopyColor(color)
end

local function GetThemeTexture()
    local theme = GetThemeModule()
    if not theme or type(theme.Get) ~= "function" then
        return GetLSMTexture("TwichUI-Smooth")
    end

    local textureName = theme:Get("statusBarTexture") or "TwichUI-Smooth"
    return GetLSMTexture(textureName)
end

local function EnsureBackdrop(frame)
    if frame.TwichBackdrop then
        return frame.TwichBackdrop
    end

    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    backdrop:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    backdrop:SetBackdropColor(0.06, 0.07, 0.09, 0.92)
    backdrop:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)

    frame.TwichBackdrop = backdrop
    return backdrop
end

local function BuildFrameName(unit)
    if unit == "targettarget" then
        return "Target of Target"
    end

    if unit == "pettarget" then
        return "Pet Target"
    end

    -- Power bar sub-movers use a "unitkey_power" naming convention.
    local powerBase = unit and unit:match("^(.-)_power$")
    if powerBase then
        return BuildFrameName(powerBase) .. " Power"
    end

    return unit and (unit:gsub("^%l", string.upper)) or "Unit"
end

local function ResolveScopeByUnitKey(unitKey)
    if unitKey == "partyMember" then
        return "party"
    end
    if unitKey == "raidMember" then
        return "raid"
    end
    if unitKey == "tankMember" then
        return "tank"
    end
    if unitKey == "boss" or (type(unitKey) == "string" and unitKey:match("^boss")) then
        return "boss"
    end
    return "singles"
end

local function ResolveCastbarScopeByUnitKey(unitKey)
    if unitKey == "partyMember" or unitKey == "tankMember" then
        return "party"
    end
    if unitKey == "raidMember" then
        return "raid"
    end
    if unitKey == "boss" or (type(unitKey) == "string" and unitKey:match("^boss")) then
        return "boss"
    end
    return "target"
end

local function ResolveOutlineFlags(mode)
    local m = tostring(mode or "OUTLINE")
    if m == "NONE" then return nil end
    if m == "THICKOUTLINE" then return "THICKOUTLINE" end
    if m == "MONOCHROME" then return "MONOCHROME" end
    if m == "MONOCHROMEOUTLINE" then return "OUTLINE, MONOCHROME" end
    if m == "MONOCHROMETHICKOUTLINE" then return "THICKOUTLINE, MONOCHROME" end
    return "OUTLINE"
end

local function IsValidAuraUnit(unit)
    if type(unit) ~= "string" or unit == "" then return false end
    if unit == "player" or unit == "pet" or unit == "target" or unit == "focus" then return true end
    if unit == "targettarget" or unit == "mouseover" or unit == "vehicle" then return true end
    if unit:match("^party%d+$") or unit:match("^raid%d+$") then return true end
    if unit:match("^boss%d+$") or unit:match("^arena%d+$") then return true end
    return false
end

local cachedDispelClass, cachedDispelSpec, cachedDispelTypes
local function GetPlayerDispelTypes()
    local _, classToken = UnitClass("player")
    local specID = GetSpecialization and GetSpecialization() or 0
    if cachedDispelClass == classToken and cachedDispelSpec == specID then
        return cachedDispelTypes
    end
    local dispelTypes = {}
    if classToken == "DRUID" then
        dispelTypes.Curse = true; dispelTypes.Poison = true
        if specID == 105 then dispelTypes.Magic = true end
    elseif classToken == "MAGE" then
        dispelTypes.Curse = true
    elseif classToken == "MONK" then
        dispelTypes.Disease = true; dispelTypes.Poison = true
        if specID == 270 then dispelTypes.Magic = true end
    elseif classToken == "PALADIN" then
        dispelTypes.Disease = true; dispelTypes.Magic = true; dispelTypes.Poison = true
    elseif classToken == "PRIEST" then
        dispelTypes.Disease = true; dispelTypes.Magic = true
    elseif classToken == "SHAMAN" then
        dispelTypes.Curse = true
        if specID == 264 then dispelTypes.Magic = true end
    end
    cachedDispelClass = classToken; cachedDispelSpec = specID; cachedDispelTypes = dispelTypes
    return dispelTypes
end

local function NormalizeDispelName(name)
    return (name == "") and "Enrage" or name
end

local function AuraMatchesDisplayMode(mode, data)
    if not data then return false end
    if mode == "DISPELLABLE" or mode == "DISPELLABLE_OR_BOSS" then
        -- isHarmful / isHarmfulAura can be secret booleans — wrap comparisons in pcall.
        local _okh, _harm   = pcall(function() return data.isHarmful == true end)
        local _okha, _harma = pcall(function() return data.isHarmfulAura == true end)
        if not ((_okh and _harm) or (_okha and _harma)) then return false end
        -- dispelName can also be a secret string — guard the table key lookup.
        local _okd, _canDispel = pcall(function()
            return GetPlayerDispelTypes()[NormalizeDispelName(data.dispelName or "")] == true
        end)
        local canDispel = _okd and _canDispel
        if mode == "DISPELLABLE" then return canDispel end
        -- isBossAura can be a secret boolean too.
        local _okb, _isBoss = pcall(function() return data.isBossAura == true end)
        return canDispel or (_okb and _isBoss)
    end
    return true
end

-- Method wrapper so AuraWatcher.lua (loaded after this file) can call it.
function UnitFrames:CheckAuraMatchesFilter(mode, data)
    return AuraMatchesDisplayMode(mode, data)
end

function UnitFrames:GetOptions()
    local configuration = T:GetModule("Configuration")
    return configuration and configuration.Options and configuration.Options.UnitFrames or nil
end

function UnitFrames:GetDB()
    local options = self:GetOptions()
    if options and type(options.GetDB) == "function" then
        return options:GetDB()
    end

    return {}
end

function UnitFrames:GetUnitSettings(unit)
    local db = self:GetDB()
    db.units = db.units or {}
    db.units[unit] = db.units[unit] or {}
    return db.units[unit]
end

function UnitFrames:GetGroupSettings(group)
    local db = self:GetDB()
    db.groups = db.groups or {}
    db.groups[group] = db.groups[group] or {}
    return db.groups[group]
end

function UnitFrames:GetLayoutSettings(key)
    local db = self:GetDB()
    db.layout = db.layout or {}
    db.layout[key] = db.layout[key] or {}
    return db.layout[key]
end

function UnitFrames:GetPalette(scopeOrUnitKey, unit, mockClass)
    local db = self:GetDB()
    db.colors = db.colors or {}
    db.colors.scopes = db.colors.scopes or {}
    db.healthColorByScope = db.healthColorByScope or {}

    local unitKey = nil
    local resolvedScope = scopeOrUnitKey or "singles"
    if resolvedScope ~= "singles" and resolvedScope ~= "party" and resolvedScope ~= "raid"
        and resolvedScope ~= "tank" and resolvedScope ~= "boss" then
        unitKey = resolvedScope
        resolvedScope = ResolveScopeByUnitKey(unitKey)
    end

    db.colors.scopes[resolvedScope] = db.colors.scopes[resolvedScope] or {}
    local scopeColors = db.colors.scopes[resolvedScope]

    local unitColors = nil
    local unitHealth = nil
    if unitKey and unitKey ~= "partyMember" and unitKey ~= "raidMember" and unitKey ~= "tankMember" then
        db.units = db.units or {}
        db.units[unitKey] = db.units[unitKey] or {}
        unitColors = db.units[unitKey].colors or nil
        unitHealth = db.units[unitKey].healthColor or nil
    end

    local palette = {
        health          = CopyColor(scopeColors.health or db.colors.health or
            GetThemeColor("successColor", { 0.34, 0.84, 0.54, 1 })),
        power           = CopyColor(scopeColors.power or db.colors.power or
            GetThemeColor("primaryColor", { 0.10, 0.72, 0.74, 1 })),
        -- Alpha 0 → transparent when empty; the frame backdrop shows through so no black bar.
        -- Users who want a visible empty-bar tint can set a custom powerBackground color.
        powerBackground = CopyColor(scopeColors.powerBackground or db.colors.powerBackground or
            GetThemeColor("powerBackgroundColor", { 0.05, 0.06, 0.08, 0.0 })),
        powerBorder     = CopyColor(scopeColors.powerBorder or db.colors.powerBorder or
            GetThemeColor("borderColor", { 0.24, 0.26, 0.32, 0.9 })),
        cast            = CopyColor(scopeColors.cast or db.colors.cast or
            GetThemeColor("accentColor", { 0.96, 0.76, 0.24, 1 })),
        background      = CopyColor(scopeColors.background or db.colors.background or
            GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08, 1 })),
        border          = CopyColor(scopeColors.border or db.colors.border or
            GetThemeColor("borderColor", { 0.24, 0.26, 0.32, 1 })),
    }

    if unitColors then
        if type(unitColors.power) == "table" then palette.power = CopyColor(unitColors.power) end
        if type(unitColors.powerBackground) == "table" then
            palette.powerBackground = CopyColor(unitColors
                .powerBackground)
        end
        if type(unitColors.powerBorder) == "table" then palette.powerBorder = CopyColor(unitColors.powerBorder) end
        if type(unitColors.cast) == "table" then palette.cast = CopyColor(unitColors.cast) end
        if type(unitColors.background) == "table" then palette.background = CopyColor(unitColors.background) end
        if type(unitColors.border) == "table" then palette.border = CopyColor(unitColors.border) end
    end

    local healthScope = (unitKey and db.healthColorByScope[unitKey]) or db.healthColorByScope[resolvedScope] or {}
    local mode = (unitHealth and unitHealth.mode and unitHealth.mode ~= "inherit" and unitHealth.mode)
        or healthScope.mode
        or (db.useClassColor == true and "class" or "theme")

    if mode == "custom" then
        if unitHealth and type(unitHealth.color) == "table" then
            palette.health = CopyColor(unitHealth.color)
        elseif type(healthScope.color) == "table" then
            palette.health = CopyColor(healthScope.color)
        end
        UFDebug(string.format("GetPalette: scope=%s mode=custom r=%.2f g=%.2f b=%.2f",
            tostring(resolvedScope),
            palette.health[1], palette.health[2], palette.health[3]))
    elseif mode == "class" then
        local classToken = nil
        if unit then
            -- Call UnitClass directly — it returns nil for non-player units so no
            -- UnitIsPlayer pre-check is needed. Removing that check means party/raid
            -- member frames no longer depend on UnitIsPlayer returning truthy.
            local _, ct = UnitClass(unit)
            classToken = ct
        end
        if not classToken and unitKey == "player" then
            -- Fallback for player-scoped frames when the unit string wasn't passed.
            local _, ct = UnitClass("player")
            classToken = ct
        end
        -- Fall back to the caller-supplied mock class (used by test mode previews).
        if not classToken then classToken = mockClass end
        local classColor = nil
        if classToken then
            -- Prefer the modern namespaced API (available since BFA). Fall back to the
            -- legacy RAID_CLASS_COLORS global so both APIs are covered.
            if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
                classColor = C_ClassColor.GetClassColor(classToken)
            end
            if not classColor then
                classColor = (_G.CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[classToken]
            end
            if classColor and type(classColor.r) == "number" then
                palette.health = { classColor.r, classColor.g, classColor.b, 1 }
            end
        end
        UFDebug(string.format("GetPalette: scope=%s mode=class token=%s found=%s",
            tostring(resolvedScope),
            tostring(classToken), tostring(classColor ~= nil)))
    end

    return palette
end

-- Returns the resolved power bar fill colour for unitKey/unit, honouring
-- powerColorMode at per-unit → per-scope → global cascade level.
--   "custom"    — use the configured palette colour (default)
--   "powertype" — look up WoW's PowerBarColor for the unit's active resource
-- Falls back to palette.power when mode = "powertype" but no mapping exists.
function UnitFrames:ResolvePowerColor(unitKey, unit)
    local db            = self:GetDB()
    local palette       = self:GetPalette(unitKey, unit)

    local resolvedScope = ResolveScopeByUnitKey(unitKey or "")
    local unitColors    = nil
    if unitKey and unitKey ~= "partyMember" and unitKey ~= "raidMember" and unitKey ~= "tankMember" then
        db.units = db.units or {}
        db.units[unitKey] = db.units[unitKey] or {}
        unitColors = db.units[unitKey].colors or nil
    end
    db.colors         = db.colors or {}
    db.colors.scopes  = db.colors.scopes or {}
    local scopeColors = db.colors.scopes[resolvedScope] or {}

    local mode        = (unitColors and unitColors.powerColorMode and unitColors.powerColorMode ~= "inherit" and unitColors.powerColorMode)
        or (scopeColors.powerColorMode and scopeColors.powerColorMode ~= "" and scopeColors.powerColorMode)
        or db.powerColorMode
        or "custom"

    if mode == "powertype" then
        local ptColor = GetPowerTypeColor(unit, db)
        if ptColor then return ptColor end
    end

    return palette.power
end

-- Applies healer-only power bar visibility for party/raid frames.
-- Collapses height to 0 for non-healers so health bar fills the whole frame.
function UnitFrames:UpdatePowerBarForRole(powerBar, unitKey, unit)
    local healerOnly = false
    if unitKey == "partyMember" then
        -- Default to healer-only (nil means never explicitly turned off → treat as true).
        -- Only disable when the user has explicitly stored false.
        healerOnly = self:GetGroupSettings("party").healerOnlyPower ~= false
    elseif unitKey == "raidMember" then
        healerOnly = self:GetGroupSettings("raid").healerOnlyPower ~= false
    end

    -- Determine desired state first, then bail early if nothing changed.
    -- This is called from PostUpdate/PostUpdateColor (every power tick), so avoiding
    -- redundant SetHeight/SetAlpha/Show/Hide calls is critical for performance.
    local shouldCollapse = false
    local role = nil
    if healerOnly and unit and UnitGroupRolesAssigned then
        role = UnitGroupRolesAssigned(unit) or ""
        shouldCollapse = (role ~= "HEALER")
    end

    if powerBar._roleCollapsed == shouldCollapse then return end
    powerBar._roleCollapsed = shouldCollapse

    if shouldCollapse then
        UFDebug(string.format("UpdatePowerBarForRole: key=%s healerOnly=true role=%s → COLLAPSE", tostring(unitKey),
            tostring(role)))
        powerBar:SetHeight(0)
        powerBar:SetAlpha(0)
        if powerBar._ownerFrame and powerBar._detached ~= true and powerBar._ownerFrame.Health then
            local health = powerBar._ownerFrame.Health
            health:ClearAllPoints()
            health:SetAllPoints(powerBar._ownerFrame)
        end
        if powerBar.border then
            powerBar.border:SetAlpha(0)
            powerBar.border:Hide()
        end
    else
        local restoreH = powerBar._designedHeight or 8
        if healerOnly then
            UFDebug(string.format("UpdatePowerBarForRole: key=%s healerOnly=true role=HEALER → RESTORE h=%d",
                tostring(unitKey), restoreH))
        else
            UFDebug(string.format("UpdatePowerBarForRole: key=%s healerOnly=false → RESTORE h=%d", tostring(unitKey),
                restoreH))
        end
        powerBar:SetHeight(restoreH)
        powerBar:SetAlpha(1)
        if powerBar._ownerFrame and powerBar._detached ~= true and powerBar._ownerFrame.Health then
            local health = powerBar._ownerFrame.Health
            health:ClearAllPoints()
            health:SetPoint("TOPLEFT", powerBar._ownerFrame, "TOPLEFT", 0, 0)
            health:SetPoint("TOPRIGHT", powerBar._ownerFrame, "TOPRIGHT", 0, 0)
            health:SetPoint("BOTTOM", powerBar, "TOP", 0, 0)
        end
        if powerBar.border then
            powerBar.border:SetAlpha(1)
            powerBar.border:Show()
        end
    end
end

-- Returns whether the power bar should be shown for the given unitKey.
-- Group member types always show power (per group config); single units read showPower.
function UnitFrames:GetEffectiveShowPower(unitKey)
    if unitKey == "partyMember" or unitKey == "raidMember" or unitKey == "tankMember" then
        return true
    end
    local key = (unitKey and unitKey:match("^boss")) and "boss" or (unitKey or "")
    return self:GetUnitSettings(key).showPower ~= false
end

-- ---------------------------------------------------------------------------
-- Role Icon (Task 2)
-- ---------------------------------------------------------------------------

--- Returns the merged role icon config for a given unit key.
function UnitFrames:GetRoleIconConfig(unitKey)
    local db = self:GetDB()
    local scope = ResolveScopeByUnitKey(unitKey)

    local groupCfg = {}
    if scope ~= "singles" then
        local grp = db.groups and db.groups[scope] or {}
        groupCfg = type(grp.roleIcon) == "table" and grp.roleIcon or {}
    end

    local unitCfg = {}
    if scope == "singles" and unitKey and unitKey ~= "partyMember" and unitKey ~= "raidMember" and unitKey ~= "tankMember" then
        local u = db.units and db.units[unitKey] or {}
        unitCfg = type(u.roleIcon) == "table" and u.roleIcon or {}
    end

    local function get(k, default)
        if unitCfg[k] ~= nil then return unitCfg[k] end
        if groupCfg[k] ~= nil then return groupCfg[k] end
        return default
    end

    return {
        enabled  = get("enabled", scope == "party"),
        corner   = get("corner", "TOPRIGHT"),
        size     = get("size", 18),
        insetX   = get("insetX", 2),
        insetY   = get("insetY", 2),
        filter   = get("filter", "all"),
        iconType = get("iconType", "standard"),
    }
end

--- Applies role icon layout settings to a frame (lazy texture creation + positioning).
--- Also installs an OnShow hook so the icon refreshes whenever the frame gains a unit.
function UnitFrames:ApplyRoleIconSettings(frame, unitKey)
    if not frame then return end

    if not frame.TwichRoleIconHost then
        local host = CreateFrame("Frame", nil, frame)
        host:SetAllPoints(frame)
        host:SetFrameStrata(frame:GetFrameStrata())
        host:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 5))
        frame.TwichRoleIconHost = host
        frame.TwichRoleIcon = host:CreateTexture(nil, "OVERLAY", nil, 1)
    else
        frame.TwichRoleIconHost:SetFrameStrata(frame:GetFrameStrata())
        frame.TwichRoleIconHost:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 5))
    end

    local icon = frame.TwichRoleIcon
    local host = frame.TwichRoleIconHost or frame
    local cfg = self:GetRoleIconConfig(unitKey)

    if not cfg.enabled then
        icon:Hide()
        if frame.TwichRoleIconHost then
            frame.TwichRoleIconHost:Hide()
        end
        return
    end

    if frame.TwichRoleIconHost then
        frame.TwichRoleIconHost:Show()
    end

    local sz = Clamp(cfg.size, 8, 40)
    icon:SetSize(sz, sz)
    icon:ClearAllPoints()
    icon:SetDrawLayer("OVERLAY", 7)

    local corner = cfg.corner or "TOPRIGHT"
    local inX = tonumber(cfg.insetX) or 2
    local inY = tonumber(cfg.insetY) or 2

    if corner == "TOPLEFT" then
        icon:SetPoint("TOPLEFT", host, "TOPLEFT", inX, -inY)
    elseif corner == "TOPRIGHT" then
        icon:SetPoint("TOPRIGHT", host, "TOPRIGHT", -inX, -inY)
    elseif corner == "BOTTOMLEFT" then
        icon:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", inX, inY)
    else
        icon:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inX, inY)
    end

    -- Ensure the icon refreshes every time the frame shows with a new unit
    if not frame._twichRoleIconOnShowHooked then
        frame._twichRoleIconOnShowHooked = true
        frame:HookScript("OnShow", function(f)
            UnitFrames:UpdateRoleIcon(f, f._unitKey or unitKey)
        end)
    end

    if not frame._twichRoleIconOnAttributeChangedHooked then
        frame._twichRoleIconOnAttributeChangedHooked = true
        frame:HookScript("OnAttributeChanged", function(f, name)
            if name == "unit" then
                UnitFrames:UpdateRoleIcon(f, f._unitKey or unitKey)
            end
        end)
    end

    self:UpdateRoleIcon(frame, unitKey)
end

--- Updates role icon visibility/atlas based on the unit's assigned role.
--- Filter "all"     = always show for any visible group member (DAMAGER icon for unassigned).
--- Filter "assigned"= show only when role is explicitly TANK/HEALER/DAMAGER (not NONE).
--- Filter "nonDps"  = TANK or HEALER only.
--- Filter "healers" = HEALER only.
--- Filter "tanks"   = TANK only.
function UnitFrames:UpdateRoleIcon(frame, unitKey)
    local icon = frame and frame.TwichRoleIcon
    if not icon then return end

    local cfg = self:GetRoleIconConfig(unitKey)
    if not cfg.enabled then
        icon:Hide(); return
    end

    local unit = ResolveFrameUnit(frame)
    local role = ""
    if unit and UnitExists(unit) then
        role = (UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)) or ""
    elseif frame and frame._isTestPreview then
        role = frame._testRole or ""
    else
        icon:Hide(); return
    end

    local filter = cfg.filter or "all"
    local displayRole = role -- role to use for the atlas lookup

    local show
    if filter == "all" then
        -- Always show; fall back to DAMAGER icon for unassigned units
        show = true
        if role == "" or role == "NONE" then displayRole = "DAMAGER" end
    elseif filter == "assigned" then
        show = role ~= "" and role ~= "NONE"
    elseif filter == "nonDps" then
        show = role == "TANK" or role == "HEALER"
    elseif filter == "healers" then
        show = role == "HEALER"
    elseif filter == "tanks" then
        show = role == "TANK"
    else
        show = role ~= "" and role ~= "NONE"
    end

    if show then
        local art = GetRoleIconArt(cfg.iconType, displayRole) or GetRoleIconArt("standard", displayRole)
        if art and art.atlas then
            icon:SetAtlas(art.atlas, false)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:SetSize(GetScaledRoleIconSize(cfg.size, art))
            icon:Show()
        elseif art and art.texture then
            icon:SetTexture(art.texture)
            if art.texCoord then
                icon:SetTexCoord(unpack(art.texCoord))
            else
                icon:SetTexCoord(0, 1, 0, 1)
            end
            icon:SetSize(GetScaledRoleIconSize(cfg.size, art))
            icon:Show()
        else
            icon:Hide()
        end
    else
        icon:Hide()
    end
end

local function GetDebugRoleIconState(frame, unitKey)
    local cfg = UnitFrames:GetRoleIconConfig(unitKey)
    local unit = ResolveFrameUnit(frame)
    local role = (unit and UnitExists(unit) and UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)) or ""
    if role == "" then role = "NONE" end

    return {
        enabled = cfg.enabled == true,
        filter = cfg.filter or "all",
        role = role,
        shown = frame and frame.TwichRoleIcon and frame.TwichRoleIcon.IsShown and frame.TwichRoleIcon:IsShown() or false,
    }
end

-- ---------------------------------------------------------------------------
-- Extra Info Bar (Task 3)
-- ---------------------------------------------------------------------------

--- Returns the merged info bar config for a given unit key.
function UnitFrames:GetInfoBarConfig(unitKey)
    local db = self:GetDB()
    local scope = ResolveScopeByUnitKey(unitKey)

    local override = {}
    if scope == "singles" and unitKey and unitKey ~= "partyMember" and unitKey ~= "raidMember" and unitKey ~= "tankMember" then
        local u = db.units and db.units[unitKey] or {}
        override = type(u.infoBar) == "table" and u.infoBar or {}
    elseif scope ~= "singles" then
        local grp = db.groups and db.groups[scope] or {}
        override = type(grp.infoBar) == "table" and grp.infoBar or {}
    end

    local function get(k, default)
        if override[k] ~= nil then return override[k] end
        return default
    end

    local cfg = {
        enabled       = get("enabled", false),
        height        = get("height", 18),
        texture       = get("texture", nil),
        bgColor       = get("bgColor", nil),
        borderColor   = get("borderColor", nil),
        borderSize    = get("borderSize", 1),
        numTexts      = get("numTexts", 3),
        -- Font / style for the whole bar (nil = inherit from unit text config)
        fontName      = get("fontName", nil),
        outlineMode   = get("outlineMode", nil),
        shadowEnabled = get("shadowEnabled", nil),
        shadowColor   = get("shadowColor", nil),
        shadowOffsetX = get("shadowOffsetX", nil),
        shadowOffsetY = get("shadowOffsetY", nil),
        texts         = {},
    }

    for i = 1, 3 do
        local key = "text" .. i
        local def = INFO_BAR_TEXT_DEFAULTS[i]
        local src = type(override[key]) == "table" and override[key] or {}
        cfg.texts[i] = {
            tag           = src.tag ~= nil and src.tag or def.tag,
            justify       = src.justify or def.justify,
            fontSize      = src.fontSize or def.fontSize,
            useClassColor = src.useClassColor ~= nil and src.useClassColor or def.useClassColor,
            color         = src.color or nil,
        }
    end

    return cfg
end

--- Lazily creates the info bar frame below the given unit frame.
--- Width is matched to the TwichBackdrop visual edge (1px outset on each side).
function UnitFrames:EnsureInfoBar(frame)
    if frame.TwichInfoBar then return frame.TwichInfoBar end

    local bar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    -- outset by 1px on each side to align with the TwichBackdrop visual border
    bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -1, -2)
    bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 1, -2)
    bar:SetHeight(18)
    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
    bar:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)

    local texts = {}
    for i = 1, 3 do
        local fs = bar:CreateFontString(nil, "OVERLAY")
        texts[i] = fs
    end
    bar.infoTexts = texts
    bar:Hide()
    frame.TwichInfoBar = bar
    return bar
end

--- Applies info bar settings; lazily creates the bar frame if needed.
function UnitFrames:ApplyInfoBarSettings(frame, unitKey)
    if not frame then return end

    local cfg = self:GetInfoBarConfig(unitKey)

    if not cfg.enabled then
        if frame.TwichInfoBar then frame.TwichInfoBar:Hide() end
        return
    end

    local bar = self:EnsureInfoBar(frame)
    local h = Clamp(cfg.height, 8, 40)
    bar:SetHeight(h)

    -- Background color
    local bg = cfg.bgColor
    if bg then
        bar:SetBackdropColor(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.92)
    else
        bar:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
    end

    -- Border size + color
    local bSize = Clamp(cfg.borderSize or 1, 0, 3)
    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = bSize > 0 and "Interface\\Buttons\\WHITE8x8" or nil,
        edgeSize = bSize,
    })
    local bc = cfg.borderColor
    if bc then
        bar:SetBackdropBorderColor(bc[1] or 0.24, bc[2] or 0.26, bc[3] or 0.32, bc[4] or 0.9)
    else
        bar:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)
    end
    -- Reapply bg color after SetBackdrop reset it
    if bg then
        bar:SetBackdropColor(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.92)
    else
        bar:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
    end

    -- Optional texture overlay
    if cfg.texture and cfg.texture ~= "" then
        if not bar._bgTex then
            bar._bgTex = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
            bar._bgTex:SetAllPoints(bar)
        end
        local texPath = GetLSMTexture(cfg.texture)
        if texPath then
            bar._bgTex:SetTexture(texPath); bar._bgTex:Show()
        else
            bar._bgTex:Hide()
        end
    elseif bar._bgTex then
        bar._bgTex:Hide()
    end

    -- Build effective text style: info bar settings override frame text config
    local baseStyle = self:GetTextConfigFor(unitKey)
    local barStyle = {
        fontName      = cfg.fontName or baseStyle.fontName,
        outlineMode   = cfg.outlineMode or baseStyle.outlineMode,
        shadowEnabled = cfg.shadowEnabled ~= nil and cfg.shadowEnabled or baseStyle.shadowEnabled,
        shadowColor   = cfg.shadowColor or baseStyle.shadowColor,
        shadowOffsetX = cfg.shadowOffsetX ~= nil and cfg.shadowOffsetX or baseStyle.shadowOffsetX,
        shadowOffsetY = cfg.shadowOffsetY ~= nil and cfg.shadowOffsetY or baseStyle.shadowOffsetY,
    }

    -- Text slots
    local numTexts = math_max(1, math_min(cfg.numTexts or 3, 3))
    local texts = bar.infoTexts
    local tagApplied = false

    for i = 1, 3 do
        local fs = texts[i]
        if not fs then break end
        local tc = cfg.texts[i]

        if i <= numTexts then
            self:ApplyFontObject(fs, Clamp(tc.fontSize or 9, 6, 20), barStyle.fontName, barStyle)

            -- Color
            local classToken = nil
            if tc.useClassColor and frame.unit then
                local _, resolvedClassToken = UnitClass(frame.unit)
                classToken = resolvedClassToken
            elseif tc.useClassColor and frame and frame._testMockClass then
                classToken = frame._testMockClass
            end

            if tc.useClassColor and classToken then
                if classToken and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classToken] then
                    local c = _G.RAID_CLASS_COLORS[classToken]
                    fs:SetTextColor(c.r, c.g, c.b, 1)
                else
                    fs:SetTextColor(1, 1, 1, 1)
                end
            elseif tc.color then
                fs:SetTextColor(tc.color[1] or 1, tc.color[2] or 1, tc.color[3] or 1, tc.color[4] or 1)
            else
                fs:SetTextColor(1, 1, 1, 1)
            end

            fs:SetJustifyH(tc.justify or "CENTER")
            fs:SetHeight(h)
            fs:ClearAllPoints()

            if numTexts == 1 then
                fs:SetPoint("LEFT", bar, "LEFT", 4, 0)
                fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
            elseif numTexts == 2 then
                if i == 1 then
                    fs:SetPoint("LEFT", bar, "LEFT", 4, 0)
                    fs:SetPoint("RIGHT", bar, "CENTER", -2, 0)
                else
                    fs:SetPoint("LEFT", bar, "CENTER", 2, 0)
                    fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
                end
            else
                -- 3 equal columns anchored to thirds
                if i == 1 then
                    fs:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, 0)
                    fs:SetPoint("TOPRIGHT", bar, "TOP", -2, 0)
                elseif i == 2 then
                    fs:SetPoint("LEFT", bar, "LEFT", 4, 0)
                    fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
                    fs:SetJustifyH("CENTER")
                else
                    fs:SetPoint("TOPLEFT", bar, "TOP", 2, 0)
                    fs:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -4, 0)
                end
            end

            -- oUF tag
            if type(frame.Untag) == "function" then frame:Untag(fs) end
            if tc.tag and tc.tag ~= "" and type(frame.Tag) == "function" then
                frame:Tag(fs, tc.tag)
                tagApplied = true
            else
                fs:SetText("")
            end
            fs:Show()
        else
            if type(frame.Untag) == "function" then frame:Untag(fs) end
            fs:Hide()
        end
    end

    bar:Show()

    -- oUF tags are event-driven; force an immediate refresh so text
    -- appears right away when the user applies settings mid-session.
    if tagApplied and frame.unit and type(frame.UpdateAllElements) == "function" then
        C_Timer.After(0, function()
            if frame.unit and type(frame.UpdateAllElements) == "function" then
                frame:UpdateAllElements("TwichInfoBar")
            end
        end)
    end
end

function UnitFrames:ApplyStatusBarTexture(frame)
    local db = self:GetDB()

    -- Fill textures
    local textureName = db.texture
    local texture = (textureName and textureName ~= "") and GetLSMTexture(textureName) or GetThemeTexture()

    local powerTextureName = db.powerTexture
    local powerTexture = (powerTextureName and powerTextureName ~= "") and GetLSMTexture(powerTextureName) or texture

    -- Background / "lost" textures.  Each falls back to the corresponding fill texture
    -- so the appearance is unchanged for anyone who hasn't set them explicitly.
    local bgTextureName = db.bgTexture
    local bgTexture = (bgTextureName and bgTextureName ~= "") and GetLSMTexture(bgTextureName) or texture

    local powerBgTextureName = db.powerBgTexture
    local powerBgTexture = (powerBgTextureName and powerBgTextureName ~= "") and GetLSMTexture(powerBgTextureName) or
        bgTexture

    if frame.Health and frame.Health.SetStatusBarTexture then
        frame.Health:SetStatusBarTexture(texture)
    end
    if frame.Health and frame.Health.bg then
        frame.Health.bg:SetTexture(bgTexture)
    end
    if frame.Power and frame.Power.SetStatusBarTexture then
        frame.Power:SetStatusBarTexture(powerTexture)
    end
    if frame.Power and frame.Power.bg then
        frame.Power.bg:SetTexture(powerBgTexture)
    end
    if frame.Castbar and frame.Castbar.SetStatusBarTexture then
        frame.Castbar:SetStatusBarTexture(texture)
    end
    if frame.ClassPower then
        for i = 1, #frame.ClassPower do
            local bar = frame.ClassPower[i]
            if bar and bar.SetStatusBarTexture then
                bar:SetStatusBarTexture(texture)
            end
        end
    end
end

function UnitFrames:ApplyFrameColors(frame, unitKey)
    local resolvedUnit = frame and (frame.unit or nil)
    local palette = self:GetPalette(unitKey, resolvedUnit, frame and frame._testMockClass or nil)

    local backdrop = EnsureBackdrop(frame)
    backdrop:SetBackdropColor(palette.background[1], palette.background[2], palette.background[3], 0.9)
    backdrop:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 0.9)

    if frame.Health and frame.Health.SetStatusBarColor then
        frame.Health:SetStatusBarColor(palette.health[1], palette.health[2], palette.health[3], 1)
    end
    -- Tint the health background texture with the frame's background palette color.
    -- This keeps the "lost health" area visually consistent with the frame backdrop
    -- while still allowing a different texture shape/pattern via db.bgTexture.
    if frame.Health and frame.Health.bg then
        local bg = palette.background
        frame.Health.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 0.9)
    end
    if frame.Power and frame.Power.SetStatusBarColor then
        local powerCol = self:ResolvePowerColor(unitKey, resolvedUnit)
        frame.Power:SetStatusBarColor(powerCol[1], powerCol[2], powerCol[3], 1)
    end
    if frame.Power and frame.Power.bg then
        local pb = palette.powerBackground
        frame.Power.bg:SetVertexColor(pb[1], pb[2], pb[3], pb[4] or 0.85)
    end
    if frame.Power and frame.Power.border then
        local pb = palette.powerBorder
        frame.Power.border:SetBackdropBorderColor(pb[1], pb[2], pb[3], pb[4] or 0.9)
    end
    if frame.Castbar and frame.Castbar.SetStatusBarColor then
        frame.Castbar:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
    end
end

function UnitFrames:ApplyClassBarColors(frame, colorObject)
    if not frame or not frame.ClassPower then return end
    local cfg = self:GetDB().classBar or {}
    local r, g, b, a = 1, 1, 1, 1
    if cfg.useCustomColor == true and type(cfg.color) == "table" then
        r = cfg.color[1] or 1; g = cfg.color[2] or 1; b = cfg.color[3] or 1; a = cfg.color[4] or 1
    elseif colorObject and type(colorObject.GetRGB) == "function" then
        r, g, b = colorObject:GetRGB()
    else
        local palette = self:GetPalette("player", "player")
        r = palette.power[1]; g = palette.power[2]; b = palette.power[3]
    end
    -- Resolve background color
    local br, bg_, bb, ba
    if cfg.useCustomBackground == true and type(cfg.backgroundColor) == "table" then
        local c = cfg.backgroundColor
        br = c[1] or 0.05; bg_ = c[2] or 0.06; bb = c[3] or 0.08; ba = c[4] or 0.9
    else
        br = r; bg_ = g; bb = b; ba = math_max(0.16, (a or 1) * 0.28)
    end
    -- Resolve border color
    local er, eg, eb, ea
    if cfg.useCustomBorder == true and type(cfg.borderColor) == "table" then
        local c = cfg.borderColor
        er = c[1] or 0.24; eg = c[2] or 0.26; eb = c[3] or 0.32; ea = c[4] or 0.9
    else
        er = r; eg = g; eb = b; ea = math_max(0.45, (a or 1) * 0.65)
    end
    for i = 1, #frame.ClassPower do
        local bar = frame.ClassPower[i]
        if bar and bar.SetStatusBarColor then
            bar:SetStatusBarColor(r, g, b, a)
            if bar.SetBackdropColor then bar:SetBackdropColor(br, bg_, bb, ba) end
            if bar.SetBackdropBorderColor then bar:SetBackdropBorderColor(er, eg, eb, ea) end
        end
    end
end

function UnitFrames:ApplyFontObject(fontString, size, fontName, textStyle)
    if not fontString then return end

    local LSM = T.Libs and T.Libs.LSM
    local theme = GetThemeModule()
    local resolvedFont = fontName or (theme and theme.Get and theme:Get("globalFont")) or nil
    local path = nil

    if LSM and type(LSM.Fetch) == "function" and resolvedFont and resolvedFont ~= "__default" and resolvedFont ~= "" then
        local ok, fetched = pcall(LSM.Fetch, LSM, "font", resolvedFont)
        if ok and type(fetched) == "string" and fetched ~= "" then
            path = fetched
        end
    end

    if not path then path = _G.STANDARD_TEXT_FONT end

    fontString:SetFont(path, size or 11, ResolveOutlineFlags(textStyle and textStyle.outlineMode or "OUTLINE"))

    if textStyle and textStyle.shadowEnabled == true then
        local sc = type(textStyle.shadowColor) == "table" and textStyle.shadowColor or { 0, 0, 0, 0.85 }
        fontString:SetShadowColor(sc[1] or 0, sc[2] or 0, sc[3] or 0, sc[4] or 0.85)
        fontString:SetShadowOffset(tonumber(textStyle.shadowOffsetX) or 1, tonumber(textStyle.shadowOffsetY) or -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

function UnitFrames:GetTextConfig()
    local db = self:GetDB()
    db.text = db.text or {}
    local t = db.text
    if t.nameFormat == nil then t.nameFormat = "full" end
    if t.healthFormat == nil then t.healthFormat = "percent" end
    if t.powerFormat == nil then t.powerFormat = "percent" end
    if t.nameFontSize == nil then t.nameFontSize = 11 end
    if t.healthFontSize == nil then t.healthFontSize = 10 end
    if t.powerFontSize == nil then t.powerFontSize = 9 end
    if t.outlineMode == nil then t.outlineMode = "OUTLINE" end
    if t.shadowEnabled == nil then t.shadowEnabled = false end
    if t.shadowColor == nil then t.shadowColor = { 0, 0, 0, 0.85 } end
    if t.shadowOffsetX == nil then t.shadowOffsetX = 1 end
    if t.shadowOffsetY == nil then t.shadowOffsetY = -1 end
    return t
end

function UnitFrames:GetTextConfigFor(unitKey)
    local root = self:GetTextConfig()
    local scope = ResolveScopeByUnitKey(unitKey)

    root.scopes = root.scopes or {}
    root.scopes[scope] = root.scopes[scope] or {}
    local scoped = root.scopes[scope]

    -- Inherit root defaults into scope
    local fields = {
        { "nameFormat",     root.nameFormat or "full" },
        { "healthFormat",   root.healthFormat or "percent" },
        { "powerFormat",    root.powerFormat or "percent" },
        { "nameFontSize",   root.nameFontSize or 11 },
        { "healthFontSize", root.healthFontSize or 10 },
        { "powerFontSize",  root.powerFontSize or 9 },
        { "fontName",       root.fontName },
        { "outlineMode",    root.outlineMode or "OUTLINE" },
        { "shadowEnabled",  root.shadowEnabled == true },
        { "shadowColor",    root.shadowColor or { 0, 0, 0, 0.85 } },
        { "shadowOffsetX",  root.shadowOffsetX or 1 },
        { "shadowOffsetY",  root.shadowOffsetY or -1 },
        { "namePoint",      "LEFT" }, { "nameRelativePoint", "LEFT" },
        { "nameOffsetX", 4 }, { "nameOffsetY", 0 },
        { "healthPoint", "RIGHT" }, { "healthRelativePoint", "RIGHT" },
        { "healthOffsetX", -4 }, { "healthOffsetY", 0 },
        { "powerPoint",    "RIGHT" }, { "powerRelativePoint", "RIGHT" },
        { "powerOffsetX", -4 }, { "powerOffsetY", 0 },
    }
    for _, f in ipairs(fields) do
        if scoped[f[1]] == nil then scoped[f[1]] = f[2] end
    end

    -- Build merged result starting from scoped
    local merged = {}
    for _, f in ipairs(fields) do merged[f[1]] = scoped[f[1]] end
    merged.customNameTag   = scoped.customNameTag
    merged.customHealthTag = scoped.customHealthTag
    merged.customPowerTag  = scoped.customPowerTag
    merged.nameColor       = scoped.nameColor
    merged.healthColor     = scoped.healthColor
    merged.powerColor      = scoped.powerColor

    -- Apply per-unit overrides (not for group member types)
    if unitKey ~= "partyMember" and unitKey ~= "raidMember" and unitKey ~= "tankMember" then
        local db = self:GetDB()
        db.units = db.units or {}
        db.units[unitKey] = db.units[unitKey] or {}
        local unitText = type(db.units[unitKey].text) == "table" and db.units[unitKey].text or nil
        if unitText then
            for k, v in pairs(unitText) do
                if v ~= nil then merged[k] = v end
            end
        end
    end

    return merged
end

function UnitFrames:GetAuraConfigFor(unitKey)
    local db = self:GetDB()
    db.auras = db.auras or {}
    db.auras.scopes = db.auras.scopes or {}
    local scope = ResolveScopeByUnitKey(unitKey)
    db.auras.scopes[scope] = db.auras.scopes[scope] or {}
    local scoped = db.auras.scopes[scope]

    local merged = {
        enabled              = scoped.enabled,
        maxIcons             = scoped.maxIcons,
        iconSize             = scoped.iconSize,
        spacing              = scoped.spacing,
        yOffset              = scoped.yOffset,
        filter               = scoped.filter,
        onlyMine             = scoped.onlyMine,
        barMode              = scoped.barMode,
        barHeight            = scoped.barHeight,
        barTexture           = scoped.barTexture,
        barFontSize          = scoped.barFontSize,
        barFontName          = scoped.barFontName,
        showTime             = scoped.showTime,
        showStacks           = scoped.showStacks,
        barColor             = scoped.barColor,
        barBackground        = scoped.barBackground,
        barBorderColor       = scoped.barBorderColor,
        barTextColor         = scoped.barTextColor,
        buffBarTexture       = scoped.buffBarTexture,
        buffBarFontSize      = scoped.buffBarFontSize,
        buffBarFontName      = scoped.buffBarFontName,
        buffBarColor         = scoped.buffBarColor,
        buffBarBackground    = scoped.buffBarBackground,
        buffBarBorderColor   = scoped.buffBarBorderColor,
        buffBarTextColor     = scoped.buffBarTextColor,
        debuffBarTexture     = scoped.debuffBarTexture,
        debuffBarFontSize    = scoped.debuffBarFontSize,
        debuffBarFontName    = scoped.debuffBarFontName,
        debuffBarColor       = scoped.debuffBarColor,
        debuffBarBackground  = scoped.debuffBarBackground,
        debuffBarBorderColor = scoped.debuffBarBorderColor,
        debuffBarTextColor   = scoped.debuffBarTextColor,
    }
    if merged.enabled == nil then merged.enabled = true end
    if merged.maxIcons == nil then merged.maxIcons = 8 end
    if merged.iconSize == nil then merged.iconSize = 18 end
    if merged.spacing == nil then merged.spacing = 2 end
    if merged.yOffset == nil then merged.yOffset = 6 end
    if merged.filter == nil then merged.filter = "ALL" end
    if merged.onlyMine == nil then merged.onlyMine = false end
    if merged.barMode == nil then merged.barMode = false end
    if merged.barHeight == nil then merged.barHeight = 14 end
    if merged.barTexture == nil then merged.barTexture = nil end   -- nil = theme default
    if merged.barFontSize == nil then merged.barFontSize = nil end -- nil = auto (barH - 4)
    if merged.barFontName == nil then merged.barFontName = nil end -- nil = text fontName
    if merged.showTime == nil then merged.showTime = true end
    if merged.showStacks == nil then merged.showStacks = true end
    if merged.barColor == nil then merged.barColor = nil end           -- nil = palette.cast
    if merged.barBackground == nil then merged.barBackground = nil end -- nil = default backdrop
    if merged.barBorderColor == nil then merged.barBorderColor = nil end
    if merged.barTextColor == nil then merged.barTextColor = nil end
    if merged.buffBarTexture == nil then merged.buffBarTexture = nil end
    if merged.buffBarFontSize == nil then merged.buffBarFontSize = nil end
    if merged.buffBarFontName == nil then merged.buffBarFontName = nil end
    if merged.buffBarColor == nil then merged.buffBarColor = nil end
    if merged.buffBarBackground == nil then merged.buffBarBackground = nil end
    if merged.buffBarBorderColor == nil then merged.buffBarBorderColor = nil end
    if merged.buffBarTextColor == nil then merged.buffBarTextColor = nil end
    if merged.debuffBarTexture == nil then merged.debuffBarTexture = nil end
    if merged.debuffBarFontSize == nil then merged.debuffBarFontSize = nil end
    if merged.debuffBarFontName == nil then merged.debuffBarFontName = nil end
    if merged.debuffBarColor == nil then merged.debuffBarColor = nil end
    if merged.debuffBarBackground == nil then merged.debuffBarBackground = nil end
    if merged.debuffBarBorderColor == nil then merged.debuffBarBorderColor = nil end
    if merged.debuffBarTextColor == nil then merged.debuffBarTextColor = nil end

    -- Per-unit overrides (scope == "singles" only for named units)
    if scope == "singles" and unitKey ~= "partyMember" and unitKey ~= "raidMember" and unitKey ~= "tankMember" then
        db.units = db.units or {}
        db.units[unitKey] = db.units[unitKey] or {}
        local unitAuras = type(db.units[unitKey].auras) == "table" and db.units[unitKey].auras or nil
        if unitAuras then
            for k, v in pairs(unitAuras) do
                if v ~= nil then merged[k] = v end
            end
        end
    end
    return merged
end

local function GetAuraBarStyleValue(aura, isHarmfulAura, specificKey, genericKey)
    if isHarmfulAura then
        local debuffKey = "debuff" .. specificKey
        if aura[debuffKey] ~= nil then
            return aura[debuffKey]
        end
    else
        local buffKey = "buff" .. specificKey
        if aura[buffKey] ~= nil then
            return aura[buffKey]
        end
    end

    return aura[genericKey]
end

function UnitFrames:GetAuraBarAppearance(aura, data, palette, text)
    local isHarmfulAura = data and data.isHarmfulAura == true
    local textureName = GetAuraBarStyleValue(aura, isHarmfulAura, "BarTexture", "barTexture")
    local texture = (textureName and textureName ~= "") and GetLSMTexture(textureName) or GetThemeTexture()

    local fillColor = NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarColor", "barColor"), nil)
    local backgroundColor = NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarBackground", "barBackground"),
        nil)
    local borderColor = NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarBorderColor", "barBorderColor"), nil)
    local textColor = NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarTextColor", "barTextColor"), nil)
    local fontSize = GetAuraBarStyleValue(aura, isHarmfulAura, "BarFontSize", "barFontSize")
    local fontName = GetAuraBarStyleValue(aura, isHarmfulAura, "BarFontName", "barFontName") or text.fontName

    if not fillColor then
        fillColor = NormalizeColor(isHarmfulAura and palette.health or palette.cast, { 1, 1, 1, 0.85 })
    end

    return {
        textureName = textureName,
        texture = texture,
        fillColor = fillColor,
        backgroundColor = backgroundColor,
        borderColor = borderColor,
        textColor = textColor,
        fontSize = (fontSize and fontSize > 0) and fontSize or nil,
        fontName = fontName,
    }
end

local MAX_AURA_BARS = 12

function UnitFrames:EnsureAuraBarsContainer(frame)
    if frame.AuraBars then return frame.AuraBars end
    local container = CreateFrame("Frame", nil, frame)
    container.bars = {}
    for i = 1, MAX_AURA_BARS do
        local bar = CreateFrame("StatusBar", nil, container, "BackdropTemplate")
        bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        bar:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
        bar:SetBackdropBorderColor(0.16, 0.18, 0.24, 0.85)
        bar:SetMinMaxValues(0, 1); bar:SetValue(1)
        local icon = bar:CreateTexture(nil, "OVERLAY")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); bar.icon = icon
        local label = bar:CreateFontString(nil, "OVERLAY")
        label:SetJustifyH("LEFT"); label:SetWordWrap(false); bar.label = label
        local timeText = bar:CreateFontString(nil, "OVERLAY")
        timeText:SetJustifyH("RIGHT"); bar.timeText = timeText
        local stackText = bar:CreateFontString(nil, "OVERLAY")
        stackText:SetJustifyH("CENTER"); bar.stackText = stackText
        bar:SetScript("OnUpdate", function(self2, _)
            local remaining = UnitFrames:GetAuraRemainingTime(nil, self2._expiry, self2._duration)
            if not self2._usesDurationObjectFill then
                if remaining > 0 and self2._duration and self2._duration > 0 then
                    self2:SetValue(remaining)
                else
                    self2:SetValue((self2._duration and self2._duration > 0) and 0 or 1)
                end
            end

            if self2.timeText then
                UnitFrames:UpdateAuraRemainingText(self2.timeText, self2._durationObject, self2._expiry, self2._duration)
            end
        end)
        bar:Hide()
        container.bars[i] = bar
    end
    frame.AuraBars = container
    return container
end

local function CollectAuraData(list, unit, auraFilter, maxCount, onlyMine, filterMode)
    if not C_UnitAuras or not C_UnitAuras.GetAuraSlots or not IsValidAuraUnit(unit) then return end
    local playerFilter = auraFilter .. "|PLAYER"
    local slots = { C_UnitAuras.GetAuraSlots(unit, auraFilter) }
    for i = 2, #slots do
        local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
        if data then
            local timing = UnitFrames:ResolveAuraTiming(unit, data, "bars")
            local d = {}
            for k, v in pairs(data) do d[k] = v end
            d.name           = data.name
            d.icon           = data.icon
            d.auraInstanceID = data.auraInstanceID
            d.spellId        = data.spellId
            d.duration       = timing.duration
            d.expirationTime = timing.expirationTime
            d.applications   = timing.applications
            d.durationObject = timing.durationObject
            d.isPlayerAura   = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, data.auraInstanceID, playerFilter)
            d.isHarmfulAura  = auraFilter:find("HARMFUL") ~= nil
            if (not onlyMine or d.isPlayerAura) and AuraMatchesDisplayMode(filterMode, d) then
                list[#list + 1] = d
                if #list >= maxCount then return end
            end
        end
    end
end

function UnitFrames:RefreshAuraBarsForFrame(frame, unitKey)
    if not frame.AuraBars then return end
    local unit = frame.unit
    if not unit and not frame._isTestPreview then return end
    local aura       = self:GetAuraConfigFor(unitKey)
    local maxBars    = math_max(1, math_min(math.floor(tonumber(aura.maxIcons) or 8), MAX_AURA_BARS))
    local barH       = Clamp(aura.barHeight or 14, 8, 30)
    local spacing    = Clamp(aura.spacing or 2, 0, 8)
    local filter     = aura.filter or "ALL"
    local onlyMine   = aura.onlyMine == true
    local container  = frame.AuraBars
    local frameWidth = math_max(40, frame:GetWidth())
    local text       = self:GetTextConfigFor(unitKey)
    local palette    = self:GetPalette(unitKey, unit, frame and frame._testMockClass or nil)
    local showTime   = aura.showTime ~= false
    local showStacks = aura.showStacks ~= false

    local auraList   = {}
    if frame._isTestPreview then
        auraList = self:GetPreviewAuraListForFrame(frame, unitKey)
    elseif filter == "HELPFUL" then
        CollectAuraData(auraList, unit, "HELPFUL", maxBars, onlyMine, filter)
    elseif filter == "HARMFUL" or filter == "DISPELLABLE" or filter == "DISPELLABLE_OR_BOSS" then
        CollectAuraData(auraList, unit, "HARMFUL", maxBars, onlyMine, filter)
    else
        CollectAuraData(auraList, unit, "HELPFUL", maxBars, onlyMine, filter)
        if #auraList < maxBars then
            CollectAuraData(auraList, unit, "HARMFUL", maxBars - #auraList, onlyMine, filter)
        end
    end

    local shown = 0
    for i = 1, MAX_AURA_BARS do
        local bar = container.bars[i]
        if not bar then break end
        local data = (i <= maxBars) and auraList[i] or nil
        if data then
            local appearance = self:GetAuraBarAppearance(aura, data, palette, text)
            local texture = appearance.texture
            local barColor = appearance.fillColor
            local bgColor = appearance.backgroundColor
            local borderColor = appearance.borderColor
            local textColor = appearance.textColor
            local barFontSz = Clamp(appearance.fontSize or (barH - 4), 6, 20)
            local barFontNm = appearance.fontName
            bar:SetWidth(frameWidth); bar:SetHeight(barH)
            bar:ClearAllPoints()
            if i == 1 then
                bar:SetPoint("TOP", container, "TOP", 0, 0)
            else
                bar:SetPoint("TOP", container.bars[i - 1], "BOTTOM", 0, -spacing)
            end
            bar:SetStatusBarTexture(texture)
            -- Apply backdrop background override if set
            if bgColor then
                bar:SetBackdropColor(bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0, bgColor[4] or 0.95)
            else
                bar:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
            end
            if borderColor then
                bar:SetBackdropBorderColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0,
                    borderColor[4] or 0.85)
            else
                bar:SetBackdropBorderColor(0.16, 0.18, 0.24, 0.85)
            end
            local dur = tonumber(data.duration) or 0
            local exp = tonumber(data.expirationTime) or 0
            bar._durationObject = data.durationObject
            bar._usesDurationObjectFill = false
            bar._hasTimer = self:ShouldUseAuraTimerFill(data.durationObject, exp, dur)
            if bar._hasTimer and data.durationObject and bar.SetTimerDuration then
                local timerDirection = StatusBarTimerDirection and StatusBarTimerDirection.RemainingTime or nil
                local okTimer = false
                if timerDirection ~= nil and StatusBarInterpolation and StatusBarInterpolation.Immediate then
                    okTimer = pcall(bar.SetTimerDuration, bar, data.durationObject, StatusBarInterpolation.Immediate,
                        timerDirection)
                else
                    okTimer = pcall(bar.SetTimerDuration, bar, data.durationObject)
                end
                if okTimer then
                    bar._usesDurationObjectFill = true
                end
            end
            self:LogAuraAppearanceOnce(unit, data, appearance, bar._usesDurationObjectFill, texture)
            if bar._usesDurationObjectFill then
                bar._duration = dur; bar._expiry = exp
                if barColor then
                    ApplyStatusBarVisualColor(bar, barColor, 0.85)
                else
                    ApplyStatusBarVisualColor(bar, palette.cast, 0.85)
                end
            elseif dur > 0 then
                bar:SetMinMaxValues(0, dur)
                bar:SetValue(math_max(0, exp - GetTime()))
                bar._duration = dur; bar._expiry = exp
                if barColor then
                    ApplyStatusBarVisualColor(bar, barColor, 0.85)
                else
                    ApplyStatusBarVisualColor(bar, palette.cast, 0.85)
                end
            else
                bar:SetMinMaxValues(0, 1); bar:SetValue(1)
                bar._duration = 0; bar._expiry = 0
                bar._durationObject = nil
                bar._usesDurationObjectFill = false
                if barColor then
                    ApplyStatusBarVisualColor(bar, barColor, 0.7)
                else
                    ApplyStatusBarVisualColor(bar, palette.health, 0.7)
                end
            end
            if bar.icon then
                bar.icon:SetTexture(data.icon); bar.icon:SetSize(barH - 2, barH - 2)
                bar.icon:ClearAllPoints(); bar.icon:SetPoint("LEFT", bar, "LEFT", 1, 0)
            end
            -- Stacks text (shown left of time, right-aligned block)
            -- Reserve space for stacks and time on the right side
            local stackStr = (showStacks and data.applications and data.applications > 1)
                and tostring(data.applications) or nil
            local iconOffset = barH + 2
            local rightReserve = 0
            if showTime then rightReserve = rightReserve + 30 end
            if showStacks then rightReserve = rightReserve + 20 end
            if bar.label then
                self:ApplyFontObject(bar.label, barFontSz, barFontNm, text)
                if textColor then
                    bar.label:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
                else
                    bar.label:SetTextColor(1, 1, 1, 1)
                end
                bar.label:ClearAllPoints()
                bar.label:SetPoint("LEFT", bar, "LEFT", iconOffset, 0)
                bar.label:SetPoint("RIGHT", bar, "RIGHT", -(rightReserve + 4), 0)
                bar.label:SetText(data.name or "")
            end
            if bar.stackText then
                self:ApplyFontObject(bar.stackText, barFontSz, barFontNm, text)
                if textColor then
                    bar.stackText:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1,
                        textColor[4] or 1)
                else
                    bar.stackText:SetTextColor(1, 1, 1, 1)
                end
                bar.stackText:ClearAllPoints()
                if showStacks then
                    local stackRight = showTime and -34 or -4
                    bar.stackText:SetPoint("RIGHT", bar, "RIGHT", stackRight, 0)
                    bar.stackText:SetText(stackStr or "")
                    bar.stackText:SetShown(stackStr ~= nil)
                else
                    bar.stackText:SetText(""); bar.stackText:Hide()
                end
            end
            if bar.timeText then
                self:ApplyFontObject(bar.timeText, barFontSz, barFontNm, text)
                if textColor then
                    bar.timeText:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1,
                        textColor[4] or 1)
                else
                    bar.timeText:SetTextColor(1, 1, 1, 1)
                end
                bar.timeText:ClearAllPoints()
                if showTime then
                    bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
                    bar.timeText:SetShown(bar._usesDurationObjectFill or bar._hasTimer == true or dur > 0)
                else
                    bar.timeText:SetText(""); bar.timeText:Hide()
                end
            end
            bar:Show(); shown = shown + 1
        else
            bar._duration = nil; bar._expiry = nil; bar._durationObject = nil; bar._usesDurationObjectFill = false; bar._hasTimer = nil; bar
                :Hide()
        end
    end
    container:SetWidth(frameWidth)
    container:SetHeight(math_max(1, shown * barH + math_max(0, shown - 1) * spacing))
end

local function BuildHealthTag(format, customTag)
    if format == "custom" then
        return (customTag and customTag ~= "") and customTag or "[perhp<$%]"
    end
    if format == "current" then
        return "[curhp]"
    end
    if format == "currentPercent" then
        return "[curhp] [perhp<$%]"
    end
    if format == "missing" then
        return "[missinghp]"
    end
    return "[perhp<$%]"
end

local function BuildPowerTag(format, customTag)
    if format == "custom" then
        return (customTag and customTag ~= "") and customTag or "[perpp<$%]"
    end
    if format == "current" then
        return "[curpp]"
    end
    if format == "currentPercent" then
        return "[curpp] [perpp<$%]"
    end
    if format == "missing" then
        return "[missingpp]"
    end
    return "[perpp<$%]"
end

local function BuildNameTag(format, customTag)
    if format == "custom" then
        return (customTag and customTag ~= "") and customTag or "[name]"
    end
    if format == "short" then
        return "[name(8)]"
    end
    return "[name]"
end

function UnitFrames:ApplyTextTags(frame, unitKey)
    if not frame or type(frame.Tag) ~= "function" or type(frame.Untag) ~= "function" then
        return
    end

    local text      = self:GetTextConfigFor(unitKey)
    local nameTag   = BuildNameTag(text.nameFormat, text.customNameTag)
    local healthTag = BuildHealthTag(text.healthFormat, text.customHealthTag)
    local powerTag  = BuildPowerTag(text.powerFormat, text.customPowerTag)

    if frame.Name then
        frame:Untag(frame.Name)
        frame:Tag(frame.Name, nameTag)
        if frame.Name.UpdateTag then frame.Name:UpdateTag() end
    end
    if frame.HealthValue then
        frame:Untag(frame.HealthValue)
        frame:Tag(frame.HealthValue, healthTag)
        if frame.HealthValue.UpdateTag then frame.HealthValue:UpdateTag() end
    end
    if frame.PowerValue then
        frame:Untag(frame.PowerValue)
        frame:Tag(frame.PowerValue, powerTag)
        if frame.PowerValue.UpdateTag then frame.PowerValue:UpdateTag() end
    end
end

function UnitFrames:ApplyFrameFonts(frame, unitKey)
    local text = self:GetTextConfigFor(unitKey)
    if frame.Name then
        self:ApplyFontObject(frame.Name, Clamp(text.nameFontSize or 11, 6, 28), text.fontName, text)
        local nc = text.nameColor
        if nc then
            frame.Name:SetTextColor(nc[1] or 1, nc[2] or 1, nc[3] or 1, nc[4] or 1)
        else
            frame.Name:SetTextColor(1, 1, 1, 1)
        end
    end
    if frame.HealthValue then
        self:ApplyFontObject(frame.HealthValue, Clamp(text.healthFontSize or 10, 6, 28), text.fontName, text)
        local hc = text.healthColor
        if hc then
            frame.HealthValue:SetTextColor(hc[1] or 1, hc[2] or 1, hc[3] or 1, hc[4] or 1)
        else
            frame.HealthValue:SetTextColor(1, 1, 1, 1)
        end
    end
    if frame.PowerValue then
        self:ApplyFontObject(frame.PowerValue, Clamp(text.powerFontSize or 9, 6, 28), text.fontName, text)
        local pc = text.powerColor
        if pc then
            frame.PowerValue:SetTextColor(pc[1] or 1, pc[2] or 1, pc[3] or 1, pc[4] or 1)
        else
            frame.PowerValue:SetTextColor(1, 1, 1, 1)
        end
    end
end

local function PointToJustify(point)
    local p = tostring(point or "CENTER")
    if p:find("LEFT") then return "LEFT" end
    if p:find("RIGHT") then return "RIGHT" end
    return "CENTER"
end

local function AnchorText(fs, parent, point, relPoint, offX, offY, width)
    if not fs or not parent then return end
    fs:ClearAllPoints()
    fs:SetPoint(point or "CENTER", parent, relPoint or point or "CENTER", offX or 0, offY or 0)
    if width and fs.SetWidth then fs:SetWidth(math_max(1, width)) end
    fs:SetJustifyH(PointToJustify(point))
end

function UnitFrames:ApplyTextPositions(frame, unitKey)
    if not frame then return end
    local text = self:GetTextConfigFor(unitKey)
    local hw = math_max(20,
        (frame.Health and frame.Health:GetWidth() or 0) > 1 and frame.Health:GetWidth() or (frame:GetWidth() or 120))
    local pw = math_max(20,
        (frame.Power and frame.Power:GetWidth() or 0) > 1 and frame.Power:GetWidth() or (frame:GetWidth() or 120))
    if frame.Name and frame.Health then
        AnchorText(frame.Name, frame.Health,
            text.namePoint or "LEFT", text.nameRelativePoint or text.namePoint or "LEFT",
            tonumber(text.nameOffsetX) or 4, tonumber(text.nameOffsetY) or 0,
            math_max(16, hw - 16))
    end
    if frame.HealthValue and frame.Health then
        AnchorText(frame.HealthValue, frame.Health,
            text.healthPoint or "RIGHT", text.healthRelativePoint or text.healthPoint or "RIGHT",
            tonumber(text.healthOffsetX) or -4, tonumber(text.healthOffsetY) or 0,
            math_max(16, hw - 8))
    end
    if frame.PowerValue and frame.Power then
        AnchorText(frame.PowerValue, frame.Power,
            text.powerPoint or "RIGHT", text.powerRelativePoint or text.powerPoint or "RIGHT",
            tonumber(text.powerOffsetX) or -4, tonumber(text.powerOffsetY) or 0,
            math_max(16, pw - 8))
    end
end

function UnitFrames:ApplyAuraSettings(frame, unitKey)
    if not frame or not frame.Auras then return end
    local aura                  = self:GetAuraConfigFor(unitKey)
    local aurasEnabled          = aura.enabled ~= false
    local maxIcons              = math_max(1, math.floor(tonumber(aura.maxIcons) or 8))
    local iconSize              = Clamp(aura.iconSize or 18, 10, 40)
    local spacing               = Clamp(aura.spacing or 2, 0, 8)
    local yOff                  = Clamp(aura.yOffset or 6, -40, 60)
    local filter                = aura.filter or "ALL"
    local capturedUK            = unitKey

    frame.Auras.onlyShowPlayer  = aura.onlyMine == true
    frame.Auras.twichFilterMode = filter
    frame.Auras.FilterAura      = function(element, _, data)
        if element.onlyShowPlayer and data.isPlayerAura ~= true then return false end
        return AuraMatchesDisplayMode(element.twichFilterMode, data)
    end

    frame.Auras._forceHide      = (not aurasEnabled) or aura.barMode == true

    if aura.barMode == true then
        -- Bar mode: hide icon grid, show bar container
        frame.Auras.num = 0; frame.Auras.numTotal = 0
        frame.Auras.numBuffs = 0; frame.Auras.numDebuffs = 0
        frame.Auras:SetShown(false)
        local bars = self:EnsureAuraBarsContainer(frame)
        bars:ClearAllPoints()
        bars:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, yOff)
        bars:SetShown(aurasEnabled)
        self:RefreshAuraBarsForFrame(frame, unitKey)
    else
        -- Icon mode
        if frame.AuraBars then frame.AuraBars:Hide() end
        if not aurasEnabled then
            frame.Auras.num = 0; frame.Auras.numTotal = 0
            frame.Auras.numBuffs = 0; frame.Auras.numDebuffs = 0
            frame.Auras:SetShown(false)
        elseif filter == "HELPFUL" then
            frame.Auras.numBuffs = maxIcons; frame.Auras.numDebuffs = 0
            frame.Auras.numTotal = maxIcons
            frame.Auras.buffFilter = "HELPFUL"; frame.Auras.debuffFilter = nil
        elseif filter == "HARMFUL" or filter == "DISPELLABLE" or filter == "DISPELLABLE_OR_BOSS" then
            frame.Auras.numBuffs = 0; frame.Auras.numDebuffs = maxIcons
            frame.Auras.numTotal = maxIcons
            frame.Auras.buffFilter = nil; frame.Auras.debuffFilter = "HARMFUL"
        else
            frame.Auras.numBuffs = nil; frame.Auras.numDebuffs = nil
            frame.Auras.numTotal = maxIcons
            frame.Auras.buffFilter = nil; frame.Auras.debuffFilter = nil
        end
        if aurasEnabled then
            frame.Auras.num = maxIcons
            frame.Auras.size = iconSize
            frame.Auras.spacing = spacing
            frame.Auras.needFullUpdate = true
            frame.Auras:SetShown(true)
            frame.Auras:ClearAllPoints()
            frame.Auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, yOff)
            frame.Auras:SetHeight(iconSize)
            frame.Auras:SetWidth((iconSize * maxIcons) + (spacing * math_max(0, maxIcons - 1)))
            if frame._isTestPreview then
                self:RefreshPreviewAuraIcons(frame, unitKey)
            elseif frame.Auras.ForceUpdate then
                local resolvedUnit = frame.unit
                if resolvedUnit then
                    frame.Auras:ForceUpdate()
                else
                    frame.Auras:Hide()
                end
            end
        end
    end

    -- Wire up PostUpdate to refresh bars and trigger custom aura indicators.
    frame.Auras.PostUpdate = function()
        if aura.barMode == true and frame.AuraBars and frame.AuraBars:IsShown() then
            UnitFrames:RefreshAuraBarsForFrame(frame, capturedUK)
        end
        UnitFrames:AWUpdate(frame)
    end

    -- Configure custom aura watcher indicators for this frame/scope.
    self:AWConfigure(frame, capturedUK)
end

function UnitFrames:ApplyClassBarSettings(frame, unitKey)
    if unitKey ~= "player" or not frame.ClassPower or not frame.ClassPower.container then return end
    local db      = self:GetDB()
    local cfg     = db.classBar or {}
    local enabled = cfg.enabled ~= false

    UFDebug(string.format("ApplyClassBarSettings: unitKey=%s enabled=%s matchFrameWidth=%s cfgWidth=%s",
        tostring(unitKey), tostring(enabled), tostring(cfg.matchFrameWidth), tostring(cfg.width)))

    -- ForceUpdate first so oUF shows/hides the correct individual bars based on
    -- the player's current class resource count. We then read back how many are
    -- actually shown and use that as the segment count for layout calculations.
    -- Guard flag prevents ForceUpdate from re-entering this function via PostUpdate.
    frame.ClassPower._applyingSettings = true
    if frame.ClassPower.ForceUpdate then frame.ClassPower:ForceUpdate() end
    frame.ClassPower._applyingSettings = nil
    local maxBars = #frame.ClassPower
    local segmentCount = 0
    for i = 1, maxBars do
        if frame.ClassPower[i] and frame.ClassPower[i]:IsShown() then
            segmentCount = segmentCount + 1
        end
    end
    if segmentCount == 0 then segmentCount = maxBars end
    UFDebug(string.format("ApplyClassBarSettings: maxBars=%d segmentCount=%d frameWidth=%.1f",
        maxBars, segmentCount, frame:GetWidth()))

    local width
    if cfg.matchFrameWidth == true then
        width = Clamp(frame:GetWidth(), 40, 600)
    else
        width = Clamp(cfg.width or math_max(frame:GetWidth(), 260), 40, 600)
    end
    local height    = Clamp(cfg.height or 10, 4, 40)
    local spacing   = Clamp(cfg.spacing or 2, 0, 40)
    local texName   = (db.texture and db.texture ~= "") and db.texture or nil
    local texture   = texName and GetLSMTexture(texName) or GetThemeTexture()
    local container = frame.ClassPower.container
    container:ClearAllPoints()
    container:SetPoint(
        cfg.point or "TOPLEFT", frame,
        cfg.relativePoint or "BOTTOMLEFT",
        tonumber(cfg.xOffset) or 0,
        tonumber(cfg.yOffset) or -2)
    container:SetSize(width, height)
    local barWidth = math_max(4, (width - spacing * math_max(0, segmentCount - 1)) / math_max(1, segmentCount))
    for i = 1, maxBars do
        local bar = frame.ClassPower[i]
        bar:ClearAllPoints(); bar:SetSize(barWidth, height)
        if i == 1 then
            bar:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", frame.ClassPower[i - 1], "RIGHT", spacing, 0)
        end
        bar:SetStatusBarTexture(texture)
        if not enabled then bar:Hide() end
    end
    container:SetShown(enabled)
    self:ApplyClassBarColors(frame)
    -- No second ForceUpdate needed — already done above.
end

function UnitFrames:GetCastbarSmoothingMethod()
    if not StatusBarInterpolation then return nil end
    if self:GetDB().smoothBars == false then return StatusBarInterpolation.Immediate end
    return StatusBarInterpolation.Linear or StatusBarInterpolation.ExponentialEaseOut
end

function UnitFrames:ApplyCastbarValue(bar, value, maxValue)
    if not bar or not bar.SetMinMaxValues or not bar.SetValue then return end
    local sm = self:GetCastbarSmoothingMethod()
    bar.smoothing = sm
    pcall(bar.SetMinMaxValues, bar, 0, maxValue)
    if sm then
        local ok = pcall(bar.SetValue, bar, value, sm)
        if ok then return end
    end
    pcall(bar.SetValue, bar, value)
end

function UnitFrames:ApplyUnitCastbarSettings(frame, unitKey)
    if not frame.Castbar then return end
    local db              = self:GetDB()
    local scope           = ResolveCastbarScopeByUnitKey(unitKey)
    local cfg             = (db.castbars and db.castbars[scope]) or {}
    local enabled         = cfg.enabled ~= false
    local detached        = cfg.detached == true
    local barH            = Clamp(cfg.height or 12, 4, 40)
    local palette         = self:GetPalette(unitKey, frame.unit)
    local text            = self:GetTextConfigFor(unitKey)
    local texName         = (db.texture and db.texture ~= "") and db.texture or nil
    local texture         = texName and GetLSMTexture(texName) or GetThemeTexture()
    local backgroundColor = palette.background
    local backgroundAlpha = 0.9

    if cfg.useCustomBackground == true and type(cfg.backgroundColor) == "table" then
        backgroundColor = cfg.backgroundColor
        backgroundAlpha = cfg.backgroundColor[4] or 1
    end

    frame.Castbar:SetHeight(barH)
    frame.Castbar.smoothing = self:GetCastbarSmoothingMethod()
    frame.Castbar:ClearAllPoints()
    if detached then
        frame.Castbar:SetWidth(Clamp(cfg.width or math_max(frame:GetWidth(), 220), 40, 600))
        frame.Castbar:SetPoint(
            cfg.point or "TOPLEFT", frame, cfg.relativePoint or "BOTTOMLEFT",
            tonumber(cfg.xOffset) or 0, tonumber(cfg.yOffset) or -2)
    else
        local yOff = -(tonumber(cfg.yOffset) or 2)
        frame.Castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, yOff)
        frame.Castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, yOff)
    end
    frame.Castbar:SetStatusBarTexture(texture)
    if cfg.useCustomColor == true and type(cfg.color) == "table" then
        local c = cfg.color
        frame.Castbar:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    else
        frame.Castbar:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
    end
    frame.Castbar:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundAlpha)
    frame.Castbar:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 0.9)
    if frame.Castbar.Text then
        self:ApplyFontObject(frame.Castbar.Text, Clamp(cfg.fontSize or 9, 6, 20), text.fontName, text)
        frame.Castbar.Text:SetShown(cfg.showText ~= false)
    end
    if frame.Castbar.Time then
        self:ApplyFontObject(frame.Castbar.Time, Clamp(cfg.timeFontSize or 9, 6, 20), text.fontName, text)
        frame.Castbar.Time:SetShown(cfg.showTimeText ~= false)
    end
    if frame.Castbar.Icon then
        local iconSize = Clamp(cfg.iconSize or math_max(4, barH - 2), 4, 60)
        local showIcon = cfg.showIcon ~= false
        local iconPos  = cfg.iconPosition or "outside"
        local iconSide = cfg.iconSide or "left"
        frame.Castbar.Icon:SetDrawLayer("OVERLAY")
        frame.Castbar.Icon:SetSize(iconSize, iconSize)
        frame.Castbar.Icon:SetShown(showIcon)
        frame.Castbar.Icon:ClearAllPoints()
        if iconPos == "inside" then
            if iconSide == "right" then
                frame.Castbar.Icon:SetPoint("RIGHT", frame.Castbar, "RIGHT", -4, 0)
            else
                frame.Castbar.Icon:SetPoint("LEFT", frame.Castbar, "LEFT", 4, 0)
            end
        else
            if iconSide == "right" then
                frame.Castbar.Icon:SetPoint("LEFT", frame.Castbar, "RIGHT", 4, 0)
            else
                frame.Castbar.Icon:SetPoint("RIGHT", frame.Castbar, "LEFT", -4, 0)
            end
        end
        -- Adjust spell text to avoid overlapping an inside icon
        if frame.Castbar.Text then
            frame.Castbar.Text:ClearAllPoints()
            if showIcon and iconPos == "inside" then
                if iconSide == "right" then
                    frame.Castbar.Text:SetPoint("LEFT", frame.Castbar, "LEFT", 4, 0)
                    frame.Castbar.Text:SetPoint("RIGHT", frame.Castbar, "RIGHT", -(iconSize + 8), 0)
                else
                    frame.Castbar.Text:SetPoint("LEFT", frame.Castbar, "LEFT", iconSize + 8, 0)
                    frame.Castbar.Text:SetPoint("RIGHT", frame.Castbar, "RIGHT", -4, 0)
                end
            else
                frame.Castbar.Text:SetPoint("LEFT", frame.Castbar, "LEFT", 4, 0)
                frame.Castbar.Text:SetPoint("RIGHT", frame.Castbar, "RIGHT", -30, 0)
            end
        end
    end
    frame.Castbar._forceHide = not enabled
    if not enabled then
        frame.Castbar:Hide()
    else
        local unit = frame.unit
        local isCasting = unit and (UnitCastingInfo(unit) or UnitChannelInfo(unit))
        if isCasting and frame.Castbar.ForceUpdate then
            frame.Castbar:ForceUpdate()
        else
            frame.Castbar:Hide()
        end
    end
end

function UnitFrames:UpdateUnitHighlights(frame)
    if not frame then return end
    local db               = self:GetDB()
    local highlights       = db.highlights or {}
    local unit             = frame.unit
    local unitKey          = frame._unitKey or unit
    -- Per-unit overrides stored at db.units[unitKey].highlights
    local unitHL           = (db.units and db.units[unitKey] and db.units[unitKey].highlights) or {}
    local targetEnabled    = highlights.showTarget ~= false and unitHL.showTarget ~= false
    local mouseoverEnabled = highlights.showMouseover ~= false and unitHL.showMouseover ~= false

    -- Reset both target elements before deciding which to show
    if frame.TwichTargetHighlight then frame.TwichTargetHighlight:Hide() end
    if frame.TwichTargetGlow then frame.TwichTargetGlow:Hide() end

    if targetEnabled then
        local showTarget = false
        if unit and unit ~= "" then
            local ok, isUnit = pcall(_G.UnitIsUnit, unit, "target")
            showTarget = ok and isUnit == true
        end
        if showTarget then
            local c    = highlights.targetColor or { 1.0, 0.82, 0.0, 0.9 }
            local mode = highlights.targetMode or "border"
            if mode == "glow" and frame.TwichTargetGlow then
                local r, g, b = c[1] or 1, c[2] or 0.82, c[3] or 0
                local a = c[4] or 0.9
                local gf = frame.TwichTargetGlow
                -- VERTICAL: bottom→top. TOP edge: color at bottom (frame edge), fade to transparent at top.
                SetGradientCompat(gf._top, "VERTICAL", r, g, b, a, r, g, b, 0)
                -- BOT edge: transparent at bottom, color at top (frame edge).
                SetGradientCompat(gf._bottom, "VERTICAL", r, g, b, 0, r, g, b, a)
                -- HORIZONTAL: left→right. LEFT edge: transparent at left, color at right (frame edge).
                SetGradientCompat(gf._left, "HORIZONTAL", r, g, b, 0, r, g, b, a)
                -- RIGHT edge: color at left (frame edge), transparent at right.
                SetGradientCompat(gf._right, "HORIZONTAL", r, g, b, a, r, g, b, 0)
                gf:Show()
            elseif frame.TwichTargetHighlight then
                frame.TwichTargetHighlight:SetBackdropBorderColor(c[1] or 1, c[2] or 0.82, c[3] or 0, c[4] or 0.9)
                frame.TwichTargetHighlight:Show()
            end
        end
    end

    if frame.TwichMouseoverHighlight then
        if mouseoverEnabled and frame.isHovering then
            local c = highlights.mouseoverColor or { 1.0, 1.0, 1.0, 0.08 }
            frame.TwichMouseoverHighlight:SetBackdropColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 0.08)
            frame.TwichMouseoverHighlight:Show()
        else
            frame.TwichMouseoverHighlight:Hide()
        end
    end
end

function UnitFrames:ApplyHighlightSettings(frame)
    if not frame then return end
    local highlights = self:GetDB().highlights or {}
    local width = Clamp(highlights.targetWidth or 2, 1, 12)
    if frame.TwichTargetHighlight then
        frame.TwichTargetHighlight:ClearAllPoints()
        frame.TwichTargetHighlight:SetPoint("TOPLEFT", frame, "TOPLEFT", -width, width)
        frame.TwichTargetHighlight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", width, -width)
        frame.TwichTargetHighlight:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = width })
    end
    if frame.TwichTargetGlow then
        local gf = frame.TwichTargetGlow
        local spread = math_max(4, width * 3)
        -- Top edge: above the frame, gradient fades upward
        gf._top:ClearAllPoints()
        gf._top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
        gf._top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, spread)
        -- Bottom edge: below the frame
        gf._bottom:ClearAllPoints()
        gf._bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
        gf._bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -spread)
        -- Left edge
        gf._left:ClearAllPoints()
        gf._left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
        gf._left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -spread, 0)
        -- Right edge
        gf._right:ClearAllPoints()
        gf._right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
        gf._right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", spread, 0)
    end
    self:UpdateUnitHighlights(frame)
end

function UnitFrames:ApplyTagVisibility(frame)
    local db = self:GetDB()
    local showHealth = db.showHealthText ~= false
    local showPower = db.showPowerText ~= false

    if frame.HealthValue then
        frame.HealthValue:SetShown(showHealth)
    end

    if frame.PowerValue then
        frame.PowerValue:SetShown(showPower)
    end
end

function UnitFrames:ApplySmoothBarValue(bar, value, maxValue)
    if not bar or not bar.SetMinMaxValues or not bar.SetValue then
        return
    end

    local hasInterpolation = StatusBarInterpolation and StatusBarInterpolation.ExponentialEaseOut
    local smoothEnabled = self:GetDB().smoothBars ~= false and hasInterpolation
    local smoothingMethod = smoothEnabled and StatusBarInterpolation.ExponentialEaseOut or
        (StatusBarInterpolation and StatusBarInterpolation.Immediate or nil)

    bar.smoothing = smoothingMethod

    local okMinMax = pcall(bar.SetMinMaxValues, bar, 0, maxValue)
    if not okMinMax then
        pcall(bar.SetMinMaxValues, bar, 0, 1)
    end

    if smoothingMethod then
        local okSmoothed = pcall(bar.SetValue, bar, value, smoothingMethod)
        if okSmoothed then
            return
        end
    end

    pcall(bar.SetValue, bar, value)
end

function UnitFrames:StopSmoothBar(bar)
    if not bar then
        return
    end

    bar.smoothing = nil
end

function UnitFrames:ApplyUnitFrameSize(frame, settings, unitKey)
    local width  = Clamp(settings.width or 220, 80, 600)
    local height = Clamp(settings.height or 42, 16, 180)
    frame:SetSize(width, height)

    if frame.Health and frame.Power then
        local powerHeight = settings.showPower == false and 0 or Clamp(settings.powerHeight or 10, 4, 32)
        local detached    = settings.powerDetached == true
        frame.Health:ClearAllPoints()
        frame.Power:ClearAllPoints()

        UFDebug(string.format("ApplyUnitFrameSize: key=%s size=%dx%d powerH=%d detached=%s showPower=%s",
            tostring(unitKey), width, height, powerHeight, tostring(detached), tostring(settings.showPower)))
        if powerHeight > 0 then
            -- Power is on — clear the force-hide guard and re-enable if oUF disabled it.
            frame.Power._forceHide = nil
            frame.Power._ownerFrame = frame
            frame.Power._detached = detached
            frame.Power:SetAlpha(1)
            if frame.Power.border then frame.Power.border:SetAlpha(1) end
            frame.Power:Show()
            if detached then
                frame.Power._designedHeight = powerHeight -- stored for runtime collapse/restore
                frame.Power:SetWidth(Clamp(settings.powerWidth or width, 40, 600))
                frame.Power:SetHeight(powerHeight)
                -- If the power bar has been freely placed by its mover, an absolute
                -- position is stored in layout[unitKey.."_power"]. Use UIParent anchoring
                -- in that case so the bar stays put when the unit frame moves.
                local powerLayout = unitKey and self:GetLayoutSettings(unitKey .. "_power") or nil
                if powerLayout and powerLayout.point == "BOTTOMLEFT" and powerLayout.x ~= nil then
                    frame.Power:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
                        tonumber(powerLayout.x) or 0,
                        tonumber(powerLayout.y) or 0)
                else
                    frame.Power:SetPoint(
                        settings.powerPoint or "TOPLEFT", frame,
                        settings.powerRelativePoint or "BOTTOMLEFT",
                        tonumber(settings.powerOffsetX) or 0,
                        tonumber(settings.powerOffsetY) or -1)
                end
                frame.Health:SetAllPoints(frame)
            else
                frame.Power._designedHeight = powerHeight -- stored for runtime collapse/restore
                frame.Power:SetHeight(powerHeight)
                frame.Power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                frame.Power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                frame.Health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                frame.Health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
                -- Offset 0 (not 1): when power height collapses to 0, health fills the
                -- entire frame with no residual 1px gap showing as a black hairline.
                frame.Health:SetPoint("BOTTOM", frame.Power, "TOP", 0, 0)
            end

            -- For healer-only group member frames, pre-apply role-based collapse
            -- immediately so the power bar never flashes visible during the spawn →
            -- RefreshAllFrames window. frame.unit may be nil (fresh spawn before oUF
            -- assigns it) or a tainted secret string — both safe for this call.
            if unitKey == "partyMember" or unitKey == "raidMember" then
                local healerOnly = (unitKey == "partyMember" and self:GetGroupSettings("party").healerOnlyPower ~= false)
                    or (unitKey == "raidMember" and self:GetGroupSettings("raid").healerOnlyPower ~= false)
                if healerOnly then
                    frame.Power._roleCollapsed = nil -- force fresh evaluation
                    self:UpdatePowerBarForRole(frame.Power, unitKey, frame.unit)
                end
            end
        else
            -- Power is off — set the force-hide flag so the OnShow hook keeps it hidden
            -- even when oUF's Enable() or any oUF event calls power:Show().
            frame.Power._forceHide = true
            frame.Power._ownerFrame = frame
            frame.Power._detached = false
            frame.Power:SetAlpha(0)
            if frame.Power.border then frame.Power.border:SetAlpha(0) end
            frame.Power:Hide()
            frame.Power:SetHeight(0)
            if frame.Power.border then frame.Power.border:Hide() end
            frame.Power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            frame.Power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            frame.Health:SetAllPoints(frame)
        end
    end
end

function UnitFrames:ApplySingleFrameSettings(frame, unitKey)
    local settings = nil
    if unitKey and unitKey:match("^boss%d+$") then
        settings = self:GetUnitSettings("boss")
    elseif unitKey == "partyMember" then
        local group = self:GetGroupSettings("party")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = true,
            powerHeight = 8,
        }
    elseif unitKey == "raidMember" then
        local group = self:GetGroupSettings("raid")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = true,
            powerHeight = 7,
        }
    elseif unitKey == "tankMember" then
        local group = self:GetGroupSettings("tank")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = true,
            powerHeight = 8,
        }
    else
        settings = self:GetUnitSettings(unitKey)
    end

    local layout = self:GetLayoutSettings(unitKey)

    self:ApplyUnitFrameSize(frame, settings, unitKey)

    if not frame.isHeaderChild then
        frame:ClearAllPoints()
        frame:SetPoint(
            layout.point or "BOTTOM",
            UIParent,
            layout.relativePoint or "BOTTOM",
            tonumber(layout.x) or 0,
            tonumber(layout.y) or 0
        )
    end

    local db = self:GetDB()
    frame:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
    frame:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))

    -- Header children (party/raid/tank members) have their visibility fully managed
    -- by SecureGroupHeaderTemplate + RegisterUnitWatch.  Calling SetShown from insecure
    -- code interferes with that mechanism and can cause frames to stay hidden even when
    -- the unit exists.  Only apply explicit show/hide for standalone (non-header) frames.
    if not frame.isHeaderChild then
        frame._forceHideFrame = db.testMode == true and not frame._isTestPreview
        local shouldShow = settings.enabled ~= false
        if frame._forceHideFrame then
            shouldShow = false
        end
        frame:SetShown(shouldShow)
    end

    self:ApplyStatusBarTexture(frame)
    self:ApplyFrameColors(frame, unitKey)
    self:ApplyFrameFonts(frame, unitKey)
    self:ApplyTextTags(frame, unitKey)
    self:ApplyTextPositions(frame, unitKey)
    self:ApplyAuraSettings(frame, unitKey)
    self:ApplyTagVisibility(frame)
    self:ApplyClassBarSettings(frame, unitKey)
    self:ApplyHighlightSettings(frame)
    self:ApplyUnitCastbarSettings(frame, unitKey)
    self:ApplyRoleIconSettings(frame, unitKey)
    self:ApplyInfoBarSettings(frame, unitKey)
end

function UnitFrames:ApplyHeaderSettings(header, groupKey)
    local settings = self:GetGroupSettings(groupKey)
    local layout = self:GetLayoutSettings(groupKey)
    local testMode = self:GetDB().testMode == true

    local enabled = settings.enabled ~= false
    UFDebug(string.format("ApplyHeaderSettings: key=%s enabled=%s layout=(%s,%s,%.0f,%.0f)",
        groupKey, tostring(enabled),
        tostring(layout.point or "CENTER"), tostring(layout.relativePoint or "CENTER"),
        tonumber(layout.x) or 0, tonumber(layout.y) or 0))

    header:ClearAllPoints()
    header:SetPoint(
        layout.point or "CENTER",
        UIParent,
        layout.relativePoint or "CENTER",
        tonumber(layout.x) or 0,
        tonumber(layout.y) or 0
    )

    header:SetAttribute("point", settings.point or "TOP")
    header:SetAttribute("xOffset", tonumber(settings.xOffset) or 0)
    header:SetAttribute("yOffset", tonumber(settings.yOffset) or -6)
    header:SetAttribute("unitsPerColumn", math_max(1, tonumber(settings.unitsPerColumn) or 5))
    header:SetAttribute("maxColumns", math_max(1, tonumber(settings.maxColumns) or 1))
    header:SetAttribute("columnSpacing", tonumber(settings.columnSpacing) or 8)
    header:SetAttribute("columnAnchorPoint", settings.columnAnchorPoint or "LEFT")

    if groupKey == "party" then
        header:SetAttribute("showParty", enabled)
        header:SetAttribute("showPlayer", settings.showPlayer == true)
        header:SetAttribute("showSolo", settings.showSolo == true)
        UFDebug(string.format("ApplyHeaderSettings: party showParty=%s showPlayer=%s showSolo=%s",
            tostring(enabled), tostring(settings.showPlayer == true), tostring(settings.showSolo == true)))
        -- Register a macro-conditional visibility driver so SecureGroupHeaderTemplate
        -- will automatically show/hide and SPAWN CHILDREN when the player is in a group.
        -- Without this call the header stays 0x0/hidden and no child frames are ever created.
        if enabled and not testMode then
            header:SetVisibility('party')
        else
            header:SetVisibility('custom hide')
        end
    elseif groupKey == "raid" then
        header:SetAttribute("showRaid", enabled)
        header:SetAttribute("showParty", false)
        header:SetAttribute("showSolo", settings.showSolo == true)
        header:SetAttribute("groupBy", settings.groupBy or "GROUP")
        header:SetAttribute("groupingOrder", settings.groupingOrder or "1,2,3,4,5,6,7,8")
        if enabled and not testMode then
            header:SetVisibility('raid')
        else
            header:SetVisibility('custom hide')
        end
    elseif groupKey == "tank" then
        header:SetAttribute("showRaid", enabled)
        header:SetAttribute("showParty", false)
        header:SetAttribute("showSolo", settings.showSolo == true)
        header:SetAttribute("groupFilter", settings.groupFilter or "MAINTANK,MAINASSIST")
        if enabled and not testMode then
            header:SetVisibility('raid')
        else
            header:SetVisibility('custom hide')
        end
    end

    header:SetScale(Clamp(self:GetDB().scale or 1, 0.6, 1.6))
    header:SetAlpha(Clamp(self:GetDB().frameAlpha or 1, 0.15, 1))

    -- Determine the unitKey used for member frames of this group.
    local memberUnitKey = (groupKey == "party" and "partyMember")
        or (groupKey == "raid" and "raidMember")
        or (groupKey == "tank" and "tankMember")

    -- Propagate appearance and text changes to all already-spawned member frames.
    for i = 1, select('#', header:GetChildren()) do
        local child = select(i, header:GetChildren())
        if child then
            if child.TwichTargetHighlight then
                self:ApplyHighlightSettings(child)
            end
            if child.Health and memberUnitKey then
                self:ApplyFrameColors(child, memberUnitKey)
                self:ApplyStatusBarTexture(child)
                self:ApplyFrameFonts(child, memberUnitKey)
                self:ApplyTextTags(child, memberUnitKey)
                self:ApplyTextPositions(child, memberUnitKey)
                self:ApplyRoleIconSettings(child, memberUnitKey)
                self:ApplyInfoBarSettings(child, memberUnitKey)
                -- Re-evaluate healer-only power bar visibility immediately so layout
                -- changes take effect without waiting for the next power event.
                if child.Power then
                    -- child.unit / GetAttribute("unit") on secure-header children is a
                    -- tainted "secret" string — safe to PASS to WoW APIs but NOT to
                    -- format into strings. Log only the safe memberUnitKey.
                    local childUnit = child:GetAttribute("unit") or child.unit
                    UFDebug(string.format("ApplyHeaderSettings: UpdatePowerBarForRole child key=%s",
                        tostring(memberUnitKey)))
                    -- Clear the role-collapse cache so that ApplyUnitFrameSize having just
                    -- restored SetHeight(designedHeight) doesn't cause an early return here.
                    child.Power._roleCollapsed = nil
                    self:UpdatePowerBarForRole(child.Power, memberUnitKey, childUnit)
                end
            end
        end
    end
end

function UnitFrames:ApplyBossLayout()
    if not self.bossAnchor then
        return
    end

    local layout = self:GetLayoutSettings("boss")
    local settings = self:GetGroupSettings("boss")

    self.bossAnchor:ClearAllPoints()
    self.bossAnchor:SetPoint(
        layout.point or "RIGHT",
        UIParent,
        layout.relativePoint or "RIGHT",
        tonumber(layout.x) or -300,
        tonumber(layout.y) or 0
    )

    local showBossFrames = settings.enabled ~= false and self:GetDB().testMode ~= true
    self.bossAnchor:SetScale(Clamp(self:GetDB().scale or 1, 0.6, 1.6))
    self.bossAnchor:SetAlpha(Clamp(self:GetDB().frameAlpha or 1, 0.15, 1))
    self.bossAnchor:SetShown(showBossFrames)

    local yOffset = tonumber(settings.yOffset) or -8
    for index = 1, 5 do
        local frame = self.frames["boss" .. index]
        if frame then
            frame:ClearAllPoints()
            if index == 1 then
                frame:SetPoint("TOP", self.bossAnchor, "TOP", 0, 0)
            else
                frame:SetPoint("TOP", self.frames["boss" .. (index - 1)], "BOTTOM", 0, yOffset)
            end
            frame:SetShown(showBossFrames)
        end
    end
end

function UnitFrames:PersistLayoutFromFrame(layoutKey, frame, absX, absY)
    local layout = self:GetLayoutSettings(layoutKey)
    layout.point = "BOTTOMLEFT"
    layout.relativePoint = "BOTTOMLEFT"
    layout.x = math.floor((absX or 0) + 0.5)
    layout.y = math.floor((absY or 0) + 0.5)

    if frame and frame.GetWidth and frame.GetHeight then
        local width = frame:GetWidth()
        local height = frame:GetHeight()
        if width and width > 0 then
            local unitSettings = self:GetUnitSettings(layoutKey)
            if unitSettings and unitSettings.width ~= nil then
                unitSettings.width = math.floor(width + 0.5)
            end
        end
        if height and height > 0 then
            local unitSettings = self:GetUnitSettings(layoutKey)
            if unitSettings and unitSettings.height ~= nil then
                unitSettings.height = math.floor(height + 0.5)
            end
        end
    end
end

-- Singleton inspector panel shown when hovering a mover handle.
-- Displays the frame name, editable X/Y/W/H fields, and nudge buttons.
function UnitFrames:GetMoverInspector()
    if self._moverInspector then return self._moverInspector end

    -- Resolve the addon theme font path at panel creation time.
    local function ResolveAddonFont(size)
        local path  = _G.STANDARD_TEXT_FONT
        local LSM   = T.Libs and T.Libs.LSM
        local theme = T:GetModule("Theme", true)
        if LSM and theme then
            local name = theme.Get and theme:Get("globalFont")
            if name and name ~= "" and name ~= "__default" then
                local ok, fetched = pcall(LSM.Fetch, LSM, "font", name)
                if ok and type(fetched) == "string" and fetched ~= "" then
                    path = fetched
                end
            end
        end
        return path, size or 11
    end

    local panel = CreateFrame("Frame", "TwichUIMoverInspector", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(9998)
    panel:SetSize(220, 170)
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.06, 0.07, 0.10, 0.97)
    panel:SetBackdropBorderColor(0.10, 0.72, 0.74, 1.0)
    panel:EnableMouse(true)
    panel:Hide()

    -- Hover-delay hide ---------------------------------------------------
    local function CancelHide()
        if panel._hideTimer then
            panel._hideTimer:Cancel()
            panel._hideTimer = nil
        end
    end
    local function ScheduleHide()
        CancelHide()
        panel._hideTimer = C_Timer.NewTimer(0.15, function()
            panel._hideTimer = nil
            if (panel.xBox and panel.xBox:HasFocus()) or
                (panel.yBox and panel.yBox:HasFocus()) or
                (panel.wBox and panel.wBox:HasFocus()) or
                (panel.hBox and panel.hBox:HasFocus()) then
                return -- keep open while the user is typing
            end
            panel:Hide()
        end)
    end
    panel.CancelHide   = CancelHide
    panel.ScheduleHide = ScheduleHide
    panel:SetScript("OnEnter", CancelHide)
    panel:SetScript("OnLeave", ScheduleHide)

    -- Shared font helper -------------------------------------------------
    local function FLabel(fs, size)
        local p, s = ResolveAddonFont(size)
        fs:SetFont(p, s, "")
    end

    -- ── Title ────────────────────────────────────────────────────────────
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    title:SetJustifyH("LEFT")
    FLabel(title, 11)
    title:SetTextColor(0.10, 0.72, 0.74, 1)
    panel.title = title

    local shiftHint = panel:CreateFontString(nil, "OVERLAY")
    shiftHint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    shiftHint:SetJustifyH("RIGHT")
    FLabel(shiftHint, 8)
    shiftHint:SetText("Shift = 10 px")
    shiftHint:SetTextColor(0.40, 0.40, 0.52)

    -- Divider 1
    local div1 = panel:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -22)
    div1:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -22)
    div1:SetColorTexture(0.10, 0.72, 0.74, 0.35)

    -- ── Shared widget helpers ────────────────────────────────────────────
    local function MakeLabel(text, xOff, yOff)
        local fs = panel:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", xOff, yOff)
        FLabel(fs, 10)
        fs:SetText(text)
        fs:SetTextColor(0.55, 0.58, 0.68)
        return fs
    end

    local function MakeEditBox(xOff, yOff, w)
        local eb = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
        eb:SetSize(w, 20)
        eb:SetPoint("TOPLEFT", panel, "TOPLEFT", xOff, yOff)
        eb:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        eb:SetBackdropColor(0.04, 0.05, 0.08, 1)
        eb:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
        eb:SetTextInsets(5, 5, 2, 2)
        eb:SetMaxLetters(7)
        eb:SetAutoFocus(false)
        local fp, fs = ResolveAddonFont(10)
        eb:SetFont(fp, fs, "")
        eb:SetTextColor(1, 1, 1)
        eb:SetJustifyH("RIGHT")
        eb:EnableMouse(true)
        eb:SetScript("OnEnter", CancelHide)
        eb:SetScript("OnLeave", ScheduleHide)
        eb:SetScript("OnEditFocusGained", CancelHide)
        return eb
    end

    -- ── X / Y inputs (row 1) ─────────────────────────────────────────────
    MakeLabel("X", 8, -35)
    MakeLabel("Y", 116, -35)
    local xBox = MakeEditBox(19, -30, 86)
    local yBox = MakeEditBox(127, -30, 82)
    panel.xBox = xBox
    panel.yBox = yBox

    -- Divider between position and size
    local div2 = panel:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -55)
    div2:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -55)
    div2:SetColorTexture(0.14, 0.16, 0.22, 1)

    -- ── W / H inputs (row 2) ─────────────────────────────────────────────
    MakeLabel("W", 8, -63)
    MakeLabel("H", 116, -63)
    local wBox = MakeEditBox(19, -58, 86)
    local hBox = MakeEditBox(127, -58, 82)
    panel.wBox = wBox
    panel.hBox = hBox

    -- Divider between size and nudge
    local div3 = panel:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -83)
    div3:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -83)
    div3:SetColorTexture(0.14, 0.16, 0.22, 1)

    -- ── Size data helpers ────────────────────────────────────────────────
    -- Returns w, h, canEditW, canEditH for the given layout key.
    local function GetSizeForKey(key)
        local db = UnitFrames:GetDB()
        local powerBase = key and key:match("^(.-)_power$")
        if powerBase then
            local s = UnitFrames:GetUnitSettings(powerBase)
            return s.powerWidth or 220, s.powerHeight or 8, true, true
        end
        if key == "castbar" then
            local cs = db.castbar or {}
            return cs.width or 260, cs.height or 20, true, true
        end
        if key == "party" or key == "raid" or key == "tank" then
            local gs = UnitFrames:GetGroupSettings(key)
            return gs.width, gs.height, true, true
        end
        if key == "boss" then
            local bs = UnitFrames:GetUnitSettings("boss")
            return bs.width, bs.height, true, true
        end
        local s = UnitFrames:GetUnitSettings(key)
        if s and s.width ~= nil then
            return s.width, s.height, true, true
        end
        return nil, nil, false, false
    end

    local function ApplySize(w, h)
        local active = panel._active
        if not active or InCombatLockdown() then return end
        local key       = active.mover._layoutKey
        local db        = UnitFrames:GetDB()
        local newW      = math_max(40, math.floor((tonumber(w) or 40) + 0.5))
        local newH      = math_max(8, math.floor((tonumber(h) or 8) + 0.5))
        local powerBase = key and key:match("^(.-)_power$")
        if powerBase then
            local s       = UnitFrames:GetUnitSettings(powerBase)
            s.powerWidth  = newW
            s.powerHeight = newH
        elseif key == "castbar" then
            db.castbar        = db.castbar or {}
            db.castbar.width  = newW
            db.castbar.height = newH
        elseif key == "party" or key == "raid" or key == "tank" then
            local gs  = UnitFrames:GetGroupSettings(key)
            gs.width  = newW
            gs.height = newH
        elseif key == "boss" then
            local bs  = UnitFrames:GetUnitSettings("boss")
            bs.width  = newW
            bs.height = newH
        else
            local s = UnitFrames:GetUnitSettings(key)
            if s then
                s.width  = newW
                s.height = newH
            end
        end
        panel.wBox:SetText(tostring(newW))
        panel.hBox:SetText(tostring(newH))
        panel.wBox:SetCursorPosition(0)
        panel.hBox:SetCursorPosition(0)
        UnitFrames:RefreshAllFrames()
    end

    -- ── Position helpers ─────────────────────────────────────────────────
    local function RepositionPanel(mover)
        panel:ClearAllPoints()
        local moverTop = mover:GetTop() or 0
        local screenH  = UIParent:GetHeight() or 768
        if moverTop > screenH * 0.55 then
            panel:SetPoint("TOP", mover, "BOTTOM", 0, -6)
        else
            panel:SetPoint("BOTTOM", mover, "TOP", 0, 6)
        end
    end

    local function ApplyPosition(x, y)
        local active = panel._active
        if not active or InCombatLockdown() then return end
        local mover = active.mover
        local frame = mover._frame
        local key   = mover._layoutKey
        local newX  = math.floor((tonumber(x) or 0) + 0.5)
        local newY  = math.floor((tonumber(y) or 0) + 0.5)
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newX, newY)
        UnitFrames:PersistLayoutFromFrame(key, frame, newX, newY)
        mover:ClearAllPoints()
        mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newX, newY)
        panel.xBox:SetText(tostring(newX))
        panel.yBox:SetText(tostring(newY))
        panel.xBox:SetCursorPosition(0)
        panel.yBox:SetCursorPosition(0)
        RepositionPanel(mover)
    end

    local function RefreshBoxes()
        local active = panel._active
        if not active then return end
        local m = active.mover
        -- Position
        local x = m:GetLeft() or 0
        local y = m:GetBottom() or 0
        panel.xBox:SetText(tostring(math.floor(x + 0.5)))
        panel.yBox:SetText(tostring(math.floor(y + 0.5)))
        panel.xBox:SetCursorPosition(0)
        panel.yBox:SetCursorPosition(0)
        -- Size
        local w, h, canW, canH = GetSizeForKey(m._layoutKey)
        local disabledColor = { 0.35, 0.35, 0.42, 1 }
        if canW then
            panel.wBox:SetText(tostring(math.floor((w or 100) + 0.5)))
            panel.wBox:SetBackdropColor(0.04, 0.05, 0.08, 1)
            panel.wBox:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
        else
            panel.wBox:SetText("—")
            panel.wBox:SetBackdropColor(0.03, 0.03, 0.05, 1)
            panel.wBox:SetBackdropBorderColor(0.12, 0.13, 0.18, 1)
        end
        if canH then
            panel.hBox:SetText(tostring(math.floor((h or 20) + 0.5)))
            panel.hBox:SetBackdropColor(0.04, 0.05, 0.08, 1)
            panel.hBox:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
        else
            panel.hBox:SetText("—")
            panel.hBox:SetBackdropColor(0.03, 0.03, 0.05, 1)
            panel.hBox:SetBackdropBorderColor(0.12, 0.13, 0.18, 1)
        end
        panel.wBox:SetCursorPosition(0)
        panel.hBox:SetCursorPosition(0)
        panel.wBox:SetEnabled(canW == true)
        panel.hBox:SetEnabled(canH == true)
    end
    panel.RefreshBoxes = RefreshBoxes

    -- X/Y scripts
    xBox:SetScript("OnEnterPressed", function(eb)
        local y = tonumber(panel.yBox:GetText()) or 0
        ApplyPosition(eb:GetText(), y)
        eb:ClearFocus()
    end)
    xBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes()
        eb:ClearFocus()
    end)
    yBox:SetScript("OnEnterPressed", function(eb)
        local x = tonumber(panel.xBox:GetText()) or 0
        ApplyPosition(x, eb:GetText())
        eb:ClearFocus()
    end)
    yBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes()
        eb:ClearFocus()
    end)

    -- W/H scripts
    wBox:SetScript("OnEnterPressed", function(eb)
        local h = tonumber(panel.hBox:GetText()) or 0
        ApplySize(eb:GetText(), h)
        eb:ClearFocus()
    end)
    wBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes()
        eb:ClearFocus()
    end)
    hBox:SetScript("OnEnterPressed", function(eb)
        local w = tonumber(panel.wBox:GetText()) or 0
        ApplySize(w, eb:GetText())
        eb:ClearFocus()
    end)
    hBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes()
        eb:ClearFocus()
    end)

    -- ── Nudge buttons ────────────────────────────────────────────────────
    local S, G = 20, 3 -- button size, gap
    local CX   = 110   -- horizontal centre of the 220-wide panel

    local function MakeNudgeBtn(label, dx, dy)
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(S, S)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.09, 0.11, 0.15, 1)
        btn:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        FLabel(fs, 11)
        fs:SetText(label)
        btn:SetScript("OnEnter", function()
            btn:SetBackdropColor(0.10, 0.72, 0.74, 0.22)
            btn:SetBackdropBorderColor(0.10, 0.72, 0.74, 1)
            CancelHide()
        end)
        btn:SetScript("OnLeave", function()
            btn:SetBackdropColor(0.09, 0.11, 0.15, 1)
            btn:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
            ScheduleHide()
        end)
        btn:SetScript("OnClick", function()
            if not panel._active or InCombatLockdown() then return end
            local step = IsShiftKeyDown() and 10 or 1
            local curX = tonumber(panel.xBox:GetText()) or 0
            local curY = tonumber(panel.yBox:GetText()) or 0
            ApplyPosition(curX + dx * step, curY + dy * step)
        end)
        return btn
    end

    -- Arrow layout: cross pattern centred on panel (shifted down for W/H row)
    local row1Y    = -91
    local row2Y    = row1Y - S - G                       -- -114
    local row3Y    = row2Y - S - G                       -- -137

    local btnUp    = MakeNudgeBtn("\226\134\145", 0, 1)  -- ↑
    local btnLeft  = MakeNudgeBtn("\226\134\144", -1, 0) -- ←
    local btnRight = MakeNudgeBtn("\226\134\146", 1, 0)  -- →
    local btnDown  = MakeNudgeBtn("\226\134\147", 0, -1) -- ↓

    btnUp:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2, row1Y)
    btnLeft:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2 - S - G, row2Y)
    btnRight:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2 + S + G, row2Y)
    btnDown:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2, row3Y)

    -- Centre indicator (non-interactive cosmetic box)
    local ctr = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    ctr:SetSize(S, S)
    ctr:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2, row2Y)
    ctr:EnableMouse(false)
    ctr:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    ctr:SetBackdropColor(0.05, 0.06, 0.09, 0.7)
    ctr:SetBackdropBorderColor(0.15, 0.17, 0.22, 0.6)
    local ctrFont = ctr:CreateFontString(nil, "OVERLAY")
    ctrFont:SetAllPoints(ctr)
    ctrFont:SetJustifyH("CENTER")
    ctrFont:SetJustifyV("MIDDLE")
    FLabel(ctrFont, 8)
    ctrFont:SetText("XY")
    ctrFont:SetTextColor(0.38, 0.40, 0.50)

    self._moverInspector = panel
    return panel
end

function UnitFrames:AttachMover(frame, layoutKey)
    if not frame or self.movers[layoutKey] then
        return
    end

    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("HIGH")
    mover:SetFrameLevel(250)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.10, 0.72, 0.74, 0.12)
    mover:SetBackdropBorderColor(0.10, 0.72, 0.74, 0.85)

    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    self:ApplyFontObject(mover.label, 11)
    mover.label:SetText(BuildFrameName(layoutKey))

    -- Store references so the inspector panel can reach the target frame.
    mover._frame     = frame
    mover._layoutKey = layoutKey

    mover:SetScript("OnMouseDown", function(selfFrame)
        if InCombatLockdown() then
            return
        end

        selfFrame:StartMoving()
        selfFrame.isMoving = true
    end)

    mover:SetScript("OnMouseUp", function(selfFrame)
        if not selfFrame.isMoving then
            return
        end

        selfFrame:StopMovingOrSizing()
        selfFrame.isMoving = false

        local x = selfFrame:GetLeft() or 0
        local y = selfFrame:GetBottom() or 0

        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)

        UnitFrames:PersistLayoutFromFrame(layoutKey, frame, x, y)

        -- Refresh inspector X/Y fields if it's currently tracking this mover.
        local inspector = UnitFrames._moverInspector
        if inspector and inspector:IsShown()
            and inspector._active
            and inspector._active.mover == selfFrame
        then
            inspector.RefreshBoxes()
        end
    end)

    mover:EnableMouse(true)
    mover:SetMovable(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", mover:GetScript("OnMouseDown"))
    mover:SetScript("OnDragStop", mover:GetScript("OnMouseUp"))

    -- Show/hide the inspector on hover.
    mover:SetScript("OnEnter", function(selfMover)
        local inspector = UnitFrames:GetMoverInspector()
        inspector.CancelHide()
        inspector._active = { mover = selfMover }
        inspector.title:SetText(BuildFrameName(selfMover._layoutKey))
        inspector.RefreshBoxes()
        inspector:ClearAllPoints()
        local moverTop = selfMover:GetTop() or 0
        local screenH  = UIParent:GetHeight() or 768
        if moverTop > screenH * 0.55 then
            inspector:SetPoint("TOP", selfMover, "BOTTOM", 0, -6)
        else
            inspector:SetPoint("BOTTOM", selfMover, "TOP", 0, 6)
        end
        inspector:Show()
    end)
    mover:SetScript("OnLeave", function()
        UnitFrames:GetMoverInspector().ScheduleHide()
    end)

    self.movers[layoutKey] = mover
end

function UnitFrames:UpdateMovers()
    local db = self:GetDB()
    local showMovers = db.lockFrames == false

    local function PlaceMover(mover, point, relPoint, x, y, w, h, enabled)
        if not mover then return end
        mover:SetSize(math_max(20, w), math_max(10, h))
        mover:ClearAllPoints()
        mover:SetPoint(point, UIParent, relPoint, x, y)
        mover:SetShown(showMovers and enabled ~= false)
    end

    -- Single unit frames
    local singleUnits = {
        { key = "player",       defaultW = 220, defaultH = 42 },
        { key = "target",       defaultW = 220, defaultH = 42 },
        { key = "targettarget", defaultW = 180, defaultH = 32 },
        { key = "focus",        defaultW = 180, defaultH = 32 },
        { key = "pet",          defaultW = 140, defaultH = 28 },
    }
    for _, entry in ipairs(singleUnits) do
        local key = entry.key
        local frame = self.frames[key]
        if frame and not self.movers[key] then
            self:AttachMover(frame, key)
        end
        local mover = self.movers[key]
        if mover then
            local s = self:GetUnitSettings(key)
            local layout = self:GetLayoutSettings(key)
            PlaceMover(mover,
                layout.point or "BOTTOM", layout.relativePoint or layout.point or "BOTTOM",
                tonumber(layout.x) or 0, tonumber(layout.y) or 0,
                Clamp(s.width or entry.defaultW, 80, 600),
                Clamp(s.height or entry.defaultH, 16, 180),
                s.enabled ~= false)
        end
    end

    -- Detached power bar movers (one per single unit that has powerDetached == true).
    -- Each power bar gets its own freely-draggable mover stored under "unitkey_power".
    do
        local powerMoverUnits = {
            { key = "player",       defaultW = 260, defaultH = 10 },
            { key = "target",       defaultW = 240, defaultH = 10 },
            { key = "targettarget", defaultW = 180, defaultH = 8 },
            { key = "focus",        defaultW = 220, defaultH = 8 },
            { key = "pet",          defaultW = 180, defaultH = 8 },
        }
        for _, entry in ipairs(powerMoverUnits) do
            local key      = entry.key
            local ufFrame  = self.frames[key]
            local s        = self:GetUnitSettings(key)
            local powerKey = key .. "_power"
            if ufFrame and ufFrame.Power and s.powerDetached == true then
                if not self.movers[powerKey] then
                    self:AttachMover(ufFrame.Power, powerKey)
                end
                local mover = self.movers[powerKey]
                if mover then
                    local powerLayout = self:GetLayoutSettings(powerKey)
                    local pw = Clamp(s.powerWidth or s.width or entry.defaultW, 40, 600)
                    -- Use a minimum mover height of 16 so thin bars remain easy to grab.
                    local ph = math_max(16, Clamp(s.powerHeight or entry.defaultH, 4, 32))
                    if powerLayout.point == "BOTTOMLEFT" and powerLayout.x ~= nil then
                        PlaceMover(mover, "BOTTOMLEFT", "BOTTOMLEFT",
                            tonumber(powerLayout.x) or 0,
                            tonumber(powerLayout.y) or 0,
                            pw, ph, s.enabled ~= false)
                    else
                        -- Bar hasn't been freely placed yet; position the mover over
                        -- wherever the power bar currently sits on screen.
                        local bl = ufFrame.Power:IsVisible() and ufFrame.Power:GetLeft()
                        local bb = ufFrame.Power:IsVisible() and ufFrame.Power:GetBottom()
                        if bl and bb then
                            PlaceMover(mover, "BOTTOMLEFT", "BOTTOMLEFT", bl, bb, pw, ph, s.enabled ~= false)
                        else
                            mover:Hide()
                        end
                    end
                end
            else
                -- Detach is off for this unit — hide any lingering power mover.
                local mover = self.movers[powerKey]
                if mover then mover:Hide() end
            end
        end
    end

    -- Castbar
    do
        local frame = self.frames.castbar
        if frame and not self.movers.castbar then
            self:AttachMover(frame, "castbar")
        end
        local mover = self.movers.castbar
        if mover then
            local cs = db.castbar or {}
            local layout = self:GetLayoutSettings("castbar")
            PlaceMover(mover,
                layout.point or "BOTTOM", layout.relativePoint or layout.point or "BOTTOM",
                tonumber(layout.x) or -260, tonumber(layout.y) or 220,
                Clamp(cs.width or 260, 120, 600),
                Clamp(cs.height or 20, 10, 60),
                cs.enabled ~= false)
        end
    end

    -- Group headers (party / raid / tank)
    local groupEntries = {
        { key = "party", defaultW = 180, defaultH = 36, defaultRows = 5 },
        { key = "raid",  defaultW = 120, defaultH = 30, defaultRows = 5 },
        { key = "tank",  defaultW = 180, defaultH = 32, defaultRows = 2 },
    }
    for _, entry in ipairs(groupEntries) do
        local key = entry.key
        local header = self.headers[key]
        if header and not self.movers[key] then
            self:AttachMover(header, key)
        end
        local mover = self.movers[key]
        if mover then
            local gs = self:GetGroupSettings(key)
            local layout = self:GetLayoutSettings(key)
            local w = Clamp(gs.width or entry.defaultW, 70, 500)
            local rowH = Clamp(gs.height or entry.defaultH, 14, 120)
            local yOff = math_abs(tonumber(gs.yOffset) or 6)
            local rows = math_max(1, tonumber(gs.unitsPerColumn) or entry.defaultRows)
            -- Use the configured maxColumns for ALL group types (not just raid) so
            -- horizontally-arranged party/tank layouts get an accurate mover size.
            local cols = math_max(1, tonumber(gs.maxColumns) or 1)
            local colSpacing = (cols > 1) and (tonumber(gs.columnSpacing) or 8) or 0
            local mw = (w + colSpacing) * cols - colSpacing
            local mh = rowH * rows + yOff * math_max(0, rows - 1)
            UFDebug(string.format("UpdateMovers: %s mover  rows=%d cols=%d mw=%d mh=%d enabled=%s",
                key, rows, cols, mw, mh, tostring(gs.enabled ~= false)))
            PlaceMover(mover,
                layout.point or "CENTER", layout.relativePoint or layout.point or "CENTER",
                tonumber(layout.x) or 0, tonumber(layout.y) or 0,
                mw, mh, gs.enabled ~= false)
        end
    end

    -- Boss anchor
    do
        if self.bossAnchor and not self.movers.boss then
            self:AttachMover(self.bossAnchor, "boss")
        end
        local mover = self.movers.boss
        if mover then
            local gs = self:GetGroupSettings("boss")
            local bs = self:GetUnitSettings("boss")
            local layout = self:GetLayoutSettings("boss")
            local w = Clamp(bs.width or 220, 120, 500)
            local rowH = Clamp(bs.height or 36, 16, 120)
            local yOff = math_abs(tonumber(gs.yOffset) or 8)
            local mh = (rowH + yOff) * 5 - yOff
            PlaceMover(mover,
                layout.point or "RIGHT", layout.relativePoint or layout.point or "RIGHT",
                tonumber(layout.x) or -300, tonumber(layout.y) or 0,
                w, mh, gs.enabled ~= false)
        end
    end

    if not showMovers then
        for _, mover in pairs(self.movers) do
            if mover then mover:Hide() end
        end
    end
end

function UnitFrames:RegisterLayoutFrame(layoutKey, frame)
    local setupWizard = T:GetModule("SetupWizard", true)
    if not setupWizard or not frame then
        return
    end

    setupWizard:RegisterLayoutFrame("UF_" .. layoutKey, frame, function(absX, absY, absW, absH)
        local layout = UnitFrames:GetLayoutSettings(layoutKey)
        layout.point = "BOTTOMLEFT"
        layout.relativePoint = "BOTTOMLEFT"
        layout.x = math.floor((absX or 0) + 0.5)
        layout.y = math.floor((absY or 0) + 0.5)

        if layoutKey == "party" or layoutKey == "raid" or layoutKey == "tank" or layoutKey == "boss" then
            return
        end

        if layoutKey == "castbar" then
            local db = UnitFrames:GetDB()
            db.castbar = db.castbar or {}
            if absW and absW > 20 then
                db.castbar.width = math.floor(absW + 0.5)
            end
            if absH and absH > 12 then
                db.castbar.height = math.floor(absH + 0.5)
            end
            return
        end

        local unitSettings = UnitFrames:GetUnitSettings(layoutKey)
        if absW and absW > 20 then
            unitSettings.width = math.floor(absW + 0.5)
        end
        if absH and absH > 12 then
            unitSettings.height = math.floor(absH + 0.5)
        end
    end)
end

local PREVIEW_NAMES = {
    "Aeloria", "Bromm", "Cyrene", "Dathor", "Elyndra", "Fenrik", "Galen", "Hestia", "Ilya", "Jorren",
    "Kaelis", "Lyra", "Marek", "Nyssa", "Orin", "Perrin", "Quilla", "Riven", "Sylas", "Tarin",
}

local PREVIEW_CAST_ICONS = {
    136243, 135963, 135734, 136208, 237561,
}

local function GetPreviewIndexFromLabel(label)
    return tonumber(type(label) == "string" and label:match("(%d+)$")) or 1
end

local function GetPreviewRoleForUnitKey(unitKey, index)
    if unitKey == "tankMember" then
        return "TANK"
    end
    if unitKey == "partyMember" then
        local partyRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
        return partyRoles[index] or "DAMAGER"
    end
    if unitKey == "raidMember" then
        local raidRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER" }
        return raidRoles[((index - 1) % #raidRoles) + 1]
    end
    if unitKey == "boss" or (type(unitKey) == "string" and unitKey:match("^boss")) then
        return "TANK"
    end
    if unitKey == "player" then
        local assigned = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or ""
        if assigned == nil or assigned == "" or assigned == "NONE" then
            return "DAMAGER"
        end
        return assigned
    end
    return "DAMAGER"
end

local function BuildPreviewUnitState(unitKey, label, mockClass)
    local index = GetPreviewIndexFromLabel(label)
    local role = GetPreviewRoleForUnitKey(unitKey, index)
    local healthMax = 1000000 + (index * 125000)
    local healthCur = math_max(1, math.floor(healthMax * (0.42 + ((index % 4) * 0.12))))
    local powerMax = 100
    local powerCur = math_max(1, math.floor(powerMax * (0.25 + ((index % 5) * 0.13))))
    local castDuration = 2.6 + ((index % 3) * 0.4)
    local castProgress = castDuration * 0.62
    local name = label or PREVIEW_NAMES[((index - 1) % #PREVIEW_NAMES) + 1]

    if unitKey == "player" then
        name = UnitName("player") or "Player"
    elseif unitKey == "target" then
        name = "Training Dummy"
    elseif unitKey == "targettarget" then
        name = "Off Target"
    elseif unitKey == "focus" then
        name = "Priority Add"
    elseif unitKey == "pet" then
        name = "Companion"
    elseif unitKey == "boss" or (type(unitKey) == "string" and unitKey:match("^boss")) then
        name = label or ("Boss " .. tostring(index))
        healthMax = 3800000 + (index * 250000)
        healthCur = math_max(1, math.floor(healthMax * (0.68 - ((index - 1) * 0.08))))
    end

    return {
        index = index,
        name = name,
        role = role,
        classToken = mockClass,
        healthCur = healthCur,
        healthMax = healthMax,
        powerCur = powerCur,
        powerMax = powerMax,
        level = 80,
        castName = (role == "HEALER" and "Flash Heal") or (role == "TANK" and "Shield Slam") or "Chaos Bolt",
        castIcon = PREVIEW_CAST_ICONS[((index - 1) % #PREVIEW_CAST_ICONS) + 1],
        castDuration = castDuration,
        castProgress = castProgress,
        classPowerMax = unitKey == "player" and 5 or nil,
        classPowerValue = unitKey == "player" and 3 or nil,
        infoTexts = {
            role,
            string.format("%d%%", math.floor((healthCur / healthMax) * 100 + 0.5)),
            "Burst Window",
        },
    }
end

local function FormatPreviewNumber(value)
    local numeric = tonumber(value) or 0
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(math.floor(numeric + 0.5))
    end
    return tostring(math.floor(numeric + 0.5))
end

local function BuildPreviewTagText(tag, state)
    if not state then return "" end
    local text = tostring(tag or "")
    local hpPercent = string.format("%d%%",
        math.floor(((state.healthCur or 0) / math_max(1, state.healthMax or 1)) * 100 + 0.5))
    local ppPercent = string.format("%d%%",
        math.floor(((state.powerCur or 0) / math_max(1, state.powerMax or 1)) * 100 + 0.5))

    text = text:gsub("%[name%((%d+)%)%]", function(length)
        return string.sub(state.name or "", 1, tonumber(length) or 0)
    end)
    text = text:gsub("%[name%]", state.name or "")
    text = text:gsub("%[curhp%]", FormatPreviewNumber(state.healthCur))
    text = text:gsub("%[curpp%]", FormatPreviewNumber(state.powerCur))
    text = text:gsub("%[missinghp%]", FormatPreviewNumber((state.healthMax or 0) - (state.healthCur or 0)))
    text = text:gsub("%[missingpp%]", FormatPreviewNumber((state.powerMax or 0) - (state.powerCur or 0)))
    text = text:gsub("%[perhp.-%]", hpPercent)
    text = text:gsub("%[perpp.-%]", ppPercent)
    text = text:gsub("%[level%]", tostring(state.level or 80))
    text = text:gsub("%[classification%]", "")
    text = text:gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function BuildPreviewAuraList(state)
    local now = GetTime()
    return {
        {
            name = "Arcane Intellect",
            icon = 135932,
            applications = 1,
            duration = 3600,
            expirationTime = now + 3200,
            isHarmfulAura = false,
            isPlayerAura = true,
        },
        {
            name = "Power Word: Shield",
            icon = 135940,
            applications = 1,
            duration = 15,
            expirationTime = now + 9.4,
            isHarmfulAura = false,
            isPlayerAura = true,
        },
        {
            name = "Weakened Soul",
            icon = 136214,
            applications = 1,
            duration = 12,
            expirationTime = now + 6.8,
            isHarmfulAura = true,
            dispelName = "Magic",
            isPlayerAura = false,
        },
        {
            name = "Shadow Vulnerability",
            icon = 136207,
            applications = math_max(1, (state and state.index or 1) % 4),
            duration = 18,
            expirationTime = now + 12.1,
            isHarmfulAura = true,
            isPlayerAura = true,
            isBossAura = true,
        },
    }
end

function UnitFrames:GetPreviewAuraListForFrame(frame, unitKey)
    local aura = self:GetAuraConfigFor(unitKey)
    local maxIcons = math_max(1, math.floor(tonumber(aura.maxIcons) or 8))
    local filter = aura.filter or "ALL"
    local onlyMine = aura.onlyMine == true
    local source = frame and frame._testAuraList or BuildPreviewAuraList(frame and frame._testState)
    local filtered = {}
    for _, data in ipairs(source) do
        if data and ((not onlyMine) or data.isPlayerAura == true) and AuraMatchesDisplayMode(filter, data) then
            if filter == "HELPFUL" and data.isHarmfulAura ~= true then
                filtered[#filtered + 1] = data
            elseif (filter == "HARMFUL" or filter == "DISPELLABLE" or filter == "DISPELLABLE_OR_BOSS") and data.isHarmfulAura == true then
                filtered[#filtered + 1] = data
            elseif filter == "ALL" then
                filtered[#filtered + 1] = data
            end
        end
        if #filtered >= maxIcons then
            break
        end
    end
    return filtered
end

function UnitFrames:RefreshPreviewAuraIcons(frame, unitKey)
    if not frame or not frame._isTestPreview or not frame.Auras then return end
    local aura = self:GetAuraConfigFor(unitKey)
    local element = frame.Auras
    local list = self:GetPreviewAuraListForFrame(frame, unitKey)
    local iconSize = Clamp(aura.iconSize or 18, 10, 40)
    local spacing = Clamp(aura.spacing or 2, 0, 8)
    local textStyle = self:GetTextConfigFor(unitKey)

    element._previewIcons = element._previewIcons or {}

    for index = 1, math_max(#list, #element._previewIcons) do
        local auraData = list[index]
        local button = element._previewIcons[index]
        if auraData then
            if not button then
                button = CreateFrame("Frame", nil, element, "BackdropTemplate")
                button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                button.icon = button:CreateTexture(nil, "ARTWORK")
                button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                button.count = button:CreateFontString(nil, "OVERLAY")
                button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                button.time = button:CreateFontString(nil, "OVERLAY")
                button.time:SetPoint("TOP", button, "BOTTOM", 0, -1)
                button:SetScript("OnUpdate", function(self)
                    if self._expiry and self._duration and self.time then
                        local remaining = math_max(0, self._expiry - GetTime())
                        self.time:SetText(UnitFrames:FormatAuraRemainingTime(remaining))
                        self.time:SetShown(remaining > 0)
                    end
                end)
                element._previewIcons[index] = button
            end

            button:SetSize(iconSize, iconSize)
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", element, "BOTTOMLEFT", (index - 1) * (iconSize + spacing), 0)
            button:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
            button:SetBackdropBorderColor(0.16, 0.18, 0.24, 0.85)
            button.icon:SetTexture(auraData.icon)
            button._duration = auraData.duration
            button._expiry = auraData.expirationTime
            self:ApplyFontObject(button.count, Clamp(iconSize * 0.48, 6, 16), textStyle.fontName, textStyle)
            self:ApplyFontObject(button.time, Clamp(iconSize * 0.44, 6, 16), textStyle.fontName, textStyle)
            button.count:SetText((aura.showStacks ~= false and auraData.applications and auraData.applications > 1)
                and tostring(auraData.applications) or "")
            button.count:SetShown(aura.showStacks ~= false and auraData.applications and auraData.applications > 1)
            button.time:SetShown(aura.showTime ~= false and (auraData.duration or 0) > 0)
            button:Show()
        elseif button then
            button:Hide()
        end
    end

    element:SetWidth((iconSize * math_max(1, #list)) + (spacing * math_max(0, #list - 1)))
    element:SetHeight(iconSize + ((aura.showTime ~= false and #list > 0) and 10 or 0))
end

function UnitFrames:ApplyPreviewFrameData(frame, unitKey, label, mockClass)
    if not frame then return end

    local state = BuildPreviewUnitState(unitKey, label, mockClass)
    frame._testState = state
    frame._testRole = state.role
    frame._testMockClass = mockClass
    frame._testAuraList = BuildPreviewAuraList(state)

    self:ApplySingleFrameSettings(frame, unitKey)

    if frame.Health then
        self:ApplySmoothBarValue(frame.Health, state.healthCur, state.healthMax)
    end
    if frame.Power then
        self:ApplySmoothBarValue(frame.Power, state.powerCur, state.powerMax)
    end

    local textCfg = self:GetTextConfigFor(unitKey)
    if frame.Name then
        frame.Name:SetText(BuildPreviewTagText(BuildNameTag(textCfg.nameFormat, textCfg.customNameTag), state))
    end
    if frame.HealthValue then
        frame.HealthValue:SetText(BuildPreviewTagText(BuildHealthTag(textCfg.healthFormat, textCfg.customHealthTag),
            state))
    end
    if frame.PowerValue then
        frame.PowerValue:SetText(BuildPreviewTagText(BuildPowerTag(textCfg.powerFormat, textCfg.customPowerTag), state))
    end

    if frame.ClassPower and state.classPowerMax then
        local cfg = self:GetDB().classBar or {}
        local container = frame.ClassPower.container
        local spacing = Clamp(cfg.spacing or 2, 0, 40)
        local maxBars = math_max(1, math_min(state.classPowerMax or 0, #frame.ClassPower))
        local width = container and container:GetWidth() or frame:GetWidth()
        local height = container and container:GetHeight() or 10
        local barWidth = math_max(4, (width - spacing * math_max(0, maxBars - 1)) / maxBars)
        for i = 1, #frame.ClassPower do
            local bar = frame.ClassPower[i]
            if bar then
                bar:ClearAllPoints()
                if i <= maxBars then
                    bar:SetSize(barWidth, height)
                    if i == 1 then
                        bar:SetPoint("LEFT", container, "LEFT", 0, 0)
                    else
                        bar:SetPoint("LEFT", frame.ClassPower[i - 1], "RIGHT", spacing, 0)
                    end
                    bar:SetShown(true)
                    bar:SetMinMaxValues(0, 1)
                    bar:SetValue(i <= (state.classPowerValue or 0) and 1 or 0.15)
                else
                    bar:Hide()
                end
            end
        end
    end

    if frame.Castbar then
        local castCfg = (self:GetDB().castbars and self:GetDB().castbars[ResolveCastbarScopeByUnitKey(unitKey)]) or {}
        if castCfg.enabled == false then
            frame.Castbar:Hide()
        else
            frame.Castbar:Show()
            self:ApplyCastbarValue(frame.Castbar, state.castProgress, state.castDuration)
            if frame.Castbar.Text then frame.Castbar.Text:SetText(state.castName or "Casting") end
            if frame.Castbar.Time then
                frame.Castbar.Time:SetText(string.format("%.1f",
                    (state.castDuration or 0) - (state.castProgress or 0)))
            end
            if frame.Castbar.Icon then frame.Castbar.Icon:SetTexture(state.castIcon or 136243) end
        end
    end

    self:UpdateRoleIcon(frame, unitKey)

    if frame.TwichInfoBar and frame.TwichInfoBar.infoTexts then
        local cfg = self:GetInfoBarConfig(unitKey)
        for i = 1, 3 do
            local fs = frame.TwichInfoBar.infoTexts[i]
            local tc = cfg.texts[i]
            if fs and tc and fs:IsShown() then
                if tc.tag and tc.tag ~= "" then
                    fs:SetText(BuildPreviewTagText(tc.tag, state))
                else
                    fs:SetText(state.infoTexts and state.infoTexts[i] or "")
                end
            end
        end
    end

    local auraCfg = self:GetAuraConfigFor(unitKey)
    if auraCfg.enabled ~= false then
        if auraCfg.barMode == true then
            self:RefreshAuraBarsForFrame(frame, unitKey)
        else
            self:RefreshPreviewAuraIcons(frame, unitKey)
        end
    end
end

function UnitFrames:CreatePreviewFrame(parent, width, height, label, scopeOrUnitKey, mockClass)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame._isTestPreview = true
    frame._testMockClass = mockClass
    self:StyleFrame(frame)
    self:ApplyPreviewFrameData(frame, scopeOrUnitKey, label, mockClass)
    return frame
end

function UnitFrames:UpdatePreviewFrame(frame, width, height, label, scopeOrUnitKey, mockClass)
    if not frame then return end
    frame:SetSize(width, height)
    self:ApplyPreviewFrameData(frame, scopeOrUnitKey, label, mockClass or frame._testMockClass)
end

function UnitFrames:BuildOrRefreshSinglePreviews()
    local preview = self.previewFrames
    local db = self:GetDB()

    for _, entry in ipairs(PREVIEW_SINGLE_UNITS) do
        local settings = self:GetUnitSettings(entry.key)
        local layout = self:GetLayoutSettings(entry.key)
        local width = Clamp(settings.width or 220, 80, 600)
        local height = Clamp(settings.height or 42, 16, 180)
        local mockClass = PREVIEW_MOCK_CLASSES[entry.key]

        if not preview[entry.key] then
            preview[entry.key] = self:CreatePreviewFrame(UIParent, width, height, entry.label, entry.key, mockClass)
        else
            self:UpdatePreviewFrame(preview[entry.key], width, height, entry.label, entry.key, mockClass)
        end

        local frame = preview[entry.key]
        frame:ClearAllPoints()
        frame:SetPoint(
            layout.point or "BOTTOM",
            UIParent,
            layout.relativePoint or "BOTTOM",
            tonumber(layout.x) or 0,
            tonumber(layout.y) or 0
        )
        frame:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
        frame:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))
    end

    if not preview.castbar then
        preview.castbar = CreateFrame("StatusBar", nil, UIParent, "BackdropTemplate")
        preview.castbar:SetClipsChildren(false)
        preview.castbar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        preview.castbar.bg = preview.castbar:CreateTexture(nil, "BACKGROUND")
        preview.castbar.bg:SetAllPoints(preview.castbar)
        preview.castbar.bg:SetColorTexture(0.05, 0.06, 0.08, 0.9)

        local iconButton = CreateFrame("Button", nil, preview.castbar)
        iconButton:SetSize(20, 20)
        iconButton:SetPoint("RIGHT", preview.castbar, "LEFT", -6, 0)
        local iconTex = iconButton:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints(iconButton)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconTex:SetTexture(136243)
        preview.castbar.iconButton = iconButton
        preview.castbar.icon = iconTex

        preview.castbar.spellText = preview.castbar:CreateFontString(nil, "OVERLAY")
        preview.castbar.spellText:SetPoint("LEFT", preview.castbar, "LEFT", 6, 0)
        self:ApplyFontObject(preview.castbar.spellText, 11)

        preview.castbar.timeText = preview.castbar:CreateFontString(nil, "OVERLAY")
        preview.castbar.timeText:SetPoint("RIGHT", preview.castbar, "RIGHT", -6, 0)
        self:ApplyFontObject(preview.castbar.timeText, 10)
    end

    do
        local castSettings = db.castbar or {}
        local layout = self:GetLayoutSettings("castbar")
        local palette = self:GetPalette("player", "player")
        local text = self:GetTextConfigFor("player")
        local castPreview = preview.castbar
        local texName = (castSettings.texture and castSettings.texture ~= "") and castSettings.texture
            or ((db.texture and db.texture ~= "") and db.texture or nil)
        castPreview:ClearAllPoints()
        castPreview:SetPoint(
            layout.point or "BOTTOM",
            UIParent,
            layout.relativePoint or "BOTTOM",
            tonumber(layout.x) or -260,
            tonumber(layout.y) or 220
        )
        castPreview:SetSize(Clamp(castSettings.width or 260, 120, 600), Clamp(castSettings.height or 20, 10, 60))
        castPreview:SetStatusBarTexture(texName and GetLSMTexture(texName) or GetThemeTexture())
        if castSettings.useCustomColor == true and type(castSettings.color) == "table" then
            castPreview:SetStatusBarColor(castSettings.color[1] or 1, castSettings.color[2] or 1,
                castSettings.color[3] or 1, castSettings.color[4] or 1)
        else
            castPreview:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
        end
        castPreview:SetBackdropColor(palette.background[1], palette.background[2], palette.background[3], 0.9)
        castPreview:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 0.9)
        if castPreview.bg then
            castPreview.bg:SetColorTexture(palette.background[1], palette.background[2], palette.background[3], 0.9)
        end
        castPreview:SetMinMaxValues(0, 100)
        castPreview:SetValue(64)
        castPreview.spellText:SetText("Shadow Bolt")
        castPreview.timeText:SetText("1.4")
        castPreview.spellText:SetShown(castSettings.showSpellText ~= false)
        castPreview.timeText:SetShown(castSettings.showTimeText ~= false)
        local castbarTextStyle = {
            fontName = castSettings.fontName or text.fontName,
            outlineMode = text.outlineMode,
            shadowEnabled = text.shadowEnabled,
            shadowOffsetX = text.shadowOffsetX,
            shadowOffsetY = text.shadowOffsetY,
        }
        self:ApplyFontObject(castPreview.spellText, Clamp(castSettings.spellFontSize or 11, 6, 24),
            castbarTextStyle.fontName, castbarTextStyle)
        self:ApplyFontObject(castPreview.timeText, Clamp(castSettings.timeFontSize or 10, 6, 24),
            castbarTextStyle.fontName, castbarTextStyle)
        do
            local iconSize = Clamp(castSettings.iconSize or castSettings.height or 20, 12, 50)
            local showIcon = castSettings.showIcon ~= false
            local iconPos  = castSettings.iconPosition or "outside"
            local iconSide = castSettings.iconSide or "left"
            if castPreview.iconButton then
                castPreview.iconButton:SetSize(iconSize, iconSize)
                castPreview.iconButton:SetShown(showIcon)
            end
            if castPreview.icon then
                castPreview.icon:SetShown(showIcon)
            end
            if castPreview.iconButton then
                castPreview.iconButton:ClearAllPoints()
                if iconPos == "inside" then
                    if iconSide == "right" then
                        castPreview.iconButton:SetPoint("RIGHT", castPreview, "RIGHT", -4, 0)
                    else
                        castPreview.iconButton:SetPoint("LEFT", castPreview, "LEFT", 4, 0)
                    end
                else
                    if iconSide == "right" then
                        castPreview.iconButton:SetPoint("LEFT", castPreview, "RIGHT", 6, 0)
                    else
                        castPreview.iconButton:SetPoint("RIGHT", castPreview, "LEFT", -6, 0)
                    end
                end
            end
        end
        ApplyStandaloneCastbarTextAnchors(castPreview, castSettings)
        castPreview:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
        castPreview:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))
    end

    if not preview.bossAnchor then
        preview.bossAnchor = CreateFrame("Frame", nil, UIParent)
    end

    do
        local bossLayout = self:GetLayoutSettings("boss")
        local bossGroup = self:GetGroupSettings("boss")
        local bossUnit = self:GetUnitSettings("boss")
        local width = Clamp(bossUnit.width or 220, 120, 500)
        local height = Clamp(bossUnit.height or 36, 16, 120)
        local yOffset = tonumber(bossGroup.yOffset) or -8

        preview.bossAnchor:ClearAllPoints()
        preview.bossAnchor:SetPoint(
            bossLayout.point or "RIGHT",
            UIParent,
            bossLayout.relativePoint or "RIGHT",
            tonumber(bossLayout.x) or -60,
            tonumber(bossLayout.y) or 520
        )
        preview.bossAnchor:SetSize(width, (height + math.abs(yOffset)) * 5)

        local bossClasses = { "DEATHKNIGHT", "WARLOCK", "MAGE", "WARRIOR", "PRIEST" }
        for index = 1, 5 do
            local key = "bossPreview" .. index
            local bossMockClass = bossClasses[index] or "DEATHKNIGHT"
            if not preview[key] then
                preview[key] = self:CreatePreviewFrame(preview.bossAnchor, width, height, "Boss " .. index, "boss",
                    bossMockClass)
            else
                self:UpdatePreviewFrame(preview[key], width, height, "Boss " .. index, "boss", bossMockClass)
            end

            preview[key]:ClearAllPoints()
            if index == 1 then
                preview[key]:SetPoint("TOP", preview.bossAnchor, "TOP", 0, 0)
            else
                preview[key]:SetPoint("TOP", preview["bossPreview" .. (index - 1)], "BOTTOM", 0, yOffset)
            end
            preview[key]:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
            preview[key]:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))
        end
    end
end

function UnitFrames:BuildPreviewGroups()
    local preview = self.previewFrames

    local function EnsureContainer(key)
        if not preview[key] then
            preview[key] = CreateFrame("Frame", nil, UIParent)
            preview[key].rows = {}
        end
        return preview[key]
    end

    local function PositionContainer(container, layout)
        container:ClearAllPoints()
        container:SetPoint(
            layout.point or "CENTER",
            UIParent,
            layout.relativePoint or "CENTER",
            tonumber(layout.x) or 0,
            tonumber(layout.y) or 0
        )
    end

    local party = EnsureContainer("party")
    do
        local settings = self:GetGroupSettings("party")
        local layout = self:GetLayoutSettings("party")
        local width = Clamp(settings.width or 180, 80, 500)
        local height = Clamp(settings.height or 36, 14, 120)
        local yOffset = tonumber(settings.yOffset) or -6
        local colSpacing = tonumber(settings.columnSpacing) or 6
        local unitsPerColumn = math_max(1, tonumber(settings.unitsPerColumn) or 5)
        local maxColumns = math_max(1, tonumber(settings.maxColumns) or 1)
        PositionContainer(party, layout)
        party:SetSize((width + colSpacing) * maxColumns - colSpacing, (height + math_abs(yOffset)) * unitsPerColumn)
        for index = 1, 5 do
            local partyMockClass = PREVIEW_CLASS_TOKENS[((index - 1) % #PREVIEW_CLASS_TOKENS) + 1]
            if not party.rows[index] then
                party.rows[index] = self:CreatePreviewFrame(party, width, height, "Party " .. index, "partyMember",
                    partyMockClass)
            else
                self:UpdatePreviewFrame(party.rows[index], width, height, "Party " .. index, "partyMember",
                    partyMockClass)
            end
            local row = party.rows[index]
            local column = math.floor((index - 1) / unitsPerColumn)
            local rowIndex = (index - 1) % unitsPerColumn
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", party, "TOPLEFT", column * (width + colSpacing),
                -(rowIndex * (height + math_abs(yOffset))))
            row:SetShown(column < maxColumns)
        end
    end

    local raid = EnsureContainer("raid")
    do
        local settings = self:GetGroupSettings("raid")
        local layout = self:GetLayoutSettings("raid")
        local width = Clamp(settings.width or 120, 70, 300)
        local height = Clamp(settings.height or 30, 14, 80)
        local yOffset = tonumber(settings.yOffset) or -6
        local colSpacing = tonumber(settings.columnSpacing) or 6
        local unitsPerColumn = math_max(1, tonumber(settings.unitsPerColumn) or 5)
        local maxColumns = math_max(1, tonumber(settings.maxColumns) or 4)
        PositionContainer(raid, layout)
        raid:SetSize((width + colSpacing) * maxColumns, (height + math_abs(yOffset)) * unitsPerColumn)
        for index = 1, 20 do
            local raidMockClass = PREVIEW_CLASS_TOKENS[((index - 1) % #PREVIEW_CLASS_TOKENS) + 1]
            if not raid.rows[index] then
                raid.rows[index] = self:CreatePreviewFrame(raid, width, height, "Raid " .. index, "raidMember",
                    raidMockClass)
            else
                self:UpdatePreviewFrame(raid.rows[index], width, height, "Raid " .. index, "raidMember", raidMockClass)
            end
            local row = raid.rows[index]
            local column = math.floor((index - 1) / unitsPerColumn)
            local rowIndex = (index - 1) % unitsPerColumn
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", raid, "TOPLEFT", column * (width + colSpacing),
                -(rowIndex * (height + math_abs(yOffset))))
            row:SetShown(column < maxColumns)
        end
    end

    local tank = EnsureContainer("tank")
    do
        local settings = self:GetGroupSettings("tank")
        local layout = self:GetLayoutSettings("tank")
        local width = Clamp(settings.width or 180, 80, 400)
        local height = Clamp(settings.height or 32, 14, 80)
        local yOffset = tonumber(settings.yOffset) or -6
        PositionContainer(tank, layout)
        tank:SetSize(width, (height + math_abs(yOffset)) * 2)
        local tankClasses = { "WARRIOR", "PALADIN" }
        for index = 1, 2 do
            local tankMockClass = tankClasses[index] or "WARRIOR"
            if not tank.rows[index] then
                tank.rows[index] = self:CreatePreviewFrame(tank, width, height, "Tank " .. index, "tankMember",
                    tankMockClass)
            else
                self:UpdatePreviewFrame(tank.rows[index], width, height, "Tank " .. index, "tankMember", tankMockClass)
            end
            local row = tank.rows[index]
            row:ClearAllPoints()
            if index == 1 then
                row:SetPoint("TOP", tank, "TOP", 0, 0)
            else
                row:SetPoint("TOP", tank.rows[index - 1], "BOTTOM", 0, yOffset)
            end
            row:SetShown(true)
        end
    end
end

function UnitFrames:RefreshPreviewVisibility()
    self:BuildPreviewGroups()
    self:BuildOrRefreshSinglePreviews()

    local db = self:GetDB()
    local showPreview = db.testMode == true

    for key, container in pairs(self.previewFrames) do
        if container then
            local shouldShow = showPreview
            if key == "castbar" then
                shouldShow = shouldShow and ((db.castbar and db.castbar.enabled ~= false) ~= false)
            elseif key:match("^bossPreview") then
                shouldShow = shouldShow and (self:GetGroupSettings("boss").enabled ~= false)
            elseif key == "bossAnchor" then
                shouldShow = shouldShow and (self:GetGroupSettings("boss").enabled ~= false)
            elseif key == "player" or key == "target" or key == "targettarget" or key == "focus" or key == "pet" then
                shouldShow = shouldShow and (self:GetUnitSettings(key).enabled ~= false)
            elseif key == "party" or key == "raid" or key == "tank" then
                shouldShow = shouldShow and (self:GetGroupSettings(key).enabled ~= false)
            end
            container:SetShown(shouldShow)
        end
    end
end

function UnitFrames:ApplyTestModeToSingles()
    local db = self:GetDB()
    if not self._testModeHiddenRoot then
        self._testModeHiddenRoot = CreateFrame("Frame", nil, UIParent)
        self._testModeHiddenRoot:Hide()
    end

    local hiddenRoot = self._testModeHiddenRoot
    local useHiddenParent = db.testMode == true

    local function ApplyHiddenParent(frame)
        if not frame then return end
        frame._testModeOriginalParent = frame._testModeOriginalParent or frame:GetParent() or UIParent
        local targetParent = useHiddenParent and hiddenRoot or frame._testModeOriginalParent
        if frame:GetParent() ~= targetParent then
            frame:SetParent(targetParent)
        end
        if useHiddenParent then
            frame:Hide()
        end
    end

    ApplyHiddenParent(self.frames and self.frames.player)
    ApplyHiddenParent(self.frames and self.frames.castbar)
end

function UnitFrames:RefreshAllFrames()
    if InCombatLockdown() then
        self._queuedRefresh = true
        return
    end

    for unitKey, frame in pairs(self.frames) do
        if unitKey ~= "castbar" then
            self:ApplySingleFrameSettings(frame, unitKey)
        end
    end

    for groupKey, header in pairs(self.headers) do
        self:ApplyHeaderSettings(header, groupKey)
    end

    self:ApplyBossLayout()
    self:RefreshCastbarLayout()
    self:RefreshCastbarStyle()
    self:RefreshPreviewVisibility()
    self:ApplyTestModeToSingles()
    self:UpdateMovers()
    self:ApplyMasqueSettings()
end

function UnitFrames:OnThemeChanged()
    self:RefreshAllFrames()
end

function UnitFrames:OnConfigRestored()
    self:RefreshAllFrames()
end

function UnitFrames:StyleFrame(frame)
    local unit = frame.unit or "unit"
    local unitKey = unit
    local parent = frame:GetParent()
    local parentName = parent and parent:GetName() or ""

    if parentName == "TwichUIUF_PartyHeader" then
        unitKey = "partyMember"; frame.isHeaderChild = true
    elseif parentName == "TwichUIUF_RaidHeader" then
        unitKey = "raidMember"; frame.isHeaderChild = true
    elseif parentName == "TwichUIUF_TankHeader" then
        unitKey = "tankMember"; frame.isHeaderChild = true
    elseif unit:match("^boss") then
        unitKey = "boss"
    end

    local capturedUnitKey = unitKey
    frame._unitKey = capturedUnitKey

    frame:SetAttribute("useparent-unit", true)
    frame:RegisterForClicks("AnyUp")
    frame:HookScript("OnShow", function(self)
        if self._forceHideFrame then
            self:Hide()
        end
    end)

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    health:SetHeight(30)
    health.colorClass = false; health.colorDisconnected = false
    health.colorReaction = false; health.colorTapping = false
    health.frequentUpdates = true
    -- Background texture layer: fills the entire health bar area and shows in the
    -- "lost health" (empty) region behind the StatusBar fill.  Texture is controlled
    -- via db.bgTexture; color is driven by palette.background in ApplyFrameColors.
    local healthBg = health:CreateTexture(nil, "BACKGROUND")
    healthBg:SetAllPoints(health)
    healthBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    health.bg = healthBg
    health.PostUpdate = function(healthBar, unit2, cur, max)
        UnitFrames:ApplySmoothBarValue(healthBar, cur, max)
        local palette = UnitFrames:GetPalette(capturedUnitKey, unit2)
        healthBar:SetStatusBarColor(palette.health[1], palette.health[2], palette.health[3], 1)
    end
    frame.Health = health

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -1)
    power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -1)
    power:SetHeight(10)
    local powerBg = power:CreateTexture(nil, "BACKGROUND")
    powerBg:SetAllPoints(power)
    powerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    power.bg = powerBg
    local powerBorder = CreateFrame("Frame", nil, power, "BackdropTemplate")
    powerBorder:SetPoint("TOPLEFT", power, "TOPLEFT", -1, 1)
    powerBorder:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 1, -1)
    powerBorder:SetFrameLevel(math_max(0, power:GetFrameLevel() - 1))
    powerBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    powerBorder:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)
    power.border = powerBorder
    power.colorClass = false; power.colorDisconnected = false
    power.colorReaction = false; power.colorTapping = false; power.colorPower = false
    power.frequentUpdates = true
    -- oUF's Power:Enable() unconditionally calls element:Show(), which happens after
    -- StyleFrame returns.  This hook fires synchronously when that Show() is called and
    -- immediately re-hides the bar if we configured it to be off (_forceHide flag).
    power:HookScript("OnShow", function(self)
        if self._forceHide then
            self:Hide()
            if self.border then self.border:Hide() end
        end
    end)
    -- oUF's Power:PostUpdate signature is (unit, cur, min, max) — the 4th arg is the
    -- minimum, not the maximum. Capturing it as 'max' caused SetMinMaxValues(0, min=0)
    -- which left the bar permanently empty. We name the 4th param _min and take max 5th.
    power.PostUpdate = function(powerBar, unit2, cur, _min, max)
        local effShow = UnitFrames:GetEffectiveShowPower(capturedUnitKey)
        -- If power bar is configured off, prevent oUF re-showing it during update events.
        if not effShow then
            powerBar:SetHeight(0) -- collapse so health fills the full frame
            powerBar:Hide()
            if powerBar.border then powerBar.border:Hide() end
            return
        end
        -- Check role restriction first (cached — usually a no-op).
        -- For collapsed bars the heavy work below is skipped entirely.
        UnitFrames:UpdatePowerBarForRole(powerBar, capturedUnitKey, unit2)
        if powerBar._roleCollapsed then return end
        UnitFrames:ApplySmoothBarValue(powerBar, cur, max)
        local col = UnitFrames:ResolvePowerColor(capturedUnitKey, unit2)
        powerBar:SetStatusBarColor(col[1], col[2], col[3], 1)
    end
    -- PostUpdateColor fires from oUF's UpdateColor path (e.g. power type changes,
    -- zone transitions). When all colorXxx flags are false oUF skips SetStatusBarColor
    -- entirely, so we must force our resolved color here to avoid a black bar.
    power.PostUpdateColor = function(powerBar, unit2, _color, _r, _g, _b)
        local effShow = UnitFrames:GetEffectiveShowPower(capturedUnitKey)
        if not effShow then
            powerBar:SetHeight(0) -- collapse so health fills the full frame
            powerBar:Hide()
            if powerBar.border then powerBar.border:Hide() end
            return
        end
        UnitFrames:UpdatePowerBarForRole(powerBar, capturedUnitKey, unit2)
        if powerBar._roleCollapsed then return end
        local col = UnitFrames:ResolvePowerColor(capturedUnitKey, unit2)
        powerBar:SetStatusBarColor(col[1], col[2], col[3], 1)
    end
    frame.Power = power

    -- Class power bar (player only)
    if capturedUnitKey == "player" then
        local classPower = {}
        local classContainer = CreateFrame("Frame", nil, frame)
        classContainer:SetSize(260, 10)
        classContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
        classPower.container = classContainer
        classPower.PostVisibility = function(element, isVisible)
            local cfg = UnitFrames:GetDB().classBar or {}
            local shouldShow = cfg.enabled ~= false and isVisible
            UFDebug(string.format("ClassPower.PostVisibility: isVisible=%s enabled=%s → container shown=%s",
                tostring(isVisible), tostring(cfg.enabled ~= false), tostring(shouldShow)))
            element.container:SetShown(shouldShow)
        end
        classPower.PostUpdate = function(element, unit2, min2, max2, hasMaxChanged)
            -- Guard: ApplyClassBarSettings calls ForceUpdate which re-fires PostUpdate.
            -- Without this guard the two functions recurse infinitely and freeze the client.
            if element._applyingSettings then
                UFDebug("ClassPower.PostUpdate: skipped (inside ApplyClassBarSettings)")
                return
            end
            UFDebug(string.format("ClassPower.PostUpdate: hasMaxChanged=%s",
                tostring(hasMaxChanged)))
            -- Re-run the full layout when the class resource maximum changes
            -- (e.g. spec swap from 5 to 6 segments or vice-versa).
            if hasMaxChanged then
                UnitFrames:ApplyClassBarSettings(frame, capturedUnitKey)
            end
        end
        classPower.PostUpdateColor = function(element, color)
            UnitFrames:ApplyClassBarColors(frame, color)
        end
        for i = 1, 10 do
            local bar = CreateFrame("StatusBar", nil, classContainer, "BackdropTemplate")
            bar:SetMinMaxValues(0, 1); bar:SetValue(0)
            bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            bar:SetBackdropColor(0.05, 0.06, 0.08, 0.9)
            bar:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)
            classPower[i] = bar
        end
        frame.ClassPower = classPower
    end

    local nameFS = health:CreateFontString(nil, "OVERLAY")
    nameFS:SetPoint("LEFT", health, "LEFT", 4, 0)
    nameFS:SetPoint("RIGHT", health, "RIGHT", -56, 0)
    nameFS:SetJustifyH("LEFT")
    frame.Name = nameFS

    local healthValue = health:CreateFontString(nil, "OVERLAY")
    healthValue:SetPoint("RIGHT", health, "RIGHT", -4, 0)
    healthValue:SetJustifyH("RIGHT")
    frame.HealthValue = healthValue

    local powerValue = power:CreateFontString(nil, "OVERLAY")
    powerValue:SetPoint("RIGHT", power, "RIGHT", -4, 0)
    powerValue:SetJustifyH("RIGHT")
    frame.PowerValue = powerValue

    local auras = CreateFrame("Frame", nil, frame)
    auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 6)
    auras:SetHeight(18); auras:SetWidth(160)
    auras.initialAnchor = "BOTTOMLEFT"
    auras["growth-x"] = "RIGHT"
    auras["growth-y"] = "UP"
    auras.size = 18; auras.spacing = 2; auras.num = 8
    auras:HookScript("OnShow", function(self)
        if self._forceHide then
            self:Hide()
        end
    end)
    frame.Auras = auras

    -- Embedded castbar for non-player units
    if capturedUnitKey ~= "player" then
        local castbar = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
        castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
        castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
        castbar:SetHeight(12)
        castbar:SetMinMaxValues(0, 1); castbar:SetValue(0)
        castbar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        castbar:SetBackdropColor(0.05, 0.06, 0.08, 0.9)
        castbar:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)
        local cbText = castbar:CreateFontString(nil, "OVERLAY")
        cbText:SetPoint("LEFT", castbar, "LEFT", 4, 0)
        cbText:SetPoint("RIGHT", castbar, "RIGHT", -30, 0)
        cbText:SetJustifyH("LEFT"); castbar.Text = cbText
        local cbTime = castbar:CreateFontString(nil, "OVERLAY")
        cbTime:SetPoint("RIGHT", castbar, "RIGHT", -3, 0)
        cbTime:SetJustifyH("RIGHT"); castbar.Time = cbTime
        local cbIcon = castbar:CreateTexture(nil, "OVERLAY")
        cbIcon:SetSize(12, 12)
        cbIcon:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
        cbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92); castbar.Icon = cbIcon
        castbar:HookScript("OnShow", function(self)
            if self._forceHide then
                self:Hide()
            end
        end)
        local capturedCBScope = ResolveCastbarScopeByUnitKey(capturedUnitKey)
        castbar.PostCastStart = function(cb)
            local db2 = UnitFrames:GetDB()
            local cfg = (db2.castbars and db2.castbars[capturedCBScope]) or {}
            if cfg.enabled == false or cb._forceHide then cb:Hide() end
        end
        castbar.PostChannelStart = castbar.PostCastStart
        frame.Castbar = castbar
    end

    -- Attach the Aura Watcher state table. Must come before EnsureBackdrop so that
    -- AWUpdate can safely be called at any time after StyleFrame completes.
    self:AWAttach(frame)

    EnsureBackdrop(frame)

    -- Target highlight
    local targetHL = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    targetHL:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    targetHL:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    targetHL:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 3))
    targetHL:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    targetHL:SetBackdropBorderColor(1, 0.82, 0, 0)
    targetHL:Hide()
    frame.TwichTargetHighlight = targetHL

    -- Target glow: 8 gradient textures forming a soft outer halo.
    -- Rendered one level below the unit frame so the interior is covered by
    -- the frame's own content. SetClipsChildren(false) lets them spill outward.
    local glowContainer = CreateFrame("Frame", nil, frame)
    glowContainer:SetAllPoints(frame)
    glowContainer:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
    glowContainer:SetClipsChildren(false)
    glowContainer:Hide()
    local function MkGTex()
        local t = glowContainer:CreateTexture(nil, "BACKGROUND")
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetBlendMode("ADD")
        return t
    end
    glowContainer._top    = MkGTex()
    glowContainer._bottom = MkGTex()
    glowContainer._left   = MkGTex()
    glowContainer._right  = MkGTex()
    frame.TwichTargetGlow = glowContainer

    -- Mouseover highlight
    local hoverHL         = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    hoverHL:SetAllPoints(frame)
    hoverHL:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 2))
    hoverHL:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    hoverHL:SetBackdropColor(1, 1, 1, 0)
    hoverHL:Hide()
    frame.TwichMouseoverHighlight = hoverHL

    frame:SetScript("OnEnter", function(self2)
        self2.isHovering = true
        UnitFrames:UpdateUnitHighlights(self2)
    end)
    frame:SetScript("OnLeave", function(self2)
        self2.isHovering = false
        UnitFrames:UpdateUnitHighlights(self2)
    end)

    self:ApplyFrameFonts(frame, unitKey)
    self:ApplyTextTags(frame, unitKey)
    self:ApplySingleFrameSettings(frame, unitKey)
end

function UnitFrames:CreateCastbarFrame()
    if self.frames.castbar then
        return self.frames.castbar
    end

    local frame = CreateFrame("StatusBar", "TwichUIUnitFramesPlayerCastbar", UIParent, "BackdropTemplate")
    frame:SetMinMaxValues(0, 1)
    frame:SetValue(0)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.bg:SetColorTexture(0.05, 0.06, 0.08, 0.9)

    -- Wrap the icon in a Button so Masque can skin it.
    -- frame.icon remains the texture (backward-compatible); frame.iconButton
    -- is what gets positioned and registered with Masque.
    local iconButton = CreateFrame("Button", nil, frame)
    iconButton:SetSize(20, 20)
    iconButton:SetPoint("RIGHT", frame, "LEFT", -6, 0) -- default; overridden by RefreshCastbarLayout
    local iconTex = iconButton:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(iconButton)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.iconButton = iconButton
    frame.icon = iconTex -- :SetTexture / :SetShown still work on this

    frame.spellText = frame:CreateFontString(nil, "OVERLAY")
    frame.spellText:SetPoint("LEFT", frame, "LEFT", 6, 0)

    frame.timeText = frame:CreateFontString(nil, "OVERLAY")
    frame.timeText:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

    frame:HookScript("OnShow", function(self)
        if self._forceHide then
            self:Hide()
        end
    end)

    self:ApplyFontObject(frame.spellText, 11)
    self:ApplyFontObject(frame.timeText, 10)

    frame._testModeOriginalParent = frame:GetParent() or UIParent
    self.frames.castbar = frame
    self:RegisterLayoutFrame("castbar", frame)
    return frame
end

ApplyStandaloneCastbarTextAnchors = function(castbar, settings)
    if not castbar then
        return
    end

    settings = settings or {}
    local showIcon = settings.showIcon ~= false
    local iconPosition = settings.iconPosition or "outside"
    local iconSide = settings.iconSide or "left"
    local iconSize = Clamp(settings.iconSize or settings.height or 20, 12, 50)

    local defaultSpellOffsetX = 6
    if showIcon and iconPosition == "inside" and iconSide ~= "right" then
        defaultSpellOffsetX = iconSize + 8
    end

    if castbar.spellText then
        castbar.spellText:ClearAllPoints()
        castbar.spellText:SetPoint(
            settings.spellPoint or "LEFT",
            castbar,
            settings.spellRelativePoint or settings.spellPoint or "LEFT",
            settings.spellOffsetX ~= nil and tonumber(settings.spellOffsetX) or defaultSpellOffsetX,
            settings.spellOffsetY ~= nil and tonumber(settings.spellOffsetY) or 0
        )
    end

    if castbar.timeText then
        castbar.timeText:ClearAllPoints()
        castbar.timeText:SetPoint(
            settings.timePoint or "RIGHT",
            castbar,
            settings.timeRelativePoint or settings.timePoint or "RIGHT",
            settings.timeOffsetX ~= nil and tonumber(settings.timeOffsetX) or -6,
            settings.timeOffsetY ~= nil and tonumber(settings.timeOffsetY) or 0
        )
    end
end

function UnitFrames:RefreshCastbarLayout()
    local castbar = self:CreateCastbarFrame()
    local db = self:GetDB()
    local settings = db.castbar or {}
    local layout = self:GetLayoutSettings("castbar")

    castbar:ClearAllPoints()
    castbar:SetPoint(
        layout.point or "BOTTOM",
        UIParent,
        layout.relativePoint or "BOTTOM",
        tonumber(layout.x) or -260,
        tonumber(layout.y) or 220
    )

    castbar:SetSize(Clamp(settings.width or 260, 120, 600), Clamp(settings.height or 20, 10, 60))
    if settings.enabled == false then
        castbar._forceHide = true
        castbar:Hide()
    elseif db.testMode == true then
        castbar._forceHide = true
        castbar:Hide()
    elseif not self._castbarState then
        castbar._forceHide = nil
        -- Only show if a cast is actually in progress; hide on initial load / layout refresh.
        castbar:Hide()
    else
        castbar._forceHide = nil
    end
    castbar:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
    castbar:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))

    local iconSize = Clamp(settings.iconSize or settings.height or 20, 12, 50)
    local showIcon = settings.showIcon ~= false
    if castbar.iconButton then
        castbar.iconButton:SetSize(iconSize, iconSize)
        castbar.iconButton:SetShown(showIcon)
    end
    if castbar.icon then
        castbar.icon:SetShown(showIcon)
    end
    if self._masqueGroup and self._masqueGroup.ReSkin then
        self._masqueGroup:ReSkin()
    end

    -- Position the icon based on iconPosition (inside/outside) and iconSide (left/right).
    if castbar.iconButton then
        local iconPos  = settings.iconPosition or "outside"
        local iconSide = settings.iconSide or "left"
        castbar.iconButton:ClearAllPoints()
        if iconPos == "inside" then
            if iconSide == "right" then
                castbar.iconButton:SetPoint("RIGHT", castbar, "RIGHT", -4, 0)
            else -- left (default)
                castbar.iconButton:SetPoint("LEFT", castbar, "LEFT", 4, 0)
            end
        else -- outside
            if iconSide == "right" then
                castbar.iconButton:SetPoint("LEFT", castbar, "RIGHT", 6, 0)
            else -- left (default)
                castbar.iconButton:SetPoint("RIGHT", castbar, "LEFT", -6, 0)
            end
        end
    end

    ApplyStandaloneCastbarTextAnchors(castbar, settings)
end

function UnitFrames:RefreshCastbarStyle()
    local castbar = self:CreateCastbarFrame()
    local db = self:GetDB()
    local settings = db.castbar or {}
    local palette = self:GetPalette("player", "player")
    local text = self:GetTextConfigFor("player")
    local castbarTextStyle = {
        fontName = settings.fontName or text.fontName,
        outlineMode = text.outlineMode,
        shadowEnabled = text.shadowEnabled,
        shadowOffsetX = text.shadowOffsetX,
        shadowOffsetY = text.shadowOffsetY,
    }
    local texName = (settings.texture and settings.texture ~= "") and settings.texture
        or ((db.texture and db.texture ~= "") and db.texture or nil)
    castbar:SetStatusBarTexture(texName and GetLSMTexture(texName) or GetThemeTexture())
    castbar.smoothing = self:GetCastbarSmoothingMethod()
    if settings.useCustomColor == true and type(settings.color) == "table" then
        castbar:SetStatusBarColor(settings.color[1] or 1, settings.color[2] or 1, settings.color[3] or 1,
            settings.color[4] or 1)
    else
        castbar:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
    end
    castbar:SetBackdropColor(palette.background[1], palette.background[2], palette.background[3], 0.9)
    castbar:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 0.9)
    castbar.spellText:SetShown(settings.showSpellText ~= false)
    castbar.timeText:SetShown(settings.showTimeText ~= false)
    self:ApplyFontObject(castbar.spellText, Clamp(settings.spellFontSize or 11, 6, 24), castbarTextStyle.fontName,
        castbarTextStyle)
    self:ApplyFontObject(castbar.timeText, Clamp(settings.timeFontSize or 10, 6, 24), castbarTextStyle.fontName,
        castbarTextStyle)
end

function UnitFrames:UpdateCastbarElapsed()
    local state = self._castbarState
    local castbar = self.frames.castbar
    if not state or not castbar then return end

    local duration = math_max(0.001, state.endTime - state.startTime)
    local now = GetTimePreciseSec()

    if now >= state.endTime then
        self:ApplyCastbarValue(castbar, duration, duration)
        if castbar.timeText then castbar.timeText:SetText("0.0") end
        castbar:Hide()
        self._castbarState = nil
        return
    end

    local elapsed = now - state.startTime
    local timeValue = state.reverse and (duration - elapsed) or elapsed
    self:ApplyCastbarValue(castbar, timeValue, duration)
    if castbar.timeText then
        castbar.timeText:SetText(string.format("%.1f", state.endTime - now))
    end
end

function UnitFrames:BeginCastbar(name, icon, startMS, endMS, reverse)
    local castbar = self.frames.castbar
    if not castbar then return end
    local startSec = (tonumber(startMS) or 0) / 1000
    local endSec   = (tonumber(endMS) or 0) / 1000
    if startSec <= 0 or endSec <= startSec then return end
    if castbar.spellText then castbar.spellText:SetText(name or "Casting") end
    if castbar.icon then castbar.icon:SetTexture(icon or 136243) end
    local duration = math_max(0.001, endSec - startSec)
    self:ApplyCastbarValue(castbar, reverse and duration or 0, duration)
    castbar:Show()
    self._castbarState = { startTime = startSec, endTime = endSec, reverse = reverse == true }
end

function UnitFrames:StopCastbar()
    local castbar = self.frames.castbar
    if castbar then
        castbar:Hide()
    end
    self._castbarState = nil
end

function UnitFrames:HandlePlayerCastEvent(event, unit, castGUID, spellID)
    if unit and unit ~= "player" then
        return
    end

    if event == "UNIT_SPELLCAST_START" then
        local name, _, texture, startMS, endMS = UnitCastingInfo("player")
        if name then
            self:BeginCastbar(name, texture, startMS, endMS, false)
        end
        return
    end

    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, _, texture, startMS, endMS = UnitChannelInfo("player")
        if name then
            self:BeginCastbar(name, texture, startMS, endMS, true)
        end
        return
    end

    if event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    then
        self:StopCastbar()
        return
    end
end

function UnitFrames:SpawnSingleFrame(oUF, unit, key)
    local frame = oUF:Spawn(unit, "TwichUIUF_" .. key)
    frame.key = key
    frame._testModeOriginalParent = frame:GetParent() or UIParent
    self.frames[key] = frame
    self:RegisterLayoutFrame(key, frame)
    return frame
end

function UnitFrames:SpawnBossFrames(oUF)
    if self.bossAnchor then
        return
    end

    self.bossAnchor = CreateFrame("Frame", "TwichUIUF_BossAnchor", UIParent)
    self.bossAnchor:SetSize(260, 220)
    self:RegisterLayoutFrame("boss", self.bossAnchor)

    for index = 1, 5 do
        local key = "boss" .. index
        local frame = self:SpawnSingleFrame(oUF, key, key)
        if index == 1 then
            frame:SetPoint("TOP", self.bossAnchor, "TOP", 0, 0)
        else
            frame:SetPoint("TOP", self.frames["boss" .. (index - 1)], "BOTTOM", 0, -8)
        end
    end
end

function UnitFrames:SpawnHeaders(oUF)
    if self.headers.party then
        UFDebug("SpawnHeaders: skipped (already spawned)")
        return
    end

    UFDebug("SpawnHeaders: creating party/raid/tank headers")

    self.headers.party = oUF:SpawnHeader(
        "TwichUIUF_PartyHeader",
        nil,
        "showParty", true,
        "showPlayer", true,
        "showSolo", false,
        "yOffset", -8,
        "point", "TOP"
    )
    UFDebug(string.format("SpawnHeaders: party header = %s",
        tostring(self.headers.party and self.headers.party:GetName() or "nil")))

    self.headers.raid = oUF:SpawnHeader(
        "TwichUIUF_RaidHeader",
        nil,
        "showRaid", true,
        "showParty", false,
        "showSolo", false,
        "groupBy", "GROUP",
        "groupingOrder", "1,2,3,4,5,6,7,8",
        "yOffset", -6,
        "point", "TOP",
        "maxColumns", 8,
        "unitsPerColumn", 5
    )

    self.headers.tank = oUF:SpawnHeader(
        "TwichUIUF_TankHeader",
        nil,
        "showRaid", true,
        "showParty", false,
        "showSolo", false,
        "groupFilter", "MAINTANK,MAINASSIST",
        "yOffset", -6,
        "point", "TOP",
        "maxColumns", 1,
        "unitsPerColumn", 8
    )

    self:RegisterLayoutFrame("party", self.headers.party)
    self:RegisterLayoutFrame("raid", self.headers.raid)
    self:RegisterLayoutFrame("tank", self.headers.tank)
    UFDebug("SpawnHeaders: done")
end

function UnitFrames:EnsureStyle()
    local oUF = GetOUF()
    if not oUF then
        return false
    end

    if self.styleRegistered then
        return true
    end

    oUF:RegisterStyle(STYLE_NAME, function(frame)
        UnitFrames:StyleFrame(frame)
    end)

    self.styleRegistered = true
    return true
end

function UnitFrames:SpawnFrames()
    local oUF = GetOUF()
    if not oUF then
        return false
    end

    if not self:EnsureStyle() then
        return false
    end

    oUF:SetActiveStyle(STYLE_NAME)

    oUF:Factory(function(factory)
        if UnitFrames.frames.player then
            UnitFrames:RefreshAllFrames()
            return
        end

        UnitFrames:SpawnSingleFrame(factory, "player", "player")
        UnitFrames:SpawnSingleFrame(factory, "target", "target")
        UnitFrames:SpawnSingleFrame(factory, "targettarget", "targettarget")
        UnitFrames:SpawnSingleFrame(factory, "focus", "focus")
        UnitFrames:SpawnSingleFrame(factory, "pet", "pet")

        UnitFrames:SpawnBossFrames(factory)
        UnitFrames:SpawnHeaders(factory)

        UnitFrames:CreateCastbarFrame()
        UnitFrames:RefreshAllFrames()
    end)

    return true
end

function UnitFrames:BuildDebugReport()
    local lines = { "TwichUI Unit Frames Debug Report", "" }
    local db = self:GetDB()

    tinsert(lines, string.format("Module enabled: %s", tostring(db.enabled)))
    tinsert(lines, string.format("Scale: %.2f  Alpha: %.2f", db.scale or 1, db.frameAlpha or 1))
    tinsert(lines, string.format("Texture: %s", tostring(db.texture or "default")))
    tinsert(lines, "")

    local frameKeys = {}
    for k in pairs(self.frames or {}) do tinsert(frameKeys, k) end
    table.sort(frameKeys)

    tinsert(lines, string.format("Spawned frames: %d", #frameKeys))
    for _, k in ipairs(frameKeys) do
        local f = self.frames[k]
        if f then
            local shown = f.IsShown and f:IsShown() or false
            local w = f.GetWidth and math.floor(f:GetWidth() + 0.5) or 0
            local h = f.GetHeight and math.floor(f:GetHeight() + 0.5) or 0
            local unit = f.unit and tostring(f.unit) or "(no unit)"
            tinsert(lines, string.format("  [%s] %s  %dx%d  visible:%s", k, unit, w, h, shown and "yes" or "no"))
        end
    end
    tinsert(lines, "")

    -- Castbar state
    tinsert(lines, "Castbar:")
    local castbar = self.frames.castbar
    if castbar then
        local shown = castbar.IsShown and castbar:IsShown() or false
        local w = castbar.GetWidth and math.floor(castbar:GetWidth() + 0.5) or 0
        local h = castbar.GetHeight and math.floor(castbar:GetHeight() + 0.5) or 0
        tinsert(lines, string.format("  frame: %dx%d  visible:%s", w, h, shown and "yes" or "no"))
        local state = self._castbarState
        if state then
            tinsert(lines, string.format("  casting: end=%.2f  reverse=%s", state.endTime or 0, tostring(state.reverse)))
        else
            tinsert(lines, "  casting: idle")
        end
        local ib = castbar.iconButton
        if ib then
            local ibShown = ib.IsShown and ib:IsShown() or false
            tinsert(lines, string.format("  iconButton: visible:%s", ibShown and "yes" or "no"))
        end
    else
        tinsert(lines, "  not created")
    end
    tinsert(lines, "")

    -- Group Headers (party / raid / tank)
    local headerKeys = {}
    for k in pairs(self.headers or {}) do tinsert(headerKeys, k) end
    table.sort(headerKeys)
    tinsert(lines, string.format("Group headers: %d", #headerKeys))
    for _, k in ipairs(headerKeys) do
        local h = self.headers[k]
        if h then
            local shown      = h.IsShown and h:IsShown() or false
            local w          = h.GetWidth and math.floor(h:GetWidth() + 0.5) or 0
            local hgt        = h.GetHeight and math.floor(h:GetHeight() + 0.5) or 0
            local showAttr   = h.GetAttribute and h:GetAttribute("showParty") or h:GetAttribute("showRaid")
            local childCount = 0
            for _ in pairs({ h:GetChildren() }) do childCount = childCount + 1 end
            -- Count how many children are shown (i.e. have a live unit)
            local shownChildren = 0
            for i = 1, select("#", h:GetChildren()) do
                local c = select(i, h:GetChildren())
                if c and c.IsShown and c:IsShown() then shownChildren = shownChildren + 1 end
            end
            local posStr = "(no pos)"
            if h.GetPoint and h:GetNumPoints() > 0 then
                local pt, _, rpt, ox, oy = h:GetPoint(1)
                posStr = string.format("%s/%s %.0f,%.0f", pt or "?", rpt or "?", ox or 0, oy or 0)
            end
            tinsert(lines, string.format("  [%s]  %dx%d  visible:%s  show=%s  children:%d(shown:%d)  pos:%s",
                k, w, hgt, shown and "yes" or "no",
                tostring(showAttr), childCount, shownChildren, posStr))
            -- List each styled child
            for i = 1, select("#", h:GetChildren()) do
                local c = select(i, h:GetChildren())
                if c and c.Health then
                    -- c.unit is set by SecureGroupHeaderTemplate (a secret string).
                    -- GetAttribute("unit") returns the same value as a safe plain string.
                    local cu = c:GetAttribute("unit") or "(none)"
                    local cs = c.IsShown and c:IsShown() or false
                    local cw = c.GetWidth and math.floor(c:GetWidth() + 0.5) or 0
                    local ch = c.GetHeight and math.floor(c:GetHeight() + 0.5) or 0
                    local memberKey = (k == "party" and "partyMember") or (k == "raid" and "raidMember") or
                        (k == "tank" and "tankMember") or nil
                    local roleState = memberKey and GetDebugRoleIconState(c, memberKey) or nil
                    tinsert(lines,
                        string.format("    child%d: unit=%-8s %dx%d shown=%s roleIcon:%s/%s role=%s filter=%s",
                            i, cu, cw, ch, tostring(cs),
                            roleState and tostring(roleState.enabled) or "n/a",
                            roleState and (roleState.shown and "shown" or "hidden") or "n/a",
                            roleState and roleState.role or "n/a",
                            roleState and roleState.filter or "n/a"))
                end
            end
        end
    end
    tinsert(lines, "")

    -- Movers
    local lockFrames = db.lockFrames
    tinsert(lines, string.format("Lock frames: %s  (movers %s)",
        tostring(lockFrames), lockFrames == false and "SHOWN" or "hidden"))
    local moverKeys = {}
    for k in pairs(self.movers or {}) do tinsert(moverKeys, k) end
    table.sort(moverKeys)
    tinsert(lines, string.format("Movers: %d", #moverKeys))
    for _, k in ipairs(moverKeys) do
        local mv = self.movers[k]
        if mv then
            local mvShown = mv.IsShown and mv:IsShown() or false
            local mvW = mv.GetWidth and math.floor(mv:GetWidth() + 0.5) or 0
            local mvH = mv.GetHeight and math.floor(mv:GetHeight() + 0.5) or 0
            local mvPos = "(no pos)"
            if mv.GetNumPoints and mv:GetNumPoints() > 0 then
                local pt, _, rpt, ox, oy = mv:GetPoint(1)
                mvPos = string.format("%s/%s %.0f,%.0f", pt or "?", rpt or "?", ox or 0, oy or 0)
            end
            tinsert(lines, string.format("  [%s]  %dx%d  visible:%s  pos:%s",
                k, mvW, mvH, mvShown and "yes" or "no", mvPos))
        end
    end

    return table.concat(lines, "\n")
end

function UnitFrames:OnInitialize()
    local db = self:GetDB()
    db.enabled = db.enabled ~= false

    local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if DebugConsole and DebugConsole.RegisterSource then
        DebugConsole:RegisterSource("unitframes", {
            title = "Unit Frames",
            order = 40,
            aliases = { "uf", "unitframe", "frames", "ouf" },
            maxLines = 200,
            buildReport = function()
                return UnitFrames:BuildDebugReport()
            end,
        })
    end
end

-- Refresh target highlights on every frame when the player's target changes.
-- Without this, frames that were previously targeted keep their highlight until
-- the next time the mouse enters/leaves them.
function UnitFrames:OnTargetChanged()
    for _, frame in pairs(self.frames) do
        if frame and frame.TwichTargetHighlight then
            self:UpdateUnitHighlights(frame)
        end
    end
    for _, header in pairs(self.headers) do
        if header then
            for i = 1, select('#', header:GetChildren()) do
                local child = select(i, header:GetChildren())
                if child and child.TwichTargetHighlight then
                    self:UpdateUnitHighlights(child)
                end
            end
        end
    end
end

-- Refresh mouseover highlights on every frame when the WoW mouseover unit changes.
-- This ensures that frames whose unit matches the new mouseover unit light up even
-- if the cursor moved to them between frames without triggering OnEnter/OnLeave.
function UnitFrames:OnMouseoverChanged()
    for _, frame in pairs(self.frames) do
        if frame and frame.TwichMouseoverHighlight then
            self:UpdateUnitHighlights(frame)
        end
    end
    for _, header in pairs(self.headers) do
        if header then
            for i = 1, select('#', header:GetChildren()) do
                local child = select(i, header:GetChildren())
                if child and child.TwichMouseoverHighlight then
                    self:UpdateUnitHighlights(child)
                end
            end
        end
    end
end

function UnitFrames:OnEnable()
    -- Migration: old default was nil (no value stored) or false for healerOnlyPower.
    -- New semantics: nil means ON by default; false means explicitly OFF. If savedvars has
    -- an explicit false from before the default was changed to healer-only-ON, clear it
    -- so the correct default (healer-only power bar) takes effect for all existing profiles.
    -- Guarded by a one-time migration flag so this doesn't clobber future explicit choices.
    do
        local db = self:GetDB()
        db._migrated = db._migrated or {}
        if not (db._migrated and db._migrated.healerOnlyPower) then
            if db.groups then
                for _, gk in ipairs({ "party", "raid" }) do
                    if type(db.groups[gk]) == "table" and db.groups[gk].healerOnlyPower == false then
                        db.groups[gk].healerOnlyPower = nil
                    end
                end
            end
            db._migrated.healerOnlyPower = true
        end

        if not db._migrated.partyRoleIconDefault then
            db.groups = db.groups or {}
            db.groups.party = db.groups.party or {}
            db.groups.party.roleIcon = db.groups.party.roleIcon or {}
            if db.groups.party.roleIcon.enabled == nil then
                db.groups.party.roleIcon.enabled = true
            end
            db._migrated.partyRoleIconDefault = true
        end

        if not db._migrated.partyRoleIconFilterDefault then
            db.groups = db.groups or {}
            db.groups.party = db.groups.party or {}
            db.groups.party.roleIcon = db.groups.party.roleIcon or {}
            local filter = db.groups.party.roleIcon.filter
            if filter == nil or filter == "nonDps" then
                db.groups.party.roleIcon.filter = "all"
            end
            db._migrated.partyRoleIconFilterDefault = true
        end
    end

    if not self:SpawnFrames() then
        T:Print("UnitFrames: oUF is unavailable. Ensure Libraries/oUF/oUF.xml is loaded.")
        return
    end

    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")
    self:RegisterMessage("TWICH_CONFIG_RESTORED", "OnConfigRestored")

    self:RegisterEvent("UNIT_SPELLCAST_START", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "HandlePlayerCastEvent")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "OnMouseoverChanged")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "RefreshAllFrames")
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "RefreshAllFrames")
    self:RegisterEvent("ROLE_CHANGED_INFORM", "RefreshAllFrames")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshAllFrames")

    self.ticker = C_Timer.NewTicker(0.05, function()
        if UnitFrames._castbarState then
            UnitFrames:UpdateCastbarElapsed()
        end
        if UnitFrames._queuedRefresh and not InCombatLockdown() then
            UnitFrames._queuedRefresh = false
            UnitFrames:RefreshAllFrames()
        end
    end)

    self:RefreshAllFrames()

    -- Apply Masque skinning if enabled (gated by db.castbar.masqueEnabled).
    -- ApplyMasqueSettings is also called from RefreshAllFrames so toggling the
    -- option takes effect without a UI reload.
    self:ApplyMasqueSettings()
end

--- Applies or tears down Masque skinning for the standalone castbar icon.
--- Safe to call multiple times; initialises Masque only when masqueEnabled is true
--- and tears it down (deletes the group) when it is disabled.
function UnitFrames:ApplyMasqueSettings()
    local db = self:GetDB()
    local castbarCfg = type(db.castbar) == "table" and db.castbar or {}
    local wantMasque = castbarCfg.masqueEnabled == true

    if wantMasque then
        -- Initialise only once; ReSkin on subsequent calls
        if not self._masqueGroup then
            local Masque = LibStub and LibStub("Masque", true)
            if Masque then
                local castbar = self.frames.castbar
                if castbar and castbar.iconButton then
                    local masqueGroup = Masque:Group("TwichUI Reformed", "Castbar Icon")
                    masqueGroup:AddButton(castbar.iconButton, {
                        Icon         = castbar.icon,
                        Highlight    = nil,
                        Normal       = false,
                        Pushed       = false,
                        Disabled     = false,
                        Checked      = false,
                        Border       = false,
                        Cooldown     = nil,
                        AutoCast     = nil,
                        AutoCastable = nil,
                        HotKey       = nil,
                        Count        = false,
                        Name         = nil,
                        Duration     = false,
                        FloatingBG   = nil,
                        Flash        = nil,
                    })
                    masqueGroup:ReSkin()
                    self._masqueGroup = masqueGroup
                end
            end
        elseif self._masqueGroup.ReSkin then
            self._masqueGroup:ReSkin()
        end
    else
        -- Masque was disabled; remove the group to restore default icon appearance
        if self._masqueGroup then
            if type(self._masqueGroup.Delete) == "function" then
                self._masqueGroup:Delete()
            end
            self._masqueGroup = nil
        end
    end
end

function UnitFrames:OnDisable()
    self:UnregisterMessage("TWICH_THEME_CHANGED")
    self:UnregisterMessage("TWICH_CONFIG_RESTORED")
    self:UnregisterAllEvents()

    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end

    for _, frame in pairs(self.frames) do
        if frame then
            self:StopSmoothBar(frame.Health)
            self:StopSmoothBar(frame.Power)
            frame:Hide()
        end
    end

    for _, header in pairs(self.headers) do
        if header then
            header:Hide()
        end
    end

    for _, preview in pairs(self.previewFrames) do
        if preview then
            preview:Hide()
        end
    end

    for _, mover in pairs(self.movers) do
        if mover then
            mover:Hide()
        end
    end

    self:StopCastbar()
end

function UnitFrames:SetTestMode(enabled)
    local db = self:GetDB()
    db.testMode = enabled == true
    self:RefreshAllFrames()
end

function UnitFrames:SetFrameLock(locked)
    local db = self:GetDB()
    db.lockFrames = locked == true
    if locked and self._moverInspector then
        self._moverInspector:Hide()
    end
    self:UpdateMovers()
end

function UnitFrames:RefreshFromOptions()
    if self:IsEnabled() then
        self:RefreshAllFrames()
    end
end
