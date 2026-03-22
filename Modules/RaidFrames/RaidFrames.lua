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
local LegacyUnitDebuff = UnitDebuff
local UIParent = UIParent
local math_max = math.max
local math_min = math.min
local ipairs = ipairs
local LBG = LibStub("LibButtonGlow-1.0", true)

local OUTER_GLOW_PADDING = 2
local INNER_GLOW_PADDING = 0
local BORDER_THICKNESS = 2
local SPARK_SIZE = 7
local SPARK_CYCLE_SECONDS = 2.15
local CLASSIC_CHASER_THICKNESS = 2
local CLASSIC_CHASER_LENGTH = 12
local CLASSIC_CHASER_FADE_SECONDS = 0.05
local CLASSIC_CHASER_CYCLE_SECONDS = 1.85
local STYLE_CLASSIC = "classic"
local STYLE_BUTTON = "button"

local DEFAULT_COLOR = {
    r = 1,
    g = 0.82,
    b = 0.18,
    a = 0.9,
}

local state = {
    glowByFrame = setmetatable({}, { __mode = "k" }),
    active = setmetatable({}, { __mode = "k" }),
    trackedFrames = {},
    framesByUnit = {},
    frameCacheDirty = true,
    pendingFullRefresh = false,
    testTimer = nil,
    testUntil = 0,
    debugFrame = nil,
}

local function GetOptions()
    return T:GetModule("Configuration").Options.RaidFrames
end

local function IsDispellableDebuffsHighlightEnabled()
    local options = GetOptions()
    return options and options.GetDispellableDebuffsHighlightEnabled and options:GetDispellableDebuffsHighlightEnabled()
end

local function NormalizeGlowStyle(style)
    if style == STYLE_BUTTON then
        return STYLE_BUTTON
    end

    return STYLE_CLASSIC
end

local function GetGlowStyle()
    local options = GetOptions()
    if not options or type(options.GetGlowStyle) ~= "function" then
        return STYLE_CLASSIC
    end

    return NormalizeGlowStyle(options:GetGlowStyle())
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

local function GetoUF()
    return rawget(_G, "ElvUF")
end

local function IsTrackedUnit(unit)
    return unit == "player"
        or (type(unit) == "string" and unit:match("^party%d+$") ~= nil)
        or (type(unit) == "string" and unit:match("^raid%d+$") ~= nil)
end

local function HasLegacyRaidDispellableDebuff(unit)
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

local function PrimeUnitAuraState(frame, unit, event, updateInfo)
    local oUF = GetoUF()
    if not oUF or type(oUF.ShouldSkipAuraUpdate) ~= "function" or not frame or not unit then
        return
    end

    pcall(oUF.ShouldSkipAuraUpdate, oUF, frame, event or "TwichRx_RaidFrames", unit, updateInfo)
end

local function UnitHasDispellableDebuff(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    local oUF = GetoUF()
    local harmful = oUF and oUF.AuraFiltered and oUF.AuraFiltered.HARMFUL and oUF.AuraFiltered.HARMFUL[unit]
    if type(harmful) == "table" then
        for _, aura in next, harmful do
            if aura then
                local raidPlayerDispellable = type(oUF.CanAccessValue) == "function"
                    and oUF:CanAccessValue(aura.auraIsRaidPlayerDispellable)
                    and aura.auraIsRaidPlayerDispellable == true
                if raidPlayerDispellable then
                    return true
                end

                local canActivePlayerDispel = type(oUF.CanAccessValue) == "function"
                    and oUF:CanAccessValue(aura.canActivePlayerDispel)
                    and aura.canActivePlayerDispel == true
                if canActivePlayerDispel then
                    return true
                end
            end
        end

        return false
    end

    return HasLegacyRaidDispellableDebuff(unit)
end

local function DescribeAuraValue(oUF, value)
    if type(oUF) == "table" and type(oUF.CanAccessValue) == "function" and not oUF:CanAccessValue(value) then
        return "<secret>"
    end

    if value == nil then
        return "nil"
    end

    return tostring(value)
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

    holder.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -OUTER_GLOW_PADDING, OUTER_GLOW_PADDING)
    holder.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", OUTER_GLOW_PADDING, OUTER_GLOW_PADDING)
    holder.top:SetHeight(3)

    holder.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -OUTER_GLOW_PADDING, -OUTER_GLOW_PADDING)
    holder.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", OUTER_GLOW_PADDING, -OUTER_GLOW_PADDING)
    holder.bottom:SetHeight(3)

    holder.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -OUTER_GLOW_PADDING, OUTER_GLOW_PADDING)
    holder.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -OUTER_GLOW_PADDING, -OUTER_GLOW_PADDING)
    holder.left:SetWidth(3)

    holder.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", OUTER_GLOW_PADDING, OUTER_GLOW_PADDING)
    holder.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", OUTER_GLOW_PADDING, -OUTER_GLOW_PADDING)
    holder.right:SetWidth(3)

    holder.glowKind = "fallback"
    return holder
