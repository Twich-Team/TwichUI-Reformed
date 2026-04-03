---@diagnostic disable: undefined-field, undefined-global, inject-field
--[[
    TwichUI Aura Watcher Engine

    Custom per-frame aura tracking, complementary to oUF's generic Auras element.
    Tracks specific spells by ID (via named Spell Groups) or generic filters, then
    renders them as icon clusters anchored at any frame point, or as colored border
    highlights triggered by aura presence.

    Integration:
      UnitFrames:AWAttach(frame)          -- StyleFrame: one-time setup
      UnitFrames:AWConfigure(frame, key)  -- ApplyAuraSettings: push new config
      UnitFrames:AWUpdate(frame)          -- oUF PostUpdate: scan & render
      UnitFrames:AWHideAll(frame)         -- Clear all indicators
]]

local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type UnitFramesModule
local UnitFrames = T:GetModule("UnitFrames")
if not UnitFrames then return end

-- ============================================================
-- Upvalues
-- ============================================================
local CreateFrame            = _G.CreateFrame
local GetTime                = _G.GetTime
local C_UnitAuras            = _G.C_UnitAuras
local setmetatable           = _G.setmetatable
local math_max               = math.max
local math_min               = math.min
local math_floor             = math.floor
local format                 = string.format
local Clamp                  = _G.Clamp or function(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local MAX_INDICATORS         = 6 -- indicator slots per frame
local MAX_ICONS              = 12 -- icon slots per indicator
local TIMER_RATE             = 0.1 -- icon timer update frequency (seconds)
local FILTER_HELPFUL         = { "HELPFUL" }
local FILTER_HARMFUL         = { "HARMFUL" }
local FILTER_BOTH            = { "HELPFUL", "HARMFUL" }

local spellLookupCache       = setmetatable({}, { __mode = "k" })
local singleSpellLookupCache = setmetatable({}, { __mode = "k" })
local groupLookupCache       = setmetatable({}, { __mode = "k" })

local function ResolveFrameUnit(frame)
    if type(frame) ~= "table" then
        return nil
    end

    return frame:GetAttribute("unit") or frame.unit
end

local function IsValidAuraUnit(unit)
    return UnitFrames:IsValidAuraUnit(unit)
end

local function GetAuraWatcherTextStyle(frame, cfg, prefix)
    local unitKey = frame and frame._awState and frame._awState.unitKey or "player"
    local base = UnitFrames.GetTextConfigFor and UnitFrames:GetTextConfigFor(unitKey) or nil
    local textStyle = {
        fontName = cfg[prefix .. "FontName"],
        outlineMode = cfg[prefix .. "OutlineMode"],
        shadowEnabled = cfg[prefix .. "ShadowEnabled"],
        shadowColor = cfg[prefix .. "ShadowColor"],
        shadowOffsetX = cfg[prefix .. "ShadowOffsetX"],
        shadowOffsetY = cfg[prefix .. "ShadowOffsetY"],
    }

    if textStyle.fontName == nil and base then textStyle.fontName = base.fontName end
    if textStyle.outlineMode == nil then textStyle.outlineMode = (base and base.outlineMode) or "OUTLINE" end
    if textStyle.shadowEnabled == nil then textStyle.shadowEnabled = base and base.shadowEnabled == true or false end
    if textStyle.shadowColor == nil then textStyle.shadowColor = (base and base.shadowColor) or { 0, 0, 0, 0.85 } end
    if textStyle.shadowOffsetX == nil then textStyle.shadowOffsetX = (base and base.shadowOffsetX) or 1 end
    if textStyle.shadowOffsetY == nil then textStyle.shadowOffsetY = (base and base.shadowOffsetY) or -1 end

    return textStyle
end

-- ============================================================
-- DB helpers
-- ============================================================

-- Returns the raw indicator array for a given unitKey.
-- Singles / boss → db.units[unitKey].indicators
-- Group members   → db.auras.scopes[scope].indicators
function UnitFrames:AWGetIndicators(unitKey)
    local db = self:GetDB()
    if unitKey == "partyMember" then
        db.auras              = db.auras or {}
        db.auras.scopes       = db.auras.scopes or {}
        db.auras.scopes.party = db.auras.scopes.party or {}
        return db.auras.scopes.party.indicators or {}
    elseif unitKey == "raidMember" then
        db.auras             = db.auras or {}
        db.auras.scopes      = db.auras.scopes or {}
        db.auras.scopes.raid = db.auras.scopes.raid or {}
        return db.auras.scopes.raid.indicators or {}
    elseif unitKey == "tankMember" then
        db.auras             = db.auras or {}
        db.auras.scopes      = db.auras.scopes or {}
        db.auras.scopes.tank = db.auras.scopes.tank or {}
        return db.auras.scopes.tank.indicators or {}
    else
        db.units          = db.units or {}
        db.units[unitKey] = db.units[unitKey] or {}
        return db.units[unitKey].indicators or {}
    end
end

-- Parse a comma/newline-separated spell ID string into an array of numbers.
local function ParseSpellIds(str)
    local result = {}
    if type(str) ~= "string" or str == "" then return result end
    for token in str:gmatch("[^%s,\n]+") do
        local n = tonumber(token)
        if n then result[#result + 1] = n end
    end
    return result
end

-- Build a reverse lookup { [spellId] = true } from a parsed ID array.
local function BuildLookup(ids)
    local t = {}
    for _, id in ipairs(ids) do t[id] = true end
    return t
end

local function ClearSequentialTable(tbl)
    if not tbl then
        return tbl
    end

    for index = #tbl, 1, -1 do
        tbl[index] = nil
    end

    return tbl
end

local function PushAuraResult(result, count, data, timing)
    count = count + 1

    local entry = result[count]
    if not entry then
        entry = {}
        result[count] = entry
    end

    entry.icon = data.icon
    entry.duration = timing.duration
    entry.expirationTime = timing.expirationTime
    entry.applications = timing.applications
    entry.durationObject = timing.durationObject

    return count
end

local function FinalizeAuraResults(result, count)
    for index = #result, count + 1, -1 do
        result[index] = nil
    end

    return result
end

local function GetCachedSpellLookup(cfg)
    local ids = cfg and cfg.spellIds
    if type(ids) ~= "table" or #ids == 0 then
        return nil
    end

    local cache = spellLookupCache[cfg]
    if cache and cache.ids == ids then
        return cache.lookup
    end

    local lookup = BuildLookup(ids)
    spellLookupCache[cfg] = {
        ids = ids,
        lookup = lookup,
    }

    return lookup
end

local function GetCachedSingleSpellLookup(cfg)
    local spellId = cfg and tonumber(cfg.spellId) or nil
    if not spellId or spellId <= 0 then
        return nil
    end

    local cache = singleSpellLookupCache[cfg]
    if cache and cache.spellId == spellId then
        return cache.lookup
    end

    local lookup = { [spellId] = true }
    singleSpellLookupCache[cfg] = {
        spellId = spellId,
        lookup = lookup,
    }

    return lookup
end

local function GetCachedGroupLookup(group)
    if type(group) ~= "table" then
        return nil
    end

    local raw = group.spellIds
    if type(raw) ~= "string" or raw == "" then
        return nil
    end

    local cache = groupLookupCache[group]
    if cache and cache.raw == raw then
        return cache.lookup
    end

    local ids = ParseSpellIds(raw)
    local lookup = #ids > 0 and BuildLookup(ids) or nil
    groupLookupCache[group] = {
        raw = raw,
        lookup = lookup,
    }

    return lookup
end

local function GetReusableAuraResults(frame, key)
    if not (frame and frame._awState) then
        return {}
    end

    local results = frame._awState.auraResults
    if not results then
        results = {}
        frame._awState.auraResults = results
    end

    if not results[key] then
        results[key] = {}
    end

    return results[key]
end

-- ============================================================
-- Aura scanning
-- ============================================================

local function ResolveIsPlayerAura(unit, auraInstanceID, filter, data)
    if data and data.isPlayerAura == true then
        return true
    end

    if not unit or not auraInstanceID or not C_UnitAuras or type(C_UnitAuras.IsAuraFilteredOutByInstanceID) ~= "function" then
        return false
    end

    local playerFilter = filter .. "|PLAYER"
    return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, playerFilter)
end

-- Scan unit auras matching a spell-ID lookup table.
local function ScanBySpellIds(unit, lookup, onlyMine, result)
    if not C_UnitAuras or not C_UnitAuras.GetAuraSlots or not IsValidAuraUnit(unit) then
        return ClearSequentialTable(result or {})
    end

    result = result or {}
    local count = 0
    for _, filter in ipairs(FILTER_BOTH) do
        local slots = { C_UnitAuras.GetAuraSlots(unit, filter) }
        for i = 2, #slots do
            local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
            -- spellId can be a 'secret' type in combat — pcall the table lookup.
            local _ok_cfg, _cfg = false, nil
            if data and data.spellId then
                _ok_cfg, _cfg = pcall(function() return lookup[data.spellId] end)
            end
            if data and _ok_cfg and _cfg then
                local isPlayerAura = ResolveIsPlayerAura(unit, data.auraInstanceID, filter, data)
                if not onlyMine or isPlayerAura then
                    local timing = UnitFrames:ResolveAuraTiming(unit, data, "watcher")
                    count = PushAuraResult(result, count, data, timing)
                end
            end
        end
    end

    return FinalizeAuraResults(result, count)
end

-- Scan unit auras matching a generic filter (HELPFUL / HARMFUL / DISPELLABLE / etc).
local function ScanByFilter(unit, source, onlyMine, result)
    if not C_UnitAuras or not C_UnitAuras.GetAuraSlots or not IsValidAuraUnit(unit) then
        return ClearSequentialTable(result or {})
    end

    result = result or {}
    local count = 0

    -- DISPELLABLE / DISPELLABLE_OR_BOSS: use WoW's engine-level "HARMFUL|RAID" filter.
    -- This is evaluated by the WoW client against the player's current class/spec
    -- and returns only the debuffs the player can actually dispel — without ever
    -- touching dispelName or isHarmful, both of which are secret types in PvP and
    -- throw errors when read even inside a pcall.
    if source == "DISPELLABLE" or source == "DISPELLABLE_OR_BOSS" then
        local seen = source == "DISPELLABLE_OR_BOSS" and {} or nil

        local dispelSlots = { C_UnitAuras.GetAuraSlots(unit, "HARMFUL|RAID") }
        for i = 2, #dispelSlots do
            local data = C_UnitAuras.GetAuraDataBySlot(unit, dispelSlots[i])
            if data then
                data.isHarmfulAura = true
                local passPlayer = not onlyMine or ResolveIsPlayerAura(unit, data.auraInstanceID, "HARMFUL", data)
                if passPlayer then
                    if seen then seen[data.auraInstanceID] = true end
                    local timing = UnitFrames:ResolveAuraTiming(unit, data, "watcher")
                    count = PushAuraResult(result, count, data, timing)
                end
            end
        end

        -- For DISPELLABLE_OR_BOSS also include boss auras not already captured.
        -- isBossAura is PvE metadata and readable outside of PvP secret restrictions.
        if source == "DISPELLABLE_OR_BOSS" then
            local bossSlots = { C_UnitAuras.GetAuraSlots(unit, "HARMFUL") }
            for i = 2, #bossSlots do
                local data = C_UnitAuras.GetAuraDataBySlot(unit, bossSlots[i])
                if data and not seen[data.auraInstanceID] then
                    data.isHarmfulAura = true
                    local passPlayer = not onlyMine or ResolveIsPlayerAura(unit, data.auraInstanceID, "HARMFUL", data)
                    if passPlayer then
                        local _okb, _isBoss = pcall(function() return data.isBossAura == true end)
                        if _okb and _isBoss then
                            local timing = UnitFrames:ResolveAuraTiming(unit, data, "watcher")
                            count = PushAuraResult(result, count, data, timing)
                        end
                    end
                end
            end
        end

        return FinalizeAuraResults(result, count)
    end

    local filters
    if source == "HELPFUL" then
        filters = FILTER_HELPFUL
    elseif source == "HARMFUL" then
        filters = FILTER_HARMFUL
    else
        filters = FILTER_BOTH
    end
    for _, f in ipairs(filters) do
        local slots = { C_UnitAuras.GetAuraSlots(unit, f) }
        for i = 2, #slots do
            local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
            if data then
                -- isHarmful is a secret boolean in combat; annotate isHarmfulAura so
                -- CheckAuraMatchesFilter can reliably detect harmful auras without a
                -- pcall comparison that may fail on the secret type.
                if f == "HARMFUL" then data.isHarmfulAura = true end
                local passPlayer = not onlyMine or ResolveIsPlayerAura(unit, data.auraInstanceID, f, data)
                if passPlayer and UnitFrames:CheckAuraMatchesFilter(source, data) then
                    local timing = UnitFrames:ResolveAuraTiming(unit, data, "watcher")
                    if source ~= "HELPFUL" or UnitFrames:ShouldKeepGenericHelpfulAura(unit, data, timing, onlyMine) then
                        count = PushAuraResult(result, count, data, timing)
                    end
                end
            end
        end
    end

    return FinalizeAuraResults(result, count)
end

-- Resolve which auras are active for a given indicator config on a frame.
local function ResolveAuras(frame, cfg, resultKey)
    local unit = ResolveFrameUnit(frame)
    local result = GetReusableAuraResults(frame, resultKey)
    if not IsValidAuraUnit(unit) then
        return ClearSequentialTable(result)
    end

    local source   = cfg.source or "HARMFUL"
    local onlyMine = cfg.onlyMine and true or false

    -- Catalog-assigned spells (source == "spell").
    -- Supports spellIds array (new) and legacy spellId scalar.
    if source == "spell" then
        local lookup = GetCachedSpellLookup(cfg)
        if lookup then
            return ScanBySpellIds(unit, lookup, onlyMine, result)
        end

        lookup = GetCachedSingleSpellLookup(cfg)
        if lookup then
            return ScanBySpellIds(unit, lookup, onlyMine, result)
        end

        return ClearSequentialTable(result)
    end

    -- Named spell group  (source == "group", groupKey references db.spellGroups)
    if source == "group" then
        local db     = UnitFrames:GetDB()
        local grp    = db.spellGroups and cfg.groupKey and db.spellGroups[cfg.groupKey]
        local lookup = GetCachedGroupLookup(grp)
        if lookup then
            return ScanBySpellIds(unit, lookup, onlyMine, result)
        end

        return ClearSequentialTable(result)
    end

    return ScanByFilter(unit, source, onlyMine, result)
end

-- ============================================================
-- Icon slot factory
-- ============================================================

local function CreateIconSlot(parent)
    local slot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slot:SetSize(18, 18)
    slot:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    slot:SetBackdropColor(0.06, 0.07, 0.09, 0.9)
    slot:SetBackdropBorderColor(0.22, 0.24, 0.3, 0.85)

    local tex = slot:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.icon = tex

    local cnt = slot:CreateFontString(nil, "OVERLAY")
    cnt:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, 1)
    cnt:SetFont(_G.STANDARD_TEXT_FONT, 9, "OUTLINE")
    cnt:SetTextColor(1, 1, 1, 1)
    slot.count = cnt

    local dur = slot:CreateFontString(nil, "OVERLAY")
    dur:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    dur:SetFont(_G.STANDARD_TEXT_FONT, 7, "OUTLINE")
    dur:SetTextColor(0.9, 0.9, 0.9, 0.85)
    slot.dur = dur

    slot:Hide()
    return slot
