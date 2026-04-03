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
local C_Timer = _G.C_Timer
local InCombatLockdown = _G.InCombatLockdown
local SecureHandlerSetFrameRef = _G.SecureHandlerSetFrameRef
local UIParent = _G.UIParent
local CheckInteractDistance = _G.CheckInteractDistance
local UnitExists = _G.UnitExists
local UnitClass = _G.UnitClass
local UnitInRange = _G.UnitInRange
local UnitInParty = _G.UnitInParty
local UnitInRaid = _G.UnitInRaid
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local StatusBarInterpolation = (_G.Enum and _G.Enum.StatusBarInterpolation) or _G.StatusBarInterpolation
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local C_UnitAuras = _G.C_UnitAuras
local C_Spell = _G.C_Spell
local issecretvalue = _G.issecretvalue or function() return false end
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local math_floor = math.floor
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi

local FRIENDLY_RANGE_SPELLS = {
    DEATHKNIGHT = { 47541 },
    DEMONHUNTER = {},
    DRUID = { 8936 },
    EVOKER = { 355913 },
    HUNTER = {},
    MAGE = { 1459 },
    MONK = { 116670 },
    PALADIN = { 85673 },
    PRIEST = { 17, 2050 },
    ROGUE = { 36554, 921 },
    SHAMAN = { 8004 },
    WARLOCK = { 5697 },
    WARRIOR = {},
}

local RESURRECT_RANGE_SPELLS = {
    DEATHKNIGHT = { 61999 },
    DEMONHUNTER = {},
    DRUID = { 50769 },
    EVOKER = { 361227 },
    HUNTER = {},
    MAGE = {},
    MONK = { 115178 },
    PALADIN = { 7328 },
    PRIEST = { 2006 },
    ROGUE = {},
    SHAMAN = { 2008 },
    WARLOCK = { 20707 },
    WARRIOR = {},
}

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

local function UFDiagnosticsVerboseEnabled(self)
    if not (self and type(self.GetUFDiagnosticsConfig) == "function") then
        return false
    end

    local cfg = self:GetUFDiagnosticsConfig()
    return cfg and cfg.enabled == true and cfg.verbose == true
end

local function UFDebugVerbose(self, msg)
    if UFDiagnosticsVerboseEnabled(self) then
        UFDebug(msg)
    end
end

function UnitFrames:GetUFDiagnosticsMemoryKB()
    if type(_G.UpdateAddOnMemoryUsage) == "function" then
        _G.UpdateAddOnMemoryUsage()
    end

    if type(_G.GetAddOnMemoryUsage) == "function" then
        local value = _G.GetAddOnMemoryUsage("TwichUI_Reformed")
        if type(value) == "number" then
            return value
        end
    end

    if type(collectgarbage) == "function" then
        local ok, value = pcall(collectgarbage, "count")
        if ok and type(value) == "number" then
            return value
        end
    end

    return 0
end

function UnitFrames:GetUFDiagnosticsConfig()
    local db = self:GetDB()
    db.debug = db.debug or {}
    db.debug.unitFramesDiagnostics = db.debug.unitFramesDiagnostics or {}
    local cfg = db.debug.unitFramesDiagnostics

    if cfg.enabled == nil then cfg.enabled = false end
    if cfg.intervalSec == nil then cfg.intervalSec = 2 end
    if cfg.minMemoryDeltaKB == nil then cfg.minMemoryDeltaKB = 512 end
    if cfg.verbose == nil then cfg.verbose = false end

    cfg.intervalSec = math_max(0.5, math_min(30, tonumber(cfg.intervalSec) or 2))
    cfg.minMemoryDeltaKB = math_max(0, math_min(1024 * 50, tonumber(cfg.minMemoryDeltaKB) or 512))

    return cfg
end

function UnitFrames:IsUFDiagnosticsEnabled()
    return self._ufDiagEnabled == true
end

function UnitFrames:ResetUFDiagnosticsRuntime()
    local now = (_G.GetTimePreciseSec or _G.GetTime)()
    local memoryKB = self:GetUFDiagnosticsMemoryKB()
    self._ufDiagRuntime = {
        startedAt = now,
        lastReportAt = now,
        lastMemoryKB = memoryKB,
        peakMemoryKB = memoryKB,
        total = {},
        window = {},
        peaks = {},
    }
end

function UnitFrames:SetUFDiagnosticsEnabled(enabled, silent)
    local cfg = self:GetUFDiagnosticsConfig()
    local nextState = enabled == true
    cfg.enabled = nextState
    self._ufDiagEnabled = nextState

    if nextState then
        self:ResetUFDiagnosticsRuntime()
        if silent ~= true then
            UFDebug("UFDiagnostics: enabled")
            self:UFDiagMaybeReport("enable", true)
        end
    else
        if silent ~= true then
            UFDebug("UFDiagnostics: disabled")
        end
        self._ufDiagRuntime = nil
        self._auraTimingDebugSeen = nil
        self._auraTimingDebugSeenCount = nil
    end
end

function UnitFrames:RefreshUFDiagnosticsState()
    local cfg = self:GetUFDiagnosticsConfig()
    self._ufDiagEnabled = cfg.enabled == true
    if self._ufDiagEnabled then
        if not self._ufDiagRuntime then
            self:ResetUFDiagnosticsRuntime()
        end
    else
        self._ufDiagRuntime = nil
        self._auraTimingDebugSeen = nil
        self._auraTimingDebugSeenCount = nil
    end
end

function UnitFrames:SetUFDiagnosticsInterval(intervalSec)
    local cfg = self:GetUFDiagnosticsConfig()
    cfg.intervalSec = math_max(0.5, math_min(30, tonumber(intervalSec) or 2))
end

function UnitFrames:SetUFDiagnosticsMemoryDelta(minDeltaKB)
    local cfg = self:GetUFDiagnosticsConfig()
    cfg.minMemoryDeltaKB = math_max(0, math_min(1024 * 50, tonumber(minDeltaKB) or 512))
end

function UnitFrames:SetUFDiagnosticsVerbose(enabled)
    local cfg = self:GetUFDiagnosticsConfig()
    cfg.verbose = enabled == true
end

function UnitFrames:UFDiagBump(counterKey, amount)
    if self._ufDiagEnabled ~= true then
        return
    end

    local runtime = self._ufDiagRuntime
    if not runtime then
        self:ResetUFDiagnosticsRuntime()
        runtime = self._ufDiagRuntime
    end

    local delta = amount or 1
    runtime.total[counterKey] = (runtime.total[counterKey] or 0) + delta
    runtime.window[counterKey] = (runtime.window[counterKey] or 0) + delta
end

function UnitFrames:UFDiagSetPeak(peakKey, value)
    if self._ufDiagEnabled ~= true then
        return
    end

    local runtime = self._ufDiagRuntime
    if not runtime then
        self:ResetUFDiagnosticsRuntime()
        runtime = self._ufDiagRuntime
    end

    local numeric = tonumber(value)
    if not numeric then
        return
    end

    local previous = runtime.peaks[peakKey]
    if not previous or numeric > previous then
        runtime.peaks[peakKey] = numeric
    end
end

function UnitFrames:UFDiagGetStatusLine()
    local cfg = self:GetUFDiagnosticsConfig()
    local runtime = self._ufDiagRuntime
    local memoryKB = runtime and runtime.lastMemoryKB or self:GetUFDiagnosticsMemoryKB()
    return string.format(
        "UFDiagnostics: enabled=%s interval=%.1fs delta=%dkb verbose=%s mem=%.1fmb",
        tostring(cfg.enabled == true),
        tonumber(cfg.intervalSec) or 2,
        math_floor((tonumber(cfg.minMemoryDeltaKB) or 512) + 0.5),
        tostring(cfg.verbose == true),
        (tonumber(memoryKB) or 0) / 1024
    )
end

function UnitFrames:UFDiagMaybeReport(reason, force)
    if self._ufDiagEnabled ~= true then
        return
    end

    local runtime = self._ufDiagRuntime
    if not runtime then
        self:ResetUFDiagnosticsRuntime()
        runtime = self._ufDiagRuntime
    end

    local cfg = self:GetUFDiagnosticsConfig()
    local now = (_G.GetTimePreciseSec or _G.GetTime)()
    local elapsed = now - (runtime.lastReportAt or now)
    local minInterval = tonumber(cfg.intervalSec) or 2
    if force ~= true and elapsed < minInterval then
        return
    end

    local memoryKB = self:GetUFDiagnosticsMemoryKB()
    local memoryDeltaKB = memoryKB - (runtime.lastMemoryKB or memoryKB)
    runtime.lastMemoryKB = memoryKB
    runtime.lastReportAt = now
    if memoryKB > (runtime.peakMemoryKB or 0) then
        runtime.peakMemoryKB = memoryKB
    end

    local absDeltaKB = math_abs(memoryDeltaKB)
    local shouldLog = force == true or cfg.verbose == true or absDeltaKB >= (tonumber(cfg.minMemoryDeltaKB) or 512)
    if not shouldLog then
        wipe(runtime.window)
        return
    end

    local window = runtime.window or {}
    UFDebug(string.format(
        "UFDiagnostics[%s]: dt=%.2fs mem=%.2fmb delta=%+.1fkb peak=%.2fmb",
        tostring(reason or "tick"),
        elapsed,
        memoryKB / 1024,
        memoryDeltaKB,
        (runtime.peakMemoryKB or memoryKB) / 1024
    ))
    UFDebug(string.format(
        "UFDiagnostics counters: awUpdate=%d awScanCalls=%d awSlots=%d awResults=%d auraBars=%d castTicks=%d castEvents=%d castStart=%d castStop=%d",
        window.awUpdateCalls or 0,
        window.awScanCalls or 0,
        window.awSlotsScanned or 0,
        window.awAurasReturned or 0,
        window.auraBarRefreshCalls or 0,
        window.castbarUpdateTicks or 0,
        window.castEvents or 0,
        window.castStarts or 0,
        window.castStops or 0
    ))
    UFDebug(string.format(
        "UFDiagnostics peaks: auraBarsVisible=%d awIndicatorsActive=%d",
        runtime.peaks.auraBarsVisible or 0,
        runtime.peaks.awIndicatorsActive or 0
    ))

    wipe(runtime.window)
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

local function ReadSafeUnitGUID(unit)
    if not unit or unit == "" then
        return nil
    end

    local okGuid, guid = pcall(UnitGUID, unit)
    if not okGuid or guid == nil then
        return nil
    end

    if issecretvalue and issecretvalue(guid) then
        return nil
    end

    return guid
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
    if not UFDiagnosticsVerboseEnabled(self) then
        return
    end

    self._auraTimingDebugSeen = self._auraTimingDebugSeen or {}
    self._auraTimingDebugSeenCount = self._auraTimingDebugSeenCount or 0
    if self._auraTimingDebugSeenCount > 1024 then
        self._auraTimingDebugSeen = {}
        self._auraTimingDebugSeenCount = 0
    end

    local key = BuildAuraTimingDebugKey(contextKey, unit, auraData, reason)
    if self._auraTimingDebugSeen[key] then return end
    self._auraTimingDebugSeen[key] = true
    self._auraTimingDebugSeenCount = self._auraTimingDebugSeenCount + 1

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

function UnitFrames:ResolveAuraTiming(unit, auraData, contextKey, buffer)
    local timing = buffer or {
        duration = 0, expirationTime = 0, applications = 0, durationObject = nil,
    }
    timing.duration       = ReadAuraNumber(auraData and auraData.duration) or 0
    timing.expirationTime = ReadAuraNumber(auraData and auraData.expirationTime) or 0
    timing.applications   = ReadAuraNumber(auraData and auraData.applications) or 0
    timing.durationObject = nil

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
            if not (issecretvalue and issecretvalue(remaining)) and type(remaining) == "number" and remaining > 0 then
                return true
            end
        end
    end

    return expirationTime and expirationTime > 0 and duration and duration > 0
end

local function IsGroupMemberAuraUnitKey(unitKey)
    return unitKey == "partyMember" or unitKey == "raidMember" or unitKey == "tankMember"
end

function UnitFrames:GetHelpfulAuraPromotionLookup()
    local specKey = self.AWGetSpecKey and self:AWGetSpecKey() or nil
    local cache = self._helpfulAuraPromotionCache
    if cache and cache.specKey == specKey and cache.lookup and cache.nameLookup then
        return cache.lookup, cache.nameLookup
    end

    local lookup = {}
    local nameLookup = {}
    if specKey and self.AWGetSpecCatalog then
        local catalog = self:AWGetSpecCatalog(specKey) or {}
        for _, entry in ipairs(catalog) do
            if entry and entry.promoteHelpful == true and type(entry.spellIds) == "table" then
                if type(entry.display) == "string" and entry.display ~= "" then
                    nameLookup[entry.display] = true
                end

                for _, rawSpellId in ipairs(entry.spellIds) do
                    local spellId = tonumber(rawSpellId)
                    if spellId and spellId > 0 then
                        lookup[spellId] = true

                        local spellName = nil
                        if C_Spell and C_Spell.GetSpellName then
                            local okSpellName, resolvedName = pcall(C_Spell.GetSpellName, spellId)
                            if okSpellName and type(resolvedName) == "string" and resolvedName ~= "" then
                                spellName = resolvedName
                            end
                        end
                        if not spellName and _G.GetSpellInfo then
                            local okLegacyName, legacyName = pcall(_G.GetSpellInfo, spellId)
                            if okLegacyName and type(legacyName) == "string" and legacyName ~= "" then
                                spellName = legacyName
                            end
                        end
                        if spellName then
                            nameLookup[spellName] = true
                        end
                    end
                end
            end
        end
    end

    self._helpfulAuraPromotionCache = {
        specKey = specKey,
        lookup = lookup,
        nameLookup = nameLookup,
    }

    return lookup, nameLookup
end

function UnitFrames:IsPromotedHelpfulAura(data)
    if not data then
        return false
    end

    local spellLookup, nameLookup = self:GetHelpfulAuraPromotionLookup()

    local okSpellId, spellId = pcall(function()
        if data.spellId == nil or (issecretvalue and issecretvalue(data.spellId)) then
            return nil
        end

        return tonumber(data.spellId)
    end)

    if okSpellId and type(spellId) == "number" and spellId > 0 and spellLookup[spellId] == true then
        return true
    end

    local okName, auraName = pcall(function()
        if data.name == nil or (issecretvalue and issecretvalue(data.name)) then
            return nil
        end

        return tostring(data.name)
    end)

    return okName and type(auraName) == "string" and auraName ~= "" and nameLookup[auraName] == true
end

function UnitFrames:PopulateHelpfulAuraMetadata(unit, data, timing, unitKey, onlyMine)
    if not data or data.isHarmfulAura == true then
        return data
    end

    timing = timing or self:ResolveAuraTiming(unit, data, "icons")
    local promoted = self:IsPromotedHelpfulAura(data) == true
    local stacks = tonumber(timing and timing.applications) or 0
    local isTransient = stacks > 1
        or self:ShouldUseAuraTimerFill(
            timing and timing.durationObject,
            timing and timing.expirationTime,
            timing and timing.duration
        )

    data.twichPromotedHelpful = promoted
    data.twichTransientHelpful = isTransient

    if promoted then
        data.twichKeepHelpful = true
    elseif IsGroupMemberAuraUnitKey(unitKey) then
        data.twichKeepHelpful = isTransient
    elseif onlyMine == true then
        data.twichKeepHelpful = isTransient
    else
        data.twichKeepHelpful = true
    end

    return data
end

function UnitFrames:GetHelpfulAuraSortPriority(data)
    if not data or data.isHarmfulAura == true then
        return 0
    end

    if data.twichPromotedHelpful == true then
        return 300
    end

    if data.isPlayerAura == true then
        return 200
    end

    if data.twichTransientHelpful == true then
        return 100
    end

    return 0
end

function UnitFrames:ShouldKeepGenericHelpfulAura(unit, data, timing, onlyMine, unitKey)
    self:PopulateHelpfulAuraMetadata(unit, data, timing, unitKey, onlyMine)

    if not data or not timing then
        return false
    end

    return data.twichKeepHelpful == true
end

function UnitFrames:UpdateAuraRemainingText(fs, durationObject, expirationTime, duration)
    if not fs then return false end

    local function SetIfChanged(text)
        text = text or ""
        if fs._twichAuraTimeText == text then
            return
        end

        fs._twichAuraTimeText = text
        fs:SetText(text)
    end

    if durationObject and durationObject.GetRemainingDuration then
        local okRemaining, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
        if okRemaining and remaining ~= nil then
            if issecretvalue and issecretvalue(remaining) then
                fs:SetFormattedText("%.1f", remaining)
                fs._twichAuraTimeText = nil
                return true
            end

            if type(remaining) == "number" then
                remaining = math_max(0, remaining)
                if remaining <= 0 then
                    SetIfChanged("")
                    return false
                end
                SetIfChanged(self:FormatAuraRemainingTime(remaining))
                return true
            end
        end
    end

    local remaining = self:GetAuraRemainingTime(nil, expirationTime, duration)
    if remaining <= 0 then
        SetIfChanged("")
        return false
    end

    SetIfChanged(self:FormatAuraRemainingTime(remaining))
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
    local powerType, powerToken = _G.UnitPowerType(unit)
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

local PLAYER_CLASS_ARTWORKS = {
    PALADIN = {
        texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Paladin",
        width = 250,
        height = 233,
    },
}

local function RoundToNearestInteger(value)
    local numeric = tonumber(value) or 0
    if numeric >= 0 then
        return math_floor(numeric + 0.5)
    end

    return math_floor(numeric - 0.5)
end

local function GetPlayerClassArtworkDefinition()
    local _, classToken = UnitClass("player")
    if not classToken then
        return nil
    end

    return PLAYER_CLASS_ARTWORKS[classToken]
end

local RANGE_FADE_UNIT_KEYS = {
    partyMember = true,
    raidMember = true,
    tankMember = true,
}

function UnitFrames:GetDistanceFadeConfig()
    local db = self:GetDB()
    if type(db.distanceFade) ~= "table" then
        db.distanceFade = {}
    end

    if db.distanceFade.enabled == nil then
        db.distanceFade.enabled = false
    end
    if db.distanceFade.outsideAlpha == nil then
        db.distanceFade.outsideAlpha = 0.45
    end

    return db.distanceFade
end

function UnitFrames:GetBaseFrameAlpha()
    return Clamp(self:GetDB().frameAlpha or 1, 0.15, 1)
end

function UnitFrames:ShouldUseDistanceFade(unitKey)
    return RANGE_FADE_UNIT_KEYS[unitKey] == true
end

function UnitFrames:ResetRangeSpellCache()
    self._activeRangeSpellCache = nil
end

function UnitFrames:IsRangeCheckSpellKnown(spellID)
    if type(spellID) ~= "number" then
        return false
    end

    if _G.C_SpellBook and type(_G.C_SpellBook.IsSpellInSpellBook) == "function" then
        local okKnown, isKnown = pcall(_G.C_SpellBook.IsSpellInSpellBook, spellID)
        if okKnown and isKnown then
            return true
        end
    end

    return false
end