end

local function AddShadowFrame(glow, shadow)
    if not shadow then
        return
    end

    glow.shadowFrames = glow.shadowFrames or {}
    glow.shadowFrames[#glow.shadowFrames + 1] = shadow
end

local function AddAnimationGroup(glow, animation)
    if not animation then
        return
    end

    glow.animations = glow.animations or {}
    glow.animations[#glow.animations + 1] = animation
end

local function UpdatePerimeterSparkAnimationLayout(glow)
    if not glow or not glow.sparkTop then
        return
    end

    local width = math_max(glow:GetWidth(), CLASSIC_CHASER_LENGTH + 4)
    local height = math_max(glow:GetHeight(), CLASSIC_CHASER_LENGTH + 4)
    local horizontalDistance = math_max(0, width - CLASSIC_CHASER_LENGTH)
    local verticalDistance = math_max(0, height - CLASSIC_CHASER_LENGTH)
    local perimeter = math_max(1, (horizontalDistance * 2) + (verticalDistance * 2))
    local travelBudget = math_max(0.4, CLASSIC_CHASER_CYCLE_SECONDS - (CLASSIC_CHASER_FADE_SECONDS * 4))
    local topDuration = math_max(0.12, travelBudget * (horizontalDistance / perimeter))
    local rightDuration = math_max(0.1, travelBudget * (verticalDistance / perimeter))
    local bottomDuration = math_max(0.12, travelBudget * (horizontalDistance / perimeter))
    local leftDuration = math_max(0.1, travelBudget * (verticalDistance / perimeter))
    local totalDuration = topDuration + rightDuration + bottomDuration + leftDuration + (CLASSIC_CHASER_FADE_SECONDS * 4)

    glow.sparkTop:ClearAllPoints()
    glow.sparkTop:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
    glow.sparkTop:SetSize(CLASSIC_CHASER_LENGTH, CLASSIC_CHASER_THICKNESS)

    glow.sparkRight:ClearAllPoints()
    glow.sparkRight:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
    glow.sparkRight:SetSize(CLASSIC_CHASER_THICKNESS, CLASSIC_CHASER_LENGTH)

    glow.sparkBottom:ClearAllPoints()
    glow.sparkBottom:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
    glow.sparkBottom:SetSize(CLASSIC_CHASER_LENGTH, CLASSIC_CHASER_THICKNESS)

    glow.sparkLeft:ClearAllPoints()
    glow.sparkLeft:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
    glow.sparkLeft:SetSize(CLASSIC_CHASER_THICKNESS, CLASSIC_CHASER_LENGTH)

    glow.sparkTopMove:SetOffset(horizontalDistance, 0)
    glow.sparkTopMove:SetDuration(topDuration)
    glow.sparkTopPause:SetDuration(0)
    glow.sparkTopOn:SetDuration(0.001)
    glow.sparkTopFade:SetDuration(CLASSIC_CHASER_FADE_SECONDS)
    glow.sparkTopRest:SetDuration(math_max(0.001, totalDuration - topDuration - CLASSIC_CHASER_FADE_SECONDS))

    glow.sparkRightMove:SetOffset(0, -verticalDistance)
    glow.sparkRightMove:SetDuration(rightDuration)
    glow.sparkRightPause:SetDuration(topDuration + CLASSIC_CHASER_FADE_SECONDS)
    glow.sparkRightOn:SetDuration(0.001)
    glow.sparkRightFade:SetDuration(CLASSIC_CHASER_FADE_SECONDS)
    glow.sparkRightRest:SetDuration(math_max(0.001, totalDuration - (topDuration + CLASSIC_CHASER_FADE_SECONDS) - rightDuration - CLASSIC_CHASER_FADE_SECONDS))

    glow.sparkBottomMove:SetOffset(-horizontalDistance, 0)
    glow.sparkBottomMove:SetDuration(bottomDuration)
    glow.sparkBottomPause:SetDuration(topDuration + rightDuration + (CLASSIC_CHASER_FADE_SECONDS * 2))
    glow.sparkBottomOn:SetDuration(0.001)
    glow.sparkBottomFade:SetDuration(CLASSIC_CHASER_FADE_SECONDS)
    glow.sparkBottomRest:SetDuration(math_max(0.001, totalDuration - (topDuration + rightDuration + (CLASSIC_CHASER_FADE_SECONDS * 2)) - bottomDuration - CLASSIC_CHASER_FADE_SECONDS))

    glow.sparkLeftMove:SetOffset(0, verticalDistance)
    glow.sparkLeftMove:SetDuration(leftDuration)
    glow.sparkLeftPause:SetDuration(topDuration + rightDuration + bottomDuration + (CLASSIC_CHASER_FADE_SECONDS * 3))
    glow.sparkLeftOn:SetDuration(0.001)
    glow.sparkLeftFade:SetDuration(CLASSIC_CHASER_FADE_SECONDS)
    glow.sparkLeftRest:SetDuration(math_max(0.001, totalDuration - (topDuration + rightDuration + bottomDuration + (CLASSIC_CHASER_FADE_SECONDS * 3)) - leftDuration - CLASSIC_CHASER_FADE_SECONDS))
end

local function CreateChaserSegment(glow, name, width, height)
    local texture = glow:CreateTexture(nil, "OVERLAY")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetBlendMode("ADD")
    texture:SetSize(width, height)
    texture:SetAlpha(0)
    glow[name] = texture

    local anim = texture:CreateAnimationGroup()
    anim:SetLooping("REPEAT")

    local pause = anim:CreateAnimation("Alpha")
    pause:SetOrder(1)
    pause:SetFromAlpha(0)
    pause:SetToAlpha(0)

    local on = anim:CreateAnimation("Alpha")
    on:SetOrder(2)
    on:SetFromAlpha(0)
    on:SetToAlpha(1)

    local move = anim:CreateAnimation("Translation")
    move:SetOrder(2)
    move:SetSmoothing("NONE")

    local fade = anim:CreateAnimation("Alpha")
    fade:SetOrder(3)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)

    local rest = anim:CreateAnimation("Alpha")
    rest:SetOrder(4)
    rest:SetFromAlpha(0)
    rest:SetToAlpha(0)

    glow[name .. "Anim"] = anim
    glow[name .. "Pause"] = pause
    glow[name .. "On"] = on
    glow[name .. "Move"] = move
    glow[name .. "Fade"] = fade
    glow[name .. "Rest"] = rest
    AddAnimationGroup(glow, anim)
end

local function CreateSparkAnimation(glow)
    CreateChaserSegment(glow, "sparkTop", CLASSIC_CHASER_LENGTH, CLASSIC_CHASER_THICKNESS)
    CreateChaserSegment(glow, "sparkRight", CLASSIC_CHASER_THICKNESS, CLASSIC_CHASER_LENGTH)
    CreateChaserSegment(glow, "sparkBottom", CLASSIC_CHASER_LENGTH, CLASSIC_CHASER_THICKNESS)
    CreateChaserSegment(glow, "sparkLeft", CLASSIC_CHASER_THICKNESS, CLASSIC_CHASER_LENGTH)
end

local function CreateClassicGlow(frame)
    local anchor = frame.Health and (frame.Health.backdrop or frame.Health) or frame
    if not anchor then
        return nil
    end

    local E = GetElvUIEngine()
    local blankTexture = E and E.media and E.media.blankTex or "Interface\\Buttons\\WHITE8X8"

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", anchor, "TOPLEFT", -OUTER_GLOW_PADDING, OUTER_GLOW_PADDING)
    holder:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", OUTER_GLOW_PADDING, -OUTER_GLOW_PADDING)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or frame:GetFrameLevel() or 0) + 10)
    holder:EnableMouse(false)
    holder.anchor = anchor
    holder.style = STYLE_CLASSIC
    holder.nativeShadow = frame.AuraHightlightGlow
    holder.nativeHighlight = frame.AuraHighlight
    holder.shadowFrames = {}
    holder.animations = {}

    if holder.CreateShadow then
        holder.shadow = holder:CreateShadow(4, true)
        holder.glowKind = "shadow"
        if holder.shadow then
            holder.shadow:SetFrameStrata(frame:GetFrameStrata())
            holder.shadow:SetFrameLevel(holder:GetFrameLevel())
            AddShadowFrame(holder, holder.shadow)
        end

        holder.outerShadow = holder:CreateShadow(8, true)
        if holder.outerShadow then
            holder.outerShadow:SetFrameStrata(frame:GetFrameStrata())
            holder.outerShadow:SetFrameLevel(holder:GetFrameLevel() - 1)
            AddShadowFrame(holder, holder.outerShadow)
        end
    end

    holder.fill = holder:CreateTexture(nil, "ARTWORK")
    holder.fill:SetTexture(blankTexture)
    holder.fill:SetBlendMode("ADD")
    holder.fill:SetPoint("TOPLEFT", anchor, "TOPLEFT", -INNER_GLOW_PADDING, INNER_GLOW_PADDING)
    holder.fill:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", INNER_GLOW_PADDING, -INNER_GLOW_PADDING)

    holder.outerBloom = holder:CreateTexture(nil, "ARTWORK")
    holder.outerBloom:SetTexture(blankTexture)
    holder.outerBloom:SetBlendMode("ADD")
    holder.outerBloom:SetAllPoints(holder)

    local function NewEdge(layer)
        local texture = holder:CreateTexture(nil, layer)
        texture:SetTexture(blankTexture)
        texture:SetBlendMode("ADD")
        return texture
    end

    holder.top = NewEdge("OVERLAY")
    holder.bottom = NewEdge("OVERLAY")
    holder.left = NewEdge("OVERLAY")
    holder.right = NewEdge("OVERLAY")

    holder.top:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    holder.top:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    holder.top:SetHeight(BORDER_THICKNESS)

    holder.bottom:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    holder.bottom:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    holder.bottom:SetHeight(BORDER_THICKNESS)

    holder.left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    holder.left:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    holder.left:SetWidth(BORDER_THICKNESS)

    holder.right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    holder.right:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    holder.right:SetWidth(BORDER_THICKNESS)

    holder.shimmer = holder:CreateTexture(nil, "OVERLAY")
    holder.shimmer:SetTexture(blankTexture)
    holder.shimmer:SetBlendMode("ADD")
    holder.shimmer:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    holder.shimmer:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)

    local animation = holder:CreateAnimationGroup()
    animation:SetLooping("BOUNCE")

    local alpha = animation:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.8)
    alpha:SetToAlpha(1)
    alpha:SetDuration(1.1)
    alpha:SetSmoothing("IN_OUT")

    holder.anim = animation
    AddAnimationGroup(holder, animation)

    local shimmerAnim = holder.shimmer:CreateAnimationGroup()
    shimmerAnim:SetLooping("BOUNCE")

    local shimmerAlpha = shimmerAnim:CreateAnimation("Alpha")
    shimmerAlpha:SetFromAlpha(0.02)
    shimmerAlpha:SetToAlpha(0.08)
    shimmerAlpha:SetDuration(1.25)
    shimmerAlpha:SetSmoothing("IN_OUT")

    holder.shimmerAnim = shimmerAnim
    AddAnimationGroup(holder, shimmerAnim)
    CreateSparkAnimation(holder)
    holder:Hide()
    return holder