end

local function UpdateDurationText(fs, expiry, duration, durationObject)
    UnitFrames:UpdateAuraRemainingText(fs, durationObject, expiry, duration)
end

local function SetIconContainerTimerActive(container, active)
    if not container then
        return
    end

    if active then
        if container._timerActive ~= true then
            container._timerActive = true
            container:SetScript("OnUpdate", container._timerUpdateFunc)
        end
    elseif container._timerActive then
        container._timerActive = nil
        container._lastTick = 0
        container:SetScript("OnUpdate", nil)
    end
end

-- ============================================================
-- Lazy container creation
-- ============================================================

local function EnsureIconContainer(frame, idx)
    local state = frame._awState
    state.iconContainers = state.iconContainers or {}
    if not state.iconContainers[idx] then
        local c = CreateFrame("Frame", nil, frame)
        c:SetSize(1, 1)
        c._slots                  = {}
        c._lastTick               = 0
        c._timerUpdateFunc        = function(self2, elapsed)
            self2._lastTick = (self2._lastTick or 0) + elapsed
            if self2._lastTick < TIMER_RATE then return end
            self2._lastTick = 0
            for _, slot in ipairs(self2._slots) do
                if slot:IsShown() and slot.dur then
                    UpdateDurationText(slot.dur, slot._expiry, slot._duration, slot._durationObject)
                end
            end
        end
        state.iconContainers[idx] = c
    end
    return state.iconContainers[idx]
