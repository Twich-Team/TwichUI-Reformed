--[[
        Best in Slot -- Great Vault Enchancement module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

---@class GreatVaultEnhancementModule: AceEvent-3.0
local Monitor = BIS:NewModule("GreatVaultEnhancement", "AceEvent-3.0")

---@class GreatVaultHighlightState
---@field hooked boolean
---@field glowByTarget table<table, Frame>
---@field active table<table, boolean>
---@field listener fun(...)|nil
local VaultHighlight = {
    hooked = false,
    glowByTarget = setmetatable({}, { __mode = "k" }),
    active = setmetatable({}, { __mode = "k" }),
    listener = nil,
}

---@return BestInSlotConfigurationOptions
local function GetOptions()
    return T:GetModule("Configuration").Options.BestInSlot
end

---@return MonitorGreatVaultItemsModule|nil
local function GetGVMonitor()
    ---@type MonitorGreatVaultItemsModule|nil
    return BIS:GetModule("MonitorGreatVaultItems", true)
end

function Monitor:OnEnable()
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
end

---@param _ any
---@param frameType Enum.PlayerInteractionType|number
function Monitor:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(_, frameType)
    if frameType ~= Enum.PlayerInteractionType.WeeklyRewards then
        return
    end
    self:UpdateVaultHighlights()
end

local function ClearVaultHighlights()
    for target in pairs(VaultHighlight.active) do
        local glow = VaultHighlight.glowByTarget[target]
        if glow then
            if glow.anim then glow.anim:Stop() end
            glow:Hide()
        end
        VaultHighlight.active[target] = nil
    end
end

---@param parent Frame|table|nil
---@return Frame|nil
local function CreatePixelGlow(parent)
    if not parent or not parent.CreateTexture then return nil end

    local ElvUI = rawget(_G, "ElvUI")
    local E = ElvUI and ElvUI[1]
    local borderTexture = (E and E.media and (E.media.blankTex or E.media.normTex)) or "Interface\\Buttons\\WHITE8X8"

    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 20)

    local thickness = 2
    local offset = 2

    local function NewEdge()
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetTexture(borderTexture)
        t:SetBlendMode("ADD")
        return t
    end

    f.top = NewEdge()
    f.bottom = NewEdge()
    f.left = NewEdge()
    f.right = NewEdge()

    f.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -offset, offset)
    f.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", offset, offset)
    f.top:SetHeight(thickness)

    f.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -offset, -offset)
    f.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", offset, -offset)
    f.bottom:SetHeight(thickness)

    f.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -offset, offset)
    f.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -offset, -offset)
    f.left:SetWidth(thickness)

    f.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", offset, offset)
    f.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", offset, -offset)
    f.right:SetWidth(thickness)

    f.anim = f:CreateAnimationGroup()
    f.anim:SetLooping("BOUNCE")
    local a = f.anim:CreateAnimation("Alpha")
    a:SetFromAlpha(0.15)
    a:SetToAlpha(1.0)
    a:SetDuration(0.85)
    a:SetSmoothing("IN_OUT")

    return f
end

---@param glow Frame|table|nil
---@param r number
---@param g number
---@param b number
---@param a number
local function SetGlowColor(glow, r, g, b, a)
    if not glow then return end
    if glow.top then glow.top:SetVertexColor(r, g, b, a) end
    if glow.bottom then glow.bottom:SetVertexColor(r, g, b, a) end
    if glow.left then glow.left:SetVertexColor(r, g, b, a) end
    if glow.right then glow.right:SetVertexColor(r, g, b, a) end
end

function Monitor:UpdateVaultHighlights()
    local GVMonitor = GetGVMonitor()
    if not GVMonitor or type(GVMonitor.FindVaultFrame) ~= "function" or type(GVMonitor.ScanVault) ~= "function" or type(GVMonitor.IsItemBestInSlot) ~= "function" then
        ClearVaultHighlights()
        return
    end

    local frame, frameName = GVMonitor.FindVaultFrame()
    if not frame or not frame.IsShown or not frame:IsShown() then
        ClearVaultHighlights()
        return
    end

    local r, g, b, a = GetOptions():GetGreatVaultHighlightColor()

    local rewards = GVMonitor.ScanVault(frame, frameName)
    local newActive = {}

    if type(rewards) ~= "table" or next(rewards) == nil then
        ClearVaultHighlights()
        return
    end

    for _, reward in ipairs(rewards) do
        if GVMonitor.IsItemBestInSlot(reward.itemID) then
            -- TODO: Is item better, but for now::
            if reward.node then
                local alreadyOwned, alreadyEquipped, ownedIlvl, ownedLink, ownedTrackRank = BIS.ItemScanner
                    .PlayerOwnsItem(reward.itemID)

                local isUpgrade = false

                if alreadyOwned and link then
                    local track, currentStage, maxStage = BIS.ItemScanner.GetTrackFromLink(link)
                    local newTrackRank = BIS.ItemScanner.GetGearTrackRank(track)

                    if newTrackRank and ownedTrackRank and newTrackRank > ownedTrackRank then
                        isUpgrade = true
                    else
                        -- same or lower track
                    end
                elseif not alreadyOwned then
                    isUpgrade = true
                end

                if isUpgrade then
                    local glow = VaultHighlight.glowByTarget[reward.node]
                    if not glow then
                        glow = CreatePixelGlow(reward.node)
                        VaultHighlight.glowByTarget[reward.node] = glow
                    end
                    if glow then
                        SetGlowColor(glow, r, g, b, a)
                        glow:Show()
                        if glow.anim and not glow.anim:IsPlaying() then
                            glow.anim:Play()
                        end
                        newActive[reward.node] = true
                    end
                end
            end
        end
    end

    -- Remove glows that are no longer active.
    for target in pairs(VaultHighlight.glowByTarget) do
        if VaultHighlight.glowByTarget[target] and not newActive[target] then
            local glow = VaultHighlight.glowByTarget[target]
            if glow then
                if glow.anim then glow.anim:Stop() end
                glow:Hide()
            end
        end
    end

    VaultHighlight.active = setmetatable(newActive, { __mode = "k" })
end
