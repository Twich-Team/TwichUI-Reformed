--[[
    Module that provides various quality of life submodules
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class QualityOfLife : AceModule
local QOL = T:NewModule("QualityOfLife")
QOL:SetEnabledState(true)

function QOL:OnEnable()
    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    local Options = CM.Options

    -- Enable submodules
    if Options.QuestAutomation and Options.QuestAutomation:IsModuleEnabled() then
        self:GetModule("QuestAutomation"):Enable()
    end

    if Options.GossipHotkeys and Options.GossipHotkeys:IsModuleEnabled() then
        self:GetModule("GossipHotkeys"):Enable()
    end

    if Options.SatchelWatch and Options.SatchelWatch:GetEnabled() then
        self:GetModule("SatchelWatch"):Enable()
    end

    if Options.DungeonTracking and Options.DungeonTracking:GetEnabled() then
        self:GetModule("DungeonTracking"):Enable()
    end

    if Options.PreyTweaks and Options.PreyTweaks:GetEnabled() then
        self:GetModule("PreyTweaks"):Enable()
    end

    if Options.Teleports and Options.Teleports:GetEnabled() then
        self:GetModule("Teleports"):Enable()
    end
end