end

local function UpdateClassicGlowAnimationLayout(glow)
    UpdatePerimeterSparkAnimationLayout(glow)
end

local function SetClassicGlowColor(glow, r, g, b, a)
    if not glow then
        return
    end

    if glow.nativeShadow then
        glow.nativeShadow:Hide()
    end

    if glow.nativeHighlight then
        glow.nativeHighlight:SetVertexColor(0, 0, 0, 0)
    end

    if glow.shadow then
        glow.shadow:SetBackdropColor(r, g, b, math_min(1, a * 0.12))
        glow.shadow:SetBackdropBorderColor(r, g, b, math_min(1, a * 0.62))
    end

    if glow.outerShadow then
        glow.outerShadow:SetBackdropColor(r, g, b, a * 0.04)
        glow.outerShadow:SetBackdropBorderColor(r, g, b, math_min(1, a * 0.22))
    end

    if glow.fill then
        glow.fill:SetVertexColor(r, g * 0.98, b * 0.9, math_max(0.03, a * 0.06))
    end

    if glow.outerBloom then
        glow.outerBloom:SetVertexColor(r, g * 0.97, b * 0.88, math_max(0.05, a * 0.09))
    end

    if glow.shimmer then
        glow.shimmer:SetVertexColor(
            math_min(1, r * 1.02 + 0.03),
            math_min(1, g * 1.02 + 0.04),
            math_min(1, b * 0.96 + 0.02),
            math_max(0.02, a * 0.05)
        )
    end

    if glow.top then glow.top:SetVertexColor(r, g, b, math_max(0.42, a * 0.72)) end
    if glow.bottom then glow.bottom:SetVertexColor(r, g, b, math_max(0.42, a * 0.72)) end
    if glow.left then glow.left:SetVertexColor(r, g, b, math_max(0.42, a * 0.72)) end
    if glow.right then glow.right:SetVertexColor(r, g, b, math_max(0.42, a * 0.72)) end

    local chaseR = math_min(1, r * 0.82 + 0.26)
    local chaseG = math_min(1, g * 0.9 + 0.22)
    local chaseB = math_min(1, b * 0.55 + 0.08)
    local chaseA = math_max(0.8, a)

    if glow.sparkTop then glow.sparkTop:SetVertexColor(chaseR, chaseG, chaseB, chaseA) end
    if glow.sparkRight then glow.sparkRight:SetVertexColor(chaseR, chaseG, chaseB, chaseA) end
    if glow.sparkBottom then glow.sparkBottom:SetVertexColor(chaseR, chaseG, chaseB, chaseA) end
    if glow.sparkLeft then glow.sparkLeft:SetVertexColor(chaseR, chaseG, chaseB, chaseA) end

    glow:SetAlpha(a)