function UnitFrames:GetActiveRangeSpellList(bucket)
    local _, classToken = UnitClass("player")
    if not classToken then
        return nil
    end

    self._activeRangeSpellCache = self._activeRangeSpellCache or {}
    local cacheKey = table.concat({ classToken, bucket or "friendly" }, ":")
    local cached = self._activeRangeSpellCache[cacheKey]
    if cached then
        return cached
    end

    local source = (bucket == "resurrect" and RESURRECT_RANGE_SPELLS[classToken]) or FRIENDLY_RANGE_SPELLS[classToken] or
        {}
    local spells = {}
    for _, spellID in ipairs(source) do
        if self:IsRangeCheckSpellKnown(spellID) then
            spells[#spells + 1] = spellID
        end
    end

    self._activeRangeSpellCache[cacheKey] = spells
    return spells
end

function UnitFrames:UnitInConfiguredSpellRange(unit, bucket)
    if not unit or not C_Spell or type(C_Spell.IsSpellInRange) ~= "function" then
        return nil
    end

    local spells = self:GetActiveRangeSpellList(bucket)
    if type(spells) ~= "table" or #spells == 0 then
        return nil
    end

    local hadCheckedResult = false
    for _, spellID in ipairs(spells) do
        local okRange, range = pcall(C_Spell.IsSpellInRange, spellID, unit)
        if okRange and not (issecretvalue and issecretvalue(range)) and range ~= nil then
            if range == true or range == 1 then
                return true
            end

            hadCheckedResult = true
        end
    end

    if hadCheckedResult then
        return false
    end

    return nil
end

function UnitFrames:GetFriendlyUnitAssistState(unit)
    if not unit or not UnitExists(unit) then
        return nil, false
    end

    if type(_G.UnitPhaseReason) == "function" then
        local okPhase, phaseReason = pcall(_G.UnitPhaseReason, unit)
        if okPhase and not (issecretvalue and issecretvalue(phaseReason)) and phaseReason ~= nil then
            return false, true
        end
    end

    if type(_G.UnitCanAssist) == "function" then
        local okAssist, canAssist = pcall(_G.UnitCanAssist, "player", unit)
        if okAssist and not (issecretvalue and issecretvalue(canAssist)) and canAssist ~= nil then
            return canAssist == true or canAssist == 1, true
        end
    end

    return nil, false
end

function UnitFrames:GetFriendlyUnitRangeState(unit)
    if not unit or not UnitExists(unit) then
        return nil, false
    end

    local canAssist, assistChecked = self:GetFriendlyUnitAssistState(unit)
    if assistChecked and canAssist == false then
        return false, true
    end

    local okRange, inRange, wasChecked = pcall(UnitInRange, unit)
    if okRange and not (issecretvalue and issecretvalue(wasChecked)) and wasChecked ~= nil then
        if wasChecked == true or wasChecked == 1 then
            if not (issecretvalue and issecretvalue(inRange)) and inRange ~= nil then
                return (inRange == true or inRange == 1), true
            end
        end
    end

    local spellBucket = (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost(unit)) and "resurrect" or "friendly"
    local spellRange = self:UnitInConfiguredSpellRange(unit, spellBucket)
    if spellRange ~= nil then
        return spellRange, true
    end

    if not InCombatLockdown() and type(CheckInteractDistance) == "function" then
        local okInteract, interactInRange = pcall(CheckInteractDistance, unit, 4)
        if okInteract and not (issecretvalue and issecretvalue(interactInRange)) and interactInRange ~= nil then
            return interactInRange == true or interactInRange == 1, true
        end
    end

    return nil, false
end

function UnitFrames:ForceRangeFadeUpdate(frame)
    if not frame or not frame.Range then
        return
    end

    if frame.Range and type(frame.Range.ForceUpdate) == "function" then
        frame.Range:ForceUpdate()
    elseif type(frame.UpdateAllElements) == "function" then
        frame:UpdateAllElements("ForceUpdate")
    end
end

function UnitFrames:RegisterRangeFadeEvents(frame)
    if not frame or frame._twichRangeFadeEventsRegistered then
        return
    end

    frame._twichRangeFadeEventHandler = function(owner, _, unit)
        if unit and owner and owner.unit and unit ~= owner.unit then
            return
        end

        UnitFrames:ForceRangeFadeUpdate(owner)
    end

    frame:RegisterEvent("UNIT_PHASE", frame._twichRangeFadeEventHandler)
    frame:RegisterEvent("UNIT_FLAGS", frame._twichRangeFadeEventHandler)
    frame._twichRangeFadeEventsRegistered = true
end

function UnitFrames:ConfigureRangeFade(frame, unitKey)
    if not frame then
        return
    end

    local baseAlpha = self:GetBaseFrameAlpha()
    local distanceFade = self:GetDistanceFadeConfig()
    local shouldEnable = distanceFade.enabled == true and frame._isTestPreview ~= true and
        self:ShouldUseDistanceFade(unitKey)

    if not frame.Range then
        frame.Range = {}
    end

    frame.Range.insideAlpha = baseAlpha
    frame.Range.outsideAlpha = Clamp(math_min(baseAlpha, tonumber(distanceFade.outsideAlpha) or 0.45), 0.05, 1)
    frame.Range.Override = function(owner)
        local element = owner.Range
        local unit = owner.unit
        local inRange = nil
        local isEligible = false

        if unit and UnitExists(unit) and not (_G.UnitIsUnit and _G.UnitIsUnit(unit, "player")) and
            (not _G.UnitIsConnected or _G.UnitIsConnected(unit)) then
            inRange, isEligible = UnitFrames:GetFriendlyUnitRangeState(unit)
        end

        owner:SetAlpha(isEligible and (inRange and element.insideAlpha or element.outsideAlpha) or element.insideAlpha)

        if element.PostUpdate then
            return element:PostUpdate(owner, inRange, isEligible)
        end
    end

    if type(frame.EnableElement) ~= "function" or type(frame.DisableElement) ~= "function" or
        type(frame.IsElementEnabled) ~= "function" then
        frame:SetAlpha(baseAlpha)
        return
    end

    self:RegisterRangeFadeEvents(frame)

    if shouldEnable then
        if not frame:IsElementEnabled("Range") then
            frame:EnableElement("Range")
        end
        if frame.Range and type(frame.Range.ForceUpdate) == "function" then
            frame.Range:ForceUpdate()
        else
            frame:UpdateAllElements("ForceUpdate")
        end
    else
        if frame:IsElementEnabled("Range") then
            frame:DisableElement("Range")
        end
        frame:SetAlpha(baseAlpha)
    end
end

local function ResolveFrameUnit(frame)
    if type(frame) ~= "table" then
        return nil
    end

    return frame:GetAttribute("unit") or frame.unit
end

local function NormalizeHeaderFilterValue(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == "" then
        return nil
    end

    return trimmed
end

local VALID_GROWTH_DIRECTIONS = {
    UP = true,
    DOWN = true,
    LEFT = true,
    RIGHT = true,
}

local MAX_BOSS_FRAMES = 5

local VALID_HEADER_POINTS = {
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
}

local function NormalizeGrowthDirection(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = value:match("^%s*(.-)%s*$")
    local upper = trimmed and trimmed:upper() or nil
    if upper and VALID_GROWTH_DIRECTIONS[upper] then
        return upper
    end

    return nil
end

local function NormalizeHeaderPointValue(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = value:match("^%s*(.-)%s*$")
    local upper = trimmed and trimmed:upper() or nil
    if upper and VALID_HEADER_POINTS[upper] then
        return upper
    end

    return nil
end

local function DeriveGrowthDirectionFromPoint(point, fallback)
    local normalized = NormalizeHeaderPointValue(point)
    if normalized == "BOTTOM" then
        return "UP"
    elseif normalized == "TOP" then
        return "DOWN"
    elseif normalized == "RIGHT" then
        return "LEFT"
    elseif normalized == "LEFT" then
        return "RIGHT"
    end

    if type(point) == "string" then
        local upper = point:upper()
        if upper:find("BOTTOM", 1, true) then
            return "UP"
        elseif upper:find("TOP", 1, true) then
            return "DOWN"
        elseif upper:find("RIGHT", 1, true) then
            return "LEFT"
        elseif upper:find("LEFT", 1, true) then
            return "RIGHT"
        end
    end

    return NormalizeGrowthDirection(fallback) or "DOWN"
end

local function ResolveGroupGrowthDirection(settings, fallback)
    if type(settings) == "table" then
        local direction = NormalizeGrowthDirection(settings.growthDirection)
        if direction then
            return direction
        end

        return DeriveGrowthDirectionFromPoint(settings.point, fallback)
    end

    return NormalizeGrowthDirection(fallback) or "DOWN"
end

local function IsHorizontalGrowthDirection(direction)
    return direction == "LEFT" or direction == "RIGHT"
end

local function ResolveHeaderPoint(settings, fallback)
    local direction = ResolveGroupGrowthDirection(settings, DeriveGrowthDirectionFromPoint(fallback, "DOWN"))

    if direction == "UP" then
        return "BOTTOM"
    elseif direction == "LEFT" then
        return "RIGHT"
    elseif direction == "RIGHT" then
        return "LEFT"
    end

    return "TOP"
end

local function ResolveHeaderColumnAnchorPoint(settings, growthDirection, fallback)
    local columnAnchor = NormalizeHeaderPointValue(settings and settings.columnAnchorPoint)
        or NormalizeHeaderPointValue(fallback)

    if IsHorizontalGrowthDirection(growthDirection) then
        if columnAnchor == "TOP" or columnAnchor == "BOTTOM" then
            return columnAnchor
        end

        return "TOP"
    end

    if columnAnchor == "LEFT" or columnAnchor == "RIGHT" then
        return columnAnchor
    end

    return "LEFT"
end

local function ResolveGroupRowSpacing(settings, fallback)
    if type(settings) == "table" and settings.rowSpacing ~= nil then
        return math_abs(tonumber(settings.rowSpacing) or fallback or 6)
    end

    if type(settings) == "table" and settings.yOffset ~= nil then
        return math_abs(tonumber(settings.yOffset) or fallback or 6)
    end

    return math_abs(fallback or 6)
end

local function ResolveHeaderXOffset(settings, growthDirection, fallback)
    local direction = growthDirection or ResolveGroupGrowthDirection(settings, "DOWN")
    if not IsHorizontalGrowthDirection(direction) then
        return 0
    end

    local spacing = math_abs(tonumber(settings and settings.xOffset) or fallback or 0)
    if direction == "LEFT" then
        return -spacing
    end

    return spacing
end

local function ResolveHeaderYOffset(settings, fallback, growthDirection)
    local direction = growthDirection or ResolveGroupGrowthDirection(settings, "DOWN")
    if IsHorizontalGrowthDirection(direction) then
        return 0
    end

    local spacing = ResolveGroupRowSpacing(settings, fallback)
    if direction == "UP" then
        return spacing
    end

    return -spacing
end

local function GetDirectionalStep(direction, width, height, spacing)
    local gap = math_max(0, tonumber(spacing) or 0)

    if direction == "UP" then
        return 0, -(height + gap)
    elseif direction == "DOWN" then
        return 0, height + gap
    elseif direction == "LEFT" then
        return -(width + gap), 0
    end

    return width + gap, 0
end

local function BuildGroupGeometry(settings, width, height, rows, cols, rowSpacingFallback, columnSpacingFallback,
                                  defaultGrowthDirection, defaultColumnAnchorPoint)
    local growthDirection = ResolveGroupGrowthDirection(settings, defaultGrowthDirection or "DOWN")
    local columnAnchorPoint = ResolveHeaderColumnAnchorPoint(settings, growthDirection, defaultColumnAnchorPoint)
    local secondaryDirection = DeriveGrowthDirectionFromPoint(columnAnchorPoint,
        IsHorizontalGrowthDirection(growthDirection) and "DOWN" or "RIGHT")
    local primarySpacing = IsHorizontalGrowthDirection(growthDirection)
        and math_abs(tonumber(settings and settings.xOffset) or 0)
        or ResolveGroupRowSpacing(settings, rowSpacingFallback or 6)
    local secondarySpacing = math_max(0, tonumber(settings and settings.columnSpacing) or columnSpacingFallback or 6)
    local primaryDx, primaryDy = GetDirectionalStep(growthDirection, width, height, primarySpacing)
    local secondaryDx, secondaryDy = GetDirectionalStep(secondaryDirection, width, height, secondarySpacing)
    local geometry = {
        rows = math_max(1, tonumber(rows) or 1),
        cols = math_max(1, tonumber(cols) or 1),
        growthDirection = growthDirection,
        columnAnchorPoint = columnAnchorPoint,
        primaryDx = primaryDx,
        primaryDy = primaryDy,
        secondaryDx = secondaryDx,
        secondaryDy = secondaryDy,
        minX = 0,
        maxX = 0,
        minY = 0,
        maxY = 0,
        width = width,
        height = height,
    }

    for index = 1, geometry.rows * geometry.cols do
        local primaryIndex = (index - 1) % geometry.rows
        local secondaryIndex = math.floor((index - 1) / geometry.rows)
        local x = (secondaryIndex * geometry.secondaryDx) + (primaryIndex * geometry.primaryDx)
        local y = (secondaryIndex * geometry.secondaryDy) + (primaryIndex * geometry.primaryDy)

        if x < geometry.minX then geometry.minX = x end
        if x > geometry.maxX then geometry.maxX = x end
        if y < geometry.minY then geometry.minY = y end
        if y > geometry.maxY then geometry.maxY = y end
    end

    geometry.width = (geometry.maxX - geometry.minX) + width
    geometry.height = (geometry.maxY - geometry.minY) + height

    return geometry
end

local function GetGroupGeometryOffset(geometry, index)
    local primaryIndex = (index - 1) % geometry.rows
    local secondaryIndex = math.floor((index - 1) / geometry.rows)
    local x = (secondaryIndex * geometry.secondaryDx) + (primaryIndex * geometry.primaryDx) - geometry.minX
    local y = (secondaryIndex * geometry.secondaryDy) + (primaryIndex * geometry.primaryDy) - geometry.minY
    return x, y
end

local function ResolveGroupCountCaps(groupKey)
    if groupKey == "party" then
        return 5, 5
    elseif groupKey == "tank" then
        return 8, 4
    elseif groupKey == "raid" then
        return 8, 8
    end

    return 8, 8
end

local function ResolveGroupHeaderCounts(groupKey, settings, defaultRows, defaultCols)
    local maxRows, maxCols = ResolveGroupCountCaps(groupKey)
    local rows = math_max(1, math_min(maxRows, tonumber(settings and settings.unitsPerColumn) or defaultRows or 1))
    local cols = math_max(1, math_min(maxCols, tonumber(settings and settings.maxColumns) or defaultCols or 1))
    return rows, cols
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


local function ResolveBossGeometry(settings, width, height, frameCount)
    local count = math_max(1, math_min(MAX_BOSS_FRAMES, tonumber(frameCount) or MAX_BOSS_FRAMES))
    local rows = math_max(1, math_min(count, tonumber(settings and settings.unitsPerColumn) or count))
    local cols = math_max(1, math.ceil(count / rows))

    return BuildGroupGeometry(settings, width, height, rows, cols, 8, 8, "DOWN", "LEFT")
end

local function GetBossFrameOffset(geometry, index)
    local resolvedIndex = math_max(1, math_min(index, geometry.rows * geometry.cols))
    return GetGroupGeometryOffset(geometry, resolvedIndex)
end

local function CountActiveBossUnits()
    local count = 0
    for index = 1, MAX_BOSS_FRAMES do
        if UnitExists("boss" .. index) then
            count = count + 1
        end
    end

    return count
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

local STATE_ICON_TEXTURE = "Interface\\CharacterFrame\\UI-StateIcon"

local STANDARD_STATE_TEXTURES = {
    combat = { texture = STATE_ICON_TEXTURE, texCoord = { 0.5, 1, 0, 0.49 }, width = 32, height = 32 },
    resting = { texture = STATE_ICON_TEXTURE, texCoord = { 0, 0.5, 0, 0.421875 }, width = 32, height = 27 },
    spirit = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Spirit", width = 64, height = 64 },
}

local TWICH_STATE_TEXTURES = {
    combat = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Combat", width = 64, height = 70 },
    resting = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Resting", width = 64, height = 63 },
    spirit = { texture = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Spirit", width = 64, height = 64 },
}

local READY_CHECK_ART = {
    standard = {
        ready = { atlas = "UI-LFG-ReadyMark-Raid", width = 1, height = 1 },
        notready = { atlas = "UI-LFG-DeclineMark-Raid", width = 1, height = 1 },
        waiting = { atlas = "UI-LFG-PendingMark-Raid", width = 1, height = 1 },
    },
    legacy = {
        ready = { texture = "Interface\\RaidFrame\\ReadyCheck-Ready", width = 32, height = 32 },
        notready = { texture = "Interface\\RaidFrame\\ReadyCheck-NotReady", width = 32, height = 32 },
        waiting = { texture = "Interface\\RaidFrame\\ReadyCheck-Waiting", width = 32, height = 32 },
    },
}

local STATE_INDICATOR_DEFS = {
    combatIndicator = {
        stateKey = "combat",
        hostKey = "TwichCombatIndicatorHost",
        textureKey = "TwichCombatIndicator",
        defaultPoint = "CENTER",
        defaultRelativePoint = "TOP",
        defaultOffsetX = 0,
        defaultOffsetY = 10,
        defaultSize = 20,
        defaultAlpha = 1,
    },
    restingIndicator = {
        stateKey = "resting",
        hostKey = "TwichRestingIndicatorHost",
        textureKey = "TwichRestingIndicator",
        defaultPoint = "CENTER",
        defaultRelativePoint = "TOPLEFT",
        defaultOffsetX = -2,
        defaultOffsetY = 8,
        defaultSize = 18,
        defaultAlpha = 1,
    },
    spiritIndicator = {
        stateKey = "spirit",
        hostKey = "TwichSpiritIndicatorHost",
        textureKey = "TwichSpiritIndicator",
        defaultPoint = "CENTER",
        defaultRelativePoint = "CENTER",
        defaultOffsetX = 0,
        defaultOffsetY = 0,
        defaultSize = 24,
        defaultAlpha = 0.9,
    },
}

local READY_CHECK_INDICATOR_DEF = {
    hostKey = "TwichReadyCheckIndicatorHost",
    textureKey = "TwichReadyCheckIndicator",
    defaultPoint = "TOP",
    defaultRelativePoint = "TOP",
    defaultOffsetX = 0,
    defaultOffsetY = 8,
    defaultSize = 16,
    defaultAlpha = 1,
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

local function GetStateIndicatorArt(iconType, stateKey)
    if iconType == "twich" then
        return TWICH_STATE_TEXTURES[stateKey]
    end

    return STANDARD_STATE_TEXTURES[stateKey]
end

local function GetReadyCheckArt(iconType, status)
    local style = READY_CHECK_ART[iconType] or READY_CHECK_ART.standard
    return style and style[status] or nil
end

local function GetScaledIconSize(size, art, minimumSize, maximumSize)
    local boundedSize = Clamp(size or 18, minimumSize or 8, maximumSize or 64)
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

local function GetScaledRoleIconSize(size, art)
    return GetScaledIconSize(size, art, 8, 40)
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

function UnitFrames:IsValidAuraUnit(unit)
    return IsValidAuraUnit(unit)
end

local cachedDispelClass, cachedDispelSpec, cachedDispelTypes
local function GetPlayerDispelTypes()
    local _, classToken = UnitClass("player")
    -- GetSpecialization() returns the spec index (1-4), not the spec ID.
    -- We need the actual spec ID from GetSpecializationInfo to match against
    -- known spec IDs like 105 (Resto Druid), 270 (Mistweaver), 264 (Resto Shaman).
    local specIdx = _G.GetSpecialization and _G.GetSpecialization() or 0
    local specID = 0
    if specIdx > 0 and _G.GetSpecializationInfo then
        specID = select(1, _G.GetSpecializationInfo(specIdx)) or 0
    end
    if cachedDispelClass == classToken and cachedDispelSpec == specID then
        return cachedDispelTypes
    end
    local dispelTypes = {}
    if classToken == "DRUID" then
        dispelTypes.Curse = true; dispelTypes.Poison = true
        if specID == 105 then dispelTypes.Magic = true end -- Restoration
    elseif classToken == "MAGE" then
        dispelTypes.Curse = true
    elseif classToken == "MONK" then
        dispelTypes.Disease = true; dispelTypes.Poison = true
        if specID == 270 then dispelTypes.Magic = true end -- Mistweaver
    elseif classToken == "PALADIN" then
        dispelTypes.Disease = true; dispelTypes.Magic = true; dispelTypes.Poison = true
    elseif classToken == "PRIEST" then
        dispelTypes.Disease = true; dispelTypes.Magic = true
    elseif classToken == "SHAMAN" then
        dispelTypes.Curse = true
        if specID == 264 then dispelTypes.Magic = true end -- Restoration
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

local HEAL_PREDICTION_DEFAULTS = {
    enabled = true,
    showPlayer = true,
    showOthers = true,
    maxOverflow = 1.05,
    texture = nil,
    playerColor = { 0.34, 0.84, 0.54, 0.75 },
    otherColor = { 0.56, 0.92, 0.72, 0.45 },
}

local function ResolveHealPredictionUnitKey(unitKey)
    if unitKey and type(unitKey) == "string" and unitKey:match("^boss%d+$") then
        return "boss"
    end

    return unitKey
end

function UnitFrames:GetHealPredictionConfig(unitKey)
    local resolvedUnitKey = ResolveHealPredictionUnitKey(unitKey)
    local settings = self:GetUnitSettings(resolvedUnitKey)
    local cfg = type(settings.healPrediction) == "table" and settings.healPrediction or {}

    return {
        enabled = cfg.enabled ~= false,
        showPlayer = cfg.showPlayer ~= false,
        showOthers = cfg.showOthers ~= false,
        maxOverflow = Clamp(tonumber(cfg.maxOverflow) or HEAL_PREDICTION_DEFAULTS.maxOverflow, 1, 1.5),
        texture = cfg.texture,
        playerColor = CopyColor(type(cfg.playerColor) == "table" and cfg.playerColor or
            HEAL_PREDICTION_DEFAULTS.playerColor),
        otherColor = CopyColor(type(cfg.otherColor) == "table" and cfg.otherColor or HEAL_PREDICTION_DEFAULTS.otherColor),
    }
end

function UnitFrames:ApplyHealPredictionSettings(frame, unitKey)
    if not frame or not frame.HealthPrediction then return end

    local cfg = self:GetHealPredictionConfig(unitKey)
    local db = self:GetDB()
    local textureName = (cfg.texture and cfg.texture ~= "") and cfg.texture or db.texture
    local texture = (textureName and textureName ~= "") and GetLSMTexture(textureName) or GetThemeTexture()
    local health = frame.Health
    local element = frame.HealthPrediction

    element.incomingHealOverflow = cfg.maxOverflow
    if element.values and element.values.SetIncomingHealOverflowPercent then
        element.values:SetIncomingHealOverflowPercent(cfg.maxOverflow)
    end

    if element.healingPlayer then
        element.healingPlayer:SetStatusBarTexture(texture)
        element.healingPlayer:SetStatusBarColor(cfg.playerColor[1] or 1, cfg.playerColor[2] or 1,
            cfg.playerColor[3] or 1, cfg.playerColor[4] or 1)
        element.healingPlayer:SetShown(cfg.enabled and cfg.showPlayer)
    end

    if element.healingOther then
        element.healingOther:SetStatusBarTexture(texture)
        element.healingOther:SetStatusBarColor(cfg.otherColor[1] or 1, cfg.otherColor[2] or 1,
            cfg.otherColor[3] or 1, cfg.otherColor[4] or 1)
        element.healingOther:SetShown(cfg.enabled and cfg.showOthers)
    end

    if health then
        local anchorTexture = health.GetStatusBarTexture and health:GetStatusBarTexture() or nil
        if element.healingPlayer then
            element.healingPlayer:ClearAllPoints()
            element.healingPlayer:SetPoint("TOP", health, "TOP", 0, 0)
            element.healingPlayer:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
            element.healingPlayer:SetPoint("LEFT", anchorTexture or health, anchorTexture and "RIGHT" or "LEFT", 0, 0)
            element.healingPlayer:SetWidth(math_max(1, health:GetWidth()))
        end
        if element.healingOther then
            local otherAnchor = (element.healingPlayer and element.healingPlayer.GetStatusBarTexture and element.healingPlayer:GetStatusBarTexture()) or
                anchorTexture or health
            local otherPoint = (element.healingPlayer and element.healingPlayer.GetStatusBarTexture and element.healingPlayer:GetStatusBarTexture()) and
                "RIGHT"
                or (anchorTexture and "RIGHT" or "LEFT")
            element.healingOther:ClearAllPoints()
            element.healingOther:SetPoint("TOP", health, "TOP", 0, 0)
            element.healingOther:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
            element.healingOther:SetPoint("LEFT", otherAnchor, otherPoint, 0, 0)
            element.healingOther:SetWidth(math_max(1, health:GetWidth()))
        end
    end
end

function UnitFrames:ApplyPreviewHealPrediction(frame, unitKey, state)
    if not frame or not frame.HealthPrediction then return end

    local cfg = self:GetHealPredictionConfig(unitKey)
    local element = frame.HealthPrediction
    local maxHealth = math_max(1, tonumber(state and state.healthMax) or 1)
    local playerHeal = tonumber(state and state.incomingPlayer) or 0
    local otherHeal = tonumber(state and state.incomingOther) or 0

    self:ApplyHealPredictionSettings(frame, unitKey)

    if element.healingPlayer then
        element.healingPlayer:SetMinMaxValues(0, maxHealth)
        element.healingPlayer:SetValue(playerHeal)
        element.healingPlayer:SetShown(cfg.enabled and cfg.showPlayer and playerHeal > 0)
    end

    if element.healingOther then
        element.healingOther:SetMinMaxValues(0, maxHealth)
        element.healingOther:SetValue(otherHeal)
        element.healingOther:SetShown(cfg.enabled and cfg.showOthers and otherHeal > 0)
    end
end

function UnitFrames:GetPalette(scopeOrUnitKey, unit, mockClass)
    local db = self:GetDB()
    db.colors = db.colors or {}
    db.colors.scopes = db.colors.scopes or {}
    db.healthColorByScope = db.healthColorByScope or {}

    local useThemeAccentHealth = db.useThemeAccentHealth == true
    local themeHealthColor = useThemeAccentHealth
        and GetThemeColor("accentColor", { 0.96, 0.76, 0.24, 1 })
        or GetThemeColor("successColor", { 0.34, 0.84, 0.54, 1 })
    local defaultHealthMode = useThemeAccentHealth
        and "theme"
        or (db.useClassColor == true and "class" or "theme")
    local globalCustomHealthColor = CopyColor(db.colors.health or COLOR_DEFAULTS.health)

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
        health          = CopyColor(themeHealthColor),
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
    local explicitUnitMode = unitHealth and unitHealth.mode
    local explicitScopeMode = healthScope.mode
    local mode = (explicitUnitMode and explicitUnitMode ~= "inherit" and explicitUnitMode)
        or healthScope.mode
        or defaultHealthMode

    if useThemeAccentHealth and mode == "class"
        and (explicitUnitMode == nil or explicitUnitMode == "inherit")
        and explicitScopeMode == nil then
        mode = "theme"
    end

    local diagCfg = self:GetUFDiagnosticsConfig()
    local logPaletteDetails = diagCfg and diagCfg.enabled == true and diagCfg.verbose == true

    if mode == "custom" then
        if unitHealth and type(unitHealth.color) == "table" then
            palette.health = CopyColor(unitHealth.color)
        elseif type(healthScope.color) == "table" then
            palette.health = CopyColor(healthScope.color)
        else
            palette.health = CopyColor(globalCustomHealthColor)
        end
        if logPaletteDetails then
            UFDebug(string.format("GetPalette: scope=%s mode=custom r=%.2f g=%.2f b=%.2f",
                tostring(resolvedScope),
                palette.health[1], palette.health[2], palette.health[3]))
        end
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
        if logPaletteDetails then
            UFDebug(string.format("GetPalette: scope=%s mode=class token=%s found=%s",
                tostring(resolvedScope),
                tostring(classToken), tostring(classColor ~= nil)))
        end
    else
        palette.health = CopyColor(themeHealthColor)
        if logPaletteDetails then
            UFDebug(string.format("GetPalette: scope=%s mode=theme r=%.2f g=%.2f b=%.2f accent=%s",
                tostring(resolvedScope),
                palette.health[1], palette.health[2], palette.health[3], tostring(useThemeAccentHealth)))
        end
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
    local effectiveShowPower = self:GetEffectiveShowPower(unitKey)
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
    local shouldCollapse = effectiveShowPower ~= true
    local role = nil
    if not shouldCollapse and healerOnly and unit and UnitGroupRolesAssigned then
        role = UnitGroupRolesAssigned(unit) or ""
        shouldCollapse = (role ~= "HEALER")
    end

    if powerBar._roleCollapsed == shouldCollapse then return end
    powerBar._roleCollapsed = shouldCollapse

    if shouldCollapse then
        UFDebugVerbose(self, string.format("UpdatePowerBarForRole: key=%s showPower=%s healerOnly=%s role=%s → COLLAPSE",
            tostring(unitKey), tostring(effectiveShowPower == true), tostring(healerOnly), tostring(role)))
        powerBar:SetHeight(0)
        powerBar:SetAlpha(0)
        if powerBar._ownerFrame and powerBar._detached ~= true and powerBar._ownerFrame.Health then
            local health = powerBar._ownerFrame.Health
            health:ClearAllPoints()
            health:SetAllPoints(powerBar._ownerFrame)
        end
        powerBar:Hide()
        if powerBar.border then
            powerBar.border:SetAlpha(0)
            powerBar.border:Hide()
        end
    else
        local restoreH = powerBar._designedHeight or 8
        if healerOnly then
            UFDebugVerbose(self, string.format("UpdatePowerBarForRole: key=%s healerOnly=true role=HEALER → RESTORE h=%d",
                tostring(unitKey), restoreH))
        else
            UFDebugVerbose(self, string.format("UpdatePowerBarForRole: key=%s healerOnly=false → RESTORE h=%d", tostring(unitKey),
                restoreH))
        end
        powerBar:SetHeight(restoreH)
        powerBar:SetAlpha(1)
        powerBar:Show()
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
    if unitKey == "partyMember" then
        return self:GetGroupSettings("party").showPower ~= false
    end
    if unitKey == "raidMember" then
        return self:GetGroupSettings("raid").showPower ~= false
    end
    if unitKey == "tankMember" then
        return self:GetGroupSettings("tank").showPower ~= false
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
        enabled  = get("enabled", scope == "party" or scope == "tank"),
        corner   = get("corner", "TOPRIGHT"),
        size     = get("size", 18),
        alpha    = get("alpha", 1),
        insetX   = get("insetX", 2),
        insetY   = get("insetY", 2),
        filter   = get("filter", "all"),
        iconType = get("iconType", "standard"),
    }
end

function UnitFrames:GetStateIndicatorConfig(unitKey, indicatorKey)
    local indicatorDef = STATE_INDICATOR_DEFS[indicatorKey]
    if not indicatorDef then
        return {
            enabled = false,
            point = "CENTER",
            relativePoint = "CENTER",
            offsetX = 0,
            offsetY = 0,
            size = 18,
            alpha = 1,
            iconType = "standard",
        }
    end

    local db = self:GetDB()
    local scope = ResolveScopeByUnitKey(unitKey)

    local groupCfg = {}
    if scope == "party" or scope == "raid" or scope == "tank" then
        local grp = db.groups and db.groups[scope] or {}
        groupCfg = type(grp[indicatorKey]) == "table" and grp[indicatorKey] or {}
    end

    local unitCfg = {}
    local unitConfigKey = unitKey
    if scope == "boss" then
        unitConfigKey = "boss"
    end
    if scope == "singles" or scope == "boss" then
        local u = db.units and db.units[unitConfigKey] or {}
        unitCfg = type(u[indicatorKey]) == "table" and u[indicatorKey] or {}
    end

    local function get(k, default)
        if unitCfg[k] ~= nil then return unitCfg[k] end
        if groupCfg[k] ~= nil then return groupCfg[k] end
        return default
    end

    return {
        enabled = get("enabled", false),
        point = get("point", indicatorDef.defaultPoint),
        relativePoint = get("relativePoint", indicatorDef.defaultRelativePoint),
        offsetX = get("offsetX", indicatorDef.defaultOffsetX),
        offsetY = get("offsetY", indicatorDef.defaultOffsetY),
        size = get("size", indicatorDef.defaultSize),
        alpha = Clamp(get("alpha", indicatorDef.defaultAlpha or 1), 0, 1),
        iconType = get("iconType", indicatorDef.stateKey == "spirit" and "twich" or "standard"),
    }
end

function UnitFrames:GetReadyCheckIndicatorConfig(unitKey)
    local db = self:GetDB()
    local scope = ResolveScopeByUnitKey(unitKey)

    local groupCfg = {}
    if scope == "party" or scope == "raid" or scope == "tank" then
        local grp = db.groups and db.groups[scope] or {}
        groupCfg = type(grp.readyCheckIndicator) == "table" and grp.readyCheckIndicator or {}
    end

    local unitCfg = {}
    local unitConfigKey = unitKey
    if scope == "boss" then
        unitConfigKey = "boss"
    end
    if scope == "singles" or scope == "boss" then
        local u = db.units and db.units[unitConfigKey] or {}
        unitCfg = type(u.readyCheckIndicator) == "table" and u.readyCheckIndicator or {}
    end

    local function get(k, default)
        if unitCfg[k] ~= nil then return unitCfg[k] end
        if groupCfg[k] ~= nil then return groupCfg[k] end
        return default
    end

    local defaultEnabled = scope == "party" or scope == "raid" or scope == "tank"
    return {
        enabled = get("enabled", defaultEnabled),
        point = get("point", READY_CHECK_INDICATOR_DEF.defaultPoint),
        relativePoint = get("relativePoint", READY_CHECK_INDICATOR_DEF.defaultRelativePoint),
        offsetX = get("offsetX", READY_CHECK_INDICATOR_DEF.defaultOffsetX),
        offsetY = get("offsetY", READY_CHECK_INDICATOR_DEF.defaultOffsetY),
        size = get("size", READY_CHECK_INDICATOR_DEF.defaultSize),
        alpha = Clamp(get("alpha", READY_CHECK_INDICATOR_DEF.defaultAlpha), 0, 1),
        iconType = get("iconType", "standard"),
    }
end

function UnitFrames:ApplyStateIndicatorSettings(frame, unitKey, indicatorKey)
    if not frame then return end

    local indicatorDef = STATE_INDICATOR_DEFS[indicatorKey]
    if not indicatorDef then
        return
    end

    local hostKey = indicatorDef.hostKey
    local textureKey = indicatorDef.textureKey

    if not frame[hostKey] then
        local host = CreateFrame("Frame", nil, frame)
        host:SetAllPoints(frame)
        host:SetFrameStrata(frame:GetFrameStrata())
        host:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 6))
        frame[hostKey] = host
        frame[textureKey] = host:CreateTexture(nil, "OVERLAY", nil, 1)
    else
        frame[hostKey]:SetFrameStrata(frame:GetFrameStrata())
        frame[hostKey]:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 6))
    end

    local host = frame[hostKey]
    local icon = frame[textureKey]
    local cfg = self:GetStateIndicatorConfig(unitKey, indicatorKey)

    if not cfg.enabled then
        icon:Hide()
        host:Hide()
        return
    end

    host:Show()
    icon:ClearAllPoints()
    icon:SetDrawLayer("OVERLAY", 7)
    icon:SetPoint(cfg.point or indicatorDef.defaultPoint, host, cfg.relativePoint or indicatorDef.defaultRelativePoint,
        tonumber(cfg.offsetX) or indicatorDef.defaultOffsetX, tonumber(cfg.offsetY) or indicatorDef.defaultOffsetY)
    icon:SetAlpha(Clamp(cfg.alpha or indicatorDef.defaultAlpha or 1, 0, 1))

    local art = GetStateIndicatorArt(cfg.iconType, indicatorDef.stateKey)
        or GetStateIndicatorArt("standard", indicatorDef.stateKey)
    if art and art.atlas then
        icon:SetAtlas(art.atlas, false)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetSize(GetScaledIconSize(cfg.size, art, 8, 64))
    elseif art and art.texture then
        icon:SetTexture(art.texture)
        if art.texCoord then
            icon:SetTexCoord(unpack(art.texCoord))
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
        icon:SetSize(GetScaledIconSize(cfg.size, art, 8, 64))
    else
        icon:Hide()
        return
    end

    if not frame._twichStateIndicatorOnShowHooked then
        frame._twichStateIndicatorOnShowHooked = true
        frame:HookScript("OnShow", function(f)
            UnitFrames:UpdateStateIndicator(f, f._unitKey or unitKey, "combatIndicator")
            UnitFrames:UpdateStateIndicator(f, f._unitKey or unitKey, "restingIndicator")
            UnitFrames:UpdateStateIndicator(f, f._unitKey or unitKey, "spiritIndicator")
        end)
    end

    if not frame._twichStateIndicatorOnAttributeChangedHooked then
        frame._twichStateIndicatorOnAttributeChangedHooked = true
        frame:HookScript("OnAttributeChanged", function(f, name)
            if name == "unit" then
                UnitFrames:UpdateStateIndicator(f, f._unitKey or unitKey, "combatIndicator")
                UnitFrames:UpdateStateIndicator(f, f._unitKey or unitKey, "restingIndicator")
                UnitFrames:UpdateStateIndicator(f, f._unitKey or unitKey, "spiritIndicator")
            end
        end)
    end

    self:UpdateStateIndicator(frame, unitKey, indicatorKey)
end

function UnitFrames:UpdateStateIndicator(frame, unitKey, indicatorKey)
    local indicatorDef = STATE_INDICATOR_DEFS[indicatorKey]
    if not indicatorDef then
        return
    end

    local icon = frame and frame[indicatorDef.textureKey]
    local host = frame and frame[indicatorDef.hostKey]
    if not icon then
        return
    end

    local cfg = self:GetStateIndicatorConfig(unitKey, indicatorKey)
    if not cfg.enabled then
        icon:Hide()
        if host then
            host:Hide()
        end
        return
    end

    if host then
        host:Show()
    end

    local shouldShow = false
    local unit = ResolveFrameUnit(frame)
    if frame and frame._isTestPreview then
        if indicatorKey == "combatIndicator" then
            shouldShow = frame._testInCombat == true
        elseif indicatorKey == "restingIndicator" then
            shouldShow = frame._testIsResting == true
        elseif indicatorKey == "spiritIndicator" then
            shouldShow = frame._testIsDead == true
        end
    elseif unit and UnitExists(unit) then
        if indicatorKey == "combatIndicator" then
            local okCombat, inCombat = pcall(_G.UnitAffectingCombat, unit)
            shouldShow = okCombat and inCombat == true
        elseif indicatorKey == "restingIndicator" then
            local okPlayer, isPlayer = pcall(_G.UnitIsUnit, unit, "player")
            shouldShow = okPlayer and isPlayer == true and _G.IsResting and _G.IsResting() == true
        elseif indicatorKey == "spiritIndicator" then
            local okPlayer, isPlayer = pcall(_G.UnitIsPlayer, unit)
            local okDead, isDead = pcall(_G.UnitIsDeadOrGhost, unit)
            shouldShow = okPlayer and isPlayer == true and okDead and isDead == true
        end
    end

    if shouldShow then
        icon:Show()
    else
        icon:Hide()
    end
end

function UnitFrames:RefreshStateIndicatorFrames()
    for _, frame in pairs(self.frames) do
        if frame then
            self:UpdateStateIndicator(frame, frame._unitKey or ResolveFrameUnit(frame), "combatIndicator")
            self:UpdateStateIndicator(frame, frame._unitKey or ResolveFrameUnit(frame), "restingIndicator")
            self:UpdateStateIndicator(frame, frame._unitKey or ResolveFrameUnit(frame), "spiritIndicator")
        end
    end

    for _, header in pairs(self.headers) do
        if header then
            for index = 1, select('#', header:GetChildren()) do
                local child = select(index, header:GetChildren())
                if child then
                    self:UpdateStateIndicator(child, child._unitKey or ResolveFrameUnit(child), "combatIndicator")
                    self:UpdateStateIndicator(child, child._unitKey or ResolveFrameUnit(child), "restingIndicator")
                    self:UpdateStateIndicator(child, child._unitKey or ResolveFrameUnit(child), "spiritIndicator")
                end
            end
        end
    end
end

function UnitFrames:ApplyReadyCheckIndicatorSettings(frame, unitKey)
    if not frame then return end

    if not frame[READY_CHECK_INDICATOR_DEF.hostKey] then
        local host = CreateFrame("Frame", nil, frame)
        host:SetAllPoints(frame)
        host:SetFrameStrata(frame:GetFrameStrata())
        host:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 6))
        frame[READY_CHECK_INDICATOR_DEF.hostKey] = host
        frame[READY_CHECK_INDICATOR_DEF.textureKey] = host:CreateTexture(nil, "OVERLAY", nil, 1)
    else
        frame[READY_CHECK_INDICATOR_DEF.hostKey]:SetFrameStrata(frame:GetFrameStrata())
        frame[READY_CHECK_INDICATOR_DEF.hostKey]:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 6))
    end

    local host = frame[READY_CHECK_INDICATOR_DEF.hostKey]
    local icon = frame[READY_CHECK_INDICATOR_DEF.textureKey]
    local cfg = self:GetReadyCheckIndicatorConfig(unitKey)

    if not cfg.enabled then
        icon:Hide()
        host:Hide()
        return
    end

    host:Show()
    icon:ClearAllPoints()
    icon:SetDrawLayer("OVERLAY", 7)
    icon:SetPoint(cfg.point or READY_CHECK_INDICATOR_DEF.defaultPoint, host,
        cfg.relativePoint or READY_CHECK_INDICATOR_DEF.defaultRelativePoint,
        tonumber(cfg.offsetX) or READY_CHECK_INDICATOR_DEF.defaultOffsetX,
        tonumber(cfg.offsetY) or READY_CHECK_INDICATOR_DEF.defaultOffsetY)
    icon:SetAlpha(Clamp(cfg.alpha or READY_CHECK_INDICATOR_DEF.defaultAlpha, 0, 1))

    if not frame._twichReadyCheckOnShowHooked then
        frame._twichReadyCheckOnShowHooked = true
        frame:HookScript("OnShow", function(f)
            UnitFrames:UpdateReadyCheckIndicator(f, f._unitKey or unitKey)
        end)
    end

    if not frame._twichReadyCheckOnAttributeChangedHooked then
        frame._twichReadyCheckOnAttributeChangedHooked = true
        frame:HookScript("OnAttributeChanged", function(f, name)
            if name == "unit" then
                UnitFrames:UpdateReadyCheckIndicator(f, f._unitKey or unitKey)
            end
        end)
    end

    self:UpdateReadyCheckIndicator(frame, unitKey)
