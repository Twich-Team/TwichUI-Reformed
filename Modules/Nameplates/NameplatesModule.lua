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

local TwichRx                = _G.TwichRx
---@type TwichUI
local T                      = unpack(TwichRx)

---@class NameplatesModule : AceModule, AceEvent-3.0, AceTimer-3.0
local Nameplates             = T:NewModule("Nameplates", "AceEvent-3.0", "AceTimer-3.0")

-- ── WoW API locals ──────────────────────────────────────────────────────────
local CreateFrame            = _G.CreateFrame
local UIParent               = _G.UIParent
local C_NamePlate            = _G.C_NamePlate
local C_UnitAuras            = _G.C_UnitAuras
local C_Timer                = _G.C_Timer
local C_Spell                = _G.C_Spell
local UnitReaction           = _G.UnitReaction
local UnitExists             = _G.UnitExists
local UnitHealth             = _G.UnitHealth
local UnitHealthMax          = _G.UnitHealthMax
local UnitName               = _G.UnitName
local UnitIsPlayer           = _G.UnitIsPlayer
local UnitLevel              = _G.UnitLevel
local UnitIsUnit             = _G.UnitIsUnit
local UnitClass              = _G.UnitClass
local UnitAffectingCombat    = _G.UnitAffectingCombat
local UnitThreatSituation    = _G.UnitThreatSituation
local UnitIsTapDenied        = _G.UnitIsTapDenied
local UnitGetTotalAbsorbs    = _G.UnitGetTotalAbsorbs
local UnitIsDeadOrGhost      = _G.UnitIsDeadOrGhost
local UnitCastingInfo        = _G.UnitCastingInfo
local UnitChannelInfo        = _G.UnitChannelInfo
local UnitClassification     = _G.UnitClassification
local UnitPower              = _G.UnitPower
local UnitPowerMax           = _G.UnitPowerMax
local UnitPowerType          = _G.UnitPowerType
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local GetSpecalization       = _G.GetSpecialization
local GetSpecalizationRole   = _G.GetSpecializationRole
local GetTime                = _G.GetTime
local CooldownFrame_Set      = _G.CooldownFrame_Set
local RAID_CLASS_COLORS      = _G.RAID_CLASS_COLORS
local C_ClassColor           = _G.C_ClassColor
local math_max               = math.max
local math_min               = math.min
local math_floor             = math.floor

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
local _activeCastPlates  = {}   -- frame → true
local _castTickerActive  = false
local _castTickerFrame   = CreateFrame("Frame", "TwichUI_NpCastTicker", UIParent)

