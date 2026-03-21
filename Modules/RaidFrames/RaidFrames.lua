--[[
    Raid frame enhancements for ElvUI group frames.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class RaidFramesModule : AceModule, AceEvent-3.0, AceTimer-3.0
local RaidFrames = T:NewModule("RaidFrames", "AceEvent-3.0", "AceTimer-3.0")

local CreateFrame = CreateFrame
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local C_UnitAuras = C_UnitAuras
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local LegacyUnitDebuff = UnitDebuff

local TRACKED_GROUPS = {
    party = true,
    raid1 = true,
    raid2 = true,
    raid3 = true,
}

local DEFAULT_COLOR = {
    r = 1,
    g = 0.82,
    b = 0.18,
    a = 0.9,
}

local state = {
    glowByFrame = setmetatable({}, { __mode = "k" }),
    active = setmetatable({}, { __mode = "k" }),
    pendingFullRefresh = false,
    testTimer = nil,
    testUntil = 0,
}

local function GetOptions()
    return T:GetModule("Configuration").Options.RaidFrames
end

local function IsDispellableDebuffsHighlightEnabled()
    local options = GetOptions()
    return options and options.GetDispellableDebuffsHighlightEnabled and options:GetDispellableDebuffsHighlightEnabled()
end

local function GetElvUIEngine()
    local ElvUI = rawget(_G, "ElvUI")
    local E = ElvUI and ElvUI[1]
    if not E or type(E.GetModule) ~= "function" then
        return nil
    end

    return E
end

local function GetUF()
    local E = GetElvUIEngine()
    if not E then
        return nil
    end

    return E:GetModule("UnitFrames", true)
end

local function IsTrackedUnit(unit)
    return unit == "player"
        or (type(unit) == "string" and unit:match("^party%d+$") ~= nil)
        or (type(unit) == "string" and unit:match("^raid%d+$") ~= nil)
end

local function UnitHasDispellableDebuff(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if GetAuraDataByIndex then
        for index = 1, 40 do
            local auraData = GetAuraDataByIndex(unit, index, "HARMFUL|RAID")
            if not auraData then
                break
            end

            return true
        end

        return false
    end

    if not LegacyUnitDebuff then
        return false
    end

    for index = 1, 40 do
        local auraName = LegacyUnitDebuff(unit, index, "RAID")
        if not auraName then
            break
        end

        return true
    end

    return false
end

local function CreateFallbackGlow(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetAllPoints(parent)
    holder:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 10)
    holder:EnableMouse(false)

    local function NewEdge()
        local texture = holder:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetBlendMode("ADD")
        return texture
    end

    holder.top = NewEdge()
    holder.bottom = NewEdge()
    holder.left = NewEdge()
    holder.right = NewEdge()

    holder.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -3, 3)
    holder.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 3, 3)
    holder.top:SetHeight(2)

    holder.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -3, -3)
    holder.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 3, -3)
    holder.bottom:SetHeight(2)

    holder.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -3, 3)
    holder.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -3, -3)
    holder.left:SetWidth(2)

    holder.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 3, 3)
    holder.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 3, -3)
    holder.right:SetWidth(2)

    holder.glowKind = "fallback"
    return holder
end

local function CreateGlow(frame)
    local anchor = frame.Health and (frame.Health.backdrop or frame.Health) or frame
    if not anchor then
        return nil
    end

    local E = GetElvUIEngine()
    local blankTexture = E and E.media and E.media.blankTex or "Interface\\Buttons\\WHITE8X8"

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(anchor)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or frame:GetFrameLevel() or 0) + 10)
    holder:EnableMouse(false)

    if holder.CreateShadow then
        holder.shadow = holder:CreateShadow(5, true)
        holder.glowKind = "shadow"
        if holder.shadow then
            holder.shadow:SetFrameStrata(frame:GetFrameStrata())
            holder.shadow:SetFrameLevel(holder:GetFrameLevel())
        end

        holder.outerShadow = holder:CreateShadow(10, true)
        if holder.outerShadow then
            holder.outerShadow:SetFrameStrata(frame:GetFrameStrata())
            holder.outerShadow:SetFrameLevel(holder:GetFrameLevel() - 1)
        end
    else
        holder = CreateFallbackGlow(anchor)
    end

    holder.innerGlow = holder:CreateTexture(nil, "ARTWORK")
    holder.innerGlow:SetTexture(blankTexture)
    holder.innerGlow:SetBlendMode("ADD")
    holder.innerGlow:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
    holder.innerGlow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, 1)

    holder.holySheen = holder:CreateTexture(nil, "OVERLAY")
    holder.holySheen:SetTexture(blankTexture)
    holder.holySheen:SetBlendMode("ADD")
    holder.holySheen:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
    holder.holySheen:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)

    local animation = holder:CreateAnimationGroup()
    animation:SetLooping("BOUNCE")

    local alpha = animation:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.6)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.72)
    alpha:SetSmoothing("IN_OUT")

    holder.anim = animation
    holder:Hide()
    return holder
end

local function SetGlowColor(glow, r, g, b, a)
    if not glow then
        return
    end

    if glow.shadow then
        glow.shadow:SetBackdropColor(r, g, b, a * 0.28)
        glow.shadow:SetBackdropBorderColor(r, g, b, a)
    end

    if glow.outerShadow then
        glow.outerShadow:SetBackdropColor(r, g, b, a * 0.08)
        glow.outerShadow:SetBackdropBorderColor(r, g, b, a * 0.65)
    end

    if glow.innerGlow then
        glow.innerGlow:SetVertexColor(r, g * 0.96, b * 0.8, a * 0.16)
    end

    if glow.holySheen then
        glow.holySheen:SetVertexColor(1, 0.96, 0.72, a * 0.1)
    end

    if glow.top then glow.top:SetVertexColor(r, g, b, a) end
    if glow.bottom then glow.bottom:SetVertexColor(r, g, b, a) end
    if glow.left then glow.left:SetVertexColor(r, g, b, a) end
    if glow.right then glow.right:SetVertexColor(r, g, b, a) end

    glow:SetAlpha(a)