end

function UnitFrames:UpdateReadyCheckIndicator(frame, unitKey)
    local icon = frame and frame[READY_CHECK_INDICATOR_DEF.textureKey]
    local host = frame and frame[READY_CHECK_INDICATOR_DEF.hostKey]
    if not icon then
        return
    end

    local cfg = self:GetReadyCheckIndicatorConfig(unitKey)
    if not cfg.enabled then
        icon:Hide()
        if host then
            host:Hide()
        end
        return
    end

    if host then
        host:Show()
    end

    local status = nil
    if frame and frame._isTestPreview then
        status = frame._testReadyStatus
    else
        local unit = ResolveFrameUnit(frame)
        if unit and UnitExists(unit) and GetReadyCheckStatus then
            status = GetReadyCheckStatus(unit)
        end
    end

    if status ~= "ready" and status ~= "notready" and status ~= "waiting" then
        icon:Hide()
        return
    end

    local art = GetReadyCheckArt(cfg.iconType, status) or GetReadyCheckArt("standard", status)
    if not art then
        icon:Hide()
        return
    end

    if art.atlas then
        icon:SetAtlas(art.atlas, false)
        icon:SetTexCoord(0, 1, 0, 1)
    elseif art.texture then
        icon:SetTexture(art.texture)
        if art.texCoord then
            icon:SetTexCoord(unpack(art.texCoord))
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    else
        icon:Hide()
        return
    end

    icon:SetSize(GetScaledIconSize(cfg.size, art, 8, 64))
    icon:Show()
end

function UnitFrames:RefreshReadyCheckIndicatorFrames()
    for _, frame in pairs(self.frames) do
        if frame then
            self:UpdateReadyCheckIndicator(frame, frame._unitKey or ResolveFrameUnit(frame))
        end
    end

    for _, header in pairs(self.headers) do
        if header then
            for index = 1, select('#', header:GetChildren()) do
                local child = select(index, header:GetChildren())
                if child then
                    self:UpdateReadyCheckIndicator(child, child._unitKey or ResolveFrameUnit(child))
                end
            end
        end
    end
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
    icon:SetAlpha(Clamp(cfg.alpha or 1, 0, 1))
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
    self._auraConfigCache = self._auraConfigCache or {}
    local cached = self._auraConfigCache[unitKey]
    if cached then
        return cached
    end

    local db = self:GetDB()
    db.auras = db.auras or {}
    db.auras.scopes = db.auras.scopes or {}
    local scope = ResolveScopeByUnitKey(unitKey)
    db.auras.scopes[scope] = db.auras.scopes[scope] or {}
    local scoped = db.auras.scopes[scope]

    local merged = {
        enabled                    = scoped.enabled,
        maxIcons                   = scoped.maxIcons,
        iconSize                   = scoped.iconSize,
        spacing                    = scoped.spacing,
        yOffset                    = scoped.yOffset,
        filter                     = scoped.filter,
        onlyMine                   = scoped.onlyMine,
        barMode                    = scoped.barMode,
        barHeight                  = scoped.barHeight,
        barTexture                 = scoped.barTexture,
        barBackgroundTexture       = scoped.barBackgroundTexture,
        barFontSize                = scoped.barFontSize,
        barFontName                = scoped.barFontName,
        showTime                   = scoped.showTime,
        showStacks                 = scoped.showStacks,
        barColor                   = scoped.barColor,
        barBackground              = scoped.barBackground,
        barBorderColor             = scoped.barBorderColor,
        barTextColor               = scoped.barTextColor,
        buffBarTexture             = scoped.buffBarTexture,
        buffBarBackgroundTexture   = scoped.buffBarBackgroundTexture,
        buffBarFontSize            = scoped.buffBarFontSize,
        buffBarFontName            = scoped.buffBarFontName,
        buffBarColor               = scoped.buffBarColor,
        buffUseThemeAccentFill     = scoped.buffUseThemeAccentFill,
        buffBarBackground          = scoped.buffBarBackground,
        buffBarBorderColor         = scoped.buffBarBorderColor,
        buffBarTextColor           = scoped.buffBarTextColor,
        debuffBarTexture           = scoped.debuffBarTexture,
        debuffBarBackgroundTexture = scoped.debuffBarBackgroundTexture,
        debuffBarFontSize          = scoped.debuffBarFontSize,
        debuffBarFontName          = scoped.debuffBarFontName,
        debuffBarColor             = scoped.debuffBarColor,
        debuffUseThemeAccentFill   = scoped.debuffUseThemeAccentFill,
        debuffBarBackground        = scoped.debuffBarBackground,
        debuffBarBorderColor       = scoped.debuffBarBorderColor,
        debuffBarTextColor         = scoped.debuffBarTextColor,
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
    if merged.barBackgroundTexture == nil then merged.barBackgroundTexture = nil end
    if merged.barFontSize == nil then merged.barFontSize = nil end -- nil = auto (barH - 4)
    if merged.barFontName == nil then merged.barFontName = nil end -- nil = text fontName
    if merged.showTime == nil then merged.showTime = true end
    if merged.showStacks == nil then merged.showStacks = true end
    if merged.barColor == nil then merged.barColor = nil end           -- nil = palette.cast
    if merged.barBackground == nil then merged.barBackground = nil end -- nil = default backdrop
    if merged.barBorderColor == nil then merged.barBorderColor = nil end
    if merged.barTextColor == nil then merged.barTextColor = nil end
    if merged.buffBarTexture == nil then merged.buffBarTexture = nil end
    if merged.buffBarBackgroundTexture == nil then merged.buffBarBackgroundTexture = nil end
    if merged.buffBarFontSize == nil then merged.buffBarFontSize = nil end
    if merged.buffBarFontName == nil then merged.buffBarFontName = nil end
    if merged.buffBarColor == nil then merged.buffBarColor = nil end
    if merged.buffUseThemeAccentFill == nil then
        merged.buffUseThemeAccentFill = scoped.buffUseThemeAccentBackground == true
    end
    if merged.buffBarBackground == nil then merged.buffBarBackground = nil end
    if merged.buffBarBorderColor == nil then merged.buffBarBorderColor = nil end
    if merged.buffBarTextColor == nil then merged.buffBarTextColor = nil end
    if merged.debuffBarTexture == nil then merged.debuffBarTexture = nil end
    if merged.debuffBarBackgroundTexture == nil then merged.debuffBarBackgroundTexture = nil end
    if merged.debuffBarFontSize == nil then merged.debuffBarFontSize = nil end
    if merged.debuffBarFontName == nil then merged.debuffBarFontName = nil end
    if merged.debuffBarColor == nil then merged.debuffBarColor = nil end
    if merged.debuffUseThemeAccentFill == nil then
        merged.debuffUseThemeAccentFill = scoped.debuffUseThemeAccentBackground == true
    end
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

    self._auraConfigCache[unitKey] = merged
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

function UnitFrames:GetAuraBarAppearance(aura, data, palette, text, outAppearance)
    local isHarmfulAura = data and data.isHarmfulAura == true
    local textureName = GetAuraBarStyleValue(aura, isHarmfulAura, "BarTexture", "barTexture")
    local texture = (textureName and textureName ~= "") and GetLSMTexture(textureName) or GetThemeTexture()
    local backgroundTextureName = GetAuraBarStyleValue(aura, isHarmfulAura, "BarBackgroundTexture",
        "barBackgroundTexture")
    local backgroundTexture = (backgroundTextureName and backgroundTextureName ~= "")
        and GetLSMTexture(backgroundTextureName) or GetThemeTexture()
    local useThemeAccentFill = GetAuraBarStyleValue(aura, isHarmfulAura, "UseThemeAccentFill",
        "useThemeAccentFill") == true

    local fillColor = useThemeAccentFill
        and GetThemeColor("accentColor", { 0.96, 0.76, 0.24, 1 })
        or NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarColor", "barColor"), nil)
    local backgroundColor = NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarBackground", "barBackground"),
        nil)
    local borderColor = NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarBorderColor", "barBorderColor"), nil)
    local textColor = NormalizeColor(GetAuraBarStyleValue(aura, isHarmfulAura, "BarTextColor", "barTextColor"), nil)
    local fontSize = GetAuraBarStyleValue(aura, isHarmfulAura, "BarFontSize", "barFontSize")
    local fontName = GetAuraBarStyleValue(aura, isHarmfulAura, "BarFontName", "barFontName") or text.fontName

    if not fillColor then
        fillColor = NormalizeColor(isHarmfulAura and palette.health or palette.cast, { 1, 1, 1, 0.85 })
    end

    outAppearance = outAppearance or {}
    outAppearance.textureName = textureName
    outAppearance.texture = texture
    outAppearance.backgroundTextureName = backgroundTextureName
    outAppearance.backgroundTexture = backgroundTexture
    outAppearance.fillColor = fillColor
    outAppearance.backgroundColor = backgroundColor
    outAppearance.borderColor = borderColor
    outAppearance.textColor = textColor
    outAppearance.fontSize = (fontSize and fontSize > 0) and fontSize or nil
    outAppearance.fontName = fontName
    return outAppearance
end

local MAX_AURA_BARS = 12
local AURA_TIMER_UPDATE_RATE = 0.1

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
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetTexture(GetThemeTexture())
        bg:SetVertexColor(0.04, 0.05, 0.07, 0.95)
        bar.bg = bg
        local icon = bar:CreateTexture(nil, "OVERLAY")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); bar.icon = icon
        local label = bar:CreateFontString(nil, "OVERLAY")
        label:SetFont(_G.STANDARD_TEXT_FONT, 11, "OUTLINE")
        label:SetJustifyH("LEFT"); label:SetWordWrap(false); bar.label = label
        local timeText = bar:CreateFontString(nil, "OVERLAY")
        timeText:SetFont(_G.STANDARD_TEXT_FONT, 11, "OUTLINE")
        timeText:SetJustifyH("RIGHT"); bar.timeText = timeText
        local stackText = bar:CreateFontString(nil, "OVERLAY")
        stackText:SetFont(_G.STANDARD_TEXT_FONT, 11, "OUTLINE")
        stackText:SetJustifyH("CENTER"); bar.stackText = stackText
        bar:SetScript("OnUpdate", function(self2, elapsed)
            if not self2:IsShown() or self2._hasTimer ~= true then
                return
            end

            self2._auraTimerElapsed = (self2._auraTimerElapsed or 0) + (elapsed or 0)
            if self2._auraTimerElapsed < AURA_TIMER_UPDATE_RATE then
                return
            end

            self2._auraTimerElapsed = 0
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

local function CompareHelpfulAuraData(a, b)
    local aPriority = UnitFrames:GetHelpfulAuraSortPriority(a)
    local bPriority = UnitFrames:GetHelpfulAuraSortPriority(b)
    if aPriority ~= bPriority then
        return aPriority > bPriority
    end

    if a.isPlayerAura ~= b.isPlayerAura then
        return a.isPlayerAura == true
    end

    return (tonumber(a.auraInstanceID) or 0) < (tonumber(b.auraInstanceID) or 0)
end

local function WipeSequentialTable(tbl)
    for index = #tbl, 1, -1 do
        tbl[index] = nil
    end

    return tbl
end

local function CopyAuraBarData(target, source)
    target.name = source.name
    target.icon = source.icon
    target.auraInstanceID = source.auraInstanceID
    target.spellId = source.spellId
    target.dispelName = source.dispelName
    target.isBossAura = source.isBossAura
    target.isHarmful = source.isHarmful
    target.isHarmfulAura = source.isHarmfulAura
    target.duration = source.duration
    target.expirationTime = source.expirationTime
    target.applications = source.applications
    target.durationObject = source.durationObject
    target.isPlayerAura = source.isPlayerAura
    target.priorityAura = source.priorityAura
    target.priorityRank = source.priorityRank
    target.categoryPriority = source.categoryPriority
    target.prioritySource = source.prioritySource
    target.category = source.category
    target.dispelPriority = source.dispelPriority
    target.isPriorityDispel = source.isPriorityDispel
    return target
end

local function FillAuraSlotBuffer(buffer, ...)
    local count = select("#", ...)
    for index = 1, count do
        buffer[index] = select(index, ...)
    end
    for index = count + 1, #buffer do
        buffer[index] = nil
    end
    return count
end

local function PopulateAuraBarData(target, data, timing, isHarmfulAura, isPlayerAura)
    target.name = data.name
    target.icon = data.icon
    target.auraInstanceID = data.auraInstanceID
    target.spellId = data.spellId
    target.dispelName = data.dispelName
    target.isBossAura = data.isBossAura
    target.isHarmful = data.isHarmful
    target.isHarmfulAura = isHarmfulAura
    target.duration = timing.duration
    target.expirationTime = timing.expirationTime
    target.applications = timing.applications
    target.durationObject = timing.durationObject
    target.isPlayerAura = isPlayerAura
    target.priorityAura = nil
    target.priorityRank = nil
    target.categoryPriority = nil
    target.prioritySource = nil
    target.category = nil
    target.dispelPriority = nil
    target.isPriorityDispel = nil
    return target
end

local function CollectAuraData(list, scratch, unit, unitKey, auraFilter, maxCount, onlyMine, filterMode)
    if not C_UnitAuras or not C_UnitAuras.GetAuraSlots or not IsValidAuraUnit(unit) then return end
    local playerFilter = auraFilter .. "|PLAYER"
    local slots = scratch._slotBuffer or {}
    scratch._slotBuffer = slots
    local slotCount = FillAuraSlotBuffer(slots, C_UnitAuras.GetAuraSlots(unit, auraFilter))
    local candidates = WipeSequentialTable(scratch or {})
    local candidateCount = 0
    local isHarmfulAura = auraFilter:find("HARMFUL") ~= nil
    for i = 2, slotCount do
        local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
        if data then
            local timing = UnitFrames:ResolveAuraTiming(unit, data, "bars")
            local isPlayerAura = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, data.auraInstanceID, playerFilter)
            candidateCount = candidateCount + 1
            local d = candidates[candidateCount]
            if not d then
                d = {}
                candidates[candidateCount] = d
            end
            PopulateAuraBarData(d, data, timing, isHarmfulAura, isPlayerAura)
            if auraFilter == "HELPFUL" then
                UnitFrames:PopulateHelpfulAuraMetadata(unit, d, timing, unitKey, onlyMine)
            end
            if (not onlyMine or d.isPlayerAura)
                and AuraMatchesDisplayMode(filterMode, d)
                and (auraFilter ~= "HELPFUL" or UnitFrames:ShouldKeepGenericHelpfulAura(unit, d, timing, onlyMine,
                    unitKey)) then
                candidates[candidateCount] = d
            else
                candidates[candidateCount] = nil
                candidateCount = candidateCount - 1
            end
        end
    end

    if auraFilter == "HELPFUL" then
        for i = #candidates, candidateCount + 1, -1 do
            candidates[i] = nil
        end
        table.sort(candidates, CompareHelpfulAuraData)
    end

    local listCount = #list
    for i = 1, math.min(maxCount, candidateCount) do
        listCount = listCount + 1
        local entry = list[listCount]
        if not entry then
            entry = {}
            list[listCount] = entry
        end
        CopyAuraBarData(entry, candidates[i])
    end
end

function UnitFrames:RefreshAuraBarsForFrame(frame, unitKey)
    if not frame.AuraBars then return end
    self:UFDiagBump("auraBarRefreshCalls", 1)
    local unit = ResolveFrameUnit(frame)
    if not unit and not frame._isTestPreview then return end
    local aura                        = self:GetAuraConfigFor(unitKey)
    local maxBars                     = math_max(1, math_min(math.floor(tonumber(aura.maxIcons) or 8), MAX_AURA_BARS))
    local barH                        = Clamp(aura.barHeight or 14, 8, 30)
    local spacing                     = Clamp(aura.spacing or 2, 0, 8)
    local filter                      = aura.filter or "ALL"
    local onlyMine                    = aura.onlyMine == true
    local container                   = frame.AuraBars
    local frameWidth                  = math_max(40, frame:GetWidth())
    local text                        = self:GetTextConfigFor(unitKey)
    local palette                     = self:GetPalette(unitKey, unit, frame and frame._testMockClass or nil)
    local showTime                    = aura.showTime ~= false
    local showStacks                  = aura.showStacks ~= false

    container._twichAuraBarList       = WipeSequentialTable(container._twichAuraBarList or {})
    container._twichAuraBarScratch    = container._twichAuraBarScratch or {}
    container._twichAuraBarAppearance = container._twichAuraBarAppearance or {}
    local auraList                    = container._twichAuraBarList
    if frame._isTestPreview then
        auraList = self:GetPreviewAuraListForFrame(frame, unitKey)
    elseif filter == "HELPFUL" then
        CollectAuraData(auraList, container._twichAuraBarScratch, unit, unitKey, "HELPFUL", maxBars, onlyMine, filter)
    elseif filter == "HARMFUL" or filter == "DISPELLABLE" or filter == "DISPELLABLE_OR_BOSS" then
        CollectAuraData(auraList, container._twichAuraBarScratch, unit, unitKey, "HARMFUL", maxBars, onlyMine, filter)
    else
        CollectAuraData(auraList, container._twichAuraBarScratch, unit, unitKey, "HELPFUL", maxBars, onlyMine, filter)
        if #auraList < maxBars then
            CollectAuraData(auraList, container._twichAuraBarScratch, unit, unitKey, "HARMFUL", maxBars - #auraList,
                onlyMine, filter)
        end
    end

    local shown = 0
    for i = 1, MAX_AURA_BARS do
        local bar = container.bars[i]
        if not bar then break end
        local data = (i <= maxBars) and auraList[i] or nil
        if data then
            local appearance = self:GetAuraBarAppearance(aura, data, palette, text, container._twichAuraBarAppearance)
            local texture = appearance.texture
            local backgroundTexture = appearance.backgroundTexture
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
            if bar.bg then
                bar.bg:SetTexture(backgroundTexture or GetThemeTexture())
                if bgColor then
                    bar.bg:SetVertexColor(bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0, bgColor[4] or 0.95)
                else
                    bar.bg:SetVertexColor(0.04, 0.05, 0.07, 0.95)
                end
                bar:SetBackdropColor(0, 0, 0, 0)
            elseif bgColor then
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
            bar._auraTimerElapsed = 0
            if bar._hasTimer and data.durationObject and bar.SetTimerDuration then
                local timerDirection = (_G.Enum and _G.Enum.StatusBarTimerDirection)
                    and _G.Enum.StatusBarTimerDirection.RemainingTime or nil
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
            local stackStr = (showStacks and data.applications and data.applications > 1)
                and string.format(" (x%d)", data.applications) or ""
            local labelText = string.format("%s%s", data.name or "", stackStr)
            local iconOffset = barH + 2
            local rightReserve = 0
            if showTime then rightReserve = rightReserve + 30 end
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
                bar.label:SetText(labelText)
            end
            if bar.stackText then
                bar.stackText:Hide()
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
                    bar.timeText._twichAuraTimeText = nil
                    bar.timeText:SetText(""); bar.timeText:Hide()
                end
            end
            bar:Show(); shown = shown + 1
        else
            bar._duration = nil; bar._expiry = nil; bar._durationObject = nil; bar._usesDurationObjectFill = false; bar._hasTimer = nil; bar._auraTimerElapsed = nil; bar
                :Hide()
            if bar.timeText then
                bar.timeText._twichAuraTimeText = nil
                bar.timeText:SetText("")
            end
        end
    end
    self:UFDiagBump("auraBarsVisible", shown)
    self:UFDiagSetPeak("auraBarsVisible", shown)
    self:UFDiagMaybeReport("aurabars")
    container:SetWidth(frameWidth)
    container:SetHeight(math_max(1, shown * barH + math_max(0, shown - 1) * spacing))
end