local function _castTickerFn()
    local now      = GetTime()
    local anyLeft  = false
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
    local ok = pcall(_G.SetCVar, name, tostring(value))
    if not ok and _G.C_CVar and _G.C_CVar.SetCVar then
        pcall(_G.C_CVar.SetCVar, name, tostring(value))
    end
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
    local reaction = UnitReaction and UnitReaction(unit, "player")
    return reaction ~= nil and reaction >= 5
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
function Nameplates:GetEffectiveDB(unit)
    if unit and self:IsFriendlyUnit(unit) then
        return self:GetFriendlyDB()
    end
    return self:GetDB()
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

        -- Classification sub-type colours (hostile only).
        -- Classification always wins — a boss that is also a caster class stays boss color.
        local reaction = UnitReaction and UnitReaction(unit, "player")
        if reaction and reaction <= 3 then
            local cl = UnitClassification and UnitClassification(unit) or ""
            if cl == "worldboss" or cl == "boss" then
                return DBColor(db, "colorBoss", COLOR_BOSS)
            elseif cl == "rareelite" then
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

            -- Caster-type NPC detection (only for non-classified hostiles).
            if db.colorByCaster then
                local baseClass = UnitClassBase and UnitClassBase(unit)
                if baseClass == "PALADIN" then
                    return DBColor(db, "colorNpcCaster", COLOR_NPC_CASTER)
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
    local db                  = self:GetDB()
    local w                   = Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600)
    local h                   = Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60)
    local castH               = Clamp(db.castHeight or NP_DEFAULT_CAST_HEIGHT, 6, 30)
    local auraMax             = Clamp(db.auraMax or NP_DEFAULT_AURA_MAX, 0, NP_MAX_AURA_POOL)
    local auraSize            = Clamp(db.auraSize or NP_DEFAULT_AURA_SIZE, 12, 40)
    local hpTex               = GetPlateTexture("healthBarTexture", db)
    local castTex             = GetPlateTexture("castBarTexture", db)
    local bgTex               = GetPlateTexture("healthBgTexture", db)

    local bgC                 = type(db.healthBgColor) == "table" and db.healthBgColor or { 0.05, 0.06, 0.08, 0.92 }
    local bdC                 = type(db.healthBorderColor) == "table" and db.healthBorderColor or
        { 0.14, 0.15, 0.20, 0.90 }
    local cbgC                = type(db.castBgColor) == "table" and db.castBgColor or { 0.05, 0.06, 0.08, 0.92 }
    local cbdC                = type(db.castBorderColor) == "table" and db.castBorderColor or { 0.14, 0.15, 0.20, 0.90 }

    -- ── Root frame ────────────────────────────────────────────────────────────
    -- MIDNIGHT SECRET: parentPlate:GetFrameLevel() returns a secret/tainted number.
    -- ANY arithmetic on it (+ 3, - 1) causes a secret-arithmetic crash that silently
    -- kills BuildPlateFrame before self._plates[unitID] is set → 0 plates tracked.
    -- Fix: use fixed frame levels.  Our frame at 140 sits above Blizzard's UnitFrame.
    local NP_FRAME_LEVEL      = 140
    local NP_GLOW_FRAME_LEVEL = 138
    local frame               = CreateFrame("Frame", nil, parentPlate or UIParent, "BackdropTemplate")
    frame._isTwichFrame       = true -- used by suppression loops to skip our own frame
    frame:SetSize(w, h)
    frame:SetPoint("CENTER", parentPlate or UIParent, "CENTER", 0, 0)
    frame:SetFrameLevel(NP_FRAME_LEVEL)
    ApplyBackdrop(frame, bgC[1], bgC[2], bgC[3], bgC[4], bdC[1], bdC[2], bdC[3], bdC[4])

    -- ── Target / focus glow ring ──────────────────────────────────────────────
    local glowOutset = Clamp(db.targetGlowOutset or 4, 1, 12)
    local targetGlow = CreateFrame("Frame", nil, parentPlate, "BackdropTemplate")
    targetGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", -glowOutset, glowOutset)
    targetGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", glowOutset, -glowOutset)
    targetGlow:SetFrameLevel(NP_GLOW_FRAME_LEVEL)
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
    healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    healthBar:SetHeight(h - 2)
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

    -- ── Absorb overlay ────────────────────────────────────────────────────────
    local absorbBar = CreateFrame("StatusBar", nil, healthBar)
    absorbBar:SetAllPoints()
    absorbBar:SetStatusBarTexture(hpTex)
    absorbBar:SetStatusBarColor(0.67, 0.85, 0.97, 0.5)
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:SetReverseFill(true)
    absorbBar:Hide()
    frame.absorbBar = absorbBar

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
    if db.nameFontShadow then nameText:SetShadowOffset(1, -1) else nameText:SetShadowOffset(0, 0) end
    nameText:SetPoint(nameAnchorPt, frame, "TOPLEFT", nameOX, nameOY)
    nameText:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -nameOX, nameOY)
    nameText:SetJustifyH(db.nameJustify or "LEFT")
    nameText:SetTextColor(1, 1, 1, 1)
    nameText:SetWordWrap(false)
    frame.nameText     = nameText

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
    frame.eliteIcon      = eliteIcon

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
    local aurasYOffset = castH + 8
    auraFrame:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, aurasYOffset)
    auraFrame:SetSize(w, auraSize + 4)
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
    frame.auraFrame      = auraFrame

    -- Cast state tracking
    frame._casting       = false
    frame._channeling    = false
    frame._castStart     = 0
    frame._castEnd       = 0
    frame._castMax       = 1
    frame._castObservedAt  = 0
    frame._castDurationSec = 1
    frame._onCastEnd     = nil
    frame._unit          = nil
    frame._isTestPreview = false

    return frame
end

-- ── Frame pool acquisition / release ─────────────────────────────────────────
-- Recycling plate frames avoids allocating ~25 sub-frames per mob on every pull.
function Nameplates:AcquirePlateFrame(plate)
    local frame = tremove(self._platePool)
    if frame then
        -- Reparent to new Blizzard plate so positioning is correct.
        frame:SetParent(plate)
        if frame.targetGlow then frame.targetGlow:SetParent(plate) end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", plate, "CENTER", 0, 0)
        frame._isTestPreview = false
        return frame
    end
    return self:BuildPlateFrame(plate)
