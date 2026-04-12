---@diagnostic disable: undefined-field, undefined-global
--[[
    TwichUI Nameplates

    Provides fully custom nameplates that overlay the Blizzard nameplate frames.
    All appearance is driven by the TwichUI theme system and per-module settings.

    Features:
      • Health bars with reaction / class / custom coloring + absorb overlay
      • Smooth cast bars with uninterruptible highlight and channel support
      • Name, level, elite/boss/rare indicators
      • Target / focus glow
      • Threat accent
      • Debuff icons (configurable filter, count, size)
      • Test mode with offline preview plates
      • Interface Designer extras via Movers module
      • Full theme and TWICH_THEME_CHANGED integration
      • Clean OnDisable: restores Blizzard plates and removes all custom frames

    Midnight API compliance:
      • Uses C_NamePlate.GetNamePlateForUnit / GetNamePlates
      • Uses C_UnitAuras.GetAuraSlots continuation-token pattern
      • CVars applied through pcall + C_CVar fallback
]]

local TwichRx                              = _G.TwichRx
---@type TwichUI
local T                                    = unpack(TwichRx)

---@class NameplatesModule : AceModule, AceEvent-3.0, AceTimer-3.0
local Nameplates                           = T:NewModule("Nameplates", "AceEvent-3.0", "AceTimer-3.0")

-- ── WoW API locals ──────────────────────────────────────────────────────────
local CreateFrame                          = _G.CreateFrame
local UIParent                             = _G.UIParent
local C_NamePlate                          = _G.C_NamePlate
local C_NamePlateManager                   = _G.C_NamePlateManager
local C_NamePlate_SetNamePlateSize         = C_NamePlate and C_NamePlate.SetNamePlateSize
local C_NamePlate_SetNamePlateEnemySize    = C_NamePlate and C_NamePlate.SetNamePlateEnemySize
local C_NamePlate_SetNamePlateFriendlySize = C_NamePlate and C_NamePlate.SetNamePlateFriendlySize
local C_CVar                               = _G.C_CVar
local C_UnitAuras                          = _G.C_UnitAuras
local C_Timer                              = _G.C_Timer
local C_Spell                              = _G.C_Spell
local Enum_NamePlateType                   = _G.Enum and _G.Enum.NamePlateType
local Enum_NamePlateStackType              = _G.Enum and _G.Enum.NamePlateStackType
local GetCVar                              = _G.GetCVar
local UnitReaction                         = _G.UnitReaction
local UnitExists                           = _G.UnitExists
local UnitHealth                           = _G.UnitHealth
local UnitHealthMax                        = _G.UnitHealthMax
local UnitName                             = _G.UnitName
local UnitIsPlayer                         = _G.UnitIsPlayer
local UnitIsFriend                         = _G.UnitIsFriend
local UnitCanAttack                        = _G.UnitCanAttack
local UnitLevel                            = _G.UnitLevel
local UnitIsUnit                           = _G.UnitIsUnit
local UnitClass                            = _G.UnitClass
local GetRaidTargetIndex                   = _G.GetRaidTargetIndex
local SetRaidTargetIconTexture             = _G.SetRaidTargetIconTexture
local UnitAffectingCombat                  = _G.UnitAffectingCombat
local UnitThreatSituation                  = _G.UnitThreatSituation
local UnitIsTapDenied                      = _G.UnitIsTapDenied
local UnitGetTotalAbsorbs                  = _G.UnitGetTotalAbsorbs
local UnitIsDeadOrGhost                    = _G.UnitIsDeadOrGhost
local UnitCastingInfo                      = _G.UnitCastingInfo
local UnitChannelInfo                      = _G.UnitChannelInfo
local UnitClassification                   = _G.UnitClassification
local UnitPower                            = _G.UnitPower
local UnitPowerMax                         = _G.UnitPowerMax
local UnitPowerType                        = _G.UnitPowerType
local UnitGroupRolesAssigned               = _G.UnitGroupRolesAssigned
local GetSpecalization                     = _G.GetSpecialization
local GetSpecalizationRole                 = _G.GetSpecializationRole
local GetTime                              = _G.GetTime
local InCombatLockdown                     = _G.InCombatLockdown
local CooldownFrame_Set                    = _G.CooldownFrame_Set
local RAID_CLASS_COLORS                    = _G.RAID_CLASS_COLORS
local C_ClassColor                         = _G.C_ClassColor
local math_max                             = math.max
local math_min                             = math.min
local math_floor                           = math.floor

-- ── Error reporting helper ────────────────────────────────────────────────────
-- Routes real (non-taint) pcall errors to the central ErrorLog.
-- Resolved lazily so Tools is guaranteed to have loaded ReportErr by the time
-- any plate event fires.
local function NpErr(context, err)
    local fn = T.Tools and T.Tools.ReportErr
    if type(fn) == "function" then fn(context, err) end
end

-- ── Profiling helpers ───────────────────────────────────────────────────────
-- Lazy reference — Profiler is assigned to T.Tools.UI.Profiler after full
-- load so we cannot cache it at file-scope init time.
local _profilerRef = nil
local function NpScope(name)
    if not _profilerRef then
        _profilerRef = T.Tools and T.Tools.UI and T.Tools.UI.Profiler
    end
    return _profilerRef and _profilerRef.BeginScope(name)
end
local function NpScopeEnd(scope)
    if scope and _profilerRef then _profilerRef.EndScope(scope) end
end

-- ── Debug logging helper ──────────────────────────────────────────────────────
local _debugConsoleRef = nil
local function NpLog(msg)
    if not _debugConsoleRef then
        _debugConsoleRef = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    end
    if _debugConsoleRef and type(_debugConsoleRef.Log) == "function" then
        _debugConsoleRef:Log("nameplates", msg, false)
    end
end

local NP_DEFAULT_WIDTH       = 220
local NP_DEFAULT_HEIGHT      = 22
local NP_DEFAULT_CAST_HEIGHT = 12
local NP_DEFAULT_AURA_SIZE   = 20
local NP_DEFAULT_AURA_MAX    = 5
local NP_MAX_AURA_POOL       = 10 -- pre-allocated icons per plate
local TARGET_GROW_ANIM_SEC   = 0.14
local RANGE_FADE_ANIM_SEC    = 0.16
local STATE_FADE_ANIM_SEC    = 0.18
local NP_BASE_FRAME_LEVEL    = 140
local NP_BASE_GLOW_LEVEL     = 138
local NP_CAST_FRAME_LEVEL    = 170
local NP_CAST_GLOW_LEVEL     = 168
local NP_TARGET_FRAME_LEVEL  = 180
local NP_TARGET_GLOW_LEVEL   = 178

-- Default reaction colours used when healthColorMode = "reaction"
-- These are the built-in fallbacks; users can override each via DB.
local COLOR_HOSTILE          = { 0.87, 0.25, 0.25, 1 }
local COLOR_FRIENDLY         = { 0.28, 0.88, 0.42, 1 }
local COLOR_NEUTRAL          = { 0.92, 0.77, 0.22, 1 }
local COLOR_TAPPED           = { 0.48, 0.48, 0.48, 1 }
local COLOR_BOSS             = { 0.90, 0.10, 0.10, 1 }
local COLOR_MINIBOSS         = { 0.75, 0.30, 0.90, 1 }
local COLOR_RARE             = { 0.50, 0.80, 1.00, 1 }
local COLOR_NPC_CASTER       = { 0.90, 0.45, 0.22, 1 }
local COLOR_CAST             = { 0.96, 0.76, 0.24, 1 }
local COLOR_CAST_UNINT       = { 0.75, 0.12, 0.12, 1 }
local COLOR_CHANNEL          = { 0.22, 0.78, 0.96, 1 }
local COLOR_AGGRO_TANK       = { 0.25, 0.90, 0.40, 1 } -- green: aggro = good for tank
local COLOR_AGGRO_DPS        = { 1.00, 0.40, 0.10, 1 } -- orange: aggro = bad for dps/healer

-- Elite / boss / rare atlas keys
local ATLAS_BOSS             = "nameplates-icon-boss-skull"
local ATLAS_ELITE            = "nameplates-icon-elite-star"
local ATLAS_RARE             = "nameplates-icon-rare"

local PLAIN_BD               = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}
-- Soft-edge backdrop for the target glow frame.
-- GlowTex creates a blurred halo; edgeSize=6 gives a visible but not overwhelming ring.
local GLOW_EDGE              = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\GlowTex.tga"
local GLOW_BD                = {
    edgeFile = GLOW_EDGE,
    edgeSize = 6,
}

-- Arrow texture base folder (contains Arrow0-72, ArrowBracket, ArrowRed, ArrowUp)
local ARROW_BASE             = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Arrows\\"
-- TexCoords for arrow textures (all assumed to be upward-pointing designs):
--   Left  arrow (RIGHT of plate facing ←): 90°CW rotation
--   Right arrow (LEFT of plate facing →): 90°CW + H-flip
-- These produce inward-pointing arrows from each side.
local ARROW_TC_LEFT          = { 1, 0, 0, 0, 1, 1, 0, 1 } -- points ← (right side of plate)
local ARROW_TC_RIGHT         = { 0, 1, 1, 1, 0, 0, 1, 0 } -- points → (left side of plate)

local function GetArrowTexPath(styleName)
    return ARROW_BASE .. (styleName or "ArrowUp") .. ".tga"
end

local function ApplyPlateFrameLevels(frame, frameLevel, glowLevel)
    if not frame then return end

    frame:SetFrameLevel(frameLevel)
    if frame.targetGlow then
        frame.targetGlow:SetFrameLevel(glowLevel)
    end
    if frame.powerContainer then
        frame.powerContainer:SetFrameLevel(frameLevel + 1)
    end
    if frame.castContainer then
        frame.castContainer:SetFrameLevel(frameLevel + 2)
    end
    if frame.auraFrame then
        frame.auraFrame:SetFrameLevel(frameLevel + 3)
    end
    if frame.raidMarkerOverlay then
        frame.raidMarkerOverlay:SetFrameLevel(frameLevel + 10)
    end
end

local LEGACY_NAME_ANCHORS = {
    BOTTOMLEFT  = "ABOVE_LEFT",
    BOTTOM      = "ABOVE_CENTER",
    BOTTOMRIGHT = "ABOVE_RIGHT",
    TOPLEFT     = "BELOW_LEFT",
    TOP         = "BELOW_CENTER",
    TOPRIGHT    = "BELOW_RIGHT",
    LEFT        = "HEALTH_LEFT",
    CENTER      = "HEALTH_CENTER",
    RIGHT       = "HEALTH_RIGHT",
}

local NAME_ANCHOR_LAYOUTS = {
    ABOVE_LEFT = { point = "BOTTOMLEFT", relativeTo = "frame", relativePoint = "TOPLEFT", x = 2, y = 0, justify = "LEFT" },
    ABOVE_CENTER = { point = "BOTTOM", relativeTo = "frame", relativePoint = "TOP", x = 0, y = 0, justify = "CENTER" },
    ABOVE_RIGHT = { point = "BOTTOMRIGHT", relativeTo = "frame", relativePoint = "TOPRIGHT", x = -2, y = 0, justify = "RIGHT" },
    HEALTH_LEFT = { point = "LEFT", relativeTo = "healthBar", relativePoint = "LEFT", x = 4, y = 0, justify = "LEFT" },
    HEALTH_CENTER = { point = "CENTER", relativeTo = "healthBar", relativePoint = "CENTER", x = 0, y = 0, justify = "CENTER" },
    HEALTH_RIGHT = { point = "RIGHT", relativeTo = "healthBar", relativePoint = "RIGHT", x = -4, y = 0, justify = "RIGHT" },
    BELOW_LEFT = { point = "TOPLEFT", relativeTo = "frame", relativePoint = "BOTTOMLEFT", x = 2, y = 0, justify = "LEFT" },
    BELOW_CENTER = { point = "TOP", relativeTo = "frame", relativePoint = "BOTTOM", x = 0, y = 0, justify = "CENTER" },
    BELOW_RIGHT = { point = "TOPRIGHT", relativeTo = "frame", relativePoint = "BOTTOMRIGHT", x = -2, y = 0, justify = "RIGHT" },
}

local AURA_ANCHOR_LAYOUTS = {
    ABOVE_LEFT = { point = "BOTTOMLEFT", relativePoint = "TOPLEFT", x = 0, direction = 1 },
    ABOVE_CENTER = { point = "BOTTOM", relativePoint = "TOP", x = 0, direction = 1 },
    ABOVE_RIGHT = { point = "BOTTOMRIGHT", relativePoint = "TOPRIGHT", x = 0, direction = 1 },
    BELOW_LEFT = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 0, direction = -1 },
    BELOW_CENTER = { point = "TOP", relativePoint = "BOTTOM", x = 0, direction = -1 },
    BELOW_RIGHT = { point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", x = 0, direction = -1 },
}