end

local function ApplyButtonGlowColor(glow)
    if not glow or not glow.anchor then
        return
    end

    local overlay = glow.anchor.__LBGoverlay
    local color = glow.buttonGlowColor
    if not overlay or not color then
        return
    end

    local r, g, b, a = color[1], color[2], color[3], color[4]
    local strongA = math_max(0.5, a)
    local softA = math_max(0.18, a * 0.45)

    if overlay.spark then overlay.spark:SetVertexColor(r, g, b, strongA) end
    if overlay.innerGlow then overlay.innerGlow:SetVertexColor(r, g, b, strongA) end
    if overlay.innerGlowOver then overlay.innerGlowOver:SetVertexColor(r, g, b, softA) end
    if overlay.outerGlow then overlay.outerGlow:SetVertexColor(r, g, b, strongA) end
    if overlay.outerGlowOver then overlay.outerGlowOver:SetVertexColor(r, g, b, softA) end
    if overlay.ants then overlay.ants:SetVertexColor(r, g, b, strongA) end
end

local function CreateButtonGlow(frame)
    local anchor = frame.Health and (frame.Health.backdrop or frame.Health) or frame
    if not anchor then
        return nil
    end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    holder:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or frame:GetFrameLevel() or 0) + 12)
    holder:EnableMouse(false)
    holder.anchor = anchor
    holder.style = STYLE_BUTTON
    holder.nativeShadow = frame.AuraHightlightGlow
    holder.nativeHighlight = frame.AuraHighlight
    holder.animations = {}

    holder:Hide()
    return holder
