--[[
    Module that provides various quality of life submodules
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class QualityOfLife : AceModule
local QOL = T:NewModule("QualityOfLife")
QOL:SetEnabledState(true)

function QOL:SetSubmoduleEnabled(moduleName, shouldEnable)
    if type(moduleName) ~= "string" or moduleName == "" then
        return nil
    end

    if shouldEnable and not self:IsEnabled() then
        self:Enable()
    end

    local module = self:GetModule(moduleName, true)
    if not module then
        return nil
    end

    if shouldEnable then
        if not module:IsEnabled() then
            module:Enable()
        else
            local runtimeModule = module --[[@as any]]
            if type(runtimeModule.RefreshSettings) == "function" then
                runtimeModule:RefreshSettings()
            end
        end
    elseif module:IsEnabled() then
        module:Disable()
    end

    return module
end

function QOL:OnEnable()
    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    local Options = CM.Options --[[@as any]]

    if Options.MapTweaks and Options.MapTweaks:GetEnabled() then
        self:SetSubmoduleEnabled("MapTweaks", true)
    end

    if Options.GameTweaks and Options.GameTweaks:GetEnabled() then
        self:SetSubmoduleEnabled("GameTweaks", true)
    end

    -- Enable submodules
    if Options.AutoLoot and Options.AutoLoot:GetEnabled() then
        self:SetSubmoduleEnabled("AutoLoot", true)
    end

    if Options.LootFeed and Options.LootFeed:GetEnabled() then
        self:SetSubmoduleEnabled("LootFeed", true)
    end

    if Options.QuestAutomation and Options.QuestAutomation:IsModuleEnabled() then
        self:GetModule("QuestAutomation"):Enable()
    end

    if Options.GossipHotkeys and Options.GossipHotkeys:IsModuleEnabled() then
        self:GetModule("GossipHotkeys"):Enable()
    end

    if Options.SatchelWatch and Options.SatchelWatch:GetEnabled() then
        self:SetSubmoduleEnabled("SatchelWatch", true)
    end

    if Options.DungeonTracking and Options.DungeonTracking:GetEnabled() then
        self:SetSubmoduleEnabled("DungeonTracking", true)
    end


    if Options.PreyTweaks and Options.PreyTweaks:GetEnabled() then
        self:SetSubmoduleEnabled("PreyTweaks", true)
    end

    if Options.Teleports and Options.Teleports:GetEnabled() then
        self:SetSubmoduleEnabled("Teleports", true)
    end

    if Options.WorldQuests and Options.WorldQuests:GetEnabled() then
        self:SetSubmoduleEnabled("WorldQuests", true)
    end
end