local RAID_MARKER_POINTS = {
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    CENTER = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local function NormalizeNameAnchor(anchor)
    local normalized = LEGACY_NAME_ANCHORS[anchor] or anchor
    if NAME_ANCHOR_LAYOUTS[normalized] then
        return normalized
    end
    return "ABOVE_LEFT"
end

local function NormalizeAuraAnchor(anchor)
    if AURA_ANCHOR_LAYOUTS[anchor] then
        return anchor
    end
    return "ABOVE_LEFT"
end

local function GetAuraRowWidth(db)
    local auraSize = Clamp(db.auraSize or NP_DEFAULT_AURA_SIZE, 12, 40)
    local auraMax = Clamp(db.auraMax or NP_DEFAULT_AURA_MAX, 1, NP_MAX_AURA_POOL)
    return (auraSize * auraMax) + (math_max(0, auraMax - 1) * 2), auraSize
end

local function ApplyAuraFrameLayout(frame, db)
    if not frame or not frame.auraFrame then return end

    local layout = AURA_ANCHOR_LAYOUTS[NormalizeAuraAnchor(db.auraAnchorPoint)]
    local rowWidth, auraSize = GetAuraRowWidth(db)
    local castHeight = Clamp(db.castHeight or NP_DEFAULT_CAST_HEIGHT, 6, 30)
    local baseYOffset = (castHeight + 8) * (layout.direction or 1)
    local offsetX = Clamp(tonumber(db.auraOffsetX) or 0, -200, 200)
    local offsetY = Clamp(tonumber(db.auraOffsetY) or 0, -200, 200)

    frame.auraFrame:ClearAllPoints()
    frame.auraFrame:SetPoint(layout.point, frame, layout.relativePoint, (layout.x or 0) + offsetX, baseYOffset + offsetY)
    frame.auraFrame:SetSize(rowWidth, auraSize + 4)
end

local function ApplyAbsorbBarLayout(frame)
    if not frame or not frame.healthBar or not frame.absorbBar then return end

    local healthTexture = frame.healthBar.GetStatusBarTexture and frame.healthBar:GetStatusBarTexture()
    if not healthTexture then return end

    local barWidth = math_max(1, frame.healthBar:GetWidth() or frame:GetWidth() or NP_DEFAULT_WIDTH)
    frame.absorbBar:ClearAllPoints()
    frame.absorbBar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT", 0, 0)
    frame.absorbBar:SetPoint("BOTTOMLEFT", healthTexture, "BOTTOMRIGHT", 0, 0)
    frame.absorbBar:SetWidth(barWidth)
end

local function ApplyNameTextLayout(frame, db, width)
    if not frame or not frame.nameText then return end

    local nameText       = frame.nameText
    local nameAnchorKey  = NormalizeNameAnchor(db.nameAnchorPoint)
    local layout         = NAME_ANCHOR_LAYOUTS[nameAnchorKey] or NAME_ANCHOR_LAYOUTS.ABOVE_LEFT
    local nameOX, nameOY = db.nameOffsetX or 0, db.nameOffsetY or 0
    local anchorFrame    = (layout.relativeTo == "healthBar" and frame.healthBar) or frame
    local nameParent     = anchorFrame or frame
    local availableWidth = Clamp(width or frame:GetWidth() or db.width or NP_DEFAULT_WIDTH, 40, 600)
    local justify        = db.nameJustify or layout.justify or "LEFT"

    if layout.relativeTo == "healthBar" then
        availableWidth = Clamp((frame.healthBar and frame.healthBar:GetWidth()) or availableWidth, 40, 600)
    else
        availableWidth = Clamp(availableWidth - 4, 40, 600)
    end
    if db.nameWidth and tonumber(db.nameWidth) and tonumber(db.nameWidth) > 0 then
        availableWidth = Clamp(tonumber(db.nameWidth), 40, 600)
    end

    if nameText:GetParent() ~= nameParent then
        nameText:SetParent(nameParent)
    end
    nameText:ClearAllPoints()
    nameText:SetWidth(availableWidth)
    nameText:SetWordWrap(false)
    if nameText.SetNonSpaceWrap then nameText:SetNonSpaceWrap(false) end
    if nameText.SetMaxLines then pcall(nameText.SetMaxLines, nameText, 1) end
    nameText:SetSpacing(0)
    nameText:SetPoint(layout.point, anchorFrame, layout.relativePoint, (layout.x or 0) + nameOX, (layout.y or 0) + nameOY)
    nameText:SetJustifyH(justify)
end

local function NormalizeRaidMarkerPoint(point)
    if RAID_MARKER_POINTS[point] then
        return point
    end
    return "TOP"
end

local function ApplyRaidMarkerLayout(frame, db)
    if not frame or not frame.raidMarkerIcon then return end

    local marker = frame.raidMarkerIcon
    local point = NormalizeRaidMarkerPoint(db.raidMarkerPoint)
    local scale = Clamp(tonumber(db.raidMarkerScale) or 1, 0.5, 3)
    local size = Clamp(18 * scale, 8, 64)
    local offsetX = tonumber(db.raidMarkerOffsetX) or 0
    local offsetY = tonumber(db.raidMarkerOffsetY) or 0

    marker:ClearAllPoints()
    marker:SetSize(size, size)
    marker:SetPoint(point, frame, point, offsetX, offsetY)
end

local function EaseOutCubic(progress)
    local inv = 1 - Clamp(progress or 0, 0, 1)
    return 1 - (inv * inv * inv)
end

local function SanitizeDebugLine(value, fallback)
    local placeholder = fallback or "<secret>"
    if value == nil then return placeholder end

    local text = value
    if type(text) ~= "string" then
        local ok, converted = pcall(tostring, value)
        if not ok or type(converted) ~= "string" then
            return placeholder
        end
        text = converted
    end

    local ok, concatenated = pcall(function()
        return table.concat({ text }, "")
    end)
    if ok and type(concatenated) == "string" then
        return concatenated
    end

    return placeholder
end

-- CVars we take control of while the module is active
local NAMEPLATE_CVARS    = {
    nameplateMinAlpha              = "1",
    nameplateMinAlphaDistance      = "-1000000",
    nameplateSelectedAlpha         = "1",
    nameplateNotSelectedAlpha      = "1",
    nameplateRemovalAnimation      = "0",
    nameplateShowFriendlyBuffs     = "0",
    nameplateShowPersonalCooldowns = "0",
    nameplateResourceOnTarget      = "0",
}

-- ── Module state ─────────────────────────────────────────────────────────────
Nameplates._plates       = {} -- unitID → custom plate frame
Nameplates._platePool    = {} -- recycled plate frames waiting for reuse
Nameplates._testPlates   = {} -- list of { frame, anchor } for test mode
Nameplates._testMode     = false
Nameplates._castTestMode = false
-- Throttle table: unitID → last aura-refresh timestamp.
-- UNIT_AURA fires for every mob on every aura change; capping at ~6/sec per
-- unit prevents O(n) GetUnitAuras bursts when pulling groups.
local _auraThrottle      = {}
local AURA_THROTTLE_SEC  = 0.15

-- ── Shared cast bar ticker ────────────────────────────────────────────────────
-- A single OnUpdate closure drives ALL active cast bars instead of one per plate.
-- At 10+ casts simultaneously this cuts N callbacks/frame down to 1.
local _activeCastPlates  = {} -- frame → true
local _castTickerActive  = false
local _castTickerFrame   = CreateFrame("Frame", "TwichUI_NpCastTicker", UIParent)

local function _castTickerFn()
    local now     = GetTime()
    local anyLeft = false
    for frame in pairs(_activeCastPlates) do
        if not frame._casting then
            _activeCastPlates[frame] = nil
            if frame.castContainer then frame.castContainer:Hide() end
            -- Fire optional post-cast callback (used by cast test mode to reschedule).
            if frame._onCastEnd then frame._onCastEnd(frame) end
        else
            anyLeft       = true
            local dur     = frame._castDurationSec or 1
            local elapsed = now - (frame._castObservedAt or now)
            local clamped = math_min(elapsed, dur)
            if frame._channeling then
                frame.castBar:SetValue(math_max(0, dur - clamped))
            else
                frame.castBar:SetValue(clamped)
            end
            if elapsed >= dur then
                frame._casting = false
                _activeCastPlates[frame] = nil
                if frame.castContainer then frame.castContainer:Hide() end
                if frame._onCastEnd then frame._onCastEnd(frame) end
            end
        end
    end
    if not anyLeft then
        _castTickerFrame:SetScript("OnUpdate", nil)
        _castTickerActive = false
    end
end

local function _startCastTicker(frame)
    _activeCastPlates[frame] = true
    if not _castTickerActive then
        _castTickerActive = true
        _castTickerFrame:SetScript("OnUpdate", _castTickerFn)
    end
end

local function _stopCastTicker(frame)
    _activeCastPlates[frame] = nil
    if not next(_activeCastPlates) then
        _castTickerFrame:SetScript("OnUpdate", nil)
        _castTickerActive = false
    end
end

-- Hidden off-screen parent used to reparent Blizzard nameplate sub-frames so
-- they receive no events, take no screen space, and never become visible.
-- Matches Plater's hiddenParentFrame design.
local _hiddenPlateParent = CreateFrame("Frame", "TwichUI_HiddenNpParent", WorldFrame)
_hiddenPlateParent:SetSize(1, 1)
_hiddenPlateParent:SetPoint("CENTER", WorldFrame, "CENTER", -10000, -10000)
_hiddenPlateParent:Hide()

-- Per-blizzUF suppress lock used by the SetAlpha hook to avoid re-entry.
local _alphaLocks = {} -- blizzUF pointer (tostring) → true

-- ── Utility helpers ───────────────────────────────────────────────────────────
local function CopyColor(c, fallback)
    local src = type(c) == "table" and c or fallback or { 1, 1, 1, 1 }
    return { src[1] or 1, src[2] or 1, src[3] or 1, src[4] or 1 }
end

local function Clamp(v, lo, hi)
    local n = tonumber(v)
    if not n then return lo end
    return n < lo and lo or (n > hi and hi or n)
end

local function SetCVarSafe(name, value)
    local valueStr = tostring(value)
    local ok = pcall(_G.SetCVar, name, valueStr)
    local current = GetCVar and GetCVar(name)
    if ((not ok) or (current ~= nil and tostring(current) ~= valueStr)) and _G.C_CVar and _G.C_CVar.SetCVar then
        pcall(_G.C_CVar.SetCVar, name, valueStr)
    end
end

local function GetCVarBoolSafe(name, fallback)
    if not GetCVar then return fallback end
    local value = GetCVar(name)
    if value == nil then return fallback end
    return value == "1"
end

local function SupportsStackingBitfield()
    return C_CVar and C_CVar.GetCVarBitfield and C_CVar.SetCVarBitfield and Enum_NamePlateStackType
end

local function GetStackingBitfieldState(kind, fallback)
    if not SupportsStackingBitfield() then return fallback end
    local stackType = Enum_NamePlateStackType[kind]
    if not stackType then return fallback end

    local ok, value = pcall(C_CVar.GetCVarBitfield, "nameplateStackingTypes", stackType)
    if ok and type(value) == "boolean" then
        return value
    end

    return fallback
end

local function SetStackingBitfieldState(kind, enabled)
    if not SupportsStackingBitfield() then return end
    local stackType = Enum_NamePlateStackType[kind]
    if not stackType then return end
    pcall(C_CVar.SetCVarBitfield, "nameplateStackingTypes", stackType, enabled == true)
end

-- ── Theme helpers ─────────────────────────────────────────────────────────────
local function GetThemeModule()
    if Nameplates._themeCache then return Nameplates._themeCache end
    Nameplates._themeCache = T:GetModule("Theme", true)
    return Nameplates._themeCache
end

local function GetThemeColor(key, fallback)
    local theme = GetThemeModule()
    if theme and type(theme.GetColor) == "function" then
        local c = theme:GetColor(key)
        if type(c) == "table" then return CopyColor(c) end
    end
    return CopyColor(fallback)
end

local function GetThemeTexture()
    local LSM   = T.Libs and T.Libs.LSM
    local theme = GetThemeModule()
    if LSM and theme and type(theme.Get) == "function" then
        local name = theme:Get("statusBarTexture")
        if name and name ~= "" then
            local ok, tex = pcall(LSM.Fetch, LSM, "statusbar", name)
            if ok and type(tex) == "string" and tex ~= "" then return tex end
        end
    end
    return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

local function GetThemeFont(size)
    local LSM   = T.Libs and T.Libs.LSM
    local theme = GetThemeModule()
    if LSM and theme and type(theme.Get) == "function" then
        local name = theme:Get("globalFont")
        if name and name ~= "" and name ~= "__default" then
            local ok, path = pcall(LSM.Fetch, LSM, "font", name)
            if ok and type(path) == "string" and path ~= "" then
                return path, size or 10, "OUTLINE"
            end
        end
    end
    return _G.STANDARD_TEXT_FONT, size or 10, "OUTLINE"
end

-- Per-element font resolver: DB key overrides theme fallback.
-- key is e.g. "name", "health", "cast" — reads db[key.."Font"] etc.
-- NOTE: outline is ALWAYS read from DB so changing it takes effect without
-- a frame rebuild, even when the theme default font path is used.
local function GetPlateFont(key, size, db)
    local outline = (db and db[key .. "FontOutline"]) or "OUTLINE"
    local LSM = T.Libs and T.Libs.LSM
    if LSM and db then
        local fontName = db[key .. "Font"]
        if fontName and fontName ~= "" and fontName ~= "__default" then
            local ok, path = pcall(LSM.Fetch, LSM, "font", fontName)
            if ok and type(path) == "string" and path ~= "" then
                return path, size or 10, outline
            end
        end
    end
    local f, s = GetThemeFont(size)
    return f, s, outline
end

-- Per-element statusbar texture resolver: DB key overrides theme.
-- key is e.g. "healthBarTexture", "castBarTexture".
local function GetPlateTexture(key, db)
    local LSM = T.Libs and T.Libs.LSM
    if LSM and db then
        local texName = db[key]
        if texName and texName ~= "" and texName ~= "__default" then
            local ok, path = pcall(LSM.Fetch, LSM, "statusbar", texName)
            if ok and type(path) == "string" and path ~= "" then return path end
        end
    end
    return GetThemeTexture()
end

-- ── DB access ─────────────────────────────────────────────────────────────────
function Nameplates:GetOptions()
    if self._optionsCache then return self._optionsCache end
    local cm = T:GetModule("Configuration")
    self._optionsCache = cm and cm.Options and cm.Options.Nameplates or nil
    return self._optionsCache
end

function Nameplates:GetDB()
    if self._dbCache then return self._dbCache end
    local opts = self:GetOptions()
    if opts and type(opts.GetDB) == "function" then
        self._dbCache = opts:GetDB()
        return self._dbCache
    end
    self._dbCache = {}
    return self._dbCache
end

-- ── Friendly unit / DB helpers ────────────────────────────────────────────────
-- A unit is "friendly" when its reaction to the player is >= 5 (Friendly/Honored/…).
-- Party/raid members, pets, and friendly NPCs all qualify; hostiles, neutrals, and
-- the player's own nameplate do not.
function Nameplates:IsFriendlyUnit(unit)
    if not unit then return false end
    -- UnitReaction returns a SECRET NUMBER in Midnight; ANY comparison on it
    -- (>= 5, == 4, etc.) propagates taint and silently throws even inside pcall.
    -- UnitIsFriend and UnitCanAttack return TRUE BOOLEANS and are safe to compare.
    if UnitIsFriend then
        local f = UnitIsFriend(unit, "player")
        if f == true then return true end
        if f == false then return false end -- explicit false = enemy/neutral
    end
    -- Fallback: if the player cannot attack the unit it is effectively friendly.
    if UnitCanAttack then
        return not UnitCanAttack("player", unit)
    end
    return false
end

-- Returns db.friendly with an __index fallback to the main DB so any key not
-- explicitly set in the friendly sub-table inherits the enemy value.
-- The result is cached and rebuilt whenever InvalidateCache() is called.
function Nameplates:GetFriendlyDB()
    if self._friendlyDBCache then return self._friendlyDBCache end
    local db = self:GetDB()
    if not db.friendly then db.friendly = {} end
    -- __index metatable: reads fall through to the main DB for unset keys.
    self._friendlyDBCache = setmetatable(db.friendly, { __index = db })
    return self._friendlyDBCache
end

-- Returns the appropriate DB for a unit: friendly merged-DB or main DB.
-- If the frame's _isFriendly flag has been seeded (OnNamePlateAdded), use that
-- directly to avoid the per-call API overhead on every update event.
function Nameplates:GetEffectiveDB(unit)
    if unit then
        -- Prefer the cached per-frame flag when the unit is a tracked plate token.
        local frame = self._plates and self._plates[unit]
        if frame then
            if frame._isFriendly then return self:GetFriendlyDB() end
            return self:GetDB()
        end
        -- Fallback for unit tokens not yet in _plates (e.g. called before assignment).
        if self:IsFriendlyUnit(unit) then return self:GetFriendlyDB() end
    end
    return self:GetDB()
end

function Nameplates:IsStackingEnabledForUnit(unit, isFriendly)
    local db = self:GetDB()
    local friendly = isFriendly
    if friendly == nil and unit then
        local frame = self._plates and self._plates[unit]
        if frame then
            friendly = frame._isFriendly == true
        else
            friendly = self:IsFriendlyUnit(unit)
        end
    end

    if SupportsStackingBitfield() then
        if friendly then
            local fdb = self:GetFriendlyDB()
            if fdb.stackNameplates ~= nil then return fdb.stackNameplates == true end
            return GetStackingBitfieldState("Friendly", false)
        end
        if db.stackNameplates ~= nil then return db.stackNameplates == true end
        return GetStackingBitfieldState("Enemy", false)
    end

    if db.stackNameplates ~= nil then return db.stackNameplates == true end
    return GetCVarBoolSafe("nameplateMotion", false)
end

function Nameplates:InvalidateCache()
    self._optionsCache    = nil
    self._dbCache         = nil
    self._themeCache      = nil
    self._friendlyDBCache = nil
end

-- ── Health colour resolution ──────────────────────────────────────────────────
-- Helper: read a color from DB or fall back to a built-in constant.
local function DBColor(db, key, fallback)
    local c = db and db[key]
    return (type(c) == "table") and CopyColor(c) or CopyColor(fallback)
end

-- Max player level cache (used for elite-level miniboss/boss derivation).
local _maxLevel = nil
local function GetMaxLevel()
    if not _maxLevel then
        _maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80
    end
    return _maxLevel
end

-- ── Role detection ────────────────────────────────────────────────────────────
-- Cached; invalidated on spec change (PLAYER_SPECIALIZATION_CHANGED event).
local _cachedIsTank = nil
local function GetPlayerIsTank()
    if _cachedIsTank ~= nil then return _cachedIsTank end
    -- 1. In a group, use the assigned role.
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned("player")
        if role == "TANK" then
            _cachedIsTank = true; return true
        end
        if role == "DAMAGER" or role == "HEALER" then
            _cachedIsTank = false; return false
        end
    end
    -- 2. Fall back to specialization role.
    if GetSpecalization and GetSpecalizationRole then
        local spec = GetSpecalization()
        if spec and spec > 0 then
            local ok, role = pcall(GetSpecalizationRole, spec)
            if ok and role == "TANK" then
                _cachedIsTank = true; return true
            end
            if ok then
                _cachedIsTank = false; return false
            end
        end
    end
    _cachedIsTank = false
    return false
end

function Nameplates:ResolveHealthColor(unit, db)
    local mode = db.healthColorMode or "reaction"

    -- ── Aggro color override (hostile units only, highest priority) ────────────
    -- threat 3 = highest threat / tanking, 2 = nearing aggro loss, 1 = risky.
    -- We only tint the bar when the player is at threat level 3 (actually has aggro).
    if unit and db.showAggroColor ~= false then
        local reaction = UnitReaction and UnitReaction(unit, "player")
        local isEnemy  = reaction and reaction <= 3
        if isEnemy then
            local threat = UnitThreatSituation and UnitThreatSituation("player", unit) or 0
            if threat == 3 then
                if GetPlayerIsTank() then
                    return DBColor(db, "aggroColorTank", COLOR_AGGRO_TANK)
                else
                    return DBColor(db, "aggroColorDps", COLOR_AGGRO_DPS)
                end
            end
        end
    end

    if mode == "class" and unit and UnitIsPlayer(unit) then
        local _, classToken = UnitClass(unit)
        if classToken then
            local cc = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
            if cc and type(cc.r) == "number" then
                return { cc.r, cc.g, cc.b, 1 }
            end
        end
    end

    if mode == "custom" and type(db.healthCustomColor) == "table" then
        return CopyColor(db.healthCustomColor)
    end

    if mode == "theme" then
        return GetThemeColor("accentColor", COLOR_HOSTILE)
    end

    -- Reaction-based (default).  Within reaction mode we also honour
    -- per-classification overrides (boss, miniboss, rare, npc caster).
    if unit then
        if UnitIsTapDenied and UnitIsTapDenied(unit) then
            return DBColor(db, "colorTapped", COLOR_TAPPED)
        end

        -- Hostile override priority:
        --   1. Boss/worldboss
        --   2. Caster NPCs (when enabled)
        --   3. Remaining classification colours (rare/miniboss/etc.)
        local reaction = UnitReaction and UnitReaction(unit, "player")
        if reaction and reaction <= 3 then
            local cl = UnitClassification and UnitClassification(unit) or ""
            if cl == "worldboss" or cl == "boss" then
                return DBColor(db, "colorBoss", COLOR_BOSS)
            end

            if db.colorByCaster then
                local baseClass = UnitClassBase and UnitClassBase(unit)
                if baseClass == "PALADIN" then
                    return DBColor(db, "colorNpcCaster", COLOR_NPC_CASTER)
                end
            end

            if cl == "rareelite" then
                return DBColor(db, "colorMiniboss", COLOR_MINIBOSS)
            elseif cl == "rare" then
                return DBColor(db, "colorRare", COLOR_RARE)
            elseif cl == "elite" then
                -- Derive boss/miniboss from level vs expansion cap (ElvUI approach)
                local lvl    = UnitLevel and UnitLevel(unit) or 0
                local maxLvl = GetMaxLevel()
                if lvl >= (maxLvl + 2) then
                    return DBColor(db, "colorBoss", COLOR_BOSS)
                elseif lvl >= (maxLvl + 1) then
                    return DBColor(db, "colorMiniboss", COLOR_MINIBOSS)
                end
            end

            return DBColor(db, "colorHostile", COLOR_HOSTILE)
        end

        if reaction then
            if reaction >= 5 then return DBColor(db, "colorFriendly", COLOR_FRIENDLY) end
            if reaction == 4 then return DBColor(db, "colorNeutral", COLOR_NEUTRAL) end
        end
    end

    return GetThemeColor("accentColor", COLOR_HOSTILE)
end

-- ── Backdrop helper ───────────────────────────────────────────────────────────
local function ApplyBackdrop(frame, r, g, b, a, br, bg, bb, ba)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop(PLAIN_BD)
    frame:SetBackdropColor(r or 0.05, g or 0.06, b or 0.08, a or 0.92)
    frame:SetBackdropBorderColor(br or 0.14, bg or 0.15, bb or 0.20, ba or 0.9)
end

-- ── Aura slot iterator (Midnight continuation-token API) ─────────────────────
-- Returns a flat list of slot indices from C_UnitAuras.GetAuraSlots,
-- handling both the old (pure varargs) and new (continuationToken, ...) forms.
local _slotBuffer = {}
local function CollectAuraSlots(unit, filter, maxCount)
    local _scope = NpScope("Nameplates:CollectAuraSlots")
    local count = 0
    if not C_UnitAuras or not C_UnitAuras.GetAuraSlots then
        NpScopeEnd(_scope)
        return count
    end

    local continuationToken = nil
    repeat
        local token, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12
        local ok
        ok, token, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12 =
            pcall(C_UnitAuras.GetAuraSlots, unit, filter, continuationToken)
        if not ok then break end

        -- If token is a number, the old API is in use (no continuation token)
        if type(token) == "number" then
            -- Treat token as the first slot index
            local slots = { token, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12 }
            for _, v in ipairs(slots) do
                if type(v) ~= "number" then break end
                count = count + 1
                _slotBuffer[count] = v
                if count >= maxCount then return count end
            end
            break -- no continuation with old API
        else
            -- New API: token is a string continuation token (or nil = done)
            continuationToken = token
            local slots = { s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12 }
            for _, v in ipairs(slots) do
                if type(v) ~= "number" then break end
                count = count + 1
                _slotBuffer[count] = v
                if count >= maxCount then return count end
            end
        end
    until continuationToken == nil

    NpScopeEnd(_scope)
    return count
end

-- ── Frame construction ────────────────────────────────────────────────────────
function Nameplates:BuildPlateFrame(parentPlate)
    local db            = self:GetDB()
    local w             = Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600)
    local h             = Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60)
    local castH         = Clamp(db.castHeight or NP_DEFAULT_CAST_HEIGHT, 6, 30)
    local auraMax       = Clamp(db.auraMax or NP_DEFAULT_AURA_MAX, 0, NP_MAX_AURA_POOL)
    local auraSize      = Clamp(db.auraSize or NP_DEFAULT_AURA_SIZE, 12, 40)
    local hpTex         = GetPlateTexture("healthBarTexture", db)
    local castTex       = GetPlateTexture("castBarTexture", db)
    local bgTex         = GetPlateTexture("healthBgTexture", db)

    local bgC           = type(db.healthBgColor) == "table" and db.healthBgColor or { 0.05, 0.06, 0.08, 0.92 }
    local bdC           = type(db.healthBorderColor) == "table" and db.healthBorderColor or
        { 0.14, 0.15, 0.20, 0.90 }
    local cbgC          = type(db.castBgColor) == "table" and db.castBgColor or { 0.05, 0.06, 0.08, 0.92 }
    local cbdC          = type(db.castBorderColor) == "table" and db.castBorderColor or { 0.14, 0.15, 0.20, 0.90 }

    -- ── Root frame ────────────────────────────────────────────────────────────
    -- MIDNIGHT SECRET: parentPlate:GetFrameLevel() returns a secret/tainted number.
    -- ANY arithmetic on it (+ 3, - 1) causes a secret-arithmetic crash that silently
    -- kills BuildPlateFrame before self._plates[unitID] is set → 0 plates tracked.
    -- Fix: use fixed frame levels.  Our frame at 140 sits above Blizzard's UnitFrame.
    local frame         = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame._isTwichFrame = true       -- used by suppression loops to skip our own frame
    -- MIDNIGHT LAYOUT NOTE: any direct child of the Blizzard nameplate plate can have its
    -- dimensions coerced by the plate's C-side layout. Keep the TwichUI plate root on
    -- UIParent and anchor it to the Blizzard plate instead so the size is entirely ours.
    local plate         = parentPlate or UIParent
    frame:SetSize(w, h)
    frame:SetPoint("TOPLEFT", plate, "CENTER", -w / 2, h / 2)
    frame:SetPoint("BOTTOMRIGHT", plate, "CENTER", w / 2, -h / 2)
    frame:SetFrameLevel(NP_BASE_FRAME_LEVEL)
    ApplyBackdrop(frame, bgC[1], bgC[2], bgC[3], bgC[4], bdC[1], bdC[2], bdC[3], bdC[4])

    -- ── Target / focus glow ring ──────────────────────────────────────────────
    local glowOutset = Clamp(db.targetGlowOutset or 4, 1, 12)
    local targetGlow = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    targetGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", -glowOutset, glowOutset)
    targetGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", glowOutset, -glowOutset)
    targetGlow:SetFrameLevel(NP_BASE_GLOW_LEVEL)
    if targetGlow.SetBackdrop then
        targetGlow:SetBackdrop(GLOW_BD)
    end
    targetGlow:SetBackdropBorderColor(0.96, 0.76, 0.24, 0)
    targetGlow:Hide()
    frame.targetGlow     = targetGlow

    -- Store the normal border colour so UpdateTargetGlow can restore it.
    frame._normalBdColor = { bdC[1], bdC[2], bdC[3], bdC[4] or 0.9 }

    -- ── Target arrows ─────────────────────────────────────────────────────────
    -- Arrow textures live in Media/Textures/Arrows/  (ArrowUp default, Arrow0-72, etc.)
    -- ARROW_TC_RIGHT makes the arrow point → (used on the LEFT side of the plate).
    -- ARROW_TC_LEFT  makes the arrow point ← (used on the RIGHT side of the plate).
    local arrowSize      = Clamp(db.targetArrowSize or 18, 8, 32)
    local arrowTex       = GetArrowTexPath(db.targetArrowStyle)

    local arrowL         = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    arrowL:SetSize(arrowSize, arrowSize)
    arrowL:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    arrowL:SetTexture(arrowTex)
    arrowL:SetTexCoord(unpack(ARROW_TC_RIGHT))
    arrowL:Hide()
    frame.arrowL = arrowL

    local arrowR = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    arrowR:SetSize(arrowSize, arrowSize)
    arrowR:SetPoint("LEFT", frame, "RIGHT", 4, 0)
    arrowR:SetTexture(arrowTex)
    arrowR:SetTexCoord(unpack(ARROW_TC_LEFT))
    arrowR:Hide()
    frame.arrowR = arrowR

    -- ── Health bar ────────────────────────────────────────────────────────────
    local healthBar = CreateFrame("StatusBar", nil, frame)
    -- Two diagonal anchors fill the frame interior (1 px inset on all sides).
    -- Do NOT use SetHeight — with anchor-based frame sizing that call is redundant
    -- and can produce a visible grey gap when the value differs from the frame's
    -- actual rendered height.
    healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    healthBar:SetStatusBarTexture(hpTex)
    healthBar:SetStatusBarColor(COLOR_HOSTILE[1], COLOR_HOSTILE[2], COLOR_HOSTILE[3], 1)
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(1)

    local healthBg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBg:SetAllPoints()
    healthBg:SetTexture(bgTex)
    healthBg:SetVertexColor(bgC[1], bgC[2], bgC[3], bgC[4] or 0.92)
    frame.healthBar = healthBar
    frame.healthBg  = healthBg

    -- ── Absorb prediction ─────────────────────────────────────────────────────
    local absorbBar = CreateFrame("StatusBar", nil, healthBar)
    absorbBar:SetStatusBarTexture(hpTex)
    absorbBar:SetStatusBarColor(0.67, 0.85, 0.97, 0.72)
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:SetFrameLevel(healthBar:GetFrameLevel() + 1)
    absorbBar:Hide()
    frame.absorbBar = absorbBar
    ApplyAbsorbBarLayout(frame)

    -- ── Threat accent bar (left edge strip) ───────────────────────────────────
    local threatBar = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    threatBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    threatBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 0)
    threatBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    threatBar:SetVertexColor(0, 0, 0, 0)
    frame.threatBar      = threatBar

    -- ── Name text ─────────────────────────────────────────────────────────────
    local nf, ns, nfl    = GetPlateFont("name", Clamp(db.nameFontSize or 10, 6, 20), db)
    local nameAnchorPt   = db.nameAnchorPoint or "BOTTOMLEFT"
    local nameOX, nameOY = db.nameOffsetX or 2, db.nameOffsetY or 3
    local nameText       = frame:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(nf, ns, nfl)
    nameText:SetDrawLayer("OVERLAY", 7)
    if db.nameFontShadow then nameText:SetShadowOffset(1, -1) else nameText:SetShadowOffset(0, 0) end
    nameText:SetTextColor(1, 1, 1, 1)
    nameText:SetWordWrap(false)
    frame.nameText = nameText
    ApplyNameTextLayout(frame, db, w)

    -- ── Health text ───────────────────────────────────────────────────────────
    local hf, hs, hfl  = GetPlateFont("health", Clamp(db.healthFontSize or 9, 6, 18), db)
    local hTextJustify = db.healthTextAnchor or "RIGHT" -- "LEFT", "CENTER", or "RIGHT"
    local hTextOX      = db.healthTextOffsetX or 0
    local hTextOY      = db.healthTextOffsetY or 0
    local healthText   = healthBar:CreateFontString(nil, "OVERLAY")
    healthText:SetFont(hf, hs, hfl)
    if db.healthFontShadow then healthText:SetShadowOffset(1, -1) else healthText:SetShadowOffset(0, 0) end
    -- Span the full healthBar width so the FontString has size; justify controls L/C/R position.
    healthText:SetPoint("LEFT", healthBar, "LEFT", 4 + hTextOX, hTextOY)
    healthText:SetPoint("RIGHT", healthBar, "RIGHT", -4 + hTextOX, hTextOY)
    healthText:SetJustifyH(hTextJustify)
    healthText:SetTextColor(1, 1, 1, 1)
    frame.healthText = healthText

    -- ── Level text ────────────────────────────────────────────────────────────
    local levelText = healthBar:CreateFontString(nil, "OVERLAY")
    levelText:SetFont(hf, hs, hfl)
    levelText:SetPoint("LEFT", healthBar, "LEFT", 3, 0)
    levelText:SetJustifyH("LEFT")
    levelText:SetTextColor(0.8, 0.8, 0.8, 1)
    frame.levelText = levelText

    -- ── Elite / boss / rare icon ──────────────────────────────────────────────
    local eliteIcon = frame:CreateTexture(nil, "OVERLAY")
    eliteIcon:SetSize(14, 14)
    eliteIcon:SetPoint("LEFT", frame, "RIGHT", 4, 0)
    eliteIcon:Hide()
    frame.eliteIcon         = eliteIcon

    -- ── Raid target marker ───────────────────────────────────────────────────
    local raidMarkerOverlay = CreateFrame("Frame", nil, frame)
    raidMarkerOverlay:SetAllPoints()
    raidMarkerOverlay:SetFrameLevel(NP_BASE_FRAME_LEVEL + 10)
    raidMarkerOverlay:EnableMouse(false)
    frame.raidMarkerOverlay = raidMarkerOverlay

    local raidMarkerIcon = raidMarkerOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    raidMarkerIcon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])
    raidMarkerIcon:SetDrawLayer("OVERLAY", 7)
    raidMarkerIcon:Hide()
    frame.raidMarkerIcon = raidMarkerIcon
    ApplyRaidMarkerLayout(frame, db)

    -- ── Power bar ─────────────────────────────────────────────────────────────
    -- Always created so toggling Show/Hide live works without a frame rebuild.
    -- Sits between the health bar and cast bar.  Height is driven by db.powerBarHeight.
    local powerH         = Clamp(db.powerBarHeight or 4, 2, 14)
    local powerGap       = Clamp(db.powerBarGap or 2, 0, 12)
    local pbgC           = type(db.powerBgColor) == "table" and db.powerBgColor or { 0.05, 0.06, 0.08, 0.92 }
    local pbdC           = type(db.powerBorderColor) == "table" and db.powerBorderColor or { 0.14, 0.15, 0.20, 0.90 }
    local powerContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    powerContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -powerGap)
    powerContainer:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -powerGap)
    powerContainer:SetHeight(powerH + 2)
    ApplyBackdrop(powerContainer, pbgC[1], pbgC[2], pbgC[3], pbgC[4] or 0.92,
        pbdC[1], pbdC[2], pbdC[3], pbdC[4] or 0.9)
    local powerBar = CreateFrame("StatusBar", nil, powerContainer)
    powerBar:SetPoint("TOPLEFT", powerContainer, "TOPLEFT", 1, -1)
    powerBar:SetPoint("TOPRIGHT", powerContainer, "TOPRIGHT", -1, -1)
    powerBar:SetHeight(powerH)
    powerBar:SetStatusBarTexture(hpTex)
    powerBar:SetStatusBarColor(0.22, 0.52, 1.0, 1) -- default mana blue; UpdatePower overwrites
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)
    frame.powerBar       = powerBar
    frame.powerContainer = powerContainer
    -- Show/hide based on initial setting; live toggle handled in ResizePlateFrame.
    if db.showPowerBar == false then powerContainer:Hide() end

    -- Cast container is anchored below the power bar (always, whether visible or not,
    -- so toggling the power bar live just needs a Show/Hide + reposition).
    local castOffsetY = (db.showPowerBar ~= false) and (-powerGap - powerH - 2 - powerGap) or -powerGap

    -- ── Cast bar container ────────────────────────────────────────────────────
    local castH_outer = castH + 2
    local castContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    castContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, castOffsetY)
    castContainer:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, castOffsetY)
    castContainer:SetHeight(castH_outer)
    ApplyBackdrop(castContainer, cbgC[1], cbgC[2], cbgC[3], cbgC[4] or 0.92,
        cbdC[1], cbdC[2], cbdC[3], cbdC[4] or 0.9)
    castContainer:Hide()
    frame.castContainer = castContainer

    local castBar = CreateFrame("StatusBar", nil, castContainer)
    castBar:SetPoint("TOPLEFT", castContainer, "TOPLEFT", 1, -1)
    castBar:SetPoint("TOPRIGHT", castContainer, "TOPRIGHT", -1, -1)
    castBar:SetHeight(castH)
    castBar:SetStatusBarTexture(castTex)
    castBar:SetStatusBarColor(COLOR_CAST[1], COLOR_CAST[2], COLOR_CAST[3], 1)
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)

    local castBg = castBar:CreateTexture(nil, "BACKGROUND")
    castBg:SetAllPoints()
    castBg:SetTexture(castTex)
    castBg:SetVertexColor(cbgC[1], cbgC[2], cbgC[3], cbgC[4] or 0.92)
    frame.castBar  = castBar
    frame.castBg   = castBg

    -- Spell icon (left of cast container)
    local castIcon = castContainer:CreateTexture(nil, "OVERLAY")
    castIcon:SetSize(castH, castH)
    castIcon:SetPoint("RIGHT", castContainer, "LEFT", -2, 0)
    castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.castIcon = castIcon

    -- Interrupt shield (right of cast container)
    local castShield = castContainer:CreateTexture(nil, "OVERLAY")
    castShield:SetSize(castH + 4, castH + 4)
    castShield:SetPoint("LEFT", castContainer, "RIGHT", 2, 0)
    castShield:SetAtlas("nameplates-InterruptShield")
    castShield:Hide()
    frame.castShield = castShield

    -- Cast spell name text — parented to castBar (not castContainer) so it renders
    -- above the castBar's fill rather than being covered by the child Frame.
    local cf, cs, cfl = GetPlateFont("cast", Clamp(db.castFontSize or 9, 6, 16), db)
    local castText = castBar:CreateFontString(nil, "OVERLAY")
    castText:SetFont(cf, cs, cfl)
    if db.castFontShadow then castText:SetShadowOffset(1, -1) else castText:SetShadowOffset(0, 0) end
    castText:SetPoint("LEFT", castBar, "LEFT", 4, 0)
    castText:SetPoint("RIGHT", castBar, "RIGHT", -4, 0)
    castText:SetJustifyH("CENTER")
    castText:SetTextColor(1, 1, 1, 0.9)
    castText:SetWordWrap(false)
    frame.castText = castText

    -- ── Aura icon pool ────────────────────────────────────────────────────────
    local auraFrame = CreateFrame("Frame", nil, frame)
    auraFrame.icons = {}

    local timerFSize = Clamp(db.auraTimerFontSize or 8, 6, 28)
    for i = 1, NP_MAX_AURA_POOL do
        local iconF = CreateFrame("Frame", nil, auraFrame, "BackdropTemplate")
        iconF:SetSize(auraSize, auraSize)
        if i == 1 then
            iconF:SetPoint("LEFT", auraFrame, "LEFT", 0, 0)
        else
            iconF:SetPoint("LEFT", auraFrame.icons[i - 1], "RIGHT", 2, 0)
        end
        ApplyBackdrop(iconF)

        local iconTex = iconF:CreateTexture(nil, "ARTWORK")
        iconTex:SetPoint("TOPLEFT", iconF, "TOPLEFT", 1, -1)
        iconTex:SetPoint("BOTTOMRIGHT", iconF, "BOTTOMRIGHT", -1, 1)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconF.tex = iconTex

        -- Cooldown frame: Blizzard handles tainted DurationObjects internally.
        -- We never read back any values from it, so no taint errors.
        local cd = CreateFrame("Cooldown", nil, iconF, "CooldownFrameTemplate")
        cd:SetAllPoints(iconF)
        cd:SetDrawEdge(false)
        cd:SetDrawSwipe(true)
        cd:SetMinimumCountdownDuration(0)
        cd:SetHideCountdownNumbers(false)
        cd:SetAlpha(1)
        -- In Midnight, GetRegions() returns the built-in timer region directly
        -- (same as Plater_Auras.lua line ~1454).  Assign it to cd.Timer so we
        -- can SetFont on it — the template's own .Timer may be nil in Midnight.
        local timerRegion = cd:GetRegions()
        cd.Timer = timerRegion or cd.Timer
        if cd.Timer then
            cd.Timer:SetFont(_G.STANDARD_TEXT_FONT, timerFSize, "OUTLINE")
        end
        cd:Hide()
        iconF.cooldown = cd

        iconF:Hide()
        auraFrame.icons[i] = iconF
    end

    auraFrame:Hide()
    frame.auraFrame = auraFrame
    ApplyAuraFrameLayout(frame, db)

    -- Cast state tracking
    frame._casting         = false
    frame._channeling      = false
    frame._castStart       = 0
    frame._castEnd         = 0
    frame._castMax         = 1
    frame._castObservedAt  = 0
    frame._castDurationSec = 1
    frame._onCastEnd       = nil
    frame._unit            = nil
    frame._isTestPreview   = false
    frame._currentWidth    = w
    frame._currentHeight   = h
    frame._currentAlpha    = 1

    local sizeAnimDriver   = CreateFrame("Frame", nil, frame)
    sizeAnimDriver:Hide()
    sizeAnimDriver:SetScript("OnUpdate", function(_, elapsed)
        if not frame._sizeAnimDuration then
            sizeAnimDriver:Hide()
            return
        end

        frame._sizeAnimElapsed = (frame._sizeAnimElapsed or 0) + elapsed
        local progress = Clamp(frame._sizeAnimElapsed / frame._sizeAnimDuration, 0, 1)
        local eased = EaseOutCubic(progress)
        local width = frame._sizeAnimStartWidth + ((frame._sizeAnimTargetWidth - frame._sizeAnimStartWidth) * eased)
        local height = frame._sizeAnimStartHeight + ((frame._sizeAnimTargetHeight - frame._sizeAnimStartHeight) * eased)

        Nameplates:SetPlateFrameGeometry(frame, width, height, Nameplates:GetEffectiveDB(frame._unit))

        if progress >= 1 then
            Nameplates:SetPlateFrameGeometry(frame, frame._sizeAnimTargetWidth, frame._sizeAnimTargetHeight,
                Nameplates:GetEffectiveDB(frame._unit))
            frame._sizeAnimElapsed = nil
            frame._sizeAnimDuration = nil
            frame._sizeAnimStartWidth = nil
            frame._sizeAnimStartHeight = nil
            frame._sizeAnimTargetWidth = nil
            frame._sizeAnimTargetHeight = nil
            sizeAnimDriver:Hide()
        end
    end)
    frame._sizeAnimDriver = sizeAnimDriver

    local alphaAnimDriver = CreateFrame("Frame", nil, frame)
    alphaAnimDriver:Hide()
    alphaAnimDriver:SetScript("OnUpdate", function(_, elapsed)
        if not frame._alphaAnimDuration then
            alphaAnimDriver:Hide()
            return
        end

        frame._alphaAnimElapsed = (frame._alphaAnimElapsed or 0) + elapsed
        local progress = Clamp(frame._alphaAnimElapsed / frame._alphaAnimDuration, 0, 1)
        local eased = EaseOutCubic(progress)
        local alpha = frame._alphaAnimStart + ((frame._alphaAnimTarget - frame._alphaAnimStart) * eased)

        Nameplates:SetPlateFrameAlpha(frame, alpha)

        if progress >= 1 then
            Nameplates:SetPlateFrameAlpha(frame, frame._alphaAnimTarget)
            frame._alphaAnimElapsed = nil
            frame._alphaAnimDuration = nil
            frame._alphaAnimStart = nil
            frame._alphaAnimTarget = nil
            alphaAnimDriver:Hide()

            if frame._alphaAnimOnFinished then
                local callback = frame._alphaAnimOnFinished
                frame._alphaAnimOnFinished = nil
                callback(frame)
            end
        end
    end)
    frame._alphaAnimDriver = alphaAnimDriver

    ApplyPlateFrameLevels(frame, NP_BASE_FRAME_LEVEL, NP_BASE_GLOW_LEVEL)

    return frame