local function BuildHealthTag(format, customTag)
    if format == "none" then
        return nil
    end
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
    if format == "none" then
        return nil
    end
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
    if format == "none" then
        return nil
    end
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
        if nameTag and nameTag ~= "" then
            frame:Tag(frame.Name, nameTag)
            if frame.Name.UpdateTag then frame.Name:UpdateTag() end
        else
            frame.Name:SetText("")
        end
    end
    if frame.HealthValue then
        frame:Untag(frame.HealthValue)
        if healthTag and healthTag ~= "" then
            frame:Tag(frame.HealthValue, healthTag)
            if frame.HealthValue.UpdateTag then frame.HealthValue:UpdateTag() end
        else
            frame.HealthValue:SetText("")
        end
    end
    if frame.PowerValue then
        frame:Untag(frame.PowerValue)
        if powerTag and powerTag ~= "" then
            frame:Tag(frame.PowerValue, powerTag)
            if frame.PowerValue.UpdateTag then frame.PowerValue:UpdateTag() end
        else
            frame.PowerValue:SetText("")
        end
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
    local aura                      = self:GetAuraConfigFor(unitKey)
    local aurasEnabled              = aura.enabled ~= false
    local maxIcons                  = math_max(1, math.floor(tonumber(aura.maxIcons) or 8))
    local iconSize                  = Clamp(aura.iconSize or 18, 10, 40)
    local spacing                   = Clamp(aura.spacing or 2, 0, 8)
    local yOff                      = Clamp(aura.yOffset or 6, -40, 60)
    local filter                    = aura.filter or "ALL"
    local capturedUK                = unitKey
    local onlyMine                  = aura.onlyMine == true

    frame.Auras.onlyShowPlayer      = onlyMine
    frame.Auras.twichFilterMode     = filter
    frame.Auras.PostProcessAuraData = function(element, unit, data)
        if data and data.isHarmfulAura ~= true then
            local timing = UnitFrames:ResolveAuraTiming(unit, data, "icons")
            UnitFrames:PopulateHelpfulAuraMetadata(unit, data, timing, capturedUK, onlyMine)
        end

        return data
    end
    frame.Auras.FilterAura          = function(element, _, data)
        if element.onlyShowPlayer and data.isPlayerAura ~= true then return false end
        if not AuraMatchesDisplayMode(element.twichFilterMode, data) then
            return false
        end

        if data and data.isHarmfulAura ~= true then
            if data.twichKeepHelpful == nil then
                local owner = element.__owner or element:GetParent()
                local unit = ResolveFrameUnit(owner)
                local timing = UnitFrames:ResolveAuraTiming(unit, data, "icons")
                UnitFrames:PopulateHelpfulAuraMetadata(unit, data, timing, capturedUK, element.onlyShowPlayer)
            end

            if data.twichKeepHelpful ~= true then
                return false
            end
        end

        return true
    end
    frame.Auras.SortBuffs           = function(a, b)
        return CompareHelpfulAuraData(a, b)
    end

    frame.Auras._forceHide          = (not aurasEnabled) or aura.barMode == true

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
                local resolvedUnit = ResolveFrameUnit(frame)
                if self:IsValidAuraUnit(resolvedUnit) then
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

    UFDebugVerbose(self, string.format("ApplyClassBarSettings: unitKey=%s enabled=%s matchFrameWidth=%s cfgWidth=%s",
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
    UFDebugVerbose(self, string.format("ApplyClassBarSettings: maxBars=%d segmentCount=%d frameWidth=%.1f",
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

local function MixTowardColor(color, target, amount)
    local mix = Clamp(amount or 0, 0, 1)
    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = color[4] or 1

    return {
        r + (((target and target[1]) or 1) - r) * mix,
        g + (((target and target[2]) or 1) - g) * mix,
        b + (((target and target[3]) or 1) - b) * mix,
        a,
    }
end

local function RandomRange(minValue, maxValue)
    return minValue + (math.random() * (maxValue - minValue))
end

local function GetSpellTextureCompat(spellID)
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        return C_Spell.GetSpellTexture(spellID)
    end

    local getter = _G.GetSpellTexture
    if type(getter) == "function" then
        return getter(spellID)
    end

    return nil
end

local function SetTextureRotation(texture, angle)
    local cosine = math_cos(angle)
    local sine = math_sin(angle)
    texture:SetTexCoord(
        0.5 + (-0.5) * cosine - (-0.5) * sine, 0.5 + (-0.5) * sine + (-0.5) * cosine,
        0.5 + (-0.5) * cosine - (0.5) * sine, 0.5 + (-0.5) * sine + (0.5) * cosine,
        0.5 + (0.5) * cosine - (-0.5) * sine, 0.5 + (0.5) * sine + (-0.5) * cosine,
        0.5 + (0.5) * cosine - (0.5) * sine, 0.5 + (0.5) * sine + (0.5) * cosine
    )
end

local FANTASY_CASTBAR_THEME_COLORS = {
    neutral = { 0.85, 0.85, 0.88, 1 },
    neutral2 = { 0.45, 0.84, 1.0, 1 },
    neutral3 = { 0.90, 0.30, 0.30, 1 },
    metal = { 0.92, 0.78, 0.52, 1 },
    metal_icon = { 0.92, 0.78, 0.52, 1 },
    engrenages = { 0.86, 0.73, 0.46, 1 },
    honey_icon = { 0.95, 0.74, 0.28, 1 },
    mossystone = { 0.22, 0.78, 0.62, 1 },
    mossystone_icon = { 0.22, 0.78, 0.62, 1 },
    viking = { 0.37, 0.89, 0.92, 1 },
    alliance = { 0.40, 0.70, 1.0, 1 },
    horde = { 1.0, 0.36, 0.18, 1 },
    bronze = { 0.90, 0.69, 0.35, 1 },
    aim = { 1.0, 0.32, 0.10, 1 },
    arcane = { 0.55, 0.20, 1.0, 1 },
    arcaneum = { 0.94, 0.18, 0.88, 1 },
    arctic = { 0.70, 0.92, 1.0, 1 },
    chaos = { 0.10, 0.85, 0.20, 1 },
    chiji = { 0.98, 0.84, 0.45, 1 },
    holy = { 1.0, 0.88, 0.45, 1 },
    moon = { 0.0, 0.90, 1.0, 1 },
    nature = { 0.38, 0.94, 0.42, 1 },
    earth = { 0.63, 0.57, 0.49, 1 },
    felfire = { 0.35, 0.95, 0.30, 1 },
    fire = { 1.0, 0.45, 0.18, 1 },
    fishing = { 0.52, 0.86, 1.0, 1 },
    frost = { 0.62, 0.90, 1.0, 1 },
    frostfire = { 0.83, 0.62, 1.0, 1 },
    herbalism = { 0.40, 0.90, 0.55, 1 },
    inferno = { 1.0, 0.86, 0.35, 1 },
    lava = { 1.0, 0.32, 0.12, 1 },
    lumber = { 0.70, 0.45, 0.18, 1 },
    mining = { 0.72, 0.70, 0.66, 1 },
    mistweaver = { 0.21, 0.98, 0.71, 1 },
    sacred = { 0.99, 0.93, 0.79, 1 },
    shadow = { 0.62, 0.28, 0.95, 1 },
    skinning = { 0.83, 0.65, 0.48, 1 },
    thunder = { 0.58, 0.84, 1.0, 1 },
    void = { 0.62, 0.30, 1.0, 1 },
    water = { 0.23, 0.74, 0.86, 1 },
    fists = { 0.40, 0.80, 0.90, 1 },
}

local OPULENT_CASTBAR_TEXTURE_PATH = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\OpulentCastBars\\"

local FANTASY_THEME_FOLDER_ALIASES = {
    metal_icon = "metal_Icon",
    honey_icon = "honey",
    mossystone_icon = "mossystone",
    lava = "fire2",
}

local FANTASY_THEME_BASE_ALIASES = {
    neutral = "Neutral",
    neutral2 = "Neutral2",
    neutral3 = "Neutral3",
    metal = "Metal",
    metal_icon = "Metalicon",
    engrenages = "Engrenages",
    honey_icon = "Honey_Icon",
    mossystone_icon = "Mossystone_Icon",
    mossystone = "Mossystone",
    viking = "Neutral2_Ennemy",
    alliance = "Alliance",
    horde = "Horde",
    bronze = "Bronze",
    aim = "Aim",
    arcane = "Arcane",
    arcaneum = "Arcaneum",
    arctic = "Arctic",
    chaos = "Chaos",
    chiji = "Chiji",
    earth = "Earth",
    felfire = "Felfire",
    fire = "Fire",
    fishing = "Fishing",
    frost = "Frost",
    frostfire = "Frostfire",
    herbalism = "Herbalism",
    holy = "Holy",
    inferno = "Inferno",
    lava = "Fire2",
    lumber = "Lumber",
    mining = "Mining",
    mistweaver = "Mistweaver",
    moon = "Moon",
    nature = "Nature",
    sacred = "Sacred",
    shadow = "Shadow",
    skinning = "Skinning",
    thunder = "Thunder",
    void = "Void",
    water = "Water",
    fists = "Fists",
}

local FANTASY_THEME_LIGHT_ALIASES = {
    holy = OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Light_Holy",
    thunder = OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Light_Thunder",
    water = OPULENT_CASTBAR_TEXTURE_PATH .. "water\\Frame_Water_Light",
    arctic = OPULENT_CASTBAR_TEXTURE_PATH .. "arctic\\Frame_Arctic_Light",
    felfire = OPULENT_CASTBAR_TEXTURE_PATH .. "felfire\\Frame_Felfire_Light",
    inferno = OPULENT_CASTBAR_TEXTURE_PATH .. "inferno\\Frame_Inferno_Light",
    lava = OPULENT_CASTBAR_TEXTURE_PATH .. "fire2\\Frame_Fire2_Light",
    mossystone = OPULENT_CASTBAR_TEXTURE_PATH .. "mossystone\\Frame_Mossystone_Light",
    mossystone_icon = OPULENT_CASTBAR_TEXTURE_PATH .. "mossystone\\Frame_Mossystone_Icon_Light",
    alliance = OPULENT_CASTBAR_TEXTURE_PATH .. "alliance\\BG_Alliance_Light",
    horde = OPULENT_CASTBAR_TEXTURE_PATH .. "horde\\BG_Light_Horde",
}

local FANTASY_THEME_BG_LIGHT_ALIASES = {
    alliance = OPULENT_CASTBAR_TEXTURE_PATH .. "alliance\\BG_Alliance_Light",
    horde = OPULENT_CASTBAR_TEXTURE_PATH .. "horde\\BG_Light_Horde",
    arctic = OPULENT_CASTBAR_TEXTURE_PATH .. "arctic\\FrostBG_Arctic",
}

local FANTASY_CASTBAR_THEME_ASSETS = {
    holy = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\BG_Holy",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Fill_Holy",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Frame_Holy",
        light = OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Light_Holy",
        misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_02",
        },
        front = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Stars_Holy",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
        },
    },
    moon = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "moon\\BG_Moon",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "moon\\Fill_Moon",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "moon\\Frame_Moon",
        light = OPULENT_CASTBAR_TEXTURE_PATH .. "moon\\Frame_Moon_Light",
        misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_02",
        },
        front = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Stars_Holy",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
        },
        glow = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Particle_Frost_01",
        },
    },
    nature = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\BG_Nature",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Fill_Nature",
        frames = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Frame_Nature_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Frame_Nature_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Frame_Nature_03",
        },
        misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_03",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_04",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_05",
        },
    },
    earth = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\BG_Earth",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Fill_Earth",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Frame_Earth",
        rocks = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_03",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_04",
        },
        debris = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_05",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_06",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_07",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_08",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_09",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_10",
            OPULENT_CASTBAR_TEXTURE_PATH .. "earth\\Misc_Earth_11",
        },
    },
    water = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "water\\BG_Water",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "water\\Fill_Water",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "water\\Frame_Water",
        light = OPULENT_CASTBAR_TEXTURE_PATH .. "water\\Frame_Water_Light",
        circle = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "water\\Water_Circle",
        },
    },
    arcane = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\BG_Arcane",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Fill_Arcane",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Frame_Arcane",
        runes = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Rune_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Rune_02",
        },
    },
    arcaneum = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "arcaneum\\Fill_Arcaneum",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "arcaneum\\Fill_Arcaneum",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "arctic\\Frame_Arctic",
        runes = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Rune_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Rune_02",
        },
    },
    void = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "void\\BG_Void",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "void\\Fill_Void",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "void\\Frame_Void",
        light = OPULENT_CASTBAR_TEXTURE_PATH .. "void\\Frame_Void_Light",
        vortex = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "void\\Vortex",
        },
    },
    mining = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\BG_Mining",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Fill_Mining",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Frame_Mining",
        stones = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Stone_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Stone_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Stone_03",
            OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Stone_04",
            OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Stone_05",
            OPULENT_CASTBAR_TEXTURE_PATH .. "mining\\Stone_06",
        },
    },
    lumber = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "lumber\\Lumber_01",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "lumber\\Lumber_01",
        chips = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "lumber\\Lumber_Misc_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "lumber\\Lumber_Misc_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "lumber\\Lumber_Misc_03",
            OPULENT_CASTBAR_TEXTURE_PATH .. "lumber\\Lumber_Misc_04",
            OPULENT_CASTBAR_TEXTURE_PATH .. "lumber\\Lumber_Misc_05",
        },
    },
    thunder = {
        bg = OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\BG_Thunder",
        fill = OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Fill_Thunder",
        frame = OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Frame_Thunder",
        light = OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Light_Thunder",
        misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Lightning_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Lightning_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Lightning_03",
        },
        bolts = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Lightning_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Lightning_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "thunder\\Lightning_03",
        },
    },
}

local FANTASY_NATURE_FRAME_SEQUENCE = { 1, 2, 3, 2 }
local FANTASY_ART_NATIVE_WIDTH = 1024
local FANTASY_ART_NATIVE_HEIGHT = 512

local FANTASY_THEME_TEXTURE_BANDS = {
    default = {
        bg = { 0, 1, 194 / 512, 294 / 512 },
        fill = { 0, 1, 198 / 512, 291 / 512 },
        light = { 0, 1, 176 / 512, 336 / 512 },
    },
}

local FANTASY_THEME_EFFECT_FAMILY = {
    neutral = "metal",
    neutral2 = "metal",
    neutral3 = "metal",
    metal = "metal",
    metal_icon = "metal",
    engrenages = "metal",
    honey_icon = "metal",
    mossystone_icon = "water",
    mossystone = "water",
    viking = "metal",
    holy = "holy",
    sacred = "holy",
    moon = "moon",
    alliance = "metal",
    horde = "fire",
    bronze = "metal",
    nature = "nature",
    aim = "nature",
    fists = "monk",
    mistweaver = "monk",
    chiji = "monk",
    earth = "earth",
    herbalism = "nature",
    water = "water",
    fishing = "water",
    mining = "gather",
    skinning = "gather",
    lumber = "gather",
    thunder = "thunder",
    chaos = "fire",
    arcane = "arcane",
    arcaneum = "arcane",
    void = "void",
    frost = "frost",
    arctic = "frost",
    frostfire = "frost",
    fire = "fire",
    inferno = "fire",
    lava = "fire",
    felfire = "fire",
    shadow = "void",
}

local FANTASY_THEME_FILL_MARGINS = {
    holy = { 0.1758, 0.1709 },
    sacred = { 0.1258, 0.1460 },
    moon = { 0.0908, 0.0977 },
    alliance = { 0.0908, 0.0977 },
    horde = { 0.0908, 0.0977 },
    bronze = { 0.0908, 0.0977 },
    nature = { 0.0908, 0.0977 },
    aim = { 0.0908, 0.0977 },
    fists = { 0.1533, 0.0977 },
    mistweaver = { 0.0908, 0.0977 },
    chiji = { 0.0908, 0.0977 },
    earth = { 0.0908, 0.0977 },
    herbalism = { 0.0908, 0.0977 },
    water = { 0.19, 0.21 },
    thunder = { 0.1709, 0.1562 },
    chaos = { 0.1221, 0.1162 },
}

local function GetFantasyThemeColor(theme)
    return FANTASY_CASTBAR_THEME_COLORS[theme or "holy"] or FANTASY_CASTBAR_THEME_COLORS.holy
end

local function GetFantasyThemeEffectFamily(theme)
    return FANTASY_THEME_EFFECT_FAMILY[theme or ""]
end

local function GetFantasyThemeFillMargins(theme)
    local margins = FANTASY_THEME_FILL_MARGINS[theme or ""] or
        FANTASY_THEME_FILL_MARGINS[GetFantasyThemeEffectFamily(theme) or ""]
    if margins then
        return margins[1], margins[2]
    end

    return 0.0908, 0.0977
end

local function GetFantasyEffectScale(castbar)
    local value = castbar and tonumber(castbar._twichFantasyEffectScale) or 1
    return Clamp(value or 1, 0.5, 3)
end

local function GetFantasyThemeTextureBand(theme, layer)
    local bands = FANTASY_THEME_TEXTURE_BANDS[theme] or FANTASY_THEME_TEXTURE_BANDS.default
    return bands[layer] or FANTASY_THEME_TEXTURE_BANDS.default[layer] or FANTASY_THEME_TEXTURE_BANDS.default.bg
end

local function ApplyFantasyTextureBand(texture, band)
    if not texture then
        return
    end

    local coords = band or FANTASY_THEME_TEXTURE_BANDS.default.bg
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

local function GetFantasyTextureBandAspect(band)
    local coords = band or FANTASY_THEME_TEXTURE_BANDS.default.bg
    local bandHeight = math_max(1, (coords[4] - coords[3]) * FANTASY_ART_NATIVE_HEIGHT)
    return FANTASY_ART_NATIVE_WIDTH / bandHeight
end

local function GetFantasyThemeAssets(theme)
    local key = theme or "holy"
    local existing = FANTASY_CASTBAR_THEME_ASSETS[key]
    if existing then
        return existing
    end

    local folder = FANTASY_THEME_FOLDER_ALIASES[key] or key
    local base = FANTASY_THEME_BASE_ALIASES[key]
    if not base then
        return FANTASY_CASTBAR_THEME_ASSETS.holy
    end

    local root = OPULENT_CASTBAR_TEXTURE_PATH .. folder .. "\\"
    local assets = {
        bg = root .. "BG_" .. base,
        fill = root .. "Fill_" .. base,
        frame = root .. "Frame_" .. base,
        light = FANTASY_THEME_LIGHT_ALIASES[key] or (root .. "Frame_" .. base .. "_Light"),
        bgLight = FANTASY_THEME_BG_LIGHT_ALIASES[key],
    }

    if key == "nature" then
        assets.frames = {
            root .. "Frame_Nature_01",
            root .. "Frame_Nature_02",
            root .. "Frame_Nature_03",
        }
        assets.misc = {
            root .. "Leaf_01",
            root .. "Leaf_02",
            root .. "Leaf_03",
            root .. "Leaf_04",
            root .. "Leaf_05",
        }
    elseif key == "aim" then
        assets.fill = root .. "Fill_Left_Aim"
        assets.misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_03",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_04",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_05",
            OPULENT_CASTBAR_TEXTURE_PATH .. "skinning\\Misc_Skinning_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "skinning\\Misc_Skinning_02",
        }
    elseif key == "holy" then
        assets.misc = {
            root .. "Misc_Holy_01",
            root .. "Misc_Holy_02",
        }
        assets.front = {
            root .. "Stars_Holy",
            root .. "Misc_Holy_01",
        }
    elseif key == "moon" then
        assets.misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_02",
        }
        assets.front = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Stars_Holy",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
        }
        assets.glow = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Particle_Frost_01",
        }
    elseif key == "thunder" then
        assets.misc = {
            root .. "Lightning_01",
            root .. "Lightning_02",
            root .. "Lightning_03",
        }
        assets.bolts = {
            root .. "Lightning_01",
            root .. "Lightning_02",
            root .. "Lightning_03",
        }
    elseif key == "fists" then
        assets.misc = {
            root .. "Leafpink_01",
            root .. "Leafpink_02",
            root .. "Leafpink_03",
            root .. "Leafpink_04",
            root .. "Leafpink_05",
        }
    elseif key == "sacred" then
        assets.misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_02",
        }
        assets.front = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Stars_Holy",
            OPULENT_CASTBAR_TEXTURE_PATH .. "holy\\Misc_Holy_01",
        }
    elseif key == "earth" then
        assets.rocks = {
            root .. "Misc_Earth_01",
            root .. "Misc_Earth_02",
            root .. "Misc_Earth_03",
            root .. "Misc_Earth_04",
        }
        assets.debris = {
            root .. "Misc_Earth_05",
            root .. "Misc_Earth_06",
            root .. "Misc_Earth_07",
            root .. "Misc_Earth_08",
            root .. "Misc_Earth_09",
            root .. "Misc_Earth_10",
            root .. "Misc_Earth_11",
        }
    elseif key == "water" then
        assets.circle = {
            root .. "Water_Circle",
        }
    elseif key == "fishing" then
        assets.circle = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "water\\Water_Circle",
        }
        assets.mist = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Mist_Frost_01",
        }
    elseif key == "mossystone" or key == "mossystone_icon" then
        assets.circle = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "water\\Water_Circle",
        }
    elseif key == "arcane" then
        assets.runes = {
            root .. "Rune_01",
            root .. "Rune_02",
        }
    elseif key == "arcaneum" then
        assets.runes = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Rune_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "arcane\\Rune_02",
        }
    elseif key == "void" then
        assets.vortex = {
            root .. "Vortex",
        }
    elseif key == "shadow" then
        assets.vortex = {
            root .. "Circle_Shadow",
        }
    elseif key == "mining" then
        assets.stones = {
            root .. "Stone_01",
            root .. "Stone_02",
            root .. "Stone_03",
            root .. "Stone_04",
            root .. "Stone_05",
            root .. "Stone_06",
        }
    elseif key == "lumber" then
        assets.chips = {
            root .. "Lumber_Misc_01",
            root .. "Lumber_Misc_02",
            root .. "Lumber_Misc_03",
            root .. "Lumber_Misc_04",
            root .. "Lumber_Misc_05",
        }
    elseif key == "skinning" then
        assets.misc = {
            root .. "Misc_Skinning_01",
            root .. "Misc_Skinning_02",
        }
    elseif key == "mistweaver" or key == "chiji" or key == "herbalism" then
        assets.misc = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_01",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_02",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_03",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_04",
            OPULENT_CASTBAR_TEXTURE_PATH .. "nature\\Leaf_05",
        }
        if key == "mistweaver" then
            assets.mist = {
                OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Mist_Frost_01",
            }
        end
    elseif key == "frost" or key == "arctic" or key == "frostfire" or key == "inferno" or key == "lava" or key == "felfire" then
        assets.mist = {
            OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Mist_Frost_01",
        }
    end

    FANTASY_CASTBAR_THEME_ASSETS[key] = assets
    return assets
end

