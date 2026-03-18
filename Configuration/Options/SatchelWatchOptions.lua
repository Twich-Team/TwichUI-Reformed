--[[
    Options for the QuestLogCleaner module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class SatchelWatchConfigurationOptions
local Options = ConfigurationModule.Options.SatchelWatch or {}
ConfigurationModule.Options.SatchelWatch = Options

---@return table satchelWatchDB the profile-level satchel watch configuration database.
function Options:GetSatchelWatchDB()
    if not ConfigurationModule:GetProfileDB().satchelWatch then
        ConfigurationModule:GetProfileDB().satchelWatch = {}
    end
    return ConfigurationModule:GetProfileDB().satchelWatch
end

function Options:GetEnabled(info)
    local db = self:GetSatchelWatchDB()
    return db.enabled or false
end

function Options:SetEnabled(info, value)
    local db = self:GetSatchelWatchDB()
    db.enabled = value
end

function Options:GetNotifyForDPS(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForDPS or false
end

function Options:SetNotifyForDPS(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForDPS = value
end

function Options:GetNotifyForHealers(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForHealers or false
end

function Options:SetNotifyForHealers(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForHealers = value
end

function Options:GetNotifyForTanks(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForTanks or false
end

function Options:SetNotifyForTanks(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForTanks = value
end

function Options:GetNotifyOnlyWhenNotInGroup(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyOnlyWhenNotInGroup or false
end

function Options:SetNotifyOnlyWhenNotInGroup(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyOnlyWhenNotInGroup = value
end

function Options:GetNotifyForRegularDungeon(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForRegularDungeon or false
end

function Options:SetNotifyForRegularDungeon(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForRegularDungeon = value
end

function Options:GetNotifyOnlyForRaids(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyOnlyForRaids or false
end

function Options:SetNotifyOnlyForRaids(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyOnlyForRaids = value
end