end

-- ── Frame pool acquisition / release ─────────────────────────────────────────
-- Recycling plate frames avoids allocating ~25 sub-frames per mob on every pull.
function Nameplates:AcquirePlateFrame(plate)
    local frame = tremove(self._platePool)
    if frame then
        -- The TwichUI root frame stays on UIParent so Blizzard's nameplate plate layout
        -- cannot coerce its size. ResizePlateFrame re-anchors it to the new plate.
        frame:SetParent(UIParent)
        if frame.targetGlow then frame.targetGlow:SetParent(UIParent) end
        frame:ClearAllPoints()
        frame._isTestPreview = false
        return frame
    end
    return self:BuildPlateFrame(plate)
end

function Nameplates:ReleasePlateFrame(frame)
    if not frame then return end
    -- Cancel any active cast animation on the shared ticker.
    _stopCastTicker(frame)
    self:StopPlateSizeAnimation(frame)
    self:StopPlateAlphaAnimation(frame)
    frame._unit            = nil
    frame._plate           = nil
    frame._casting         = false
    frame._channeling      = false
    frame._castObservedAt  = 0
    frame._castDurationSec = 1
    frame._onCastEnd       = nil
    -- Hide all sub-elements so recycled frames start invisible.
    frame:Hide()
    if frame.stackBoundsFrame then frame.stackBoundsFrame:Hide() end
    if frame.castContainer then frame.castContainer:Hide() end
    if frame.targetGlow then frame.targetGlow:Hide() end
    if frame.auraFrame then frame.auraFrame:Hide() end
    if frame.absorbBar then frame.absorbBar:Hide() end
    if frame.arrowL then frame.arrowL:Hide() end
    if frame.arrowR then frame.arrowR:Hide() end
    ApplyPlateFrameLevels(frame, NP_BASE_FRAME_LEVEL, NP_BASE_GLOW_LEVEL)
    self._platePool[#self._platePool + 1] = frame
end

function Nameplates:UpdatePlateDrawPriority(frame, unit)
    if not frame then return end

    local frameLevel = NP_BASE_FRAME_LEVEL
    local glowLevel = NP_BASE_GLOW_LEVEL
    local isTarget = unit and UnitIsUnit and UnitIsUnit(unit, "target")
    local isCasting = frame._casting == true

    if isTarget then
        frameLevel = NP_TARGET_FRAME_LEVEL
        glowLevel = NP_TARGET_GLOW_LEVEL
    elseif isCasting then
        frameLevel = NP_CAST_FRAME_LEVEL
        glowLevel = NP_CAST_GLOW_LEVEL
    end

    ApplyPlateFrameLevels(frame, frameLevel, glowLevel)
end

function Nameplates:SetPlateFrameGeometry(frame, width, height, db)
    if not frame or not frame._plate then return end

    local resolvedWidth = Clamp(width or frame._currentWidth or frame:GetWidth() or NP_DEFAULT_WIDTH, 60, 600)
    local resolvedHeight = Clamp(height or frame._currentHeight or frame:GetHeight() or NP_DEFAULT_HEIGHT, 8, 60)
    local effectiveDB = db or self:GetEffectiveDB(frame._unit)

    frame._currentWidth = resolvedWidth
    frame._currentHeight = resolvedHeight
    frame:ClearAllPoints()
    frame:SetSize(resolvedWidth, resolvedHeight)
    frame:SetPoint("TOPLEFT", frame._plate, "CENTER", -resolvedWidth / 2, resolvedHeight / 2)
    frame:SetPoint("BOTTOMRIGHT", frame._plate, "CENTER", resolvedWidth / 2, -resolvedHeight / 2)

    ApplyNameTextLayout(frame, effectiveDB, resolvedWidth)
    ApplyAbsorbBarLayout(frame)
    ApplyAuraFrameLayout(frame, effectiveDB)
end

function Nameplates:StopPlateSizeAnimation(frame)
    if not frame then return end
    frame._sizeAnimElapsed = nil
    frame._sizeAnimDuration = nil
    frame._sizeAnimStartWidth = nil
    frame._sizeAnimStartHeight = nil
    frame._sizeAnimTargetWidth = nil
    frame._sizeAnimTargetHeight = nil
    if frame._sizeAnimDriver then
        frame._sizeAnimDriver:Hide()
    end
end

function Nameplates:SetPlateFrameAlpha(frame, alpha)
    if not frame then return end

    local resolvedAlpha = Clamp(alpha or frame._currentAlpha or frame:GetAlpha() or 1, 0, 1)
    frame._currentAlpha = resolvedAlpha
    frame:SetAlpha(resolvedAlpha)
    if frame.targetGlow then
        frame.targetGlow:SetAlpha(resolvedAlpha)
    end
end

function Nameplates:StopPlateAlphaAnimation(frame)
    if not frame then return end
    frame._alphaAnimElapsed = nil
    frame._alphaAnimDuration = nil
    frame._alphaAnimStart = nil
    frame._alphaAnimTarget = nil
    frame._alphaAnimOnFinished = nil
    if frame._alphaAnimDriver then
        frame._alphaAnimDriver:Hide()
    end
end

function Nameplates:AnimatePlateFrameAlpha(frame, alpha, duration, onFinished, instant)
    if not frame then return end

    local targetAlpha = Clamp(alpha or frame._currentAlpha or frame:GetAlpha() or 1, 0, 1)
    local currentAlpha = Clamp(frame._currentAlpha or frame:GetAlpha() or targetAlpha, 0, 1)
    local fadeDuration = Clamp(duration or RANGE_FADE_ANIM_SEC, 0.01, 1)

    if instant or math.abs(targetAlpha - currentAlpha) < 0.01 then
        self:StopPlateAlphaAnimation(frame)
        self:SetPlateFrameAlpha(frame, targetAlpha)
        if onFinished then onFinished(frame) end
        return
    end

    frame._alphaAnimElapsed = 0
    frame._alphaAnimDuration = fadeDuration
    frame._alphaAnimStart = currentAlpha
    frame._alphaAnimTarget = targetAlpha
    frame._alphaAnimOnFinished = onFinished

    self:SetPlateFrameAlpha(frame, currentAlpha)
    if frame._alphaAnimDriver then
        frame._alphaAnimDriver:Show()
    end
end

function Nameplates:GetDesiredPlateAlpha(frame, unit, db)
    local effectiveDB = db or self:GetEffectiveDB(unit)
    local baseAlpha = Clamp(effectiveDB.alpha or 1, 0.1, 1)
    local inactiveAlpha = Clamp(effectiveDB.inactiveAlpha or baseAlpha, 0.05, 1)

    if inactiveAlpha >= (baseAlpha - 0.01) then
        return baseAlpha
    end

    local isTarget = unit and UnitIsUnit and UnitIsUnit(unit, "target")
    local isCasting = frame and frame._casting == true

    if isTarget or isCasting then
        return baseAlpha
    end

    return inactiveAlpha
end

function Nameplates:UpdatePlateAlpha(frame, unit, instant)
    if not frame then return end
    self:AnimatePlateFrameAlpha(frame, self:GetDesiredPlateAlpha(frame, unit), STATE_FADE_ANIM_SEC, nil, instant)
end

function Nameplates:ShouldShowPowerForUnit(unit, plate)
    if not unit then return false end
    if UnitIsPlayer(unit) == true then return true end

    local hostile = false
    pcall(function()
        hostile = UnitCanAttack and UnitCanAttack("player", unit) == true
    end)
    if hostile then
        return true
    end

    local nativeFrame = plate and plate.UnitFrame
    if not nativeFrame then return false end

    local visible = false
    pcall(function()
        local power = nativeFrame.manabar or nativeFrame.ManaBar or nativeFrame.powerBarAlt or nativeFrame.PowerBarAlt
        if power and power.IsShown and power:IsShown() then
            visible = true
        end
    end)

    return visible
end

function Nameplates:AnimatePlateFrameGeometry(frame, width, height, db, instant)
    if not frame or not frame._plate then return end

    local effectiveDB = db or self:GetEffectiveDB(frame._unit)
    local targetWidth = Clamp(width or frame._currentWidth or frame:GetWidth() or NP_DEFAULT_WIDTH, 60, 600)
    local targetHeight = Clamp(height or frame._currentHeight or frame:GetHeight() or NP_DEFAULT_HEIGHT, 8, 60)
    local currentWidth = Clamp(frame._currentWidth or frame:GetWidth() or targetWidth, 60, 600)
    local currentHeight = Clamp(frame._currentHeight or frame:GetHeight() or targetHeight, 8, 60)

    if instant or (math.abs(targetWidth - currentWidth) < 0.5 and math.abs(targetHeight - currentHeight) < 0.5) then
        self:StopPlateSizeAnimation(frame)
        self:SetPlateFrameGeometry(frame, targetWidth, targetHeight, effectiveDB)
        return
    end

    frame._sizeAnimElapsed = 0
    frame._sizeAnimDuration = TARGET_GROW_ANIM_SEC
    frame._sizeAnimStartWidth = currentWidth
    frame._sizeAnimStartHeight = currentHeight
    frame._sizeAnimTargetWidth = targetWidth
    frame._sizeAnimTargetHeight = targetHeight

    self:SetPlateFrameGeometry(frame, currentWidth, currentHeight, effectiveDB)
    if frame._sizeAnimDriver then
        frame._sizeAnimDriver:Show()
    end
end

-- ── Element updaters ──────────────────────────────────────────────────────────
function Nameplates:UpdateHealth(frame, unit)
    if not frame or not frame.healthBar then return end
    local db    = self:GetEffectiveDB(unit)

    -- In Midnight, UnitHealth/UnitHealthMax for nameplate units return secret numbers.
    -- Secret numbers CAN be passed directly to StatusBar API calls but will error
    -- on any Lua arithmetic (math.max, /, *, etc.).  Pass them straight through.
    local hp    = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)
    frame.healthBar:SetMinMaxValues(0, hpMax)
    frame.healthBar:SetValue(hp)

    -- Absorb prediction.
    -- Like ElvUI's nameplate health prediction, anchor the absorb segment to the live
    -- health texture so the shield extends from the current health edge rather than
    -- washing over the entire bar. This keeps the visual readable and avoids the
    -- all-points reverse-fill overlay that was not showing reliably in practice.
    if db.showAbsorb ~= false and UnitGetTotalAbsorbs then
        local absorb = UnitGetTotalAbsorbs(unit)
        ApplyAbsorbBarLayout(frame)
        frame.absorbBar:SetMinMaxValues(0, hpMax)
        frame.absorbBar:SetValue(absorb)
        frame.absorbBar:Show()
    else
        frame.absorbBar:Hide()
    end

    -- Health text.
    -- In Midnight, ALL Lua arithmetic on nameplate unit health secrets is blocked by the taint
    -- system — direct division, multiplication, and comparison all fail with:
    --   "attempt to perform arithmetic on local/upvalue 'hp' (a secret number value tainted by ...)"
    -- Plater explicitly skips health arithmetic for Midnight (IS_WOW_PROJECT_MIDNIGHT guards in
    -- QuickHealthUpdate / OnUpdateHealth) with a --TODO: MIDNIGHT!! comment in UpdateLifePercentText.
    -- Safe paths:
    --   AbbreviateNumbers(hp)       → C API, accepts secrets, returns "125k" / "1.2M" strings.
    --   UnitHealthPercent(unit,true) → Midnight-exclusive C API that returns a real (non-secret)
    --                                  percent value; wrapped in pcall since availability varies.
    if frame.healthText then
        local fmt = db.healthFormat or "percent"
        if fmt == "none" then
            frame.healthText:SetText("")
        elseif fmt == "percent" then
            -- Midnight exposes UnitHealthPercent, but the raw return can be normalized unless
            -- CurveConstants.ScaleTo100 is provided. oUF's tag path uses the scaled form.
            -- Keep this wrapped in pcall because API availability/signature can vary by build.
            local ok, result = pcall(function()
                local fn = _G.UnitHealthPercent
                if fn then
                    local curve = _G.CurveConstants and _G.CurveConstants.ScaleTo100
                    local pct = curve and fn(unit, true, curve) or fn(unit, true)
                    return string.format("%d%%", pct)
                end
            end)
            if ok and result then
                frame.healthText:SetText(result)
            else
                local AbbNums = _G.AbbreviateNumbers
                frame.healthText:SetText(AbbNums and AbbNums(hp) or "")
            end
        else
            -- "current": abbreviated absolute.  "deficit": arithmetic on secrets is blocked;
            -- fall back to absolute as well.
            local AbbNums = _G.AbbreviateNumbers
            frame.healthText:SetText(AbbNums and AbbNums(hp) or "")
        end
    end

    -- Health bar color
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        frame.healthBar:SetStatusBarColor(0.4, 0.4, 0.4, 0.6)
    else
        local c = self:ResolveHealthColor(unit, db)
        frame.healthBar:SetStatusBarColor(c[1], c[2], c[3], 1)
    end