local function GetFantasyThemeTexture(theme, kind, index)
    local assets = GetFantasyThemeAssets(theme)
    local bucket = assets and assets[kind]
    if type(bucket) == "table" and #bucket > 0 then
        return bucket[((index or 1) - 1) % #bucket + 1]
    end
    if type(bucket) == "string" and bucket ~= "" then
        return bucket
    end
    return "Interface\\Cooldown\\star4"
end

local function GetFantasyParticleTexture(theme, purpose, index)
    local assets = GetFantasyThemeAssets(theme)
    local family = GetFantasyThemeEffectFamily(theme)
    local bucket = nil

    if purpose == "glow" then
        bucket = assets.glow
    elseif purpose == "mist" then
        bucket = assets.mist
    elseif purpose == "ripple" then
        bucket = assets.circle
    elseif purpose == "rune" then
        bucket = assets.runes
    elseif purpose == "vortex" then
        bucket = assets.vortex
    elseif purpose == "gather" then
        bucket = assets.stones or assets.chips or assets.misc
    elseif purpose == "ember" then
        bucket = assets.debris or assets.stones or assets.chips or assets.misc
    elseif purpose == "orbit" then
        bucket = assets.rocks
    elseif purpose == "front" then
        if family == "earth" then
            bucket = assets.debris
        else
            bucket = assets.front or assets.misc
        end
    elseif purpose == "ambient" or purpose == "stream" then
        bucket = assets.debris or assets.misc
    end

    if type(bucket) ~= "table" or #bucket == 0 then
        if family == "holy" then
            local holyAssets = GetFantasyThemeAssets("holy")
            bucket = purpose == "front" and (holyAssets.front or holyAssets.misc) or holyAssets.misc
        elseif family == "moon" then
            local moonAssets = GetFantasyThemeAssets("moon")
            if purpose == "glow" then
                bucket = moonAssets.glow
            elseif purpose == "front" then
                bucket = moonAssets.front or moonAssets.misc
            else
                bucket = moonAssets.misc
            end
        elseif family == "earth" then
            local earthAssets = GetFantasyThemeAssets("earth")
            bucket = purpose == "orbit" and earthAssets.rocks or earthAssets.debris
        elseif family == "nature" then
            bucket = GetFantasyThemeAssets("nature").misc
        elseif family == "monk" then
            bucket = GetFantasyThemeAssets(theme).misc or GetFantasyThemeAssets("nature").misc
        elseif family == "thunder" then
            bucket = GetFantasyThemeAssets("thunder").misc
        elseif family == "metal" or family == "fire" or family == "gather" then
            bucket = GetFantasyThemeAssets("earth").debris
        elseif family == "water" then
            local waterAssets = GetFantasyThemeAssets(theme)
            bucket = purpose == "ripple" and waterAssets.circle or GetFantasyThemeAssets("earth").debris
        elseif family == "frost" then
            local frostAssets = GetFantasyThemeAssets(theme)
            bucket = purpose == "mist" and
                (frostAssets.mist or { OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Mist_Frost_01" })
                or
                { OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Particle_Frost_01", OPULENT_CASTBAR_TEXTURE_PATH ..
                "frost\\Particle_Frost_02" }
        elseif family == "arcane" then
            local arcaneAssets = GetFantasyThemeAssets(theme)
            bucket = purpose == "rune" and arcaneAssets.runes or
                { OPULENT_CASTBAR_TEXTURE_PATH .. "frost\\Particle_Frost_01" }
        elseif family == "void" then
            local voidAssets = GetFantasyThemeAssets(theme)
            bucket = purpose == "vortex" and voidAssets.vortex or GetFantasyThemeAssets("earth").debris
        end
    end

    if type(bucket) == "table" and #bucket > 0 then
        return bucket[((index or 1) - 1) % #bucket + 1]
    end

    return "Interface\\Cooldown\\star4"
end

local function CountFantasyParticles(fx, kind)
    local count = 0
    for index = 1, #fx.particles do
        local particle = fx.particles[index]
        if particle.active and particle.kind == kind then
            count = count + 1
        end
    end
    return count
end

local function SetFantasyTexturePoint(fx, texture, x, y)
    texture:ClearAllPoints()
    texture:SetPoint(
        "CENTER",
        fx.particleLayer,
        "BOTTOMLEFT",
        (fx.particleInsetX or 0) + x,
        (fx.particleInsetY or 0) + y
    )
end

local function ResetFantasyParticle(particle)
    particle.active = false
    particle.kind = nil
    particle.tex:SetAlpha(0)
    particle.tex:Hide()
    particle.tex:SetTexCoord(0, 1, 0, 1)
end

local function ResetFantasyBolt(bolt)
    bolt.active = false
    bolt.tex:SetAlpha(0)
    bolt.tex:Hide()
end

local function AcquireFantasyParticle(fx)
    for index = 1, #fx.particles do
        local particle = fx.particles[index]
        if not particle.active then
            return particle, index
        end
    end

    return nil, nil
end

local function AcquireFantasyBolt(fx)
    for index = 1, #fx.bolts do
        local bolt = fx.bolts[index]
        if not bolt.active then
            return bolt, index
        end
    end

    return nil, nil
end

local function HideFantasyCastbarVisuals(fx)
    if not fx then
        return
    end

    if fx.themeBG then
        fx.themeBG:SetAlpha(0)
    end
    if fx.overlay then
        fx.overlay:Hide()
    end
    if fx.fillGlow then
        fx.fillGlow:SetAlpha(0)
    end
    if fx.themeFill then
        fx.themeFill:SetAlpha(0)
    end
    if fx.themeLight then
        fx.themeLight:SetAlpha(0)
    end
    if fx.pulse then
        fx.pulse:SetAlpha(0)
    end
    if fx.themeFrame then
        fx.themeFrame:SetAlpha(0)
    end
    if fx.edgeGlow then
        fx.edgeGlow:SetAlpha(0)
    end
    if fx.completionFlash then
        fx.completionFlash:SetAlpha(0)
    end
    if fx.castbar and fx.castbar.bg and fx.castbar.bg.SetAlpha then
        fx.castbar.bg:SetAlpha(1)
    end
    if fx.sheenFrame then
        fx.sheenFrame:Hide()
    end
    if fx.particleLayer then
        fx.particleLayer:Hide()
    end
    if fx.particles then
        for index = 1, #fx.particles do
            ResetFantasyParticle(fx.particles[index])
        end
    end
    if fx.bolts then
        for index = 1, #fx.bolts do
            ResetFantasyBolt(fx.bolts[index])
        end
    end
end

function UnitFrames:LayoutFantasyCastbarVisuals(castbar)
    local fx = castbar and castbar.TwichFantasy
    if not fx then
        return
    end

    local width = math_max(1, castbar:GetWidth() or 1)
    local height = math_max(1, castbar:GetHeight() or 1)
    local effectScale = GetFantasyEffectScale(castbar)

    fx.width = width
    fx.height = height
    fx.effectScale = effectScale
    fx.sheenWidth = math_max(24, math_min(width * 0.34, 96))
    fx.particleInsetX = math_max(18, height * 1.35) * effectScale
    fx.particleInsetY = math_max(14, height * 1.15) * effectScale

    local band = GetFantasyThemeTextureBand(fx.theme or castbar._twichFantasyTheme or "holy", "bg")
    local artWidth = width
    local artHeight = math_max(height, artWidth / GetFantasyTextureBandAspect(band))
    fx.artWidth = artWidth
    fx.artHeight = artHeight

    if fx.artFrame then
        fx.artFrame:ClearAllPoints()
        fx.artFrame:SetPoint("CENTER", castbar, "CENTER", 0, 0)
        fx.artFrame:SetSize(artWidth, artHeight)
    end

    fx.progressMask:SetWidth(math_max(1, math_floor((artWidth * (fx.progress or 0)) + 0.5)))
    fx.sheenFrame:SetSize(fx.sheenWidth, artHeight)

    if fx.particleLayer then
        fx.particleLayer:ClearAllPoints()
        fx.particleLayer:SetPoint("TOPLEFT", castbar, "TOPLEFT", -fx.particleInsetX, fx.particleInsetY)
        fx.particleLayer:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", fx.particleInsetX, -fx.particleInsetY)
    end

    local statusTexture = castbar.GetStatusBarTexture and castbar:GetStatusBarTexture() or nil
    fx.edgeGlow:ClearAllPoints()
    if statusTexture then
        fx.edgeGlow:SetPoint("CENTER", statusTexture, "RIGHT", 0, 0)
    else
        fx.edgeGlow:SetPoint("LEFT", castbar, "LEFT", 0, 0)
    end
    fx.edgeGlow:SetSize(math_max(22, height * 1.9), math_max(height + 8, height * 2.5))
end

function UnitFrames:ResetFantasyCastbarVisuals(castbar)
    local fx = castbar and castbar.TwichFantasy
    if not fx then
        return
    end

    fx.clock = 0
    fx.progress = 0
    fx.flashAlpha = 0
    fx.finishPulseTriggered = false
    fx.pulseBaseAlpha = 0.1
    fx.edgeBaseAlpha = 0.35
    fx.theme = nil
    fx.natureFrameTimer = 0
    fx.natureFrameStep = 1
    fx.previousProgress = 0
    fx.ambientAccumulator = 0
    fx.frontAccumulator = 0
    fx.streamAccumulator = 0
    fx.glowAccumulator = 0
    fx.rippleAccumulator = 0
    fx.nextBoltAt = RandomRange(0.16, 0.42)

    if fx.progressMask then
        fx.progressMask:SetWidth(1)
    end
    if fx.themeBG then
        fx.themeBG:SetAlpha(0)
    end
    if fx.completionFlash then
        fx.completionFlash:SetAlpha(0)
    end
    if fx.themeFill then
        fx.themeFill:SetAlpha(0)
    end
    if fx.themeLight then
        fx.themeLight:SetAlpha(0)
    end
    if fx.pulse then
        fx.pulse:SetAlpha(0)
    end
    if fx.themeFrame then
        fx.themeFrame:SetAlpha(0)
    end
    if fx.edgeGlow then
        fx.edgeGlow:SetAlpha(0)
    end
    if fx.sheenFrame then
        fx.sheenFrame:Hide()
    end
    if fx.particleLayer then
        fx.particleLayer:Hide()
    end
    if fx.particles then
        for index = 1, #fx.particles do
            ResetFantasyParticle(fx.particles[index])
        end
    end
    if fx.bolts then
        for index = 1, #fx.bolts do
            ResetFantasyBolt(fx.bolts[index])
        end
    end
end

function UnitFrames:EnsureFantasyCastbarVisuals(castbar)
    if not castbar then
        return nil
    end

    if castbar.TwichFantasy then
        return castbar.TwichFantasy
    end

    if castbar.SetClipsChildren then
        castbar:SetClipsChildren(false)
    end

    local overlay = CreateFrame("Frame", nil, castbar)
    overlay:SetAllPoints(castbar)
    overlay:SetFrameStrata(castbar:GetFrameStrata())
    overlay:SetFrameLevel(math_max(1, castbar:GetFrameLevel() + 3))
    overlay:EnableMouse(false)
    overlay:Hide()

    local artFrame = CreateFrame("Frame", nil, overlay)
    artFrame:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    artFrame:SetSize(math_max(1, castbar:GetWidth() or 1), math_max(1, castbar:GetHeight() or 1))
    artFrame:SetFrameLevel(overlay:GetFrameLevel())

    local progressMask = artFrame:CreateMaskTexture()
    progressMask:SetTexture("Interface\\Buttons\\WHITE8x8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    progressMask:SetPoint("TOPLEFT", artFrame, "TOPLEFT")
    progressMask:SetPoint("BOTTOMLEFT", artFrame, "BOTTOMLEFT")
    progressMask:SetWidth(1)

    local themeBG = artFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
    themeBG:SetAllPoints(artFrame)
    themeBG:SetAlpha(0)

    local fillGlow = artFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    fillGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    fillGlow:SetAllPoints(artFrame)
    fillGlow:SetBlendMode("ADD")
    fillGlow:AddMaskTexture(progressMask)

    local themeFill = artFrame:CreateTexture(nil, "ARTWORK", nil, 0)
    themeFill:SetAllPoints(artFrame)
    themeFill:SetBlendMode("BLEND")
    themeFill:SetAlpha(0)
    themeFill:AddMaskTexture(progressMask)

    local themeLight = artFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    themeLight:SetAllPoints(artFrame)
    themeLight:SetBlendMode("ADD")
    themeLight:SetAlpha(0)
    themeLight:AddMaskTexture(progressMask)

    local pulse = artFrame:CreateTexture(nil, "ARTWORK", nil, 2)
    pulse:SetTexture("Interface\\Buttons\\WHITE8x8")
    pulse:SetAllPoints(artFrame)
    pulse:SetBlendMode("ADD")
    pulse:AddMaskTexture(progressMask)

    local themeFrame = artFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    themeFrame:SetAllPoints(artFrame)
    themeFrame:SetBlendMode("BLEND")
    themeFrame:SetAlpha(0)

    local sheenFrame = CreateFrame("Frame", nil, overlay)
    sheenFrame:SetPoint("LEFT", overlay, "LEFT", -32, 0)
    sheenFrame:SetHeight(math_max(1, castbar:GetHeight() or 1))
    sheenFrame:SetFrameLevel(overlay:GetFrameLevel() + 1)
    sheenFrame:Hide()

    local sheenLeft = sheenFrame:CreateTexture(nil, "OVERLAY")
    sheenLeft:SetPoint("TOPLEFT", sheenFrame, "TOPLEFT")
    sheenLeft:SetPoint("BOTTOM", sheenFrame, "BOTTOM")
    sheenLeft:SetPoint("RIGHT", sheenFrame, "CENTER")
    sheenLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    sheenLeft:SetBlendMode("ADD")
    sheenLeft:AddMaskTexture(progressMask)

    local sheenRight = sheenFrame:CreateTexture(nil, "OVERLAY")
    sheenRight:SetPoint("TOP", sheenFrame, "TOP")
    sheenRight:SetPoint("BOTTOMRIGHT", sheenFrame, "BOTTOMRIGHT")
    sheenRight:SetPoint("LEFT", sheenFrame, "CENTER")
    sheenRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    sheenRight:SetBlendMode("ADD")
    sheenRight:AddMaskTexture(progressMask)

    local edgeGlow = overlay:CreateTexture(nil, "OVERLAY", nil, 4)
    edgeGlow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    edgeGlow:SetBlendMode("ADD")
    edgeGlow:SetAlpha(0)

    local completionFlash = artFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    completionFlash:SetTexture("Interface\\Buttons\\WHITE8x8")
    completionFlash:SetAllPoints(artFrame)
    completionFlash:SetBlendMode("ADD")
    completionFlash:SetAlpha(0)
    completionFlash:AddMaskTexture(progressMask)

    local particleLayer = CreateFrame("Frame", nil, overlay)
    particleLayer:SetFrameStrata(castbar:GetFrameStrata())
    particleLayer:SetFrameLevel(overlay:GetFrameLevel() + 2)
    particleLayer:EnableMouse(false)
    particleLayer:Hide()

    local particles = {}
    for index = 1, 240 do
        local texture = particleLayer:CreateTexture(nil, "OVERLAY", nil, 1)
        texture:SetAlpha(0)
        texture:Hide()
        particles[index] = {
            tex = texture,
            active = false,
            seed = index,
        }
    end

    local bolts = {}
    for index = 1, 4 do
        local texture = particleLayer:CreateTexture(nil, "OVERLAY", nil, 3)
        texture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        texture:SetBlendMode("ADD")
        texture:SetAlpha(0)
        texture:Hide()
        bolts[index] = {
            tex = texture,
            active = false,
        }
    end

    local fx = {
        castbar = castbar,
        overlay = overlay,
        artFrame = artFrame,
        progressMask = progressMask,
        themeBG = themeBG,
        fillGlow = fillGlow,
        themeFill = themeFill,
        themeLight = themeLight,
        pulse = pulse,
        themeFrame = themeFrame,
        sheenFrame = sheenFrame,
        sheenLeft = sheenLeft,
        sheenRight = sheenRight,
        edgeGlow = edgeGlow,
        completionFlash = completionFlash,
        particleLayer = particleLayer,
        particles = particles,
        bolts = bolts,
        clock = 0,
        progress = 0,
        flashAlpha = 0,
        pulseBaseAlpha = 0.1,
        edgeBaseAlpha = 0.35,
        finishPulseTriggered = false,
        glowAccumulator = 0,
        enabled = false,
    }
    castbar.TwichFantasy = fx

    castbar:HookScript("OnSizeChanged", function(self)
        UnitFrames:LayoutFantasyCastbarVisuals(self)
        UnitFrames:SyncFantasyCastbarVisuals(self, true)
    end)
    castbar:HookScript("OnShow", function(self)
        UnitFrames:ResetFantasyCastbarVisuals(self)
        UnitFrames:SyncFantasyCastbarVisuals(self, true)
    end)
    castbar:HookScript("OnHide", function(self)
        UnitFrames:ResetFantasyCastbarVisuals(self)
    end)
    castbar:HookScript("OnUpdate", function(self, elapsed)
        UnitFrames:OnFantasyCastbarUpdate(self, elapsed)
    end)

    SetGradientCompat(sheenLeft, "HORIZONTAL", 1, 1, 1, 0, 1, 1, 1, 0.75)
    SetGradientCompat(sheenRight, "HORIZONTAL", 1, 1, 1, 0.75, 1, 1, 1, 0)

    self:LayoutFantasyCastbarVisuals(castbar)
    return fx
end

local function SpawnFantasyAmbientParticle(fx)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "holy"
    local family = GetFantasyThemeEffectFamily(theme)
    if family ~= "holy" and family ~= "moon" then
        return
    end

    local function Gauss(range)
        return (RandomRange(-range, range) + RandomRange(-range, range) + RandomRange(-range, range)) / 3
    end

    local color = GetFantasyThemeColor(theme)
    local barHeight = fx.height or 20
    local fillWidth = fx.fillWidth or fx.width or 1
    local effectScale = fx.effectScale or 1
    local centerX = (fx.fillLeftX or 0) + (fillWidth * 0.5)
    local xRange = ((fillWidth * 0.5) + 5) * effectScale
    local yRange = ((barHeight * 0.5) + 5) * effectScale
    local size = RandomRange(3, 20) * math_min(effectScale, 1.8)
    if family == "moon" then
        size = RandomRange(3, 18) * math_min(effectScale, 1.65)
    end

    particle.active = true
    particle.kind = family == "moon" and "moon-ambient" or "holy-ambient"
    particle.family = family
    particle.life = 0
    particle.maxLife = RandomRange(0.6, 1.4)
    if family == "moon" then
        particle.maxLife = RandomRange(0.85, 1.7)
    end
    particle.x = centerX + Gauss(xRange)
    particle.y = (barHeight * 0.5) + Gauss(yRange)
    particle.vx = RandomRange(-6, 6)
    particle.vy = RandomRange(-4, 8)
    if family == "moon" then
        particle.vx = RandomRange(-4, 4)
        particle.vy = RandomRange(-3, 5)
    end
    particle.phase = RandomRange(0, math_pi * 2)
    particle.maxAlpha = RandomRange(0.28, 0.65)
    if family == "moon" then
        particle.maxAlpha = RandomRange(0.22, 0.55)
    end
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "ambient", index))
    particle.tex:SetSize(size, size)
    particle.tex:SetBlendMode("ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyFrontParticle(fx, frontX)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "holy"
    local family = GetFantasyThemeEffectFamily(theme)
    local color = GetFantasyThemeColor(theme)
    local barHeight = fx.height or 20
    local effectScale = fx.effectScale or 1

    particle.active = true
    particle.kind = family == "nature" and "leaf-burst"
        or family == "earth" and "earth-front"
        or family == "moon" and "moon-front"
        or "holy-front"
    particle.family = family
    particle.life = 0
    particle.maxLife = family == "nature" and RandomRange(0.35, 0.75)
        or family == "earth" and RandomRange(0.45, 0.9)
        or family == "moon" and RandomRange(0.45, 1.0)
        or RandomRange(0.4, 0.9)
    particle.x = frontX + RandomRange(-4, 6) * effectScale
    particle.y = (barHeight * 0.5) + RandomRange(-barHeight * 0.35, barHeight * 0.35) * effectScale
    particle.baseY = particle.y
    if family == "nature" then
        local angle = RandomRange(math_pi * 0.22, math_pi * 0.78)
        local speed = RandomRange(35, 95) * effectScale
        particle.vx = math_cos(angle) * speed
        particle.vy = math_sin(angle) * speed
        particle.gravity = 80
        particle.rotSpeed = RandomRange(-3.1, 3.1)
    elseif family == "earth" then
        local angle = RandomRange(math_pi * 0.18, math_pi * 0.72)
        local speed = RandomRange(22, 58) * effectScale
        particle.vx = math_cos(angle) * speed
        particle.vy = math_sin(angle) * speed
        particle.gravity = 125
        particle.rotSpeed = RandomRange(-4.4, 4.4)
    else
        particle.vx = RandomRange(-10, 10) * effectScale
        particle.vy = RandomRange(-18, 4) * effectScale
        if family == "moon" then
            particle.vx = RandomRange(-7, 7) * effectScale
            particle.vy = RandomRange(-12, 2) * effectScale
        end
        particle.gravity = 0
        particle.rotSpeed = RandomRange(-1.4, 1.4)
    end
    particle.phase = RandomRange(0, math_pi * 2)
    particle.rot = RandomRange(0, math_pi * 2)
    particle.maxAlpha = family == "nature" and RandomRange(0.55, 0.88)
        or family == "earth" and RandomRange(0.58, 0.82)
        or family == "moon" and RandomRange(0.72, 0.88)
        or 0.9
    local size = (family == "nature" and RandomRange(7, 16)
        or family == "earth" and RandomRange(6, 14)
        or RandomRange(4, 22)) * math_min(effectScale, 1.8)
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "front", index))
    particle.tex:SetSize(size, size)
    particle.tex:SetBlendMode((family == "nature" or family == "earth") and "BLEND" or "ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyEarthOrbiter(fx, isRock)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "earth"
    local effectScale = fx.effectScale or 1
    local width = fx.width or 1
    local height = fx.height or 20
    local centerX = (width * 0.5) + RandomRange(-6, 6) * math_min(effectScale, 1.5)
    local centerY = height * 0.5
    local color = isRock
        and { 0.60, 0.56, 0.52, 1 }
        or { 0.48, 0.46, 0.43, 1 }

    particle.active = true
    particle.kind = "earth-orbiter"
    particle.family = "earth"
    particle.life = 0
    particle.maxLife = 9999
    particle.isRock = isRock == true
    particle.centerX = centerX
    particle.centerY = centerY
    particle.orbitAngle = RandomRange(0, math_pi * 2)
    particle.orbitSpeed = RandomRange(0.28, 0.72) * (math.random(0, 1) == 0 and -1 or 1)
    particle.radiusX = RandomRange(isRock and width * 0.18 or width * 0.14, isRock and width * 0.46 or width * 0.52) *
        effectScale
    particle.radiusY = RandomRange(isRock and height * 0.55 or height * 0.75, isRock and height * 1.1 or height * 1.45) *
        effectScale
    particle.verticalBob = RandomRange(0.6, 2.8) * effectScale
    particle.phase = RandomRange(0, math_pi * 2)
    particle.rot = RandomRange(0, math_pi * 2)
    particle.rotSpeed = RandomRange(-1.8, 1.8)
    particle.maxAlpha = isRock and RandomRange(0.72, 0.92) or RandomRange(0.45, 0.72)

    local size = RandomRange(isRock and 11 or 6, isRock and 18 or 11) * math_min(effectScale, 1.8)
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, isRock and "orbit" or "ambient", index))
    particle.tex:SetSize(size, size)
    particle.tex:SetBlendMode("BLEND")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, centerX, centerY)
end