end

function Nameplates:ReleasePlateFrame(frame)
    if not frame then return end
    -- Cancel any active cast animation on the shared ticker.
    _stopCastTicker(frame)
    frame._unit            = nil
    frame._plate           = nil
    frame._casting         = false
    frame._channeling      = false
    frame._castObservedAt  = 0
    frame._castDurationSec = 1
    frame._onCastEnd       = nil
    -- Hide all sub-elements so recycled frames start invisible.
    frame:Hide()
    if frame.castContainer then frame.castContainer:Hide() end
    if frame.targetGlow    then frame.targetGlow:Hide()    end
    if frame.auraFrame     then frame.auraFrame:Hide()     end
    if frame.absorbBar     then frame.absorbBar:Hide()     end
    if frame.arrowL        then frame.arrowL:Hide()        end
    if frame.arrowR        then frame.arrowR:Hide()        end
    self._platePool[#self._platePool + 1] = frame
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

    -- Absorb overlay.
    -- In Midnight, UnitGetTotalAbsorbs returns a secret number. Comparison (absorb > 0) is blocked
    -- by the taint system — even inside pcall it fails as an upvalue comparison error.
    -- Solution: always set the bar and show it; zero absorb produces zero fill (visually absent).
    if db.showAbsorb ~= false and UnitGetTotalAbsorbs then
        local absorb = UnitGetTotalAbsorbs(unit)
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
            -- UnitHealthPercent returns a secret number in Midnight — comparison (pct > 1) is
            -- blocked, but string.format with %d accepts secret numbers directly (Plater verified).
            -- UnitHealthPercent(unit, true) returns 0-100 scale without CurveConstants.ScaleTo100.
            -- Wrapped in pcall in case the API doesn't exist on this build.
            local ok, result = pcall(function()
                local fn = _G.UnitHealthPercent
                if fn then
                    local pct = fn(unit, true)
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

function Nameplates:UpdateTargetGlow(frame, unit)
    if not frame or not frame.targetGlow then return end
    local db = self:GetDB()

    -- Helper: restore the frame's normal border colour from stored state or DB.
    local function RestoreBorder()
        local bc = frame._normalBdColor
            or (type(db.healthBorderColor) == "table" and db.healthBorderColor)
            or { 0.14, 0.15, 0.20, 0.90 }
        frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 0.9)
    end

    if db.showTargetGlow == false then
        RestoreBorder()
        frame.targetGlow:Hide()
        if frame.arrowL then frame.arrowL:Hide() end
        if frame.arrowR then frame.arrowR:Hide() end
        return
    end

    local isTarget = UnitIsUnit and UnitIsUnit(unit, "target")
    local isFocus  = UnitIsUnit and UnitIsUnit(unit, "focus")
    local baseW    = Clamp(db.width or NP_DEFAULT_WIDTH, 60, 600)
    local baseH    = Clamp(db.height or NP_DEFAULT_HEIGHT, 8, 60)

    if isTarget then
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
        frame:SetSize(baseW * growW, baseH * growH)

        if db.showTargetArrows ~= false then
            -- Use dedicated arrow color if set, otherwise fall back to the glow color.
            local ac = type(db.targetArrowColor) == "table" and db.targetArrowColor or nil
            local ar = ac and ac[1] or gr
            local ag = ac and ac[2] or gg
            local ab = ac and ac[3] or gb
            if frame.arrowL then
                frame.arrowL:SetVertexColor(ar, ag, ab, 1)
                frame.arrowL:Show()
            end
            if frame.arrowR then
                frame.arrowR:SetVertexColor(ar, ag, ab, 1)
                frame.arrowR:Show()
            end
        else
            if frame.arrowL then frame.arrowL:Hide() end
            if frame.arrowR then frame.arrowR:Hide() end
        end
    elseif isFocus then
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
        frame:SetSize(baseW, baseH)
    else
        RestoreBorder()
        frame.targetGlow:Hide()
        if frame.arrowL then frame.arrowL:Hide() end
        if frame.arrowR then frame.arrowR:Hide() end
        frame:SetSize(baseW, baseH)
    end
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
end

function Nameplates:UpdatePower(frame, unit)
    if not frame or not frame.powerContainer then return end
    local db = self:GetEffectiveDB(unit)

    if db.showPowerBar == false then
        frame.powerContainer:Hide()
        return
    end

    -- Hide the power bar for units that have no power resource (e.g. many NPCs).
    -- UnitPowerMax returns a secret number in Midnight so comparison is pcall-guarded;
    -- on error we assume the unit does have power (safe default — shows the bar).
    local hasPower = true
    pcall(function()
        if UnitPowerMax(unit) == 0 then hasPower = false end
    end)
    if not hasPower then
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
    self:UpdateTargetGlow(frame, unit)
    self:UpdateThreat(frame, unit)
    self:UpdateCastBar(frame, unit)
    self:UpdateAuras(frame, unit)
    self:UpdatePower(frame, unit)
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
    if frame.absorbBar then frame.absorbBar:SetStatusBarTexture(hpTex) end

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
        -- Re-apply anchor point and horizontal justify whenever theme/settings change.
        local nameAnchorPt   = db.nameAnchorPoint or "BOTTOMLEFT"
        local nameOX, nameOY = db.nameOffsetX or 2, db.nameOffsetY or 3
        frame.nameText:ClearAllPoints()
        frame.nameText:SetPoint(nameAnchorPt, frame, "TOPLEFT", nameOX, nameOY)
        frame.nameText:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -nameOX, nameOY)
        frame.nameText:SetJustifyH(db.nameJustify or "LEFT")
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

    frame:SetSize(w, h)
    if frame.healthBar then frame.healthBar:SetHeight(h - 2) end
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
end