end

function Nameplates:UpdateName(frame, unit)
    if not frame or not frame.nameText then return end
    local db = self:GetEffectiveDB(unit)
    if db.showName == false then
        frame.nameText:SetText("")
        return
    end
    -- UnitName returns a secret string in Midnight; SetText accepts it directly.
    -- String methods (:match, :sub) are indexing ops that fail on secret strings,
    -- so short-format trimming runs inside pcall and falls back to the raw value.
    local name = UnitName(unit)
    if name and db.nameFormat == "short" then
        local ok, short = pcall(function()
            return name:match("^(.-)%s") or name:sub(1, 10)
        end)
        if ok and short then name = short end
    end
    frame.nameText:SetText(name or "")

    -- Name color: class color (players only) > custom override > default white.
    if db.nameColorClass and UnitIsPlayer(unit) then
        local _, classToken = UnitClass(unit)
        if classToken then
            local cc = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
            if cc and type(cc.r) == "number" then
                frame.nameText:SetTextColor(cc.r, cc.g, cc.b, 1)
                return
            end
        end
    end
    local nc = type(db.nameFontColor) == "table" and db.nameFontColor or nil
    if nc then
        frame.nameText:SetTextColor(nc[1], nc[2], nc[3], nc[4] or 1)
    else
        frame.nameText:SetTextColor(1, 1, 1, 1)
    end
end

function Nameplates:UpdateLevel(frame, unit)
    if not frame or not frame.levelText then return end
    local db = self:GetEffectiveDB(unit)
    if db.showLevel == false then
        frame.levelText:SetText("")
        return
    end
    -- UnitLevel may return a secret number; tonumber() safely extracts it.
    local levelRaw = UnitLevel and UnitLevel(unit)
    local level    = tonumber(levelRaw)
    if not level or level == -1 or level == 9999 then
        frame.levelText:SetText("??")
        frame.levelText:SetTextColor(0.9, 0.2, 0.2, 1)
    else
        frame.levelText:SetText(tostring(level))
        frame.levelText:SetTextColor(0.8, 0.8, 0.8, 1)
    end
end

function Nameplates:UpdateEliteIcon(frame, unit)
    if not frame or not frame.eliteIcon then return end
    local db = self:GetEffectiveDB(unit)
    if db.showEliteIcon == false then
        frame.eliteIcon:Hide(); return
    end

    -- Use explicit texture paths like Plater does — SetAtlas names for nameplates
    -- are unreliable across Midnight builds.
    local classification = UnitClassification and UnitClassification(unit) or ""
    if classification == "worldboss" or classification == "boss" then
        frame.eliteIcon:SetTexture([[Interface\Scenarios\ScenarioIcon-Boss]])
        frame.eliteIcon:SetTexCoord(0, 1, 0, 1)
        frame.eliteIcon:SetVertexColor(1, 1, 1, 1)
        frame.eliteIcon:SetDesaturated(false)
        frame.eliteIcon:Show()
    elseif classification == "rareelite" or classification == "elite" then
        frame.eliteIcon:SetTexture([[Interface\GLUES\CharacterSelect\Glues-AddOn-Icons]])
        frame.eliteIcon:SetTexCoord(0.75, 1, 0, 1)
        frame.eliteIcon:SetVertexColor(1, 0.82, 0.1, 1) -- gold star
        frame.eliteIcon:SetDesaturated(false)
        frame.eliteIcon:Show()
    elseif classification == "rare" then
        frame.eliteIcon:SetTexture([[Interface\GLUES\CharacterSelect\Glues-AddOn-Icons]])
        frame.eliteIcon:SetTexCoord(0.75, 1, 0, 1)
        frame.eliteIcon:SetVertexColor(1, 1, 1, 1)
        frame.eliteIcon:SetDesaturated(true)
        frame.eliteIcon:Show()
    else
        frame.eliteIcon:Hide()
    end
end

function Nameplates:UpdateRaidMarker(frame, unit)
    if not frame or not frame.raidMarkerIcon then return end

    local db = self:GetEffectiveDB(unit)
    if db.showRaidMarker == false then
        frame.raidMarkerIcon:Hide()
        return
    end

    ApplyRaidMarkerLayout(frame, db)

    local index = nil
    if GetRaidTargetIndex then
        pcall(function()
            index = GetRaidTargetIndex(unit)
        end)
    end

    frame.raidMarkerIcon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])

    if _G.issecretvalue and _G.issecretvalue(index) then
        if frame.raidMarkerIcon.SetSpriteSheetCell then
            local ok = pcall(function()
                frame.raidMarkerIcon:SetSpriteSheetCell(index, 4, 4, 64, 64)
            end)
            if ok then
                frame.raidMarkerIcon:Show()
                return
            end
        end
    elseif (_G.canaccessvalue == nil or _G.canaccessvalue(index)) and index and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(frame.raidMarkerIcon, index)
        frame.raidMarkerIcon:Show()
        return
    end

    frame.raidMarkerIcon:Hide()
end