local function SpawnFantasyEmberParticle(fx, frontX, familyOverride)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "fire"
    local family = familyOverride or GetFantasyThemeEffectFamily(theme) or "fire"
    local effectScale = fx.effectScale or 1
    local barHeight = fx.height or 20
    local color = GetFantasyThemeColor(theme)
    local roll = math.random(10)
    local heavy = roll <= 4
    local fast = roll >= 8
    local sizeMin = heavy and 8 or fast and 4 or 6
    local sizeMax = heavy and 14 or fast and 8 or 12
    local spread = family == "gather" and 90 or family == "metal" and 120 or 140
    local gravity = family == "void" and -18 or family == "gather" and 180 or 20
    local speedMin = heavy and 25 or fast and 80 or 40
    local speedMax = heavy and 60 or fast and 160 or 90
    local angle = RandomRange(math.rad(90 - (spread * 0.5)), math.rad(90 + (spread * 0.5)))
    local speed = RandomRange(speedMin, speedMax) * effectScale

    particle.active = true
    particle.kind = family == "gather" and "gather-front" or family == "void" and "void-front" or "ember"
    particle.family = family
    particle.life = 0
    particle.maxLife = heavy and RandomRange(0.8, 1.6) or fast and RandomRange(0.3, 0.7) or RandomRange(0.6, 1.2)
    particle.x = frontX + RandomRange(-5, 5) * effectScale
    particle.y = (barHeight * 0.5) + RandomRange(-8, 8) * effectScale
    particle.vx = math_cos(angle) * speed
    particle.vy = math_sin(angle) * speed
    particle.gravity = gravity
    particle.drift = RandomRange(-12, 12)
    particle.rot = RandomRange(0, math_pi * 2)
    particle.rotSpeed = RandomRange(-2.6, 2.6)
    particle.maxAlpha = family == "gather" and 0.92 or 0.85
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, family == "gather" and "gather" or "ember", index))
    particle.tex:SetSize(RandomRange(sizeMin, sizeMax) * math_min(effectScale, 1.9),
        RandomRange(sizeMin, sizeMax) * math_min(effectScale, 1.9))
    particle.tex:SetBlendMode(family == "gather" and "BLEND" or "ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyFireAmbient(fx)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "fire"
    local color = GetFantasyThemeColor(theme)
    local effectScale = fx.effectScale or 1
    local fillWidth = fx.fillWidth or fx.width or 1
    local fillLeftX = fx.fillLeftX or 0
    local barHeight = fx.height or 20

    particle.active = true
    particle.kind = "fire-ambient"
    particle.family = "fire"
    particle.life = 0
    particle.maxLife = RandomRange(1.0, 2.2)
    particle.x = fillLeftX + RandomRange(0, math_max(1, fillWidth))
    particle.y = (barHeight * 0.5) + RandomRange(-barHeight * 0.35, barHeight * 0.35)
    particle.vx = RandomRange(-18, 18) * effectScale
    particle.vy = RandomRange(12, 38) * effectScale
    particle.phase = RandomRange(0, math_pi * 2)
    particle.maxAlpha = 0.55
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "ember", index))
    particle.tex:SetSize(RandomRange(6, 14) * math_min(effectScale, 1.7), RandomRange(6, 14) * math_min(effectScale, 1.7))
    particle.tex:SetBlendMode("ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyMistParticle(fx)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "frost"
    local color = GetFantasyThemeColor(theme)
    local width = fx.width or 1
    local height = fx.height or 20
    local effectScale = fx.effectScale or 1

    particle.active = true
    particle.kind = "mist"
    particle.family = GetFantasyThemeEffectFamily(theme)
    particle.life = 0
    particle.maxLife = RandomRange(3.8, 6.4)
    particle.baseX = width * RandomRange(0.18, 0.82)
    particle.baseY = height * 0.5
    particle.scaleBase = RandomRange(0.75, 1.30) * math_min(effectScale, 1.6)
    particle.rot = RandomRange(0, math_pi * 2)
    particle.rotSpeed = RandomRange(-0.05, 0.05)
    particle.phase = RandomRange(0, math_pi * 2)
    particle.maxAlpha = 0.45
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "mist", index))
    particle.tex:SetSize(338 * particle.scaleBase, 169 * particle.scaleBase)
    particle.tex:SetBlendMode("ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 0.9)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.baseX, particle.baseY)
end

local function SpawnFantasyRippleParticle(fx)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "water"
    local color = GetFantasyThemeColor(theme)
    local fillWidth = fx.fillWidth or fx.width or 1
    local fillLeftX = fx.fillLeftX or 0
    local barHeight = fx.height or 20
    local effectScale = fx.effectScale or 1
    local size = RandomRange(barHeight * 1.0, barHeight * 1.8) * effectScale
    local margin = math_min(30, fillWidth * 0.1)

    particle.active = true
    particle.kind = "ripple"
    particle.family = "water"
    particle.life = 0
    particle.maxLife = RandomRange(1.2, 2.2)
    particle.x = fillLeftX + RandomRange(margin, math_max(margin, fillWidth - margin))
    particle.y = math.random(0, 1) == 0 and (barHeight + (size * 0.1)) or -(size * 0.1)
    particle.grow = RandomRange(0.20, 0.45)
    particle.rot = RandomRange(0, math_pi * 2)
    particle.rotSpeed = RandomRange(-0.8, 0.8)
    particle.baseSize = size
    particle.maxAlpha = 0.8
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "ripple", index))
    particle.tex:SetSize(size, size)
    particle.tex:SetBlendMode("ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyRuneParticle(fx)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "arcane"
    local color = GetFantasyThemeColor(theme)
    local width = fx.width or 1
    local height = fx.height or 20
    local effectScale = fx.effectScale or 1

    particle.active = true
    particle.kind = "rune"
    particle.family = "arcane"
    particle.life = 0
    particle.maxLife = 9999
    particle.centerX = width * 0.5
    particle.centerY = height * 0.5
    particle.radiusX = RandomRange(width * 0.18, width * 0.28) * effectScale
    particle.radiusY = RandomRange(height * 0.8, height * 1.2) * effectScale
    particle.orbitAngle = RandomRange(0, math_pi * 2)
    particle.orbitSpeed = RandomRange(0.45, 0.95) * (math.random(0, 1) == 0 and -1 or 1)
    particle.rot = RandomRange(0, math_pi * 2)
    particle.rotSpeed = RandomRange(-0.8, 0.8)
    particle.phase = RandomRange(0, math_pi * 2)
    particle.maxAlpha = 0.85
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "rune", index))
    particle.tex:SetSize(26 * math_min(effectScale, 1.8), 26 * math_min(effectScale, 1.8))
    particle.tex:SetBlendMode("ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.centerX, particle.centerY)
end

local function SpawnFantasyVortexParticle(fx)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "void"
    local color = GetFantasyThemeColor(theme)
    local width = fx.width or 1
    local height = fx.height or 20
    local effectScale = fx.effectScale or 1
    local size = math_max(24, height * 1.9) * math_min(effectScale, 1.8)

    particle.active = true
    particle.kind = "vortex"
    particle.family = "void"
    particle.life = 0
    particle.maxLife = 9999
    particle.x = (width * 0.5) - 5
    particle.y = (height * 0.5) + math_max(14, height * 0.9)
    particle.rot = 0
    particle.rotSpeed = 0.55
    particle.maxAlpha = theme == "shadow" and 0.55 or 0.9
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "vortex", index))
    particle.tex:SetSize(size, size)
    particle.tex:SetBlendMode("ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyNatureStream(fx)
    local particle, index = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "nature"
    local color = GetFantasyThemeColor(theme)
    local effectScale = fx.effectScale or 1
    local size = RandomRange(10, 22) * math_min(effectScale, 1.7)
    local barHeight = fx.height or 20

    particle.active = true
    particle.kind = "stream"
    particle.family = "nature"
    particle.life = 0
    particle.maxLife = RandomRange(1.0, 1.8)
    particle.x = (fx.fillLeftX or 0) - size
    particle.y = (barHeight * 0.5) + RandomRange(-barHeight * 0.25, barHeight * 0.25) * effectScale
    particle.baseY = particle.y
    particle.vx = RandomRange(55, 120) * math_max(1, effectScale * 0.9)
    particle.vy = RandomRange(-4, 4) * effectScale
    particle.waveAmp = RandomRange(3, 9) * effectScale
    particle.waveFreq = RandomRange(1.2, 2.8)
    particle.phase = RandomRange(0, math_pi * 2)
    particle.rot = RandomRange(0, math_pi * 2)
    particle.rotSpeed = RandomRange(-2.8, 2.8)
    particle.maxAlpha = RandomRange(0.55, 0.9)
    particle.deadX = ((fx.fillLeftX or 0) + (fx.fillWidth or (fx.width or 1))) + size * 2
    particle.tex:SetTexture(GetFantasyParticleTexture(theme, "stream", index))
    particle.tex:SetSize(size, size)
    particle.tex:SetBlendMode("BLEND")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyGlowParticle(fx, frontX)
    local particle = AcquireFantasyParticle(fx)
    if not particle then
        return
    end

    local theme = fx.theme or "holy"
    local family = GetFantasyThemeEffectFamily(theme)
    if not family then
        return
    end

    local barHeight = fx.height or 20
    local effectScale = fx.effectScale or 1
    local spread = family == "holy" and math_min(barHeight * 0.28, 12)
        or family == "moon" and math_min(barHeight * 0.28, 12)
        or (family == "nature" or family == "monk") and math_min(barHeight * 0.25, 10)
        or math_min(barHeight * 0.30, 14)
    local sizeMin = family == "holy" and 4 or family == "moon" and 4 or (family == "nature" or family == "monk") and 6 or
        5
    local sizeMax = family == "holy" and 10 or family == "moon" and 10 or (family == "nature" or family == "monk") and 12 or
        14
    local color = family == "holy" and { 1.0, 0.92, 0.45, 1 }
        or family == "moon" and { 0.0, 0.90, 1.0, 1 }
        or (family == "nature" or family == "monk") and { 0.30, 1.0, 0.25, 1 }
        or GetFantasyThemeColor(theme)

    particle.active = true
    particle.kind = "glow"
    particle.family = family
    particle.life = 0
    particle.maxLife = family == "holy" and RandomRange(0.25, 0.50)
        or family == "moon" and RandomRange(0.28, 0.60)
        or (family == "nature" or family == "monk") and RandomRange(0.18, 0.35)
        or RandomRange(0.15, 0.30)
    particle.x = frontX +
        RandomRange((family == "holy" or family == "moon") and -2 or -4,
            (family == "holy" or family == "moon") and 4 or 4) *
        effectScale
    particle.y = (barHeight * 0.5) + RandomRange(-spread, spread) * effectScale
    particle.vy = family == "holy" and RandomRange(-8, 8)
        or family == "moon" and RandomRange(-6, 6)
        or (family == "nature" or family == "monk") and RandomRange(-5, 5)
        or RandomRange(-8, 12)
    particle.phase = RandomRange(0, math_pi * 2)
    particle.maxAlpha = family == "holy" and 0.65 or family == "moon" and 0.55 or
        (family == "nature" or family == "monk") and 0.55 or 0.65
    particle.tex:SetTexture(family == "moon" and GetFantasyParticleTexture(theme, "glow", 1) or
        "Interface\\Cooldown\\star4")
    particle.tex:SetSize(RandomRange(sizeMin, sizeMax) * math_min(effectScale, 1.8),
        RandomRange(sizeMin, sizeMax) * math_min(effectScale, 1.8))
    particle.tex:SetBlendMode("ADD")
    particle.tex:SetVertexColor(color[1], color[2], color[3], 1)
    particle.tex:Show()
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
end

local function SpawnFantasyThunderBolt(fx, frontX)
    local bolt = AcquireFantasyBolt(fx)
    if not bolt then
        return
    end

    local color = GetFantasyThemeColor("thunder")
    local assets = GetFantasyThemeAssets("thunder")
    local width = fx.width or 1
    local height = fx.height or 20
    local effectScale = fx.effectScale or 1

    bolt.active = true
    bolt.life = 0
    bolt.maxLife = RandomRange(0.14, 0.3)
    bolt.x = RandomRange(math_max(8, frontX * 0.35), math_max(10, frontX))
    bolt.y = height * 0.5
    bolt.maxAlpha = RandomRange(0.72, 0.96)
    bolt.width = RandomRange(math_max(26, height * 1.4), math_max(34, height * 2.2)) * math_min(effectScale, 1.9)
    bolt.height = RandomRange(math_max(height + 16, height * 2.3), math_max(height + 26, height * 3.1)) *
        math_min(effectScale, 1.9)
    bolt.tex:SetTexture((assets.bolts and assets.bolts[math.random(1, #assets.bolts)]) or
        GetFantasyThemeTexture("thunder", "bolt", 1))
    bolt.tex:SetBlendMode("ADD")
    bolt.tex:SetVertexColor(color[1], color[2], color[3], 1)
    bolt.tex:SetSize(bolt.width, bolt.height)
    bolt.tex:Show()
    SetFantasyTexturePoint(fx, bolt.tex, bolt.x, bolt.y)
end

local function UpdateFantasyParticle(fx, particle, elapsed)
    if not particle.active then
        return
    end

    particle.life = particle.life + elapsed
    local progress = particle.maxLife > 0 and (particle.life / particle.maxLife) or 1
    if progress >= 1 then
        ResetFantasyParticle(particle)
        return
    end

    if particle.kind == "stream" then
        particle.x = particle.x + particle.vx * elapsed
        particle.y = particle.baseY + math_sin((particle.life * particle.waveFreq) + particle.phase) * particle.waveAmp +
            particle.vy * particle.life
        particle.rot = particle.rot + particle.rotSpeed * elapsed
        local fade = particle.x > ((particle.deadX or (fx.width or 1)) - 40)
            and math_max(0, 1 - (((particle.deadX or (fx.width or 1)) - particle.x) / 40)) or 0
        local alpha = particle.maxAlpha * math_min(particle.life / 0.5, 1) * (1 - fade)
        if particle.x >= (particle.deadX or (fx.width or 1)) then
            ResetFantasyParticle(particle)
            return
        end
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "holy-ambient" or particle.kind == "moon-ambient" then
        particle.x = particle.x + particle.vx * elapsed + math_sin((particle.life * 2) + (particle.phase or 0)) * 0.3
        particle.y = particle.y + particle.vy * elapsed
        local alpha = (progress < 0.25 and progress / 0.25 or progress < 0.65 and 1 or math_max(0, (1 - progress) / 0.35)) *
            (particle.maxAlpha or 1)
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        return
    end

    if particle.kind == "holy-front" or particle.kind == "moon-front" then
        particle.vy = (particle.vy or 0) - (8 * elapsed)
        particle.x = particle.x + particle.vx * elapsed + math_sin((particle.life * 4) + (particle.phase or 0)) * 0.4
        particle.y = particle.y + particle.vy * elapsed
        local alpha = (progress < 0.2 and progress / 0.2 or progress < 0.7 and 1 or math_max(0, (1 - progress) / 0.3)) *
            (particle.maxAlpha or 1)
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        return
    end

    if particle.kind == "leaf-burst" then
        particle.vy = particle.vy - (particle.gravity or 0) * elapsed
        particle.x = particle.x + particle.vx * elapsed
        particle.y = particle.y + particle.vy * elapsed
        particle.rot = particle.rot + particle.rotSpeed * elapsed
        local alpha = (progress < 0.55 and 1 or math_max(0, (1 - progress) / 0.45)) * (particle.maxAlpha or 1)
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "earth-front" then
        particle.vy = particle.vy - (particle.gravity or 0) * elapsed
        particle.x = particle.x + particle.vx * elapsed
        particle.y = particle.y + particle.vy * elapsed
        particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed
        local alpha = (progress < 0.18 and progress / 0.18 or progress < 0.62 and 1 or math_max(0, (1 - progress) / 0.38)) *
            (particle.maxAlpha or 1)
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "earth-orbiter" then
        particle.orbitAngle = (particle.orbitAngle or 0) + ((particle.orbitSpeed or 0.5) * elapsed)
        particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed
        particle.x = (particle.centerX or 0) + math_cos(particle.orbitAngle) * (particle.radiusX or 0)
        particle.y = (particle.centerY or 0) + math_sin(particle.orbitAngle) * (particle.radiusY or 0) +
            math_sin((particle.life * 2.4) + (particle.phase or 0)) * (particle.verticalBob or 0)
        particle.tex:SetAlpha((particle.maxAlpha or 1) * (particle.isRock and 1 or 0.92))
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "ember" or particle.kind == "gather-front" or particle.kind == "void-front" then
        particle.vy = particle.vy - (particle.gravity or 0) * elapsed
        particle.vx = particle.vx + ((particle.drift or 0) * elapsed * math_max(0, 1 - progress))
        particle.x = particle.x + particle.vx * elapsed
        particle.y = particle.y + particle.vy * elapsed
        particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed
        local alpha
        if progress < 0.15 then
            alpha = progress / 0.15
        elseif progress < 0.65 then
            alpha = 1
        else
            alpha = math_max(0, (1 - progress) / 0.35)
        end
        particle.tex:SetAlpha(alpha * (particle.maxAlpha or 1))
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "fire-ambient" then
        particle.vy = particle.vy - (4 * elapsed)
        particle.x = particle.x + particle.vx * elapsed
        particle.y = particle.y + particle.vy * elapsed
        local alpha = (progress < 0.1 and progress / 0.1 or progress < 0.65 and 1 or math_max(0, (1 - progress) / 0.35)) *
            (particle.maxAlpha or 1)
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        return
    end

    if particle.kind == "mist" then
        particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed
        local pulse = 1 + math_sin((particle.life * 0.9) + (particle.phase or 0)) * 0.09
        local alpha
        if progress < 0.25 then
            alpha = (progress / 0.25) * (particle.maxAlpha or 1)
        elseif progress < 0.75 then
            alpha = (particle.maxAlpha or 1)
        else
            alpha = math_max(0, (1 - progress) / 0.25) * (particle.maxAlpha or 1)
        end
        particle.tex:SetSize((338 * (particle.scaleBase or 1)) * pulse, (169 * (particle.scaleBase or 1)) * pulse)
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.baseX or particle.x,
            (particle.baseY or particle.y) + math_sin((particle.life * 0.45) + (particle.phase or 0)) * 3)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "ripple" then
        particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed
        local size = (particle.baseSize or 1) * (1 + ((particle.grow or 0.3) * progress))
        local alpha = (progress < 0.2 and progress / 0.2 or progress < 0.7 and 1 or math_max(0, (1 - progress) / 0.3)) *
            (particle.maxAlpha or 1)
        particle.tex:SetSize(size, size)
        particle.tex:SetAlpha(alpha)
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "rune" then
        particle.orbitAngle = (particle.orbitAngle or 0) + ((particle.orbitSpeed or 0.5) * elapsed)
        particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed
        particle.x = (particle.centerX or 0) + math_cos(particle.orbitAngle) * (particle.radiusX or 0)
        particle.y = (particle.centerY or 0) + math_sin(particle.orbitAngle) * (particle.radiusY or 0)
        particle.tex:SetAlpha((particle.maxAlpha or 1) *
            (0.75 + (0.25 * math_sin((particle.life * 2.2) + (particle.phase or 0)))))
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "vortex" then
        particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed
        particle.tex:SetAlpha((particle.maxAlpha or 1) * (0.9 + (0.1 * math_sin(particle.life * 1.4))))
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        SetTextureRotation(particle.tex, particle.rot)
        return
    end

    if particle.kind == "glow" then
        local damping = particle.family == "holy" and 0.88 or particle.family == "moon" and 0.91 or
            (particle.family == "nature" or particle.family == "monk") and 0.90 or 0.88
        local wobble = particle.family == "holy" and 10 or particle.family == "moon" and 7.5 or
            (particle.family == "nature" or particle.family == "monk") and 10 or 12
        local fadeStart = particle.family == "holy" and 0.2 or particle.family == "moon" and 0.22 or
            (particle.family == "nature" or particle.family == "monk") and 0.2 or 0.15
        local fadeEnd = particle.family == "holy" and 0.75 or particle.family == "moon" and 0.82 or
            (particle.family == "nature" or particle.family == "monk") and 0.8 or 0.75
        local tail = particle.family == "holy" and 0.25 or particle.family == "moon" and 0.18 or
            (particle.family == "nature" or particle.family == "monk") and 0.2 or 0.25
        particle.vy = (particle.vy or 0) * damping
        particle.y = particle.y + particle.vy * elapsed +
            math_sin((particle.life * wobble) + (particle.phase or 0)) * 0.4
        local alphaEnvelope
        if progress < fadeStart then
            alphaEnvelope = progress / fadeStart
        elseif progress < fadeEnd then
            alphaEnvelope = 1
        else
            alphaEnvelope = math_max(0, (1 - progress) / tail)
        end
        particle.tex:SetAlpha(alphaEnvelope * (particle.maxAlpha or 1))
        SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
        return
    end

    particle.x = particle.x + particle.vx * elapsed
    particle.y = particle.y + particle.vy * elapsed + math_sin((particle.life * (particle.waveFreq or 2)) +
        (particle.phase or 0)) * (particle.waveAmp or 0)
    particle.rot = particle.rot + (particle.rotSpeed or 0) * elapsed

    local alphaEnvelope
    if progress < 0.18 then
        alphaEnvelope = progress / 0.18
    elseif progress < 0.75 then
        alphaEnvelope = 1
    else
        alphaEnvelope = (1 - progress) / 0.25
    end

    particle.tex:SetAlpha(math_max(0, alphaEnvelope) * (particle.maxAlpha or 1))
    SetFantasyTexturePoint(fx, particle.tex, particle.x, particle.y)
    if particle.kind == "ambient" and fx.theme == "nature" then
        SetTextureRotation(particle.tex, particle.rot)
    end
end

local function UpdateFantasyBolt(fx, bolt, elapsed)
    if not bolt.active then
        return
    end

    bolt.life = bolt.life + elapsed
    local progress = bolt.maxLife > 0 and (bolt.life / bolt.maxLife) or 1
    if progress >= 1 then
        ResetFantasyBolt(bolt)
        return
    end

    bolt.tex:SetAlpha(((1 - progress) * (1 - progress)) * (bolt.maxAlpha or 1))
    SetFantasyTexturePoint(fx, bolt.tex, bolt.x, bolt.y)
end

function UnitFrames:SyncFantasyCastbarVisuals(castbar, force)
    local fx = self:EnsureFantasyCastbarVisuals(castbar)
    if not fx then
        return
    end

    local style = castbar._twichCastbarStyle or "modern"
    fx.enabled = style == "fantasy"
    if not fx.enabled then
        HideFantasyCastbarVisuals(fx)
        return
    end

    local theme = castbar._twichFantasyTheme or "holy"
    if force or fx.theme ~= theme then
        self:ResetFantasyCastbarVisuals(castbar)
        fx.theme = theme
    end

    local width = math_max(1, castbar:GetWidth() or 1)
    local height = math_max(1, castbar:GetHeight() or 1)
    if force or fx.width ~= width or fx.height ~= height then
        self:LayoutFantasyCastbarVisuals(castbar)
    end

    if not castbar:IsShown() then
        HideFantasyCastbarVisuals(fx)
        return
    end

    fx.overlay:Show()
    fx.sheenFrame:Hide()
    fx.particleLayer:Show()

    local _, maxValue = castbar:GetMinMaxValues()
    local value = tonumber(castbar:GetValue()) or 0
    local maxSafe = tonumber(maxValue) or 0
    local progress = maxSafe > 0 and Clamp(value / maxSafe, 0, 1) or 0
    local reverse = castbar.channeling == true or castbar._twichReverse == true
    local visualProgress = reverse and (1 - progress) or progress
    local marginL, marginR = GetFantasyThemeFillMargins(theme)
    local fillLeftX = (fx.artWidth or width) * marginL
    local fillWidth = (fx.artWidth or width) * (1 - marginL - marginR)
    fx.visualProgress = visualProgress
    fx.fillLeftX = fillLeftX
    fx.fillWidth = fillWidth

    if force or progress ~= fx.progress then
        fx.progress = progress
        fx.progressMask:SetWidth(math_max(1, math_floor(((fx.artWidth or width) * progress) + 0.5)))
    end

    local r, g, b, a = castbar:GetStatusBarColor()
    if force or r ~= fx.baseR or g ~= fx.baseG or b ~= fx.baseB or a ~= fx.baseA then
        local baseColor = { r or 1, g or 1, b or 1, a or 1 }
        local themeColor = GetFantasyThemeColor(theme)
        local highlightColor = MixTowardColor(baseColor, themeColor, 0.58)
        local shadowColor = MixTowardColor(baseColor, { 0.12, 0.05, 0.02, 1 }, 0.68)
        local pulseColor = MixTowardColor(baseColor, themeColor, 0.8)

        SetGradientCompat(fx.fillGlow, "HORIZONTAL",
            shadowColor[1], shadowColor[2], shadowColor[3], 0.18,
            highlightColor[1], highlightColor[2], highlightColor[3], 0.42)
        SetGradientCompat(fx.pulse, "VERTICAL",
            pulseColor[1], pulseColor[2], pulseColor[3], 0.1,
            highlightColor[1], highlightColor[2], highlightColor[3], 0.2)
        fx.sheenLeft:SetVertexColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.85)
        fx.sheenRight:SetVertexColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.85)
        fx.edgeGlow:SetVertexColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.95)
        fx.completionFlash:SetVertexColor(1, 0.82, 0.42, 1)

        if fx.themeBG then
            fx.themeBG:SetAlpha(0)
        end
        if fx.themeFill then
            fx.themeFill:SetAlpha(0)
        end
        if fx.themeLight then
            fx.themeLight:SetAlpha(0)
        end
        if fx.themeFrame then
            fx.themeFrame:SetAlpha(0)
        end

        if castbar.bg and castbar.bg.SetAlpha then
            castbar.bg:SetAlpha(1)
        end

        fx.baseR = r
        fx.baseG = g
        fx.baseB = b
        fx.baseA = a
    end

    fx.pulseBaseAlpha = 0.07 + (0.12 * Clamp(visualProgress, 0, 1))
    fx.edgeBaseAlpha = 0.3 + (0.38 * Clamp(visualProgress, 0, 1))

    if visualProgress >= 0.965 and not fx.finishPulseTriggered then
        fx.finishPulseTriggered = true
        fx.flashAlpha = 0.78
    elseif visualProgress <= 0.05 then
        fx.finishPulseTriggered = false
        fx.flashAlpha = 0
    end

    fx.fillGlow:SetAlpha(0)
    fx.pulse:SetAlpha(0)
    fx.edgeGlow:SetAlpha(0)
end

function UnitFrames:OnFantasyCastbarUpdate(castbar, elapsed)
    local fx = castbar and castbar.TwichFantasy
    if not fx or fx.enabled ~= true then
        return
    end

    self:SyncFantasyCastbarVisuals(castbar)
    if not castbar:IsShown() or not fx.overlay:IsShown() then
        return
    end

    fx.clock = (fx.clock or 0) + (elapsed or 0)

    local width = fx.width or math_max(1, castbar:GetWidth() or 1)
    local height = fx.height or math_max(1, castbar:GetHeight() or 1)
    local sheenWidth = fx.sheenWidth or math_max(24, math_min(width * 0.34, 96))
    local travel = width + (sheenWidth * 2)
    local speed = math_max(40, width * 0.42)
    local offset = -sheenWidth + ((fx.clock * speed) % travel)
    local family = GetFantasyThemeEffectFamily(fx.theme)
    local visualProgress = Clamp(fx.visualProgress or fx.progress or 0, 0, 1)
    local fillLeftX = fx.fillLeftX or 0
    local fillWidth = fx.fillWidth or width
    local frontX = fillLeftX + (fillWidth * visualProgress)
    local effectScale = fx.effectScale or 1
    local densityScale = 1 + ((effectScale - 1) * 0.8)
    local assets = GetFantasyThemeAssets(fx.theme)

    fx.sheenFrame:Hide()

    if fx.themeFill then
        fx.themeFill:SetAlpha(0)
    end
    if fx.themeLight then
        fx.themeLight:SetAlpha(0)
    end
    if fx.themeFrame then
        if fx.theme == "nature" and assets.frames then
            fx.natureFrameTimer = (fx.natureFrameTimer or 0) + elapsed
            if fx.natureFrameTimer >= 0.12 then
                fx.natureFrameTimer = 0
                fx.natureFrameStep = ((fx.natureFrameStep or 1) % #FANTASY_NATURE_FRAME_SEQUENCE) + 1
                fx.themeFrame:SetTexture(assets.frames[FANTASY_NATURE_FRAME_SEQUENCE[fx.natureFrameStep]])
            end
            fx.themeFrame:SetAlpha(0)
        else
            fx.themeFrame:SetAlpha(0)
        end
    end

    fx.pulse:SetAlpha(0)
    fx.edgeGlow:SetAlpha(0)

    if (fx.flashAlpha or 0) > 0 then
        fx.flashAlpha = math_max(0, fx.flashAlpha - ((elapsed or 0) * 2.2))
        fx.completionFlash:SetAlpha(fx.flashAlpha)
    else
        fx.completionFlash:SetAlpha(0)
    end

    if family == "nature" or family == "monk" then
        fx.streamAccumulator = (fx.streamAccumulator or 0) + elapsed
        if fx.streamAccumulator >= ((family == "monk" and 0.16 or 0.12) / densityScale) then
            fx.streamAccumulator = 0
            SpawnFantasyNatureStream(fx)
        end
    else
        fx.streamAccumulator = 0
    end

    fx.frontAccumulator = (fx.frontAccumulator or 0) + elapsed
    fx.ambientAccumulator = (fx.ambientAccumulator or 0) + elapsed
    fx.glowAccumulator = (fx.glowAccumulator or 0) + elapsed

    if family == "holy" then
        if visualProgress < 0.90 and fx.frontAccumulator >= (0.08 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(2, math_floor(effectScale + 1)) do
                SpawnFantasyFrontParticle(fx, frontX)
            end
        end
        if fx.ambientAccumulator >= (0.12 / densityScale) then
            fx.ambientAccumulator = 0
            for _ = 1, math_max(3, math_floor(2 + effectScale)) do
                SpawnFantasyAmbientParticle(fx)
            end
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.02 / densityScale) then
            fx.glowAccumulator = 0
            local count = math.random(2, 4) + math_max(0, math_floor(effectScale - 1))
            for _ = 1, count do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "moon" then
        if visualProgress < 0.90 and fx.frontAccumulator >= (0.08 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(1, math_floor(effectScale + 0.5)) do
                SpawnFantasyFrontParticle(fx, frontX)
            end
        end
        if fx.ambientAccumulator >= (0.12 / densityScale) then
            fx.ambientAccumulator = 0
            for _ = 1, math_max(2, math_floor(1 + effectScale)) do
                SpawnFantasyAmbientParticle(fx)
            end
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.024 / densityScale) then
            fx.glowAccumulator = 0
            local count = math.random(1, 3) + math_max(0, math_floor(effectScale - 1))
            for _ = 1, count do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "nature" then
        if visualProgress > 0.02 and visualProgress < 0.90 and fx.frontAccumulator >= (0.027 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(1, math_floor(effectScale)) do
                SpawnFantasyFrontParticle(fx, frontX)
            end
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.02 / densityScale) then
            fx.glowAccumulator = 0
            local count = math.random(2, 4) + math_max(0, math_floor(effectScale - 1))
            for _ = 1, count do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "monk" then
        if visualProgress > 0.02 and visualProgress < 0.90 and fx.frontAccumulator >= (0.045 / densityScale) then
            fx.frontAccumulator = 0
            SpawnFantasyFrontParticle(fx, frontX)
            SpawnFantasyEmberParticle(fx, frontX, "metal")
        end
        if fx.theme == "mistweaver" and CountFantasyParticles(fx, "mist") < 3 then
            SpawnFantasyMistParticle(fx)
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.024 / densityScale) then
            fx.glowAccumulator = 0
            local count = math.random(2, 3) + math_max(0, math_floor(effectScale - 1))
            for _ = 1, count do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "earth" then
        local rockCount = 0
        local debrisCount = 0
        for index = 1, #fx.particles do
            local particle = fx.particles[index]
            if particle.active and particle.kind == "earth-orbiter" then
                if particle.isRock then
                    rockCount = rockCount + 1
                else
                    debrisCount = debrisCount + 1
                end
            end
        end

        while rockCount < 4 do
            SpawnFantasyEarthOrbiter(fx, true)
            rockCount = rockCount + 1
        end
        while debrisCount < 14 do
            SpawnFantasyEarthOrbiter(fx, false)
            debrisCount = debrisCount + 1
        end

        if visualProgress > 0.02 and visualProgress < 0.87 and fx.frontAccumulator >= (0.035 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(1, math_floor(effectScale)) do
                SpawnFantasyFrontParticle(fx, frontX)
            end
        end
    elseif family == "metal" then
        if visualProgress < 0.90 and fx.frontAccumulator >= (0.03 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(1, math_floor(effectScale)) do
                SpawnFantasyEmberParticle(fx, frontX, family)
            end
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.02 / densityScale) then
            fx.glowAccumulator = 0
            for _ = 1, math.random(2, 4) do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "fire" then
        if visualProgress < 0.90 and fx.frontAccumulator >= (0.03 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(1, math_floor(effectScale + 0.5)) do
                SpawnFantasyEmberParticle(fx, frontX, family)
            end
        end
        if fx.ambientAccumulator >= (0.08 / densityScale) then
            fx.ambientAccumulator = 0
            SpawnFantasyFireAmbient(fx)
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.024 / densityScale) then
            fx.glowAccumulator = 0
            for _ = 1, math.random(1, 3) do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "frost" then
        while CountFantasyParticles(fx, "mist") < (fx.theme == "arctic" and 4 or fx.theme == "frostfire" and 4 or 3) do
            SpawnFantasyMistParticle(fx)
        end
        if visualProgress < 0.92 and fx.frontAccumulator >= (0.06 / densityScale) then
            fx.frontAccumulator = 0
            SpawnFantasyEmberParticle(fx, frontX, "metal")
        end
    elseif family == "water" then
        if visualProgress < 0.90 and fx.frontAccumulator >= (0.03 / densityScale) then
            fx.frontAccumulator = 0
            SpawnFantasyEmberParticle(fx, frontX, "metal")
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.02 / densityScale) then
            fx.glowAccumulator = 0
            for _ = 1, math.random(2, 4) do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
        fx.rippleAccumulator = (fx.rippleAccumulator or 0) + elapsed
        if fx.rippleAccumulator >= ((fx.theme == "fishing" and 0.34 or 0.45) / densityScale) then
            fx.rippleAccumulator = 0
            SpawnFantasyRippleParticle(fx)
        end
        if fx.theme == "fishing" and CountFantasyParticles(fx, "mist") < 2 then
            SpawnFantasyMistParticle(fx)
        end
    elseif family == "arcane" then
        while CountFantasyParticles(fx, "rune") < (fx.theme == "arcaneum" and 3 or 2) do
            SpawnFantasyRuneParticle(fx)
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.025 / densityScale) then
            fx.glowAccumulator = 0
            for _ = 1, math.random(2, 3) do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "void" then
        if CountFantasyParticles(fx, "vortex") < 1 then
            SpawnFantasyVortexParticle(fx)
        end
        if visualProgress < 0.90 and fx.frontAccumulator >= (0.025 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(1, math_floor(effectScale + 0.5)) do
                SpawnFantasyEmberParticle(fx, frontX, family)
            end
        end
        if visualProgress < 0.87 and fx.glowAccumulator >= (0.03 / densityScale) then
            fx.glowAccumulator = 0
            for _ = 1, math.random(1, 3) do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    elseif family == "gather" then
        if visualProgress > 0.02 and visualProgress < 0.90 and fx.frontAccumulator >= (0.04 / densityScale) then
            fx.frontAccumulator = 0
            for _ = 1, math_max(1, math_floor(effectScale + 0.2)) do
                SpawnFantasyEmberParticle(fx, frontX, family)
            end
        end
    elseif family == "thunder" then
        if fx.clock >= (fx.nextBoltAt or 0) and frontX > (fillLeftX + 10) then
            fx.nextBoltAt = fx.clock + RandomRange(0.18, 0.58)
            SpawnFantasyThunderBolt(fx, frontX)
        end
        if visualProgress < 0.90 and fx.glowAccumulator >= (0.025 / densityScale) then
            fx.glowAccumulator = 0
            local count = math.random(2, 4) + math_max(0, math_floor(effectScale - 1))
            for _ = 1, count do
                SpawnFantasyGlowParticle(fx, frontX)
            end
        end
    end

    for index = 1, #fx.particles do
        UpdateFantasyParticle(fx, fx.particles[index], elapsed)
    end
    for index = 1, #fx.bolts do
        UpdateFantasyBolt(fx, fx.bolts[index], elapsed)
    end
end

function UnitFrames:ApplyCastbarValue(bar, value, maxValue)
    if not bar or not bar.SetMinMaxValues or not bar.SetValue then return end
    local sm = self:GetCastbarSmoothingMethod()
    bar.smoothing = sm
    pcall(bar.SetMinMaxValues, bar, 0, maxValue)
    if sm then
        local ok = pcall(bar.SetValue, bar, value, sm)
        if ok then
            self:SyncFantasyCastbarVisuals(bar)
            return
        end
    end
    pcall(bar.SetValue, bar, value)
    self:SyncFantasyCastbarVisuals(bar)
end

function UnitFrames:ApplyUnitCastbarSettings(frame, unitKey)
    if not frame.Castbar then return end
    local db              = self:GetDB()
    local scope           = ResolveCastbarScopeByUnitKey(unitKey)
    local cfg             = (db.castbars and db.castbars[scope]) or {}
    local enabled         = cfg.enabled ~= false
    local style           = cfg.style or "modern"
    local fantasyTheme    = cfg.fantasyTheme or "holy"
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
    frame.Castbar._twichCastbarStyle = style
    frame.Castbar._twichFantasyTheme = fantasyTheme
    frame.Castbar._twichFantasyEffectScale = cfg.fantasyEffectScale or 1
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
    self:SyncFantasyCastbarVisuals(frame.Castbar, true)
end

local function ApplyHighlightGlow(glowFrame, color)
    if not glowFrame then return end

    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = color[4] or 1

    SetGradientCompat(glowFrame._top, "VERTICAL", r, g, b, a, r, g, b, 0)
    SetGradientCompat(glowFrame._bottom, "VERTICAL", r, g, b, 0, r, g, b, a)
    SetGradientCompat(glowFrame._left, "HORIZONTAL", r, g, b, 0, r, g, b, a)
    SetGradientCompat(glowFrame._right, "HORIZONTAL", r, g, b, a, r, g, b, 0)
end

local function ShowHighlightElements(borderFrame, glowFrame, mode, color)
    if mode == "glow" and glowFrame then
        ApplyHighlightGlow(glowFrame, color)
        glowFrame:Show()
        if borderFrame then
            borderFrame:Hide()
        end
    elseif borderFrame then
        borderFrame:SetBackdropBorderColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        borderFrame:Show()
        if glowFrame then
            glowFrame:Hide()
        end
    elseif glowFrame then
        ApplyHighlightGlow(glowFrame, color)
        glowFrame:Show()
    end
end

local function CreateGlowContainer(frame, frameLevel)
    local glowContainer = CreateFrame("Frame", nil, frame)
    glowContainer:SetAllPoints(frame)
    glowContainer:SetFrameLevel(frameLevel)
    glowContainer:SetClipsChildren(false)
    glowContainer:Hide()

    local function MakeGlowTexture()
        local texture = glowContainer:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        texture:SetBlendMode("ADD")
        return texture
    end

    glowContainer._top = MakeGlowTexture()
    glowContainer._bottom = MakeGlowTexture()
    glowContainer._left = MakeGlowTexture()
    glowContainer._right = MakeGlowTexture()

    return glowContainer
end

local function IsHostileUnitForHighlight(unit)
    if not unit or unit == "" or not UnitExists(unit) then
        return false
    end

    local okAttack, canAttack = pcall(UnitCanAttack, "player", unit)
    if okAttack and canAttack == true then
        return true
    end

    local okFriend, isFriend = pcall(UnitIsFriend, "player", unit)
    return okFriend and isFriend == false
end

function UnitFrames:BuildEnemyTargetLookup()
    local lookup = {}

    local function CaptureTargetedUnit(hostileUnit)
        if not IsHostileUnitForHighlight(hostileUnit) then
            return
        end

        local targetUnit = hostileUnit .. "target"
        if not UnitExists(targetUnit) then
            return
        end

        local guid = ReadSafeUnitGUID(targetUnit)
        if guid then
            lookup[guid] = true
        end
    end

    CaptureTargetedUnit("target")
    CaptureTargetedUnit("focus")

    for index = 1, 5 do
        CaptureTargetedUnit("boss" .. index)
        CaptureTargetedUnit("arena" .. index)
    end

    for index = 1, 40 do
        CaptureTargetedUnit("nameplate" .. index)
    end

    return lookup
end

function UnitFrames:RefreshHighlightFrames(enemyTargetLookup)
    enemyTargetLookup = enemyTargetLookup or self:BuildEnemyTargetLookup()

    for _, frame in pairs(self.frames) do
        if frame then
            self:UpdateUnitHighlights(frame, enemyTargetLookup)
        end
    end

    for _, header in pairs(self.headers) do
        if header then
            for index = 1, select('#', header:GetChildren()) do
                local child = select(index, header:GetChildren())
                if child then
                    self:UpdateUnitHighlights(child, enemyTargetLookup)
                end
            end
        end
    end
end

function UnitFrames:UpdateUnitHighlights(frame, enemyTargetLookup)
    if not frame then return end
    local db = self:GetDB()
    local highlights = db.highlights or {}
    local unit = frame.unit or (frame.GetAttribute and frame:GetAttribute("unit"))
    local unitKey = frame._unitKey or unit
    -- Per-unit overrides stored at db.units[unitKey].highlights
    local unitHL = (db.units and db.units[unitKey] and db.units[unitKey].highlights) or {}
    local targetEnabled = highlights.showTarget ~= false and unitHL.showTarget ~= false
    local mouseoverEnabled = highlights.showMouseover ~= false and unitHL.showMouseover ~= false
    local threatEnabled = highlights.showThreat == true and unitHL.showThreat ~= false
    local enemyTargetEnabled = highlights.showEnemyTarget == true and unitHL.showEnemyTarget ~= false

    -- Reset both target elements before deciding which to show
    if frame.TwichTargetHighlight then frame.TwichTargetHighlight:Hide() end
    if frame.TwichTargetGlow then frame.TwichTargetGlow:Hide() end
    if frame.TwichThreatHighlight then frame.TwichThreatHighlight:Hide() end
    if frame.TwichThreatGlow then frame.TwichThreatGlow:Hide() end
    if frame.TwichEnemyTargetHighlight then frame.TwichEnemyTargetHighlight:Hide() end
    if frame.TwichEnemyTargetGlow then frame.TwichEnemyTargetGlow:Hide() end

    if targetEnabled then
        local showTarget = false
        if unit and unit ~= "" then
            local ok, isUnit = pcall(_G.UnitIsUnit, unit, "target")
            showTarget = ok and isUnit == true
        end
        if showTarget then
            local c = highlights.targetColor or { 1.0, 0.82, 0.0, 0.9 }
            local mode = highlights.targetMode or "border"
            ShowHighlightElements(frame.TwichTargetHighlight, frame.TwichTargetGlow, mode, c)
        end
    end

    if threatEnabled and unit and unit ~= "" then
        local threatStatus = UnitThreatSituation(unit)
        if threatStatus and threatStatus >= 2 then
            local c = highlights.threatColor or { 1.0, 0.24, 0.18, 0.95 }
            local mode = highlights.threatMode or "glow"
            ShowHighlightElements(frame.TwichThreatHighlight, frame.TwichThreatGlow, mode, c)
        end
    end

    if enemyTargetEnabled and unit and unit ~= "" then
        local unitGuid = ReadSafeUnitGUID(unit)
        local targetedLookup = enemyTargetLookup or self:BuildEnemyTargetLookup()
        if unitGuid and targetedLookup[unitGuid] then
            local c = highlights.enemyTargetColor or { 1.0, 0.55, 0.18, 0.85 }
            local mode = highlights.enemyTargetMode or "border"
            ShowHighlightElements(frame.TwichEnemyTargetHighlight, frame.TwichEnemyTargetGlow, mode, c)
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
    local targetWidth = Clamp(highlights.targetWidth or 2, 1, 12)
    local threatWidth = Clamp(highlights.threatWidth or 3, 1, 16)
    local enemyTargetWidth = Clamp(highlights.enemyTargetWidth or 2, 1, 16)

    local function IsReasonableHighlightSize(targetFrame)
        if not targetFrame or type(targetFrame.GetWidth) ~= "function" or type(targetFrame.GetHeight) ~= "function" then
            return false
        end

        local width = tonumber(targetFrame:GetWidth()) or 0
        local height = tonumber(targetFrame:GetHeight()) or 0
        if width <= 0 or height <= 0 then
            return false
        end

        return width < 8192 and height < 8192
    end

    local function ApplyBorderFrame(borderFrame, width)
        if not borderFrame then return end
        borderFrame:ClearAllPoints()
        borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -width, width)
        borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", width, -width)
        if not IsReasonableHighlightSize(frame) then
            borderFrame:Hide()
            return
        end
        borderFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = width })
    end

    local function ApplyGlowFrame(glowFrame, width)
        if not glowFrame then return end
        local spread = math_max(4, width * 3)
        glowFrame._top:ClearAllPoints()
        glowFrame._top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
        glowFrame._top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, spread)
        glowFrame._bottom:ClearAllPoints()
        glowFrame._bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
        glowFrame._bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -spread)
        glowFrame._left:ClearAllPoints()
        glowFrame._left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
        glowFrame._left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -spread, 0)
        glowFrame._right:ClearAllPoints()
        glowFrame._right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
        glowFrame._right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", spread, 0)
    end

    if frame.TwichTargetHighlight then
        ApplyBorderFrame(frame.TwichTargetHighlight, targetWidth)
    end
    if frame.TwichTargetGlow then
        ApplyGlowFrame(frame.TwichTargetGlow, targetWidth)
    end
    if frame.TwichThreatHighlight then
        ApplyBorderFrame(frame.TwichThreatHighlight, threatWidth)
    end
    if frame.TwichThreatGlow then
        ApplyGlowFrame(frame.TwichThreatGlow, threatWidth)
    end
    if frame.TwichEnemyTargetHighlight then
        ApplyBorderFrame(frame.TwichEnemyTargetHighlight, enemyTargetWidth)
    end
    if frame.TwichEnemyTargetGlow then
        ApplyGlowFrame(frame.TwichEnemyTargetGlow, enemyTargetWidth)
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

        UFDebugVerbose(self, string.format("ApplyUnitFrameSize: key=%s size=%dx%d powerH=%d detached=%s showPower=%s",
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
            showPower = group.showPower ~= false,
            powerHeight = 8,
        }
    elseif unitKey == "raidMember" then
        local group = self:GetGroupSettings("raid")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = group.showPower ~= false,
            powerHeight = 7,
        }
    elseif unitKey == "tankMember" then
        local group = self:GetGroupSettings("tank")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = group.showPower ~= false,
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
    frame:SetAlpha(self:GetBaseFrameAlpha())
    self:ConfigureRangeFade(frame, unitKey)

    -- Header children (party/raid/tank members) have their visibility fully managed
    -- by SecureGroupHeaderTemplate + RegisterUnitWatch.  Calling SetShown from insecure
    -- code interferes with that mechanism and can cause frames to stay hidden even when
    -- the unit exists.  Only apply explicit show/hide for standalone (non-header) frames.
    if not frame.isHeaderChild then
        frame._forceHideFrame = db.testMode == true and not frame._isTestPreview
        local shouldShow = settings.enabled ~= false

        if shouldShow and frame._isTestPreview ~= true and unitKey ~= "player" then
            local resolvedUnit = ResolveFrameUnit(frame) or frame.unit
            if not resolvedUnit or resolvedUnit == "" or not UnitExists(resolvedUnit) then
                shouldShow = false
            end
        end

        if frame._forceHideFrame then
            shouldShow = false
        end
        frame._twichNoUnitHidden = (not shouldShow)
            and frame._forceHideFrame ~= true
            and frame._isTestPreview ~= true
            and unitKey ~= "player"
        frame:SetShown(shouldShow)
    end

    self:ApplyStatusBarTexture(frame)
    self:ApplyFrameColors(frame, unitKey)
    self:ApplyHealPredictionSettings(frame, unitKey)
    if frame.HealthPrediction and frame.HealthPrediction.ForceUpdate and frame.unit then
        frame.HealthPrediction:ForceUpdate()
    end
    self:ApplyFrameFonts(frame, unitKey)
    self:ApplyTextTags(frame, unitKey)
    self:ApplyTextPositions(frame, unitKey)
    self:ApplyAuraSettings(frame, unitKey)
    self:ApplyTagVisibility(frame)
    self:ApplyClassBarSettings(frame, unitKey)
    self:ApplyPlayerClassArtworkSettings(frame, unitKey)
    self:ApplyHighlightSettings(frame)
    self:ApplyUnitCastbarSettings(frame, unitKey)
    self:ApplyRoleIconSettings(frame, unitKey)
    self:ApplyStateIndicatorSettings(frame, unitKey, "combatIndicator")
    self:ApplyStateIndicatorSettings(frame, unitKey, "restingIndicator")
    self:ApplyStateIndicatorSettings(frame, unitKey, "spiritIndicator")
    self:ApplyReadyCheckIndicatorSettings(frame, unitKey)
    self:ApplyInfoBarSettings(frame, unitKey)