end

local function EnsureSlot(container, i)
    if not container._slots[i] then
        container._slots[i] = CreateIconSlot(container)
    end
    return container._slots[i]
end

local function EnsureBorderOverlay(frame, idx)
    local state = frame._awState
    state.borders = state.borders or {}
    if not state.borders[idx] then
        local b = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        b:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 4))
        b:Hide()
        state.borders[idx] = b
    end
    return state.borders[idx]
end

-- ============================================================
-- Icon cluster rendering
-- ============================================================

-- Growth direction → per-slot x/y offset multipliers.
local GROW_STEP = {
    RIGHT = function(i, step) return (i - 1) * step, 0 end,
    LEFT  = function(i, step) return -((i - 1) * step), 0 end,
    UP    = function(i, step) return 0, (i - 1) * step end,
    DOWN  = function(i, step) return 0, -((i - 1) * step) end,
}

local function UpdateIconIndicator(frame, idx, cfg, auras)
    local container      = EnsureIconContainer(frame, idx)
    local size           = Clamp(cfg.iconSize or 18, 8, 40)
    local spacing        = Clamp(cfg.spacing or 2, 0, 12)
    local maxCount       = Clamp(cfg.maxCount or 5, 1, MAX_ICONS)
    local shown          = math_min(#auras, maxCount)
    local step           = size + spacing
    local growFn         = GROW_STEP[cfg.growDirection or "RIGHT"] or GROW_STEP.RIGHT
    local showDur        = cfg.showDuration ~= false
    local durFont        = Clamp(cfg.durationFontSize or 7, 5, 14)
    local showCount      = cfg.showCount ~= false
    local countFont      = Clamp(cfg.countFontSize or 9, 5, 16)
    local durTextStyle   = GetAuraWatcherTextStyle(frame, cfg, "duration")
    local countTextStyle = GetAuraWatcherTextStyle(frame, cfg, "count")
    local durAnchor      = cfg.durAnchor or "TOPLEFT"
    local cntAnchor      = cfg.countAnchor or "BOTTOMRIGHT"
    local needsTimerPoll = false

    -- Small inset offsets so text sits just inside the icon border
    local ANCHOR_OFS     = {
        TOPLEFT = { 1, -1 },
        TOP = { 0, -1 },
        TOPRIGHT = { -1, -1 },
        LEFT = { 1, 0 },
        CENTER = { 0, 0 },
        RIGHT = { -1, 0 },
        BOTTOMLEFT = { 1, 1 },
        BOTTOM = { 0, 1 },
        BOTTOMRIGHT = { -1, 1 },
    }

    container:ClearAllPoints()
    container:SetPoint(
        cfg.anchor or "TOPLEFT",
        frame,
        cfg.relativeAnchor or "TOPLEFT",
        tonumber(cfg.offsetX) or 0,
        tonumber(cfg.offsetY) or 0
    )

    for i = 1, shown do
        local slot = EnsureSlot(container, i)
        local data = auras[i]
        local ox, oy = growFn(i, step)

        slot:SetSize(size, size)
        slot:ClearAllPoints()
        slot:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", ox, oy)

        slot.icon:SetTexture(data.icon)

        local n = data.applications or 0
        local daOfs = ANCHOR_OFS[durAnchor] or { 0, 0 }
        slot.dur:ClearAllPoints()
        slot.dur:SetPoint(durAnchor, slot, durAnchor, daOfs[1], daOfs[2])
        UnitFrames:ApplyFontObject(slot.dur, durFont, durTextStyle.fontName, durTextStyle)
        UpdateDurationText(slot.dur, data.expirationTime, data.duration, data.durationObject)
        slot.dur:SetShown(showDur)

        local caOfs = ANCHOR_OFS[cntAnchor] or { 0, 0 }
        slot.count:ClearAllPoints()
        slot.count:SetPoint(cntAnchor, slot, cntAnchor, caOfs[1], caOfs[2])
        UnitFrames:ApplyFontObject(slot.count, countFont, countTextStyle.fontName, countTextStyle)
        slot.count:SetText(n > 1 and tostring(n) or "")
        slot.count:SetShown(showCount and n > 1)

        slot._expiry         = data.expirationTime
        slot._duration       = data.duration
        slot._durationObject = data.durationObject
        if showDur and ((slot._durationObject and slot._durationObject.GetRemainingDuration) or
                ((tonumber(slot._expiry) or 0) > 0 and (tonumber(slot._duration) or 0) > 0)) then
            needsTimerPoll = true
        end

        slot:Show()
    end

    -- Hide unused slots
    for i = shown + 1, #container._slots do
        container._slots[i]._durationObject = nil
        container._slots[i]:Hide()
    end

    if shown == 0 then
        container:SetSize(1, 1)
        SetIconContainerTimerActive(container, false)
        container:Hide()
    else
        local isHoriz = (cfg.growDirection == "RIGHT" or cfg.growDirection == "LEFT"
            or cfg.growDirection == nil)
        local tw = isHoriz and (shown * size + (shown - 1) * spacing) or size
        local th = isHoriz and size or (shown * size + (shown - 1) * spacing)
        container:SetSize(math_max(1, tw), math_max(1, th))
        SetIconContainerTimerActive(container, needsTimerPoll)
        container:Show()
    end
end

-- ============================================================
-- Border overlay rendering
-- ============================================================

local function HideChaseDots(border)
    if border._chaseDots then
        for _, dt in ipairs(border._chaseDots) do dt:Hide() end
    end
end

local function UpdateBorderIndicator(frame, idx, cfg, isActive)
    local border = EnsureBorderOverlay(frame, idx)
    local bw     = Clamp(cfg.borderWidth or 2, 1, 8)
    local anim   = cfg.borderAnim or "solid"
    local speed  = cfg.borderAnimSpeed or 1.0
    local c      = type(cfg.borderColor) == "table" and cfg.borderColor or { 1, 0.5, 0, 1 }

    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -bw, bw)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", bw, -bw)

    if not isActive then
        if border._onUpdateSet then
            border:SetScript("OnUpdate", nil)
            border._onUpdateSet = nil
        end
        border:Hide()
        HideChaseDots(border)
        return
    end

    -- Active ─────────────────────────────────────────────────────
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = bw })
    border._animSpeed   = speed
    border._borderColor = c
    border._bw          = bw

    -- Solid: no OnUpdate needed
    if anim == "solid" then
        border._animType = "solid"
        if border._onUpdateSet then
            border:SetScript("OnUpdate", nil)
            border._onUpdateSet = nil
        end
        HideChaseDots(border)
        border:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
        border:Show()
        return
    end

    -- Pulse or Chase: install shared OnUpdate handler once
    if not border._onUpdateSet then
        border._onUpdateSet = true
        border:SetScript("OnUpdate", function(self2, elapsed)
            local at = self2._animType
            local sp = self2._animSpeed or 1.0
            local bc = self2._borderColor or { 1, 0.5, 0, 1 }
            if at == "pulse" then
                self2._pulseTime = (self2._pulseTime or 0) + elapsed
                local alpha = 0.35 + 0.65 * math.abs(math.sin(
                    self2._pulseTime * math.pi * sp))
                self2:SetBackdropBorderColor(bc[1], bc[2], bc[3], alpha)
            elseif at == "chase" then
                self2._chaseTime = (self2._chaseTime or 0) + elapsed * sp
                local t          = self2._chaseTime
                local dots       = self2._chaseDots
                if not dots then return end
                local N      = self2._activeChaseCount or #dots
                local dLen   = self2._chasePixelW or 6 -- length along travel direction
                local dThick = self2._chasePixelH or 2 -- thickness perpendicular to travel
                local cc     = self2._chaseColor
                if not cc then
                    cc = {
                        math_min(1, bc[1] + 0.5),
                        math_min(1, bc[2] + 0.5),
                        math_min(1, bc[3] + 0.5), 1,
                    }
                end
                local fw = self2:GetWidth()
                local fh = self2:GetHeight()
                for di = 1, N do
                    local dot     = dots[di]
                    local phase   = (t + (di - 1) / N * 4) % 4
                    local side    = math_floor(phase)
                    local frac    = phase - side
                    local isHoriz = (side == 0 or side == 2)
                    local dotW    = isHoriz and dLen or dThick
                    local dotH    = isHoriz and dThick or dLen
                    dot:SetSize(dotW, dotH)
                    dot:SetColorTexture(cc[1], cc[2], cc[3], cc[4] or 1)
                    dot:ClearAllPoints()
                    if side == 0 then
                        dot:SetPoint("TOPLEFT", self2, "TOPLEFT",
                            frac * (fw - dotW), 0)
                    elseif side == 1 then
                        dot:SetPoint("TOPRIGHT", self2, "TOPRIGHT",
                            0, -(frac * (fh - dotH)))
                    elseif side == 2 then
                        dot:SetPoint("BOTTOMRIGHT", self2, "BOTTOMRIGHT",
                            -(frac * (fw - dotW)), 0)
                    else
                        dot:SetPoint("BOTTOMLEFT", self2, "BOTTOMLEFT",
                            0, frac * (fh - dotH))
                    end
                end
            end
        end)
    end

    if anim == "pulse" then
        border._animType  = "pulse"
        border._pulseTime = border._pulseTime or 0
        HideChaseDots(border)
        border:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    else -- chase
        border._animType    = "chase"
        border._chaseTime   = border._chaseTime or 0
        border._chasePixelW = Clamp(cfg.chasePixelW or 6, 1, 24) -- length along edge
        border._chasePixelH = Clamp(cfg.chasePixelH or 2, 1, 12) -- thickness
        border._chaseColor  = type(cfg.chaseColor) == "table" and cfg.chaseColor or nil
        local count         = Clamp(cfg.chaseCount or 3, 1, 8)
        border._chaseDots   = border._chaseDots or {}
        for di = #border._chaseDots + 1, count do
            local dt = border:CreateTexture(nil, "OVERLAY")
            dt:SetColorTexture(1, 1, 1, 1)
            border._chaseDots[di] = dt
        end
        for di = count + 1, #border._chaseDots do
            border._chaseDots[di]:Hide()
        end
        for di = 1, count do
            border._chaseDots[di]:Show()
        end
        border._activeChaseCount = count
        border:SetBackdropBorderColor(c[1], c[2], c[3], 0.9)
    end
    border:Show()