function Nameplates:UpdateTargetGlow(frame, unit)
    if not frame or not frame.targetGlow then return end
    local db = self:GetEffectiveDB(unit)

    -- Helper: restore the frame's normal border colour from stored state or DB.
    local function RestoreBorder()
        local bc = frame._normalBdColor
            or (type(db.healthBorderColor) == "table" and db.healthBorderColor)
            or { 0.14, 0.15, 0.20, 0.90 }
        frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 0.9)
    end

    local isCasting = frame._casting == true and db.castEmphasisEnabled == true
    self:UpdatePlateDrawPriority(frame, unit)

    if db.showTargetGlow == false and not isCasting then
        RestoreBorder()
        frame.targetGlow:Hide()
        if frame.arrowL then frame.arrowL:Hide() end
        if frame.arrowR then frame.arrowR:Hide() end
        self:AnimatePlateFrameGeometry(frame, Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600),
            Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60), db)
        return
    end

    local isTarget = UnitIsUnit and UnitIsUnit(unit, "target")
    local isFocus  = UnitIsUnit and UnitIsUnit(unit, "focus")
    local baseW    = Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600)
    local baseH    = Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60)
    local targetW  = baseW
    local targetH  = baseH

    if db.showTargetGlow ~= false and isTarget then
        -- Resolve target glow colour (custom DB override or theme accent).
        local gc = type(db.targetGlowColor) == "table" and db.targetGlowColor or nil
        local gr, gg, gb, ga
        if gc then
            gr, gg, gb, ga = gc[1], gc[2], gc[3], gc[4] or 0.9
        else
            local ac = GetThemeColor("accentColor", { 0.96, 0.76, 0.24 })
            gr, gg, gb, ga = ac[1], ac[2], ac[3], 0.9
        end

        -- Change the main frame's 1px border to the accent colour — the most
        -- reliable visual indicator regardless of frameLevel stacking.
        frame:SetBackdropBorderColor(gr, gg, gb, ga)

        -- Show the outer glow ring (2px border, outset from the frame).
        frame.targetGlow:SetBackdropBorderColor(gr, gg, gb, ga * 0.6)
        frame.targetGlow:Show()

        -- Optional frame grow on target.
        local growW = (db.targetGrowWidth and db.targetGrowWidth ~= 1)
            and Clamp(db.targetGrowWidth, 0.5, 2) or 1
        local growH = (db.targetGrowHeight and db.targetGrowHeight ~= 1)
            and Clamp(db.targetGrowHeight, 0.5, 2) or 1
        targetW = baseW * growW
        targetH = baseH * growH

        if db.showTargetArrows ~= false then
            local arrowTex = GetArrowTexPath(db.targetArrowStyle)
            local arrowSz = Clamp(db.targetArrowSize or 18, 8, 32)
            -- Use dedicated arrow color if set, otherwise fall back to the glow color.
            local ac = type(db.targetArrowColor) == "table" and db.targetArrowColor or nil
            local ar = ac and ac[1] or gr
            local ag = ac and ac[2] or gg
            local ab = ac and ac[3] or gb
            if frame.arrowL then
                frame.arrowL:SetTexture(arrowTex)
                frame.arrowL:SetTexCoord(unpack(ARROW_TC_RIGHT))
                frame.arrowL:SetSize(arrowSz, arrowSz)
                frame.arrowL:SetVertexColor(ar, ag, ab, 1)
                frame.arrowL:Show()
            end
            if frame.arrowR then
                frame.arrowR:SetTexture(arrowTex)
                frame.arrowR:SetTexCoord(unpack(ARROW_TC_LEFT))
                frame.arrowR:SetSize(arrowSz, arrowSz)
                frame.arrowR:SetVertexColor(ar, ag, ab, 1)
                frame.arrowR:Show()
            end
        else
            if frame.arrowL then frame.arrowL:Hide() end
            if frame.arrowR then frame.arrowR:Hide() end
        end
    elseif db.showTargetGlow ~= false and isFocus then
        local fc = type(db.focusGlowColor) == "table" and db.focusGlowColor or nil
        local fr, fg, fb, fa
        if fc then
            fr, fg, fb, fa = fc[1], fc[2], fc[3], fc[4] or 0.7
        else
            fr, fg, fb, fa = 0.22, 0.78, 0.96, 0.7
        end

        frame:SetBackdropBorderColor(fr, fg, fb, fa)
        frame.targetGlow:SetBackdropBorderColor(fr, fg, fb, fa * 0.5)
        frame.targetGlow:Show()

        if frame.arrowL then frame.arrowL:Hide() end
        if frame.arrowR then frame.arrowR:Hide() end
    elseif isCasting then
        local bc = type(db.castEmphasisBorderColor) == "table" and db.castEmphasisBorderColor or nil
        local br, bg, bb, ba
        if bc then
            br, bg, bb, ba = bc[1], bc[2], bc[3], bc[4] or 1
        else
            local cc = type(db.castColor) == "table" and db.castColor or COLOR_CAST
            br, bg, bb, ba = cc[1], cc[2], cc[3], cc[4] or 1
        end

        frame:SetBackdropBorderColor(br, bg, bb, ba)

        if db.castEmphasisGlow ~= false then
            local gc = type(db.castEmphasisGlowColor) == "table" and db.castEmphasisGlowColor or nil
            local gr = gc and gc[1] or br
            local gg = gc and gc[2] or bg
            local gb = gc and gc[3] or bb
            local ga = gc and (gc[4] or 0.8) or 0.8
            frame.targetGlow:SetBackdropBorderColor(gr, gg, gb, ga * 0.6)
            frame.targetGlow:Show()
        else
            frame.targetGlow:Hide()
        end

        local castScale = Clamp(tonumber(db.castEmphasisScale) or 1.08, 1, 1.5)
        targetW = baseW * castScale
        targetH = baseH * castScale

        if db.castEmphasisArrows == true then
            local arrowStyle = db.castEmphasisArrowStyle or db.targetArrowStyle
            local arrowTex = GetArrowTexPath(arrowStyle)
            local arrowSz = Clamp(db.targetArrowSize or 18, 8, 32)
            local ac = type(db.castEmphasisArrowColor) == "table" and db.castEmphasisArrowColor or nil
            local ar = ac and ac[1] or br
            local ag = ac and ac[2] or bg
            local ab = ac and ac[3] or bb
            if frame.arrowL then
                frame.arrowL:SetTexture(arrowTex)
                frame.arrowL:SetTexCoord(unpack(ARROW_TC_RIGHT))
                frame.arrowL:SetSize(arrowSz, arrowSz)
                frame.arrowL:SetVertexColor(ar, ag, ab, 1)
                frame.arrowL:Show()
            end
            if frame.arrowR then
                frame.arrowR:SetTexture(arrowTex)
                frame.arrowR:SetTexCoord(unpack(ARROW_TC_LEFT))
                frame.arrowR:SetSize(arrowSz, arrowSz)
                frame.arrowR:SetVertexColor(ar, ag, ab, 1)
                frame.arrowR:Show()
            end
        else
            if frame.arrowL then frame.arrowL:Hide() end
            if frame.arrowR then frame.arrowR:Hide() end
        end
    else
        RestoreBorder()
        frame.targetGlow:Hide()
        if frame.arrowL then frame.arrowL:Hide() end
        if frame.arrowR then frame.arrowR:Hide() end
    end

    self:AnimatePlateFrameGeometry(frame, targetW, targetH, db)
end

function Nameplates:UpdateThreat(frame, unit)
    if not frame or not frame.threatBar then return end
    local db = self:GetEffectiveDB(unit)
    if db.showThreat == false then
        frame.threatBar:SetVertexColor(0, 0, 0, 0)
        return
    end

    local threat = UnitThreatSituation and UnitThreatSituation("player", unit) or 0
    if threat == 3 then
        frame.threatBar:SetVertexColor(0.87, 0.25, 0.25, 0.9)
    elseif threat == 2 then
        frame.threatBar:SetVertexColor(0.96, 0.76, 0.24, 0.75)
    elseif threat == 1 then
        frame.threatBar:SetVertexColor(0.92, 0.92, 0.12, 0.5)
    else
        frame.threatBar:SetVertexColor(0, 0, 0, 0)
    end
end

function Nameplates:UpdateAuras(frame, unit)
    if not frame or not frame.auraFrame then return end
    local db = self:GetEffectiveDB(unit)
    if db.showAuras == false then
        frame.auraFrame:Hide()
        return
    end

    local maxAuras   = Clamp(db.auraMax or NP_DEFAULT_AURA_MAX, 0, NP_MAX_AURA_POOL)
    -- Append |PLAYER to the filter when onlyMine is set. This is resolved at the API level
    -- so we never need to touch tainted secret boolean/string fields (isFromPlayerOrPlayerPet,
    -- sourceUnit) which throw errors on == comparison in Midnight.
    local baseFilter = db.auraFilter or "HARMFUL"
    local auraFilter = (db.auraOnlyMine == true) and (baseFilter .. "|PLAYER") or baseFilter
    local auraSize   = Clamp(db.auraSize or NP_DEFAULT_AURA_SIZE, 12, 40)
    local showTimer  = db.auraShowTimer ~= false
    local shown      = 0

    ApplyAuraFrameLayout(frame, db)

    -- ── Populate aura icon ────────────────────────────────────────────────────
    -- Timer: DurationObject methods (IsZero, GetRemainingDuration) return tainted
    -- secret booleans/numbers in Midnight — any Lua comparison throws, even in pcall.
    -- SetCooldownFromDurationObject is a Blizzard widget method that accepts tainted
    -- objects safely (no Lua-side return values). This is how Plater does it.
    local function ShowAuraIcon(iconF, aura)
        local _scope = NpScope("Nameplates:ShowAuraIcon")
        iconF:SetSize(auraSize, auraSize)
        -- icon fileID can be a secret number; wrap in pcall
        if not pcall(function() iconF.tex:SetTexture(aura.icon) end) then
            pcall(function() iconF.tex:SetTexture(134400) end)
        end
        -- Timer via Cooldown frame
        local cd = iconF.cooldown
        if showTimer and cd and C_UnitAuras and C_UnitAuras.GetAuraDuration then
            local instanceID = aura.auraInstanceID
            if instanceID then
                local durationObj = C_UnitAuras.GetAuraDuration(unit, instanceID)
                if durationObj then
                    -- Pass the tainted object directly into the widget — no Lua comparisons.
                    pcall(function() cd:SetCooldownFromDurationObject(durationObj) end)
                    cd:Show()
                else
                    cd:Hide()
                end
            else
                cd:Hide()
            end
        elseif cd then
            cd:Hide()
        end
        iconF:Show()
        NpScopeEnd(_scope)
    end

    -- ── Fetch aura list ───────────────────────────────────────────────────────
    -- Midnight: C_UnitAuras.GetUnitAuras(unit, filter, nil, sortRule) returns
    -- an array of aura tables directly (Plater_Auras.lua line ~806).
    -- Do NOT wrap in pcall — it silently eats the entire result on error.
    -- GetAuraSlots is a pre-Midnight API that returns no slots for nameplate tokens.
    local auraList = nil
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        -- Pass Unsorted sort rule for Midnight (required for proper return value).
        local sortRule = Enum and Enum.UnitAuraSortRule and Enum.UnitAuraSortRule.Unsorted or nil
        local getOk, getResult = pcall(C_UnitAuras.GetUnitAuras, unit, auraFilter, nil, sortRule)
        if getOk then
            auraList = getResult
        else
            NpLog(string.format("UpdateAuras(%s): GetUnitAuras FAILED: %s", tostring(unit), tostring(getResult)))
            NpErr("Nameplates:UpdateAuras:GetUnitAuras", getResult)
        end
    end

    -- GetUnitAuras returns a table; iterate with pairs (Midnight may use non-sequential keys).
    -- Player filtering was already handled by the |PLAYER filter token above — no field checks.
    if auraList then
        local iterOk, iterErr = pcall(function()
            for _, aura in pairs(auraList) do
                if shown >= maxAuras then break end
                if not aura then break end
                shown = shown + 1
                local iconF = frame.auraFrame.icons[shown]
                if iconF then ShowAuraIcon(iconF, aura) end
            end
        end)
        if not iterOk then
            NpLog(string.format("UpdateAuras(%s): ITERATION ERROR: %s", tostring(unit), tostring(iterErr)))
            NpErr("Nameplates:UpdateAuras:iteration", iterErr)
        end
    else
        -- ── Fallback: GetAuraSlots / GetAuraDataBySlot (pre-Midnight API) ───────
        -- auraFilter already contains |PLAYER if onlyMine is set.
        local slotCount = CollectAuraSlots(unit, auraFilter, maxAuras)
        for s = 1, slotCount do
            if shown >= maxAuras then break end
            local slotIndex = _slotBuffer[s]
            if not slotIndex then break end
            local data = C_UnitAuras and C_UnitAuras.GetAuraDataBySlot(unit, slotIndex)
            if data and data.icon then
                shown = shown + 1
                local iconF = frame.auraFrame.icons[shown]
                if iconF then ShowAuraIcon(iconF, data) end
            end
        end
    end

    for i = shown + 1, NP_MAX_AURA_POOL do
        local iconF = frame.auraFrame.icons[i]
        if iconF then iconF:Hide() end
    end

    if shown > 0 then
        frame.auraFrame:Show()
    else
        frame.auraFrame:Hide()
    end
end

function Nameplates:UpdateCastBar(frame, unit)
    if not frame or not frame.castContainer then return end
    local db = self:GetEffectiveDB(unit)

    if db.showCastBar == false then
        frame._casting = false
        frame.castContainer:Hide()
        self:UpdateTargetGlow(frame, unit)
        return
    end

    -- Try casting first, then channeling
    local name, _, _, startTime, endTime, _, _, notInterruptible, spellId
    local channeling = false

    if UnitCastingInfo then
        name, _, _, startTime, endTime, _, _, notInterruptible, spellId = UnitCastingInfo(unit)
    end

    if not name and UnitChannelInfo then
        local interrupt
        name, _, _, startTime, endTime, _, interrupt, spellId = UnitChannelInfo(unit)
        if name then
            channeling = true
            notInterruptible = interrupt
        end
    end

    if not name then
        frame._casting = false
        frame.castContainer:Hide()
        _stopCastTicker(frame)
        self:UpdateTargetGlow(frame, unit)
        return
    end

    -- Update cast state
    -- MIDNIGHT SECRET NOTE: startTime/endTime from UnitCastingInfo/UnitChannelInfo
    -- are secret numbers on nameplate units — cannot do / 1000 arithmetic on them.
    -- We derive duration entirely via C_Spell.GetSpellInfo(spellId).castTime (non-secret),
    -- then drive the bar solely with GetTime() arithmetic. No secret arithmetic needed.
    frame._casting         = true
    frame._channeling      = channeling
    frame._castObservedAt  = GetTime()

    -- MIDNIGHT SECRET: C_Spell.GetSpellInfo returns castTime as a tainted/secret number
    -- in combat.  Any comparison (> 0) on it will crash.  We therefore always use the
    -- 2-second fallback duration.  The bar terminates early via UNIT_SPELLCAST_STOP, so
    -- this only matters for the worst-case tail display.
    local dur              = 2.0
    frame._castDurationSec = dur
    frame.castBar:SetMinMaxValues(0, dur)
    frame.castBar:SetValue(channeling and dur or 0)

    frame.castText:SetText(name)

    -- Color: uninterruptible vs normal vs channel.
    -- MIDNIGHT SECRET: notInterruptible from UnitCastingInfo/UnitChannelInfo is a secret
    -- boolean — `if notInterruptible then` throws.  Wrap in pcall; on error treat as
    -- interruptible (unint stays false).
    if channeling then
        local cc = CopyColor(db.castColor, COLOR_CHANNEL)
        frame.castBar:SetStatusBarColor(cc[1], cc[2], cc[3], 1)
        frame.castShield:Hide()
    else
        local unint = false
        pcall(function() if notInterruptible then unint = true end end)
        if unint then
            frame.castBar:SetStatusBarColor(COLOR_CAST_UNINT[1], COLOR_CAST_UNINT[2], COLOR_CAST_UNINT[3], 1)
            frame.castShield:Show()
        else
            local cc = CopyColor(db.castColor, COLOR_CAST)
            frame.castBar:SetStatusBarColor(cc[1], cc[2], cc[3], 1)
            frame.castShield:Hide()
        end
    end

    -- Spell icon
    if spellId then
        local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId))
            or (_G.GetSpellTexture and _G.GetSpellTexture(spellId))
        if icon then
            frame.castIcon:SetTexture(icon)
            frame.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end

    frame.castContainer:Show()
    -- Register with the shared single-ticker instead of spawning a new OnUpdate per plate.
    _startCastTicker(frame)
    self:UpdateTargetGlow(frame, unit)
end

function Nameplates:UpdatePower(frame, unit)
    if not frame or not frame.powerContainer then return end
    local db = self:GetEffectiveDB(unit)

    if db.showPowerBar == false then
        frame.powerContainer:Hide()
        return
    end

    if frame._showPower == nil or frame._showPower == false then
        frame._showPower = self:ShouldShowPowerForUnit(unit, frame._plate)
    end

    -- _showPower is seeded on add and can be promoted later by runtime events.
    -- This avoids any comparison against UnitPowerMax (a secret number in Midnight).
    if not frame._showPower then
        frame.powerContainer:Hide()
        return
    end

    frame.powerContainer:Show()

    local pb = frame.powerBar
    if not pb then return end

    -- These return secret numbers but SetMinMaxValues/SetValue accept them directly.
    pb:SetMinMaxValues(0, UnitPowerMax(unit))
    pb:SetValue(UnitPower(unit))

    -- Determine power type color (UnitPowerType may taint in Midnight — use pcall).
    local pwrType
    local ok, result = pcall(function() return UnitPowerType(unit) end)
    if ok then pwrType = tonumber(result) end

    local pbc = pwrType and _G.PowerBarColor and _G.PowerBarColor[pwrType]
    if pbc then
        pb:SetStatusBarColor(pbc.r or 0.22, pbc.g or 0.52, pbc.b or 1.0, 1)
    else
        -- Fallback by type index: 0=mana, 1=rage, 3=energy, 6=runic
        local fallbacks = {
            [0] = { 0.22, 0.52, 1.00 },
            [1] = { 1.00, 0.10, 0.10 },
            [3] = { 1.00, 0.90, 0.10 },
            [6] = { 0.20, 0.80, 0.90 },
        }
        local fc = pwrType and fallbacks[pwrType] or fallbacks[0]
        pb:SetStatusBarColor(fc[1], fc[2], fc[3], 1)
    end
end

function Nameplates:UpdateAllElements(frame, unit)
    if not frame or not unit then return end
    if not UnitExists(unit) then
        NpLog(string.format("UpdateAllElements skipped: UnitExists(%s)=false", tostring(unit)))
        return
    end

    self:UpdateHealth(frame, unit)
    self:UpdateName(frame, unit)
    self:UpdateLevel(frame, unit)
    self:UpdateEliteIcon(frame, unit)
    self:UpdateRaidMarker(frame, unit)
    self:UpdateThreat(frame, unit)
    self:UpdateCastBar(frame, unit)
    self:UpdateTargetGlow(frame, unit)
    self:UpdateAuras(frame, unit)
    self:UpdatePower(frame, unit)
    local currentAlpha = Clamp(frame._currentAlpha or frame:GetAlpha() or 1, 0, 1)
    self:UpdatePlateAlpha(frame, unit, currentAlpha > 0.01)
end