end

local function SetButtonGlowColor(glow, r, g, b, a)
    if not glow then
        return
    end

    glow.buttonGlowColor = {
        math_min(1, r * 0.96 + 0.04),
        math_min(1, g * 0.96 + 0.04),
        math_min(1, b * 0.96 + 0.04),
        math_max(0.45, a * 0.85),
    }

    if glow.nativeShadow then
        glow.nativeShadow:Hide()
    end

    if glow.nativeHighlight then
        glow.nativeHighlight:SetVertexColor(0, 0, 0, 0)
    end

    ApplyButtonGlowColor(glow)

    glow:SetAlpha(a)
end

local function CreateGlow(frame, style)
    style = NormalizeGlowStyle(style)
    if style == STYLE_BUTTON then
        return CreateButtonGlow(frame)
    end

    return CreateClassicGlow(frame)
end

local function UpdateGlowAnimationLayout(glow)
    if not glow then
        return
    end

    UpdateClassicGlowAnimationLayout(glow)
end

local function SetGlowColor(glow, r, g, b, a)
    if not glow then
        return
    end

    if glow.style == STYLE_BUTTON then
        SetButtonGlowColor(glow, r, g, b, a)
        return
    end

    SetClassicGlowColor(glow, r, g, b, a)
end

local function StartGlowAnimations(glow)
    local animations = glow and glow.animations
    if not animations then
        return
    end

    if glow.style == STYLE_BUTTON and LBG and glow.anchor then
        LBG.ShowOverlayGlow(glow.anchor)
        ApplyButtonGlowColor(glow)
    end

    for index = 1, #animations do
        local animation = animations[index]
        if animation and not animation:IsPlaying() then
            animation:Play()
        end
    end