end

-- ============================================================
-- Color overlay rendering
-- ============================================================

local function EnsureColorOverlay(frame, idx)
    local state = frame._awState
    state.overlays = state.overlays or {}
    if not state.overlays[idx] then
        local o = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        o:SetFrameLevel(math_max(1, frame:GetFrameLevel() + 3))
        o:SetAllPoints(frame)
        o:Hide()
        state.overlays[idx] = o
    end
    return state.overlays[idx]
end

local function UpdateColorOverlayIndicator(frame, idx, cfg, isActive)
    local overlay = EnsureColorOverlay(frame, idx)
    if isActive then
        local c = type(cfg.overlayColor) == "table" and cfg.overlayColor or { 0.10, 0.72, 0.74 }
        local alpha = tonumber(c[4]) or tonumber(cfg.overlayAlpha) or 0.25
        overlay:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        overlay:SetBackdropColor(c[1], c[2], c[3], alpha)
        overlay:Show()
    else
        overlay:Hide()
    end
end

-- ============================================================
-- Public API
-- ============================================================

-- Registry of all active frames so we can force-push config changes.
local awFrameRegistry = {}

--- Called once per frame in StyleFrame. Creates the per-frame state table.
function UnitFrames:AWAttach(frame)
    frame._awState = {
        unitKey        = nil,
        auraResults    = {},
        iconContainers = {},
        borders        = {},
        overlays       = {},
    }