-- ── Refresh / resize helpers ──────────────────────────────────────────────────
function Nameplates:ApplyThemeToFrame(frame)
    if not frame then return end
    local db    = self:GetEffectiveDB(frame and frame._unit)
    local hpTex = GetPlateTexture("healthBarTexture", db)
    local cTex  = GetPlateTexture("castBarTexture", db)
    local bgTex = GetPlateTexture("healthBgTexture", db)

    -- Bar textures
    if frame.healthBar then frame.healthBar:SetStatusBarTexture(hpTex) end
    if frame.healthBg then
        frame.healthBg:SetTexture(bgTex)
        local bgC = type(db.healthBgColor) == "table" and db.healthBgColor or { 0.05, 0.06, 0.08, 0.92 }
        frame.healthBg:SetVertexColor(bgC[1], bgC[2], bgC[3], bgC[4] or 0.92)
    end
    if frame.castBar then frame.castBar:SetStatusBarTexture(cTex) end
    if frame.castBg then
        frame.castBg:SetTexture(cTex)
        local cbgC = type(db.castBgColor) == "table" and db.castBgColor or { 0.05, 0.06, 0.08, 0.92 }
        frame.castBg:SetVertexColor(cbgC[1], cbgC[2], cbgC[3], cbgC[4] or 0.92)
    end
    if frame.absorbBar then
        frame.absorbBar:SetStatusBarTexture(hpTex)
        ApplyAbsorbBarLayout(frame)
    end

    -- Power bar texture
    if frame.powerBar then frame.powerBar:SetStatusBarTexture(hpTex) end
    if frame.powerContainer then
        local pbgC = type(db.powerBgColor) == "table" and db.powerBgColor or { 0.05, 0.06, 0.08, 0.92 }
        local pbdC = type(db.powerBorderColor) == "table" and db.powerBorderColor or { 0.14, 0.15, 0.20, 0.90 }
        ApplyBackdrop(frame.powerContainer, pbgC[1], pbgC[2], pbgC[3], pbgC[4] or 0.92,
            pbdC[1], pbdC[2], pbdC[3], pbdC[4] or 0.9)
        if db.showPowerBar == false then
            frame.powerContainer:Hide()
        else
            frame.powerContainer:Show()
        end
    end

    -- Frame backdrop colors
    local bgC = type(db.healthBgColor) == "table" and db.healthBgColor or { 0.05, 0.06, 0.08, 0.92 }
    local bdC = type(db.healthBorderColor) == "table" and db.healthBorderColor or { 0.14, 0.15, 0.20, 0.90 }
    ApplyBackdrop(frame, bgC[1], bgC[2], bgC[3], bgC[4], bdC[1], bdC[2], bdC[3], bdC[4])
    -- Keep the cached normal-border colour in sync so UpdateTargetGlow can restore it.
    frame._normalBdColor = { bdC[1], bdC[2], bdC[3], bdC[4] or 0.9 }

    if frame.castContainer then
        local cbgC = type(db.castBgColor) == "table" and db.castBgColor or { 0.05, 0.06, 0.08, 0.92 }
        local cbdC = type(db.castBorderColor) == "table" and db.castBorderColor or { 0.14, 0.15, 0.20, 0.90 }
        ApplyBackdrop(frame.castContainer, cbgC[1], cbgC[2], cbgC[3], cbgC[4],
            cbdC[1], cbdC[2], cbdC[3], cbdC[4])
    end

    -- Per-element fonts
    local nf, ns, nfl = GetPlateFont("name", Clamp(db.nameFontSize or 10, 6, 20), db)
    local hf, hs, hfl = GetPlateFont("health", Clamp(db.healthFontSize or 9, 6, 18), db)
    local cf, cs, cfl = GetPlateFont("cast", Clamp(db.castFontSize or 9, 6, 16), db)

    if frame.nameText then
        frame.nameText:SetFont(nf, ns, nfl)
        if db.nameFontShadow then frame.nameText:SetShadowOffset(1, -1) else frame.nameText:SetShadowOffset(0, 0) end
        ApplyNameTextLayout(frame, db)
        -- Color is handled by UpdateName (class color, custom, or default white).
    end
    if frame.healthText then
        frame.healthText:SetFont(hf, hs, hfl)
        if db.healthFontShadow then frame.healthText:SetShadowOffset(1, -1) else frame.healthText:SetShadowOffset(0, 0) end
        local hc = type(db.healthFontColor) == "table" and db.healthFontColor or nil
        if hc then frame.healthText:SetTextColor(hc[1], hc[2], hc[3], hc[4] or 1) end
    end
    if frame.levelText then frame.levelText:SetFont(hf, hs, hfl) end
    if frame.castText then
        frame.castText:SetFont(cf, cs, cfl)
        if db.castFontShadow then frame.castText:SetShadowOffset(1, -1) else frame.castText:SetShadowOffset(0, 0) end
    end

    -- Arrow texture refresh (style may have changed in settings)
    local arrowTex = GetArrowTexPath(db.targetArrowStyle)
    local arrowSz  = Clamp(db.targetArrowSize or 18, 8, 32)
    if frame.arrowL then
        frame.arrowL:SetTexture(arrowTex)
        frame.arrowL:SetTexCoord(unpack(ARROW_TC_RIGHT))
        frame.arrowL:SetSize(arrowSz, arrowSz)
    end
    if frame.arrowR then
        frame.arrowR:SetTexture(arrowTex)
        frame.arrowR:SetTexCoord(unpack(ARROW_TC_LEFT))
        frame.arrowR:SetSize(arrowSz, arrowSz)
    end

    -- Re-position targetGlow outset: the SetPoint is set at construction time so
    -- changing targetGlowOutset only takes effect after ClearAllPoints + re-anchor.
    if frame.targetGlow then
        local outset = Clamp(db.targetGlowOutset or 4, 1, 12)
        frame.targetGlow:ClearAllPoints()
        frame.targetGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
        frame.targetGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
    end
end

function Nameplates:ResizePlateFrame(frame)
    if not frame then return end
    local db    = self:GetEffectiveDB(frame and frame._unit)
    local w     = Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600)
    local h     = Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60)
    local castH = Clamp(db.castHeight or NP_DEFAULT_CAST_HEIGHT, 6, 30)

    -- Anchor-based resize: clear old anchors and reposition the frame using
    -- TOPLEFT+BOTTOMRIGHT offsets from the plate's CENTER.  This is immune to
    -- the Midnight nameplate plate layout system that silently ignores SetSize
    -- on direct children, which caused the frame to remain at the initial
    -- (main-DB) height while the health bar was already resized to the correct
    -- (friendly-DB) height -- producing the grey gap the user saw.
    self:SetPlateFrameGeometry(frame, w, h, db)
    -- healthBar fills the frame via BOTTOMRIGHT anchor; no explicit SetHeight needed.
    if frame.threatBar then frame.threatBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0) end
    if frame.castContainer then frame.castContainer:SetHeight(castH + 2) end
    if frame.castBar then frame.castBar:SetHeight(castH) end

    -- Resize power bar and reposition cast container relative to it.
    local powerH   = Clamp(db.powerBarHeight or 4, 2, 14)
    local powerGap = Clamp(db.powerBarGap or 2, 0, 12)
    if frame.powerContainer and frame.powerBar then
        frame.powerContainer:SetHeight(powerH + 2)
        frame.powerBar:SetHeight(powerH)
        frame.powerContainer:ClearAllPoints()
        frame.powerContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -powerGap)
        frame.powerContainer:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -powerGap)
        if db.showPowerBar == false then
            frame.powerContainer:Hide()
        else
            frame.powerContainer:Show()
        end
    end
    if frame.castContainer then
        local castOffsetY = (db.showPowerBar ~= false) and (-powerGap - powerH - 2 - powerGap) or -powerGap
        frame.castContainer:ClearAllPoints()
        frame.castContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, castOffsetY)
        frame.castContainer:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, castOffsetY)
    end

    -- Resize aura frame width
    if frame.auraFrame then frame.auraFrame:SetWidth(w) end

    self:UpdatePlateStackingBounds(frame)
end

function Nameplates:UpdatePlateStackingBounds(frame)
    if not frame or not frame._plate or not frame._plate.SetStackingBoundsFrame then return end

    local db = self:GetEffectiveDB(frame._unit)
    local enabled = self:IsStackingEnabledForUnit(frame._unit, frame._isFriendly)
    local widthScale = Clamp(db.stackingWidthScale or 1, 0.75, 3)
    local heightScale = Clamp(db.stackingHeightScale or 1, 0.75, 4)
    local baseW = Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600)
    local baseH = Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60)
    local powerGap = Clamp(db.powerBarGap or 2, 0, 12)
    local powerH = (db.showPowerBar == false) and 0 or (Clamp(db.powerBarHeight or 4, 2, 14) + 2)
    local castH = (db.showCastBar == false) and 0 or (Clamp(db.castHeight or NP_DEFAULT_CAST_HEIGHT, 6, 30) + 2)
    local castSidePad = (db.showCastBar == false) and 0 or (castH + 4)
    local nativeCarrier = frame._plate.UnitFrame or frame._plate
    local nativeW = 0
    local nativeH = 0

    pcall(function()
        nativeW = tonumber(nativeCarrier:GetWidth()) or 0
        nativeH = tonumber(nativeCarrier:GetHeight()) or 0
    end)

    local visualH = baseH
    if powerH > 0 then
        visualH = visualH + powerGap + powerH
    end
    if castH > 0 then
        visualH = visualH + powerGap + castH
        if powerH > 0 then
            visualH = visualH + powerGap
        end
    end

    local boundsW = math.max(baseW + castSidePad * 2, nativeW) * widthScale
    local boundsH = math.max(visualH, nativeH) * heightScale

    local bounds = frame.stackBoundsFrame
    if not bounds then
        bounds = CreateFrame("Frame", nil, nativeCarrier, "BackdropTemplate")
        bounds:EnableMouse(false)
        bounds._fill = bounds:CreateTexture(nil, "BACKGROUND")
        bounds._fill:SetColorTexture(1, 0, 0, 0)
        bounds._fill:SetAllPoints(bounds)
        bounds:Hide()
        frame.stackBoundsFrame = bounds
    end

    bounds:SetParent(nativeCarrier)
    bounds:ClearAllPoints()

    if not enabled then
        bounds:SetPoint("CENTER", nativeCarrier, "CENTER", 0, 0)
        bounds:SetSize(1, 1)
        bounds:Show()
        pcall(frame._plate.SetStackingBoundsFrame, frame._plate, bounds)
        return
    end

    bounds:SetPoint("CENTER", nativeCarrier, "CENTER", 0, 0)
    bounds:SetSize(boundsW, boundsH)
    bounds:Show()

    pcall(frame._plate.SetStackingBoundsFrame, frame._plate, bounds)
end

function Nameplates:RefreshAllPlates()
    self:InvalidateCache()
    for unitID, frame in pairs(self._plates) do
        if unitID and UnitExists(unitID) then
            frame._isFriendly = self:IsFriendlyUnit(unitID)
        end
        self:ResizePlateFrame(frame)
        self:ApplyThemeToFrame(frame)
        if unitID and UnitExists(unitID) then
            self:UpdateAllElements(frame, unitID)
        end
    end
end

function Nameplates:QueuePlateRefresh(delay)
    if not C_Timer or not C_Timer.After then return end
    self._queuedPlateRefreshId = (self._queuedPlateRefreshId or 0) + 1
    local refreshId = self._queuedPlateRefreshId
    C_Timer.After(delay or 0, function()
        if Nameplates._queuedPlateRefreshId ~= refreshId then return end
        if InCombatLockdown and InCombatLockdown() then return end
        Nameplates:RefreshAllPlates()
    end)
end

-- ── CVar management ───────────────────────────────────────────────────────────
function Nameplates:ApplyCVars()
    local db = self:GetDB()
    local fdb = self:GetFriendlyDB()

    if InCombatLockdown and InCombatLockdown() then
        self._pendingCVarRefresh = true
        return
    end

    self._pendingCVarRefresh = false
    self._pendingCVarRefreshNotified = nil

    for cvar, value in pairs(NAMEPLATE_CVARS) do
        SetCVarSafe(cvar, value)
    end
    local maxDist = Clamp(db.nameplateMaxDistance or 60, 20, 100)
    SetCVarSafe("nameplatePlayerMaxDistance", tostring(maxDist))

    local clampTarget = db.clampTargetNameplateToScreen
    if clampTarget == nil then
        clampTarget = GetCVarBoolSafe("clampTargetNameplateToScreen", true)
    end
    SetCVarSafe("clampTargetNameplateToScreen", clampTarget and "1" or "0")

    if SupportsStackingBitfield() then
        local enemyStacking = db.stackNameplates
        if enemyStacking == nil then
            enemyStacking = GetStackingBitfieldState("Enemy", false)
        end

        local friendlyStacking = fdb.stackNameplates
        if friendlyStacking == nil then
            friendlyStacking = GetStackingBitfieldState("Friendly", false)
        end

        SetStackingBitfieldState("Enemy", enemyStacking)
        SetStackingBitfieldState("Friendly", friendlyStacking)
    else
        local stacked = db.stackNameplates
        if stacked == nil then
            stacked = GetCVarBoolSafe("nameplateMotion", false)
        end
        SetCVarSafe("nameplateMotion", stacked and "1" or "0")
    end

    -- Match Blizzard's own friendly/enemy plate footprint to the active TwichUI
    -- configuration. ElvUI does this too. Even though we render our own overlay,
    -- keeping the underlying plate sizes separated avoids a whole class of Blizzard
    -- layout and anchor behaviors still assuming the old shared dimensions.
    if SupportsStackingBitfield() and C_NamePlate_SetNamePlateSize then
        pcall(C_NamePlate_SetNamePlateSize,
            Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600),
            Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60))
    elseif C_NamePlate_SetNamePlateEnemySize then
        pcall(C_NamePlate_SetNamePlateEnemySize,
            Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600),
            Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60))
    end
    if C_NamePlate_SetNamePlateFriendlySize then
        pcall(C_NamePlate_SetNamePlateFriendlySize,
            Clamp(fdb.width or db.width or NP_DEFAULT_WIDTH, 60, 600),
            Clamp(fdb.height or db.height or NP_DEFAULT_HEIGHT, 8, 60))
    end
    if SupportsStackingBitfield() and C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets and Enum_NamePlateType and Enum_NamePlateType.Enemy then
        pcall(C_NamePlateManager.SetNamePlateHitTestInsets,
            Enum_NamePlateType.Enemy,
            -10000, -10000, -10000, -10000)
    end

    NpLog(string.format(
        "ApplyCVars enemyStack=%s friendlyStack=%s clampTarget=%s",
        tostring(self:IsStackingEnabledForUnit(nil, false)),
        tostring(self:IsStackingEnabledForUnit(nil, true)),
        tostring(clampTarget == true)
    ))
end

-- ── Plate lifecycle ───────────────────────────────────────────────────────────
function Nameplates:OnNamePlateAdded(_, unitID)
    if not C_NamePlate then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unitID)
    if not plate then return end

    -- ── Suppress Blizzard's built-in unit frame ───────────────────────────────
    -- Plater's Midnight approach (Plater.lua ~4515-4550):
    --   1. hooksecurefunc(blizzUF, "Show")  — works on protected frames in combat
    --   2. hooksecurefunc(blizzUF, "SetAlpha") — catches Blizzard resetting alpha
    --   3. blizzUF:UnregisterAllEvents()    — prevents event-driven re-draws
    --   4. Reparent AurasFrame children to a hidden parent
    -- We MUST use hooksecurefunc, not HookScript — HookScript on protected frames
    -- is forbidden during combat lockdown.
    local blizzUF = plate.UnitFrame ---@type any
    if blizzUF and not blizzUF._twichSuppressed then
        blizzUF._twichSuppressed = true
        blizzUF:SetAlpha(0)

        -- Hook Show: whenever Blizzard tries to show it, zero alpha immediately.
        hooksecurefunc(blizzUF, "Show", function(f)
            if not f._isTwichFrame then f:SetAlpha(0) end
        end)

        -- Hook SetAlpha: prevent Blizzard from restoring the alpha (threat flashes etc.).
        local key = tostring(blizzUF)
        hooksecurefunc(blizzUF, "SetAlpha", function(f, v)
            if _alphaLocks[key] then return end
            if v ~= 0 then
                _alphaLocks[key] = true
                f:SetAlpha(0)
                _alphaLocks[key] = nil
            end
        end)

        -- Stop Blizzard receiving events that re-trigger element updates/shows.
        pcall(function() blizzUF:UnregisterAllEvents() end)
        pcall(function()
            if blizzUF.HealthBarsContainer and blizzUF.HealthBarsContainer.healthBar then
                blizzUF.HealthBarsContainer.healthBar:UnregisterAllEvents()
            end
            if blizzUF.castBar then blizzUF.castBar:UnregisterAllEvents() end
        end)

        -- Reparent Blizzard's aura/CC sub-frames to the hidden parent so they
        -- take no screen space and receive no further event-driven updates.
        pcall(function()
            if blizzUF.AurasFrame then
                local af = blizzUF.AurasFrame
                if af.DebuffListFrame then af.DebuffListFrame:SetParent(_hiddenPlateParent) end
                if af.BuffListFrame then af.BuffListFrame:SetParent(_hiddenPlateParent) end
                if af.CrowdControlListFrame then af.CrowdControlListFrame:SetParent(_hiddenPlateParent) end
                if af.LossOfControlFrame then af.LossOfControlFrame:SetParent(_hiddenPlateParent) end
            end
        end)
    elseif blizzUF then
        blizzUF:SetAlpha(0) -- already hooked; just re-zero
    end

    -- Suppress other non-TwichUI art children on the plate.
    pcall(function()
        local children = { plate:GetChildren() }
        for _, child in ipairs(children) do
            local anyChild = child ---@type any
            if anyChild ~= blizzUF and not anyChild._isTwichFrame and not anyChild._twichSuppressed then
                anyChild._twichSuppressed = true
                anyChild:SetAlpha(0)
                hooksecurefunc(anyChild, "Show", function(f) f:SetAlpha(0) end)
            end
        end
    end)

    local frame          = self:AcquirePlateFrame(plate)
    frame._unit          = unitID
    frame._plate         = plate -- store direct ref to avoid GetNamePlateForUnit on any unit token
    -- Seed the friendly flag BEFORE inserting into _plates so GetEffectiveDB can
    -- read it the moment any code looks up this unit via self._plates[unitID].
    frame._isFriendly    = self:IsFriendlyUnit(unitID)
    self._plates[unitID] = frame
    -- Apply friendly-specific sizing now that we know the unit reaction.
    -- BuildPlateFrame always uses the main DB (no unit yet); ResizePlateFrame
    -- re-reads GetEffectiveDB(unit) and corrects width/height for friendly plates.
    self:ResizePlateFrame(frame)

    -- Power bar visibility seed.
    -- Midnight secrets make direct UnitPowerMax comparisons unreliable, so prefer
    -- native frame visibility when it exists and fall back to always-on for players.
    frame._showPower = self:ShouldShowPowerForUnit(unitID, plate)

    local db         = self:GetEffectiveDB(unitID)
    local scale      = Clamp(db.scale or 1, 0.5, 2)
    frame:SetScale(scale)
    self:SetPlateFrameAlpha(frame, 0)
    frame:Show()

    self:UpdateAllElements(frame, unitID)
    self:AnimatePlateFrameAlpha(frame, self:GetDesiredPlateAlpha(frame, unitID, db), RANGE_FADE_ANIM_SEC)

    -- If cast test mode is running, start a fake cast on this new plate
    if self._castTestMode then
        C_Timer.After(math.random() * 0.5, function()
            if self._castTestMode and frame and frame:IsShown() then
                self:StartFakeCast(frame)
            end
        end)
    end
end