end

local function VisitFrameTree(node, callback)
    if not node then
        return
    end

    if node.Health and IsTrackedUnit(node.unit) then
        callback(node)
        return
    end

    if not node.GetChildren then
        return
    end

    for _, child in next, { node:GetChildren() } do
        VisitFrameTree(child, callback)
    end
end

function RaidFrames:EnumerateFrames(callback)
    local UF = GetUF()
    if not UF or not UF.headers then
        return
    end

    for groupName in pairs(UF.headers) do
        if TRACKED_GROUPS[groupName] then
            local group = UF[groupName]
            if group and group.GetChildren then
                for _, child in next, { group:GetChildren() } do
                    VisitFrameTree(child, callback)
                end
            end
        end
    end
end

function RaidFrames:IsTesting()
    return state.testUntil > GetTime()
end

function RaidFrames:GetOrCreateGlow(frame, allowCreate)
    local glow = state.glowByFrame[frame]
    if glow then
        return glow
    end

    if not allowCreate then
        state.pendingFullRefresh = true
        return nil
    end

    glow = CreateGlow(frame)
    state.glowByFrame[frame] = glow
    return glow
end

function RaidFrames:ShowGlow(frame, allowCreate)
    local glow = self:GetOrCreateGlow(frame, allowCreate)
    if not glow then
        return
    end

    local r, g, b, a = GetOptions():GetGlowColor()
    SetGlowColor(glow, r, g, b, a)

    glow:Show()
    if glow.shadow then
        glow.shadow:Show()
    end
    if glow.outerShadow then
        glow.outerShadow:Show()
    end

    if glow.anim and not glow.anim:IsPlaying() then
        glow.anim:Play()
    end

    state.active[frame] = true
end

function RaidFrames:HideGlow(frame)
    local glow = state.glowByFrame[frame]
    if not glow then
        return
    end

    if glow.anim then
        glow.anim:Stop()
    end

    if glow.shadow then
        glow.shadow:Hide()
    end

    if glow.outerShadow then
        glow.outerShadow:Hide()
    end

    glow:Hide()
    state.active[frame] = nil
end

function RaidFrames:UpdateFrame(frame, allowCreate)
    if not frame or not frame.unit or not frame.IsShown or not frame:IsShown() then
        self:HideGlow(frame)
        return
    end

    if not IsDispellableDebuffsHighlightEnabled() then
        self:HideGlow(frame)
        return
    end

    if self:IsTesting() or UnitHasDispellableDebuff(frame.unit) then
        self:ShowGlow(frame, allowCreate)
    else
        self:HideGlow(frame)
    end
end

function RaidFrames:RefreshAllFrames()
    if not IsDispellableDebuffsHighlightEnabled() then
        state.pendingFullRefresh = false

        for frame in pairs(state.active) do
            self:HideGlow(frame)
        end

        return
    end

    local allowCreate = not InCombatLockdown()
    state.pendingFullRefresh = not allowCreate

    self:EnumerateFrames(function(frame)
        self:UpdateFrame(frame, allowCreate)
    end)
end

function RaidFrames:RefreshUnit(unit)
    if not IsTrackedUnit(unit) then
        return
    end

    if not IsDispellableDebuffsHighlightEnabled() then
        self:RefreshAllFrames()
        return
    end

    local allowCreate = not InCombatLockdown()
    if not allowCreate then
        state.pendingFullRefresh = true
    end

    self:EnumerateFrames(function(frame)
        if frame.unit == unit then
            self:UpdateFrame(frame, allowCreate)
        end
    end)
end

function RaidFrames:StartTest(duration)
    if not self:IsEnabled() or not IsDispellableDebuffsHighlightEnabled() then
        return
    end

    state.testUntil = GetTime() + (duration or 8)

    if state.testTimer then
        self:CancelTimer(state.testTimer)
        state.testTimer = nil
    end

    state.testTimer = self:ScheduleTimer("StopTest", duration or 8)
    self:RefreshAllFrames()
end

function RaidFrames:StopTest()
    state.testUntil = 0
    state.testTimer = nil
    self:RefreshAllFrames()
end

function RaidFrames:PLAYER_REGEN_ENABLED()
    if state.pendingFullRefresh then
        self:RefreshAllFrames()
    end
end

function RaidFrames:UNIT_AURA(_, unit)
    self:RefreshUnit(unit)
end

function RaidFrames:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshAllFrames")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "RefreshAllFrames")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "RefreshAllFrames")
    self:RegisterEvent("SPELLS_CHANGED", "RefreshAllFrames")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    self:RefreshAllFrames()
end

function RaidFrames:OnDisable()
    if state.testTimer then
        self:CancelTimer(state.testTimer)
        state.testTimer = nil
    end

    state.testUntil = 0
    state.pendingFullRefresh = false
    self:UnregisterAllEvents()

    for frame in pairs(state.active) do
        self:HideGlow(frame)
    end
end

function RaidFrames:Refresh()
    if self:IsEnabled() then
        self:RefreshAllFrames()
    end
end

function RaidFrames:GetDefaultColor()
    return DEFAULT_COLOR.r, DEFAULT_COLOR.g, DEFAULT_COLOR.b, DEFAULT_COLOR.a
end
