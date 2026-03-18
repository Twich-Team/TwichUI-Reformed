--[[
    Options for the QuestLogCleaner module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class QuestLogCleanerConfigurationOptions
local Options = ConfigurationModule.Options.QuestLogCleaner or {}
ConfigurationModule.Options.QuestLogCleaner = Options

---@return table questLogCleanerDB the profile-level quest log cleaner configuration database.
function Options:GetQuestLogCleanerDB()
    if not ConfigurationModule:GetProfileDB().questLogCleaner then
        ConfigurationModule:GetProfileDB().questLogCleaner = {}
    end
    return ConfigurationModule:GetProfileDB().questLogCleaner
end

function Options:GetKeepNearMyLevelQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.onlyLowLevelQuests or false
end

function Options:SetKeepNearMyLevelQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.onlyLowLevelQuests = value
end

function Options:GetKeepCampaignQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.keepCampaignQuests or false
end

function Options:SetKeepCampaignQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.keepCampaignQuests = value
end

function Options:GetKeepImportantQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.keepImportantQuests or false
end

function Options:SetKeepImportantQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.keepImportantQuests = value
end

function Options:GetKeepMetaQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.keepMetaQuests or false
end

function Options:SetKeepMetaQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.keepMetaQuests = value
end

function Options:GetKeepDungeonQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.keepDungeonQuests or false
end

function Options:SetKeepDungeonQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.keepDungeonQuests = value
end

function Options:GetKeepRaidQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.keepRaidQuests or false
end

function Options:SetKeepRaidQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.keepRaidQuests = value
end

function Options:GetKeepDelveQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.keepDelveQuests or false
end

function Options:SetKeepDelveQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.keepDelveQuests = value
end

function Options:GetKeepArtifactQuests(info)
    local db = self:GetQuestLogCleanerDB()
    return db.keepArtifactQuests or false
end

function Options:SetKeepArtifactQuests(info, value)
    local db = self:GetQuestLogCleanerDB()
    db.keepArtifactQuests = value
end