function Nameplates:OnNamePlateRemoved(_, unitID)
    local frame = self._plates[unitID]
    if not frame then return end
    self._plates[unitID] = nil
    _auraThrottle[unitID] = nil
    self:StopPlateSizeAnimation(frame)
    self:AnimatePlateFrameAlpha(frame, 0, RANGE_FADE_ANIM_SEC, function(f)
        self:ReleasePlateFrame(f)
    end)
end

-- ── Test mode ─────────────────────────────────────────────────────────────────
local TEST_SCENARIOS = {
    {
        name = "Voidguard Channeler",
        hp = 68,
        hpMax = 100,
        level = 80,
        classification = "elite",
        reaction = 3,
        casting = "Shadow Bolt",
        castProgress = 0.6,
        notInterruptible = false,
        absorbPeak = 34,
        absorbCycle = 7.0,
        absorbHold = 1.35,
    },
    {
        name = "Captain Aldric",
        hp = 50,
        hpMax = 100,
        level = 78,
        classification = "",
        reaction = 5,
        classToken = "WARRIOR",
        casting = nil
    },
    {
        name = "Gluttonous Maw",
        hp = 30,
        hpMax = 100,
        level = 83,
        classification = "worldboss",
        reaction = 3,
        casting = "Devour Essence",
        castProgress = 0.3,
        notInterruptible = true
    },
    {
        name = "Restoring Touch",
        hp = 72,
        hpMax = 100,
        level = 80,
        classification = "",
        reaction = 5,
        classToken = "PRIEST",
        casting = "Flash Heal",
        castProgress = 0.8,
        notInterruptible = false
    },
    {
        name = "Vorken the Rare",
        hp = 63,
        hpMax = 100,
        level = 79,
        classification = "rare",
        reaction = 3,
        casting = nil
    },
}

local function ApplyPreviewAbsorb(frame, value, maxValue)
    if not frame or not frame.absorbBar then return end

    local safeMax = math_max(1, tonumber(maxValue) or 1)
    local safeValue = Clamp(tonumber(value) or 0, 0, safeMax)
    ApplyAbsorbBarLayout(frame)
    frame.absorbBar:SetMinMaxValues(0, safeMax)
    frame.absorbBar:SetValue(safeValue)

    if safeValue > 0.001 then
        frame.absorbBar:Show()
    else
        frame.absorbBar:Hide()
    end
end

local function StopPreviewAbsorbDriver(frame)
    if not frame or not frame._previewAbsorbDriver then return end
    frame._previewAbsorbDriver:SetScript("OnUpdate", nil)
    frame._previewAbsorbDriver:Hide()
    frame._previewAbsorbDriver.elapsed = 0
end

local function StartPreviewAbsorbDriver(frame, mock)
    if not frame or not frame.absorbBar then return end

    StopPreviewAbsorbDriver(frame)

    local peak = tonumber(mock and mock.absorbPeak) or 0
    local maxValue = tonumber(mock and mock.hpMax) or 100
    if peak <= 0 then
        ApplyPreviewAbsorb(frame, tonumber(mock and mock.absorb) or 0, maxValue)
        return
    end

    local cycle = math_max(2.5, tonumber(mock.absorbCycle) or 7.0)
    local hold = Clamp(tonumber(mock.absorbHold) or 1.2, 0, cycle * 0.65)
    local ramp = math_max(0.45, (cycle - hold) * 0.35)
    local decay = math_max(0.8, cycle - hold - ramp)
    local driver = frame._previewAbsorbDriver or CreateFrame("Frame", nil, frame)
    frame._previewAbsorbDriver = driver
    driver.elapsed = 0
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        local t = self.elapsed % cycle
        local current

        if t < ramp then
            current = peak * (t / ramp)
        elseif t < (ramp + hold) then
            current = peak
        else
            current = peak * (1 - ((t - ramp - hold) / decay))
        end

        ApplyPreviewAbsorb(frame, current, maxValue)
    end)
    driver:Show()
end

function Nameplates:EnterTestMode()
    if self._testMode then return end
    self._testMode = true

    local db       = self:GetDB()
    local w        = Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600)
    local h        = Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60)
    local castH    = Clamp(db.castHeight or NP_DEFAULT_CAST_HEIGHT, 6, 30)
    local spacing  = h + castH + 36

    for i, mock in ipairs(TEST_SCENARIOS) do
        local anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(w, h)
        local col = (i % 2 == 0) and 1 or -1
        anchor:SetPoint("CENTER", UIParent, "CENTER",
            col * (w * 0.65),
            spacing * (3 - i))

        local frame = self:BuildPlateFrame(anchor)
        frame._isTestPreview = true
        frame._unit = "test_" .. i

        -- Name
        if frame.nameText then frame.nameText:SetText(mock.name) end

        -- Level
        if frame.levelText then
            frame.levelText:SetText(tostring(mock.level))
            frame.levelText:SetTextColor(0.8, 0.8, 0.8, 1)
            ApplyNameTextLayout(frame, db)
            if mock.classToken then
                local cc = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(mock.classToken))
                    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[mock.classToken])
                if cc and type(cc.r) == "number" then
                    frame.healthBar:SetStatusBarColor(cc.r, cc.g, cc.b, 1)
                end
            elseif mock.reaction then
                if mock.reaction >= 5 then
                    frame.healthBar:SetStatusBarColor(COLOR_FRIENDLY[1], COLOR_FRIENDLY[2], COLOR_FRIENDLY[3], 1)
                elseif mock.reaction == 4 then
                    frame.healthBar:SetStatusBarColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3], 1)
                else
                    frame.healthBar:SetStatusBarColor(COLOR_HOSTILE[1], COLOR_HOSTILE[2], COLOR_HOSTILE[3], 1)
                end
            end
        end

        -- Elite icon
        if frame.eliteIcon then
            local cl = mock.classification or ""
            if cl == "worldboss" or cl == "boss" then
                frame.eliteIcon:SetAtlas(ATLAS_BOSS); frame.eliteIcon:Show()
            elseif cl == "elite" or cl == "rareelite" then
                frame.eliteIcon:SetAtlas(ATLAS_ELITE); frame.eliteIcon:Show()
            elseif cl == "rare" then
                frame.eliteIcon:SetAtlas(ATLAS_RARE); frame.eliteIcon:Show()
            end
        end

        -- Target glow on first plate (preview)
        if i == 1 and frame.targetGlow then
            local ac = GetThemeColor("accentColor", { 0.96, 0.76, 0.24 })
            -- Mirror the live behaviour: colour the main frame border + show outer ring.
            frame:SetBackdropBorderColor(ac[1], ac[2], ac[3], 0.9)
            frame.targetGlow:SetBackdropBorderColor(ac[1], ac[2], ac[3], 0.55)
            frame.targetGlow:Show()
            if frame.arrowL then
                frame.arrowL:SetVertexColor(ac[1], ac[2], ac[3], 1); frame.arrowL:Show()
            end
            if frame.arrowR then
                frame.arrowR:SetVertexColor(ac[1], ac[2], ac[3], 1); frame.arrowR:Show()
            end
        end

        -- Cast bar
        frame._casting = false
        if mock.casting and frame.castContainer then
            frame._casting = true
            frame.castText:SetText(mock.casting)
            frame.castBar:SetMinMaxValues(0, 1)
            frame.castBar:SetValue(mock.castProgress or 0.5)
            if mock.notInterruptible then
                frame.castBar:SetStatusBarColor(COLOR_CAST_UNINT[1], COLOR_CAST_UNINT[2], COLOR_CAST_UNINT[3], 1)
                frame.castShield:Show()
            else
                local cc = CopyColor(db.castColor, COLOR_CAST)
                frame.castBar:SetStatusBarColor(cc[1], cc[2], cc[3], 1)
                frame.castShield:Hide()
            end
            frame.castContainer:Show()
        end

        if frame._casting and i ~= 1 then
            self:UpdateTargetGlow(frame, frame._unit)
        end

        -- Threat on first hostile plate
        if i == 1 and mock.reaction == 3 and frame.threatBar then
            frame.threatBar:SetVertexColor(0.87, 0.25, 0.25, 0.9)
        end

        if db.showAbsorb ~= false then
            StartPreviewAbsorbDriver(frame, mock)
        elseif frame.absorbBar then
            frame.absorbBar:Hide()
        end

        -- Fake aura icons (test aura mode)
        if db.showAuras ~= false and db.auraTestMode ~= false and frame.auraFrame then
            local FAKE_ICONS = { 135817, 136243, 135768, 135723 }
            local auraSize   = Clamp(db.auraSize or NP_DEFAULT_AURA_SIZE, 12, 40)
            local fSize      = Clamp(db.auraTimerFontSize or 8, 6, 14)
            local count      = math_min(#FAKE_ICONS, Clamp(db.auraMax or NP_DEFAULT_AURA_MAX, 0, NP_MAX_AURA_POOL))
            ApplyAuraFrameLayout(frame, db)
            for ai = 1, count do
                local iconF = frame.auraFrame.icons[ai]
                if iconF then
                    iconF:SetSize(auraSize, auraSize)
                    iconF.tex:SetTexture(FAKE_ICONS[ai])
                    iconF.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    local cd = iconF.cooldown
                    if cd then
                        if db.auraShowTimer ~= false then
                            -- Use plain SetCooldown for fake data (no tainted DurationObject).
                            local fakeRem = 10 + (ai * 8)
                            if cd.Timer then
                                cd.Timer:SetFont(_G.STANDARD_TEXT_FONT, fSize, "OUTLINE")
                            end
                            CooldownFrame_Set(cd, GetTime() - (30 - fakeRem), 30, 1, true, 1)
                            cd:Show()
                        else
                            cd:Hide()
                        end
                    end
                    iconF:Show()
                end
            end
            for ai = count + 1, NP_MAX_AURA_POOL do
                local iconF = frame.auraFrame.icons[ai]
                if iconF then iconF:Hide() end
            end
            frame.auraFrame:Show()
        end

        anchor:Show()
        frame:Show()
        self._testPlates[#self._testPlates + 1] = { frame = frame, anchor = anchor }
    end
end

function Nameplates:ExitTestMode()
    if not self._testMode then return end
    self._testMode = false
    for _, entry in ipairs(self._testPlates) do
        if entry.frame then
            _stopCastTicker(entry.frame)
            StopPreviewAbsorbDriver(entry.frame)
            entry.frame:Hide()
        end
        if entry.anchor then entry.anchor:Hide() end
    end
    wipe(self._testPlates)
end

function Nameplates:ToggleTestMode()
    if self._testMode then
        self:ExitTestMode()
    else
        self:EnterTestMode()
    end
end

-- ── Cast bar test mode ─────────────────────────────────────────────────────────────
local CAST_TEST_SPELLS = {
    { name = "Shadow Bolt",     duration = 2.0, notInterruptible = false, channeling = false },
    { name = "Mend Pet",        duration = 3.0, notInterruptible = false, channeling = true },
    { name = "Devour Essence",  duration = 2.5, notInterruptible = true,  channeling = false },
    { name = "Pyroblast",       duration = 3.5, notInterruptible = false, channeling = false },
    { name = "Arcane Missiles", duration = 2.0, notInterruptible = false, channeling = true },
    { name = "Fel Concentrate", duration = 2.8, notInterruptible = true,  channeling = false },
}

function Nameplates:StartFakeCast(frame)
    if not frame or not frame.castContainer then return end
    local db = self:GetDB()
    if db.showCastBar == false then return end

    local idx         = math.random(#CAST_TEST_SPELLS)
    local spell       = CAST_TEST_SPELLS[idx]
    local now         = GetTime()

    frame._casting    = true
    frame._channeling = spell.channeling
    frame._castStart  = now
    frame._castEnd    = now + spell.duration
    frame._castMax    = spell.duration

    frame.castText:SetText(spell.name)

    if spell.notInterruptible then
        frame.castBar:SetStatusBarColor(COLOR_CAST_UNINT[1], COLOR_CAST_UNINT[2], COLOR_CAST_UNINT[3], 1)
        frame.castShield:Show()
    elseif spell.channeling then
        local cc = CopyColor(db.castColor, COLOR_CHANNEL)
        frame.castBar:SetStatusBarColor(cc[1], cc[2], cc[3], 1)
        frame.castShield:Hide()
    else
        local cc = CopyColor(db.castColor, COLOR_CAST)
        frame.castBar:SetStatusBarColor(cc[1], cc[2], cc[3], 1)
        frame.castShield:Hide()
    end

    frame.castBar:SetMinMaxValues(0, spell.duration)
    frame.castBar:SetValue(0)
    frame.castContainer:Show()
    -- Use shared ticker; assign custom OnUpdate fields so _castTickerFn can drive it.
    frame._castObservedAt  = now
    frame._castDurationSec = spell.duration
    frame._castEnd         = now + spell.duration
    -- Reschedule the next fake cast when this one ends (replaces the old per-frame reschedule).
    frame._onCastEnd       = function(f)
        f._onCastEnd = nil
        if Nameplates._castTestMode and f and f:IsShown() then
            C_Timer.After(0.5 + math.random() * 1.5, function()
                if Nameplates._castTestMode and f and f:IsShown() then
                    Nameplates:StartFakeCast(f)
                end
            end)
        end
    end
    _startCastTicker(frame)
end

function Nameplates:EnterCastBarTestMode()
    if self._castTestMode then return end
    self._castTestMode = true
    -- Stagger fake casts on all visible plates
    local delay = 0
    for _, frame in pairs(self._plates) do
        local f = frame -- upvalue
        C_Timer.After(delay, function()
            if Nameplates._castTestMode then Nameplates:StartFakeCast(f) end
        end)
        delay = delay + 0.15
    end
end

function Nameplates:ExitCastBarTestMode()
    if not self._castTestMode then return end
    self._castTestMode = false
    for _, frame in pairs(self._plates) do
        frame._casting = false
        _stopCastTicker(frame)
        if frame.castContainer then frame.castContainer:Hide() end
    end
end

function Nameplates:ToggleCastBarTestMode()
    if self._castTestMode then
        self:ExitCastBarTestMode()
    else
        self:EnterCastBarTestMode()
    end
end

-- ── Module lifecycle ──────────────────────────────────────────────────────────
function Nameplates:OnInitialize()
    -- Intentionally empty; enable logic deferred to OnEnable
end

function Nameplates:OnEnable()
    self:InvalidateCache()

    -- WoW nameplate events
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnNamePlateAdded")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnNamePlateRemoved")
    self:RegisterEvent("UNIT_HEALTH", "OnUnitHealth")
    self:RegisterEvent("UNIT_MAXHEALTH", "OnUnitHealth")
    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", "OnUnitHealth")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    -- UNIT_POWER_FREQUENT fires every ~0.1s for every unit in combat.
    -- With 10+ mobs that is ~100 callbacks/sec. UNIT_POWER_UPDATE fires only when
    -- power actually changes, which is far less often for nameplated mobs.
    self:RegisterEvent("UNIT_POWER_UPDATE", "OnUnitPower")
    self:RegisterEvent("UNIT_MAXPOWER", "OnUnitPower")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "OnUnitDisplayPower")
    -- UNIT_POWER_BAR_SHOW/HIDE fire when a nameplate unit gains or loses a visible
    -- power resource (e.g. a boss mechanic starts draining energy, or an NPC's
    -- energy pool empties). We use these instead of comparing UnitPowerMax (a secret
    -- number in Midnight that cannot be compared in Lua).
    self:RegisterEvent("UNIT_POWER_BAR_SHOW", "OnUnitPowerBarShow")
    self:RegisterEvent("UNIT_POWER_BAR_HIDE", "OnUnitPowerBarHide")
    self:RegisterEvent("UNIT_SPELLCAST_START", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnCastEvent")
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", "OnThreatUpdate")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetFocusChanged")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnTargetFocusChanged")
    self:RegisterEvent("RAID_TARGET_UPDATE", "OnRaidTargetUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    -- Re-suppress Blizzard plate art when entering combat (Blizzard re-shows
    -- threat rings / selection art on PLAYER_REGEN_DISABLED and UNIT_THREAT_*).
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChange")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatStateChange")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "OnSpecChanged")
    -- Apply CVars
    self:ApplyCVars()

    -- Process any plates already visible (reload / late enable)
    C_Timer.After(0, function()
        if not self:IsEnabled() then return end
        if C_NamePlate and C_NamePlate.GetNamePlates then
            local plates = C_NamePlate.GetNamePlates()
            if plates then
                for _, plate in ipairs(plates) do
                    local unit = plate and plate.namePlateUnitToken
                    if unit then self:OnNamePlateAdded(unit) end
                end
            end
        end
    end)

    -- Register Interface Designer movers after a brief delay
    C_Timer.After(0.1, function()
        if self:IsEnabled() then self:RegisterMovers() end
    end)
end

function Nameplates:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()

    if self._testMode then self:ExitTestMode() end
    if self._castTestMode then self:ExitCastBarTestMode() end

    -- Restore Blizzard UnitFrame visibility on all active plates
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            for _, plate in ipairs(plates) do
                local uf = plate and plate.UnitFrame
                if uf then uf:SetAlpha(1) end
            end
        end
    end

    -- Clean up every custom frame
    for unitID, frame in pairs(self._plates) do
        _stopCastTicker(frame)
        frame:Hide()
    end
    wipe(self._plates)
    -- Clear the pool too so stale frames don't accumulate across enable/disable cycles.
    wipe(self._platePool)
    wipe(_activeCastPlates)
    wipe(_auraThrottle)
    _castTickerFrame:SetScript("OnUpdate", nil)
    _castTickerActive = false
end

-- ── Event handlers ───────────────────────────────────────────────────────────
function Nameplates:OnUnitHealth(_, unit)
    local frame = unit and self._plates[unit]
    if frame and UnitExists(unit) then
        self:UpdateHealth(frame, unit)
    end
end

function Nameplates:OnUnitAura(_, unit)
    local frame = unit and self._plates[unit]
    if not frame or not UnitExists(unit) then return end
    -- Throttle: auras change fire in bursts for every mob simultaneously.
    -- Skip if updated within the last AURA_THROTTLE_SEC seconds.
    local now = GetTime()
    local last = _auraThrottle[unit]
    if last and (now - last) < AURA_THROTTLE_SEC then return end
    _auraThrottle[unit] = now
    self:UpdateAuras(frame, unit)
end

function Nameplates:OnUnitPower(_, unit)
    local frame = unit and self._plates[unit]
    if frame and UnitExists(unit) then
        if not frame._showPower then
            frame._showPower = true
        end
        self:UpdatePower(frame, unit)
    end
end

function Nameplates:OnUnitDisplayPower(_, unit)
    -- Power type changed (e.g. druid shifting form) — re-fetch type and re-color.
    local frame = unit and self._plates[unit]
    if frame and UnitExists(unit) then
        if not frame._showPower then
            frame._showPower = true
        end
        self:UpdatePower(frame, unit)
    end
end

function Nameplates:OnUnitPowerBarShow(_, unit)
    -- An NPC's power bar has become visible (mechanic-driven or boss energy pool).
    local frame = unit and self._plates[unit]
    if frame then
        frame._showPower = true
        if UnitExists(unit) then self:UpdatePower(frame, unit) end
    end
end