end

function UnitFrames:PositionPlayerClassArtwork(frame, offsetX, offsetY)
    local artwork = frame and frame.TwichPlayerClassArtwork
    if not artwork then
        return
    end

    artwork:ClearAllPoints()
    artwork:SetPoint("TOPLEFT", frame, "TOPLEFT", tonumber(offsetX) or 0, tonumber(offsetY) or 0)
end

function UnitFrames:UpdatePlayerClassArtworkDrag(frame)
    local artwork = frame and frame.TwichPlayerClassArtwork
    if not artwork or not artwork._dragging then
        return
    end

    local scale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = _G.GetCursorPosition()
    local scaledX = cursorX / scale
    local scaledY = cursorY / scale
    local nextOffsetX = (artwork._dragStartOffsetX or 0) + (scaledX - (artwork._dragStartCursorX or scaledX))
    local nextOffsetY = (artwork._dragStartOffsetY or 0) + (scaledY - (artwork._dragStartCursorY or scaledY))

    artwork._pendingOffsetX = nextOffsetX
    artwork._pendingOffsetY = nextOffsetY
    self:PositionPlayerClassArtwork(frame, nextOffsetX, nextOffsetY)
end

function UnitFrames:StopPlayerClassArtworkDrag(frame, shouldPersist)
    local artwork = frame and frame.TwichPlayerClassArtwork
    if not artwork or not artwork._dragging then
        return
    end

    artwork._dragging = false
    artwork:SetScript("OnUpdate", nil)

    local offsetX = RoundToNearestInteger(artwork._pendingOffsetX or artwork._dragStartOffsetX or 0)
    local offsetY = RoundToNearestInteger(artwork._pendingOffsetY or artwork._dragStartOffsetY or 0)

    if shouldPersist ~= false then
        local settings = self:GetUnitSettings("player")
        settings.classArtworkOffsetX = offsetX
        settings.classArtworkOffsetY = offsetY
        T:Print(string.format("[TwichUI] Player class artwork offsets: x=%d y=%d", offsetX, offsetY))
    end

    artwork._pendingOffsetX = nil
    artwork._pendingOffsetY = nil
    artwork._dragStartCursorX = nil
    artwork._dragStartCursorY = nil
    artwork._dragStartOffsetX = nil
    artwork._dragStartOffsetY = nil

    self:PositionPlayerClassArtwork(frame, offsetX, offsetY)
end

function UnitFrames:StartPlayerClassArtworkDrag(frame)
    local artwork = frame and frame.TwichPlayerClassArtwork
    if not artwork or self._playerClassArtworkAlignmentMode ~= true then
        return
    end

    local settings = self:GetUnitSettings("player")
    local scale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = _G.GetCursorPosition()

    artwork._dragging = true
    artwork._dragStartCursorX = cursorX / scale
    artwork._dragStartCursorY = cursorY / scale
    artwork._dragStartOffsetX = tonumber(settings.classArtworkOffsetX) or 0
    artwork._dragStartOffsetY = tonumber(settings.classArtworkOffsetY) or 0
    artwork._pendingOffsetX = artwork._dragStartOffsetX
    artwork._pendingOffsetY = artwork._dragStartOffsetY
    artwork:SetScript("OnUpdate", function()
        UnitFrames:UpdatePlayerClassArtworkDrag(frame)
    end)
end

function UnitFrames:IsPlayerClassArtworkAlignmentModeEnabled()
    return self._playerClassArtworkAlignmentMode == true
end

function UnitFrames:SetPlayerClassArtworkAlignmentMode(enabled)
    local nextState = enabled == true
    if self._playerClassArtworkAlignmentMode == nextState then
        return
    end

    self._playerClassArtworkAlignmentMode = nextState
    self:RefreshAllFrames()

    if nextState then
        T:Print(
            "[TwichUI] Player class artwork alignment enabled. Drag the artwork, then use /tui artwork again when finished.")
    else
        T:Print("[TwichUI] Player class artwork alignment disabled.")
    end
end

function UnitFrames:TogglePlayerClassArtworkAlignmentMode()
    local settings = self:GetUnitSettings("player")
    if settings.classArtworkEnabled ~= true then
        T:Print("[TwichUI] Enable Class Corner Artwork on the player frame before aligning it.")
        return
    end

    if not GetPlayerClassArtworkDefinition() then
        T:Print("[TwichUI] No class corner artwork is available for your class yet.")
        return
    end

    self:SetPlayerClassArtworkAlignmentMode(not self:IsPlayerClassArtworkAlignmentModeEnabled())
end

function UnitFrames:PrintPlayerClassArtworkOffsets()
    local settings = self:GetUnitSettings("player")
    local offsetX = RoundToNearestInteger(settings.classArtworkOffsetX or 0)
    local offsetY = RoundToNearestInteger(settings.classArtworkOffsetY or 0)
    T:Print(string.format("[TwichUI] Player class artwork offsets: x=%d y=%d", offsetX, offsetY))
end

function UnitFrames:ApplyPlayerClassArtworkSettings(frame, unitKey)
    local artwork = frame and frame.TwichPlayerClassArtwork
    if not artwork then
        return
    end

    if unitKey ~= "player" then
        if artwork._dragging then
            self:StopPlayerClassArtworkDrag(frame, false)
        end
        artwork:Hide()
        return
    end

    local settings = self:GetUnitSettings("player")
    local definition = GetPlayerClassArtworkDefinition()
    local shouldShow = settings.classArtworkEnabled == true and definition ~= nil

    if not shouldShow then
        if artwork._dragging then
            self:StopPlayerClassArtworkDrag(frame, false)
        end
        artwork:EnableMouse(false)
        if artwork.Border then artwork.Border:Hide() end
        if artwork.Hint then artwork.Hint:Hide() end
        artwork:Hide()
        return
    end

    if not definition then
        artwork:Hide()
        return
    end

    local artworkScale = Clamp(settings.classArtworkScale or 1, 0.5, 2.5)
    local artworkWidth = definition.width * artworkScale
    local artworkHeight = definition.height * artworkScale
    local artworkTexture = definition.texture

    artwork._definition = definition
    artwork._scale = artworkScale
    artwork:SetSize(artworkWidth, artworkHeight)
    artwork.Texture:SetTexture(artworkTexture)
    artwork.Texture:SetVertexColor(1, 1, 1, 1)
    self:PositionPlayerClassArtwork(frame, settings.classArtworkOffsetX or 0, settings.classArtworkOffsetY or 0)

    local alignMode = self._playerClassArtworkAlignmentMode == true
    if not alignMode and artwork._dragging then
        self:StopPlayerClassArtworkDrag(frame, false)
    end
    artwork:EnableMouse(alignMode)
    if artwork.Border then artwork.Border:SetShown(alignMode) end
    if artwork.Hint then artwork.Hint:SetShown(alignMode) end
    artwork:Show()
end