function Nameplates:RefreshAllPlates()
    self:InvalidateCache()
    for unitID, frame in pairs(self._plates) do
        self:ResizePlateFrame(frame)
        self:ApplyThemeToFrame(frame)
        if unitID and UnitExists(unitID) then
            self:UpdateAllElements(frame, unitID)
        end
    end
end

-- ── CVar management ───────────────────────────────────────────────────────────
function Nameplates:ApplyCVars()
    local db = self:GetDB()
    for cvar, value in pairs(NAMEPLATE_CVARS) do
        SetCVarSafe(cvar, value)
    end
    local maxDist = Clamp(db.nameplateMaxDistance or 60, 20, 100)
    SetCVarSafe("nameplatePlayerMaxDistance", tostring(maxDist))
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
    local blizzUF = plate.UnitFrame
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
            if child ~= blizzUF and not child._isTwichFrame and not child._twichSuppressed then
                child._twichSuppressed = true
                child:SetAlpha(0)
                hooksecurefunc(child, "Show", function(f) f:SetAlpha(0) end)
            end
        end
    end)

    local frame          = self:AcquirePlateFrame(plate)
    frame._unit          = unitID
    frame._plate         = plate -- store direct ref to avoid GetNamePlateForUnit on any unit token
    self._plates[unitID] = frame
    -- Apply friendly-specific sizing now that we know the unit reaction.
    -- BuildPlateFrame always uses the main DB (no unit yet); ResizePlateFrame
    -- re-reads GetEffectiveDB(unit) and corrects width/height for friendly plates.
    self:ResizePlateFrame(frame)

    local db             = self:GetEffectiveDB(unitID)
    local alpha          = Clamp(db.alpha or 1, 0.1, 1)
    local scale          = Clamp(db.scale or 1, 0.5, 2)
    frame:SetAlpha(alpha)
    frame:SetScale(scale)
    frame:Show()

    self:UpdateAllElements(frame, unitID)

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
    self:ReleasePlateFrame(frame)
    _auraThrottle[unitID] = nil
    self._plates[unitID] = nil
end