function Nameplates:OnUnitPowerBarHide(_, unit)
    -- The unit's power bar has been hidden by the server (mechanic ended, etc.).
    local frame = unit and self._plates[unit]
    if frame then
        frame._showPower = self:ShouldShowPowerForUnit(unit, frame._plate)
        if frame._showPower then
            if UnitExists(unit) then self:UpdatePower(frame, unit) end
        elseif frame.powerContainer then
            frame.powerContainer:Hide()
        end
    end
end

function Nameplates:OnCastEvent(_, unit)
    local frame = unit and self._plates[unit]
    if frame then
        self:UpdateCastBar(frame, unit)
        self:UpdatePlateAlpha(frame, unit)
    end
end

function Nameplates:OnThreatUpdate(_, unit)
    -- IMPORTANT: UNIT_THREAT_SITUATION_UPDATE fires for ANY unit token (player, party1,
    -- raid5, targettarget, etc.).  C_NamePlate.GetNamePlateForUnit only accepts nameplate
    -- unit tokens and throws for anything else.  We NEVER call it here.
    -- Use the stored _plate reference instead (set in OnNamePlateAdded).
    local frame = unit and self._plates[unit]
    if not frame then return end
    self:UpdateThreat(frame, unit)
    -- BlizzUF suppression is handled by the OnShow hooks set at plate creation time;
    -- no manual re-suppression sweep needed here.
end

function Nameplates:OnTargetFocusChanged()
    for unitID, frame in pairs(self._plates) do
        self:UpdateTargetGlow(frame, unitID)
        self:UpdatePlateAlpha(frame, unitID)
    end
end

function Nameplates:OnRaidTargetUpdate()
    for unitID, frame in pairs(self._plates) do
        if frame and UnitExists(unitID) then
            self:UpdateRaidMarker(frame, unitID)
        end
    end
end

function Nameplates:OnPlayerEnteringWorld()
    self:ApplyCVars()
    C_Timer.After(0.5, function()
        if self:IsEnabled() then self:RefreshAllPlates() end
    end)
end

-- Blizzard re-shows its threat rings, selection art, and aggro overlays when entering
-- combat or when threat changes.  Individual plates already have OnShow hooks from
-- OnNamePlateAdded that force blizzUF alpha to 0 — no child sweep needed here.
function Nameplates:OnCombatStateChange()
    if (not InCombatLockdown or not InCombatLockdown()) and self._pendingCVarRefresh then
        self:ApplyCVars()
        C_Timer.After(0, function()
            if self:IsEnabled() then
                self:RefreshAllPlates()
            end
        end)
    end

    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end
    -- Re-zero blizzUF alpha (hooks handle OnShow; this catches any direct SetAlpha calls).
    for _, plate in ipairs(plates) do
        local blizzUF = plate.UnitFrame
        if blizzUF then blizzUF:SetAlpha(0) end
    end
    -- Re-assert our own frame alphas in case anything disturbed them.
    for unitID, frame in pairs(self._plates) do
        if frame then
            local edb = self:GetEffectiveDB(unitID)
            self:SetPlateFrameAlpha(frame, self:GetDesiredPlateAlpha(frame, unitID, edb))
            frame:SetScale(Clamp(edb.scale or 1, 0.5, 2))
        end
    end
end

function Nameplates:OnSpecChanged()
    -- Invalidate the cached role so GetPlayerIsTank() re-evaluates on next call.
    _cachedIsTank = nil
end

function Nameplates:SuppressAllBlizzardPlateChildren()
    self:OnCombatStateChange()
end

function Nameplates:OnThemeChanged()
    self:InvalidateCache()
    self:RefreshAllPlates()
end

-- Called from Options when any setting changes
function Nameplates:Refresh()
    self:InvalidateCache()
    -- Friendly/enemy footprint changes must be pushed into Blizzard's native
    -- nameplate system immediately. If we only apply these on enable/zone load,
    -- the friendly DB can say height=10 while the live Blizzard friendly plate
    -- still remains at the previous 26px size until reload.
    if InCombatLockdown and InCombatLockdown() and not self._pendingCVarRefreshNotified then
        self._pendingCVarRefreshNotified = true
        T:Print("[NP] Blizzard nameplate positioning changes will apply after combat.")
    end
    self:ApplyCVars()
    -- Update cooldown timer font on all existing icon pools when settings change.
    local function updatePoolFont(frame)
        if frame and frame.auraFrame and frame.auraFrame.icons then
            local edb   = Nameplates:GetEffectiveDB(frame._unit)
            local fSize = Clamp(edb.auraTimerFontSize or 8, 6, 28)
            for _, iconF in ipairs(frame.auraFrame.icons) do
                if iconF.cooldown and iconF.cooldown.Timer then
                    iconF.cooldown.Timer:SetFont(_G.STANDARD_TEXT_FONT, fSize, "OUTLINE")
                end
            end
        end
    end
    for _, frame in pairs(self._plates) do updatePoolFont(frame) end
    for _, entry in ipairs(self._testPlates or {}) do updatePoolFont(entry.frame) end
    self:RefreshAllPlates()
    self:QueuePlateRefresh(0)
    self:QueuePlateRefresh(0.1)
    if self._testMode then
        self:ExitTestMode()
        self:EnterTestMode()
    end
    if self._castTestMode then
        self:ExitCastBarTestMode()
        self:EnterCastBarTestMode()
    end
end

-- ── Interface Designer registration ──────────────────────────────────────────
function Nameplates:RegisterMovers()
    local moversModule = T:GetModule("Movers", true)
    if not moversModule or type(moversModule.RegisterMover) ~= "function" then return end

    local self2 = self -- upvalue capture

    moversModule:RegisterMover("NP_settings", {
        label     = "Nameplates",
        category  = "Unit Frames",
        -- Nameplates follow units; no single repositionable anchor.
        -- getFrame returns nil so no drag handle appears, but extras still render in the dock.
        getFrame  = function() return nil end,
        getX      = function() return 0 end,
        getY      = function() return 0 end,
        getW      = function() return Clamp(self2:GetDB().width or NP_DEFAULT_WIDTH, 60, 600) end,
        getH      = function() return Clamp(self2:GetDB().height or NP_DEFAULT_HEIGHT, 8, 60) end,
        setPos    = function() end, -- not positionally movable
        setSize   = function(w, h)
            local db  = self2:GetDB()
            db.width  = math_max(60, math_floor(w + 0.5))
            db.height = math_max(8, math_floor(h + 0.5))
            self2:Refresh()
        end,
        isEnabled = function() return self2:IsEnabled() end,
        extras    = {
            {
                label = "Enabled",
                type  = "toggle",
                get   = function() return self2:IsEnabled() end,
                set   = function(v)
                    local opts = self2:GetOptions()
                    if opts and type(opts.SetModuleEnabled) == "function" then
                        opts:SetModuleEnabled(nil, v)
                    elseif v then
                        self2:Enable()
                    else
                        self2:Disable()
                    end
                end,
            },
            {
                label = "Test Mode",
                type  = "execute",
                func  = function() self2:ToggleTestMode() end,
            },
            {
                label = "Alpha",
                type = "range",
                min = 0.05,
                max = 1.0,
                step = 0.05,
                get = function() return Clamp(self2:GetDB().alpha or 1, 0.05, 1.0) end,
                set = function(v)
                    self2:GetDB().alpha = v
                    for _, frame in pairs(self2._plates) do
                        self2:SetPlateFrameAlpha(frame, v)
                    end
                end,
            },
            {
                label = "Scale",
                type = "range",
                min = 0.5,
                max = 2.0,
                step = 0.05,
                get = function() return Clamp(self2:GetDB().scale or 1, 0.5, 2.0) end,
                set = function(v)
                    self2:GetDB().scale = v
                    for _, frame in pairs(self2._plates) do
                        frame:SetScale(v)
                    end
                end,
            },
            {
                label = "Bar Width",
                type = "range",
                min = 60,
                max = 500,
                step = 5,
                get = function() return Clamp(self2:GetDB().width or NP_DEFAULT_WIDTH, 60, 500) end,
                set = function(v)
                    self2:GetDB().width = math_floor(v + 0.5)
                    self2:Refresh()
                end,
            },
            {
                label = "Bar Height",
                type = "range",
                min = 8,
                max = 60,
                step = 1,
                get = function() return Clamp(self2:GetDB().height or NP_DEFAULT_HEIGHT, 8, 60) end,
                set = function(v)
                    self2:GetDB().height = math_floor(v + 0.5)
                    self2:Refresh()
                end,
            },
        },
    })
end

-- ── Debug report ─────────────────────────────────────────────────────────────
function Nameplates:BuildDebugReport()
    local lines = {}
    local function add(s) lines[#lines + 1] = SanitizeDebugLine(s) end
    local function fmtValue(v)
        local ok, ts = pcall(tostring, v)
        return (ok and type(ts) == "string") and ts or "<secret>"
    end
    local function addDBSection(title, db, keys)
        add(title)
        if not db then
            add("  DB unavailable")
            add("")
            return
        end
        for _, k in ipairs(keys) do
            local ok, v = pcall(function() return db[k] end)
            add(string.format("  %-28s = %s", k, ok and fmtValue(v) or "<tainted>"))
        end
        add("")
    end

    add("=== Nameplates Debug Report ===")
    add("")

    local dbKeys = {
        "enabled", "width", "height", "alpha", "scale",
        "stackNameplates", "stackingWidthScale", "stackingHeightScale", "clampTargetNameplateToScreen",
        "healthColorMode", "healthFont", "healthFontSize", "healthFontFlags",
        "healthFormat", "healthTextAnchor", "showAbsorb",
        "castFont", "castFontSize", "castHeight", "showCastBar", "showPowerBar",
        "nameFont", "nameFontSize", "nameFontFlags", "nameAnchorPoint", "nameJustify", "nameWidth",
        "nameOffsetX", "nameOffsetY",
        "showLevel", "showEliteIcon", "showRaidMarker", "raidMarkerPoint", "raidMarkerOffsetX", "raidMarkerOffsetY",
        "raidMarkerScale", "showTargetGlow", "showTargetArrow",
        "showThreat", "showAuras", "auraSize", "auraMax", "auraOnlyMine", "auraAnchorPoint", "auraOffsetX", "auraOffsetY",
    }
    addDBSection("--- Main DB ---", self:GetDB(), dbKeys)

    local baseDB = self:GetDB()
    local friendlyDB = baseDB and baseDB.friendly or nil
    addDBSection("--- Friendly Overrides ---", friendlyDB, dbKeys)

    -- Theme
    add("--- Theme ---")
    local theme = self._themeCache or (T and T:GetModule("Theme", true))
    if theme and type(theme.Get) == "function" then
        for _, k in ipairs({ "statusBarTexture", "globalFont", "primaryColor" }) do
            local ok, v = pcall(theme.Get, theme, k)
            add(string.format("  %-28s = %s", k, ok and tostring(v) or "error"))
        end
    else
        add("  Theme module unavailable")
    end
    add("")

    add("--- Runtime Positioning ---")
    add(string.format("  %-28s = %s", "stackingBitfieldSupported", tostring(SupportsStackingBitfield() and true or false)))
    add(string.format("  %-28s = %s", "enemyStackingActive", tostring(self:IsStackingEnabledForUnit(nil, false))))
    add(string.format("  %-28s = %s", "friendlyStackingActive", tostring(self:IsStackingEnabledForUnit(nil, true))))
    add(string.format("  %-28s = %s", "clampTargetActive", tostring(self:GetDB().clampTargetNameplateToScreen ~= false)))
    if SupportsStackingBitfield() then
        add(string.format("  %-28s = %s", "enemyBitfield", tostring(GetStackingBitfieldState("Enemy", false))))
        add(string.format("  %-28s = %s", "friendlyBitfield", tostring(GetStackingBitfieldState("Friendly", false))))
    end
    add("")

    -- Plate count
    local total, visible = 0, 0
    for _, frame in pairs(self._plates) do
        total = total + 1
        pcall(function() if frame and frame:IsShown() then visible = visible + 1 end end)
    end
    add(string.format("--- Plates: %d tracked / %d visible ---", total, visible))

    -- Visible plate details.
    -- MIDNIGHT SECRET: calling frame methods (IsShown, GetWidth, GetFont, GetText, etc.)
    -- on nameplate-parented frames returns tainted/secret values in combat.  string.format
    -- propagates taint, inserting secret strings into `lines` which then crash
    -- table.concat.  Wrap the entire detail block in pcall so a single tainted value
    -- does not break the whole report.
    local found = false
    for unit, frame in pairs(self._plates) do
        -- IsShown may itself be tainted; guard with pcall
        local shown = false
        pcall(function() if frame and frame:IsShown() then shown = true end end)
        if shown then
            found = true
            local effDB = self:GetEffectiveDB(unit)
            local rawMainDB = self:GetDB()
            local rawFriendlyDB = rawMainDB and rawMainDB.friendly or nil
            local unitName = "<unknown>"
            pcall(function()
                local n = UnitName(unit)
                if n then unitName = tostring(n) end
            end)
            local isPlayer = false
            local isFriend = false
            local canAttack = false
            pcall(function() isPlayer = UnitIsPlayer(unit) == true end)
            pcall(function() isFriend = UnitIsFriend and UnitIsFriend(unit, "player") == true end)
            pcall(function() canAttack = UnitCanAttack and UnitCanAttack("player", unit) == true end)

            add(string.format("  sample unit : %s", tostring(unit)))
            add(string.format("  unit name   : %s", unitName))
            add(string.format("  routing     : _isFriendly=%s  UnitIsFriend=%s  UnitCanAttack=%s  UnitIsPlayer=%s",
                tostring(frame._isFriendly), tostring(isFriend), tostring(canAttack), tostring(isPlayer)))
            add(string.format("  db source   : %s",
                (effDB == rawFriendlyDB or frame._isFriendly) and "friendly" or "main"))
            add(string.format("  db heights  : main=%s  friendly=%s  effective=%s",
                fmtValue(rawMainDB and rawMainDB.height),
                fmtValue(rawFriendlyDB and rawFriendlyDB.height),
                fmtValue(effDB and effDB.height)))
            add(string.format("  db names    : anchor=%s  justify=%s  ox=%s  oy=%s",
                fmtValue(effDB and effDB.nameAnchorPoint),
                fmtValue(effDB and effDB.nameJustify),
                fmtValue(effDB and effDB.nameOffsetX),
                fmtValue(effDB and effDB.nameOffsetY)))
            -- Stored metadata (_unit, _casting, etc.) is set by us — always safe.
            add(string.format("  casting     : %s  channeling=%s",
                tostring(frame._casting), tostring(frame._channeling)))
            -- Frame method calls that may return tainted values — each in its own pcall.
            local function safeGet(fmt, fn)
                local ok, result = pcall(fn)
                add(ok and result or (fmt .. " <tainted>"))
            end
            safeGet("  frame size", function()
                return string.format("  frame size  : %.0f x %.0f", frame:GetWidth(), frame:GetHeight())
            end)
            if frame._plate then
                safeGet("  native plate", function()
                    local plate = frame._plate
                    return string.format("  nativePlate : %.0f x %.0f",
                        plate:GetWidth(), plate:GetHeight())
                end)
            end
            if frame.stackBoundsFrame then
                safeGet("  stack bounds", function()
                    local bounds = frame.stackBoundsFrame
                    return string.format("  stackBounds : %.0f x %.0f",
                        bounds:GetWidth(), bounds:GetHeight())
                end)
            end
            safeGet("  frame point", function()
                local p1, relTo, p2, x, y = frame:GetPoint(1)
                local relName = relTo and relTo.GetName and relTo:GetName() or tostring(relTo)
                return string.format("  frame point : p1=%s rel=%s p2=%s x=%.0f y=%.0f",
                    tostring(p1), tostring(relName), tostring(p2), x or 0, y or 0)
            end)
            if frame.healthBar then
                safeGet("  healthBar", function()
                    local hb = frame.healthBar
                    return string.format("  healthBar   : IsShown=%s  w=%.0f h=%.0f",
                        tostring(hb:IsShown()), hb:GetWidth(), hb:GetHeight())
                end)
            end
            if frame.healthText then
                safeGet("  healthText", function()
                    local ht = frame.healthText
                    return string.format("  healthText  : IsShown=%s  pts=%d",
                        tostring(ht:IsShown()), ht:GetNumPoints())
                end)
            else
                add("  healthText  : NOT CREATED")
            end
            if frame.nameText then
                safeGet("  nameText", function()
                    local nt = frame.nameText
                    local p1, relTo, p2, x, y = nt:GetPoint(1)
                    local relName = relTo and relTo.GetName and relTo:GetName() or tostring(relTo)
                    return string.format(
                        "  nameText    : IsShown=%s  w=%.0f  justify=%s  p1=%s rel=%s p2=%s x=%.0f y=%.0f",
                        tostring(nt:IsShown()), nt:GetWidth(), tostring(nt:GetJustifyH()),
                        tostring(p1), tostring(relName), tostring(p2), x or 0, y or 0)
                end)
            end
            if frame.castBar then
                safeGet("  castBar", function()
                    local cb = frame.castBar
                    return string.format("  castBar     : IsShown=%s", tostring(cb:IsShown()))
                end)
            end
            if frame.raidMarkerIcon then
                safeGet("  raidMarker", function()
                    local marker = frame.raidMarkerIcon
                    local index = nil
                    if GetRaidTargetIndex then
                        pcall(function() index = GetRaidTargetIndex(unit) end)
                    end
                    return string.format("  raidMarker  : shown=%s  enabled=%s  index=%s",
                        tostring(marker:IsShown()), tostring(effDB.showRaidMarker ~= false), fmtValue(index))
                end)
            end
            if frame.powerBar and frame.powerContainer then
                safeGet("  powerBar", function()
                    local pb = frame.powerBar
                    local pc = frame.powerContainer
                    return string.format("  powerBar    : container=%s  bar=%s  seeded=%s",
                        tostring(pc:IsShown()), tostring(pb:IsShown()), tostring(frame._showPower))
                end)
            end
            add("")
        end
    end
    if not found then
        add("  (no visible plates in range)")
    end

    add("")
    add("=== End Nameplates Report ===")

    -- Append any diagnostic log lines captured since load.
    -- Lines may contain secret strings if previous code passed secrets to NpLog;
    -- use a safe per-element tostring that falls back to "<secret>" instead of
    -- crashing table.concat with an invalid value.
    local dc = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if dc and dc.GetLines then
        local logLines = dc:GetLines("nameplates")
        if logLines and #logLines > 0 then
            add("")
            add("--- Diagnostic log (last " .. math.min(#logLines, 20) .. ") ---")
            local start = math.max(1, #logLines - 19)
            for i = start, #logLines do
                add(logLines[i])
            end
        end
    end

    return table.concat(lines, "\n")
end

-- ── DebugConsole source registration ────────────────────────────────────────
do
    local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if DebugConsole and DebugConsole.RegisterSource then
        DebugConsole:RegisterSource("nameplates", {
            title       = "Nameplates",
            order       = 30,
            aliases     = { "np", "nameplate" },
            maxLines    = 200,
            isEnabled   = function()
                return Nameplates:IsEnabled()
            end,
            buildReport = function()
                return Nameplates:BuildDebugReport()
            end,
        })
    end
end