end

--- Called from ApplyAuraSettings. Stores the resolved unitKey and triggers
--- an immediate update so indicators reflect the current aura state.
function UnitFrames:AWConfigure(frame, unitKey)
    if not frame._awState then return end
    frame._awState.unitKey = unitKey
    awFrameRegistry[frame] = true
    self:AWUpdate(frame)
end

--- Force-update all registered frames — called after designer config changes.
function UnitFrames:AWForceUpdate()
    for frame in pairs(awFrameRegistry) do
        if frame and frame.IsShown and frame:IsShown() then
            self:AWUpdate(frame)
        end
    end
end

--- Main update function — called from oUF's Auras.PostUpdate whenever a
--- UNIT_AURA fires on this frame's unit. Scans auras and refreshes all indicators.
function UnitFrames:AWUpdate(frame)
    if not frame or not frame._awState then return end
    local unit = ResolveFrameUnit(frame)
    if not IsValidAuraUnit(unit) then
        self:AWHideAll(frame)
        return
    end

    local unitKey = frame._awState.unitKey
    if not unitKey then return end

    local indicators = self:AWGetIndicators(unitKey)

    local MAX_EXTRA_LAYERS = 3
    for idx = 1, MAX_INDICATORS do
        local cfg = indicators[idx]
        if cfg and cfg.enabled ~= false then
            local auras  = ResolveAuras(frame, cfg, idx)
            local itype  = cfg.type or "icons"
            local active = #auras > 0
            if itype == "icons" then
                UpdateIconIndicator(frame, idx, cfg, auras)
                local bd = frame._awState.borders and frame._awState.borders[idx]
                local ov = frame._awState.overlays and frame._awState.overlays[idx]
                if bd then bd:Hide() end
                if ov then ov:Hide() end
            elseif itype == "border" then
                UpdateBorderIndicator(frame, idx, cfg, active)
                local ic = frame._awState.iconContainers and frame._awState.iconContainers[idx]
                local ov = frame._awState.overlays and frame._awState.overlays[idx]
                if ic then
                    SetIconContainerTimerActive(ic, false)
                    ic:Hide()
                end
                if ov then ov:Hide() end
            elseif itype == "overlay" then
                UpdateColorOverlayIndicator(frame, idx, cfg, active)
                local ic = frame._awState.iconContainers and frame._awState.iconContainers[idx]
                local bd = frame._awState.borders and frame._awState.borders[idx]
                if ic then
                    SetIconContainerTimerActive(ic, false)
                    ic:Hide()
                end
                if bd then bd:Hide() end
            end
            -- Process extra indicator layers (same aura condition, different visual)
            if cfg.extraLayers then
                for lj, extraCfg in ipairs(cfg.extraLayers) do
                    local ei    = MAX_INDICATORS * lj + idx
                    local etype = extraCfg.type or "icons"
                    if etype == "icons" then
                        UpdateIconIndicator(frame, ei, extraCfg, auras)
                        local bd2 = frame._awState.borders and frame._awState.borders[ei]
                        local ov2 = frame._awState.overlays and frame._awState.overlays[ei]
                        if bd2 then bd2:Hide() end
                        if ov2 then ov2:Hide() end
                    elseif etype == "border" then
                        UpdateBorderIndicator(frame, ei, extraCfg, active)
                        local ic2 = frame._awState.iconContainers and frame._awState.iconContainers[ei]
                        local ov2 = frame._awState.overlays and frame._awState.overlays[ei]
                        if ic2 then
                            SetIconContainerTimerActive(ic2, false)
                            ic2:Hide()
                        end
                        if ov2 then ov2:Hide() end
                    elseif etype == "overlay" then
                        UpdateColorOverlayIndicator(frame, ei, extraCfg, active)
                        local ic2 = frame._awState.iconContainers and frame._awState.iconContainers[ei]
                        local bd2 = frame._awState.borders and frame._awState.borders[ei]
                        if ic2 then
                            SetIconContainerTimerActive(ic2, false)
                            ic2:Hide()
                        end
                        if bd2 then bd2:Hide() end
                    end
                end
            end
            -- Hide any extra layer slots no longer in use
            local extraCount = cfg.extraLayers and #cfg.extraLayers or 0
            for lj = extraCount + 1, MAX_EXTRA_LAYERS do
                local ei = MAX_INDICATORS * lj + idx
                local ic2 = frame._awState.iconContainers and frame._awState.iconContainers[ei]
                if ic2 then
                    SetIconContainerTimerActive(ic2, false)
                    ic2:Hide()
                end
                local bd2 = frame._awState.borders and frame._awState.borders[ei]
                if bd2 then bd2:Hide() end
                local ov2 = frame._awState.overlays and frame._awState.overlays[ei]
                if ov2 then ov2:Hide() end
            end
        else
            -- Hide primary visuals and all potential extra layer slots
            local ic = frame._awState.iconContainers and frame._awState.iconContainers[idx]
            if ic then
                SetIconContainerTimerActive(ic, false)
                ic:Hide()
            end
            local bd = frame._awState.borders and frame._awState.borders[idx]
            if bd then bd:Hide() end
            local ov = frame._awState.overlays and frame._awState.overlays[idx]
            if ov then ov:Hide() end
            for lj = 1, MAX_EXTRA_LAYERS do
                local ei = MAX_INDICATORS * lj + idx
                local ic2 = frame._awState.iconContainers and frame._awState.iconContainers[ei]
                if ic2 then
                    SetIconContainerTimerActive(ic2, false)
                    ic2:Hide()
                end
                local bd2 = frame._awState.borders and frame._awState.borders[ei]
                if bd2 then bd2:Hide() end
                local ov2 = frame._awState.overlays and frame._awState.overlays[ei]
                if ov2 then ov2:Hide() end
            end
        end
    end