-- ── Test mode ─────────────────────────────────────────────────────────────────
local TEST_SCENARIOS = {
    {
        name = "Shadowmage Selene",
        hp = 68,
        hpMax = 100,
        level = 80,
        classification = "elite",
        reaction = 3,
        casting = "Shadow Bolt",
        castProgress = 0.6,
        notInterruptible = false
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
        end

        -- Health
        if frame.healthBar then
            frame.healthBar:SetMinMaxValues(0, mock.hpMax)
            frame.healthBar:SetValue(mock.hp)

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
        if mock.casting and frame.castContainer then
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

        -- Threat on first hostile plate
        if i == 1 and mock.reaction == 3 and frame.threatBar then
            frame.threatBar:SetVertexColor(0.87, 0.25, 0.25, 0.9)
        end

        -- Fake aura icons (test aura mode)
        if db.showAuras ~= false and db.auraTestMode ~= false and frame.auraFrame then
            local FAKE_ICONS = { 135817, 136243, 135768, 135723 }
            local auraSize   = Clamp(db.auraSize or NP_DEFAULT_AURA_SIZE, 12, 40)
            local fSize      = Clamp(db.auraTimerFontSize or 8, 6, 14)
            local count      = math_min(#FAKE_ICONS, Clamp(db.auraMax or NP_DEFAULT_AURA_MAX, 0, NP_MAX_AURA_POOL))
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
    frame._onCastEnd = function(f)
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
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    -- UNIT_POWER_FREQUENT fires every ~0.1s for every unit in combat.
    -- With 10+ mobs that is ~100 callbacks/sec. UNIT_POWER_UPDATE fires only when
    -- power actually changes, which is far less often for nameplated mobs.
    self:RegisterEvent("UNIT_POWER_UPDATE", "OnUnitPower")
    self:RegisterEvent("UNIT_MAXPOWER", "OnUnitPower")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "OnUnitDisplayPower")
    self:RegisterEvent("UNIT_SPELLCAST_START", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnCastEvent")
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", "OnThreatUpdate")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetFocusChanged")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnTargetFocusChanged")
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
        self:UpdatePower(frame, unit)
    end
end

function Nameplates:OnUnitDisplayPower(_, unit)
    -- Power type changed (e.g. druid shifting form) — re-fetch type and re-color.
    local frame = unit and self._plates[unit]
    if frame and UnitExists(unit) then
        self:UpdatePower(frame, unit)
    end
end

function Nameplates:OnCastEvent(_, unit)
    local frame = unit and self._plates[unit]
    if frame then
        self:UpdateCastBar(frame, unit)
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
            frame:SetAlpha(Clamp(edb.alpha or 1, 0.1, 1))
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
                        frame:SetAlpha(v)
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
    local function add(s) lines[#lines + 1] = s end

    add("=== Nameplates Debug Report ===")
    add("")

    -- DB snapshot
    add("--- DB ---")
    local db = self:GetDB()
    if db then
        local keys = {
            "enabled", "width", "height", "alpha", "scale",
            "healthColorMode", "healthFont", "healthFontSize", "healthFontFlags",
            "healthFormat", "healthTextAnchor", "showAbsorb",
            "castFont", "castFontSize", "castHeight",
            "nameFont", "nameFontSize", "nameFontFlags",
            "showLevel", "showEliteIcon", "showTargetGlow", "showTargetArrow",
            "showThreat", "showAuras", "auraSize", "auraMax", "auraOnlyMine",
        }
        for _, k in ipairs(keys) do
            local ok, v = pcall(function() return db[k] end)
            local vs
            if not ok then
                vs = "<tainted>"
            else
                local tok, ts = pcall(tostring, v)
                vs = (tok and type(ts) == "string") and ts or "<secret>"
            end
            add(string.format("  %-28s = %s", k, vs))
        end
    else
        add("  DB unavailable")
    end
    add("")

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

    -- Plate count
    local total, visible = 0, 0
    for _, frame in pairs(self._plates) do
        total = total + 1
        pcall(function() if frame and frame:IsShown() then visible = visible + 1 end end)
    end
    add(string.format("--- Plates: %d tracked / %d visible ---", total, visible))

    -- First visible plate detail.
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
            add(string.format("  sample unit : %s", tostring(unit)))
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
            if frame.castBar then
                safeGet("  castBar", function()
                    local cb = frame.castBar
                    return string.format("  castBar     : IsShown=%s", tostring(cb:IsShown()))
                end)
            end
            break
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
                local v = logLines[i]
                if type(v) == "string" then
                    add(v)
                else
                    local ok, s = pcall(tostring, v)
                    add((ok and type(s) == "string") and s or "<secret>")
                end
            end
        end
    end

    -- Safe concat: guard against any secrets that slipped into the lines table.
    local out = {}
    for i, v in ipairs(lines) do
        if type(v) == "string" then
            out[i] = v
        else
            local ok, s = pcall(tostring, v)
            out[i] = (ok and type(s) == "string") and s or "<secret@" .. tostring(i) .. ">"
        end
    end
    return table.concat(out, "\n")
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
