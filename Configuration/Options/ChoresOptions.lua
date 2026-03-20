---@diagnostic disable: undefined-field
--[[
    Options for the Chores module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class ChoresConfigurationOptions
local Options = ConfigurationModule.Options.Chores or {}
ConfigurationModule.Options.Chores = Options

local function RefreshChores()
    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if choresModule and choresModule.RequestRefresh then
        choresModule:RequestRefresh(true)
    end

    ---@type DataTextModule
    local datatextModule = T:GetModule("Datatexts")
    if datatextModule and datatextModule.RefreshDataText then
        datatextModule:RefreshDataText("TwichUI: Chores")
    end
end

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().chores then
        ConfigurationModule:GetProfileDB().chores = {}
    end
    return ConfigurationModule:GetProfileDB().chores
end

function Options:GetCategoryDB()
    local db = self:GetDB()
    if not db.categories then
        db.categories = {}
    end
    return db.categories
end

function Options:GetRaidWingDB()
    local db = self:GetDB()
    if not db.raidWings then
        db.raidWings = {}
    end
    return db.raidWings
end

function Options:GetEnabled(info)
    local enabled = self:GetDB().enabled
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetEnabled(info, value)
    self:GetDB().enabled = value

    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if value then
        choresModule:Enable()
        choresModule:RequestRefresh(true)
    else
        choresModule:Disable()
    end

    RefreshChores()
end

function Options:GetShowCompleted(info)
    return self:GetDB().showCompleted == true
end

function Options:SetShowCompleted(info, value)
    self:GetDB().showCompleted = value == true
    RefreshChores()
end

function Options:GetTrackBountifulDelves(info)
    local enabled = self:GetDB().trackBountifulDelves
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetTrackBountifulDelves(info, value)
    self:GetDB().trackBountifulDelves = value == true
    RefreshChores()
end

function Options:IsCategoryEnabled(categoryKey)
    local enabled = self:GetCategoryDB()[categoryKey]
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetCategoryEnabled(categoryKey, value)
    self:GetCategoryDB()[categoryKey] = value
    RefreshChores()
end

function Options:IsRaidWingEnabled(dungeonID)
    local enabled = self:GetRaidWingDB()[tostring(dungeonID)]
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetRaidWingEnabled(dungeonID, value)
    self:GetRaidWingDB()[tostring(dungeonID)] = value == true
    RefreshChores()
end