end

--- Hides all indicator visuals on the frame (called when the unit is gone).
function UnitFrames:AWHideAll(frame)
    if not frame._awState then return end
    for _, c in pairs(frame._awState.iconContainers or {}) do
        if c then
            SetIconContainerTimerActive(c, false)
            c:Hide()
        end
    end
    for _, b in pairs(frame._awState.borders or {}) do
        if b then
            if b._onUpdateSet then
                b:SetScript("OnUpdate", nil)
                b._onUpdateSet = nil
            end
            b:Hide()
        end
    end
    for _, o in pairs(frame._awState.overlays or {}) do
        if o then o:Hide() end
    end
end

--- Preview rendering — renders mock auras on a frame WITHOUT a real unit.
--- Used by the designer's live preview panel.
function UnitFrames:AWPreviewRender(frame, slotIdx, cfg)
    if not frame or not frame._awState then return end
    if not cfg then return end
    local itype     = cfg.type or "icons"
    -- Build mock aura list from spell IDs (or 3 placeholder icons for filters)
    local mockAuras = {}
    local ids       = cfg.spellIds or (cfg.spellId and { cfg.spellId }) or {}
    local n         = math_min(cfg.maxCount or 3, math_max(#ids, 1), 3)
    for i = 1, n do
        local sid = ids[i]
        local tex = nil
        if sid and sid > 0 then
            if _G.C_Spell and _G.C_Spell.GetSpellTexture then
                tex = _G.C_Spell.GetSpellTexture(sid)
            elseif _G.GetSpellTexture then
                tex = _G.GetSpellTexture(sid)
            end
        end
        mockAuras[i] = {
            icon           = tex or 134400,
            duration       = 60,
            expirationTime = GetTime() + 45 + i * 7,
            applications   = (cfg.showCount ~= false) and 3 or 0,
        }
    end
    if itype == "icons" then
        UpdateIconIndicator(frame, slotIdx, cfg, mockAuras)
    elseif itype == "border" then
        UpdateBorderIndicator(frame, slotIdx, cfg, true)
    elseif itype == "overlay" then
        UpdateColorOverlayIndicator(frame, slotIdx, cfg, true)
    end
end

--- Clear all previewed indicators.
function UnitFrames:AWPreviewClear(frame)
    self:AWHideAll(frame)
end

-- CheckAuraMatchesFilter is defined as a method in UnitFrames.lua where the
-- local AuraMatchesDisplayMode function is in scope. AuraWatcher.lua calls
-- self:CheckAuraMatchesFilter(mode, data) via ScanByFilter above.