end

local function StopGlowAnimations(glow)
    local animations = glow and glow.animations
    if not animations then
        return
    end

    if glow.style == STYLE_BUTTON and LBG and glow.anchor then
        LBG.HideOverlayGlow(glow.anchor)
    end

    for index = 1, #animations do
        local animation = animations[index]
        if animation then
            animation:Stop()
        end
    end
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
        local group = UF[groupName]
        if group and group.GetChildren then
            for _, child in next, { group:GetChildren() } do
                VisitFrameTree(child, callback)
            end
        end
    end
end

function RaidFrames:ClearFrameCache()
    state.trackedFrames = {}
    state.framesByUnit = {}
    state.frameCacheDirty = false
end

function RaidFrames:RebuildFrameCache()
    self:ClearFrameCache()

    local seenFrames = setmetatable({}, { __mode = "k" })
    self:EnumerateFrames(function(frame)
        if not frame or seenFrames[frame] then
            return
        end

        seenFrames[frame] = true
        state.trackedFrames[#state.trackedFrames + 1] = frame

        local unit = frame.unit
        if type(unit) == "string" and unit ~= "" then
            local frames = state.framesByUnit[unit]
            if not frames then
                frames = {}
                state.framesByUnit[unit] = frames
            end
            frames[#frames + 1] = frame
        end
    end)
end

function RaidFrames:GetFramesForUnit(unit)
    if state.frameCacheDirty then
        self:RebuildFrameCache()
    end

    local frames = state.framesByUnit[unit]
    if frames or not unit then
        return frames
    end

    self:RebuildFrameCache()
    return state.framesByUnit[unit]
end

function RaidFrames:IsTesting()
    return state.testUntil > GetTime()
end

function RaidFrames:GetOrCreateGlow(frame, allowCreate)
    local glow = state.glowByFrame[frame]
    local style = GetGlowStyle()
    if glow then
        if glow.style ~= style then
            self:HideGlow(frame)
            state.glowByFrame[frame] = nil
            glow = nil
        else
            return glow
        end
    end

    if not allowCreate then
        return glow
    end

    glow = CreateGlow(frame, style)
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

    UpdateGlowAnimationLayout(glow)

    if glow.nativeShadow then
        glow.nativeShadow:Hide()
    end

    if glow.nativeHighlight then
        glow.nativeHighlight:SetVertexColor(0, 0, 0, 0)
    end

    glow:Show()
    if glow.shadow then
        glow.shadow:Show()
    end
    if glow.outerShadow then
        glow.outerShadow:Show()
    end

    StartGlowAnimations(glow)

    state.active[frame] = true
end

function RaidFrames:HideGlow(frame)
    local glow = state.glowByFrame[frame]
    if not glow then
        return
    end

    StopGlowAnimations(glow)

    if glow.nativeShadow then
        glow.nativeShadow:Hide()
    end

    if glow.nativeHighlight then
        glow.nativeHighlight:SetVertexColor(0, 0, 0, 0)
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
    self:RebuildFrameCache()

    if not IsDispellableDebuffsHighlightEnabled() then
        state.pendingFullRefresh = false

        for frame in pairs(state.active) do
            self:HideGlow(frame)
        end

        return
    end

    local allowCreate = not InCombatLockdown()
    state.pendingFullRefresh = not allowCreate

    for unit, frames in pairs(state.framesByUnit) do
        PrimeUnitAuraState(frames[1], unit, "GROUP_ROSTER_UPDATE")
    end

    for index = 1, #state.trackedFrames do
        self:UpdateFrame(state.trackedFrames[index], allowCreate)
    end
end

function RaidFrames:RefreshUnit(unit, updateInfo)
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

    local frames = self:GetFramesForUnit(unit)
    if not frames then
        return
    end

    PrimeUnitAuraState(frames[1], unit, "UNIT_AURA", updateInfo)

    for index = 1, #frames do
        self:UpdateFrame(frames[index], allowCreate)
    end
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

function RaidFrames:UNIT_AURA(_, unit, updateInfo)
    self:RefreshUnit(unit, updateInfo)
end

function RaidFrames:OnEnable()
    state.frameCacheDirty = true
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
    state.trackedFrames = {}
    state.framesByUnit = {}
    state.frameCacheDirty = true
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

local function GetDebugFrame()
    if state.debugFrame then
        return state.debugFrame
    end

    local frame = CreateFrame("Frame", "TwichUIRaidFramesDebugFrame", UIParent, "BasicFrameTemplateWithInset")
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
    frame.title:SetText("TwichUI RaidFrames Debug")

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
    state.debugFrame = frame
    return frame
end

local function ShowDebugLines(lines)
    local frame = GetDebugFrame()
    local text = table.concat(lines, "\n")
    frame.editBox:SetText(text)
    frame.editBox:HighlightText()
    frame.editBox:SetCursorPosition(0)
    frame.scroll:SetVerticalScroll(0)
    frame:Show()
end

function RaidFrames:DebugUnit(unit)
    unit = type(unit) == "string" and unit ~= "" and unit or "player"

    local frames = self:GetFramesForUnit(unit)
    local frameCount = frames and #frames or 0
    local oUF = GetoUF()
    local harmful = oUF and oUF.AuraFiltered and oUF.AuraFiltered.HARMFUL and oUF.AuraFiltered.HARMFUL[unit]
    local harmfulCount = 0
    local lines = {}

    lines[#lines + 1] = ("[RaidFrames] unit=%s exists=%s frames=%d shown=%s enabled=%s inCombat=%s"):format(
        unit,
        tostring(UnitExists(unit) == true),
        frameCount,
        tostring(frames and frames[1] and frames[1].IsShown and frames[1]:IsShown() or false),
        tostring(IsDispellableDebuffsHighlightEnabled() == true),
        tostring(InCombatLockdown() == true)
    )
    lines[#lines + 1] = ("[RaidFrames] glowStyle=%s"):format(GetGlowStyle())

    if not harmful then
        lines[#lines + 1] = "[RaidFrames] harmful cache: <nil>"
        lines[#lines + 1] = ("[RaidFrames] legacy RAID debuff result=%s"):format(
            tostring(HasLegacyRaidDispellableDebuff(unit))
        )
        ShowDebugLines(lines)
        return
    end

    for auraInstanceID, aura in pairs(harmful) do
        harmfulCount = harmfulCount + 1
        if harmfulCount <= 5 then
            lines[#lines + 1] = (
                "[RaidFrames] aura=%s raidPlayerDispellable=%s canActivePlayerDispel=%s dispelName=%s name=%s"
            ):format(
                tostring(auraInstanceID),
                DescribeAuraValue(oUF, aura and aura.auraIsRaidPlayerDispellable),
                DescribeAuraValue(oUF, aura and aura.canActivePlayerDispel),
                DescribeAuraValue(oUF, aura and aura.dispelName),
                DescribeAuraValue(oUF, aura and aura.name)
            )
        end
    end

    lines[#lines + 1] = ("[RaidFrames] harmful cache count=%d"):format(harmfulCount)
    ShowDebugLines(lines)
end

function RaidFrames:GetDefaultColor()
    return DEFAULT_COLOR.r, DEFAULT_COLOR.g, DEFAULT_COLOR.b, DEFAULT_COLOR.a
end

function RaidFrames:GetDefaultGlowStyle()
    return STYLE_CLASSIC
end