function UnitFrames:ApplyHeaderSettings(header, groupKey)
    local settings = self:GetGroupSettings(groupKey)
    local layout = self:GetLayoutSettings(groupKey)
    local testMode = self:GetDB().testMode == true
    local growthDirection = ResolveGroupGrowthDirection(settings, "DOWN")

    local enabled = settings.enabled ~= false
    UFDebugVerbose(self, string.format("ApplyHeaderSettings: key=%s enabled=%s layout=(%s,%s,%.0f,%.0f)",
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

    header:SetAttribute("point", ResolveHeaderPoint(settings, settings.point or "TOP"))
    header:SetAttribute("xOffset", ResolveHeaderXOffset(settings, growthDirection, 0))
    header:SetAttribute("yOffset", ResolveHeaderYOffset(settings, -6, growthDirection))
    local defaultUnitsPerColumn = (groupKey == "tank" and 2) or 5
    local defaultMaxColumns = (groupKey == "raid" and 4) or 1
    local unitsPerColumn, maxColumns = ResolveGroupHeaderCounts(groupKey, settings, defaultUnitsPerColumn,
        defaultMaxColumns)
    header:SetAttribute("unitsPerColumn", unitsPerColumn)
    header:SetAttribute("maxColumns", maxColumns)
    header:SetAttribute("columnSpacing", tonumber(settings.columnSpacing) or 8)
    header:SetAttribute("columnAnchorPoint",
        ResolveHeaderColumnAnchorPoint(settings, growthDirection, settings.columnAnchorPoint or "LEFT"))

    if groupKey == "party" then
        header:SetAttribute("showParty", enabled)
        header:SetAttribute("showPlayer", settings.showPlayer == true)
        header:SetAttribute("showSolo", settings.showSolo == true)
        UFDebugVerbose(self, string.format("ApplyHeaderSettings: party showParty=%s showPlayer=%s showSolo=%s",
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
        local roleFilter = NormalizeHeaderFilterValue(settings.roleFilter) or "TANK"
        local groupFilter = NormalizeHeaderFilterValue(settings.groupFilter)
        header:SetAttribute("showRaid", enabled)
        header:SetAttribute("showParty", false)
        header:SetAttribute("showSolo", settings.showSolo == true)
        header:SetAttribute("roleFilter", roleFilter)
        header:SetAttribute("groupFilter", groupFilter)
        if enabled and not testMode then
            header:SetVisibility('raid')
        else
            header:SetVisibility('custom hide')
        end
    end

    header:SetScale(Clamp(self:GetDB().scale or 1, 0.6, 1.6))
    header:SetAlpha(self:GetBaseFrameAlpha())

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
                self:ApplySingleFrameSettings(child, memberUnitKey)
                -- Re-evaluate healer-only power bar visibility immediately so layout
                -- changes take effect without waiting for the next power event.
                if child.Power then
                    -- child.unit / GetAttribute("unit") on secure-header children is a
                    -- tainted "secret" string — safe to PASS to WoW APIs but NOT to
                    -- format into strings. Log only the safe memberUnitKey.
                    local childUnit = child:GetAttribute("unit") or child.unit
                    UFDebugVerbose(self, string.format("ApplyHeaderSettings: UpdatePowerBarForRole child key=%s",
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
    local bossUnit = self:GetUnitSettings("boss")
    local width = Clamp(bossUnit.width or 220, 120, 500)
    local height = Clamp(bossUnit.height or 36, 16, 120)
    local activeCount = CountActiveBossUnits()
    local layoutCount = activeCount > 0 and activeCount or MAX_BOSS_FRAMES
    local geometry = ResolveBossGeometry(settings, width, height, layoutCount)

    self.bossAnchor:ClearAllPoints()
    self.bossAnchor:SetPoint(
        layout.point or "RIGHT",
        UIParent,
        layout.relativePoint or "RIGHT",
        tonumber(layout.x) or -300,
        tonumber(layout.y) or 0
    )
    self.bossAnchor:SetSize(geometry.width, geometry.height)

    local showBossFrames = settings.enabled ~= false and self:GetDB().testMode ~= true
    self.bossAnchor:SetScale(Clamp(self:GetDB().scale or 1, 0.6, 1.6))
    self.bossAnchor:SetAlpha(Clamp(self:GetDB().frameAlpha or 1, 0.15, 1))
    self.bossAnchor:SetShown(showBossFrames and activeCount > 0)

    for index = 1, MAX_BOSS_FRAMES do
        local frame = self.frames["boss" .. index]
        if frame then
            frame:ClearAllPoints()
            local x, y = GetBossFrameOffset(geometry, index)
            frame:SetPoint("TOPLEFT", self.bossAnchor, "TOPLEFT", x, -y)

            local shouldShow = showBossFrames and index <= activeCount
            frame:SetShown(shouldShow)
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
        local moverWidth = Clamp(w or 20, 20, 4096)
        local moverHeight = Clamp(h or 10, 10, 4096)
        mover:SetSize(moverWidth, moverHeight)
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
            local rows, cols = ResolveGroupHeaderCounts(key, gs, entry.defaultRows, 1)
            -- Use the configured maxColumns for ALL group types (not just raid) so
            -- horizontally-arranged party/tank layouts get an accurate mover size.
            local geometry = BuildGroupGeometry(gs, w, rowH, rows, cols, 6, 8, "DOWN", gs.columnAnchorPoint or "LEFT")
            UFDebugVerbose(self, string.format("UpdateMovers: %s mover dir=%s rows=%d cols=%d mw=%d mh=%d enabled=%s",
                key, tostring(geometry.growthDirection), rows, cols, geometry.width, geometry.height,
                tostring(gs.enabled ~= false)))
            PlaceMover(mover,
                layout.point or "CENTER", layout.relativePoint or layout.point or "CENTER",
                tonumber(layout.x) or 0, tonumber(layout.y) or 0,
                geometry.width, geometry.height, gs.enabled ~= false)
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
            local geometry = ResolveBossGeometry(gs, w, rowH, MAX_BOSS_FRAMES)
            PlaceMover(mover,
                layout.point or "RIGHT", layout.relativePoint or layout.point or "RIGHT",
                tonumber(layout.x) or -300, tonumber(layout.y) or 0,
                geometry.width, geometry.height, gs.enabled ~= false)
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

    if type(layoutKey) == "string" and layoutKey:match("^boss%d+$") then
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

do

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
    local isDead = (unitKey == "partyMember" or unitKey == "raidMember" or unitKey == "tankMember") and index == 2
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

    if isDead then
        healthCur = 0
        powerCur = 0
        castProgress = 0
    end

    return {
        index = index,
        name = name,
        role = role,
        inCombat = unitKey ~= "player" and unitKey ~= "pet" and not (unitKey == "partyMember" and index == 1),
        isDead = isDead,
        isResting = unitKey == "player" or ((unitKey == "partyMember" or unitKey == "raidMember") and index == 1),
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
        incomingPlayer = math.floor(healthMax * 0.12),
        incomingOther = math.floor(healthMax * 0.07),
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
    frame._testInCombat = state.inCombat == true
    frame._testIsDead = state.isDead == true
    frame._testIsResting = state.isResting == true and state.inCombat ~= true
    frame._testReadyStatus = state.readyStatus or "ready"

    self:ApplySingleFrameSettings(frame, unitKey)

    if frame.Health then
        self:ApplySmoothBarValue(frame.Health, state.healthCur, state.healthMax)
    end
    if frame.Power then
        self:ApplySmoothBarValue(frame.Power, state.powerCur, state.powerMax)
    end
    self:ApplyPreviewHealPrediction(frame, unitKey, state)

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

    self:UpdateStateIndicator(frame, unitKey, "combatIndicator")
    self:UpdateStateIndicator(frame, unitKey, "restingIndicator")
    self:UpdateStateIndicator(frame, unitKey, "spiritIndicator")
    self:UpdateReadyCheckIndicator(frame, unitKey)
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
        self:UpdateStateIndicator(frame, entry.key, "combatIndicator")
        self:UpdateStateIndicator(frame, entry.key, "restingIndicator")
        self:UpdateStateIndicator(frame, entry.key, "spiritIndicator")
        self:UpdateReadyCheckIndicator(frame, entry.key)
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
        local previewStyle = castSettings.style or "modern"
        local previewTheme = castSettings.fantasyTheme or "holy"
        local texName = (castSettings.texture and castSettings.texture ~= "") and castSettings.texture
            or ((db.texture and db.texture ~= "") and db.texture or nil)
        local previewTexture = texName and GetLSMTexture(texName) or GetThemeTexture()
        castPreview:ClearAllPoints()
        castPreview:SetPoint(
            layout.point or "BOTTOM",
            UIParent,
            layout.relativePoint or "BOTTOM",
            tonumber(layout.x) or -260,
            tonumber(layout.y) or 220
        )
        castPreview:SetSize(Clamp(castSettings.width or 260, 120, 600), Clamp(castSettings.height or 20, 10, 60))
        castPreview:SetStatusBarTexture(previewTexture)
        if castSettings.useThemeAccentFill == true then
            local accent = GetThemeColor("accentColor", { 0.96, 0.76, 0.24, 1 })
            castPreview:SetStatusBarColor(accent[1] or 1, accent[2] or 1, accent[3] or 1, accent[4] or 1)
        elseif castSettings.useCustomColor == true and type(castSettings.color) == "table" then
            castPreview:SetStatusBarColor(castSettings.color[1] or 1, castSettings.color[2] or 1,
                castSettings.color[3] or 1, castSettings.color[4] or 1)
        else
            castPreview:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
        end
        castPreview._twichCastbarStyle = previewStyle
        castPreview._twichFantasyTheme = previewTheme
        castPreview._twichFantasyEffectScale = castSettings.fantasyEffectScale or 1
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
        self:SyncFantasyCastbarVisuals(castPreview, true)
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
        local geometry = ResolveBossGeometry(bossGroup, width, height, MAX_BOSS_FRAMES)

        preview.bossAnchor:ClearAllPoints()
        preview.bossAnchor:SetPoint(
            bossLayout.point or "RIGHT",
            UIParent,
            bossLayout.relativePoint or "RIGHT",
            tonumber(bossLayout.x) or -60,
            tonumber(bossLayout.y) or 520
        )
        preview.bossAnchor:SetSize(geometry.width, geometry.height)

        local bossClasses = { "DEATHKNIGHT", "WARLOCK", "MAGE", "WARRIOR", "PRIEST" }
        for index = 1, MAX_BOSS_FRAMES do
            local key = "bossPreview" .. index
            local bossMockClass = bossClasses[index] or "DEATHKNIGHT"
            if not preview[key] then
                preview[key] = self:CreatePreviewFrame(preview.bossAnchor, width, height, "Boss " .. index, "boss",
                    bossMockClass)
            else
                self:UpdatePreviewFrame(preview[key], width, height, "Boss " .. index, "boss", bossMockClass)
            end

            preview[key]:ClearAllPoints()
            local x, y = GetBossFrameOffset(geometry, index)
            preview[key]:SetPoint("TOPLEFT", preview.bossAnchor, "TOPLEFT", x, -y)
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
        local totalMembers = 5
        local unitsPerColumn, maxColumns = ResolveGroupHeaderCounts("party", settings, 5, 1)
        unitsPerColumn = math_min(totalMembers, unitsPerColumn)
        maxColumns = math_max(1, math_min(maxColumns, math.ceil(totalMembers / unitsPerColumn)))
        local geometry = BuildGroupGeometry(settings, width, height, unitsPerColumn, maxColumns, 6, 6, "DOWN",
            settings.columnAnchorPoint or "LEFT")
        PositionContainer(party, layout)
        party:SetSize(geometry.width, geometry.height)
        for index = 1, totalMembers do
            local partyMockClass = PREVIEW_CLASS_TOKENS[((index - 1) % #PREVIEW_CLASS_TOKENS) + 1]
            if not party.rows[index] then
                party.rows[index] = self:CreatePreviewFrame(party, width, height, "Party " .. index, "partyMember",
                    partyMockClass)
            else
                self:UpdatePreviewFrame(party.rows[index], width, height, "Party " .. index, "partyMember",
                    partyMockClass)
            end
            local row = party.rows[index]
            local x, y = GetGroupGeometryOffset(geometry, index)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", party, "TOPLEFT", x, -y)
            row:SetShown(index <= (unitsPerColumn * maxColumns))
        end
    end

    local raid = EnsureContainer("raid")
    do
        local settings = self:GetGroupSettings("raid")
        local layout = self:GetLayoutSettings("raid")
        local width = Clamp(settings.width or 120, 70, 300)
        local height = Clamp(settings.height or 30, 14, 80)
        local totalMembers = 20
        local unitsPerColumn, maxColumns = ResolveGroupHeaderCounts("raid", settings, 5, 4)
        unitsPerColumn = math_min(totalMembers, unitsPerColumn)
        maxColumns = math_max(1, math_min(maxColumns, math.ceil(totalMembers / unitsPerColumn)))
        local geometry = BuildGroupGeometry(settings, width, height, unitsPerColumn, maxColumns, 6, 6, "DOWN",
            settings.columnAnchorPoint or "LEFT")
        PositionContainer(raid, layout)
        raid:SetSize(geometry.width, geometry.height)
        for index = 1, totalMembers do
            local raidMockClass = PREVIEW_CLASS_TOKENS[((index - 1) % #PREVIEW_CLASS_TOKENS) + 1]
            if not raid.rows[index] then
                raid.rows[index] = self:CreatePreviewFrame(raid, width, height, "Raid " .. index, "raidMember",
                    raidMockClass)
            else
                self:UpdatePreviewFrame(raid.rows[index], width, height, "Raid " .. index, "raidMember", raidMockClass)
            end
            local row = raid.rows[index]
            local x, y = GetGroupGeometryOffset(geometry, index)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", raid, "TOPLEFT", x, -y)
            row:SetShown(index <= (unitsPerColumn * maxColumns))
        end
    end

    local tank = EnsureContainer("tank")
    do
        local settings = self:GetGroupSettings("tank")
        local layout = self:GetLayoutSettings("tank")
        local width = Clamp(settings.width or 180, 80, 400)
        local height = Clamp(settings.height or 32, 14, 80)
        local totalMembers = 2
        local unitsPerColumn, maxColumns = ResolveGroupHeaderCounts("tank", settings, 2, 1)
        unitsPerColumn = math_min(totalMembers, unitsPerColumn)
        maxColumns = math_max(1, math_min(maxColumns, math.ceil(totalMembers / unitsPerColumn)))
        local geometry = BuildGroupGeometry(settings, width, height, unitsPerColumn, maxColumns, 6, 6, "DOWN",
            settings.columnAnchorPoint or "LEFT")
        PositionContainer(tank, layout)
        tank:SetSize(geometry.width, geometry.height)
        local tankClasses = { "WARRIOR", "PALADIN" }
        for index = 1, totalMembers do
            local tankMockClass = tankClasses[index] or "WARRIOR"
            if not tank.rows[index] then
                tank.rows[index] = self:CreatePreviewFrame(tank, width, height, "Tank " .. index, "tankMember",
                    tankMockClass)
            else
                self:UpdatePreviewFrame(tank.rows[index], width, height, "Tank " .. index, "tankMember", tankMockClass)
            end
            local row = tank.rows[index]
            local x, y = GetGroupGeometryOffset(geometry, index)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", tank, "TOPLEFT", x, -y)
            row:SetShown(index <= (unitsPerColumn * maxColumns))
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
                if key == "party" then
                    shouldShow = shouldShow and (db.testPreviewParty ~= false)
                elseif key == "raid" then
                    shouldShow = shouldShow and (db.testPreviewRaid ~= false)
                end
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

end

function UnitFrames:ApplyBlizzardPlayerCastbarVisibility()
    local blizzardCastbar = _G.PlayerCastingBarFrame or _G.CastingBarFrame
    if not blizzardCastbar then
        return
    end

    local db = self.GetDB and self:GetDB() or nil
    local isEnabled = not db or db.enabled ~= false

    if isEnabled then
        if blizzardCastbar.IgnoreFramePositionManager ~= true then
            blizzardCastbar.IgnoreFramePositionManager = true
        end
        if not blizzardCastbar._twichUIOriginalParent then
            blizzardCastbar._twichUIOriginalParent = blizzardCastbar:GetParent() or UIParent
        end
        if not blizzardCastbar._twichUIOnShowHooked then
            blizzardCastbar:HookScript("OnShow", function(frame)
                if frame._twichUISuppressCastbar == true then
                    frame:Hide()
                end
            end)
            blizzardCastbar._twichUIOnShowHooked = true
        end
        blizzardCastbar._twichUISuppressCastbar = true
        if blizzardCastbar.UnregisterAllEvents then
            blizzardCastbar:UnregisterAllEvents()
        end
        blizzardCastbar:Hide()
    else
        blizzardCastbar._twichUISuppressCastbar = nil
    end
end

function UnitFrames:ShouldHideBlizzardRaidFrames()
    local db = self.GetDB and self:GetDB() or nil
    if not db or db.enabled == false then
        return false
    end

    local groups = db.groups or {}
    local raidEnabled = not (type(groups.raid) == "table" and groups.raid.enabled == false)
    local tankEnabled = not (type(groups.tank) == "table" and groups.tank.enabled == false)

    return raidEnabled or tankEnabled
end

function UnitFrames:ApplyBlizzardRaidFrameVisibility()
    local suppress = self:ShouldHideBlizzardRaidFrames()
    if not self._blizzardRaidHiddenRoot then
        self._blizzardRaidHiddenRoot = CreateFrame("Frame", nil, UIParent)
        self._blizzardRaidHiddenRoot:Hide()
    end

    local hiddenRoot = self._blizzardRaidHiddenRoot
    local targets = {
        _G.CompactPartyFrame,
        _G.CompactRaidFrameContainer,
        _G.CompactRaidFrameManager,
        _G.CompactRaidFrameManagerContainer,
        _G.CompactRaidFrameManagerDisplayFrame,
    }

    local function ApplySuppression(frame)
        if not frame then
            return
        end

        frame._twichUIOriginalParent = frame._twichUIOriginalParent or frame:GetParent() or UIParent
        if frame._twichUIOriginalIgnoreFramePositionManager == nil then
            frame._twichUIOriginalIgnoreFramePositionManager = frame.IgnoreFramePositionManager
        end

        frame._twichUISuppressRaidFrame = suppress
        if suppress then
            if frame.IgnoreFramePositionManager ~= true then
                frame.IgnoreFramePositionManager = true
            end
            if frame:GetParent() ~= hiddenRoot then
                frame:SetParent(hiddenRoot)
            end
        else
            if frame:GetParent() ~= frame._twichUIOriginalParent then
                frame:SetParent(frame._twichUIOriginalParent)
            end
            frame.IgnoreFramePositionManager = frame._twichUIOriginalIgnoreFramePositionManager
            frame._twichUISuppressRaidFrame = nil
        end
    end

    for _, frame in ipairs(targets) do
        ApplySuppression(frame)
    end
end

local function GetActiveClickCastHeader()
    local clique = _G.Clique
    if type(clique) == "table" and clique.header then
        return clique.header
    end

    return _G.ClickCastHeader
end

function UnitFrames:RefreshHeaderClickCastSupport()
    if InCombatLockdown() then
        self._pendingHeaderClickCastRefresh = true
        return false
    end

    self._pendingHeaderClickCastRefresh = nil

    if type(SecureHandlerSetFrameRef) ~= "function" then
        return false
    end

    local clickCastHeader = GetActiveClickCastHeader()
    if not clickCastHeader then
        return false
    end

    local updated = false

    for _, header in pairs(self.headers or {}) do
        if header then
            local current = header.GetFrameRef and header:GetFrameRef("clickcast_header") or nil
            if current ~= clickCastHeader then
                SecureHandlerSetFrameRef(header, "clickcast_header", clickCastHeader)
                updated = true
            end
        end
    end

    return updated
end

function UnitFrames:OnAddonLoaded(_, addonName)
    if addonName == "Blizzard_CompactRaidFrames" or addonName == "Blizzard_EditMode" then
        self:ApplyBlizzardRaidFrameVisibility()
        return
    end

    if addonName == "Clicked" or addonName == "Clique" then
        self:RefreshHeaderClickCastSupport()
    end
end

function UnitFrames:QueueRefreshAllFrames()
    if self._fullRefreshQueued == true then
        return
    end

    self._fullRefreshQueued = true
    if not (C_Timer and type(C_Timer.After) == "function") then
        self._fullRefreshQueued = false
        self:RefreshAllFrames()
        return
    end

    C_Timer.After(0, function()
        if UnitFrames._fullRefreshQueued ~= true then
            return
        end

        UnitFrames._fullRefreshQueued = false
        if not UnitFrames:IsEnabled() then
            return
        end

        UnitFrames:RefreshAllFrames()
    end)
end

function UnitFrames:RefreshAllFrames(event)
    if type(event) == "string" then
        self:QueueRefreshAllFrames()
        return
    end

    if InCombatLockdown() then
        self._queuedRefresh = true
        return
    end

    self._auraConfigCache = nil

    self:ApplyBlizzardPlayerCastbarVisibility()
    self:ApplyBlizzardRaidFrameVisibility()

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
        if self._forceHideFrame or self._twichNoUnitHidden then
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

    local healingPlayer = CreateFrame("StatusBar", nil, health)
    healingPlayer:SetFrameLevel(health:GetFrameLevel() + 1)
    healingPlayer:SetMinMaxValues(0, 1)
    healingPlayer:SetValue(0)
    healingPlayer:SetPoint("TOP", health, "TOP", 0, 0)
    healingPlayer:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
    healingPlayer:SetPoint("LEFT", health, "LEFT", 0, 0)
    healingPlayer:SetWidth(math_max(1, health:GetWidth()))

    local healingOther = CreateFrame("StatusBar", nil, health)
    healingOther:SetFrameLevel(health:GetFrameLevel() + 1)
    healingOther:SetMinMaxValues(0, 1)
    healingOther:SetValue(0)
    healingOther:SetPoint("TOP", health, "TOP", 0, 0)
    healingOther:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
    healingOther:SetPoint("LEFT", health, "LEFT", 0, 0)
    healingOther:SetWidth(math_max(1, health:GetWidth()))

    frame.HealthPrediction = {
        healingPlayer = healingPlayer,
        healingOther = healingOther,
        incomingHealOverflow = HEAL_PREDICTION_DEFAULTS.maxOverflow,
        PostUpdate = function(element)
            UnitFrames:ApplyHealPredictionSettings(element.__owner, capturedUnitKey)
        end,
    }

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
            UFDebugVerbose(UnitFrames, string.format("ClassPower.PostVisibility: isVisible=%s enabled=%s → container shown=%s",
                tostring(isVisible), tostring(cfg.enabled ~= false), tostring(shouldShow)))
            element.container:SetShown(shouldShow)
        end
        classPower.PostUpdate = function(element, unit2, min2, max2, hasMaxChanged)
            -- Guard: ApplyClassBarSettings calls ForceUpdate which re-fires PostUpdate.
            -- Without this guard the two functions recurse infinitely and freeze the client.
            if element._applyingSettings then
                UFDebugVerbose(UnitFrames, "ClassPower.PostUpdate: skipped (inside ApplyClassBarSettings)")
                return
            end
            UFDebugVerbose(UnitFrames, string.format("ClassPower.PostUpdate: hasMaxChanged=%s",
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

    if capturedUnitKey == "player" and not frame.TwichPlayerClassArtwork then
        local artwork = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        artwork:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        artwork:SetSize(1, 1)
        artwork:SetFrameStrata(frame:GetFrameStrata())
        artwork:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 6))
        artwork:EnableMouse(false)
        artwork:Hide()

        local texture = artwork:CreateTexture(nil, "ARTWORK", nil, 6)
        texture:SetAllPoints(artwork)
        artwork.Texture = texture

        local border = CreateFrame("Frame", nil, artwork, "BackdropTemplate")
        border:SetAllPoints(artwork)
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        border:SetBackdropBorderColor(0.18, 0.82, 1, 0.85)
        border:SetBackdropColor(0, 0, 0, 0)
        border:Hide()
        artwork.Border = border

        local hint = artwork:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOMLEFT", artwork, "TOPLEFT", 0, 6)
        hint:SetText("Drag to align")
        hint:SetTextColor(0.82, 0.94, 1, 0.95)
        hint:Hide()
        artwork.Hint = hint

        artwork:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then
                return
            end
            UnitFrames:StartPlayerClassArtworkDrag(frame)
        end)
        artwork:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then
                return
            end
            UnitFrames:StopPlayerClassArtworkDrag(frame, true)
        end)
        artwork:SetScript("OnHide", function()
            UnitFrames:StopPlayerClassArtworkDrag(frame, false)
        end)

        frame.TwichPlayerClassArtwork = artwork
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
        castbar:SetClipsChildren(false)
        castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
        castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
        castbar:SetHeight(12)
        castbar:SetMinMaxValues(0, 1); castbar:SetValue(0)
        castbar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        castbar.bg = castbar:CreateTexture(nil, "BACKGROUND")
        castbar.bg:SetAllPoints(castbar)
        castbar.bg:SetColorTexture(0.05, 0.06, 0.08, 0.9)
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

    local function CreateBorderHighlight(frameLevel)
        local highlight = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
        highlight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        highlight:SetFrameLevel(frameLevel)
        highlight:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        highlight:SetBackdropBorderColor(1, 1, 1, 0)
        highlight:Hide()
        return highlight
    end

    -- Target highlight
    local targetHL                  = CreateBorderHighlight(math_max(1, frame:GetFrameLevel() + 3))
    frame.TwichTargetHighlight      = targetHL

    frame.TwichTargetGlow           = CreateGlowContainer(frame, math_max(0, frame:GetFrameLevel() - 1))

    frame.TwichThreatHighlight      = CreateBorderHighlight(math_max(1, frame:GetFrameLevel() + 4))
    frame.TwichThreatGlow           = CreateGlowContainer(frame, math_max(0, frame:GetFrameLevel() - 1))

    frame.TwichEnemyTargetHighlight = CreateBorderHighlight(math_max(1, frame:GetFrameLevel() + 5))
    frame.TwichEnemyTargetGlow      = CreateGlowContainer(frame, math_max(0, frame:GetFrameLevel() - 1))

    -- Mouseover highlight
    local hoverHL                   = CreateFrame("Frame", nil, frame, "BackdropTemplate")
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
    frame:SetClipsChildren(false)
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

function UnitFrames:StartStandaloneCastbarUpdates()
    local castbar = self.frames.castbar
    if not castbar or castbar._twichCastbarUpdating == true then
        return
    end

    castbar._twichCastbarUpdating = true
    castbar:SetScript("OnUpdate", function(_, elapsed)
        UnitFrames:UFDiagBump("castbarUpdateTicks", 1)
        UnitFrames:UpdateCastbarElapsed()
        UnitFrames:OnFantasyCastbarUpdate(castbar, elapsed or 0)
        UnitFrames:UFDiagMaybeReport("castbar")
    end)
end

function UnitFrames:StopStandaloneCastbarUpdates()
    local castbar = self.frames.castbar
    if not castbar then
        return
    end

    castbar._twichCastbarUpdating = nil
    castbar:SetScript("OnUpdate", nil)
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
        self:StopStandaloneCastbarUpdates()
        castbar:Hide()
    elseif db.testMode == true then
        castbar._forceHide = true
        self:StopStandaloneCastbarUpdates()
        castbar:Hide()
    elseif not self._castbarState then
        castbar._forceHide = nil
        -- Only show if a cast is actually in progress; hide on initial load / layout refresh.
        self:StopStandaloneCastbarUpdates()
        castbar:Hide()
    else
        castbar._forceHide = nil
        self:StartStandaloneCastbarUpdates()
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
    local style = settings.style or "modern"
    local fantasyTheme = settings.fantasyTheme or "holy"
    local castbarTexture = texName and GetLSMTexture(texName) or GetThemeTexture()
    castbar._twichCastbarStyle = style
    castbar._twichFantasyTheme = fantasyTheme
    castbar._twichFantasyEffectScale = settings.fantasyEffectScale or 1
    castbar:SetStatusBarTexture(castbarTexture)
    castbar.smoothing = self:GetCastbarSmoothingMethod()
    if settings.useThemeAccentFill == true then
        local accent = GetThemeColor("accentColor", { 0.96, 0.76, 0.24, 1 })
        castbar:SetStatusBarColor(accent[1] or 1, accent[2] or 1, accent[3] or 1, accent[4] or 1)
    elseif settings.useCustomColor == true and type(settings.color) == "table" then
        castbar:SetStatusBarColor(settings.color[1] or 1, settings.color[2] or 1, settings.color[3] or 1,
            settings.color[4] or 1)
    else
        castbar:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
    end
    castbar:SetBackdropColor(palette.background[1], palette.background[2], palette.background[3], 0.9)
    castbar:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 0.9)
    if castbar.bg then
        castbar.bg:SetColorTexture(palette.background[1], palette.background[2], palette.background[3], 0.9)
    end
    castbar.spellText:SetShown(settings.showSpellText ~= false)
    castbar.timeText:SetShown(settings.showTimeText ~= false)
    self:ApplyFontObject(castbar.spellText, Clamp(settings.spellFontSize or 11, 6, 24), castbarTextStyle.fontName,
        castbarTextStyle)
    self:ApplyFontObject(castbar.timeText, Clamp(settings.timeFontSize or 10, 6, 24), castbarTextStyle.fontName,
        castbarTextStyle)
    self:SyncFantasyCastbarVisuals(castbar, true)
end

function UnitFrames:UpdateCastbarElapsed()
    self:UFDiagBump("castbarElapsedCalls", 1)
    local state = self._castbarState
    local castbar = self.frames.castbar
    if not state or not castbar then return end

    local duration = math_max(0.001, state.endTime - state.startTime)
    local now = GetTimePreciseSec()

    if now >= state.endTime then
        self:ApplyCastbarValue(castbar, duration, duration)
        if castbar.timeText then castbar.timeText:SetText("0.0") end
        self:StopStandaloneCastbarUpdates()
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
    self:UFDiagBump("castStarts", 1)
    local castbar = self.frames.castbar
    if not castbar then return end
    local startSec = (tonumber(startMS) or 0) / 1000
    local endSec   = (tonumber(endMS) or 0) / 1000
    if startSec <= 0 or endSec <= startSec then return end
    if castbar.spellText then castbar.spellText:SetText(name or "Casting") end
    if castbar.icon then castbar.icon:SetTexture(icon or 136243) end
    local duration = math_max(0.001, endSec - startSec)
    castbar._twichReverse = reverse == true
    self:ResetFantasyCastbarVisuals(castbar)
    self:ApplyCastbarValue(castbar, reverse and duration or 0, duration)
    castbar:Show()
    self._castbarState = { startTime = startSec, endTime = endSec, reverse = reverse == true }
    self:StartStandaloneCastbarUpdates()
end

function UnitFrames:StopCastbar()
    self:UFDiagBump("castStops", 1)
    local castbar = self.frames.castbar
    if castbar then
        castbar._twichReverse = nil
        self:StopStandaloneCastbarUpdates()
        castbar:Hide()
    end
    self._castbarState = nil
end

function UnitFrames:HandlePlayerCastEvent(event, unit, castGUID, spellID)
    self:UFDiagBump("castEvents", 1)
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

    for index = 1, MAX_BOSS_FRAMES do
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
        "roleFilter", "TANK",
        "groupFilter", nil,
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
    local diagCfg = self:GetUFDiagnosticsConfig()
    local diagRt = self._ufDiagRuntime

    tinsert(lines, string.format("Module enabled: %s", tostring(db.enabled)))
    tinsert(lines, string.format("Scale: %.2f  Alpha: %.2f", db.scale or 1, db.frameAlpha or 1))
    tinsert(lines, string.format("Texture: %s", tostring(db.texture or "default")))
    tinsert(lines, string.format("Diagnostics: enabled=%s interval=%.1fs delta=%dkb verbose=%s",
        tostring(diagCfg.enabled == true),
        tonumber(diagCfg.intervalSec) or 2,
        math_floor((tonumber(diagCfg.minMemoryDeltaKB) or 512) + 0.5),
        tostring(diagCfg.verbose == true)))
    if diagRt then
        tinsert(lines, string.format("Diagnostics memory: current=%.2fmb peak=%.2fmb",
            (tonumber(diagRt.lastMemoryKB) or 0) / 1024,
            (tonumber(diagRt.peakMemoryKB) or 0) / 1024))
        local totals = diagRt.total or {}
        tinsert(lines, string.format(
            "Diagnostics totals: awUpdate=%d awScan=%d awCacheHits=%d awSlots=%d awResults=%d auraBars=%d castTicks=%d castEvents=%d",
            totals.awUpdateCalls or 0,
            totals.awScanCalls or 0,
            totals.awScanCacheHits or 0,
            totals.awSlotsScanned or 0,
            totals.awAurasReturned or 0,
            totals.auraBarRefreshCalls or 0,
            totals.castbarUpdateTicks or 0,
            totals.castEvents or 0))
    end
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

    self:RefreshUFDiagnosticsState()
end

-- Refresh target highlights on every frame when the player's target changes.
-- Without this, frames that were previously targeted keep their highlight until
-- the next time the mouse enters/leaves them.
function UnitFrames:OnTargetChanged()
    self:RefreshHighlightFrames()
end

-- Refresh mouseover highlights on every frame when the WoW mouseover unit changes.
-- This ensures that frames whose unit matches the new mouseover unit light up even
-- if the cursor moved to them between frames without triggering OnEnter/OnLeave.
function UnitFrames:OnMouseoverChanged()
    self:RefreshHighlightFrames()
end

function UnitFrames:OnThreatChanged()
    self:RefreshHighlightFrames()
end

function UnitFrames:OnUnitTargetChanged()
    self:RefreshHighlightFrames()
end

function UnitFrames:OnUnitFlagsChanged()
    if self._pendingHeaderClickCastRefresh and not InCombatLockdown() then
        self:RefreshHeaderClickCastSupport()
    end

    if self._queuedRefresh and not InCombatLockdown() then
        self._queuedRefresh = false
        self:RefreshAllFrames()
        return
    end

    self:RefreshStateIndicatorFrames()
end

function UnitFrames:OnPlayerRestingChanged()
    self:RefreshStateIndicatorFrames()
end

function UnitFrames:OnReadyCheckChanged()
    self:RefreshReadyCheckIndicatorFrames()
end

function UnitFrames:OnEnable()
    self:RefreshUFDiagnosticsState()
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

        if not db._migrated.groupRowSpacing then
            db.groups = db.groups or {}
            for _, gk in ipairs({ "party", "raid" }) do
                db.groups[gk] = db.groups[gk] or {}
                if db.groups[gk].rowSpacing == nil then
                    db.groups[gk].rowSpacing = math_abs(tonumber(db.groups[gk].yOffset) or 6)
                end
            end
            db._migrated.groupRowSpacing = true
        end

        if not db._migrated.partyTankGrowthDirection then
            db.groups = db.groups or {}
            for _, gk in ipairs({ "party", "tank" }) do
                db.groups[gk] = db.groups[gk] or {}
                if NormalizeGrowthDirection(db.groups[gk].growthDirection) == nil then
                    db.groups[gk].growthDirection = ResolveGroupGrowthDirection(db.groups[gk], "DOWN")
                end
            end
            db._migrated.partyTankGrowthDirection = true
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

        if not db._migrated.tankRoleIconDefault then
            db.groups = db.groups or {}
            db.groups.tank = db.groups.tank or {}
            db.groups.tank.roleIcon = db.groups.tank.roleIcon or {}
            if db.groups.tank.roleIcon.enabled == nil then
                db.groups.tank.roleIcon.enabled = true
            end
            db._migrated.tankRoleIconDefault = true
        end

        if not db._migrated.tankRoleFilterDefault then
            db.groups = db.groups or {}
            db.groups.tank = db.groups.tank or {}

            if db.groups.tank.roleFilter == nil or db.groups.tank.roleFilter == "" then
                db.groups.tank.roleFilter = "TANK"
            end

            local legacyGroupFilter = NormalizeHeaderFilterValue(db.groups.tank.groupFilter)
            if legacyGroupFilter == "MAINTANK,MAINASSIST" then
                db.groups.tank.groupFilter = nil
            end

            db._migrated.tankRoleFilterDefault = true
        end
    end

    if not self:SpawnFrames() then
        T:Print("UnitFrames: oUF is unavailable. Ensure Libraries/oUF/oUF.xml is loaded.")
        return
    end

    self:ApplyBlizzardPlayerCastbarVisibility()
    self:ApplyBlizzardRaidFrameVisibility()
    self:RefreshHeaderClickCastSupport()

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
    self:RegisterEvent("UNIT_TARGET", "OnUnitTargetChanged")
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", "OnThreatChanged")
    self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", "OnThreatChanged")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnUnitTargetChanged")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnUnitTargetChanged")
    self:RegisterEvent("UNIT_FLAGS", "OnUnitFlagsChanged")
    self:RegisterEvent("PLAYER_UPDATE_RESTING", "OnPlayerRestingChanged")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnUnitFlagsChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnUnitFlagsChanged")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "RefreshAllFrames")
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "RefreshAllFrames")
    self:RegisterEvent("ROLE_CHANGED_INFORM", "RefreshAllFrames")
    self:RegisterEvent("READY_CHECK", "OnReadyCheckChanged")
    self:RegisterEvent("READY_CHECK_CONFIRM", "OnReadyCheckChanged")
    self:RegisterEvent("READY_CHECK_FINISHED", "OnReadyCheckChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshAllFrames")
    self:RegisterEvent("SPELLS_CHANGED", "ResetRangeSpellCache")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "ResetRangeSpellCache")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")

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

    self:StopStandaloneCastbarUpdates()

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

    self:ApplyBlizzardPlayerCastbarVisibility()
    self:ApplyBlizzardRaidFrameVisibility()

    self:StopCastbar()
    self._ufDiagRuntime = nil
end

function UnitFrames:SetTestMode(enabled)
    local db = self:GetDB()
    db.testMode = enabled == true
    self:RefreshAllFrames()
end

function UnitFrames:SetTestPreviewGroupEnabled(groupKey, enabled)
    local db = self:GetDB()
    if groupKey == "party" then
        db.testPreviewParty = enabled ~= false
    elseif groupKey == "raid" then
        db.testPreviewRaid = enabled ~= false
    else
        return
    end

    self:RefreshPreviewVisibility()
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


